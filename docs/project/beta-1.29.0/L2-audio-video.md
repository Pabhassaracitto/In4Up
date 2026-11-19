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

1. **PSRC-219/220 không thể "xong tính năng" trong lane này** — gốc là thiếu
   plugin **native**, không phải lỗi Dart:
   - `just_audio` không có backend Linux (`pubspec.yaml` chỉ có
     `just_audio_windows`; `linux/flutter/generated_plugin_registrant.cc` không
     đăng ký trình phát âm thanh nào);
   - `video_player` chỉ có Android/iOS/macOS/Web ⇒ trên Linux/Windows
     `initialize()` ném `UnimplementedError`.
   **ĐÃ CẮM BACKEND THẬT cho Linux** (hub đồng ý 2026-11-13, sau bản sửa "nói
   đúng nguyên nhân"):
   - `just_audio_media_kit: ^2.1.0` + `media_kit: ^1.2.6` +
     `media_kit_libs_linux` ⇒ `just_audio` phát được trên Linux;
   - `video_player_media_kit: ^2.0.0` ⇒ `video_player` phát được trên Linux
     mà **không phải viết lại** màn hình phát video;
   - `lib/services/linux_media_backends*.dart` (facade có điều kiện) +
     `LinuxMediaBackends.install()` gọi trong `main()` trước `runApp`;
   - máy thiếu libmpv hoặc build không có libs ⇒ **giữ nguyên** đường dự
     phòng: nói đúng nguyên nhân + mở bằng trình phát của hệ điều hành
     (`xdg-open`/`explorer`/`open`).

   **Dung lượng tăng (quan trọng cho hub):**
   | Hạng mục | Tăng thêm |
   |---|---|
   | `libmpv` trong bundle Linux | **0 MB** — `media_kit_libs_linux` KHÔNG nhúng libmpv (chỉ bật cờ + link mimalloc tĩnh); media_kit `dlopen("libmpv.so.2")` lúc chạy |
   | Code Dart/plugin (mọi nền tảng) | **≈ +1–3 MB** (ước tính: Dart AOT của media_kit + `media_kit_video` + plugin Kotlin/C++ nhỏ) |
   | Android APK / iOS IPA | **≈ +1–2 MB**, KHÔNG có libmpv: cố ý không khai `media_kit_libs_android_*`/`ios_*` (libmpv ~10–15 MB mỗi ABI) |
   | Windows / macOS | như trên (không khai libs của họ; video Windows vẫn dự phòng mở ngoài) |

   **Phụ thuộc RUNTIME mới trên Linux (bắt buộc):** máy người dùng phải có
   libmpv — `sudo apt install libmpv2` (≈1,1 MB tải / ≈3 MB đĩa, kéo theo
   libav* nếu máy chưa có), `sudo dnf install mpv-libs`, `sudo pacman -S mpv`.
   Không có ⇒ app chạy bình thường ở chế độ dự phòng. Muốn **zero-dependency**
   thì phải tự nhúng libmpv + libav* vào bundle: **+≈10–15 MB tarball**
   (≈30 MB sau khi giải nén) — hub quyết định, lane L2 chưa làm.
   Số đo thật: chưa đo được trong lane (không build được Linux); CI
   `build_final_complete` → job `build-linux` in `ls -lh in4up-Linux-*.tar.gz`
   — so sánh con số đó với bản trước khi land để biết chính xác.

2. **PSRC-205 có hai lỗi nữa trên đường "file dài"** (ngoài phần Linear mô tả),
   đã sửa trong cùng issue:
   - `ChunkAudioExtractor` đặt tên chunk theo phần mở rộng của **nguồn**
     (`.m4a`, `.mp3`) trong khi `cutSegment` luôn ghi `pcm_s16le` ⇒ FFmpeg từ
     chối container ⇒ *mọi* đoạn bị bỏ với nguồn không phải `.wav` (nguồn
     `.wav` không lộ lỗi nên test cũ vẫn xanh);
   - đường VAD **không ghi tệp `.lrc`** (`lrcFilePath` luôn null) ⇒ file dài
     "tạo lời xong" mà không có lời lưu lại, mở lại phải chạy lại hàng chục
     phút và không bao giờ thấy "Đã có lời thoại".
   Đề nghị hub mở issue riêng nếu người dùng còn báo chậm/treo với file >1 giờ
   (lane chưa đo được RAM/CPU trên thiết bị).

3. **Rule #5 còn lỗ ở màn phát video**: 2 nhãn menu ⋮
   (`Tách âm thanh (toàn bộ video)`, `Tách âm thanh từ vị trí hiện tại`) chưa
   có bản dịch. Đã bổ sung và **đưa màn hình vào `_sources`** của
   `test/i18n/dict_pack_and_word_pop_i18n_test.dart`. Đề nghị: file UI mới phải
   được thêm vào `_sources`, nếu không rule #5 chỉ đúng với những file đã có
   tên trong danh sách.

4. **Ba bài học từ CI của lane này** (ghi để lane sau khỏi mất 1 giờ):
   - *Không chặn trước lời gọi nạp theo nền tảng.* Bản nháp PSRC-219 return sớm
     khi `!AudioPlaybackSupport.isInAppSupported` — đúng trên Linux thật nhưng
     làm đỏ 5 test listen-queue, vì **runner CI là Linux** và player trong test
     là mô phỏng. Cách đúng: **phân loại lỗi SAU khi nạp thất bại**
     (`_loadFailureKind()`), run `43487750983`.
   - *Không `await` I/O thật trong `testWidgets`.* `FakeAsync` không chạy event
     loop ⇒ `await Directory.systemTemp.createTemp(...)` / `await File(...)
     .exists()` không bao giờ hoàn tất và `flutter test` **treo im lặng** (không
     cả timeout, vì timeout cũng là Timer bị fake) — run `43488523702` treo 27
     phút ở step AVTOOL. Đã đổi sang `createTempSync`/`existsSync`.
   - *`p.dirname` theo HOST, không theo nền tảng đích.* Test thuần cho nhánh
     Windows (`explorer.exe /select,`) chạy trên CI Linux nhận `'.'` ⇒ lệnh bị
     coi là không dựng được; phải dùng `p.windows.dirname` cho nhánh Windows —
     run `43493960039`.

5. **Chưa kiểm được trên máy thật** (môi trường lane không có thiết bị, không
   build được Linux/Android):
   - `.m4a` 10 phút và file ~1 giờ thật: chưa chạy "Tạo lời" end-to-end, chưa
     đo RAM/CPU;
   - Linux desktop: chưa thấy `xdg-open` mở `.mp4`/audio, chưa thấy hộp thoại
     "máy chưa có bộ phát" trên máy thật;
   - Android/Windows: chưa kiểm lại luồng "tách âm thanh → mở trong tab Nghe"
     sau khi chuyển follow-up về lối vào (`completeExportWithFollowUp`) và
     `explorer.exe /select,` — chỉ có test widget/thuần.

**CI xanh trên nhánh** (run của tip sau khi cắm backend media_kit):
`app_analyze` **43552732479** ✅ (analyze + AVTOOL/media tools, có
`test/media_tools/linux_media_backends_test.dart`, + Rule 5 + toàn bộ step
khác), `listen_queue_tests` **43552732432** ✅.
Lưu ý `deploy-web`: workflow dùng `concurrency: group: github-pages` **dùng
chung cho mọi nhánh `arena/**`** ⇒ deploy của lane này nhiều lần bị nhánh
lane khác huỷ (`cancelled`) ngay sau khi start, không phải do code của L2;
bản deploy thành công gần nhất của nhánh: run 43495886117 ✅.
