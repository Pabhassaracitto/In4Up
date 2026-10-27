# PLAN-039 — hồ sơ rà soát và nghiệm thu

Ngày 2026-10-28 · nhánh `arena/bf95d3ae-in4up` · ADR-0018.

## Rà soát đang tiến hành

- [x] Đối chiếu yêu cầu hàng đợi phiên, playlist snapshot, mở bài đơn và giữ
  các nút tua ±10 giây trong code.
- [x] Rà soát đường đi lưu vị trí trước đổi path; phân biệt URI gốc và cache;
  không tự gán metadata cũ theo tên; không xóa playlist/file cũ.
- [x] Rà soát guards thế hệ cho nạp bài, stop/pause, completion, A–B và kết
  quả STT/LRC; đã viết fake và test tình huống tương ứng.
- [ ] Chạy `flutter analyze`, test queue/widget/locale và regression trên CI;
  sửa mọi lỗi thật, ghi run và commit. Sandbox không có Flutter/Dart.
- [ ] Review code độc lập (không coi tự rà soát là review độc lập).
- [ ] Build Android để kiểm Kotlin/method channel, rồi thử thiết bị Android:
  URI trùng tên/case, di chuyển, mất quyền/dọn cache, dữ liệu cũ, file lớn,
  tai nghe, pause/loop, chuyển tab, cỡ chữ lớn và bố cục hẹp.
- [ ] Nghiệm thu picker và đường dẫn ở Windows/iOS theo nền hỗ trợ thực tế.

## Rủi ro cần theo dõi

1. Cache cũ thiếu bằng chứng nguồn: không tự đoán. Nhiều LRC mồ côi không được
   tự chọn; vẫn còn trên disk để khôi phục thủ công.
2. Hàng đợi chỉ trong phiên; không có hợp đồng phát nền sau process death.
3. Generator legacy English báo 328 override dư; đối chiếu chạy riêng trên
   commit nền `0556f82` cũng báo đúng cùng 328 mục. Priority native pack mới
   đã kiểm `--check`; không tự xóa 328 override lịch sử.
4. Code/test chưa được Flutter analyzer hoặc thiết bị xác thực. Không đóng card
   hoặc phát hành chỉ dựa trên hồ sơ tự rà soát này.

### Cập nhật kiểm tra 2026-10-28

- `git archive 0556f82` + chạy generator legacy trong thư mục riêng: 328
  override dư là đúng cùng tập với hiện tại; 2 override mới dư do bỏ UI cũ đã
  được loại khỏi catalog nguồn.
- Workflow web tự chạy trên `arena/**`; lần chạy `40571504045` đã bị hủy ở
  bước build, **bước publish bị skipped**. Chốt trên nhánh này ngăn các lần
  deploy nhầm tiếp theo (`40571610056` skipped). Không coi đây là build app.
- Đường khôi phục path cache cũ chỉ dựa basename không chứng minh đúng file;
  nay báo thiếu để người dùng chọn lại thay vì tự phát sai bài. Dữ liệu cũ
  không bị xóa. Đã bổ sung test và cần chạy CI.

### Bổ sung bảo vệ recent 2026-10-28

Lịch sử file local trên Android/Linux phân biệt hoa/thường; ID case-fold cũ
được chuyển khi path khớp chính xác, không gộp hai file khác nhau. Path ổ đĩa
Windows vẫn so khớp không phân biệt hoa/thường. Đã bổ sung test migration;
workflow matrix `listen_queue_tests.yml` tách từng file và giới hạn thời gian.

### Kết quả CI đầu tiên (chưa phải nghiệm thu)

- Run `40572507622` tại `f86782b`: bốn job controller, recent, i18n và LRC
  xanh; integration đỏ và widget chưa hoàn tất tại lúc ghi. Fake cũ dùng sync
  stream nên không cho phát event lồng trong A–B; đang đổi fake giống stream
  bất đồng bộ thực tế và chạy lại. Analyzer run `40572173042` tại `49fe8ee`
  qua; chưa áp dụng kết luận cho thay đổi mới hơn.
- Bổ sung xếp hàng ghi vị trí và chờ ghi xong trước khi resume cùng nguồn;
  test có gate giả lập ghi chậm cần chạy lại.

### CI bắt lỗi teardown 2026-10-28

Run `40572934537` ở `9ea11c1` còn một integration failure: facade STT bị
`dispose` trước khi tạo `_nativeEngine` trong seam không khởi tạo STT. Đã thêm
lifecycle guard, đồng thời thay await không bơm fake clock trong widget test
bằng các lượt pump có giới hạn; cần chạy lại để xác nhận, không coi lỗi đã hết.

### Khôi phục lời mồ côi có xác nhận

Khi người dùng mở thao tác tạo lời, LRC basename/fingerprint chưa có index
được liệt kê để **tự chọn** hoặc tạo mới; lời đã gắn với nguồn khác không được
đề nghị như mồ côi. Đã thêm test kho dữ liệu, còn cần chạy CI và thử dialog
trên máy. Nếu URI từng gắn dữ liệu cũ sau đó trả bytes khác, cache cũ không bị
thay thế; nguồn mới dùng cache riêng và hiển thị cảnh báo không liên kết.

### CI 2026-10-28 — kết quả ở `abc8d83`

- `40573703924`: bước `flutter analyze` và test logic thư viện I4U18 qua;
  các bước còn lại không được coi là hoàn tất trong khi run còn chạy.
- `40573703977`: năm job controller, integration playback, recent, i18n và
  source-artifact qua; widget test hết timeout ở test đầu. Đang điều tra việc
  widget test bị treo trong môi trường fakeAsync; không bỏ test khỏi CI.
- Thêm bước compile Kotlin độc lập của resolver với Android SDK; không tương
  đương build Gradle, chưa xác nhận method channel hoặc máy Android thật.

### Chẩn đoán widget test

Run `40574195687` đã compile resolver Kotlin độc lập thành công (không phải
build APK). Trace cho thấy body widget test đầu chạy xong, nhưng teardown kẹt
khi chờ ghi Recent do future được tạo trong fakeAsync đã ngừng bơm. Thêm seam
để widget test dùng bộ ghi Recent giả; integration/recent test vẫn dùng kho
thật giả lập. Cần chạy lại trước khi kết luận.

Run `40574822757` tại `46a1b75`: cả sáu nhóm test PLAN-039, gồm widget,
và compile resolver Kotlin độc lập đều đạt. Sau đó sửa thêm chiều cao
mini-player: margin không được cắt phần điều khiển; có thêm assertion cho chế
độ micro/medium. Cần chạy lại trên commit mới; Android Gradle, thiết bị thật và
review độc lập vẫn chưa có bằng chứng.

Run `40575121791` phát hiện assertion chiều cao sai sau thay đổi `ac5f578`:
`Container.margin` được thêm bên ngoài chiều cao nội dung, không chiếm chiều
cao đó. Đã hoàn nguyên thay đổi chiều cao, giữ test kích thước/hit-test.
Run rộng `40574822791` còn phát hiện `isInsideImports` tạo thư mục dù file
đã ở vị trí bền; đổi phép kiểm tra thành không tạo thư mục, vẫn giữ test cũ.
Cần xác nhận CI mới trước khi kết luận.
