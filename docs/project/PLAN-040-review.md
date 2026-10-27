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
- Widget/test timing, source text, cỡ chữ, seek xa, cuộn tay, locale và cài đặt
  đang viết/đưa vào CI. Chưa có kết quả CI cho widget mới và chưa có test thiết
  bị thật, accessibility thực tế hoặc review độc lập.
