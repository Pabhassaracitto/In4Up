# I4U UX — Review Contextual Tool Panel

> Trạng thái: đạt baseline; cần yêu cầu Stitch mô tả/tạo từng state riêng thay vì chỉ tổng quan Desktop/Mobile.

## Đánh giá

Kết quả Prompt 8 phù hợp với kiến trúc đã chốt:

- Tool Panel phục vụ Reader, không thay thế Reader.
- Desktop dùng right panel; mobile dùng Bottom Sheet.
- Có đúng ba tool có cấu trúc: Từ điển, Ghi chú, Nhớ/SRS.
- Chat tự do được giữ ngoài Tool Panel.
- Context/selected word được giữ khi panel mở.
- Có pin/close trên desktop và drag/close trên mobile.

## Cần chỉnh hoặc kiểm tra

1. Không nên hiển thị quá nhiều nội dung preview của cả ba tab cùng lúc. Tab đang mở là nội dung chính; hai tab còn lại chỉ cần badge/trạng thái nhẹ.
2. Chiều cao Bottom Sheet 65% chỉ là điểm bắt đầu. Cần hỗ trợ trạng thái peek, expanded và full-screen khi nội dung dài.
3. Khi bàn phím mở trong Notes, sheet phải xử lý keyboard inset và không che ô nhập.
4. Cần phân biệt `Lưu thẻ` và `Thêm vào Nhớ` nếu hai hành động có behavior khác nhau; nếu không, dùng một nhãn thống nhất.
5. Pin panel chỉ phù hợp desktop/tablet; trên mobile nên là sheet state, không cần khái niệm pin cố định.
6. Cần mô tả rõ panel đang theo context nào khi người dùng đổi selection hoặc cuộn sang đoạn khác.

## Kết luận

Có thể chuyển tiếp, nhưng lần chạy Stitch tiếp theo nên yêu cầu tạo từng state riêng:

- Desktop — Dictionary open
- Desktop — Notes open
- Desktop — SRS open
- Desktop — panel pinned
- Desktop — panel closed/minimal
- Mobile — Dictionary peek
- Mobile — Dictionary expanded
- Mobile — Notes with keyboard
- Mobile — SRS review/save
- Mobile — close/return to Reader
