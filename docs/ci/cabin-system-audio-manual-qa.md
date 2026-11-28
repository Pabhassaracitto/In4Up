# CABIN-SYS-001 — nghiệm thu thiết bị

CI chỉ kiểm Dart/analyze, Kotlin compile giả lập embedding và Windows DLL
ABI. Không chứng minh luồng âm thanh, model, overlay hay quyền hoạt động trên
máy thật. Chạy trên APK và bundle Windows do nhóm build, không dùng test CI
thay cho nghiệm thu. Cần review mã, xem ADR-0039.

## Chuẩn bị

- Android 10+ (kiểm ít nhất Android 10 và Android 14+), Windows 10/11; mỗi máy
  có đầu ra âm thanh và một ứng dụng phát tiếng Việt cho phép thu âm. Không
  phải ứng dụng nào cũng cho phép playback capture (đặc biệt nội dung DRM).
- Cài model ASR tiếng Việt offline và thành phần VAD cần thiết; chọn nguồn VI,
  đích EN và engine dịch phù hợp. Đảm bảo người dùng có quyền nghe/ghi nội dung.
- "Âm thanh hệ thống" là âm thanh phát trên chính thiết bị, không phải âm thanh
  phát ra từ TV bên ngoài trừ khi tín hiệu TV đã được đưa vào thiết bị.

## Kiểm thử

1. Bật nguồn **Âm thanh hệ thống**, chọn **Bong bóng toàn hệ thống**, bắt đầu.
   Android: cho phép micro, cấp quyền hiển thị trên ứng dụng khác, quay lại
   bấm Bắt đầu và chấp thuận hộp thoại MediaProjection. Windows: chạy bundle
   có `in4up_cabin_audio.dll` cạnh ứng dụng.
2. Phát tiếng Việt trong ứng dụng khác và chuyển sang ứng dụng đó. Xác nhận
   bubble nổi trên ứng dụng khác, kéo được, chạm để thu gọn/mở; có dòng dịch EN
   mới liên tục và ghi nhận độ trễ/chất lượng. Thử câu dài, phải thấy bản dịch
   ở đầu bong bóng. Android: xác nhận notification và nút dừng.
3. Bật **Đọc dịch**: nghe được tiếng Anh; tiếng Anh không bị nhận dạng lại
   thành một vòng lặp. Khi đọc, nguồn bị thay bằng im lặng trong ASR **và WAV**
   (có thể mất lời đang nói), đúng cảnh báo trên màn hình.
4. Stop khi đang nói: chốt partial, dừng notification/capture, ẩn overlay,
   phiên lưu được; mở lại file WAV/text, đối chiếu hướng ngôn ngữ và mốc. Không
   được âm thầm ghi âm sau khi stop.
5. Pause/resume: partial được chốt; tiếp tục trên Android phải xin consent mới;
   Stop khi đang chờ consent, từ chối hoặc thu hồi consent thì không thu ngầm,
   không tự mở mic, hiển thị lỗi/khôi phục được bằng thao tác người dùng.
6. Từ chối quyền micro/overlay, Android dưới 10, thiết bị Windows không có đầu
   phát hoặc đổi/rút thiết bị trong lúc thu: báo lỗi, không kẹt trạng thái nghe,
   không tự bật lại nguồn hoặc tự xin consent lặp lại.
7. Thử app nguồn chặn playback capture: có thể nhận im lặng; không khẳng định
   thu được mọi ứng dụng. Với Windows thử 44.1/48/96 kHz, stereo/đa kênh; nghe
   kiểm chất lượng và đánh giá alias do bộ nội suy hiện chưa có lọc anti-alias.
8. Thử xoay màn hình, đưa app xuống nền, tắt app/giết process, khóa màn hình,
   mở lại; xác nhận không còn FGS/overlay/thu âm ngoài ý muốn và giải thích nếu
   hệ điều hành dừng phiên. Kiểm tra khung 360×640 và phóng chữ, EN + HI/ZH/SI.
9. Đổi sang Micro và kiểm tra luồng mic/engine hệ thống cũ vẫn hoạt động; thử
   chọn model thiếu, chuyển ngôn ngữ khi nghe, lưu phiên và dừng bình thường.

Ghi lại phiên bản app, OS, loại nguồn phát, model, engine dịch, từng bước và
kết quả, log lỗi đã loại dữ liệu riêng tư. Chỉ đánh dấu nghiệm thu sau khi
cả hai nền tảng đạt và các giới hạn còn lại được owner chấp nhận.
