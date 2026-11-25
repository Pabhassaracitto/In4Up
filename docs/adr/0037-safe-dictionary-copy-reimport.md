# ADR-0037 — Bảo toàn bundle khi nhập lại từ điển

- Trạng thái: code + test synthetic, cần CI, review và nghiệm thu thiết bị.
- Bối cảnh: trước đây copy mode xóa `<id>.bundle` trước khi copy/index bản mới.
  Nếu nguồn lỗi, không đủ dung lượng hay parse hỏng thì SQLite cũ còn nhưng
  MDD/MDX đã sao chép vào app có thể mất. Đặc biệt nghiêm trọng với MDD 1,22 GB.

## Quyết định

Copy vào thư mục app mới, tên ngẫu nhiên, không ghi đè bundle đang đăng ký;
chỉ đăng ký bundle mới khi MDX được copy và index thành công. Nếu lần nhập lại
không copy được một file phụ đã chọn, không thay bản cũ bằng bản thiếu; báo lỗi.
Nếu lần cài đầu thiếu file phụ được chọn thì vẫn cho dùng giảm cấp như trước và
báo thiếu. Thư mục tạm thất bại được dọn best-effort; không xóa nguồn user.

**Đổi lại:** cần đủ chỗ chứa đồng thời hai bundle và DB tạm; bundle cũ được
cố ý giữ lại cả sau thành công vì manifest/SQLite/bundle chưa có giao dịch crash
atomic và chưa có cơ chế kiểm ownership/reference để xoá an toàn. UI báo cần
thêm chỗ. Hiện chưa có UI thống kê/dọn các bundle cũ không còn gắn manifest;
không tự dọn vì có thể đó là bản duy nhất của user. Đóng gói lại/dọn cần thiết
kế riêng, xác nhận nguồn, chính sách khôi phục và crash/permission. Việc người
chọn thiếu phần phụ không đồng nghĩa có thể tự suy đoán bộ đầy đủ.

Kiểm thử ba trường hợp: MDX hỏng, file phụ chọn nhưng copy lỗi, thành công
và còn bản cũ; so lookup/MDD và manifest sau restart. Đây không chứng minh an
toàn khi app bị hệ điều hành dừng đúng giữa promotion SQLite và ghi manifest,
hai import cùng ID đồng thời, phục hồi WAL, mất điện hoặc thiếu chỗ trên máy
thật. ID hiện dựa trên basename, hai file trùng tên có thể bị coi là một bộ;
cần thiết kế nhận dạng/migration trước khi đổi. Không coi fix này là giao dịch
ACID hay hoàn tất QA LAAD3/SAF.
