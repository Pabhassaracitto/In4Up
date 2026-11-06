# ADR-0025 — Gắn chế độ xem sáu kỹ năng mà không chuyển đổi lịch sử

- **Ngày:** 2026-11-06
- **Trạng thái:** đề xuất trên `arena/075510c6-in4up`; chờ CI, review độc lập và nghiệm thu thiết bị.
- **Phạm vi:** giao diện Venn và bộ đọc dữ liệu trực quan hóa, không phải hệ thống đánh giá sáu kỹ năng hoàn chỉnh.

## Bối cảnh

Nhánh `251e` có model/engine/painter sáu trục và các ADR 0015–0021 đề xuất,
nhưng chưa nối engine vào luồng ứng dụng, chưa có kho bền vững cho
`MasteryVector`/`ReviewEvent`, cũng chưa có đường ghi bằng chứng thực tế cho
Dùng, Nói, Viết. `WordEntry` đang là dữ liệu thật của người dùng; ba
`SkillReviewData` có điểm và lịch SM-2 riêng. Kéo Venn/slider có thể sửa điểm
trực tiếp mà không tạo review event. Chép điểm đó thành EMA, di chuyển lịch
sang kho mới, hoặc giả định output bằng 0 sẽ làm sai ý nghĩa dữ liệu.

## Quyết định

1. **Mặc định Venn ba kỹ năng.** Nút chuyển sang sáu kỹ năng và quay lại Venn;
   dùng cờ `hexagon_v1` trong Hive settings cục bộ, sắp thứ tự các lần ghi,
   báo nếu không lưu được. Cờ là lựa chọn giao diện trên thiết bị, không phải
   đồng bộ dữ liệu giữa các thiết bị. Venn, cử chỉ và Triangle cũ giữ nguyên.
2. Sáu kỹ năng có view từng từ (có tìm/chọn theo từ hoặc nghĩa) và view kho
   scatter. `VocabularyMasteryProjection` là bộ đọc **một chiều**, xây lại
   từ `VocabularyProvider` sau mỗi thay đổi, dùng đúng ba điểm đang lưu trong
   `WordEntry`. Venn/slider/review vẫn là nguồn sự thật; không gọi migrator,
   không ghi `LearningState` và không coi các điểm legacy là EMA.
3. Điểm non-zero legacy được hiển thị, kể cả giá trị do Venn đặt thủ công;
   zero có bằng chứng lịch sử (`totalReviews`, lịch/interval/repetitions) hiển
   thị 0%. Zero chưa có lịch sử hiển thị **chưa đánh giá**, vì schema cũ không
   phân biệt zero mặc định và zero do người dùng tự đặt. Không thay đổi schema
   hay suy đoán nguồn cho trường hợp mơ hồ này.
4. Không có nguồn output bền vững đang nối vào app ⇒ ba trục Dùng/Nói/Viết
   **chưa đánh giá**, UI nêu rõ chức năng đánh giá/lưu chưa được nối; scatter
   chỉ vẽ từ có cả input lẫn output và báo số bị thiếu dữ liệu. Adapter chỉ
   nhận output nếu caller thật cung cấp `MasteryVector` có cờ bằng chứng; điểm
   0 có cờ là 0%, không cờ là null; Dùng một sub-test được ghi «một phần».
5. `MasteryVector` có cờ input trong bộ nhớ để phân biệt review 0 với chưa
   review; giá trị nonzero của constructor cũ vẫn tương thích. Service thuần
   từ chối review Dùng không có subtype thay vì tự đoán inflection, không xóa
   `lastReviewEventId` khi chưa có ID event mới. Chúng **không tự lưu** event.
6. Diễn giải gap của từng cặp là **chênh lệch độ dài hai bán kính**
   `|input − output| × R`; bằng nhau ⇒ 0, thiếu một phía ⇒ không tính. Công
   thức khoảng cách giữa hai đỉnh đối diện trước đó cho 2R khi hai điểm đều 1,
   mâu thuẫn với ý nghĩa «chênh lệch» và đường chéo cân bằng của scatter.
   Chỉ vẽ tam giác khi đủ ba đỉnh; đỉnh thiếu là vòng rỗng nét đứt.

## Hệ quả và việc chưa làm

- Không sửa, gộp hay migrate lịch SM-2 Hiểu–Nghe–Đọc; không xóa hay ghi lại
  bản ghi từ. Các điểm thay đổi thủ công vẫn là điểm cũ, không phải bằng chứng
  một bài kiểm tra. Venn có sẵn hành vi đặt lại **cả ba điểm** khi chuyển vùng.
- Đánh giá/lưu/sync output, durable event log, replay, compaction, conflict đa
  thiết bị, đo hiệu chuẩn EMA, session bundler và retention chưa nối production.
  Muốn bật thực sự cần thiết kế lưu bền có version, event + metadata nguồn và
  subtype, ghi nhất quán/có thể phục hồi, sync idempotent, migration không mất
  dữ liệu, review độc lập và test restart/đa thiết bị. Không gọi scorers theo
  ngôn ngữ không hỗ trợ hoặc gán điểm từ hành vi ngầm.
- Có test phân biệt null với zero, output partial, SM-2 giữ nguyên, phản ánh
  Venn, chọn từ, toggle/flag, i18n và hai view. CI không thay thế nghiệm thu
  trên iPhone (đa chạm, kích thước/độ tương phản) hay thử loa TTS thật.
- Nhánh validation được loại khỏi trigger deploy Pages; không phải quyết định
  phát hành. Khi tích hợp sang nhánh khác phải xem lại workflow deploy.
