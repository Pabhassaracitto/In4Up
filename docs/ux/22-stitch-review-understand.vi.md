# I4U UX — Review Không gian Hiểu

> Trạng thái: architecture baseline đạt; cần đặc tả state detail cho AI Coach, source handoff và failure/loading.

## Điểm mạnh

- Phân biệt rõ Global Chat và AI Coach.
- Hiểu luôn có source context, không phải chat screen trống.
- Có source đa phương thức từ Đọc, Nghe/Xem và text dán.
- Socratic flow có tiến trình.
- Có structured breakdown và cầu nối sang Nhớ.
- Desktop dùng Source Context + Coach; mobile dùng progressive disclosure.

## Điểm cần kiểm chứng

1. Cột AI Coach không nên luôn hiển thị quá nhiều module cùng lúc. Chỉ một task/coach step là primary.
2. Cần state rõ cho source missing, loading, AI unavailable, context stale và câu trả lời chưa đủ.
3. Socratic Coach phải cho phép người dùng bỏ qua, xin gợi ý, quay lại bước trước và kết thúc phiên.
4. Không dùng phần trăm tiến độ như đánh giá năng lực tuyệt đối; tiến độ là trạng thái phiên học.
5. Chat tự do và Coach cần entry point khác nhau, không mở hai panel hội thoại đồng thời.
6. Khi chuyển từ Xem/Đọc sang Hiểu, phải hiển thị source fingerprint và return path.
7. Mobile phải có cơ chế thu gọn source để dành chỗ cho câu hỏi/trả lời.

## Kết luận

Prompt 11 đạt architecture baseline, cần prompt state detail trước khi code.
