# Kế hoạch tích hợp ML Kit Text Recognition (OCR) — in4up

> Kèm ADR-0009 (`docs/adr/0009-mlkit-text-recognition-ocr.md`).
> Trạng thái: **ĐỀ XUẤT — chưa triển khai**. Đăng ký vào KANBAN trước khi bắt đầu.

## 1. Mục tiêu

Biến ảnh (chụp trang sách, ảnh scan, PDF image-only) thành văn bản có thể phân tích
được trong Text Studio / Read Mode — **offline, on-device**, kế thừa pipeline sẵn có.

Non-goal: không đụng `lib/ffi/` (UltraTimeStretch), không gộp skill SM-2, không đổi
kiến trúc translation.

## 2. Dependency — ĐÃ CHỐT version (đối chiếu pub.dev + source thật)

CI là **Flutter 3.44.1 / Dart 3.11.5** (`.github/workflows/app_analyze.yml`).

| Package | Pin | Vì sao bản này |
|---|---|---|
| `google_mlkit_text_recognition` | `^0.16.0` | 0.17.x đòi Dart **^3.12** → version solving fail. 0.16.0: Dart ≥3.8, Flutter ≥3.32, cần `google_mlkit_commons ^0.12.0` = **ĐÚNG bản `translation 0.14.0` đang kéo** → không xung đột. API 0.16 == 0.17 (đã đọc source). |
| `google_mlkit_document_scanner` | `^0.5.0` | 0.6.x đòi Dart **^3.12**. 0.5.0 **chỉ phụ thuộc `flutter`** (không dùng commons) → zero risk xung đột. Android-only, không cần quyền camera. |
| chọn ảnh | *(không thêm)* | Dùng `file_picker ^11.0.2` **sẵn có** — cùng API tĩnh `FilePicker.pickFiles(type: FileType.image)` mà `vocab_image_service.dart` đang dùng. iOS đi qua PHPicker nên **không cần** `NSPhotoLibraryUsageDescription`. |

Nền đã đúng sẵn, không phải sửa:
- iOS deployment target **15.5** (card CI-IOS-01 đã nâng đúng vì `google_mlkit_commons`)
  = đúng mức tối thiểu `text_recognition 0.16.0` đòi.
- Android `minSdk 24` ≥ 21 (ML Kit yêu cầu), `compileSdk 36` ≥ 35.
- `READ_MEDIA_IMAGES` đã có trong `AndroidManifest.xml`.

CI chạy `flutter pub get` thường (**không** `--enforce-lockfile`) → sửa
`pubspec.yaml` mà không cập nhật `pubspec.lock` vẫn resolve được.

## 3. Files — ĐÃ TẠO/SỬA

```
lib/features/ocr/
  ocr_service.dart        # TextRecognizer(latin) + Document Scanner + recognizeBitmap
                          # + normalizeOcrText (thuần tuý, test được)
  ocr_image_picker.dart   # seam bọc file_picker → test không cần plugin
  ocr_source_sheet.dart   # chọn nguồn: Scanner (Android) / ảnh có sẵn
  ocr_result_dialog.dart  # preview ảnh + ô SỬA ĐƯỢC trước khi nạp
  ocr_flow.dart           # điều phối; runOnImages / runOnBitmap / presentResult
lib/features/pdf_reader/
  services/pdf_page_ocr.dart   # rasterizePdfPage → pixels BGRA8888
  widgets/pdf_tts_bar.dart     # + nút scanner khi pageHasNoTextLayer
```

| File sửa | Thay đổi |
|---|---|
| `lib/providers/text_provider.dart` | +`TextSourceType.ocr`; `currentContextSourceRefType` trả `'ocrImage'` cho nguồn OCR |
| `lib/models/vocab_context.dart` | +case `'ocrImage'` (nhãn "Quét lại ảnh"), +case `'ocr'` (icon 📷) |
| `lib/widgets/unified_knowledge_sheet.dart` | +nhánh reopen `ocrImage` (quét lại ảnh thay vì loadTextFile) |
| `lib/screens/text_library_drawer.dart` | +nút "Quét ảnh" (ẩn khi `!isAvailable`) |
| `lib/l10n/app_*.arb` (26 file) | +14 key `ocr*`, dịch đủ 26 locale |
| `lib/core/language/generated_ui_translations.dart` | regenerate (890 source messages — trên nền `755b474`) |
| `test/ocr/ocr_service_test.dart`, `test/ocr/ocr_i18n_coverage_test.dart` | mới |

## 4. Luồng UX

1. User bấm **"Quét ảnh → văn bản"** trong text library drawer.
2. `OcrSourceSheet`: chọn **Camera** / **Gallery** / **Scanner** (Android only).
   - Trên desktop/web nút này không hiện (`isAvailable()==false`).
3. Lấy ảnh → (tùy chọn) Document Scanner crop/straighten → chạy
   `TextRecognizer(script: latin)`.
4. Kết quả đưa vào **`OcrResultDialog`**: preview ảnh + ô text **sửa được** (OCR best-effort).
5. Bấm "Nạp vào Đọc" → `TextProvider.loadFromString(content, title:, sourceType: ocr,
   localPath: ảnhGốc)` → pipeline CEFR/POS chạy như text thường.

## 5. Phân rã task — TRẠNG THÁI THẬT

> **Ghi chú về commit hash:** các commit của phiên 2026-09-15 (`c870bf2`,
> `26d77d6`, `ac29556`, `4c9e240`, `db1f082`) **không còn tồn tại** — sandbox bị
> re-clone nên git object mất, công việc chỉ sống sót dưới dạng file chưa commit.
> Toàn bộ phần OCR đã được **re-apply lên nền `origin/arena/01a0251e-in4up` @
> `755b474`** (nhanh hơn 48 commit) vào 2026-09-27. Vì vậy bảng dưới đây ghi
> trạng thái theo *code*, không ghi hash cũ — ai cần tra thì xem lịch sử thẻ
> OCR-001 trong `docs/project/KANBAN.md`.
>
> Hai hệ quả của lần rebase này, đã xử lý:
> - **ADR đổi số 0005 → 0009**, **PLAN-029 → PLAN-033** (upstream chiếm cả hai số;
>   riêng `0005` bị dùng cho ba ADR khác nhau).
> - **14 key ARB phải inject lại** vào bộ ARB mới (492 → 506 key/file) và
>   regenerate catalog; bản dịch 26 locale lấy lại được từ backup working tree nên
>   không phải dịch lại.

| # | Task | Trạng thái |
|---|---|---|
| 0 | ADR + đăng ký KANBAN/PLAN | ✅ code xong — ADR-0009, PLAN-033, thẻ OCR-001 |
| 1 | Dependency + `OcrService` | ✅ code xong |
| 2 | `OcrResultDialog` (preview + ô sửa) + `OcrSourceSheet` + `OcrFlow` | ✅ code xong |
| 3 | `TextSourceType.ocr` + nút drawer + nhánh reopen `ocrImage` | ✅ code xong |
| 4 | Chọn ảnh (`file_picker` sẵn có) + chạy `TextRecognizer` Latin | ✅ code xong |
| 5 | Document Scanner (Android) | ✅ code xong |
| 6 | iOS verify trên máy thật | ⬜ cần thiết bị |
| 7 | i18n 26 locale + 2 test | ✅ code xong |
| 8 | PDF Reader quét chữ trang scan | ✅ code xong |
| 9 | CI xanh + nghiệm thu theo 7 AT | ⬜ chờ push/owner |

Khác biệt so với plan gốc:
- **Không có `ocr_screen.dart` riêng** — gộp thành `ocr_result_dialog.dart`
  (dialog, khớp pattern `LocalTextEntryDialog` đang dùng) + `ocr_flow.dart`
  lo phần điều phối.
- **Không thêm `camera`/`image_picker`**: Document Scanner tự có UI camera
  (và không cần quyền camera), còn chọn ảnh dùng `file_picker` sẵn có →
  tổng cộng chỉ **2 dependency mới**, cả hai đều của ML Kit.
- **Thêm T8** (ngoài plan): PDF Reader là entry point giá trị nhất vì đó đúng
  là ngõ cụt hiện tại ("Trang này là ảnh, không có chữ để đọc").

## 6. i18n — 14 key ĐÃ thêm (không phải "gợi ý" nữa)

`ocrScanImage` · `ocrSheetTitle` · `ocrSourceScanner` · `ocrSourceScannerHint` ·
`ocrSourceGallery` · `ocrSourceGalleryHint` · `ocrResultTitle` · `ocrResultHint` ·
`ocrRecognizing` · `ocrEmptyResult` · `ocrLoadedFromImage` · `ocrScanPageText` ·
`ocrReopenImage` · `ocrUnsupported`

**Hai ràng buộc phát hiện được khi làm thật (plan gốc chưa biết):**

1. **Phải dịch đủ CẢ 24 locale rollout, không chỉ 4 locale T2.** Test
   `mọi locale ≥ sàn độ phủ` đo `số key ≠ English / tổng`. Sàn ratchet đang
   cực mỏng — `id` margin **0.0005**, `pt` **0.0013** → thêm key chỉ-có-English
   là **tụt sàn và đỏ test**. Dịch đủ thì margin *tăng* (`id` → 0.0208).
2. **Mọi locale phải có đúng cùng key set với `app_en.arb`** (26 file), test
   bắt cả "thiếu" lẫn "thừa".

**Bẫy trùng lặp:** `'Nạp vào Đọc'` **đã có** trong
`tool/legacy_ui_english_overrides.json` → nếu thêm key ARB `ocrLoadToRead` cùng
chuỗi đó thì `generate_legacy_ui_fallbacks.py` báo override kia *unused*
(36 → 37). Đã bỏ key trùng và tái dùng bản có sẵn. **Tra overrides/ARB trước
khi thêm key mới.**

Quy trình đã dùng:
```bash
# thêm key vào CẢ 26 file lib/l10n/app_*.arb (giữ format json indent=2 — round-trip identical)
python3 tool/generate_ui_translation_map.py     # ✅ chạy tốt
# KHÔNG chạy generate_arbs.py (đã vô hiệu — ghi đè mất catalog)
# KHÔNG chạy generate_legacy_ui_fallbacks.py: HỎNG SẴN ở baseline
#   (36 unused overrides — card I18N-001 đã ghi nhận); chỉ dùng để đối chiếu
#   rằng mình không làm con số đó tăng.
```

## 7. Test — ĐÃ VIẾT

`test/ocr/ocr_service_test.dart` (thuần tuý, chạy được trên host VM — không cần
thiết bị, không cần native):
- `normalizeOcrText`: chuẩn hoá `\r\n`/`\r`, cắt space thừa cuối dòng, gộp 3+
  dòng trống; **khoá hành vi cố ý** là KHÔNG nối dòng (kệ/câu Pāḷi ngắt dòng có
  nghĩa) và giữ nguyên dấu tiếng Việt + dấu Pāḷi Roman; idempotent.
- Guard nền tảng: trên host VM `platformSupported == false`,
  `documentScannerSupported == false`, `availableSources` không chứa scanner.
  Đây chính là cách kiểm chứng fallback desktop/web mà **không cần** Windows/Linux.
- `recognizeFile`/`recognizeFiles([])`/`scanDocumentPages` → failure có thông báo
  hoặc `UnsupportedError`, **không throw lung tung, không gọi native**.
- `OcrImagePicker.pick` seam: user hủy → rỗng; picker throw → service nuốt lỗi.
- Provenance: `VocabContext(sourceRefType: 'ocrImage').reopenActionLabel`
  == "Quét lại ảnh" (≠ "Mở vào Đọc") **và** nhãn đó phân giải được sang
  `Rescan image` — khoá luôn rule #5 cho nhãn mới.
- `OcrFlow.suggestTitleFor`: bỏ extension, đường dẫn Windows, cắt 48 ký tự.

`test/ocr/ocr_i18n_coverage_test.dart` (máy bắt rule #5 cho feature mới — cùng
cơ chế `test/pdf_reader/pdf_reader_i18n_coverage_test.dart`):
- Quét `lib/features/ocr` (trừ 2 file service/adapter, có ghi lý do miễn trừ):
  mọi literal tiếng Việt phải phân giải được sang English qua
  `AppUITranslations` — nếu không sẽ hiện nguyên tiếng Việt ở en/hi/zh/si.
- Khoá cứng **14 key × 26 file ARB**: ai xoá key mà quên sửa UI là test đỏ.
- Giá trị `vi` của từng key phải ra đúng `en` của ARB (chống lệch catalog).

Chưa có (cần thiết bị / cần `flutter`): widget test cho nút ẩn-hiện, và QA tay
7 AT trong card KANBAN OCR-001.

## 8. Rủi ro & giảm thiểu (cập nhật theo code thật)

| Rủi ro | Giảm thiểu — trạng thái |
|---|---|
| OCR nhiễu (phông lạ, ảnh mờ) | ✅ `OcrResultDialog` preview ảnh + ô sửa; `OcrFlow.presentResult` là **một cửa duy nhất** cho cả 2 đường (file ảnh / pixels PDF) nên không có nhánh nào nạp thô |
| Pāḷi không phải ngôn ngữ ML Kit hỗ trợ | ✅ Dùng `TextRecognitionScript.latin`; Pāḷi Roman là Latin → đọc được. KHÔNG bật script chinese/devanagari (cần thêm dependency native riêng, ngoài phạm vi ADR) |
| Enum thêm giá trị gây nhánh thiếu | ✅ Đã audit: **không có** `switch` exhaustive nào trên `TextSourceType`, và enum **không được persist** (state runtime, reset ở `clearText()`) → an toàn |
| **Reopen nguồn OCR bị hỏng** (rủi ro tìm ra khi audit, plan gốc không có) | ✅ `currentContextSourceRefType` trả `'ocrImage'` thay vì `'localText'`; nếu không thì reopen gọi `loadTextFile(JPEG)` → `readAsString()` throw → bấm nút không ăn gì. Đã thêm nhánh quét lại ảnh trong `unified_knowledge_sheet` |
| **Key ARB mới làm tụt sàn ratchet** | ✅ Dịch đủ 26 locale (xem mục 6) — margin tăng, không giảm |
| **Trùng chuỗi với catalog có sẵn** | ✅ Đã bỏ `ocrLoadToRead` vì `'Nạp vào Đọc'` có sẵn trong overrides |
| Pixels PDF đưa sang native sai stride → đọc tràn bộ nhớ | ✅ `recognizeBitmap` guard `pixels.length == w*h*4`; `rasterizePdfPage` trả null nếu `PdfPageRaster.isConsistent` false; copy pixels **trước** khi `image.dispose()` |
| Document Scanner chỉ Android | ✅ `documentScannerSupported` gate; iOS dùng chọn ảnh có sẵn |
| Không verify được bằng máy trong sandbox | ⚠️ còn mở — xem mục 10 |

## 9. Governance

- ADR `docs/adr/0009-mlkit-text-recognition-ocr.md` đang ở trạng thái
  **ĐỀ XUẤT** (owner duyệt miệng qua chat). Khi owner xác nhận bằng văn bản →
  đổi thành "ĐÃ DUYỆT" và append lịch sử, KHÔNG xóa.
- Card `OCR-001` trong `docs/project/KANBAN.md` = nguồn sự thật trạng thái.
- `PLAN-033` trong `docs/project/PLAN.md`. Milestone đề xuất M4 — owner xác nhận.

## 10. Việc còn lại (chuyển giao)

1. **CI là oracle thật**: sandbox của agent **không có `flutter`/`dart`** →
   chưa chạy được `pub get` / `analyze` / `test`. Push để
   `app_analyze.yml` chạy (workflow bắt `lib/**` + `pubspec.yaml` + `test/**`).
   Nếu đỏ: sửa theo log artifact `app-analyze-log`.
2. Đã bù rủi ro bằng cách **đối chiếu API trực tiếp từ source** của đúng bản
   đã pin: `TextRecognizer({script})`/`processImage`/`close`,
   `InputImage.fromFilePath`/`fromBitmap`, `DocumentScanner({required options})`
   /`scanDocument()`/`DocumentScanningResult.images`, và
   `MLKVisionImage+FlutterPlugin.m` (xác nhận **iOS có** xử lý type `bitmap`).
3. **Nghiệm thu trên máy** theo 7 AT trong card OCR-001 — đặc biệt AT 4
   (PDF scan → OCR → TTS đọc được) và AT 6 (desktop/web không hiện nút, không crash).
4. Nếu muốn reopen được cho văn bản OCR **từ PDF**: cần persist trang đã render
   thành file ảnh (encode PNG trong Dart) rồi dùng đường `localPath`. Cố ý
   CHƯA làm — hiện để `localPath = null` (degradation trung thực) thay vì thêm
   code encode ảnh không test được.
