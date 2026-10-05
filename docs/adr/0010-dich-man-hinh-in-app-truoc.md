# ADR-0010: Dịch màn hình — in-app trước (text pipeline), system-wide sau (native lane riêng)

- **Ngày:** 2026-10-05
- **Trạng thái:** ĐÃ TRIỂN KHAI PHẦN IN-APP (XLAT-SCR-001); system-wide (XLAT-SCR-002)
  còn là `proposed` — chờ agent nhận theo `PROMPT_AGENT_DICH_MAN_HINH.md`.
- **Phạm vi:** Tính năng "Dịch màn hình" (Screen Translation) cho In4Up.
- **Nguồn:** owner (kèm tư vấn Gemini): 2 hướng — dịch nội dung BÊN TRONG app
  (in-app) và dịch TOÀN HỆ THỐNG (system-wide, kiểu Google Lens/NormCap).

## Bối cảnh

- App đã có toàn bộ hạ tầng dịch: `TranslationService` (cache → online engines →
  offline, glossary protect-tokens theo ADR/LXAT-001) + `TranslationMixin.translateAll`
  hiển thị stacked/side-by-side trong Read Mode.
- PDF Reader là MÀN HÌNH DUY NHẤT còn thiếu đường dịch nhanh: phải load toàn bộ
  text vào Read Mode rồi mới dịch được — mất ngữ cảnh trang đang đọc.
- Tư vấn Gemini (owner dẫn): in-app khả thi ~95% thuần Flutter, tận dụng 100%
  code cũ; system-wide cần native (MediaProjection + overlay), UX có thể chậm vì
  OCR ảnh.
- Ràng buộc repo: không tải model lúc bootstrap (rule vàng), i18n rule #5, không
  làm mất reopen nguồn (rule vàng #3), sandbox agent không có Flutter SDK —
  prefers code thuần Dart test được trên host VM.

## Quyết định

1. **In-app trước, theo TRANG, không phải theo overlay:** "Dịch màn hình" trong
   PDF Reader = dịch **trang hiện tại** (`extractSentences` → `translatePdfPageUnits`
   → panel song ngữ ghép trên thanh TTS). Lý do chọn panel thay vì CustomPainter
   vẽ đè từng dòng theo bounding box:
   - panel dùng 100% cơ chế hiển thị đã nghiệm thu (ListView + controller state),
     rủi ro thấp khi không test được trên máy thật từ sandbox;
   - overlay vẽ đè cần đối chiếu rect PDF ↔ viewport ở mọi mức zoom + nghiệm thu
     mắt — sai một hệ toạ độ là che sai chữ (vụ "chạm trúng đâu sáng đúng đó"
     từng mất 3 bản sửa, xem ADR-0003);
   - schema đã chừa `PdfPageSentenceTranslation.bounds` để nâng cấp overlay sau
     mà không phải migrate.
2. **Trang scan dùng OCR fallback trong cùng luồng dịch:** trang không có lớp chữ
   → `rasterizePdfPage` + `OcrService.recognizeBitmap` (ADR-0009, không thêm
   dependency) → `splitOcrTextIntoUnits` → dịch theo đoạn. Chỉ Android/iOS; nơi
   khác báo rõ "không có chữ để dịch".
3. **Cache theo trang (~6 trang gần nhất)** ở controller — lật qua lại không
   dịch lại; bên dưới vẫn có TranslationCache nên trang rơi khỏi cache cũng rẻ.
4. **Batch OCR PDF (PDF-OCR-002) là tiền đề của 1+2:** sheet chọn phạm vi
   (trang hiện tại / khoảng / toàn bộ) + runner bền lỗi (một trang fail không
   chết cả lô, cancel giữ phần đã quét) + skip trang đã có lớp chữ. Kết quả vẫn
   bắt buộc qua preview/SỬA của OcrFlow (ADR-0009) trước khi nạp.
5. **System-wide (dịch app KHÁC) tách lane native riêng (XLAT-SCR-002):**
   MediaProjection + SYSTEM_ALERT_WINDOW + foreground service giữ Flutter engine
   sống; capture → ML Kit OCR (BGRA như đường PDF) → TranslationService →
   overlay native vẽ bản dịch theo bounding box block. KHÔNG làm trong lane này
   vì: (a) cần native Kotlin + quyền hệ thống + nghiệm thu thiết bị thật; (b)
   không được chặn giá trị in-app đang dùng được ngay. Prompt bàn giao đầy đủ ở
   `PROMPT_AGENT_DICH_MAN_HINH.md`.
6. **Không dùng screenshot-to-OCR cho nội dung TRONG app** (tư vấn Gemini cũng
   xác nhận): text trong app luôn trích xuất được bằng code (PDF text layer /
   widget tree / OCR 1 lần cho trang scan) — chụp màn hình rồi OCR lại chính
   mình là tốn pin + sai chữ vô lý.

## Hệ quả

- **Dương:** PDF Reader có dịch nhanh theo trang ngay hôm nay, tận dụng trọn
  TranslationService + TranslationCache + glossary; scanned PDF có đường trọn
  bộ (batch OCR → Text Studio → translateAll); desktop không hỏng gì (OCR ẩn,
  dịch trang text-layer vẫn chạy).
- **Âm / trì hoãn:** overlay đè dòng gốc (đẹp như Google Lens trong app) còn
  nợ — cần nghiệm thu thiết bị; system-wide trọn vẹn phụ thuộc lane native.
- **Nguy cơ đã chốt cách xử:** chi phí dịch cả trang khi lật nhanh → chỉ tự
  dịch khi panel đang MỞ + cache 6 trang + TranslationCache; OCR batch dài →
  cancel token + progress từng trang + cảnh báo "nên quét thử khoảng nhỏ".
