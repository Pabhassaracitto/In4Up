# I4U UX — Review Không gian Nhớ

> Trạng thái: architecture baseline đạt; cần đặc tả state detail cho Review, Học thuộc, SRS và item management.

## Điểm mạnh

- Nhớ là workspace umbrella, không tạo tab Học thuộc cấp 1.
- Có Context Bar: Ôn tập, Học thuộc, Từ vựng, Bài tập, Thống kê.
- Dominant action là phiên ôn tập tiếp theo.
- Học thuộc có progressive retention flow.
- Context từ Đọc/Nghe/Xem/Hiểu được giữ trong card.
- Nhãn phản hồi không phụ thuộc Anki.
- Export Anki là integration tùy chọn.
- Desktop có list/detail; mobile ưu tiên one-hand.

## Điểm cần kiểm chứng

1. Cần state rõ cho session empty, due items, active review, answer feedback, pause/exit, completed và failed sync.
2. Không nên hiển thị 5 cấp độ Học thuộc cùng lúc; chỉ hiện chặng hiện tại và tiến trình nhẹ.
3. `Chưa nhớ/Khó khăn/Nhớ tốt/Thuần thục` cần map rõ với scheduling engine, không chỉ là nhãn visual.
4. Swipe actions trên mobile cần undo và confirmation cho Xóa.
5. Xóa khỏi Nhớ phải có undo/soft delete, tránh mất dữ liệu ngoài ý muốn.
6. Stats không được biến thành leaderboard hoặc score cạnh tranh.
7. Bài tập cần rõ khác biệt với Học thuộc và Ôn tập để tránh trùng chức năng.

## Kết luận

Prompt 12 đạt architecture baseline, cần prompt state detail trước khi code.
