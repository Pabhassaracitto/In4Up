# I4U UX — Review Google Stitch vòng 2

> Trạng thái: Global Shell đạt mức đủ tốt để chuyển sang wireframe Workspace; còn vài điểm cần kiểm chứng khi prototype tương tác.
> Cập nhật: 2026-10-04

## Kết luận

Prompt 5 đã giải quyết đúng các vấn đề chính của vòng 1:

- Quick Actions và Command Palette đã tách rõ.
- Nhãn lõi không còn phụ thuộc Anki.
- Sidebar giữ đúng 5 workspace.
- Reader có trạng thái tối giản thực sự.
- Contextual Tool Panel và Global Chat có vai trò riêng.
- Mini Player có sáu trạng thái rõ ràng.
- Shortcut được trung tính hóa, phù hợp nhiều nền tảng.

Global Shell có thể chuyển sang giai đoạn thiết kế Workspace. Không cần tiếp tục làm đẹp shell vô hạn trước khi kiểm tra nó trong Home/Đọc/Nghe.

## Những điều nên giữ

1. Quick Actions chỉ có 4–5 hành động theo context.
2. Command Palette là surface toàn cục riêng.
3. Sidebar mặc định chỉ có Home, Đọc, Nghe, Hiểu, Nhớ.
4. Reader mặc định ưu tiên văn bản và sự tập trung.
5. Tool panel dành cho công cụ có cấu trúc.
6. Chat dành cho hội thoại, giải thích và tạo nội dung.
7. Mini Player dùng cùng một state model xuyên workspace.
8. Không dùng shortcut cụ thể ngoài các hành vi an toàn như Cmd/Ctrl+K, Escape, Enter và phím mũi tên nếu chưa có registry.

## Điểm cần kiểm chứng trước khi code

### 1. Floating Pill trên mobile

Khoảng cách 68px tính từ đáy cần được đo theo safe area, chiều cao bottom navigation và bàn phím ảo. Không được giả định 68px luôn đủ trên mọi thiết bị.

Acceptance criteria:

- Không che bottom navigation.
- Không che nút hành động chính.
- Không bị keyboard che khi nhập Chat/ghi chú.
- Có vùng chạm đủ lớn dù pill hiển thị mỏng.

### 2. Collapsed player

Thanh 36px có thể quá nhỏ cho touch target. Có thể giữ chiều cao hiển thị 36px nhưng vùng hitbox nên lớn hơn, hoặc dùng floating chip có tối thiểu 44px vùng chạm.

### 3. Idle player

Cần quyết định player có hiển thị khi chưa có audio hay không. Khuyến nghị: không hiển thị player persistent ở trạng thái idle; chỉ hiển thị entry point nhỏ nếu có một nhiệm vụ audio gần đây hoặc người dùng chủ động mở.

### 4. Transcript state

Huy hiệu Transcript nên cho biết rõ hành vi: mở transcript, cuộn tới câu hiện tại, hay chỉ báo transcript có sẵn. Không nên dùng một icon không có label/tooltip ở các trạng thái quan trọng.

### 5. Tool panel và Chat

Giữ entry point khác nhau và không hiển thị hai panel cùng lúc mặc định. Nếu người dùng mở Chat trong khi Tool Panel đang mở, cần quy tắc: thay thế, split hoặc chuyển sang tab trong một surface.

### 6. Reader tối giản nhưng không mất affordance

Các điểm neo như từ tương tác, tiến độ và hành động lưu vào Nhớ phải vẫn dễ phát hiện. Tối giản không được biến thành “ẩn chức năng”.

## Quyết định chuyển giai đoạn

Bắt đầu wireframe Workspace theo thứ tự:

1. Home command center.
2. Đọc minimal reader.
3. Đọc contextual panel.
4. Nghe với audio library và mini player.
5. Xem trong Nghe.
6. Hiểu với Chat/Coach.
7. Nhớ với Ôn tập/Học thuộc.

## Chưa nâng phiên bản 2.0 ngay

Thiết kế đã đạt mức có thể được gọi nội bộ là “Adaptive Workspace Shell”, nhưng version public chỉ quyết định sau khi xác định breaking changes, migration và compatibility.
