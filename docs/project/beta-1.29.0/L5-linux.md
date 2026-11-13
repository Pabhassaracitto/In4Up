# L5 — Web & YouTube trên Linux

**Đọc trước:** `README.md` (§ 2 commit, § 3 file, § 4 DoD). Bản đồ gốc: `../BETA-1.29.0.md` § 2.
**Nhánh:** từ `origin/arena/60e35d65-in4up`. **Không** sửa `KANBAN.md` / `BETA-1.29.0.md`.

## Mục tiêu

Trên Linux: bấm biểu tượng Web và chọn kết quả YouTube phải **hiện hình**, không còn màn hình đen.

> Việc phát `.mp4` / "could not play this track" trên Linux thuộc **L2** — đừng sửa ở đây để tránh hai lane cùng chạm `lib/features/video/**`.

## Issue

| # | Triệu chứng (theo Linear) |
|---|---|
| **PSRC-212** | Biểu tượng Web ⇒ màn hình đen |
| **PSRC-213** | Chọn kết quả YouTube ⇒ màn hình đen |

Đợt 2 (cùng khu vực, không thuộc cổng beta): **PSRC-172**, **PSRC-174** (Linux: quét thư viện không phản hồi — cùng gốc với PSRC-206 của L3, đọc phiếu L3 § 206 trước khi tự nghĩ lại).

## Hướng điều tra

Vùng code: `lib/features/web_reader/**` (`web_reader_screen.dart`, `web_reader_controller.dart`, `js/`), `lib/features/web_core/**`, `lib/features/youtube/**` (`yt_player_screen.dart`, `youtube_explorer_screen.dart`), `linux/**`.

1. Xác định cách hiển thị: Flutter WebView trên Linux thường qua `webview_linux`/`flutter_inappwebview` (WebKitGTK) hoặc chạy trong cửa sổ ngoài. Đọc `pubspec.yaml` + `linux/` để biết backend **trước khi** sửa.
2. Màn hình đen với WebKitGTK thường do: thiếu `webkit2gtk-4.1` runtime, compositing bị tắt trên Wayland (`WEBKIT_DISABLE_COMPOSITING_MODE=1`), hoặc GPU sandbox. Ghi lại phiên bản `webkit2gtk` đã kiểm.
3. YouTube: nếu là `youtube_player_iframe`/WebView thì video HTML5 trên WebKitGTK có thể cần `gstreamer-plugins-bad` (H.264) hoặc bật MSE; kiểm tra console message của WebView (`onConsoleMessage`) để lấy lỗi thật.
4. Nếu không thể hiện hình bằng WebView: phương án dự phòng là mở bằng `mpv`/trình duyệt hệ thống và **nói rõ** trong UI là "mở ngoài" — nhưng chỉ khi đã ghi lý do kỹ thuật.
5. Mọi thay đổi phải có điều kiện `Platform.isLinux`; không làm hồi quy Android/Windows.

## File chạm (dự kiến)

`lib/features/web_reader/**`, `lib/features/web_core/**`, `lib/features/youtube/**`, `linux/**`. Test: phần lớn phải kiểm tay — ghi rõ môi trường (X11 hay Wayland).

## Nghiệm thu

- [ ] Linux + X11: Web reader hiện trang, cuộn được; YouTube phát được hình (hoặc mở ngoài kèm thông báo rõ ràng).
- [ ] Linux + Wayland: ghi lại kết quả (được/không) và biến môi trường cần thiết.
- [ ] Không hồi quy Android: `app_analyze` xanh.
- [ ] Commit body ghi: backend đã xác định, gói hệ thống + phiên bản đã kiểm.

## Không làm

- Không đổi bộ phát của Android/Windows.
- Không bundle thư viện native nặng nếu chỉ cần tài liệu hoá yêu cầu gói hệ thống — nhưng phải ghi vào `docs/`.

## Commit

```
fix(PSRC-212): Web reader không còn màn hình đen trên Linux [L5]
fix(PSRC-213): YouTube phát được trên Linux [L5]
```

## Phát hiện thêm

_(trống)_
