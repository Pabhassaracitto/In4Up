# L2 — Hub nghiệm thu (2026-11-14)

> Nhánh nguồn: `arena/377f5fa5-in4up`, rebase lên tip beta rồi fast-forward — **không merge commit**.
> Kết quả trên beta: `bc8392ac` → `10d58cd8` → `629108bb` → `a9fa7d42` → `bb2ecbfb` → `558e1587`.

## 1. Đã land (5 issue + 1 commit tài liệu của lane)

| Issue | Commit | Nội dung |
|---|---|---|
| **PSRC-202** | `bc8392ac` | Mở file vừa tách từ video; báo rõ khi file đã bị dời/xoá thay vì mở path rỗng |
| **PSRC-203** | `10d58cd8` | Nút chia sẻ phản hồi sau xuất A–B (cổng `share` tiêm được ⇒ test được) |
| **PSRC-205** | `629108bb` | Tạo lời cho audio dài + `.m4a` (chia đoạn, chính sách route transcript) |
| **PSRC-219** | `a9fa7d42` | Linux "could not play this track" — backend media_kit cho `just_audio` |
| **PSRC-220** | `bb2ecbfb` | Linux `.mp4` ở tab View — `video_player_media_kit` |
| — | `558e1587` | "Phát hiện thêm" + bài học CI của lane |

**CI:** `app_analyze` **43588064106** 🟢 · `listen_queue_tests` **43588064123** 🟢 trên `558e1587`.
(4 gói mới resolve được, 232 test media_tools xanh, Rule 5 xanh.)

## 2. Xung đột đã xử lý khi rebase (L7 land trước L2)

L7 (nơi lưu tệp, ADR-0029) và L2 cùng sửa `lib/features/media_tools/widgets/media_export_follow_up.dart`.
Cách hợp nhất — **giữ cả hai, không bỏ bên nào**:

- Enum: dùng `ExportFollowUpChoice` của L2 (có `dismissed`, callback `openInListenTab`/`share` tiêm
  được cho test) và **thêm** thành viên `openFolder` của L7.
- Hộp thoại: giữ nút **"Mở thư mục"** của L7 (đi qua `ExportDestinationService.openContainingFolder`,
  đúng đích đã chọn cho lần xuất đó) đặt trước nút "Chia sẻ".
- Nhánh xử lý: `openFolder` (L7) → `share` (L2, tiêm được) → `open` (L2, kiểm `missingExportFiles`
  rồi mới mở) → `close`/`dismissed`.
- `enum _FollowUp` riêng của L7 bị bỏ (đã hợp nhất vào enum công khai).

Đã kiểm: mọi ký hiệu dùng lại (`result.destination`, `primaryPublicLocalPath`, `primaryFileUri`,
`primaryDisplayPath`, `openContainingFolder`, `missingExportFiles`, `showMissingExportFiles`) đều có
trong cây đã land.

## 3. Quyết định: **không nhúng libmpv**

Câu hỏi của lane: "nhúng libmpv (+10–15 MB) hay chấp nhận cài `libmpv2` một lệnh?".

**Chốt: không nhúng.** Hai lý do, cái thứ nhất là sự thật kỹ thuật chứ không phải sở thích:

1. `media_kit_libs_linux` **không** đóng gói libmpv trên Linux. `linux/CMakeLists.txt` của package
   chỉ tải **mimalloc**, và đặt `media_kit_libs_linux_bundled_libraries` = **chuỗi rỗng** ⇒ libmpv
   phải có sẵn trên máy. Nên "+10–15 MB" không phải giá phải trả để có tính năng; muốn nhúng thì
   phải tự bundle bằng tay.
2. Giấy phép: repo này là **VipSoundSource-Available (Non-Commercial)**; mpv là GPLv2+ ⇒ tự nhúng
   libmpv kéo theo nghĩa vụ phân phối GPL, không đáng cho một tính năng phát media desktop.

Vì vậy giữ đúng thiết kế của lane: dò libmpv (`ldconfig -p` → đường dẫn quen thuộc →
`LD_LIBRARY_PATH`) → có thì phát trong app, thiếu thì thông báo rõ + nút **mở bằng trình phát hệ
thống** (không chặn oan). Yêu cầu gói hệ thống phải nằm trong tài liệu phát hành Linux:

```
Ubuntu/Debian: sudo apt install libmpv2
Fedora:        sudo dnf install mpv-libs
Arch:          sudo pacman -S mpv
```

## 4. Việc hub/lane còn nợ trước cổng G4

1. **`pubspec.lock` chưa cập nhật** (không ai trong sandbox chạy được `flutter pub get`, pub.dev
   không truy cập được từ đây). Lock đã track nhưng **chưa có** `media_kit*` / `just_audio_media_kit`.
   Trước G4 **bắt buộc**: chạy `flutter pub get` trên máy có Flutter rồi commit `pubspec.lock`.
   Không làm thì lần build máy khác có thể resolve phiên bản khác ⇒ lệch hành vi mà không ai thấy.
2. Nhân dịp đó **pin** `media_kit_libs_linux: any` → constraint cụ thể (đọc từ lock sau khi resolve).
3. **Chưa kiểm máy thật Linux**: chưa build/ chạy desktop, chưa thấy video–audio phát thật, chưa thử
   nhánh **thiếu** libmpv, chưa đo size bundle. Đây là nội dung cổng **G3** (owner).
4. `deploy-web` bị `cancelled` nhiều lần là do `concurrency: github-pages` dùng chung cho mọi nhánh
   `arena/**` (lane khác huỷ ngay khi start) — **không phải lỗi code**; bản deploy thành công gần
   nhất của nhánh là `43495886117`. Không cần sửa trong lane này.

## 5. Ảnh hưởng tới L5 (Web & YouTube trên Linux)

L2 đã làm xong phần **phát media** trên Linux (219/220) trong `lib/services/linux_media_backends*`
và `lib/features/video/services/video_playback_support.dart`. **L5 chỉ còn WebView/YouTube màn hình
đen (212/213)** — không sửa lại các file trên, tránh hai lane cùng chạm một backend.
