# ADR-0030 — Gắn tài nguyên MDD với đúng bộ từ điển

- Trạng thái: triển khai từng bước, cần review và QA máy thật.
- Bối cảnh: ADR-0028/0029; PR #188 đã merge vào 251e `3f0ec5d`. Lõi MDD trước
  đây chỉ nhận danh sách nguồn do caller cung cấp, chưa biết bundle của DictInfo.

## Quyết định

Khi import/link/relink, lưu danh sách `mdd_paths` đúng theo scanner đã gắn với
bộ; copy mode chỉ lưu các file copy thành công trong bundle, linked filesystem
lưu đường dẫn đã chọn, SAF lưu document URI được cấp quyền. Sắp xếp tên trước khi
đổi thành URI: stem theo chữ, phần không số trước, phần số theo thứ tự số; nếu
trùng key, phần đầu tiên thắng. Không suy đường dẫn từ HTML, không fetch network.
`DictionaryService.readMddResource` chọn theo dictionary ID rồi dùng MDD reader;
lỗi file/quyền/format được truyền ra, không xóa SQLite hoặc giả làm key thiếu.
Chưa gọi API này từ widget, vì parse/index/decompression vẫn chạy isolate gọi;
không diễn giải đây là khả năng hiển thị media cho người dùng.

Manifest cũ không có `mdd_paths` khác với danh sách rỗng xác nhận không có phần:
SAF cũ dùng `source_uris` đã được gắn vào bộ khi import/relink; filesystem cũ chỉ
quét các file thường cùng thư mục, không theo symlink, khớp stem MDX chính xác,
giới hạn 4.000 entry; không tự chọn tên khác hay đệ quy. Vì vậy một số bundle cũ
đổi tên không tự được tìm ra; người dùng có thể reimport/relink. Nguồn đã chọn bị
mất/thu hồi là lỗi, không được bỏ qua để lấy tài nguyên từ bộ khác. Manifest lưu
đường dẫn/URI nên mọi thay đổi nguồn cần relink; chưa có cache hoặc invalidation.

## Giới hạn và tiếp theo

Mỗi lần đọc mở/index lại từng phần tuần tự; có giới hạn của ADR-0029 nhưng chưa
đo thời gian/RAM trên LAAD3 và chưa có cancellation. Cần thiết kế worker isolate
cho cả SAF lẫn filesystem (MethodChannel và vòng đời handle), giới hạn đồng thời,
cache index có invalidation và revocation, rồi tích hợp UI theo dạng allowlist,
giới hạn byte/kích thước giải mã ảnh, lỗi và i18n. CSS sanitizer, hiển thị ảnh,
phát âm thanh, asset rời, network/file/JS vẫn chưa thực hiện. Test synthetic/mock
không chứng minh tương thích MDD thực tế hoặc nghiệm thu Android. Lưu SQLite hiện
có; chưa quyết định kiến trúc MDX trực tiếp.

## Kiểm chứng

CI [43757560968](https://github.com/Pabhassaracitto/In4Up/actions/runs/43757560968)
xanh 4/4 trên `77cb486` (analyze, Rule 5, DICT, I4U18/import và web compile).
PR #189; dữ liệu MDD synthetic, SAF mô phỏng, chưa nghiệm thu thiết bị thật.
Khi copy một phần phụ thất bại, manifest và outcome báo tên phần bị thiếu; MDX
SQLite đã import vẫn dùng được.
