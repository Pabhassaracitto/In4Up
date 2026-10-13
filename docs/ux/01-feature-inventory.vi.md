# I4U UX — Kiểm kê tính năng

> Trạng thái: bản nháp v0.1 — kiểm kê cấp cao từ cấu trúc repository; cần rà với trải nghiệm thực tế.
> Cập nhật: 2026-10-04

## Cách đọc

- **Global Shell**: xuất hiện xuyên workspace hoặc điều phối toàn app.
- **Workspace**: nơi người dùng làm việc trong một khoảng thời gian.
- **Context Bar**: chuyển mode/nguồn/nội dung trong workspace hiện tại.
- **Tool**: hành động hoặc panel phục vụ nhiệm vụ cụ thể.

## Global Shell

| Thành phần | Vai trò đề xuất | Trạng thái cần xác minh |
|---|---|---|
| Điều hướng chính | Home, Nghe, Đọc, Hiểu, Nhớ | Đã có định hướng trong `MainShell` |
| Quick Actions | Mở hành động phù hợp ngữ cảnh | Cần phân biệt overlay và command palette |
| Tìm kiếm/command | Truy cập nhanh màn hình, tool, hành động | Chưa chốt |
| Settings/account | Cấu hình toàn app | Cần tránh trộn với tool học tập |
| Mini player | Điều khiển audio xuyên workspace | Đã có mini player; cần rà vị trí và hành vi |
| Thông báo/trạng thái | Review đến hạn, tải model, tiến trình | Cần xác định mức độ global |

## Workspace cấp 1

> Navigation mặc định đã thống nhất: `Home — Đọc — Nghe — Hiểu — Nhớ`.
> `Xem` không phải workspace cấp 1; đây là media mode/source thuộc `Nghe`.
> `Chat` là capability global nhưng thay đổi theo context.

### Home

**Mục tiêu:** tiếp tục việc đang học và chọn hành động tiếp theo.

Các nội dung hiện có/được định hướng:

- command center
- quick capture
- memory workspace shortcuts
- đường dẫn tới 4 trục học
- shortcut tới model/AI/account

**Không nên trở thành:** danh sách tất cả tính năng hoặc một màn hình settings tổng hợp.

### Nghe

**Mục tiêu:** nghe và làm việc với audio/video.

`Xem` là media mode/source bên trong `Nghe`, không phải workspace cấp 1. Video có thể chuyển sang Đọc, Hiểu hoặc Nhớ theo hành động của người dùng.

Các mode/nguồn cần rà:

- Nghe
- Nói
- Xem/video
- Audio library
- YouTube
- YouGlish
- sound list/audio tools
- mini player, transcript, playback controls

### Đọc

**Mục tiêu:** đọc và tạo nội dung chữ.

Các mode/nguồn cần rà:

- Đọc
- Viết
- tài liệu local
- PDF Reader
- Web Reader
- Tam tạng/Tipiṭaka
- text library
- write studio

### Hiểu

**Mục tiêu:** làm rõ, phân tích và trao đổi với nội dung.

Các khu vực cần rà:

- Understand workspace
- AI Coach
- live cabin/captions
- sync/comprehension
- notes/grounding
- chat/assistant

### Nhớ

**Mục tiêu:** biến nội dung thành kiến thức có thể ôn lại.

`Học thuộc` là một mode/sub-workspace quan trọng bên trong Nhớ, có thể được khởi tạo từ Đọc, Nghe, Xem hoặc Hiểu.

Các khu vực cần rà:

- review
- học thuộc/luyện thuộc
- word list
- stats/dashboard
- timeline
- vocabulary
- learning state/progress

## Context Bar — bản nháp

| Workspace | Context Bar dự kiến |
|---|---|
| Nghe | Nghe / Nói / Xem; Audio / YouTube / YouGlish khi cần |
| Đọc | Đọc / Viết; Tài liệu / Web / PDF / Tipiṭaka |
| Hiểu | Workspace hiểu; Coach / Chat / Live / Notes tùy ngữ cảnh |
| Nhớ | Review / Word List / Stats / Timeline |
| Home | Không ép mode switch; chỉ có quick actions theo mục tiêu |

## Tools — bản nháp

| Tool | Ngữ cảnh đề xuất | Cần kiểm tra |
|---|---|---|
| Dictionary / word lookup | Đọc, Nghe, Nhớ | Panel/sheet thay vì màn hình độc lập trong đa số trường hợp |
| Translation | Đọc, Viết, Hiểu | Toolbar hoặc contextual action |
| OCR | Nhập nội dung vào Đọc | Flow nhập liệu, không phải workspace |
| TTS / STT | Nghe, Nói, Viết | Có thể có control dùng lại ở nhiều nơi |
| AI Coach | Hiểu, Viết, Nói | Context panel; cần phân biệt với AI chat tổng quát |
| Vocabulary image | Nhớ, word lookup | Tool hỗ trợ lưu từ |
| Background removal | Nội dung media | Xác định có phải tool global hay chỉ thuộc workflow import |
| Import/export | Đọc, Nghe, Nhớ | Contextual action |
| Review/Stats | Nhớ | Có thể là context bar hoặc sub-workspace, không nên rải khắp app |
| PDF/Web reader controls | Đọc | Context toolbar |
| Audio transcript/markers | Nghe | Context toolbar hoặc bottom panel |

## Các câu hỏi chưa chốt

1. `Xem` có thực sự là mode cấp 2 của `Nghe`, hay nên là nguồn media trong `Nghe`?
2. `AI Chat` thuộc `Hiểu`, là tool global, hay là workspace riêng?
3. `Review` và `Stats` là mode của `Nhớ` hay workspace con?
4. `Tam tạng` là nguồn nội dung của `Đọc` hay một khu vực chuyên biệt?
5. Audio library và text library là workspace hay picker/drawer?
6. Mini player cần xuất hiện trên những nền tảng nào và ở vị trí nào?
7. Quick Actions và Command Palette nên là cùng một surface với hai cách mở, hay hai surface khác nhau?
