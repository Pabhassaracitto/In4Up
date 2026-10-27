# Tự rà soát PLAN-040 / KARAOKE-001

- Đồng hồ lyric lấy từ player kể cả khi màn Nghe/Hiểu không mở; nạp LRC mới
  đồng bộ ngay với vị trí gần nhất và giữ nguyên source/file.
- Hai tab dùng cùng widget theo index thực, không ước lượng chiều cao dòng;
  danh sách ảo hoá bằng `scrollable_positioned_list` 0.3.8 (BSD-3-Clause).
- Có hai mode dùng chung, lưu SharedPreferences, giữ nguyên mặc định danh sách;
  không chuyển ngữ nội dung của người dùng. Cho tắt auto và ưu tiên thao tác kéo.
- Tự rà parser: mốc inline áp dụng cho chữ ngay sau tag; phút >99; từ đầu giữ
  timestamp; không sửa/xoá LRC đã lưu. Khi nguồn không có mốc từng từ thì chỉ
  ước lượng, không thể bảo đảm timing khớp giọng AI.
- Widget/test timing, source text, cỡ chữ, seek xa, cuộn tay, locale, hai tab
  và cài đặt đã qua CI; chưa có test thiết bị thật, accessibility thực tế,
  build Android đầy đủ hoặc review độc lập.

## CI và bổ sung bảo toàn LRC

- Matrix `40584783154` và run rộng `40584783001` tại `b6ee188` thành công;
  gồm timing, widget auto-follow, nội dung gốc, mode, cài đặt và locale.
- Test thêm trên màn hình Nghe/Hiểu thật phát hiện hint tràn ngang sau khi mở
  lại rèm trên màn hẹp; đang sửa và chạy lại (không coi run đỏ là đã đạt).
- LRC mới giữ dấu câu, khoảng cách và độ chính xác mili giây nếu có; khi sửa
  chữ không thể khớp mốc từng từ, hỏi trước khi bỏ mốc từ các dòng đó, giữ
  mốc dòng, header và các dòng metadata. Nếu phát hiện LRC đã đổi ở nơi khác
  trước khi lưu, editor không ghi đè; vẫn cần thử thiết bị thực tế.
- Không tự mở lại sheet AI đè lên lời sau khi người dùng đóng trong lúc tạo;
  không tự đóng editor đã mở để tránh mất bản nháp chưa lưu.

Matrix `40586036063` tại `2d5f255` xác nhận test hai tab (gồm 320×500,
seek, ẩn/hiện và không mở overlay AI) đã qua; timing mới và widget view cũng
qua. Riêng test editor thất bại khi đọc file bất đồng bộ trong fake clock, đang
chuyển phần I/O test sang real-async và chạy lại; không coi toàn matrix đã đạt.

## Kết quả mới nhất

Matrix `40586662698` tại `7c8901f` thành công: 11 nhóm test Dart, gồm cả
editor với file LRC thật, hai tab và hai chế độ, cùng compile Kotlin resolver.
Run rộng `40586662734` tại cùng commit cũng thành công, gồm analyzer và các
regression app. Đây không phải build Android Gradle hoặc nghiệm thu thiết bị thật.
