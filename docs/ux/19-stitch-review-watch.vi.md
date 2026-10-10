# I4U UX — Review Chế độ Xem trong Nghe

> Trạng thái: architecture baseline đạt; cần đặc tả state detail trước khi code.
> Cập nhật: 2026-10-04

## Đánh giá

Prompt 10 đã giữ đúng quyết định cốt lõi:

- Xem là media mode/source trong Nghe, không phải workspace cấp 1.
- Video, audio, subtitle và transcript nằm trong cùng một learning context.
- Không đưa grammar analytics lên màn hình mặc định.
- Có contextual actions cho subtitle/transcript.
- Có cầu nối chủ động sang Hiểu với source context và timestamp.
- Desktop dùng split view; mobile dùng one-column flow.

## Điểm mạnh

1. Video là vùng tập trung chính.
2. Transcript được đồng bộ theo timestamp.
3. Shadowing, Dictionary, Translation và Nhớ được mở theo selection.
4. `Hiểu nội dung này` là cầu nối rõ, không tự động chuyển workspace.
5. Bottom navigation vẫn được bảo toàn trên mobile.

## Điểm cần chỉnh

### 1. Desktop không nên thành ba cột mặc định

Cấu trúc 60/40 cộng thêm Lexicon Inspector ở góc phải có nguy cơ thành 3 vùng cạnh tranh. Khuyến nghị:

- Video + Transcript là layout mặc định.
- Lexicon Inspector là popover hoặc panel thay thế transcript khi cần.
- Không mở video, transcript, inspector đầy đủ cùng lúc mặc định.

### 2. Phụ đề song ngữ cần có chế độ hiển thị

Không nên luôn hiển thị hai ngôn ngữ nếu mục tiêu là immersion. Cần các mode:

- Original only
- Original + translation
- Translation on demand
- Hide subtitles

### 3. Năm action trên mobile có thể quá dài

Dải chip `Tra từ, Dịch, Giải thích, Shadowing, Thêm vào Nhớ` nên dùng 3 action ưu tiên + `Thêm`, hoặc cuộn ngang có chỉ báo rõ. Không để chip nhỏ khó chạm.

### 4. Auto-scroll transcript cần manual override

Khi người dùng cuộn transcript thủ công, auto-scroll phải tạm dừng và có nút `Theo lại câu đang phát` để bật lại. Không tự kéo người dùng về timestamp hiện tại khi họ đang đọc câu khác.

### 5. Bridge sang Hiểu cần giữ source context

Khi bấm `Hiểu nội dung này`, Hiểu phải nhận:

- video/source ID;
- timestamp;
- selected transcript;
- subtitle language;
- playback position;
- link quay lại Xem.

### 6. Shadowing cần state riêng

Cần phân biệt:

- chuẩn bị micro;
- đang nghe mẫu;
- đang thu âm;
- đang xử lý;
- đã thu xong;
- không cấp quyền micro;
- nghe lại/đánh giá.

### 7. Video pinned trên mobile

Nên chốt video là sticky vừa phải hay cuộn theo trang. Nếu pinned quá lâu, transcript sẽ bị quá ngắn; cần có chế độ thu nhỏ video.

## Quyết định chuyển tiếp

Prompt 10 đủ để chốt architecture. Cần chạy prompt state detail trước khi code, sau đó chuyển sang Prompt 11 — Hiểu với Chat và Coach.
