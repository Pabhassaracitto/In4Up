# I4U UX — Review 18 state Global Shell

> Trạng thái: đạt interaction baseline, nhưng cần sửa shortcut, panel stacking và metadata trước khi code.

## Điểm đạt

- 5 workspace được bảo toàn.
- Quick Actions, Command Palette và Global Chat tách rõ.
- Có focus trap, return focus, back/dismiss stack.
- Có safe-area formula thay vì offset cố định.
- Có mini-player transition và keyboard behavior.
- Có quy tắc shell responsive mobile/desktop.

## Điểm cần sửa

### 1. Shortcut đang xung đột browser/OS

Các phím sau chưa nên chốt:

- `⌘1–⌘5`: thường chuyển browser tab.
- `⌘[` : thường Back trên browser/macOS.
- `⌘K`: có thể mở search/omnibox tùy browser.
- `⌥B`, `⌥C`: cần kiểm tra bàn phím/ngôn ngữ và accessibility.
- Shortcut một ký tự trong Quick Actions không nên là core contract.

Cần có shortcut registry và scope theo focus. UX chỉ nên ghi hành vi fallback bằng click/tap.

### 2. Sidebar metadata bị mâu thuẫn

State 2 còn `Nhịp học tĩnh: 18 ngày liên tiếp`, trong khi đã chốt sidebar mặc định chỉ giữ 5 workspace. Chuyển metadata vào Home/Profile/expanded utility panel.

### 3. Mini Player + Quick Actions

State 14 cho phép ba tầng cùng hiện: Bottom Navigation, Quick Actions, Mini Player. Điều này mâu thuẫn với nguyên tắc một surface đáy nổi chính. Khuyến nghị khi Quick Actions mở thì Mini Player thu gọn/ẩn/tích hợp vào sheet; không dùng translateY(-118px) làm mặc định.

### 4. Context Panel và Chat

State 15 cho phép pin cả hai và chia đôi dọc. Đây chỉ nên là advanced experiment, không phải behavior mặc định. Baseline nên là Replace; nếu Split thì phải có width threshold, close controls và không làm reader quá hẹp.

### 5. Back stack không luôn quay Home

Nấc cuối nên tuân theo app/router history và xác nhận thoát khi có draft/session. Không ép mọi Back cuối cùng về Home nếu người dùng đang ở route ngoài hoặc mở app từ deep link.

### 6. Safe-area với keyboard

Không giả định keyboard làm `safeAreaInsetBottom = 0`. Layout nên đọc keyboard/viewInsets thực tế và dùng max của navigation inset/keyboard inset.

## Kết luận

Global Shell đủ tốt để đóng UX baseline sau các chỉnh sửa trên. Chưa nên code shortcut registry hoặc panel split trước khi chốt behavior.
