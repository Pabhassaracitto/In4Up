# ADR-0015: Nguồn phát âm thống nhất (TTS · audio từ điển · YouGlish) và phạm vi dùng YouGlish

- **Ngày:** 2026-10-24 (re-check 2026-10-24 sau khi rebase lên
  `arena/01a0251e-in4up` `3986433`: mọi số dòng/trạng thái đã đối chiếu lại, xem
  PLAN-038 §0; ADR này đánh số 0015 vì 0014 đã bị `b220b78`
  (`0014-word-insight-va-lam-sach-tu-dien.md`) chiếm trước)
- **Trạng thái:** CHẤP NHẬN về khung (owner chốt 4 quyết định qua bảng câu hỏi
  2026-10-24) — **chưa có code**. Card thi công: PRON-001…PRON-004, plan
  `docs/plans/PLAN-038-nguon-phat-am-youglish.md`.
- **Phạm vi:** mọi điểm vào "nghe phát âm của MỘT từ" — `word_actions_sheet`,
  `word_mini_pop` (tab Đọc), `word_list_screen`, `memory_mode/sheets/word_detail_sheet`,
  `pdf_wordlist_panel`, `yt_word_panel`, tool `youglish/`.
- **Không đụng:** quy tắc vàng 1 (`lib/ffi/`, `UltraTimeStretch`), quy tắc vàng 2
  (3 skill SM-2 tách biệt). Audio focus chỉ được xử lý ở tầng Flutter
  (`TtsService`/`TextProvider.speak`), không sửa engine realtime.

## Cập nhật 2026-10-26 (đối chiếu lại sau 12 commit của `arena/01a0251e-in4up`, tip `0706d8f`)

Ba điều ADR này cần ghi lại, **không đổi quyết định D1–D7**:

1. **D3 càng đúng hơn:** `961fb26 READ-POP-003` + **ADR-0016** đổi pop tra từ sang
   `OverlayEntry` **không barrier** (pop không còn chặn màn hình). Vì pop giờ
   không modal, nếu ta dựng sẵn WebView thì chi phí nhân lên mọi cú chạm; còn
   "một nút, lazy" chỉ tốn khi user thật sự muốn nghe. Điểm cấy icon: hàng
   `_MiniIconButton` `word_mini_pop.dart:515`–`:527`; bắt buộc `WordMiniPop.dismiss()`
   trước khi mở sheet YouGlish và **khóa `word`** lúc mở (pop có thể nhảy sang từ
   khác khi sheet còn sống).
2. **Ràng buộc cổng CI mới:** `4b4965f` (run 40229976121 — widget+Hive treo >8')
   ⇒ test của PRON-002/003/005 phải là **test thuần Dart**; test có plugin chỉ
   chạy tay + ghi bằng chứng vào card.
3. **D1 có thêm dữ liệu thật:** `6672b57 DICT-PACK-001` + **ADR-0017** cho tải bộ
   từ điển trong app, `dict_pack_service.dart:351` chấp nhận `wav/mp3/ogg/m4a`
   ⇒ nguồn "audio từ điển" không còn là ý tưởng trên giấy. `DictEntry.audioPath`
   vẫn chưa UI nào dùng ⇒ lập **PRON-005**.

Số ADR: **0016** (pop không modal) và **0017** (tải từ điển trong app) đã bị
nhánh khác chiếm ngày 2026-10-25 ⇒ ADR tiếp theo của dự án là **0018**.

## Bối cảnh

Đề bài ban đầu (người sở hữu, 2026-10-24, nội dung do Gemini gợi ý) yêu cầu
"thêm tab Youglish vào `word_detail_sheet` ở Tab Đọc, tái sử dụng service YouGlish
có sẵn, mở modal WebView để không gián đoạn trải nghiệm đọc". Kiểm tra code
2026-10-24 cho thấy 4 giả định trong đề bài **không khớp hiện trạng**:

1. **Tab Đọc không dùng `word_detail_sheet.dart`.** Chuỗi thật khi chạm một từ:
   `read_mode/widgets/text_line_widget.dart:614` và
   `read_mode/widgets/colored_text_widget.dart:242` → `WordActionsSheet.show(...)`
   (`read_mode/sheets/word_actions_sheet.dart`, 1179 dòng); chạm-nhanh cho pop gọn
   `read_mode/widgets/word_mini_pop.dart` (599 dòng, cơ chế "kéo rèm" theo
   AUDIT-2026-10-20 mục 4). Hai file tên `word_detail_sheet.dart` đều thuộc nơi
   khác: `memory_mode/sheets/` (vườn nhớ S-M2) và `widgets/` (map/venn/triangle).
2. **`word_actions_sheet.dart` không có hệ thống tab** (không `TabBar`,
   không `DefaultTabController`) → "thêm tab Youglish" = dựng hạ tầng tab mới
   trong file 1179 dòng, rủi ro hồi quy lớn hơn hẳn "thêm một nút action".
3. **Không tồn tại "một service YouGlish dùng chung".** Có **ba** bản copy:
   `youglish/youglish_widget.dart` (WebView + nhánh Windows, chỉ `YouGlishScreen`
   dùng) · `word_list/youglish_mini_sheet.dart` (tự tạo `WebViewController`,
   tự copy `_buildUrl()`, KHÔNG có nhánh Windows, chip ngôn ngữ bị `values.take(5)`)
   · `youglish/youglish_screen.dart` (không nhận `initialWord` ⇒ không thể mở
   đúng từ đang tra). Nối thêm một chỗ nữa = bản duplicate thứ tư.
4. **Kiến trúc dự án không phải "Provider/Bloc"** — `pubspec.yaml` có
   `provider: ^6.1.2`, không có `flutter_bloc`; vùng đọc dùng `ChangeNotifier`
   (`TextProvider`, `VocabularyProvider`) + controllers.

Hai ràng buộc ngoài code, quyết định sống/chết của tính năng:

5. **YouGlish Developer Policy** (`youglish.com/api/doc widget`, truy cập
   2026-10-24): mục 6 — dùng API/widget "**as part of your mobile app**" phải
   liên hệ xin phép; mục 5 — mục đích thương mại phải xin phép; mục 7 — dòng
   "powered by YouGlish.com" phải luôn nhìn thấy; mục 3 — điều khoản app phải
   dẫn link YouTube ToS + Google Privacy Policy, player YouTube phải hiển thị
   100% và **tối thiểu 200×200 px**; mục 2 — phải xin consent cookie; mục 1 —
   lượng impression lớn/ngày phải báo trước. Widget chính thức có format
   `<a class="youglish-widget" data-query data-lang data-components>` +
   `https://youglish.com/public/emb/widget.js`, **không phải**
   `?embed=1&autoplay=1` như code ta đang dựng ⇒ khả năng cao WebView đang nạp
   nguyên website (menu, upsell, banner cookie) thay vì widget gọn.
6. **WebView trong `showModalBottomSheet` trên máy thật** là vùng hay lỗi:
   `youglish_mini_sheet` đã phải khai 4 `gestureRecognizers` để không đơ khi kéo;
   `setBackgroundColor(transparent)` + `Colors.transparent` sheet + PlatformView
   là tổ hợp dễ ám đen/trắng; **không** chỗ nào gọi
   `setMediaPlaybackRequiresUserGesture(false)` ⇒ iOS inline playback chưa chắc
   chạy; `youglish_widget.dart` import `dart:io` ⇒ mọi file reachable từ
   `lib/main_web.dart` import nó làm **build web đỏ** (CI `deploy-web.yml`).
   Ngoài ra `word_actions_sheet.dart` không pause gì khi mở ⇒ video tiếng đè lên
   TTS/`smart_playback_bar` đang đọc bài (audio focus Android có thể cắt cả hàng
   đợi đọc, user mất chỗ đang đọc).

Về sản phẩm: repo đã có **ba** nguồn nghe cho một từ nhưng chưa từng được thiết
kế chung — (a) TTS `tp.speak` (`word_actions_sheet.dart:282`,
`wordMiniPopSpeakKey`, `pdf_wordlist_panel.dart:272`); (b) audio từ điển offline
`DictEntry.audioPath`/`hasAudio` — **đã parse, đã lưu, không UI nào tiêu thụ**;
(c) YouGlish — nhiều giọng người thật + ngữ cảnh, cần mạng, vướng mục 5. Nếu chỉ
"thêm một nút YouGlish" thì sau vài đợt ta có ba nút loa cạnh nhau ở bảy nơi
(điểm vào thứ bảy vừa xuất hiện trên `arena/01a0251e-in4up`:
`features/dictionary/widgets/dict_entry_detail_sheet.dart` đã có sẵn callback
`onSpeak` nhưng chưa nối nguồn nào).

## Quyết định

**D1 — "Nguồn phát âm" là một khái niệm, YouGlish chỉ là một nguồn.**
Một widget hàng-động-tác phát âm dùng chung (tên dự kiến `WordPronunciationRow`,
đặt tại `lib/features/word_lookup/widgets/`), nguồn theo thứ tự ưu tiên
`YouGlish (nếu bật + có mạng) → audio từ điển offline → TTS`, kèm chip chọn
nguồn + chip accent. Không thêm "nút YouGlish" riêng lẻ ở từng sheet; mọi
điểm vào tra từ gọi cùng một widget. YouGlish *là một nguồn* — làm ở PRON-002,
audio-từ điển (đang chết) có thể nối sau ở PRON-005.

**D2 — Chính sách dùng YouGlish: giữ nguyên cách hiện tại + xin phép song song
+ kill-switch.** (owner chọn `ask_permission` 2026-10-24)
- WP PRON-001/002 dùng cách cũ: `WebViewController` nạp
  `https://youglish.com/pronounce/<word>/<lang>/<accent>?embed=1...`. **Không
  đổi URL** (golden test chốt từng byte — xem D5) vì đổi URL là đổi hành vi.
- Người sở hữu gửi yêu cầu cấp quyền cho YouGlish (mục 5+6 Developer Policy).
  Trong lúc chờ: **không** bật widget chính thức, **không** bật autoplay mặc định
  ở các điểm vào mới (PRON-003 sẽ đổi mặc định cho cả app, có chủ đích).
- Kill-switch: `youglish.enabled` trong `SharedPreferences` (mặc định `true`,
  mẫu `cabin_session_settings.dart`). Khi `false`: mọi điểm vào YouGlish trong
  hàng "Phát âm" **ẩn**, chỉ còn "Mở trong trình duyệt" (`url_launcher`, đã có
  trong deps web entrypoint). Nếu YouGlish từ chối hoặc im lặng quá hạn ⇒ owner
  bật `false`, không phải sửa code.
- Điều khoản/Privacy (app + store listing) phải bổ sung: link YouTube ToS +
  Google Privacy Policy (mục 3), ghi rõ nội dung phát do YouTube/YouGlish cung
  cấp, cần consent cookie (mục 2). Đây là việc **văn bản**, chặn ở PRON-004.

**D3 — Một nút, lazy. Không tab, không preload.** (owner chọn `button_lazy`)
WebView **chỉ được tạo khi người dùng bấm** điểm vào YouGlish, và chỉ tồn tại
trong lúc sheet YouGlish mở (dispose khi đóng). Đa số cú chạm từ chỉ để xem
nghĩa ⇒ không được trả giá RAM/pin/mạng cho những chạm đó. "Hiện video ngay khi
mở sheet tra từ" bị **bác**: mỗi chạm một từ = một request YouGlish + một request
YouTube, đúng cơ chế khiến add-on Anki dùng YouGlish bị chặn tạm thời / hỏi
captcha, và nó không hề "không gián đoạn" (1–3 s nạp + che mất dòng đang đọc).
Không có hệ thống tab trong `word_actions_sheet`: bác luôn.

**D4 — Pause và khôi phục playback.** (owner chọn `pause_restore`) Khi mở sheet
phát âm có WebView: lưu trạng thái playback + `pause()` TTS; khi đóng: khôi phục
đúng vị trí. Thực hiện qua API đã có của `TextProvider`/`TtsService`, **không**
chạm tầng FFI (quy tắc vàng 1). Hai sheet lồng nhau (sheet từ → sheet YouGlish)
phải dùng một bộ đếm "số sheet phát âm đang mở", không pause/restore rải rác.

**D5 — Gom YouGlish về MỘT nguồn sự thật TRƯỚC khi nhân bản (PRON-001).**
`lib/screens/tools/youglish/youglish_view.dart` (tên dự kiến) chứa toàn bộ:
builder URL, tạo controller, loading overlay, phân nhánh nền tảng
(`webview_flutter` / `webview_win_floating`), guard web. Ba chỗ gọi cũ
(`youglish_screen`, `youglish_mini_sheet`, điểm vào mới) chỉ còn là shell.
Kèm: `YouGlishScreen({String? initialWord})`; ngôn ngữ/accent đọc-ghi qua MỘT
store duy nhất (bỏ chip `.take(5)` và enum thiếu `vietnamese`/`hindi`/`thai`…
— mở theo ADR-0002, không tự chế danh sách mới). **PRON-001 không đổi hành vi**
đã quan sát được: golden test chốt URL byte-identical với
`_buildUrl()` hiện tại của cả hai file, và cả hai file cũ phải cho ra cùng URL.

**D6 — Web: bất biến "không import ngược".** `youglish_view.dart` giữ `dart:io`
⇒ cấm import vào các file reachable từ `lib/main_web.dart`. Nếu sau này cần
YouGlish trên web, làm wrapper `web/youglish_embed.html` theo tiền lệ
`web/yt_embed.html` + `url_launcher`, không dùng `webview_flutter`.

**D7 — i18n rule #5 là điều kiện nghiệm thu, không phải việc sau.** Chuỗi mới
vào ARB (đủ key parity 26 locale, `hi/zh/zh_TW/si` dịch ngay trong cùng PR);
xóa 3 chuỗi Việt hard-code đang vi phạm trong `youglish_mini_sheet.dart`
(`'Đang tải YouGlish...'`, `'Đã copy'`) và nhãn chỉ-tiếng-Anh
(`'American (US)'`…). KHÔNG chạy `generate_arbs.py`.

## Hệ quả

- **Chấp nhận đánh đổi:** điểm vào YouGlish trong luồng đọc phụ thuộc mạng và
  có thể bị YouGlish/YouTube chặn (captcha, thay đổi markup). Vì vậy mọi hàng
  "Phát âm" phải có đường lùi: lỗi/mạng chậm ⇒ tự hạ về audio từ điển → TTS,
  hiện một dòng nhẹ "Không mở được YouGlish — đã chuyển sang giọng máy", không
  dialog chặn.
- **Chất lượng hiển thị trên iOS/Windows/Linux chưa được chứng minh.** Bắt buộc
  nghiệm thu thiết bị cho: inline playback iOS — **không** bật được ở PRON-001:
  `setMediaPlaybackRequiresUserGesture` **không tồn tại** trên `WebViewController`
  của `webview_flutter` 4.14.1 (CI `app_analyze` bắt được 2026-10-24); khóa thật là
  tham số khởi tạo `WKWebViewParams.allowsInlineMediaPlayback` +
  `.mediaPlaybackRequiresUserGesture` (package `webview_flutter_wkwebview` 3.25.1,
  hiện chỉ là transitive ⇒ phải thêm vào `pubspec.yaml`), và nó **đổi hành vi iOS**
  của cả 2 điểm vào cũ ⇒ dời sang PRON-002 kèm nghiệm thu iPhone.
  Recipe đã ghi ngay trong comment ở `_initMobile()` của `youglish_view.dart`.
  Còn lại: size ≥200×200 px trong
  `DraggableScrollableSheet`, kéo không đơ, không ám đen. Build **Linux** vẫn đỏ
  sẵn vì `CI-LINUX-01` (thiếu `libwebkit2gtk-4.1-dev`) — không chặn Android/iOS/
  Windows nhưng đừng đổ lỗi cho PRON-001.
- **Nợ kỹ thuật giảm:** hết cảnh 3 bản copy YouGlish; audio từ điển offline
  (`DictEntry.audioPath`) có chỗ đứng trong thiết kế thay vì bị bỏ quên.
- **Việc chặn ngoài code:** mail xin phép YouGlish + sửa Điều khoản/Privacy là
  trách nhiệm người sở hữu; PRON-004 blocked cho tới khi có trả lời.
- `PLAN.md:472` ("YouGlish — Giữ, không làm lại") vẫn **đúng tinh thần**:
  PRON-001 là gom code, không viết UI YouGlish mới. Nếu PRON-003/004 muốn đổi
  hẳn sang widget chính thức thì phải ADR bổ sung.

## Loại bỏ (đã cân nhắc và bác)

| Phương án | Lý do bác |
|---|---|
| Tab YouGlish trong `word_actions_sheet` | sheet không có tab; dựng `TabBar` = hồi quy 1179 dòng cho một WebView |
| Preload video khi mở sheet tra từ | D3; đắt, spam request, dễ bị captcha, và chính nó là gián đoạn |
| Copy `youglish_mini_sheet` sang Read tab | bản duplicate thứ 4, không có nhánh Windows, lỗi URL nhân bản |
| Thêm Bloc/Provider layer cho state YouGlish | state chỉ là word+lang+accent trong một sheet; `ChangeNotifier`/`SharedPreferences` là đủ |
| Bỏ luôn YouGlish, chỉ TTS | mất đúng giá trị owner cần: nhiều giọng người thật trong ngữ cảnh |

## Cập nhật 2026-10-26 — PRON-002 đã code: ADR này sống đúng như thiết kế

Không cần ADR mới (quyết định kiến trúc không đổi; đây là bằng chứng thực thi).
Ghi lại 4 điều chỉ thấy khi code xong:

- **D1 thành hiện thực theo chiều ngược lại**: khi code, thứ cần tách khỏi
  YouGlish không phải UI mà là **chính sách chọn nguồn** — nó nằm ở
  `lib/features/word_lookup/pronunciation_source.dart`, THUẦN DART, và là cổng
  CI duy nhất (`4b4965f`: widget test + plugin treo >8 phút trên runner). Mọi
  surface chỉ còn gọi `WordPronunciationRow`.
- **D3 (một nút, lazy) có thêm một hệ quả không dự trước**: vì WebView chỉ dựng
  khi bấm, MỌI lỗi mạng đều nằm trên tay sheet ⇒ sheet phải tự chứa bậc thoái
  lui (watchdog `loadBudget` 8 s + banner 3 hành động + auto-TTS). Chọn banner
  thay vì auto-pop: pop sheet tự động giữa luồng đọc là một regression UX.
- **D4 (pause & restore) xác nhận `TextProvider` không có pause**:
  `speak()` đã giết đọc bài qua `_startExclusiveTtsSession`, `stopSpeaking()`
  xóa `currentLineIndex` ⇒ "pause" = capture index trước khi stop, restore bằng
  `speakAllLines(startIndex:)` (`PronunciationSession.wrapRead`). KHÔNG đụng
  `lib/ffi/` ✓. Segment/AB-loop: dừng nhưng không tự chạy lại.
- **Nợ PRON-001 đã trả**: `webview_flutter_wkwebview` thành direct dep và
  `allowsInlineMediaPlayback`/`mediaPlaybackRequiresUserGesture` đặt trong
  `WKWebViewParams.fromPlatformCreationParams` (KHÔNG có setter trên
  `WebViewController` — CI PRON-001 đã chứng minh). **Điều kiện nghiệm thu**:
  chỉ iPhone thật mới kết luận được video chạy nội tiếp hay không.
- Hệ quả cho PRON-005: `dictionary` có trong enum + policy nhưng
  `PronunciationAvailability.dictionaryHasAudio` luôn `false` cho tới khi nối
  `DictEntry.audioPath` (DICT-PACK-001 đã cho phép `wav/mp3/ogg/m4a` trong pack,
  `just_audio` đã là dep ⇒ việc nhỏ). ADR mới cho PRON tiếp theo: **0018**.
