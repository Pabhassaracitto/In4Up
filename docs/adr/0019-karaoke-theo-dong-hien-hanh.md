# ADR-0019 — Đồng hồ và vùng nhìn karaoke dùng chung

- Trạng thái: đã triển khai trên nhánh làm việc, CI matrix xanh; cần review
  độc lập, build Android đầy đủ và nghiệm thu thiết bị.
- Bối cảnh: hai tab ước lượng chiều cao dòng không theo layout thật, khiến lời
  dài/dịch/font lớn bị lệch; parser enhanced-LRC gán nhầm mốc cho từ giữa dòng.

## Quyết định

- Vị trí bộ phát là nguồn thời gian duy nhất của `UnderstandProvider`, kể cả
  khi hai tab không hiện; nạp lại LRC dùng vị trí gần nhất thay vì đợi tick.
- Hai tab dùng cùng một vùng lyric ảo hoá, theo index và vị trí được layout
  thực tế. Auto-follow được mặc định bật, người dùng có thể tắt hoặc kéo tay;
  sau khi kéo xong có khoảng nghỉ trước khi tiếp tục. Không đè thao tác seek.
- Cài đặt dùng chung và tồn tại qua phiên: chỉ hiện dòng hiện hành; hoặc hiện
  các dòng khác mờ, nhỏ hơn. Mặc định giữ kiểu danh sách trước đây.
- Chỉ highlight chính xác theo dữ liệu timestamp có trong nguồn. Khi không có
  timestamp từng từ, khoảng cách chữ chỉ là ước lượng, không sửa dữ liệu LRC.
- Sắp xếp timeline trong bộ nhớ ổn định theo timestamp; không ghi lại file cũ.
  Sửa parser để timestamp inline áp dụng cho phần chữ sau chính thẻ đó và
  hỗ trợ phút lớn hơn 99, giữ mốc từ đầu khi tạo/sửa LRC.

## Kiểm chứng cần có

Kiểm thử vị trí sau seek, nạp khi tạm dừng, timestamp từ và file dài, hàng
trăm dòng cao khác nhau/viewport nhỏ/chữ lớn/dịch, thay đổi chế độ, cuộn tay,
locale và tích hợp hai tab. CI không thay cho nghe thử trên thiết bị thật với
LRC do các engine AI khác nhau tạo; sai số nhận dạng và timestamp nguồn vẫn
cần người dùng đánh giá.
