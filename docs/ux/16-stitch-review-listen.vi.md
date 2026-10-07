# I4U UX — Review Nghe Workspace & Audio Library

> Trạng thái: kiến trúc đạt baseline; cần đặc tả state chi tiết trước khi code playback/import.
> Cập nhật: 2026-10-04

## Đánh giá

Kết quả Prompt 9 đã chốt đúng các nguyên tắc quan trọng:

- Nghe và Xem cùng một workspace, không tạo tab cấp 1 thứ sáu.
- Library không bị biến thành admin table.
- Continue Listening là primary action.
- Chọn nội dung và Phát nội dung là hai hành vi khác nhau.
- Mini Player nằm trên bottom navigation và tính safe area.
- Có Empty, Loading, Populated và Expanded Player.
- Transcript có thể trở thành nguồn cho Dictionary, Translation và Nhớ.
- Audio Library hỗ trợ imported audio và curated collections.

## Điểm cần giữ

1. Click thân card để chọn/xem chi tiết không tự phát audio.
2. Nút Play là hành động phát rõ ràng.
3. Continue Listening chỉ có một primary action.
4. Mini Player không che bottom navigation.
5. Expanded Player giữ context bài nghe và transcript.
6. Import flow phải cho biết đang tải, đang xử lý hay đã sẵn sàng.

## Điểm cần kiểm chứng

### 1. Pitch Accent chỉ hiển thị khi có dữ liệu

Không nên mặc định hứa có pitch contour/IPA cho mọi audio. Cần trạng thái:

- có dữ liệu;
- đang phân tích;
- không hỗ trợ;
- phân tích thất bại.

### 2. Imported Audio cần phân biệt nguồn và quyền sử dụng

Hiển thị rõ file local, URL, podcast, nội dung curated và trạng thái offline/online. Không làm UI giống kho file kỹ thuật.

### 3. Loading cần tránh thuật ngữ quá kỹ thuật

Các bước xử lý có thể hiển thị ở trạng thái chi tiết, nhưng trạng thái mặc định nên dùng ngôn ngữ người dùng hiểu: Đang chuẩn bị audio, Đang tạo transcript, Đang đồng bộ lời thoại.

### 4. Mini Player và Peek Dock

Nghe workspace không được tạo thêm một lớp nổi cạnh tranh với mini player. Khi Expanded Player mở, mini player/peek phải chuyển trạng thái rõ ràng.

### 5. Keyboard shortcut

`Space` chỉ hoạt động khi focus nằm trong player hoặc không nằm trong input/text field. Không ép shortcut trên mobile.

## Cần đặc tả tiếp

Prompt 9 đã đủ để chốt kiến trúc, nhưng cần prompt bổ sung cho các state:

- Empty library
- Populated library
- Continue Listening
- Selected item without playback
- Loading/import/transcription
- Playing mini player
- Paused/idle mini player
- Expanded player with transcript
- Transcript unavailable/error
- A-B loop/shadowing state
- Import success/failed

## Quyết định chuyển tiếp

Sau state detail của Nghe, chuyển sang Prompt 10 — Xem within Nghe. Không cần thiết kế lại Library từ đầu.
