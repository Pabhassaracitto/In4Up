# I4U UX — Review 14 state Home Command Center

> Trạng thái: đạt interaction baseline, cần chỉnh data integrity và ưu tiên hành động trước khi code.

## Điểm đạt

- First Launch không fake activity.
- Continue Card là dominant action.
- Next Actions giới hạn 3–4 mục.
- Needs Attention trung tính, không alarm-heavy.
- Stale source có recovery.
- Quick Capture có draft restore/undo.
- Recent Activity có context return.
- Responsive desktop two-column/mobile one-column.
- Mini Player có safe-area/padding-bottom.

## Điểm cần sửa

### 1. “18 ngày liên tiếp” dễ biến thành streak

Dùng `Nhịp học gần đây` hoặc `18 ngày có hoạt động trong 30 ngày qua`, tránh cụm `liên tiếp` nếu mục tiêu là chống áp lực streak.

### 2. Stale state phải khớp nguồn

Ví dụ thẻ đang đọc nhưng lỗi lại ghi `audio_lecture_04.mp3`. Recovery card phải hiển thị đúng source type, source ID và action tương ứng.

### 3. Offline sync không được auto-merge mù

State 11 đang nói tự động hợp nhất. Với notes, reviews và progress có xung đột, cần:

- merge an toàn theo event;
- conflict state;
- xem/giữ phiên bản;
- không làm mất dữ liệu âm thầm.

### 4. Quick Capture saved feedback

Không nên tự đóng quá nhanh nếu có hành động `Xem thẻ vừa tạo`. Giữ snackbar đủ lâu, có Undo và cho phép mở lại draft nếu cần.

### 5. Desktop Continue Card không nên có quá nhiều primary-looking actions

`Tiếp tục Đọc & Đối chiếu`, phát audio, AI Coach nên phân cấp rõ:

- Primary: tiếp tục workspace gần nhất.
- Secondary: audio.
- Tertiary/contextual: Hiểu với AI Coach.

### 6. Focus Rhythm cần là tín hiệu tùy chọn

Không hiển thị như KPI chính. Người dùng nên có thể ẩn hoặc xem ở Home/Profile.

## Kết luận

Home đủ tốt để đóng interaction baseline. Sau khi sửa stale source, offline conflict và action hierarchy, có thể chuyển sang UX freeze.
