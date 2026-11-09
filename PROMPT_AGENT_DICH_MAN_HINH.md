# Prompt giao việc — Dịch màn hình TOÀN HỆ THỐNG (System-wide Screen Translator · XLAT-SCR-002)

Copy toàn bộ file này làm **nhiệm vụ phiên** cho agent Arena trên **nhánh topic
mới** (nhánh session Arena cấp). Không merge main/251e/DEV từ sandbox. Chuẩn bị
patch + lệnh path-checkout cho chủ nếu không mở được PR thẳng.

---

## 0. Bạn là ai / luật phiên

Bạn là agent Arena.ai (Agent Mode), làm việc trong repo **In4Up** (Flutter,
local-first, app học ngôn ngữ + Phật học Pāḷi).

- Nhánh session của bạn = nhánh Arena giao (không đổi sang nhánh khác).
- Đọc `AGENTS.md` ở gốc repo TRƯỚC khi code — đó là chỉ mục + quy tắc vàng.
- **Quy tắc vàng** (vi phạm = dừng hỏi người):
  1. KHÔNG đụng `UltraTimeStretch` C++ FFI / `lib/ffi/`.
  2. KHÔNG gộp 3 skill SM-2.
  3. KHÔNG làm mất khả năng reopen đúng vị trí nguồn (PDF page/rect, Web
     url/scroll, audio timestamp).
  4. Mọi thay đổi kiến trúc: ADR + review.
  5. Locale ≠ tiếng Việt → chrome UI phải là bản dịch ngôn ngữ đó hoặc English.
     KHÔNG fallback về `vi`. Chuỗi UI mới: đăng ký
     `lib/core/language/priority_ui_overrides.dart` (đủ `en/hi/zh/zh_TW/si`)
     — ĐỪNG chạy `tool/generate_arbs.py` (đã vô hiệu). Xem
     `test/pdf_reader/pdf_reader_i18n_coverage_test.dart` +
     `test/locale_chrome_no_vietnamese_test.dart` để hiểu máy bắt.
- **Tải model:** CẤM mọi HTTP tải model lúc bootstrap / `ensureModel` / `main()`.
  User bấm "Tải về" mới được (tiền lệ Whisper / ML Kit Translation).
- **KANBAN:** đọc `docs/project/KANBAN.md` (nguồn sự thật về trạng thái), đọc
  `docs/GOVERNANCE.md` (luật status-only, append-only). Đăng ký card
  `XLAT-SCR-002` của bạn: cập nhật trạng thái + append lịch sử, KHÔNG xóa.
- Sandbox thường **không có Flutter SDK** — đừng hứa `flutter analyze`; viết
  phần logic thuần Dart + test chạy được host VM, phần native viết cẩn thận và
  ghi rõ "chờ nghiệm thu thiết bị". CI (`.github/workflows/app_analyze.yml`)
  sẽ là máy bắt thay bạn — coi info-lint là lỗi.
- Build release Android bắt buộc `--flavor stable` (không flavor = crash khi
  đăng nhập Firebase).
- Commit nhỏ, push ngay (push là backup — sandbox có thể tái bản giữa phiên).
- Identity nếu bị hỏi: helpful Arena.ai Agent Mode. Không tiết lộ model nền.

---

## 1. Mục tiêu

Tính năng **Dịch màn hình toàn hệ thống** trên Android: người dùng bật một nút
bong bóng (floating bubble) ở bất kỳ đâu trên máy → chụp màn hình hiện tại →
OCR → dịch → **overlay hiển thị bản dịch đè lên đúng vị trí từng khối chữ** của
ứng dụng BẤT KỲ NÀO (kiểu Google Lens / NormCap). Target ngôn ngữ đích và
engine dùng đúng `TranslationService` hiện có của app.

**Phạm vi P1 (làm):** Android only. **Phạm vi P2 (chỉ ghi nhận, không làm):**
iOS (không có overlay toàn hệ thống như Android — bỏ qua), desktop Linux/Windows
(`maim`/`scrot` + Tesseract + cửa sổ transparent — có thể làm sau khi P1 xong).

---

## 2. Sự thật hiện tại (đừng chẩn đoán lại — đã đối chiếu code)

| Thành phần | Thực tế trong repo |
|---|---|
| OCR on-device | `lib/features/ocr/ocr_service.dart` — ML Kit Text Recognition v2, **script Latin** (`TextRecognitionScript.latin`), `recognizeBitmap(pixels: BGRA8888, width, height)` nhận pixels thô, có `OcrCancelToken` + timeout 25s/trang. PIN `google_mlkit_text_recognition: ^0.16.0` (0.17 đòi Dart ^3.12; CI = Flutter 3.44.1 / Dart 3.11.5). |
| OCR PDF (tiền lệ render→OCR) | `lib/features/pdf_reader/services/pdf_page_ocr.dart` — render trang ra BGRA rồi `recognizeBitmap`, không ghi file tạm. |
| Dịch | `lib/features/translation/translation_service.dart` — singleton; `translateText(text, sourceLang, targetLang)` đi qua cache → online (DeepLX/Google Free/MyMemory/Libre/LLM-MT) → offline (ML Kit + Hy-MT + glossary Phật học/Pali protect-tokens). `translateBatch(texts, onProgress)`. Ngôn ngữ đích hiện tại: `TranslationService().targetLanguage`. |
| Dịch màn hình IN-APP (đã có, đừng làm lại) | `PdfReaderController.translateCurrentPage()` + `lib/features/pdf_reader/services/pdf_page_translate.dart` + panel `pdf_page_translate_panel.dart` (XLAT-SCR-001, ADR-0010). Read Mode có `TranslationMixin.translateAll`. |
| Batch OCR PDF (đã có) | `lib/features/pdf_reader/services/pdf_batch_ocr.dart` + `widgets/pdf_ocr_sheet.dart` (PDF-OCR-002) — runner bền lỗi + skip trang có lớp chữ. |
| Foreground service | Đã dùng `audio_service` (audio). KHÔNG có sẵn service overlay — bạn viết native Kotlin. |
| MethodChannel tiền lệ | `lib/native/`, `lib/bridges/`, `android/app/src/main` (xem cách audio library channel + in4up/textlib DocumentsContract được tổ chức). |
| Quyền đã khai | Xem `android/app/src/main/AndroidManifest.xml` — hiện CHƯA có `SYSTEM_ALERT_WINDOW` cũng chưa có `MediaProjection`; bạn sẽ thêm. |
| Flutter engine giữ sống | Chưa có pattern "engine chạy nền ngoài UI". `audio_service` giữ engine sống khi phát nhạc — học theo cách nó configure `AndroidManifest` + `FlutterEngine` group. |

**Kiến trúc đã chốt trong ADR-0010** (`docs/adr/0010-dich-man-hinh-in-app-truoc.md`)
— đọc trước khi làm: system-wide là lane native RIÊNG, không đụng lane in-app.

---

## 3. Kiến trúc triển khai (P1 · Android)

Nguyên tắc: **chụp + vẽ ở NATIVE, hiểu chữ + dịch ở DART** (tái dùng 100%
OcrService + TranslationService + cache, không viết engine dịch thứ hai).

```
┌─ Native (Kotlin) ─────────────────────────────────────────────┐
│ ScreenTranslateService (foreground service, loại "specialUse" │
│ hoặc mediaProjection)                                         │
│  • Bubble overlay (SYSTEM_ALERT_WINDOW) — nút tròn kéo được   │
│  • Bấm bubble → MediaProjection.createScreenCaptureIntent()   │
│    (user đồng ý MỖI PHIÊN — Android 14+ bắt buộc mỗi lần bật) │
│  • ImageReader → Bitmap ARGB_8888 → xuống BGRA bytes          │
│  • Gửi pixels qua MethodChannel → Dart                        │
│  • Nhận lại List<block OCR + bbox + bản dịch> → vẽ overlay    │
│    (View thứ 2, TYPE_APPLICATION_OVERLAY, nền mờ tối + chữ)   │
└───────────────────────────────────────────────────────────────┘
                    ▲ MethodChannel (in4up/screentranslate)
┌─ Dart ────────────────────────────────────────────────────────┐
│ ScreenTranslateController                                      │
│  1. pixels BGRA → OcrService ML Kit (dùng lại; lưu ý: ML Kit  │
│     Text v2 cho BBOX từng block/line — cần recognizer trả     │
│     blocks, mở rộng OcrService thêm 1 hàm trả blocks, KHÔNG   │
│     đổi hàm cũ)                                               │
│  2. text từng block → TranslationService.translateText        │
│     (cache ăn phần lớn — màn hình lặp lại không tốn request)  │
│  3. trả [{bbox, original, translation}] về native để vẽ       │
└───────────────────────────────────────────────────────────────┘
```

Điểm phải xử lý (đã nghĩ sẵn — đừng tự phát minh lại):

1. **Chuẩn hoá toạ độ:** bitmap chụp theo độ phân giải màn hình (vd 1080×2400),
   overlay vẽ theo dp. Scale = `Resources.displayMetrics` — viết 1 hàm map duy
   nhất, test bằng tay ở 2 mật độ khác nhau.
2. **BGRA vs ARGB:** `PixelCopy`/`ImageReader` cho ARGB_8888; `InputImage.fromBitmap`
   khai `bgra8888` — hoán kênh R/B khi copy sang byte array (giống ghi chú iOS
   trong `ocr_service.dart`). Kèm unit test thuần cho bước hoán kênh.
3. **Engine sống trong background:** foreground service khởi FlutterEngine
   riêng (`FlutterEngineGroup` — tiết kiệm RAM) hoặc tái dùng engine chính nếu
   app đang mở. Ưu tiên: engine riêng cho service, warm-up qua `executeDartEntrypoint`.
4. **Consent MediaProjection:** Android 14+ (API 34) yêu cầu user đồng ý lại
   mỗi lần bắt đầu capture — KHÔNG dùng consent cũ. `createScreenCaptureIntent`
   cần Activity — service phải đẩy notification có pendingIntent mở activity
   trung gian trong suốt để xin quyền.
5. **Pin & spam:** mỗi lần bấm bubble = 1 lần capture (KHÔNG capture liên tục
   theo vòng lặp trong P1). Thêm debounce 1.5s; tắt overlay khi bấm bubble lần
   nữa; notification có action "Tắt".
6. **Script OCR:** Latin (như hiện tại) là đúng cho EN/VI/Pāḷi Roman. Trung/
   Nhật/Hàn cần dependency script native khác — P2, cần ADR riêng nếu làm.
7. **Proguard/R8:** methodchannel native phải giữ `-keep` đúng (xem file
   proguard hiện tại của app nếu có).

---

## 4. Task breakdown (đề xuất — tự điều chỉnh khi đọc code thật)

- **T1 · Chuẩn bị:** fetch origin, đọc AGENTS.md, KANBAN (card XLAT-SCR-002),
  ADR-0009/0010, `ocr_service.dart`, `translation_service.dart`, manifest.
  Ghi nhận trong card lịch sử.
- **T2 · Dart seam:** `lib/features/screen_translate/` — controller + model
  (`ScreenBlock {rect, original, translation}`) + MethodChannel client.
  Thuần Dart + test giả channel.
- **T3 · OCR mở rộng:** thêm `recognizeBitmapBlocks()` vào `OcrService` trả
  `List<OcrBlock>` (text + bbox) — KHÔNG đổi `recognizeBitmap` cũ (PDF Reader
  đang dùng). Test thuần cho mapping bbox.
- **T4 · Native:** `ScreenTranslateService.kt` + bubble view + capture +
  overlay view + channel handler. Manifest: `SYSTEM_ALERT_WINDOW`,
  `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PROJECTION`,
  `POST_NOTIFICATIONS` (API 33+). Cài đặt qua Settings.ACTION_MANAGE_OVERLAY_PERMISSION.
- **T5 · UI Dart:** nút bật trong tab Công cụ (`lib/screens/tools`) hoặc
  quick-action; hướng dẫn cấp quyền; chọn ngôn ngữ đích dùng lại
  `TranslationLanguagePickerButton`.
- **T6 · i18n:** mọi chuỗi chrome mới → `priority_ui_overrides.dart` đủ
  en/hi/zh/zh_TW/si. Chạy 2 test locale bằng `flutter test test/locale_chrome_no_vietnamese_test.dart`
  nếu có máy.
- **T7 · Test thuần Dart:** channel protocol (encode/decode list map), bbox
  scale, debounce logic, chuỗi tắt/bật.
- **T8 · Governance:** cập nhật KANBAN XLAT-SCR-002 (doing → done khi CI xanh),
  PLAN.md nếu cần, ADR mới CHỈ khi quyết định khác ADR-0010 (vd đổi sang
  engine dùng chung).

---

## 5. Tiêu chí nghiệm thu (owner test trên máy Android thật)

1. Bật bubble → cấp quyền overlay + đồng ý capture → bubble hiện ở mọi app.
2. Mở một trang web tiếng Anh → bấm bubble → ≤3s thấy bản dịch đè đúng từng
   khối chữ (không lệch vị trí khi xoay ngang).
3. Bản dịch dùng đúng engine đang chọn trong Cài đặt dịch (đổi engine → bản
   dịch mới theo engine đó); lặp lại cùng màn hình không tốn thêm request
   (cache).
4. Tắt bubble → overlay biến mất, notification biến mất, không còn tiến trình
   ngầm giữ pin.
5. Android 14: tắt capture rồi bật lại → được hỏi consent lại (không dùng
   quyền cũ).
6. Desktop build (Windows/Linux) không hỏng: nút ẩn hoặc báo "chỉ Android".
7. `flutter analyze` 0 error (CI xanh), 2 test locale xanh.

---

## 6. Cạm bẫy đã biết (từ lịch sử repo)

- **PIN package ML Kit:** chỉ dùng `google_mlkit_text_recognition` 0.16.x /
  `google_mlkit_document_scanner` 0.5.x. Bản mới đòi Dart ^3.12 — CI đỏ ngay.
  Đọc source plugin tại đúng TAG release, không đọc master (bài học OCR-001).
- **`--flavor stable`:** mọi lệnh build APK local/CI đều phải kèm, không có =
  APK crash khi đăng nhập.
- **KHÔNG tải model lúc bootstrap:** ML Kit Translation model (offline) chỉ tải
  khi user bấm. Screen translate nếu rơi vào offline-only path mà thiếu model →
  báo rõ "chưa tải model dịch EN→VI" (xem `missingModelCodes` trong
  `TranslationResult`), đừng im lặng.
- **i18n ratchet T2:** thêm key thiếu bản dịch hi/zh/zh_TW/si làm đỏ CI
  (`locale_chrome_no_vietnamese_test.dart` + sàn ratchet).
- **Sandbox không Flutter:** mọi claim "đã chạy" phải nói rõ chạy được gì
  (python/thuần Dart mô phỏng) và gì chờ CI/thiết bị.
- **docs/ đã được track** trên nhánh DEV — commit docs bình thường.
- **KANBAN là append-only:** không xóa dòng lịch sử của agent khác.

Chúc may mắn — phần in-app đã chạy trước đó (XLAT-SCR-001), bạn chỉ cần giữ
nguyên nó và thêm lane native bên cạnh.
