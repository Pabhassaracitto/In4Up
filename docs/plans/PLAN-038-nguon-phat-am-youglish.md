# PLAN-038 — Nguồn phát âm thống nhất + nối YouGlish vào luồng tra từ (PRON-001…004)

- Nguồn: người sở hữu (2026-10-24) — "chức năng nghe âm thanh từ vựng đang chọn,
  từ đã lưu"; bản gợi ý ban đầu từ Gemini (tích hợp YouGlish vào Tab Đọc).
- Trạng thái: **PRON-001 = code xong + CI 🟢** (run `40161328540`: analyze +
  Rule 5 + golden test PRON-001; `deploy-web` 🟢) → PR #107 vào
  `arena/01a0251e-in4up`; **còn nghiệm thu máy**. PRON-002/003/004 chưa code.
  Khung đã chốt với owner (2026-10-24): chính sách = WebView như hiện tại + xin
  phép song song + kill-switch; phạm vi = **mọi** nơi tra từ; kích hoạt =
  **một nút, lazy**; xung đột âm = **pause & restore**.
- Kiến trúc: `docs/adr/0015-nguon-phat-am-va-ban-tin-youglish.md` (bắt buộc đọc
  trước khi code — mục "Quyết định" D1…D7 và "Loại bỏ").
- Card: PRON-001 (gom), PRON-002 (tab Đọc), PRON-003 (các mặt còn lại + autoplay),
  PRON-004 (widget chính thức + pháp lý — blocked chờ owner).

## 0. Bảng điểm vào tra từ (kiểm chứng 2026-10-24)

| # | Bề mặt | Điểm vào thật | Nguồn phát âm hiện có |
|---|---|---|---|
| 1 | Tab Đọc — chạm 1 từ | `read_mode/widgets/text_line_widget.dart:614`, `read_mode/widgets/colored_text_widget.dart:242` → `read_mode/sheets/word_actions_sheet.dart` | TTS `tp.speak` (`word_actions_sheet.dart:282`) |
| 2 | Tab Đọc — pop gọn (giữ/kéo rèm) | `read_mode/widgets/word_mini_pop.dart` (key `wordMiniPopSpeakKey`) | TTS |
| 3 | Từ đã lưu — WordList | `tools/word_list/word_list_screen.dart:2102` | **ĐÃ có YouGlish** (`youglish_mini_sheet.dart`) + TTS |
| 4 | Từ đã lưu — Vườn nhớ | `memory_mode/sheets/word_detail_sheet.dart` (đã có tham số `onPlayAudio`) | callback phát audio từ ngoài |
| 5 | PDF Reader | `features/pdf_reader/widgets/pdf_wordlist_panel.dart:272` | TTS |
| 6 | YouTube (Language Reactor) | `features/youtube/widgets/yt_word_panel.dart` / `features/word_lookup/word_analysis_sheet.dart` | IPA/CMU, chưa có nút nghe |
| 7 | Sheet chi tiết từ điển (251e `b220b78`) | `features/dictionary/widgets/dict_entry_detail_sheet.dart` | `onSpeak` (VoidCallback?, `:30/:198`) — **chỗ cài hàng "Phát âm" có sẵn**, chưa nối nguồn nào |
| 8 | Web Reader chạm từ (**đã có từ base** `3f8197a`) | `features/web_reader/widgets/web_word_tap_sheet.dart` (697 dòng) | `controller.speakWord(cleanWord)` ở `:189` |

> **Đối chiếu lại sau rebase lên `3986433` (2026-10-24):** mọi nhận định trong
> bảng trên vẫn đúng. `word_actions_sheet.dart` vẫn 1179 dòng, vẫn **không** có
> `TabBar`/`DefaultTabController`, nút loa TTS tụt từ `:278` xuống **`:282`**;
> `text_line_widget.dart:614` và `colored_text_widget.dart:242` giữ nguyên;
> `word_list_screen.dart:2102` và `pdf_wordlist_panel.dart:272` giữ nguyên;
> 6 key `wordMiniPop*` còn nguyên. `lib/screens/tools/youglish/` và
> `word_list/youglish_mini_sheet.dart` **không** bị 12 commit của 251e chạm vào
> (`git diff --name-only` = 0 file) ⇒ PRON-001 không xung đột.
>
> **Đính chính i18n (sai ở bản đầu, đã sửa trong ADR D7):** `'Đang tải YouGlish...'`
> và `'Đã copy'` trong mini sheet **đã có** trong catalog shim
> (`generated_legacy_ui_fallbacks.dart:1352`/`:1392` +
> `tool/legacy_ui_english_overrides.json:1533`) ⇒ không vi phạm rule #5, PRON-001
> **không** phải sửa ARB.
> `DictEntry.audioPath`/`hasAudio` **vẫn không UI nào tiêu thụ** (dòng 40);
> nhưng đã có `onSpeak` ở điểm vào #7 → PRON-002/003 thay callback đơn đó bằng
> `WordPronunciationRow`, không tự chế nút loa thứ hai.

**Không có** `ReadScreen`; `word_detail_sheet.dart` **không thuộc** tab Đọc;
`word_actions_sheet.dart` **không có** `TabBar`/`DefaultTabController`.
`lib/widgets/word_detail_sheet.dart` là của map/venn/triangle — **ngoài phạm vi**
(trừ khi owner muốn; ghi rõ trong PRON-003 như tuỳ chọn rẻ vì dùng cùng widget).

## 1. PRON-001 — Gom YouGlish về một nguồn sự thật (không đổi hành vi)

1. Tạo `lib/screens/tools/youglish/youglish_view.dart`: `YouGlishView`
   (StatefulWidget) nhận `{word, language, accent, autoplay, height,
   onUnavailable}` + `YouGlishUrl.build(word, lang, accent, autoplay)` —
   **URL từng byte bằng** `_buildUrl()` hiện tại của `youglish_widget.dart`.
   Chuyển vào trong này: tạo `WebViewController`/`WinWebViewController`,
   `setJavaScriptMode`, loading overlay, `didUpdateWidget` (chỉ `loadRequest`,
   không tạo controller mới), `mounted` guard.
2. `youglish_widget.dart` còn lại là lớp mỏng gọi `YouGlishView` (giữ API cũ để
   không vỡ `youglish_screen.dart`). `word_list/youglish_mini_sheet.dart` bỏ
   `_ctrl`/`_buildUrl`/`_reload`/`_isLoading` riêng → dùng `YouGlishView` +
   `onWordChanged`; **giữ nguyên** header/reload/copy/chip nhưng sửa chip:
   bỏ `.take(5)` → cuộn theo `YouGlishLanguage.values`, accent lấy từ
   `YouGlishAccent`.
3. `youglish_screen.dart`: thêm `YouGlishScreen({String? initialWord})` — nếu có
   thì gán vào `_wordController` + `_currentWord` và bỏ qua "hello" mặc định.
4. State ngôn ngữ/accent một chỗ: `YouGlishPrefs` (`SharedPreferences`, key
   `youglish.lang`, `youglish.accent`, `youglish.enabled` — mẫu
   `features/cabin/services/cabin_session_settings.dart`). Cả 3 điểm vào đọc/ghi
   qua nó.
5. ~~iOS inline playback ở PRON-001~~ **đã thử, KHÔNG áp dụng được**: CI
   `app_analyze` báo `undefined_method` — `WebViewController` (webview_flutter
   4.14.1) không có `setMediaPlaybackRequiresUserGesture`; đúng là
   `WKWebViewParams.fromPlatformCreationParams(..)..allowsInlineMediaPlayback =
   true..mediaPlaybackRequiresUserGesture = false` (tham số **lúc tạo**, cần thêm
   `webview_flutter_wkwebview` vào pubspec). Đây là **đổi hành vi iOS của 2 điểm
   vào cũ** ⇒ chuyển sang PRON-002 §6; recipe nằm trong comment `_initMobile()`.
6. **Đính chính i18n:** hai chuỗi Việt trong mini sheet đã được catalog shim lo
   (`generated_legacy_ui_fallbacks.dart:1352`/`:1392`) ⇒ PRON-001 không đụng ARB.
6. ~~i18n PRON-001~~ — **đã kiểm và KHÔNG cần**: hai chuỗi Việt trong mini sheet
   đã nằm trong catalog shim (`generated_legacy_ui_fallbacks.dart:1352`/`:1392`)
   nên locale ≠ vi tự hiện English. PRON-001 chỉ đổi `Text('Đã copy')` →
   `Text(context.uiText('Đã copy'))` để rõ nguồn dịch, không đụng ARB.
   Toàn bộ việc i18n dồn sang PRON-002 (chuỗi mới của hàng "Phát âm").

**Nghiệm thu PRON-001:** hành vi nhìn thấy ở `YouGlishScreen` và hàng YouGlish
trong WordList **không đổi**; golden test `test/youglish/youglish_url_test.dart`
chốt 4 URL (EN+US / EN+UK / không-EN / có khoảng trắng & ký tự đặc biệt);
`grep -rn "youglish.com/pronounce" lib` trả về **đúng một** chỗ; `flutter analyze`
xanh; `test/locale_chrome_no_vietnamese_test.dart` xanh.

## 2. PRON-002 — Hàng "Phát âm" trong tab Đọc (lazy, một nút)

1. `lib/features/word_lookup/widgets/word_pronunciation_row.dart`:
   `[▶ chơi] [nguồn: TTS · Từ điển · YouGlish] [accent] [⧉ mở ngoài]`.
   - Mặc định nguồn = YouGlish **đã cấu hình sẵn** nếu `youglish.enabled` và
     máy có mạng; ngược lại TTS. Chơi = **không** tạo WebView nếu nguồn TTS/từ điển.
   - WebView **chỉ** được dựng khi người dùng bấm nguồn YouGlish (bật sheet con
     `YouGlishViewSheet`, một `StatefulWidget` có `YouGlishView`), dispose khi đóng.
   - Bậc thoái lui: load lỗi / quá 8 s chưa `onPageFinished` → tự đóng sheet con,
     phát bằng TTS + snack "Không mở được YouGlish — đã dùng giọng máy · Mở trình
     duyệt".
2. Cấy vào `word_actions_sheet.dart`: một dòng `WordPronunciationRow` đặt **dưới
   cụm nghĩa**, thay đúng chỗ nút loa đơn hiện tại (`:282`) để không có hai nút
   loa cạnh nhau. Giữ nguyên hành vi chạm loa = TTS ngay.
3. Cấy vào `word_mini_pop.dart`: giữ pop GỌN — chỉ **thêm một icon**
   `wordMiniPopYouGlishKey` (🎧 `record_voice_over`) bên cạnh `wordMiniPopSpeakKey`,
   mở thẳng sheet YouGlish. Không thêm section nào khác vào pop (đúng
   AUDIT-2026-10-20).
4. Pause/restore (D4): `WordPronunciationRow` gọi qua một helper đếm
   `_openPronunciationSheets`; khi về 0 → `resume` nếu trước đó đang phát.
   **Không** đụng `lib/ffi/`.
5. `main_shell.dart`: `_handleTool('youglish')` nhận `initialWord` để nút
   "Mở YouGlish" (khi WebView lỗi) điều hướng sang tool với đúng từ.
6. **iOS inline playback** (chuyển từ PRON-001): `webview_flutter_wkwebview` vào
   `pubspec.yaml` (`^3.25.1`) + `YouGlishView._initMobile()` dựng controller qua
   `WebViewController.fromPlatformCreationParams(WKWebViewParams(
   allowsInlineMediaPlayback: true, mediaPlaybackRequiresUserGesture: false))`
   — chỉ khi `WebViewPlatform.instance is WKWebViewPlatform`. Bắt buộc test trên
   iPhone thật (video phải hiện trong sheet, không fullscreen cưỡng bức).

**Nghiệm thu PRON-002:** widget test với WebView được inject qua factory giả —
chạm từ → sheet hiện `WordPronunciationRow` → **chưa** có WebView cho tới khi bấm
nguồn YouGlish (đếm số lần factory được gọi = 0 → 1); đổi nguồn không dựng lại
sheet; đóng sheet → playback tiếp tục đúng dòng cũ; QA máy: Android + iOS (inline
video), bật/tắt `youglish.enabled` → điểm vào biến mất, chỉ còn "Mở trình duyệt";
locale `hi` + `zh` → hàng "Phát âm" không còn chữ Việt.

## 3. PRON-003 — Các mặt còn lại + chính sách autoplay áp dụng toàn app

1. Cùng `WordPronunciationRow` cho: Vườn nhớ (`memory_mode/sheets/word_detail_sheet.dart`,
   cấy cạnh `onPlayAudio`), `pdf_wordlist_panel.dart`, `yt_word_panel.dart` +
   `word_analysis_sheet.dart`. WordList (`word_list_screen.dart:2102`) giữ nút
   riêng **hoặc** đổi sang row chung — chọn row chung để một giao diện, nhưng
   không bỏ 6 nút icon sẵn có trong dòng (giữ nguyên, chỉ đổi hành vi nút loa).
2. Đổi **có chủ đích** (không âm thầm): mặc định `autoplay = false` cho mọi điểm
   vào (thay cho `&autoplay=1` hiện tại) + `video quality` thấp qua widget ở
   PRON-004; lý do: chính sách autoplay của YouTube trong WebView không đáng tin
   và mỗi chạm-từ-một-request là rủi ro chặn. `YouGlishPrefs` lưu
   `youglish.autoplay` để owner bật lại nếu muốn; giữ bật cho tool
   `YouGlishScreen` (người dùng chủ động tìm từ) nếu owner muốn khác biệt.
3. (Tuỳ chọn rẻ) `lib/widgets/word_detail_sheet.dart` (map/venn/triangle) dùng
   cùng row — chỉ nếu không phát sinh phụ thuộc mới.

**Nghiệm thu PRON-003:** cùng một hàng "Phát âm" xuất hiện ở ≥5 bề mặt, code
gọi cùng một widget (`grep -rn "WordPronunciationRow" lib`); không còn chỗ nào
tự dựng `WebViewController` cho YouGlish ngoài `youglish_view.dart`; QA trên
`yt` panel không được làm hỏng Known/Learning (YT-LR-002).

## 4. PRON-004 — Widget chính thức + pháp lý (blocked chờ owner)

1. Owner gửi yêu cầu cấp quyền cho YouGlish (Developer Policy mục 5+6) —
   email/link form `youglish.com/api/contact`. **Chặn toàn bộ mục 2.**
2. Nếu được phép: `web/youglish_embed.html` theo tiền lệ `web/yt_embed.html`
   (hoặc `assets/html/` cho Android/iOS) nạp `public/emb/widget.js` với
   `data-query`, `data-lang`, `data-components`, accent, `quality=Low`,
   `Auto. start = No`, `Restricted Mode` theo cài đặt; WebView chỉ load wrapper
   đó → hết cảnh nạp cả site (menu/upsell/cookie banner).
3. Bắt buộc theo policy: dòng "powered by YouGlish.com" luôn thấy; player
   ≥200×200 px; Điều khoản app dẫn link YouTube ToS + Google Privacy Policy;
   consent cookie.
4. Nếu bị từ chối im lặng: bật `youglish.enabled=false` mặc định + xoá PRON-004,
   chỉ giữ "Mở trong trình duyệt".

## 5. Ràng buộc chung mọi PR

- Rule #5: key ARB mới → đủ **26** locale, `hi`/`zh`/`zh_TW`/`si` dịch trong
  cùng PR; chrome không được còn tiếng Việt ở locale khác `vi`.
- Không import `dart:io`-touching file vào cây reachable từ `lib/main_web.dart`
  (build web `deploy-web.yml` sẽ đỏ).
- Commit nhỏ, push ngay. CI: `app_analyze` phải xanh; `CI-LINUX-01` đỏ sẵn
  (thiếu `libwebkit2gtk-4.1-dev`) — không phải hồi quy của PRON.
- Không sửa `lib/ffi/`, không gộp 3 skill SM-2 (quy tắc vàng 1 & 2).
- Một ADR bổ sung nếu PRON-004 đổi hẳn cách nhúng (hiện ADR-0015 chốt WebView-nạp-trang).

## 6. Những gì đã loại (để người sau khỏi làm lại)

Tab YouGlish trong `word_actions_sheet` · preload video khi mở sheet tra từ ·
copy `youglish_mini_sheet` sang Read tab · Bloc layer cho state YouGlish ·
bỏ hẳn YouGlish chỉ để giữ TTS. Lý do chi tiết: ADR-0015, mục "Loại bỏ".
