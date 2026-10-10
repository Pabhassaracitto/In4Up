# I4U UX — Review Home Command Center

> Trạng thái: đạt định hướng tốt; cần giữ Home nhẹ và tránh biến thành dashboard.

## Đánh giá

Kết quả Prompt 6 phù hợp với quyết định UX:

- Home trả lời đúng ba câu hỏi: đang làm gì, nên làm gì tiếp, điều gì cần chú ý.
- Continue Learning là hành động chính rõ ràng.
- Có phân biệt desktop 2 cột và mobile 1 cột.
- Không dùng leaderboard/gamification nặng.
- Global Chat, Command Palette và Profile vẫn thuộc shell.
- Quick Capture có vị trí hợp lý.

## Điểm cần giữ

1. Chỉ một Primary Continue Card nổi bật nhất.
2. Needs Attention không được biến thành danh sách cảnh báo dài.
3. Next Actions nên có tối đa 3–4 hành động ưu tiên.
4. Recent Activity nên progressive disclosure, không cạnh tranh với Continue.
5. “Nhịp hiện diện” nên là tín hiệu nhẹ, không phải streak gây áp lực.

## Điểm cần kiểm chứng

- Trên mobile, thứ tự nên là Continue → Needs Attention → Next Actions → Recent/Presence; cần kiểm tra Quick Capture có bị chìm không.
- Nút “Tiếp tục đọc” và “Nghe tiếp” cần một primary action, một secondary action; không để hai nút ngang trọng lượng.
- “Bản ghi chú chưa kết thúc” nên mở đúng context cũ, không chỉ mở lại văn bản chung chung.
- Nội dung “18 thẻ đến hạn” nên cho phép bắt đầu nhanh nhưng không dùng badge đỏ/cảnh báo quá mạnh.
- Ảnh bìa chỉ dùng nếu có ý nghĩa; không để ảnh tạo thêm nhiễu thị giác cho command center.
- Không hard-code phím tắt `N` cho Quick Capture trước khi có shortcut registry.

## Khuyến nghị chuyển tiếp

Home đã đủ tốt để chuyển sang wireframe Đọc Minimal Reader. Không cần tiếp tục thêm card vào Home.
