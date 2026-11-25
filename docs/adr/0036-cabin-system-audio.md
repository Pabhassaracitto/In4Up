# ADR-0036 — Live Cabin: nguồn âm thanh hệ thống

- Trạng thái: **đang thực hiện, cần code review và nghiệm thu thiết bị**.
- Ngày: 2026-11-24.

## Bối cảnh

Cabin hiện nhận mic và nhận dạng trước khi dịch. Người dùng cần dịch âm thanh
đang phát bởi ứng dụng khác (ví dụ tiếng Việt → tiếng Anh), đồng thời xem phụ
đề trên ứng dụng khác. Chọn Android và Windows; bong bóng phải là overlay hệ
thống, không phải chỉ là widget nổi trong app.

## Quyết định

- Dùng PCM 16 kHz mono 16-bit hiện có của engine Sherpa và recorder, không mở
  mic thứ hai. Engine STT hệ thống không nhận luồng PCM ngoài, vì vậy nguồn
  hệ thống chỉ dùng engine offline và phải yêu cầu model ngôn ngữ nguồn.
- Android 10+: playback capture qua MediaProjection, RECORD_AUDIO và foreground
  service `mediaProjection`. Mỗi phiên nhận consent mới, không tái sử dụng
  token; dừng/hủy phải vô hiệu hoá kết quả consent về muộn. Quyền overlay là
  riêng, chỉ xin khi bật bong bóng. Có thông báo hệ thống để dừng. Chỉ thu ứng
  dụng cho phép playback capture; DRM hoặc chính sách ứng dụng nguồn có thể
  chặn hoặc làm im lặng.
- Windows: WASAPI loopback dùng endpoint phát mặc định, worker COM riêng, hàng
  đợi có giới hạn; lỗi thiết bị hoặc tràn buffer phải báo, không bỏ mẫu âm thầm.
  Chuyển float interleaved thành PCM cho Sherpa. Cần overlay hệ thống Windows
  và tích hợp vào runner; DLL và Dart adapter hiện chưa tạo overlay Windows.
- Chu trình Start/Stop/Pause phải dừng nguồn, chốt partial và bảo toàn session;
  Android resume sau khi dừng projection cần consent mới. Không dùng keepalive
  tự động làm lại consent. Lỗi/thu hồi quyền phải báo rõ, không tự dùng mic.
- TTS có nguy cơ lọt trở lại luồng hệ thống. Trước khi bật nguồn hệ thống
  cần xử lý feedback bằng thiết kế được kiểm thử, không chỉ dựa vào ẩn caption
  khi đọc; cần báo rõ thời gian nguồn bị tắt/mất nếu phải mute đầu vào.
- Không đẩy dữ liệu giọng nói vào notification/log, không giữ token qua phiên.
  Luồng giữa native và Dart có giới hạn, tràn dẫn tới lỗi có thể thấy.

## Giới hạn và kiểm chứng

Mã hiện tại **chưa được nối vào Cabin/ASR/UI**. Bộ nội suy Windows hiện chưa
lọc anti-alias nên cần đánh giá chất lượng hoặc bổ sung lọc trước khi dùng.
CI native hiện kiểm tra biên dịch/ABI chứ không kiểm chứng thiết bị âm thanh,
quyền, capture, overlay hay bản dịch. Cần kiểm thử Android API 29/34+, Windows
âm thanh stereo/multichannel, mất thiết bị, từ chối/thu hồi consent, hủy trong
khi đang xin quyền, pause/resume, TTS feedback, ngôn ngữ và hiển thị overlay
trên ứng dụng khác, rồi review trước khi tuyên bố hoàn tất.

### Cập nhật 2026-11-24

`ba144c7`–`08a83d8` thêm cửa sổ Win32 topmost và `03f0551` thêm adapter FFI.
Đây mới là nền độc lập, **chưa** nối vào Cabin hay được nghiệm thu với ứng dụng
khác. Trên Android, `1f81501`–`212b3ad` thêm kênh + overlay và test hợp đồng;
vẫn phải tích hợp luồng caption và xử lý đầy đủ vòng đời trên máy thật.
