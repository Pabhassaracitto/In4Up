# ADR-0031 — Worker MDD và vòng đời nguồn

- Trạng thái: triển khai từng bước, cần review và QA thiết bị.
- Bối cảnh: ADR-0029/0030, PR #189 đã merge vào 251e tại `8ed86e1`; MDD 1,22 GB
  không được nạp toàn bộ vào RAM, không đổi pipeline tra từ SQLite.

## Quyết định

`MddWorkerPool` giới hạn mặc định 1 worker, tối đa cấu hình 2 và 16 tác vụ đợi.
Worker lập index/giải nén, nhận từ isolate gốc chỉ chỉ số part + byte qua RPC;
không nhận path/URI hay gọi plugin. Isolate gốc xác định nguồn đã đăng ký và sở
hữu File/SAF handle. RPC đọc từng trang tối đa 64 KiB; block/asset/metadata vẫn
chịu trần ADR-0029. `DictionaryService.startMddResourceRead` trả task có thể huỷ,
API Future trước đó dùng chung pool. Không mở network/file dựa trên key HTML.

Huỷ task đang chạy dừng worker, đợi I/O hiện tại và cả open đang thực hiện, sau
đó đóng handle ở isolate gốc; huỷ task chờ không mở file. Không thể ép huỷ native
provider bị treo: cancellation có thể chờ vô hạn nếu provider không hoàn tất.
Không có timeout cưỡng bức vì nếu bỏ rơi một open chưa hoàn tất có thể rò handle.
Lỗi thu hồi quyền vẫn là `RandomAccessSourceException`, không nhầm với key thiếu;
không sửa/xóa SQLite. Không cache index: mỗi lần đọc mở và index lại từng part.
Thông tin bộ là snapshot tại thời điểm bắt đầu; caller tương lai phải huỷ/loại
kết quả cũ khi relink, đổi từ hoặc đóng màn hình.

## Kiểm chứng và phần còn lại

Test dùng MDD synthetic filesystem và MethodChannel SAF mock, lỗi quyền, hàng đợi,
huỷ khi SAF open đang chờ, đóng handle, dữ liệu thay đổi và resource thiếu; test
không chứng minh hành vi provider thật, lifecycle Android hoặc hiệu năng LAAD3.
Chưa đưa vào widget; cần giới hạn ảnh giải mã, CSS/media sanitizer, lifecycle,
i18n, an toàn khi relink và QA thiết bị trước khi hiển thị. Chưa có cache,
invalidation, huỷ timeout native, hỗ trợ mọi biến thể MDD hoặc benchmark RAM/jank.

## CI và bàn giao

CI [43760882725](https://github.com/Pabhassaracitto/In4Up/actions/runs/43760882725)
xanh 4/4 trên `e208d4c` gồm DICT và I4U18/import; PR #192. Web chỉ mới compile,
chưa kiểm thử worker runtime. Test SAF là mock, chưa chứng minh provider Android
thực tế, hiệu năng, mức RAM hay khả năng huỷ khi provider bị treo.
