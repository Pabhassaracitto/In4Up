# Responsive UI System

## Mục tiêu

Thiết lập cơ chế giảm rủi ro `RenderFlex overflow` / `pixel overflow` trên nhiều nền tảng:

- Android / iOS
- Web
- Desktop
- màn hình nhỏ / lớn
- text scale hệ thống tăng cao

---

## Thành phần đã thêm

### 1. `lib/core/responsive/app_responsive.dart`
Cung cấp:

- phân loại breakpoint:
  - `compact`
  - `medium`
  - `expanded`
  - `large`
- hàm clamp text scale toàn app
- hàm tính số cột grid theo width
- hàm tính padding ngang theo width
- `ResponsiveContentFrame` để:
  - căn giữa nội dung trên màn hình lớn
  - giới hạn max width
  - giữ UI không giãn quá mức trên desktop/web

### 2. `main.dart`
Đã thêm `MaterialApp.builder` để:

- clamp `textScaleFactor`
- giảm rủi ro vỡ layout khi người dùng tăng cỡ chữ hệ thống quá cao

### 3. Các màn hình đã nối cơ chế responsive
- `HomeScreen`
- `SpeakModeScreen`
- `WriteStudioScreen`
- `ToolsOverlayV2`

---

## Nguyên tắc hoạt động

### A. Clamp text scale toàn app
Mục tiêu:
- tránh header/bottom nav/chip bị phình quá mức
- giảm overflow do accessibility font scale lớn

### B. Responsive content frame
Mục tiêu:
- mobile: full width vừa phải
- tablet/desktop: giới hạn max width
- tránh card/grid bị kéo giãn quá rộng

### C. Adaptive grid
Mục tiêu:
- màn nhỏ: giảm số cột để tránh vỡ
- màn lớn: tăng số cột để tận dụng không gian

### D. LayoutBuilder cho vùng nhạy cảm
Mục tiêu:
- quyết định số cột / aspect ratio / padding theo kích thước thực
- xử lý các nơi dễ overflow như:
  - Bento grid Home
  - Tools overlay

---

## Những gì cơ chế này giúp giảm rủi ro

- text dài trong app bar / card subtitle
- grid quá chật trên màn hình nhỏ
- grid quá giãn trên desktop
- overflow do tăng cỡ chữ hệ thống
- layout mất cân đối giữa mobile và desktop

---

## Những gì vẫn cần test thủ công

Dù đã có cơ chế responsive, vẫn phải test thực tế với:

- mobile màn nhỏ
- landscape
- web / desktop width lớn
- text scale hệ thống lớn
- có mini player
- có keyboard
- các sheet / dialog / overlay

Xem thêm:
- `docs/shell_manual_qa_checklist.md`

---

## Hướng mở rộng tiếp theo

- thêm responsive frame cho nhiều màn hình tool chuyên sâu khác
- chuyển một số layout lớn sang 2-pane trên desktop
- thêm NavigationRail / adaptive side navigation cho màn rộng
- tinh chỉnh từng màn có waveform / tab / list dài
