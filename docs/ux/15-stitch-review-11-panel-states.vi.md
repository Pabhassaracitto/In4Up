# I4U UX — Review đặc tả 11 trạng thái Contextual Tool Panel

> Trạng thái: đặc tả đủ chi tiết để làm interaction contract, sau khi sửa một số mâu thuẫn về mobile navigation, auto-dismiss và shortcut.
> Cập nhật: 2026-10-04

## Kết luận

Đặc tả 11 state đã chuyển Contextual Tool Panel từ ý tưởng visual thành một state model có thể bàn giao cho UX engineer/dev. Đặc biệt tốt ở:

- visibility rules;
- primary action theo tab;
- close gestures;
- reading/selection preservation;
- độc lập vùng cuộn;
- keyboard avoidance;
- khác biệt desktop/mobile;
- không biến panel thành chat thứ hai.

## Những điểm chốt giữ nguyên

1. Desktop Dictionary/Notes/SRS dùng right drawer 380px là điểm bắt đầu hợp lý.
2. Panel closed và panel pinned là hai behavior khác nhau.
3. Mobile có Peek → Expanded → Dismissed.
4. Chỉ tab active hiển thị nội dung chi tiết.
5. Reader và panel có vùng cuộn độc lập khi panel mở.
6. Context selection và scroll position phải được bảo toàn.
7. Notes phải xử lý keyboard inset.
8. SRS dùng nhãn trung lập `Nhớ`, không lấy Anki làm mental model.

## Các mâu thuẫn cần sửa trước khi code

### 1. Bottom Sheet không được phủ 5 tab chính

State 8 nói Bottom Sheet che/tích hợp thanh 5 tab, trong khi Global Shell đã chốt player/sheet không được che navigation. Cần chốt:

- Bottom navigation vẫn tồn tại và luôn có vùng chạm.
- Sheet dừng phía trên bottom navigation, hoặc navigation chuyển thành lớp điều khiển riêng được hệ thống dành safe-area.
- Không để sheet che icon/label của 5 workspace.

### 2. Mobile Peek Dock cần tránh chồng với Mini Player

State 7 có Peek Dock ở đáy; State 11 có Mini Player cách đáy 68px. Nếu cả hai xuất hiện, có nguy cơ ba lớp chồng nhau:

```text
Bottom Navigation
Mini Player
Peek Dock
```

Cần một quy tắc layer:

- khi Peek Dock mở, Mini Player thu gọn/ẩn hoặc chuyển vào sheet;
- chỉ một surface nổi chiếm vùng đáy tại một thời điểm;
- safe-area được tính động, không khóa 68px.

### 3. State 10 không nên tự đóng sau 3 giây

Auto-dismiss feedback chứa hành động `Quay lại bài đọc` có thể khiến người dùng mất cơ hội đọc hoặc hoàn tác. Khuyến nghị:

- hiển thị xác nhận ổn định;
- cho phép người dùng chủ động bấm `Quay lại bài đọc`;
- nếu dùng auto-dismiss, chỉ áp dụng cho toast nhỏ sau khi sheet đã đóng, không áp dụng cho sheet có primary action.

### 4. Shortcut cần neutralize

`⌥B` chưa phải shortcut đã được registry. Đặc tả nên ghi `Click hoặc mở từ Context Bar`; shortcut chỉ thêm sau khi có bảng shortcut chính thức.

### 5. Không đặc tả “biến mất khỏi DOM”

UX contract nên mô tả visibility, focus, layout và state preservation; không nên ép implementation phải xóa panel khỏi DOM. Web/mobile implementation có thể dùng overlay, offstage, portal hoặc giữ state trong tree.

### 6. Auto-update khi đổi selection trong pinned mode

Cần thêm confirmation nhẹ khi context thay đổi:

- panel cập nhật theo selection mới;
- nội dung Notes/SRS của context cũ không bị ghi đè;
- nếu người dùng đang nhập Notes, không tự đổi context mà không hỏi.

### 7. Close gesture và accessibility

Swipe, click outside và Escape cần có nút close rõ ràng tương đương. Click vào vùng văn bản để đóng không nên làm mất selection ngoài ý muốn.

## State contract tối thiểu để code sau này

```text
panelVisibility: closed | peek | expanded | pinned
activeTool: dictionary | notes | memory
contextAnchor: selectedText/word + source + location
readerPosition: stable anchor, not only pixel offset
scrollLock: none | readerLocked | panelIndependent
keyboardState: hidden | visible
saveFeedback: idle | saving | saved | failed
```

Không nên dùng một enum duy nhất để biểu diễn toàn bộ 11 state; các state có thể kết hợp, ví dụ `pinned + dictionary`, `expanded + keyboard`, `saved + return action`.

## Quyết định chuyển tiếp

Đặc tả 11 state đủ tốt để làm interaction baseline. Bước tiếp theo là kiểm tra Prompt 9 — Nghe với Audio Library, nhưng các correction về bottom nav, mini player và safe-area phải được giữ trong mọi workspace.
