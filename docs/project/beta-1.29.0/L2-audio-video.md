# L2 — Âm thanh & video

**Đọc trước:** `README.md` (§ 2 commit, § 3 file, § 4 DoD). Bản đồ gốc: `../BETA-1.29.0.md` § 2.
**Nhánh:** từ `origin/arena/60e35d65-in4up`. **Không** sửa `KANBAN.md` / `BETA-1.29.0.md`.

## Mục tiêu

Mọi thao tác xuất/tách/tạo lời phải **kết thúc được** (có file thật, mở được ngay, chia sẻ phản hồi), báo lỗi FFmpeg có nguyên nhân, và trên Linux phát được `.mp4` / không còn "could not play this track".

## Issue

| # | Triệu chứng (theo Linear) |
|---|---|
| **PSRC-202** | Âm thanh tách từ video không tự mở, rồi bị "dish" |
| **PSRC-203** | Chia sẻ sau khi xuất A–B không phản hồi (kiểm cả tab Video) |
| **PSRC-205** | Tạo lời cho file audio dài + hỗ trợ `.m4a` |
| **PSRC-219** | Linux: "could not play this track" |
| **PSRC-220** | Linux: `.mp4` ở tab View không phát |

Đợt 2 (cùng khu vực): **PSRC-180** (tạo lời lỗi FfmpegKit), **PSRC-179** (khoảng lặng nút AB), **PSRC-195** (xuất file kẹt "Estimating duration…").

## Hướng điều tra

Vùng code: `lib/features/media_tools/**` (`media_export_service`, `media_export_actions.dart`), `lib/features/video/**`, `lib/screens/listen_mode/**` (player + tạo lời), `linux/**`.

1. **202**: sau khi FFmpeg ghi xong, mở bằng `path` trả về hay bằng đường dẫn cũ? Kiểm tra `await`, và trên Android phải refresh media store (content URI) thì app ngoài mới thấy.
2. **203**: `Share.shareXFiles` sau `await` dễ mất `BuildContext` ⇒ thiếu `if (!mounted) return;` hoặc file đã bị xoá. Kiểm tra cả tab Video.
3. **205**: `.m4a` = AAC/MP4; xác nhận extension map đúng demuxer và tạo lời theo **đoạn** cho file dài (không nạp cả file vào RAM).
4. **219/220**: xác định backend phát trên Linux (đọc `pubspec.yaml` + `linux/`), rồi kiểm tra: thiếu plugin container (H.264/AAC), `hwdec` không khả dụng (`hwdec: no` để khoanh vùng), log stderr khi phát. Mọi sửa đổi phải có điều kiện `Platform.isLinux`.
5. Đợt 2 — **195** nên làm sớm nếu hub cho phép: "Estimating duration…" là bước probe không bao giờ trả (file lớn/codec lạ) ⇒ cần timeout + fallback.

## File chạm (dự kiến)

`lib/features/media_tools/**`, `lib/features/video/**`, `lib/screens/listen_mode/**`, `linux/**`. Test: `test/media/*`, `test/video/*`; phần Linux ghi rõ "kiểm tay trên Linux".

## Nghiệm thu

- [ ] Máy thật Android: tách âm thanh → file có trong nơi lưu mặc định (ADR-0029) và mở được ngay.
- [ ] Nút chia sẻ mở sheet ngay sau xuất A–B, cả tab Nghe và tab Video.
- [ ] `.m4a` 10 phút tạo lời được, chia đoạn; ghi số đo RAM nếu đo được.
- [ ] Linux: `.mp4` H.264 phát được hình + tiếng; file lỗi báo rõ nguyên nhân.
- [ ] `flutter analyze` 0 error; `app_analyze` + `listen_queue_tests` xanh.

## Không làm

- Không đổi nơi lưu file — theo **ADR-0029** (`docs/adr/0029-…`), chỉ *dùng* "Đổi…" từng lần xuất.
- Không viết lại toàn bộ pipeline FFmpeg.

## Commit

```
fix(PSRC-202): mở file âm thanh vừa tách từ video [L2]
fix(PSRC-203): nút chia sẻ phản hồi sau xuất A–B [L2]
feat(PSRC-205): tạo lời cho audio dài và .m4a [L2]
fix(PSRC-219): sửa "could not play this track" trên Linux [L2]
fix(PSRC-220): phát .mp4 ở tab View trên Linux [L2]
```

## Phát hiện thêm

_(trống)_
