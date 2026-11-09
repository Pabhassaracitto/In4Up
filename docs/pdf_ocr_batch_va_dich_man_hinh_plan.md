# Kế hoạch — PDF Batch OCR + Dịch màn hình (in-app) (PLAN-035)

> Nguồn: owner (2026-10-05, qua agent arena/01a10b7e-in4up).
> Liên quan: ADR-0009 (OCR ML Kit), ADR-0010 (dịch màn hình), KANBAN `PDF-OCR-002`,
> `XLAT-SCR-001` (in-app), `XLAT-SCR-002` (system-wide — giao agent khác qua
> `PROMPT_AGENT_DICH_MAN_HINH.md`).

## 0. Chẩn đoán (đọc code, không đoán)

- Nút "Quét chữ trang này" (`pdf_tts_bar.dart`) chỉ OCR **1 trang** (trang đang đọc)
  rồi mở preview → nạp vào TextProvider. Muốn cả sách scan thì phải bấm từng trang.
- Chế độ Text (`_ViewModeButton`, icon chữ T) với PDF scan: `extractFullText` trả
  rỗng → hiện "Không thể trích xuất text…" — ngõ cụt, không có lối OCR.
- Wordlist/Text Library đã có OCR camera + gallery + Document Scanner
  (`lib/features/ocr/` — ADR-0009, KANBAN OCR-001): `OcrService.recognizeBitmap`
  nhận pixels BGRA8888 thô, có cancel token + timeout từng trang. **Tái dùng,
  không thêm dependency, không xây pipeline OCR mới.**
- Dịch: `TranslationService` (cache → online engines → offline, glossary
  protect-tokens) + `TranslationMixin.translateAll` đã chạy trong Read Mode
  (TranslationToolbar). PDF Reader (chế độ xem trang) **chưa có** "dịch màn hình
  hiện tại" — chỉ có đường load toàn bộ text vào Read Mode rồi dịch ở đó.

## 1. Phạm vi

| Phần | Việc | Ai làm |
|---|---|---|
| A | PDF **Batch OCR**: chọn quét trang hiện tại / khoảng trang / toàn bộ | agent này (nội bộ) |
| B | **Dịch màn hình in-app** cho PDF Reader: nút "Dịch trang hiện tại" + panel song ngữ + nhánh OCR fallback cho trang scan | agent này (nội bộ) |
| C | **Dịch màn hình toàn hệ thống** (MediaProjection + overlay, Google Lens style) | agent khác — prompt `PROMPT_AGENT_DICH_MAN_HINH.md` |

Nguyên tắc chung (theo Gemini consultation của owner + đối chiếu code thực tế):
**in-app trước** (tận dụng 100% TranslationService/TranslationCache, UX mượt,
95% khả thi thuần Flutter); **system-wide sau** (cần native Android, rủi ro cao
hơn, tách lane riêng để không chặn phần trong app).

## 2. Thiết kế phần A — Batch OCR

### A1. Service thuần Dart `services/pdf_batch_ocr.dart` (test được trên host)

- `PdfOcrScope { currentPage, range, all }`.
- `resolvePdfOcrPages(...)` — suy ra danh sách trang 0-based từ lựa chọn user
  (clamp, hoán đổi from/to, dedupe, sắp xếp). Thuần logic.
- `runPdfBatchOcr({pages, recognize, hasTextLayer, skipPagesWithTextLayer,
  onProgress, cancelToken})`:
  - recognizer + text-probe là **callback tiêm vào** → test không cần pdfrx/ML Kit;
  - bỏ qua trang đã có lớp chữ (mặc định bật) — không đốt pin quét lại thứ đã có;
  - một trang fail **không giết cả lô** (khác `recognizeFiles` dừng sớm) — đếm
    ok/empty/failed/skipped, cộng dồn text các trang có chữ, join `\n\n` (cùng
    quy ước `recognizeFiles`);
  - cancel token dừng giữa chừng, kết quả đã quét vẫn được giữ.

### A2. UI `widgets/pdf_ocr_sheet.dart`

- Bottom sheet: chọn phạm vi (Trang hiện tại / Khoảng trang from→to / Toàn bộ),
  checkbox "Bỏ qua trang đã có lớp chữ", dòng tổng kết "Sẽ quét N trang" + ước
  lượng thời gian, cảnh báo tài liệu dài.
- Chạy: dialog tiến độ "Đang quét trang i/N" + nút Hủy (pattern `_OcrProgress`
  của OcrFlow: route handle tự gỡ đúng 1 lần, PopScope chặn back).
- Xong: `OcrFlow.presentResult` → preview/SỬA (bắt buộc theo ADR-0009 — không
  nạp thô) → `TextProvider.loadFromString(sourceType: ocr)` → kế thừa pipeline
  phân tích + Read Mode có nút Dịch sẵn.

### A3. Điểm vào (3 lối)

1. Nút quét trên thanh TTS (đang có, 1 trang) → giờ mở sheet, mặc định "Trang
   hiện tại" (nhanh như cũ nhưng lộ lựa chọn toàn bộ).
2. Menu ⋮ (PdfOptionsSheet): "Quét OCR (trang / toàn bộ)…" — hiện cả khi trang
   hiện tại CÓ chữ.
3. Chế độ Text với PDF scan (empty state): nút "Quét OCR tài liệu này" — mặc
   định "Toàn bộ".

## 3. Thiết kế phần B — Dịch màn hình (PDF Reader)

- Model `models/pdf_page_translation.dart`: `PdfPageSentenceTranslation`
  (original + translation + bounds câu).
- Service thuần `services/pdf_page_translate.dart`:
  `translatePdfPageCues` (cues đã có từ `extractSentences`) + translator tiêm
  vào + progress + dừng sau 5 lỗi liên tiếp (mirror `translateAll`);
  `splitOcrTextIntoUnits` — OCR text → đơn vị dịch (ngắt theo đoạn trống, cắt
  câu khi đoạn dài) cho nhánh trang scan.
- Controller: state `pageTranslations` (cache ~6 trang gần nhất, hit TranslationCache
  khi lật lại), `isTranslatingPage`, progress, error, panel visible;
  `translateCurrentPage()` — cues có lớp chữ, **fallback OCR 1 trang** khi
  không có (chỉ Android/iOS); lật trang khi panel đang mở → tự dịch trang mới.
- UI: nút icon `Icons.translate` trên toolbar (theo đề xuất Gemini) + panel
  `PdfPageTranslatePanel` ghép phía trên thanh TTS: từng câu gốc → bản dịch
  ngay dưới (stacked), thanh tiến độ, "Dịch lại", "Mở trong Read Mode"
  (dịch toàn bộ bằng translateAll đã có).
- Không vẽ overlay đè lên vị trí dòng gốc ở bản này (CustomPainter theo
  bounding box) — rủi ro cao khi không nghiệm thu được trên máy; ghi nhận là
  bước nâng cấp trong ADR-0010.

## 4. Test

- `test/pdf_reader/pdf_batch_ocr_test.dart`: resolve (3 scope + biên), runner
  (skip/cancel/fail giữa lô/join/progress), thuần Dart chạy host VM.
- `test/pdf_reader/pdf_page_translate_test.dart`: dịch theo cues (thành công,
  lỗi liên tiếp dừng sớm, progress), `splitOcrTextIntoUnits` (đoạn trống, đoạn
  dài cắt câu), thuần Dart.

## 5. i18n (rule vàng #5)

Mọi chuỗi chrome mới của PDF Reader đăng ký trong
`lib/core/language/priority_ui_overrides.dart` với đủ `en/hi/zh/zh_TW/si`
(không thêm key ARB mới → không cần gen-l10n trong sandbox, không đụng sàn
ratchet T2; `pdf_reader_i18n_coverage_test.dart` + `locale_chrome_no_vietnamese_test.dart`
phải xanh).

## 6. Phần C — system-wide (ngoại phạm vi agent này)

Xem `PROMPT_AGENT_DICH_MAN_HINH.md`: Android MediaProjection + SYSTEM_ALERT_WINDOW
+ foreground service giữ Flutter engine, capture → `recognizeBitmap` (BGRA) →
`TranslationService` → overlay native vẽ bản dịch theo bounding box của block
OCR. Desktop (Linux/Windows) để sau. Card KANBAN `XLAT-SCR-002` (proposed).
