# I4U UX — Review Google Stitch vòng 1

> Trạng thái: review dựa trên mô tả kết quả từ người dùng; cần đối chiếu thêm với ảnh/mockup thật trước khi chốt visual.
> Cập nhật: 2026-10-04

## Đánh giá tổng quan

Kết quả Stitch đã xác nhận tốt mô hình Global Shell:

- 5 workspace được giữ nhất quán trên mobile và desktop.
- Mobile dùng bottom navigation; desktop dùng collapsible sidebar.
- Quick Actions và Command Palette đã được phân biệt đúng vai trò.
- Chat là capability global, có context theo workspace.
- Xem đang được đặt trong Nghe thay vì tạo tab cấp 1.
- Reader có thể mở contextual panel mà không mất nội dung chính.
- Mini player là thành phần persistent xuyên workspace.

## Điểm mạnh

### 1. Hierarchy rõ

Các tầng Global Shell, Workspace, Context Bar và Tools đã xuất hiện tương đối rõ trong kết quả.

### 2. Progressive disclosure tốt

Trạng thái Minimal, Expanded Contextual Panel và Command Palette là ba mức mật độ hợp lý.

### 3. Đa nền tảng đúng hướng

Mobile không bị coi là desktop thu nhỏ. Desktop tận dụng sidebar, panel phải và keyboard navigation.

### 4. Contextual learning có giá trị

Các hành động như tra từ, dịch, giải thích, lưu vào Nhớ và tạo audio được gắn với nội dung đang chọn. Đây là hướng khác biệt quan trọng của I4U.

## Điểm cần chỉnh trước khi code

### 1. Không để Quick Actions chứa quá nhiều vai trò

Quick Actions hiện đang xuất hiện dưới nhiều dạng: bottom sheet, popover và có command search bên trong. Cần chốt một quy tắc:

- Mobile: bottom sheet ngắn, 4–5 hành động.
- Desktop: popover gần nút Quick Actions, 4–5 hành động.
- Command Palette: surface riêng, không nhúng toàn bộ command palette vào Quick Actions.

### 2. Không để “Thêm vào Anki” thành mặc định

I4U có thể hỗ trợ SRS/flashcard, nhưng nhãn Anki làm trải nghiệm phụ thuộc vào một sản phẩm bên ngoài. Nên dùng:

- `Thêm vào Nhớ`
- `Lưu vào bộ thẻ`
- hoặc `Lưu vào SRS`

Nếu có tích hợp Anki thật, Anki nên là đích export/integration trong settings hoặc flow export.

### 3. Sửa xung đột phím tắt

Kết quả Stitch đang có một số phím tắt không nhất quán:

- `⌘P` vừa được dùng cho Mở PDF, vừa cho Phát âm.
- `⌘O` có lúc là Mở tài liệu, có lúc là Mở PDF.
- `⌘D` thường có ý nghĩa trình duyệt/bookmark, không nên gán tùy tiện cho Tra từ.
- `⌘U` có thể xung đột với View Source trên trình duyệt.

Cần chốt một bảng shortcut riêng trước khi code. Trên web phải ưu tiên không phá shortcut tự nhiên của trình duyệt.

### 4. Không đưa quá nhiều metadata vào Global Shell

Course switcher, focus time và shortcut help trong sidebar có thể hữu ích, nhưng không nên mặc định chiếm không gian của navigation. Nên để dưới profile/workspace switcher hoặc hiển thị trong expanded state.

### 5. Kiểm soát mật độ Reader

Quote card, badge C1, progress, reading time, academic summary và interactive terms đều hữu ích, nhưng nếu cùng xuất hiện mặc định sẽ làm Reader thành dashboard. Cần một minimal reading state thật sạch.

### 6. Mini player cần có trạng thái rõ

Cần thiết kế và chốt các trạng thái:

- Không phát gì.
- Đang phát.
- Đang tải.
- Có transcript.
- Bị pause do chuyển workspace.
- Player mở rộng.
- Player bị thu gọn.

### 7. Contextual Chat cần tránh trùng với Context Panel

Dictionary/AI Coach panel và Global Chat có thể chồng lấn. Cần phân biệt:

- Context Panel: công cụ chuyên biệt, ví dụ từ điển, ghi chú, SRS.
- Chat: hội thoại, giải thích, tạo nội dung và hỏi đáp.

Không nên để cả hai cùng đưa ra sáu chip hành động giống nhau.

## Đề xuất quyết định tạm thời

- Giữ thứ tự `Home — Đọc — Nghe — Hiểu — Nhớ`.
- Giữ `Xem` trong `Nghe`.
- Giữ Chat là global contextual capability.
- Giữ Quick Actions và Command Palette là hai surface riêng.
- Dùng nhãn trung lập `Thêm vào Nhớ` thay cho `Thêm vào Anki` trong core UI.
- Chưa nâng major version chỉ vì mockup UI đẹp hơn; chỉ dùng 2.0.0 nếu triển khai gây breaking change về navigation/API/data migration hoặc thay đổi contract người dùng.

## Cần xác minh bằng ảnh/mockup thật

- Sidebar collapsed có đủ rõ khi chỉ có icon không.
- Bottom navigation và mini player có cạnh tranh chiều cao không.
- Context bar có bị quá nhiều hàng trên mobile không.
- Quick Actions popover có bị nhầm với Command Palette không.
- Context panel và Chat có khác nhau về visual hierarchy không.
