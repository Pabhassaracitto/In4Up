# Navigation Restructure Update Plan

## Mục tiêu

Tái cấu trúc điều hướng của VipSound theo hướng:

- `Home` trở thành **command center** / trung tâm điều phối.
- Bottom navigation rút về 5 đích đến thật sự:
  - `Home`
  - `Nghe`
  - `Đọc`
  - `Hiểu`
  - `Nhớ`
- Bỏ `Tools` khỏi bottom navigation.
- Biến `Tools` thành **quick actions** theo ngữ cảnh.
- Chỉ giữ tab phụ rõ ràng ở những nơi thật sự cần:
  - `Nghe | Nói`
  - `Đọc | Viết`
- `Hiểu` và `Nhớ` đứng độc lập vì đều là các module lớn.

---

## Kiến trúc mới

### 1) Bottom navigation

- Home
- Nghe
- Đọc
- Hiểu
- Nhớ

### 2) Secondary mode switch

- Trong `Nghe`: `Nghe | Nói`
- Trong `Đọc`: `Đọc | Viết`
- `Hiểu`: không ép làm subtab
- `Nhớ`: không ép làm subtab

### 3) Quick Actions

Không còn là tab thứ 6.
Quick actions sẽ là một nút toàn cục, mở overlay hành động nhanh theo ngữ cảnh hiện tại.

Ví dụ:
- Ở `Nghe`: ưu tiên YouTube, Nói, YouGlish.
- Ở `Đọc`: ưu tiên PDF, Web Reader, Viết.
- Ở `Nhớ`: ưu tiên Review, Word List, Stats.
- Ở `Home`: hiện danh sách đa dụng nhất.

---

## Chiến lược triển khai

### Phase 1 — Shell navigation foundation

- [x] Chuyển `MainShell` sang 5 tab chính.
- [x] Gỡ `Tools` khỏi bottom nav.
- [x] Di chuyển badge due review sang tab `Nhớ`.
- [x] Thêm nút quick actions toàn cục ở app bar.
- [x] Chuẩn hóa title/app bar theo tab và mode hiện tại.

### Phase 2 — Secondary modes

- [x] Thêm switch `Nghe | Nói`.
- [x] Thêm switch `Đọc | Viết`.
- [x] Tạo `SpeakModeScreen` làm speaking hub.
- [x] Tạo `WriteStudioScreen` làm writing hub.
- [x] Kết nối quick actions vào hai màn hình mới.

### Phase 3 — Home as command center

- [x] Làm sạch Home để đúng vai trò command center.
- [x] Giữ các card điều phối nhanh tới 4 trục học.
- [x] Đảm bảo Home không bị biến thành nơi nhét toàn bộ settings chi tiết.
- [x] Giữ shortcut tới Model / AI / account ở vị trí dễ thấy.

### Phase 4 — Tool redistribution

- [x] Ưu tiên audio/pronunciation tool về `Nghe` / `Nói`.
- [x] Ưu tiên text/import tool về `Đọc` / `Viết`.
- [x] Giữ sync/comprehension ở `Hiểu`.
- [x] Dồn review/word analytics về `Nhớ`.

### Phase 5 — Advanced UX settings (sau mặc định ổn định)

- [ ] Tùy chọn ẩn/thu gọn mode switch.
- [ ] Tùy chọn auto-hide mode switch khi cuộn.
- [ ] Long-press tab chính để jump nhanh sang tab phụ.
- [ ] Nhớ mode gần nhất của từng tab.

---

## Kanban

### Done
- [x] Chốt IA mới: `Home - Nghe - Đọc - Hiểu - Nhớ`
- [x] Chốt nguyên tắc: `Tools` không còn là bottom tab
- [x] Chốt nguyên tắc: mode phụ chỉ rõ ở `Nghe | Nói` và `Đọc | Viết`
- [x] Chốt nguyên tắc: advanced compact UX sẽ để trong settings, không làm mặc định

### In Progress
- [x] Refactor `MainShell`
- [x] Tạo quick actions theo ngữ cảnh
- [x] Tạo `SpeakModeScreen`
- [x] Tạo `WriteStudioScreen`
- [x] Sửa Home để ổn định và đúng vai trò command center

### Next
- [x] Gắn sâu hơn các tool vào từng tab
- [x] Tinh chỉnh text/audio drawers theo ngữ cảnh
- [x] Tối ưu mini player khi đổi mode
- [x] Rà lại overflow risk ở app bar + mode switch + mini player
- [ ] Nối các chức năng viết thật sự (dictation / cloze / AI scoring) vào `WriteStudioScreen`
- [ ] Tách sâu thêm speaking workflows (history, scoring, presets) vào `SpeakModeScreen`
- [ ] Thêm settings nâng cao cho compact mode / auto-hide / long-press chuyển mode

### Backlog
- [ ] Compact mode cho power users
- [ ] Long-press jump sang tab phụ
- [ ] Auto-hide secondary modes
- [ ] Phân quyền hiển thị quick actions theo mức độ sử dụng gần đây

---

## Ghi chú triển khai

1. Mặc định ưu tiên **discoverability** cho người mới.
2. Các tối ưu tiết kiệm không gian sẽ đi sau dưới dạng tùy chọn nâng cao.
3. Khi chưa có đủ chức năng hoàn chỉnh cho `Nói` và `Viết`, vẫn nên dựng hub rõ ràng để kiến trúc ổn định trước.
4. Trong giai đoạn đầu, quick actions có thể vẫn mở overlay cũ nhưng được sắp xếp lại theo ngữ cảnh mới.
