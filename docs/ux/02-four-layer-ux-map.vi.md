# I4U UX — Bản đồ bốn tầng

> Trạng thái: bản nháp v0.1 — chưa phải quyết định cuối cùng.
> Cập nhật: 2026-10-04

## Sơ đồ tổng quát

```text
GLOBAL SHELL
├── Điều hướng chính
├── Quick Actions / Command Palette
├── Search
├── Settings / account
├── Trạng thái đồng bộ / review / model
└── Mini player

WORKSPACE — navigation mặc định
├── Home
├── Đọc
├── Nghe
├── Hiểu
└── Nhớ

Ghi chú:
- Xem là media mode/source trong Nghe, không phải workspace cấp 1.
- Chat là capability global nhưng contextual theo workspace và nội dung.

CONTEXT BAR
├── Mode hiện tại
├── Nguồn nội dung
├── Bộ lọc
├── View/sort
└── Hành động chính của workspace

TOOLS
├── Dictionary
├── Translation
├── OCR
├── TTS / STT
├── AI Coach
├── Notes
├── Vocabulary
├── Import / Export
├── Review helpers
└── Media/text controls
```

## Nguyên tắc phân tầng

### Global Shell

Một thành phần chỉ thuộc Global Shell nếu người dùng có thể cần nó ở nhiều workspace và nó không phụ thuộc sâu vào nội dung cụ thể.

### Workspace

Một thành phần thuộc Workspace nếu nó trả lời câu hỏi “tôi đang làm loại công việc nào?” và có thể giữ trạng thái riêng.

### Context Bar

Một thành phần thuộc Context Bar nếu nó thay đổi cách làm việc trong workspace hiện tại nhưng không phải một mục tiêu lớn độc lập.

### Tools

Một thành phần thuộc Tools nếu nó hỗ trợ một nhiệm vụ ngắn, thường mở theo ngữ cảnh, có thể đóng lại và không cần chiếm vị trí điều hướng chính.

## Quy tắc responsive dự kiến

### Mobile

```text
Top bar: workspace + hành động chính
Content
Context bar: cuộn ngang hoặc compact chip
Bottom navigation: 5 workspace
Tool: bottom sheet / full-screen flow
```

### Tablet

```text
Navigation rail
Content chính
Tool panel có thể mở rộng
Mini player cố định nếu đang phát
```

### Desktop/Web

```text
Sidebar thu gọn/mở rộng
Top bar + command/search
Content chính
Contextual side panel
Mini player hoặc bottom player
```

## Các điểm cần kiểm tra trên wireframe

- Khi Context Bar tự ẩn, affordance mở lại nằm ở đâu?
- Quick Actions có hiển thị hành động ưu tiên ngay lập tức không?
- Một tool được mở có che mất nội dung chính không?
- Có thể đóng tool bằng Escape, back, swipe và nút đóng không?
- Người dùng có phân biệt được mode, nguồn nội dung và tool không?
- Desktop có tận dụng panel thay vì kéo dài một cột nội dung không?
- Bottom navigation có được thay bằng rail/sidebar ở màn hình lớn không?
