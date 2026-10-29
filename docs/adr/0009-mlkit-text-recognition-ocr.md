# ADR-0009: Tích hợp ML Kit Text Recognition v2 (OCR) + Document Scanner làm nguồn văn bản mới

- **Ngày:** 2026-09-14 (cập nhật 2026-09-27 sau khi rebase lên `arena/01a0251e-in4up` @ 755b474)
- **Trạng thái:** ĐÃ TRIỂN KHAI TRONG CODE, chờ owner duyệt + CI + nghiệm thu thiết bị.
  Đã làm T1–T5 + T7–T8 (xem `docs/project/KANBAN.md` thẻ OCR-001); T6 (Document
  Scanner) và T9 (nghiệm thu 7 tiêu chí) cần máy Android/iOS thật. Chưa có bằng
  chứng CI vì code chưa lên GitHub.
- **Số ADR:** đổi 0005 → **0009** khi rebase — upstream đã dùng `0005` cho ba ADR
  khác nhau (`0005-ipa-display-and-save-source`, `0005-nhip-dieu-hoc-tap-su-kien-hoc-that`,
  `0005-rest-auth-firestore-linux`). Kèm theo đó PLAN-029 → **PLAN-033**.
- **Phạm vi:** Nguồn văn bản mới cho Text Studio / Read Mode (ảnh → text on-device)

## Bối cảnh

- App hiện extract text từ PDF/Web **bằng code** — chỉ chạy với PDF có text layer và
  HTML. Sách Pháp thoại scan, ảnh chụp trang sách, PDF image-only **không có đường**
  vào phân tích CEFR / tra từ / Text Studio.
- App đã tích hợp **ML Kit Translation** (`lib/features/translation/engines/mlkit_engine.dart`,
  package `google_mlkit_translation`). Team đã quen với pattern `google_mlkit_*`:
  Android/iOS only + `isAvailable()==false` trên desktop/web + model không tải lúc bootstrap.
- Core sản phẩm là Pháp thoại **Pāḷi**: ML Kit OCR không nhận diện Pāḷi như một *ngôn ngữ*,
  nhưng chữ Pāḷi Roman và tiếng Việt có dấu đều thuộc **Latin script** → OCR vẫn chạy tốt.
- Rule vàng AGENTS.md ràng buộc: (1) không tải model lúc bootstrap; (2) i18n nghiêm ngặt
  (en + hi/zh/zh_TW/si, không fallback về `vi`); (3) giữ khả năng reopen đúng vị trí nguồn.

## Quyết định

1. **Tích hợp ML Kit Text Recognition v2 (script Latin)** làm nguồn văn bản mới, bên cạnh
   `manual / localFile / cloud / generated` (enum `TextSourceType`).
2. **Document Scanner** là companion **tùy chọn** (chỉ Android, qua Google Play services):
   crop + sửa phối cảnh trang sách trước khi OCR, cho ra ảnh sạch. iOS không hỗ trợ
   Document Scanner → trên iOS chỉ có capture/gallery trực tiếp.
3. Thêm **`TextSourceType.ocr`**; lưu đường dẫn ảnh nguồn vào `localPath` qua
   `_setSourceMeta` để giữ evidence (rule 3 AGENTS). "Reopen nguồn" = mở lại ảnh gốc đã quét.
4. **Entry point:** nút "Quét ảnh → văn bản" đặt cạnh "Dán / nhập văn bản thủ công" trong
   `lib/screens/text_library_drawer.dart`. Sau OCR, nạp kết quả qua
   `TextProvider.loadFromString(content, title:, sourceType: TextSourceType.ocr, localPath: ảnh)`
   → kế thừa toàn bộ pipeline phân tích sẵn có (không xây pipeline mới).
5. **Android/iOS only:** desktop/web **ẩn nút** (`isAvailable()==false`), giống `mlkit_engine`.
   Không crash khi import (plugin là MethodChannel wrapper).
6. **Về model:** ML Kit OCR model ship kèm Google Play services (Android) / SDK (iOS) —
   **không cần "Tải về" thủ công**, do đó tự nhiên thỏa rule "không tải model lúc bootstrap".
   Khác với Translation (vốn cần tải model theo cặp ngôn ngữ).
7. **KHÔNG tích hợp các tính năng ML Kit còn lại** (Speech recognition GenAI, Summarization/
   Proofreading/Rewriting, Smart Reply, Image labeling/description, Barcode, Face/Face-mesh/
   Pose/Segmentation) — lý do đã nêu trong bảng đánh giá (đã có Whisper/Sherpa, Gemma LLM riêng,
   hoặc lệch hướng sản phẩm). Nếu sau này muốn, phải có **ADR riêng**.

## Hệ quả

- Thêm dependency: `google_mlkit_text_recognition`, `google_mlkit_document_scanner`
  (Android-only), và `camera` (hoặc dùng `image_picker` cho gallery). Android dùng
  Play services nên gần như **không tăng APK**; iOS bundle model → tăng kích thước IPA.
- OCR là **best-effort** (phông lạ, ảnh mờ → nhiễu): phải có **màn preview + ô sửa** trước
  khi nạp, KHÔNG nạp thẳng kết quả thô không kiểm soát.
- Mọi chuỗi chrome mới phải vào ARB **en + hi/zh/zh_TW/si (T2) cùng PR**, theo ADR-0002;
  không hard-code tiếng Việt ra `Text`.
- Provenance: thêm giá trị mới vào `TextSourceType` là thay đổi nhỏ nhưng phải đảm bảo
  các nhánh `switch`/`if` hiện có xử lý được giá trị mới (audit trước khi merge).

## Tiêu chí chấp nhận (DoD) — khi triển khai

- [ ] Android + iOS chạy OCR Latin (tiếng Việt có dấu + Pāḷi Roman) **không cần mạng**.
- [ ] Desktop/web: nút bị ẩn, import/analyze không crash.
- [ ] Kết quả nạp vào Text Studio với đủ CEFR + POS highlight như text thường.
- [ ] Reopen nguồn mở đúng ảnh gốc đã quét (không mất evidence).
- [ ] Không tải model lúc bootstrap / `main()`.
- [ ] i18n đủ 4 locale T2; `test/locale_chrome_no_vietnamese_test.dart` xanh.
