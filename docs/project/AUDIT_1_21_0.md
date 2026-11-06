# I4U — Audit v1.21.0 (8 mục) — báo cáo triển khai

- **Ngày:** 2026-11-06 (giờ owner Asia/Colombo) / 2026-11-05 UTC.
- **Nhánh:** `arena/4e91ed51-in4up` (base `d32fc1e`, lineage 251e, version `1.21.0+21`).
- **Phạm vi owner chọn:** `fix_all` — sửa code cả 8 mục + test thuần + cập nhật KANBAN/PLAN/docs.
- **Nguyên tắc:** KHÔNG tuyên bố "đã xong" với lỗi chỉ kiểm được trên máy thật. Mục #2/#7 **bắt buộc `adb logcat`**; #3 owner yêu cầu **AI có ngữ cảnh Cabin recheck**; commit `57ad5a7` chỉ "có vẻ đã xử lý".

> Tài liệu này là bản ghi TRUNG THỰC: cột "Đã làm" là thay đổi code/test trong
> repo; cột "CÒN LẠI" là nghiệm thu thiết bị / runtime chưa chạy. Sandbox không
> có Flutter/Dart SDK nên `flutter analyze` / `flutter test` được xác minh qua
> CI GitHub Actions (xem mục Cuối): **run 42135090013 🟢** — analyze 0 error,
> rule #5, toàn bộ suite cũ và 8 file test mới đều xanh.

## Bảng 8 mục

| # | Triệu chứng owner | Đã làm (code + test thuần) | CÒN LẠI (thiết bị / runtime) |
|---|---|---|---|
| 1 | `Bong bóng dịch nhiều khối, chữ chồng lên nhau` (history `XLAT-SCR-005` / PR #106) | `layoutTranslatedBlocks()` (Dart thuần) xếp/gộp/cắt khung + tính lại `textSizeSp`; `ScreenTranslateController.handleFrame()` gọi trước khi trả kết quả; native `TranslationOverlayView.kt` **không còn phình khung** (`boxHeight = maxOf` bị xoá), dùng `clipRect` + `StaticLayout` ellipsize `TextUtils.TruncateAt.END`. Test: `test/screen_translate/overlay_layout_audit_test.dart` + pin trong `test/audit_1_21_0_wiring_test.dart`. | Chụp màn hình thật với ≥3 khối dịch dài để xác nhận không còn chữ đè; `logcat` nếu vẫn lệch khung (native vẽ là device-only). |
| 2 | Tab Đọc: `ưu tiên TTS sherpa rồi bấm Đọc ⇒ văng app` | `PiperTtsEngine.isAvailable()`/`synthesize()` đi qua `assessOfflineModel()` (cùng cụm #7), chặn gọi native khi thiếu `.onnx`/`espeak-ng-data`; thêm marker `[TTS-NATIVE] selectVoice=…` ghi kích thước file để đối chiếu logcat. PR #128 đã chặn `MissingPluginException` ở `TtsNotificationService` — phần còn lại nằm ở native/model. Test: `test/services/offline_model_gate_test.dart` + pin. | **BẮT BUỘC `adb logcat`** trên máy thật: chạy đúng thứ tự ưu tiên TTS sherpa → bấm Đọc, lấy stack `SIGSEGV`/`SIGABRT`/`Fatal signal`. Code Dart KHÔNG catch được crash C++; chưa có log ⇒ chưa được phép gọi "đã fix". |
| 3 | Cabin: `đang dịch mà nói thêm ⇒ 2 dòng trùng` | `CabinFinalizationDeduper` (thuần, nhớ in-flight + cửa sổ 8s, normalize dấu câu/hoa thường) được nối vào `_onLiveSttResult` / `_flushActivePartialBeforeClose` / `_trackFinalization`; **xoá `Future.delayed(3s)`** vốn tắt cửa sổ chống trùng đúng lúc bản dịch còn bay; `whenComplete` gọi `finish(createdCaption:)` ⇒ chỉ nhớ 8s khi caption thật sự được tạo (recheck phát hiện nhánh `speaking` return sớm từng làm MẤT câu — xem mục Rà soát bổ sung). Test: `test/cabin/cabin_finalization_dedup_test.dart` + pin. | Owner yêu cầu **AI ngữ cảnh Cabin recheck**: chạy Cabin thật, nói thêm câu mới trong lúc dịch LLM/offline chậm >3s, so caption/LRC/journal không có 2 dòng trùng. Test thuần chỉ chứng minh logic, chưa thay thế nghiệm thu luồng STT thật. |
| 4 | Thư viện `«Gần đây»` ⇒ `PdfException ... FPDF_ER_FILE:2` | `inspectPdfForOpen()` (thuần `dart:io`) kiểm tra tồn tại / dung lượng / header `%PDF-` **trước** `PdfViewer.file`; nối vào `ReadLibraryScreen._openFile()` (nhánh `localPdf` trước đó KHÔNG có `existsSync()`, trong khi `localText` có), `QuickLibrarySheet` và `PdfReaderScreen.initState` (che mọi cửa vào); mục chết tự bị gỡ; `FPDF_ER_FILE:2` được đổi thành thông báo thân thiện. PR #129 sửa 6 lỗi PDF Reader nhưng **không chạm** `recent_files_service`/library. Test: `test/pdf_reader/pdf_open_preflight_test.dart` + pin. | Repro trên máy: xoá/cache-dọn một PDF trong «Gần đây» rồi bấm mở ⇒ phải hiện thông báo + gỡ mục, không màn đỏ. Quyền SAF trên Android 11+ cũng cần 1 lượt thử. |
| 5 | `Bấm từ vựng chỉ đọc` | `WordMiniPop` (đúng surface owner chọn: **pop trong tab Đọc**) có thêm 4 chip `Dễ / Vừa / Khó / Rất khó`; bấm chip ⇒ `TextProvider.markWordDifficulty()` + đồng bộ `VocabularyProvider.updateDifficulty()`, badge cập nhật tại chỗ. Dùng nhãn `Vừa` theo lời owner (core enum vẫn `Trung bình`). Test: pin `test/audit_1_21_0_wiring_test.dart`. Không mở rộng sang `WordlistBubble`/review/knowledge graph. | Bấm từ thật trong tab Đọc (cần bật `wordTapBoxes`): pop hiện, 4 chip bấm được, mức độ lưu lại khi mở lại văn bản. |
| 6 | `Bản dịch ra https://linux.do/t/topic/111737 dù có model / kẹt «Thử kết nối DeepLX»` | Xử lý **CẢ HAI** khả năng (owner nói "Tôi không biết"): (a) `isLinkOnlyText()` chặn URL thuần ở `TranslationService._translateTextInternal`, ở `_looksUntranslated` (engine trả nguyên link) và ở OCR screen-translate; (b) `assessDeepLXEndpoint()` từ chối link bài/forum (`/t/topic/...`), host nội dung (`linux.do`, GitHub…), scheme sai, URL rác; `DeepLXEngine`/`TranslationService`/`TranslationToolbar` dùng chung verdict ⇒ không POST lên HTML, không quay 20s, không lưu URL sai, `deeplxConfigError` nói rõ lý do, nút "Thử kết nối" luôn hạ cờ. `linux.do` **không có trong source** (đã grep) ⇒ đây là dữ liệu runtime, không phải literal. Test: `test/translation/translation_link_guard_test.dart`, `test/translation/deeplx_endpoint_audit_test.dart` + pin. | Chạy DeepLX server thật trong Termux/permux, dán **đúng endpoint** `http://127.0.0.1:1188/translate` ⇒ "Thử kết nối" xanh; dán link bài `linux.do` ⇒ báo lỗi ngay. Chưa có runtime này nên KHÔNG khẳng định nguyên nhân gốc duy nhất. |
| 7 | Offline Parakeet/sherpa chưa có model vẫn chọn được ⇒ crash khi `«Tạo lời thoại»` | Cùng cụm #2: `offline_model_gate.dart` kiểm tra kích thước thật 4 file ASR (`encoder/decoder/joiner/tokens`) thay vì chỉ >1KB của `SherpaModelManager._findAsrModelInDirSync()`; `_LrcModelSelector._sherpaLanguages()` + `_sherpaBlockMessage()` chặn chip/nút; `PlayerSttMixin._sherpaLrcPreflight()` chặn trước `pause()`/native; chip tự tắt khi model biến mất. Test: `test/services/offline_model_gate_test.dart` + pin. | **BẮT BUỘC `adb logcat`** với bản import model DỞ (cắt giữa file) và bản import đúng: xác nhận UI không cho chọn và không còn `SIGSEGV` ở `OfflineRecognizer`. PR #136 đã mở đường Parakeet đa ngữ; gate mới là preflight bổ sung, cần AT máy. |
| 8 | Tab Nghe: popup A-B bên ngoài thiếu chỉnh số lần lặp; `∞ ∞ 1× 3× 5× 7× … 20×` bị trùng | Root cause chính xác: `LoopPresets.dropdownValues = [-1, 0, 1, 3, 5, 7, 10, 15, 20]` + `labelFor(count <= 0) == '∞'` ⇒ **hai mục ∞ đứng đầu**. Sửa thành `[0, 1, 3, 5, 7, 10, 15, 20]`; `safeDropdownValue(-1) → 0` cho cài đặt cũ; `badgeModes` (lặp bài, chỉ 1 ∞) giữ nguyên. Thêm `LoopCountChips` ngay trong `_ABLoopWithSilencePanel` (popup A-B bên ngoài), dùng chung một nguồn `dropdownValues`. Test: `test/models/loop_presets_audit_test.dart` + pin. | Mở tab Nghe → giữ ô A-B → xác nhận dãy còn đúng **1** `∞` và chip chọn được số lần lặp; kiểm `player.setMaxLoopCount` thực sự đổi behaviour lặp. |

## Test thuần mới (chạy trên host VM, không cần thiết bị)

```
test/screen_translate/overlay_layout_audit_test.dart
test/cabin/cabin_finalization_dedup_test.dart
test/pdf_reader/pdf_open_preflight_test.dart
test/translation/translation_link_guard_test.dart
test/translation/deeplx_endpoint_audit_test.dart
test/services/offline_model_gate_test.dart
test/models/loop_presets_audit_test.dart
test/audit_1_21_0_wiring_test.dart   (source-scan pin cho native/provider/UI)
```

## i18n (quy tắc vàng #5)

- 10 chuỗi chrome mới (5 thông báo PDF + `Dễ / Vừa / Khó / Mức độ khó / Đã lưu mức độ khó`) được đăng ký ở `tool/legacy_ui_english_overrides.json`, `lib/core/language/generated_legacy_ui_fallbacks.dart` và `tool/priority_native_pack.json` → `lib/core/language/generated_priority_native_pack.dart` (đủ `en + zh, zh_TW, hi, si, my, th, ja`; `python3 tool/generate_priority_native_pack.py --check` ✅).
- `Rất khó`, `Lặp lại`, `Chưa có model nhận diện offline — …`, `Chưa có engine nhận diện …`, `Model không khớp profile …` đã có catalog ⇒ tái dùng, không thêm key.
- Thông báo lỗi tầng service dùng English canonical (`kLinkOnlyTranslationMessage`, `DeepLXEndpointVerdict.message`, `OfflineModelVerdict.technicalMessage`) ⇒ không hard-code tiếng Việt mới ở tầng không có `BuildContext`.
- **Baseline đã đỏ sẵn:** `python3 tool/generate_legacy_ui_fallbacks.py` trên `HEAD` gốc fail `814 unused overrides` + `231 unclassified accented literals` (đã kiểm bằng `git archive HEAD` ra `/tmp`); card `I18N-001` trên `origin/main` cũng ghi "KHÔNG chạy generator này (đang đỏ sẵn)". Vì vậy file generated được cập nhật **có chủ đích, chỉ thêm 10 key mới** (không regenerate toàn bộ 3981 key), và `generate_priority_native_pack.py` (generator còn xanh) được chạy đầy đủ.

## PR/lịch sử đã đối chiếu

| PR | Kết luận rút ra |
|---|---|
| #106 `XLAT-SCR-005` (MERGED 2026-10-24) | Đưa `mapCaptureRectToOverlay` + concurrency 3 + dedupe block; **không** xử lý nhiều khối phình khung ⇒ #1 là hồi quy còn lại. |
| #128 `M4U-IMPORT-002` (MERGED 2026-11-05) | Đã bắt `MissingPluginException` của `in4up/tts_notification`; crash #2 còn lại nằm ở native/model ⇒ vẫn cần logcat. |
| #129 PDF Reader (MERGED 2026-11-03) | Chỉ chạm `pdf_reader_screen.dart` / `pdf_tts_bar` / `pdf_word_tap_sheet` / `selection_save_sheet`; **không** chạm `recent_files_service` / library ⇒ #4 chưa được che. |
| #136 `M4U-IMPORT-003` (MERGED 2026-11-05 19:38 UTC) | Mở Parakeet đa ngữ + `getAsrModelPaths` fallback; `_LrcModelSelector` dùng `isAsrProfileInstalled` (chỉ >1KB/file) ⇒ #7 gate bổ sung. |
| `57ad5a7` (251e, CABIN-FLUSH-001) | `_flushActivePartialBeforeClose`, `_drainPendingFinalizations`, `_lastFinalizedText` + delayed 3s — đúng là "có vẻ đã xử lý", chưa chặn replay final khi dịch >3s ⇒ #3. |

## Rà soát bổ sung (2026-11-06) — 3 điểm từng để treo

| Điểm treo | Kết luận sau khi rà soát | Hành động |
|---|---|---|
| #6 `DeepLXEngine.isAvailable()` GET root có làm rơi `?token=`? | **Không.** `dart:core Uri.replace()` chỉ đổi phần được truyền; khi không truyền `query`/`queryParameters`, `sdk/lib/core/uri.dart` gán `query = this._query`. `_post()` cũng dùng `normalizeUrl()` đã giữ token (test `XLAT-DEEPLX-001` pin sẵn). | Thêm 2 test `MockClient` trong `test/translation/deeplx_endpoint_audit_test.dart`: GET root vẫn mang `token=abc`; link bài/forum trả `false` **mà không gọi mạng**. Không đổi code production. |
| #8 `LoopCountChips` gọi `setMaxLoopCount`, không phải `setLoopCount` (toggle `_repeatTrack`)? | **Đúng và cố ý.** Dropdown có sẵn trong `ab_loop_controls.dart` cũng gọi `setMaxLoopCount`; đổi riêng chip sẽ làm 2 control lệch trạng thái `repeatTrack` khi chưa có `loopStart`. | Giữ nguyên; thêm pin source-scan so sánh cả 2 nơi dùng chung setter. Hành vi track-repeat vẫn thuộc QA máy. |
| #3 deduper: câu bị `return` sớm có bị "nhớ" nhầm không? | **Có lỗi thật.** `_finalizeCurrentChunk` return ngay khi `_state == speaking` (hoặc text rỗng) ⇒ không caption nào, nhưng `whenComplete` vẫn `_deduper.complete(text)` ⇒ câu vào cửa sổ 8s ⇒ engine replay `isFinal` sau TTS bị nuốt ⇒ **mất câu** (ngược yêu cầu "tránh mất, thiếu"). | Thêm `CabinFinalizationOutcome` (cờ `createdCaption` bật ngay sau `_history.add`) + `CabinFinalizationDeduper.finish(createdCaption:)` → `complete()` chỉ khi caption thật sự được tạo, nếu không thì `cancel()`. Test thuần + pin `_deduper.complete(text)` không còn trong service. |

## CÒN LẠI (tóm tắt cho owner)

1. **`adb logcat` #2 + #7** — chưa có log thiết bị, không được gọi là đã fix.
2. **AI ngữ cảnh Cabin recheck #3** — recheck LUỒNG CODE xong (đã sửa lỗi mất câu ở nhánh `speaking`, xem bảng trên); luồng STT thật trên máy (>3s, dubbing bật, nói thêm giữa chừng) vẫn chưa chạy.
3. QA máy: #1 nhiều khối, #4 stale path, #5 pop 4 chip, #6 endpoint DeepLX thật trong Termux, #8 một `∞` + chip A-B.
4. ~~CI `app_analyze.yml`~~ ✅ **xong**: run [42135090013](https://github.com/Pabhassaracitto/In4Up/actions/runs/42135090013) 🟢 trên commit `1b0fce2` (run 42133600485 🟢 ở `67d1d3f` trước đó) — `Analyze full app (chỉ ERROR là fatal)`, rule #5, `test/screen_translate/`, `test/cabin/` và step mới `AUDIT-1.21.0 — 6 file pure test + source-scan wiring pins` đều xanh. Các run đỏ trung gian (3 lỗi / 4 run) đã sửa: 42130562066 (raw-string RegExp chứa `'`; `PiperTtsEngine` dùng `name` trước khai báo), 42131063345 (`$` anchor trong chuỗi thường; thiếu import `OverlayRect`), 42132184287 + 42132971120 (`inspectPdfForOpen` trả `missing` cho thư mục ⇒ sửa thành `unreadable`). `python3 tool/generate_priority_native_pack.py --check` ✅ 3516 entry; `git diff --check` ✅.
5. Recheck 3 điểm treo (xem mục **Rà soát bổ sung**) ✅ xong ở mức code + test thuần; chỉ còn nghiệm thu runtime/thiết bị ở các mục trên.
6. **Hợp nhất tip base trước khi mở PR:** `arena/01a0251e-in4up` đã lên `1.22.0+22` (`b2ee8a4`, 32 commit sau điểm tách `d32fc1e`) và đã dùng **PLAN-043** (Worklist đa ngữ) + **PLAN-044** (READ-UI-121) ⇒ đổi kế hoạch của đợt audit thành **PLAN-045** (chỉ đổi số, không đổi phạm vi). 4 xung đột append-only (`KANBAN.md`, `PLAN.md`, 2 JSON i18n) được giải quyết bằng **giữ cả hai**: card/section của base + card/section audit; catalog i18n = 3508/3973 key của base **+ 10 key mới** ⇒ 3518/3983 key, `generate_priority_native_pack.py --check` ✅ 3518.
