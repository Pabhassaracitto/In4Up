# ADR-0029 — Đọc tài nguyên MDD có giới hạn trước khi tích hợp renderer

- Trạng thái: đề xuất triển khai từng bước; cần code review và QA thiết bị.
- Bối cảnh: ADR-0028, DICT-SOURCE-001 và yêu cầu bộ LAAD3 MDD khoảng 1,22 GB
  cùng các phần phụ; không thay pipeline định nghĩa SQLite, chưa quyết định MDX
  trực tiếp. PR #186 đã merge vào 251e tại `f46a54a`.

## Quyết định

Bổ sung lõi đọc MDD 2.0 không mã hóa thông qua `RandomAccessSource`, đọc index
khóa và metadata record có trần; chỉ giải nén block chứa tài nguyên được yêu
cầu. Checksum và kích thước đều được kiểm tra, zlib giải nén có giới hạn đầu ra.
Không coi đường dẫn trong từ điển là đường dẫn hệ thống; từ chối traversal, URL,
percent encoding và các key không an toàn. `MddParts` tìm các phần theo thứ tự
caller cung cấp, đóng từng handle kể cả lỗi; lỗi không biến thành “không tìm thấy”.
`MddReader` có thể dùng lại index trong vòng đời source, nhưng source có vị trí
đọc mutable nên caller phải serialize và chịu trách nhiệm đóng. Cách dùng multipart
hiện mở/index lại từng phần mỗi lần để giới hạn lifetime/bộ nhớ; chưa tối ưu.

Trần hiện tại: 250.000 key, 65.536 block, 16 MiB metadata/block, 8 MiB mỗi asset,
64 part; các trần là policy an toàn, có thể từ chối bộ hợp lệ. Với SAF, adapter
đọc cache 4 trang × 64 KiB; không chứng minh mức RAM tổng ứng dụng chỉ 16 MiB
(index Dart, buffer nén/giải nén và overhead vẫn tồn tại). Giải nén hiện chạy trên
isolate gọi, không được nối vào UI trước khi có chiến lược offload/cancellation.
Chỉ engine 2.0 + block raw/zlib, không LZO/mã hóa; mọi biến thể chưa hỗ trợ phải
báo lỗi, không silently fallback. Không dùng file sample bên ngoài làm fixture.

## Kiểm chứng và việc còn lại

Test dùng binary synthetic, kể cả block cắt giữa asset, hai phần, mock SAF, lỗi,
traversal, checksum và trần asset; chưa khẳng định tương thích toàn bộ MDD hay bộ
LAAD3, chưa đo hiệu năng hoặc thử quyền SAF thực tế. Lõi chưa được DictionaryService
hay widget gọi: **chưa hiển thị ảnh, âm thanh hay CSS**. Tiếp theo: kiểm thử nhiều
MDD thật hợp pháp/biến thể, cách tìm phần theo bundle/path/SAF và relink, xác định
precedence/duplicate, cache index có invalidation theo identity/permission, isolate,
huỷ và trần tổng, cấp loại tài nguyên allowlist và giới hạn kích thước ảnh; thiết
kế CSS subset/sanitizer và renderer sandbox không JS/network/file, accessibility,
playback lifecycle, missing/error UI và i18n. Xác thực LAAD3 1,22 GB và các phần
trên máy thật; đo RAM, thời gian cold/warm và không gây jank, test thu hồi quyền.
Không mở file/URL tùy ý, không sửa hoặc xóa nguồn người dùng.
