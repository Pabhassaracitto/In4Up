# ADR-0036 — Tra theo từng đợt và chọn chữ từ ứng dụng Android khác

Trạng thái: triển khai từng phần, cần review, CI và nghiệm thu thiết bị.

## Tra từ

Giữ SQLite hiện tại; lookup nhanh mặc định tối đa 10 record/bộ, đọc thêm một
record để nhận biết thiếu. Màn Từ điển cho tải thêm 10 mỗi lần bằng cách tra
lại có thứ tự theo id, tối đa 100 record/bộ; không tự tải toàn bộ. Redirect được
tra cùng hạn mức và resolver giới hạn tối đa 512 kết quả, 512 lượt thăm, 32
lookup, độ sâu 8; báo chưa đủ nếu gặp giới hạn. Vì đây là truy vấn lại, không
phải snapshot cố định nếu DB thay đổi đồng thời; cần QA race import/relink.
Các popup khác chưa phân trang; người dùng có thể mở màn Từ điển để tải thêm.
Không thay đổi giới hạn Unicode NOCASE của SQLite hoặc kiến trúc lưu MDX.

Renderer văn bản giữ ranh giới ô bảng, không đọc stylesheet, thực thi script,
network hay đường dẫn; ảnh MDD vẫn tuân thủ ADR-0034. Không coi đó là hiển thị
nguyên bản, chưa CSS/audio/font hoặc ảnh inline.

## Android PROCESS_TEXT

Thêm lựa chọn bôi chữ `text/plain` do người dùng chủ động gọi; chuyển dữ liệu
thành URI tra từ app, dùng bộ kiểm tra deep-link 64 rune. Native giới hạn đầu
vào trước encode; không đọc clipboard, không OCR, không trả văn bản thay đổi cho
ứng dụng nguồn, không mở tệp do chữ đưa vào. Hàng đợi nhận đến khi Dart sẵn;
chưa nghiệm thu cold/warm, xoay màn hình, app nguồn hoặc đa ngôn ngữ trên máy.
Từ tra thành công được lưu lịch sử màn Từ điển (người dùng có thể xoá); không
có bong bóng tra từ hoặc hỗ trợ iOS/desktop trong thay đổi này.

## Còn lại

Đo LAAD3/SAF + Lạc Việt thật, xử lý lỗi và giới hạn trong mọi popup, tìm kiếm
Unicode, phân trang theo cursor/snapshot thay vì lặp truy vấn, báo dung lượng
DB/bundle có phân biệt không rõ, renderer CSS an toàn / media, và QA phát hành.
Không tự xóa nguồn, không dùng sample có bản quyền làm fixture.

## Bổ sung chẩn đoán và quản lý

WordInsight, pop Đọc, PDF và WordAnalysis giữ báo lỗi/thiếu record khi xem
chi tiết; lookup lỗi không cache để có thể thử lại. Giao diện quản lý cho biết
kích thước riêng tệp SQLite, không tính WAL/SHM, bundle hay file nguồn; nếu
không đọc được ghi không rõ. Các báo cáo tổng dung lượng, SAF/provider treo,
UI media và nghiệm thu trên thiết bị vẫn chưa hoàn tất.

## Bổ sung kiểu chữ nội tuyến an toàn

Chỉ nhận một số giá trị chính xác của `font-weight`, `font-style` và
`text-decoration` trong thuộc tính style (tối đa 1024 ký tự, 32 khai báo);
không diễn giải URL, file, màu, font, kích thước, bố cục hay thuộc tính ẩn.
Không đọc tệp CSS, không chạy JavaScript; không coi đây là renderer nguyên bản.
