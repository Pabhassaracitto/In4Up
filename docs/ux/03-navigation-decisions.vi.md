# I4U UX — Quyết định điều hướng

> Trạng thái: bản nháp v0.1 — các quyết định đã thống nhất và các điểm cần kiểm chứng bằng mockup.

## Quyết định hiện tại

### Navigation cấp 1

```text
Home — Đọc — Nghe — Hiểu — Nhớ
```

- `Đọc` đứng trước `Nghe` trong thứ tự mặc định.
- Thứ tự mặc định không ngăn người dùng bắt đầu từ Nghe hoặc trở lại workspace gần nhất.
- `Xem` không phải tab cấp 1; là media mode/source trong `Nghe`.
- `Chat` là capability global, không phải tab thứ sáu.
- `Học thuộc` thuộc workspace `Nhớ`.

### Navigation cấp 2

- Đọc: `Đọc | Viết`.
- Nghe: `Nghe | Xem` hoặc nhãn tương đương sau khi kiểm thử.
- Nhớ: các khu vực `Ôn tập | Học thuộc | Từ vựng | Bài tập | Thống kê`, cần quyết định cách trình bày.

### Điều hướng theo nền tảng

- Mobile: bottom navigation.
- Tablet: navigation rail.
- Desktop/Web: collapsible sidebar.

## Những điều không nên làm

- Không đưa toàn bộ Tools vào navigation cấp 1.
- Không yêu cầu long-press là con đường duy nhất để tìm mode phụ.
- Không để panel hoặc tool mở làm mất ngữ cảnh workspace.
- Không dùng `Thấy` làm nhãn workspace thay cho `Đọc`.

## Cần kiểm chứng trong Stitch

- Sidebar desktop mở rộng/thu gọn.
- Bottom navigation khi có mini player.
- Context bar trên mobile hẹp.
- Cách thể hiện Nhớ với nhiều khu vực con.
