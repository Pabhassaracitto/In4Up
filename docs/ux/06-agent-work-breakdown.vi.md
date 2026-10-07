# I4U UX — Phân rã công việc cho Arena Agent

> Trạng thái: khung chuẩn bị; chưa giao agent và chưa code.

## Nguyên tắc

- Chỉ giao việc sau khi wireframe và tiêu chí UX đã được chốt.
- Một branch chỉ có một capability.
- Tối đa 1–3 commit mỗi branch.
- Agent không tự ý refactor ngoài phạm vi.
- Không gộp thay đổi business logic vào nhiệm vụ shell/UI nếu không được yêu cầu.

## Mẫu giao việc

```text
Branch:

Mục tiêu:

Bối cảnh UX:

Được phép sửa:

Không được sửa:

Hành vi bắt buộc:

Responsive requirements:

Accessibility requirements:

Test bắt buộc:

Số commit tối đa: 1–3

Commit format:

Điều kiện bàn giao:
```

## Các capability dự kiến

### Phase 1 — Shell foundation

- Mobile primary navigation
- Desktop collapsible sidebar
- Context bar foundation
- Mini player shell integration

### Phase 2 — Contextual surfaces

- Quick Actions
- Command Palette
- Global contextual Chat
- Tool panel/drawer behavior

### Phase 3 — Workspace refinement

- Home
- Đọc
- Nghe/Xem
- Hiểu
- Nhớ/Học thuộc

Chưa tạo branch hoặc giao agent ở giai đoạn UX này.
