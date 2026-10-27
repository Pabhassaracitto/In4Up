# ADR-0018: Hàng đợi phát theo phiên cho tab Nghe

- **Ngày:** 2026-10-28
- **Trạng thái:** Đang triển khai trên `arena/bf95d3ae-in4up`; chờ analyzer,
  test CI, review độc lập, build và nghiệm thu thiết bị.
- **Phạm vi:** PLAN-039; không thay schema playlist lưu bền hay engine FFI.

## Bối cảnh

Chủ dự án duyệt phát liên tiếp nhiều bài từ bộ chọn file, kết quả lọc thư
viện và playlist; nút bài trước/sau phải khác nút tua ±10 giây. Player cũ nạp
một file mỗi lần và dùng path để lưu vị trí, Âm mục và LRC. Chuyển sang native
playlist trực tiếp có nguy cơ bỏ qua các bước nạp/reset/lưu theo nguồn.

## Quyết định

1. `PlayerProvider` sở hữu controller hàng đợi **chỉ trong phiên**, là bản
   chụp có thứ tự; playlist có tên vẫn là dữ liệu độc lập. Mỗi lần phát trực
   tiếp bên ngoài tạo queue một bài. Bài mất giữ placeholder, không xóa nguồn.
2. Bộ điều phối tuần tự và generation vô hiệu kết quả nạp cũ; chỉ commit bài
   sau khi nạp thành công. Tự chuyển và nút chuyển bắt đầu ở 0; mở trực tiếp
   tiếp tục vị trí đã lưu. Chuyển thủ công giữ ý định phát/tạm dừng. Repeat,
   A–B và đoạn có ưu tiên trước khi tự chuyển; hết hàng đợi thì dừng.
3. Ghi vị trí bài ra trước khi đổi nguồn. Phân biệt URI gốc và bản cache; trên
   Android cache mới theo SHA-256 URI, copy streaming nền. Không tự gán dữ liệu
   cache cũ chỉ vì trùng tên/nội dung: giữ nguyên và hỏi người dùng khi có thể
   liên kết. Không xóa dữ liệu cũ. URI phân biệt hoa/thường.
4. LRC mới lưu theo khóa nguồn thay vì tên file chung. Index ưu tiên liên kết
   theo path đầy đủ, không tự nhận LRC mồ côi qua basename/fingerprint; giữ
   file mồ côi để khôi phục có chủ đích. LRC/diarization cũ có index theo path
   hoặc sidecar vẫn được tìm; kết quả STT cũ bị chặn theo thế hệ nguồn.
5. Dùng port audio giả trong test; thao tác `play()` không chờ future kết thúc
   cả bài. Không hứa phát gapless, khôi phục queue sau restart, shuffle, hoặc
   phát nền sau khi OS kết thúc tiến trình.

## Hệ quả và đánh đổi

- Có khoảng chờ nạp giữa các bài; quyền MediaStore bị thu hồi có thể làm bài
  không phát được. Bỏ qua lỗi có giới hạn, báo lỗi và không sửa playlist gốc.
- Cache và LRC cũ mơ hồ được giữ lại thay vì tự đoán; có thể cần thao tác
  người dùng hoặc phục hồi thủ công, đặc biệt khi có nhiều LRC mồ côi.
- Chưa khẳng định native bridge, hiệu năng file lớn, tiếp tục sau xóa cache,
  accessibility thực tế, hay tai nghe/lifecycle đến khi kiểm thiết bị.
- Các test đã viết và bước workflow là kế hoạch xác thực, không phải bằng
  chứng đã chạy. Xem `docs/project/PLAN-039-review.md` và card PLAN-039.

### Bổ sung 2026-10-28 — file import mồ côi

Path cũ đã mất không tự khớp sang file import chỉ theo basename; người dùng
cần chọn lại nguồn thay vì có nguy cơ mở nhầm bài khác cùng tên. Dữ liệu và
file cũ vẫn giữ nguyên.
