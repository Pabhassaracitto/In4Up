# L11 — Backlog cũ + hàng đợi In Review (ngoài cổng beta)

**Đọc trước:** `README.md` (§ 2 commit, § 3 file, § 4 DoD).
**Nhánh:** từ `origin/arena/60e35d65-in4up`. **Không** sửa `KANBAN.md` / `BETA-1.29.0.md`.

> ⚠️ **Lane này KHÔNG thuộc cổng beta 1.29.0.** Nó tồn tại để backlog cũ có chủ, và để chủ dự án có thể nhắn một câu và kéo một nhúm vào cùng nhánh beta nếu rảnh. Hub chỉ land sau khi 10 lane trên xong.

## Mục tiêu

Dọn phần còn lại của project I4U: (a) **chốt 2 issue đang In Review** đã sửa xong, (b) phân loại các issue mở **ID ≤ PSRC-196** — mỗi cái phải được gán vào một lane khu vực (L1–L10) hoặc đóng với lý do.

## A. Hai issue đang In Review — chốt trước

| # | Trạng thái | Việc cần làm |
|---|---|---|
| **PSRC-14** | In Review | `READ-SELECT-002` (kéo chọn nhiều từ). Mô tả nói đã sửa, CI xanh (run `37529218138`). **Việc của agent:** kiểm lại trên nhánh beta, chạy lại test liên quan, nếu đúng ⇒ comment bằng chứng rồi chuyển **Done** |
| **PSRC-6** | In Review | `XLAT-MIX-001` (câu trộn ngôn ngữ). Như trên |

Không viết lại code nếu đã xanh — chỉ **xác minh + đóng**, hoặc mở lại nếu thấy hồi quy.

**Đính chính của agent L11 (2026-11-13):** run `37529218138` trong bảng trên là của
**PSRC-6** (`XLAT-MIX-001`, head `74af5d8`, nhánh `arena/78cea3c6-in4up`), không phải của
PSRC-14. Hai run của PSRC-14 (`READ-SELECT-002`) là `37653001863` và `37654112487`
(nhánh `arena/a106f0d6-in4up`) — lấy từ card KANBAN `READ-SELECT-002`.

### A.1 PSRC-14 — `READ-SELECT-002`: kết quả xác minh (2026-11-13, agent L11)

**Kết luận: ĐẠT ⇒ đã comment bằng chứng trên Linear và chuyển `Done`.**
Xác minh trên nhánh `arena/d0e2d365-in4up`, nền `962e7e1` (= tip `arena/60e35d65-in4up`).

| Mục | Bằng chứng đọc được trong mã |
|---|---|
| Luật chọn nhiều từ (thuần logic) | `lib/screens/read_mode/services/word_range_selection.dart` — `WordRange` (mỏ neo `anchorIndex` ↔ đầu kéo `focusIndex`), `resolveWordRange`, `buildWordSelectionText`, `wordIndexAtPoint`, `WordSelectionState`. Đầu file ghi đúng nguyên nhân gốc của audit 1.e: mỗi từ là một `GestureDetector`, không có `SelectableText` |
| Widget ô chữ vào chế độ chọn | `lib/screens/read_mode/widgets/colored_text_widget.dart` — giữ một từ ⇒ `WordSelectionState.activate(lineIndex)` (dòng 339); kéo/chạm từ thứ hai ⇒ `resolveWordRange` (dòng 326, 347) + `wordIndexAtPoint` (dòng 371); 4 nút trên thanh hành động gọi **một đường duy nhất** `ReadTextActionRunner.run(...)` (dòng 225–240); ghi selection thật bằng `TextProvider.selectTextWithOffsets(...)` (dòng 413–418); thoát chọn khi chạm ra ngoài/đổi dòng (dòng 78–97, 378–379) |
| Hướng dẫn thao tác cho người dùng | `lib/screens/read_mode/widgets/read_line_hint.dart:119` — "Giữ một từ ở chế độ ô chữ: vào chế độ chọn nhiều từ; nút Từ chi tiết mở bảng tra từ đầy đủ." |
| Máy bắt (test tự động) | `test/read_mode/word_range_selection_test.dart` — **18 test / 5 nhóm**: mỏ neo ↔ đầu kéo, chuỗi ghép + offset trong dòng, `wordIndexAtPoint` khi kéo quá mép, chọn thông minh kề vùng chọn, chạm ra ngoài thì bỏ chọn |
| Test đã nối CI | `.github/workflows/app_analyze.yml` bước **"Read actions + mixed-language tests (logic thuần)"** liệt kê `test/read_mode/word_range_selection_test.dart` (dòng ~916) |
| CI xanh | Nhánh cha: run **`43360617301`** (head `0ad2f2f9`) — step "Read actions + mixed-language tests" = `success`, "Analyze full app (chỉ ERROR là fatal)" = `success`, "Rule 5 test" = `success`. Tip nhánh cha `962e7e1` chỉ **hơn** `0ad2f2f9` 3 commit tài liệu (`gh api …/compare/0ad2f2f9...962e7e1` ⇒ `ahead_by 3, behind_by 0`) ⇒ code không trôi từ lần xanh đó. Run gốc của issue: `37653001863`, `37654112487` (đều `success`, xác minh lại qua GitHub API ngày 2026-11-13) |

**Chưa kiểm được trên máy thật:** sandbox của agent **không có Dart/Flutter SDK, không có
thiết bị/`adb`** ⇒ không tự chạy `flutter test` hay chạm–giữ–kéo thật được; test được chạy
lại bằng CI (xem run ở trên). Phần nghiệm thu chạm tay vẫn thuộc chủ dự án: giữ 1 từ → kéo
qua 4–5 từ → bấm **Dịch**/**Ngữ pháp** đúng cụm đó; thoát chọn rồi chạm 1 từ vẫn phát âm như
cũ; chế độ dòng (`SelectableText`) và interlinear không đổi hành vi. Nội dung này được ghi rõ
trong comment Linear, không giấu.

### A.2 PSRC-6 — `XLAT-MIX-001`: kết quả xác minh (2026-11-13, agent L11)

**Kết luận: ĐẠT ⇒ đã comment bằng chứng trên Linear và chuyển `Done`.**

| Mục | Bằng chứng đọc được trong mã |
|---|---|
| Bộ tách mẩu theo ngôn ngữ | `lib/features/translation/mixed_language_segmenter.dart` — `segmentByLanguage` + `containsForeignSegment` (dòng 160): chấm điểm từng mẩu theo dấu thanh tiếng Việt, từ chức năng tiếng Anh, chữ Hán/Kana |
| Nhánh dịch hỗn hợp | `lib/features/translation/translation_service.dart` — import segmenter (dòng 28), gọi `_translateMixedLanguage` (dòng 473), định nghĩa tại dòng 516: chỉ gửi đi dịch các mẩu **khác** ngôn ngữ đích rồi ghép lại đúng thứ tự |
| Nới guard "nguồn trùng đích" | `lib/features/translation/text_provider_translation.dart:251` dùng `containsForeignSegment` ⇒ hết cảnh cả ba tầng cùng từ chối im lặng |
| Máy bắt (test tự động) | `test/translation/mixed_language_test.dart` — **9 test** trong nhóm `segmentByLanguage`: câu tiếng Anh xen tiếng Việt được nhận ra (đúng bug 1.h), ghép lại ra đúng nguyên văn từng ký tự, đích là tiếng Anh thì câu tiếng Việt mới là ngoại ngữ, mẩu quá ngắn được gộp (không tự nhận ngoại ngữ), đoạn rỗng/trắng, nhiều câu Anh liền nhau gộp thành một mẩu, **tiếng Việt CÓ DẤU không bao giờ bị coi là ngoại ngữ** |
| Test đã nối CI | cùng bước **"Read actions + mixed-language tests (logic thuần)"** của `app_analyze.yml` (dòng ~925 liệt kê `test/translation/mixed_language_test.dart`) |
| CI xanh | Run gốc của issue **`37529218138`** — xác minh lại qua GitHub API ngày 2026-11-13: `conclusion: success`, head `74af5d8`, nhánh `arena/78cea3c6-in4up`, 2026-10-06. Trên nhánh cha hiện tại: run **`43360617301`** (`0ad2f2f9`) step read-actions/mixed-language = `success`, analyze = `success`; tip `962e7e1` chỉ hơn 3 commit tài liệu ⇒ không hồi quy |

**Giới hạn đã biết (giữ nguyên như mô tả issue, không "sửa" nhầm):** tiếng Việt viết
**không dấu** là nhập nhằng thật (`di`, `toi`…) nên một dòng không dấu có thể bị coi là
ngoại ngữ và dịch thừa; chấp nhận được vì **nguyên văn không bao giờ bị thay**. Test
khoá lại đúng kỳ vọng này.

**Chưa kiểm được trên máy thật:** mở một tài liệu Việt xen Anh trên thiết bị, đặt đích
tiếng Việt rồi bấm Dịch (cần engine dịch thật — mạng hoặc model Hy-MT đã tải). Sandbox
không có Dart/Flutter SDK lẫn mạng tới engine dịch ⇒ chỉ chứng minh được ở tầng logic
thuần + CI, đã ghi rõ trong comment Linear.

## B. Backlog cũ — bảng phân loại

Những issue dưới đây **đã biết** và được gán sẵn. Chúng **không** nằm trong đợt 1 của lane khu vực tương ứng; làm khi hub yêu cầu.

| # | Nội dung ngắn | Lane khu vực |
|---|---|---|
| PSRC-196 | ~~Live cabin: đồng bộ chọn tab~~ ⚠️ **nội dung ghi sai** — issue thật: "Tab Đọc: mặc định đọc toàn bài khi nhấn đọc" | ~~L1 — trùng PSRC-199~~ ⇒ **L3** (xem § D.1, **không** đóng duplicate) |
| PSRC-195 | Xuất file media kẹt "Estimating duration…" | L2 (đã đưa vào đợt 1 vì chặn 202/203) |
| PSRC-180 | Tạo lời lỗi FfmpegKit | L2 (đợt 1) |
| PSRC-179 | Đồng bộ khoảng lặng nút AB | L2 (đợt 1) |
| PSRC-194 | Icon dịch cabin hiện trên tab Nghe/Speaking | L4 |
| PSRC-193 | Tipitaka: chỉ mục con sai danh mục | L3 |
| PSRC-178 | Tên gọi "Lặp câu tiếp theo" | L3 |
| PSRC-174, PSRC-172 | Linux: quét thư viện không phản hồi | L5 |

> ⚠️ **Hai dòng trong bảng này cần đính chính** — xem **§ D.1** (PSRC-196 sai nội dung,
> PSRC-172 không còn ở state Backlog). Agent L11 không xoá dòng của hub, chỉ đánh dấu.

## C. Phần chưa đọc hết — việc của agent L11

Page JSON của Linear bị giới hạn kích thước nên ~15 issue còn lại (ID thấp hơn PSRC-172, trạng thái Backlog) **chưa được liệt kê ở trên**. Agent L11 làm:

1. Mở Linear, project **I4U**, state **Backlog**, sắp theo `createdAt` tăng dần, **đọc từng trang ≤ 12 issue** (trang lớn hơn sẽ bị cắt giữa).
2. Với mỗi issue: gán **một** lane khu vực L1–L10 (theo thư mục `lib/features/...` mà nó chạm), hoặc đề xuất **đóng** (trùng/không còn tái hiện/ngoài sản phẩm) kèm lý do.
3. Ghi kết quả vào **§ D** của chính file này (một commit tài liệu), không sửa issue nào khác ngoài comment phân loại.
4. Chỉ sửa code khi chủ dự án chỉ định issue cụ thể.

## D. Bảng phân loại do agent điền

**Agent L11 điền ngày 2026-11-13** (nhánh `arena/d0e2d365-in4up`, nền `962e7e1`).

### D.0 Cách đọc danh sách (chống sót, chống trùng)

Đọc Linear: team `PSRC` → project **I4U** → state **Backlog**, sắp `createdAt`,
**phân trang 4–6 issue/trang** (trang 12 issue bị cắt giữa thật — lần đọc đầu tiên mất
2 issue, phải đọc lại). Trang cuối trả `has_next_page: false` ⇒ danh sách dưới đây là
**đủ**. Toàn bộ issue Backlog của I4U tại thời điểm đọc:

| Nhóm | Issue | Đã ghi ở đâu |
|---|---|---|
| Cổng beta 1.29.0 (35 issue) | PSRC-199…233 | `README.md` § 7 + phiếu L1–L10 ⇒ **không lặp lại ở đây** (mỗi issue vẫn xuất hiện đúng một lần, trong bản đồ lane) |
| Backlog cũ đã gán sẵn | 196, 195, 194, 193, 180, 179, 178, 174 | **§ B** (196 và 172 cần đính chính — § D.1) |
| Backlog cũ chưa ai liệt kê | **166, 35, 29, 24, 20** | **§ D.2** (bảng dưới) |

§ C dự đoán "~15 issue ID thấp hơn PSRC-172 còn ở Backlog" — **thực tế chỉ có 5**. Lý do:
các issue con `PSRC-167…173` đã land trong bản **1.26.0** (card `REL-1.26.0` của
`KANBAN.md`), `PSRC-172` đã chuyển **In Review**, và phần lớn issue ID thấp đã ở trạng
thái khác (Done/Todo/Canceled) nên không lọt vào lọc `state = Backlog`.
`PSRC-197`, `PSRC-198` **không** ở state Backlog (không có trong danh sách).

### D.1 Đính chính hai dòng của § B

| # | § B ghi | Sự thật đọc từ Linear ngày 2026-11-13 | Đề xuất |
|---|---|---|---|
| **PSRC-196** | "Live cabin: đồng bộ chọn tab" — L1, trùng PSRC-199 ⇒ đóng as duplicate | Tiêu đề thật: **"Tab Đọc: mặc định đọc toàn bài khi nhấn đọc"**; mô tả: "Audit v1.27.0: Đảm bảo khi chọn nút đọc trong tab Đọc, hành vi mặc định là đọc toàn bộ bài." Không dính gì tới Live cabin. PSRC-199 là "Cho phép sửa và xoá nội dung Live cabin"; việc "đồng bộ Live cabin qua các tab đọc/nghe/hiểu" là **PSRC-201** (đã ở L1) | **L3** (chạm `lib/screens/read_mode/**` — hành vi nút Đọc). **Không** đóng duplicate: đóng theo § B sẽ mất một yêu cầu thật của tab Đọc |
| **PSRC-172** | Gộp với PSRC-174 thành "Linux: quét thư viện không phản hồi" — L5, đợt 2 | PSRC-172 hiện ở state **In Review**, không còn Backlog: "VieNeu-TTS: Nút Quét thư viện và Cấp quyền và quét không phản hồi (Linux)", started 2026-11-09. Fix đã land trong **1.26.0** (`REL-1.26.0` liệt kê "quyền quét thư viện" trong nhóm 7 fix PSRC-167…173) | Giữ lane **L5** cho **PSRC-174** (vẫn Backlog). PSRC-172 ⇒ **xác minh rồi chốt như PSRC-14/6**, đừng làm lại; L5 đọc phiếu L3 § 206 trước (cùng gốc "quét không phản hồi") |

### D.2 Bảng phân loại backlog cũ (ID ≤ 196, chưa có trong § B)

| # | Nội dung ngắn | Lane | Ghi chú |
|---|---|---|---|
| **PSRC-166** | VieNeu-TTS: cho nhập **tệp mẫu** để clone giọng + umbrella của 7 lỗi con 167…173 | **L6** (`lib/features/tts/**`, `packages/in4up_stt/lib/tts/**`) | **Đề xuất ĐÓNG (Done)** — không cần làm lại. Issue tự ghi "Đóng issue này sau khi các issue con đã được xử lý": (a) 7 issue con 167…173 đã land trong **1.26.0** (card `REL-1.26.0`, commit `8ae37adb`…`56c2d526`); (b) phần tính năng "nhập tệp mẫu" đã có trong mã: `lib/features/tts/widgets/voice_clone_section.dart`. Agent **không** tự đổi state (chỉ được comment phân loại) ⇒ hub/chủ dự án bấm đóng |
| **PSRC-35** | `READ-SET-VOICE-COLLAPSE-001` (P2): setting tab Đọc — danh sách giọng Microsoft (Edge) quá dài ⇒ hiện vài ngôn ngữ phổ biến + sổ ra | **L3** (phiếu L3 ghi rõ `lib/features/tts/**` *(chọn giọng)* trong "File chạm") | **Đề xuất ĐÓNG (Done)** — đã làm xong dưới **PSRC-18**. Bằng chứng trong mã: `lib/features/tts/widgets/tts_settings_section.dart:1060-1072` — `featuredOrder` lấy từ `EdgeTtsEngine.featuredLanguages` (8 ngôn ngữ tiêu biểu), phần còn lại vào `remainingOrder` và gập sau nút **"Xem thêm ngôn ngữ khác (N)"** (dòng 1181-1235); mỗi ngôn ngữ là một `ExpansionTile` (`_EdgeVoiceLanguageTile`, TTS-EDGE-VOICE-002). Máy bắt: `test/edge_tts_engine_test.dart` nhóm `EdgeTtsEngine — metadata & featuredLanguages` (dòng 78-99), đã nối CI (`app_analyze.yml:826`). Đúng tiêu chí nghiệm thu "hiện ngôn ngữ phổ biến + 'thêm' sổ ra". *Lỗ hổng rule #5 còn lại (nhãn ngôn ngữ viết tiếng Việt ở mọi locale trong cùng file) là việc khác, KANBAN đã ghi — đừng gộp vào issue này* |
| **PSRC-24** | `NETAWARE-001` (P1): ưu tiên local/online model theo mạng (Wi-Fi→online, 4G→offline) + user override | **— không lane khu vực nào** (cross-cutting `packages/in4up_ai/**`; L1–L10 không lane nào sở hữu routing AI) ⇒ **hub giữ** | **Đề xuất ĐÓNG (Done/xác minh)** — yêu cầu đã được triển khai dưới thẻ **YT-AUDIT-06 (IN4-104)**: `packages/in4up_ai/lib/src/engine/ai_connectivity_routing.dart` có `AiNetworkKind {wifi, mobile, none}`, `classifyConnectivity()`, `resolveRouteMode()` (chỉ `AiRouteMode.auto` bị đổi; 3 mode tĩnh đi qua **nguyên vẹn** = đúng "user vẫn được quyết định cuối"), `AiConnectivityRouter` bọc `connectivity_plus`. Máy bắt: `test/ai_connectivity_routing_test.dart` — 18 test, khớp đúng 2 tiêu chí nghiệm thu của issue (wifi ⇒ `onlineFirst`; mobile ⇒ `offlineFirst`; none ⇒ `offlineOnly` "tuyệt đối không sinh request remote"; override tôn trọng; `AiRoutingPrefs` mặc định `auto`). **Chưa kiểm máy thật:** đổi Wi-Fi↔4G trên thiết bị rồi xem engine đổi ưu tiên — cần chủ dự án |
| **PSRC-29** | `XLAT-OFFLINE-SYNC-001` (P2): "Chỉ dùng dịch offline" có mâu thuẫn với "Server & API cho AI" không ⇒ 1 nguồn sự thật duy nhất | **— không lane khu vực nào** (`lib/features/translation/**` + `packages/in4up_ai/**`; L4 ghi rõ **"Không đổi engine dịch"** nên không thể nhét vào L4) ⇒ **hub giữ**, là việc **ADR/kiến trúc**, không phải việc của lane beta | **Không đề xuất đóng — còn việc thật, nhưng nhỏ hơn mô tả.** Đọc mã thấy hai nút đã **ăn khớp** chứ không mâu thuẫn kiểu "bật offline mà vẫn gọi mạng": `_offlineOnly` (`translation_service.dart:146, 224-234, 252-257, 507, 523`) ngắn mạch **cả** tầng LLM API (`801`, `963`) lẫn engine online (`809`); chiều ngược lại tầng API cũng tự tắt khi "routing offlineOnly / mất mạng" (comment dòng 786) và `AiRouteMode.offlineOnly` có bất biến "tuyệt đối không sinh request remote" (`ai_connectivity_routing.dart:20`). **Việc còn lại:** vẫn tồn tại **hai** pref riêng (`translation_offline_only` và `AiRoutingPrefs`) ⇒ cần một ADR ngắn chốt nguồn sự thật + test khoá "đổi 1 chỗ ⇒ hiệu lực nhất quán" (đúng tiêu chí nghiệm thu của issue). Giao hub hoặc đợt 2, **không** thuộc cổng 1.29.0 |
| **PSRC-20** | `PDF-XLAT-MULTI-001` (P1): dịch PDF cố định EN→VN ⇒ chọn nguồn/đích, ≥26 ngôn ngữ | **L3** (PDF trong tab Đọc — cùng khu với PSRC-208/209/210 đã giao L3; L10 chỉ nhận phần phát/karaoke/cuộn/tốc độ và ghi rõ "không đổi bộ chọn engine/giọng (L3)") | **Còn việc, nhưng một nửa mô tả đã hết đúng.** Đọc mã: đường dịch trang PDF **không** hardcode EN→VN — `pdf_reader_controller.dart:1111-1119` gọi `service.translateText(text)` **không** truyền `sourceLang/targetLang` ⇒ dùng cặp ngôn ngữ đã cấu hình của `TranslationService` (`translateText` có tham số tuỳ chọn, `translation_service.dart:389-395`; đích mặc định lấy từ `targetLanguage`, dòng 179); `grep` toàn `lib/features/pdf_reader/` **không có** chuỗi `'en'`/`'vi'`/`sourceLang`/`targetLang` nào; danh sách `AppLanguage` hiện có **26** ngôn ngữ (`lib/core/language/app_language.dart`) ⇒ ngưỡng "≥26" của issue đã đạt ở tầng app. **Phần còn thiếu (đúng tiêu chí nghiệm thu):** trong UI PDF reader **chưa có** chỗ chọn nguồn/đích — `TranslationLanguagePickerButton` mới được gắn ở `read_settings_sheet.dart:485`, `translation_toolbar.dart:97`, `screen_translate_card.dart:525`, **không** có trong `lib/features/pdf_reader/widgets/`. Vậy việc của L3 đợt 2: đưa bộ chọn nguồn/đích vào PDF reader (tái dùng nút sẵn có) + test. ⚠️ `lib/features/pdf_reader/**` là **file chung của L3 và L10** ⇒ hub quyết thứ tự land |

**Không có issue Backlog nào của I4U bị bỏ sót và không issue nào xuất hiện hai lần.**
Agent L11 **không đổi state** của 5 issue ở § D.2 (phiếu § C chỉ cho phép *comment phân
loại* + *đề xuất* đóng) — chỉ PSRC-14 và PSRC-6 ở § A được chuyển `Done`.

## Nghiệm thu

- [x] PSRC-14 và PSRC-6: có comment bằng chứng + đóng, hoặc mở lại kèm lý do.
      → cả hai **ĐẠT**, đã chuyển `Done` ngày 2026-11-13; bằng chứng ở § A.1 và § A.2,
      phần chưa kiểm máy thật ghi rõ trong từng mục và trong comment Linear.
- [x] Mọi issue Backlog của I4U xuất hiện **đúng một lần** trong § B hoặc § D.
      → đủ danh sách ở § D.0 (đọc phân trang tới `has_next_page: false`); PSRC-199…233
      tính một lần trong bản đồ lane `README.md` § 7, không lặp lại ở § D.
- [x] Không issue nào bị đóng mà không có lý do viết ra.
      → L11 chỉ chuyển `Done` **PSRC-14** và **PSRC-6**, mỗi cái có comment bằng chứng
      trên Linear + § A.1/§ A.2. Bốn đề xuất đóng ở § D.2 (166, 35, 24 và một nửa 20)
      đều có lý do + đường dẫn file/dòng cụ thể, và **chưa** đổi state — để hub/chủ dự án bấm.
- [x] `app_analyze` xanh (nếu có sửa code).
      → lane này **không sửa một dòng code nào** (3 commit đều chỉ đụng file phiếu lane
      này) nên điều kiện "nếu có sửa code" không áp dụng. Chi tiết trung thực:
      `app_analyze.yml` lọc theo `paths` (`lib/**`, `test/**`, …) ⇒ push docs-only **không**
      kích hoạt nó trên nhánh L11; agent **không** tự kích hoạt được vì `gh workflow run`
      trả `HTTP 403 Resource not accessible by integration`. Bằng chứng test do đó lấy từ
      run **`43360617301`** trên nhánh cha (step "Read actions + mixed-language tests" =
      `success`, đọc kết luận từng step qua `gh api …/jobs`) + phép so sánh
      `compare/0ad2f2f9...962e7e1` = `ahead 3 / behind 0` (3 commit đều là tài liệu) ⇒ code
      ở đầu nhánh beta **giống hệt** code đã xanh. Run xanh **trên chính nhánh L11**:
      `deploy-web.yml` run **`43490960771`** (head `4996c7e1`) = `success` ⇒ toàn bộ mã Dart
      ở đầu nhánh build được (`flutter build web --release -t lib/main_web.dart`), không có
      hồi quy biên dịch. Xem thêm § Phát hiện thêm mục 9 về run này.
      Sandbox không có Dart/Flutter SDK nên **không** tự chạy `flutter analyze` /
      `flutter test` tại máy được.

## Commit

```
docs(PSRC-14): xác minh và đóng READ-SELECT-002 [L11]
docs(PSRC-6): xác minh và đóng XLAT-MIX-001 [L11]
docs(backlog): phân loại issue cũ vào lane khu vực [L11]
```

## Phát hiện thêm

Ghi ngày 2026-11-13 bởi agent lane **L11** (theo `README.md` § 5: phát hiện ngoài phạm vi
lane thì ghi vào đây + báo hub, **không** tự sửa file của lane khác).

1. **§ B của chính phiếu này ghi sai nội dung PSRC-196** (chi tiết + bằng chứng ở § D.1).
   Nếu làm theo § B, agent L1 sẽ đóng nhầm PSRC-196 as duplicate của PSRC-199 và **mất**
   yêu cầu thật "Tab Đọc: mặc định đọc toàn bài khi nhấn đọc". Đã comment đính chính ngay
   trên issue PSRC-196 để không ai đóng nhầm. Đề xuất hub sửa lại card KANBAN tương ứng.
2. **PSRC-172 không còn ở Backlog** (đang **In Review**, fix đã land trong 1.26.0) nhưng
   § B và phiếu `L5-linux.md` § "Đợt 2" vẫn liệt kê nó như việc phải làm ⇒ **L5 có nguy cơ
   làm lại việc đã xong**. Đã comment trên issue; đề xuất hub gạch PSRC-172 khỏi đợt 2 của
   L5 hoặc giao L5 *xác minh + chốt* như L11 làm với PSRC-14/6.
3. **Hai issue không có lane khu vực**: PSRC-24 (`NETAWARE-001`) và PSRC-29
   (`XLAT-OFFLINE-SYNC-001`) chạm `packages/in4up_ai/**` + `lib/features/translation/**`.
   Không lane L1–L10 nào sở hữu hai đường này (L4 ghi rõ "Không đổi engine dịch", L6 chỉ
   là VieNeu/Vieu-TTS). Đề xuất hub tự giữ hoặc mở lane "AI/routing" sau beta — cả hai đều
   **ngoài cổng 1.29.0**.
4. **Chồng lấn file giữa L3 và L10**: `lib/features/pdf_reader/**` xuất hiện trong "File
   chạm" của **cả hai** phiếu (L3: phần nạp/OCR; L10: toàn bộ). PSRC-20 (đề xuất L3) và
   PSRC-229/231/232 (L10) có thể đụng cùng `pdf_reader_controller.dart` /
   `widgets/pdf_toolbar.dart`. L11 không sửa code nên không gây xung đột, nhưng hub nên
   chốt thứ tự land L3 trước hay L10 trước ở khu vực này.
5. **PSRC-35 và PSRC-166 gần như chắc chắn đã xong** (bằng chứng file/dòng ở § D.2) ⇒ nếu
   hub muốn dọn nhanh backlog cũ, đây là hai issue "rẻ" nhất: chỉ cần xác minh + đóng,
   không cần code.
6. **Hạn chế môi trường của lane này** (nói rõ để hub không hiểu nhầm "CI xanh" trong báo
   cáo): sandbox **không có Dart/Flutter SDK, không có thiết bị/`adb`, không có mạng tới
   engine dịch** ⇒ không thể chạy `flutter analyze` / `flutter test` tại máy, và không thể
   nghiệm thu chạm tay/nghe thật. Mọi bằng chứng test trong § A.1, § A.2, § D.2 lấy từ
   (a) đọc mã + đếm test, (b) GitHub API (`gh api …/actions/runs/<id>` và `…/jobs` để đọc
   kết luận từng step — cách này **không** bị chặn như log/artifact), (c) run
   `workflow_dispatch` trên chính nhánh này.
7. **`KANBAN.md` là file của hub**: hai card `READ-SELECT-002` (dòng ~7726) và
   `XLAT-MIX-001` (dòng ~140) vẫn ghi "🔄 doing / chờ nghiệm thu máy" dù Linear đã
   `Done`. L11 không được sửa file đó ⇒ hub cập nhật sau khi land.
8. **PSRC-197 và PSRC-198 không ở state Backlog** (không lọt vào lọc `state = Backlog`
   của project I4U) — ghi lại để ai đối chiếu số hiệu khỏi tưởng danh sách § D.0 bị thiếu.
9. ⚠️ **`deploy-web.yml` PUBLISH bản beta lên GitHub Pages từ nhánh lane — hub nên bịt ngay.**
   `README.md` § 6 ghi "`deploy-web.yml` … build web (beta **không** publish)", nhưng cấu
   hình thật không làm vậy:
   - `on.push.branches` gồm `'arena/**'` và **không lọc `paths`** ⇒ push **chỉ tài liệu**
     vẫn build + publish. Danh sách loại trừ chỉ có `!arena/075510c6-in4up` và
     `!arena/60e35d65-in4up` (nhánh hub), cộng thêm `if:` ở job cho `arena/bf95d3ae-in4up`
     ⇒ **11 nhánh lane beta 1.29.0 không nằm trong bất kỳ ngoại lệ nào**.
   - Step cuối "Publish to gh-pages" `git push --force origin HEAD:gh-pages` ⇒ bản beta chưa
     nghiệm thu **đè lên site Pages đang chạy của chủ dự án**.
   - Bằng chứng hôm nay (2026-11-13): run **`43490659230`** (`arena/5b743370-in4up`) và run
     **`43490960771`** (`arena/d0e2d365-in4up` — chính lane L11, push 3 commit **docs-only**)
     đều `success` ⇒ đã publish; hàng loạt run lane khác `cancelled` vì
     `concurrency: github-pages, cancel-in-progress: true` ⇒ các lane đang **đua nhau** publish.
   - Agent L11 **không chặn được**: `gh run cancel` và `gh workflow run` đều trả
     `HTTP 403 Resource not accessible by integration` (token sandbox chỉ đọc Actions).
   - **Đề xuất hub:** thêm `'!arena/**-in4up'`-style guard cho đợt beta (hoặc một
     `if: github.ref == 'refs/heads/main'` ở step Publish), và/hoặc thêm `paths:` để
     docs-only không build web. Việc này **ngoài phạm vi L11** nên L11 không tự sửa
     `.github/workflows/` — file đó thuộc § 3 "hỏi hub trước".
