# I4U — Agent prompts Foundation Phase

> Dùng để giao cho Arena Agent sau UX Freeze. Mỗi capability trên một branch riêng, tối đa 1–3 commit.
> Branch session chính hiện tại: `arena/01a10675-in4up`

---

## Agent C-00 — Shared Shell Contracts

### Branch

```text
agent/c00-shared-shell-contracts
```

### Mục tiêu

Tạo lớp contract/model dùng chung cho Global Shell và các workspace, không xây dựng visual UI lớn.

### Bối cảnh

I4U có 5 workspace cố định:

```text
Home — Đọc — Nghe — Hiểu — Nhớ
```

Các flow phải giữ source context, return path, semantic reading anchor và overlay state.

### Được phép sửa

- `lib/models/`
- `lib/core/navigation/`
- `lib/core/responsive/` nếu cần token contract nhỏ
- test model tương ứng
- tài liệu contract nếu cần cập nhật

### Không được sửa

- Không refactor `MainShell` toàn bộ.
- Không thay đổi visual UI của workspace.
- Không thêm navigation tab.
- Không thay đổi business logic SRS/audio/AI.
- Không đưa Anki thành core model.

### Contract cần có

1. Workspace target/state.
2. Source fingerprint:

```text
sourceType
sourceId
sourceRevision
page/timestamp
selectedText
locale
returnPath
```

3. Semantic reading anchor:

```text
sourceId
sourceRevision
blockId
characterOffset
selectedTerm
locale
viewportRelativeRatio
```

4. Overlay/panel state.
5. Return path.
6. Serialization/deserialization an toàn.

### Test bắt buộc

- Round-trip serialization.
- Unknown enum/value fallback.
- Source fingerprint từ Đọc và Xem.
- Semantic anchor thiếu revision vẫn đọc được.
- Không làm thay đổi test hiện tại.

### Commit

Tối đa 2 commit:

```text
feat(core): add shared shell context contracts
 test(core): cover shell context serialization
```

### Definition of Done

- Contract rõ, nhỏ, không chứa UI logic.
- Có unit test.
- Có báo cáo file đã sửa.
- Không sửa ngoài phạm vi.

---

## Agent C-01 — Shortcut Registry

### Branch

```text
agent/c01-shortcut-registry
```

### Mục tiêu

Tạo registry cho shortcut theo platform, scope và fallback. Chưa gán shortcut hàng loạt vào toàn bộ app.

### Bối cảnh

Shortcut là đường phụ. Click/tap luôn là đường chính. Không được xung đột OS/browser/input.

### Được phép sửa

- `lib/core/` hoặc `lib/services/` cho shortcut registry
- test shortcut
- storage/preferences nếu cần lưu enabled/disabled
- docs contract

### Không được sửa

- Không sửa mọi màn hình để gắn shortcut.
- Không dùng `Cmd/Ctrl+1..5`, `Cmd/Ctrl+[`, `Cmd/Ctrl+O` làm shortcut mặc định nếu chưa có platform guard.
- Không bắt shortcut khi focus ở TextField, TextArea, EditableText hoặc contenteditable.
- Không thay đổi browser-native behavior.

### Schema tối thiểu

```text
id
platform
keyChord
scope
enabled
userOverride
fallbackAction
```

### Precedence

```text
OS/browser/native input
→ active modal
→ focused component
→ workspace
→ global
```

### Shortcut an toàn ban đầu

Chỉ đăng ký capability/fallback, có thể để disabled mặc định:

```text
open-command-palette
close-active-overlay
player-play-pause-when-focused
```

### Test bắt buộc

- Không trigger trong input.
- Trigger đúng scope.
- Disabled shortcut không chạy.
- User override được lưu/đọc.
- Escape chỉ đóng lớp active trên cùng.
- Browser/native shortcut không bị preventDefault ngoài scope.

### Commit

Tối đa 2 commit:

```text
feat(core): add scoped shortcut registry
 test(core): cover shortcut precedence and input guards
```

---

## Agent C-02 — Safe-area and Overlay Policy

### Branch

```text
agent/c02-safe-area-overlay-policy
```

### Mục tiêu

Tạo policy/layout primitives dùng chung cho safe-area, keyboard inset và overlay stacking. Không triển khai lại toàn bộ shell.

### Bối cảnh

Không dùng offset cứng cho mobile floating surfaces. Công thức logic:

```text
bottomOffset = navigationHeight + safeAreaInset + spacingToken
```

Khi keyboard mở, dùng viewInsets thực tế; không tự giả định safe-area bằng 0.

### Được phép sửa

- `lib/core/responsive/`
- `lib/widgets/` cho primitive nhỏ
- test responsive/layout helper
- docs contract

### Không được sửa

- Không sửa từng workspace riêng lẻ.
- Không hard-code 64/68/72/110/118px như contract universal.
- Không đổi z-index tùy tiện trong từng màn hình.
- Không quyết định playback behavior.

### Policy bắt buộc

#### Layer precedence

```text
Full-screen modal
> Dialog/Command Palette
> Bottom Sheet/Drawer
> Context Panel/Chat
> Mini Player
> Bottom Navigation
> Workspace content
```

#### Mobile stacking

- Quick Actions mở: Mini Player thu gọn/tích hợp.
- Sheet lớn: Mini Player ẩn foreground, audio tiếp tục.
- Expanded Player: full-screen modal exception.
- Bottom Navigation không bị che trong mode không phải full-screen modal.

#### Keyboard

Dùng:

```text
max(viewInsets.bottom, safeAreaInset.bottom)
```

theo platform/layout context phù hợp; không ghi đè native keyboard behavior.

### Test bắt buộc

- Safe-area không âm.
- Keyboard inset làm input nổi đúng vị trí.
- Floating surface không che touch target navigation.
- Layer order deterministic.
- Full-screen modal có đường đóng/back rõ.
- Responsive width nhỏ không overflow.

### Commit

Tối đa 2 commit:

```text
feat(ui): add shared safe-area and overlay policy
 test(ui): cover overlay precedence and keyboard insets
```

---

## Quy tắc chung cho cả ba agent

- Không chuyển branch session chính.
- Không commit vào branch của agent khác.
- Không tạo branch khác ngoài branch được giao.
- Không sửa `.git` hoặc credential.
- Mỗi agent phải chạy test liên quan.
- Nếu phát hiện phạm vi mới, dừng và báo cáo thay vì tự mở rộng.
