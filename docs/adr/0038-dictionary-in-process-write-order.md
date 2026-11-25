# ADR-0038 — Xếp hàng các thay đổi bộ từ điển trong tiến trình

- Trạng thái: triển khai + test tổng hợp, chờ CI/review/máy thật.
- Bối cảnh: `ensureInitialized` trước đây đặt cờ trước khi manifest đọc xong;
  một lookup hoặc thao tác ghi đồng thời có thể thấy danh sách rỗng. Nhiều
  reimport/xóa/relink/lưu manifest đồng thời cũng có thể xen kẽ: DB, bundle và
  manifest không nhất quán, hoặc thao tác xóa ghi đè lên trạng thái mới.

## Quyết định

Các caller cùng chờ một Future khởi tạo manifest. Serialize các mutation trên
singleton trong thứ tự gọi: import MDX/SQLite (cả SAF), relink, đánh dấu pack,
đổi thứ tự, bật/tắt, xóa và kiểm tra nguồn linked có thể cập nhật manifest.
Sao chụp input collection trước khi xếp hàng, giải phóng hàng đợi kể cả khi
lỗi. Không khóa lookup: trong lúc index thay thế, lookup có thể báo lỗi tạm
thời thay vì chờ vô hạn, và lớp giao diện vẫn phải xử lý kết quả lỗi/cũ.

Test điều khiển barrier cho khởi tạo chồng nhau, hai copy import cùng ID,
reimport trước xóa và giải phóng hàng đợi sau ngoại lệ; kiểm tra SQLite và
manifest sau restart. Test dùng MDict synthetic/SQLite FFI, không phải QA SAF.

## Giới hạn

Đây chỉ là khóa trong **một singleton/isolate**, không phải inter-process lock,
không xử lý app bị kill, nguồn sửa bên ngoài, rollback WAL, lỗi ghi manifest
đang bị bỏ qua, hay tên trùng được hash thành cùng ID. Kiểm tra SAF/import treo
có thể giữ hàng đợi vô hạn; thao tác khác sẽ đợi, không có hủy/timeout mới.
Import từ catalog và việc gắn pack là hai thao tác riêng, không phải transaction.
Giữ bundle cũ sau reimport và chi phí lưu trữ vẫn theo ADR-0037. Cần nghiệm thu
LAAD3/Lạc Việt, mất quyền, kill/restart, lỗi dung lượng và UI trên thiết bị thật;
không kết luận an toàn giao dịch toàn diện từ test này.
