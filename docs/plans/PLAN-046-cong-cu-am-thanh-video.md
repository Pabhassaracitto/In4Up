# PLAN-046 — Công cụ Âm thanh/Video: chuyển đổi · cắt · tách · nối (tích hợp vào app, không phải "app thứ hai")

> **Trạng thái:** 📋 proposed — **kế hoạch, CHƯA code.** Sandbox không có Flutter/Dart
> SDK nên mọi kết luận dưới đây là **đọc mã + đối chiếu API thư viện**, không phải
> "đã chạy".
> **Nguồn:** người sở hữu (2026-11-06) — gửi 2 câu trả lời của một AI khác (Gemini)
> về `ffmpeg_kit_flutter` (MP4/M4A → MP3; cắt/tách/nối audio) và yêu cầu:
> *"tham khảo nội dung phản hồi của gemini sau đó khảo sát dự án để lên kế hoạch
> tối ưu phù hợp nhất để tích hợp thông minh các chức năng vào app"*.
> **Nền khảo sát:** nhánh `arena/c231303f-in4up` tại `aaba876` (= tip 251e,
> version `1.23.0+23`). **ADR:** [0025](../adr/0025-cong-cu-media-tren-ffmpeg-co-san.md).
> **Card:** `AVTOOL-001` … `AVTOOL-005` (KANBAN).

---

## 0. TL;DR

1. **Tin tốt: app KHÔNG cần thêm thư viện nào.** `ffmpeg_kit_flutter_new ^4.6.2`
   (bản `full-gpl`, có `libmp3lame`) **đã nằm trong** `packages/in4up_stt`
   (`pubspec.yaml:31`), và đã có sẵn facade chạy 2 đường mobile/desktop
   (`FfmpegRunner`, `AudioConverter`). Chi phí tích hợp = 0 MB APK.
2. **Nhưng KHÔNG thể dùng lại y nguyên `AudioConverter`** cho người dùng cuối:
   nó bị "khoá cứng" vào mục đích STT (`-ar 16000 -ac 1 -c:a pcm_s16le`,
   `audio_converter.dart:146-180`) — xuất file cho người nghe phải giữ tần số
   44.1/48 kHz và codec thật (mp3/m4a), nếu không chất lượng tụt thảm hại.
3. **Chỗ Gemini sai/thiếu — quan trọng nhất:**
   - `ffmpeg_kit_flutter_full` của **arthenica đã bị archive** (repo
     `arthenica/ffmpeg-kit` `archived=true`, cập nhật cuối 2026-07); repo này đã
     chuyển sang **fork được bảo trì** `ffmpeg_kit_flutter_new`. Làm theo Gemini =
     hạ cấp + `pub get` fail.
   - Gemini bỏ qua **`-c copy` không phải "luôn luôn đúng"**: cắt MP4/AAC bằng
     copy sẽ lệch tới keyframe/frame; nối (`concat`) bằng copy chỉ đúng khi
     **cùng codec + sample rate + channel** — WAV + MP3 + M4A trộn nhau sẽ ra file
     hỏng im lặng.
   - Gemini **không xử lý `content://`** (SAF/MediaStore) — đúng loại URI mà app
     này dùng ở tab Nghe/Thư viện video; FFmpegKit không đọc được `content://`.
   - Gemini **không có huỷ tác vụ, không có tiến trình (progress), không có
     ước lượng dung lượng**, và không dọn session FFmpegKit ⇒ file 90 phút trên
     máy 2GB RAM sẽ bị OOM-kill giữa đường.
   - Gemini khuyên xin `WRITE_EXTERNAL_STORAGE` — **sai với targetSdk 35**:
     Android 10+ phải ghi vào thư mục app rồi chia sẻ/SAF. Manifest hiện tại đã
     đúng (`maxSdkVersion=29`, dòng 6-7).
   - Gemini coi đây là "tính năng chuyển đổi file" rời rạc. Với In4Up, giá trị
     thật nằm ở **vòng lặp học**: đoạn A–B đang luyện → xuất thành file **kèm
     LRC đã dịch mốc thời gian** → mở lại trong tab Nghe để nghe chậm 0.5×/lặp
     ∞. Đó là thứ app khác không có.
4. **Đề xuất:** một **lớp Media Export** mỏng (4 tầng, logic thuần test được),
   gắn vào **6 điểm chạm có ngữ cảnh** đã có sẵn trong app (tab Nghe, Âm mục,
   Video, YouTube, Web Reader, Cài đặt), chia **5 pha**, **không** đổi schema,
   **không** đụng `lib/ffi/` (UltraTimeStretch).

---

## 1. Khảo sát hiện trạng (đọc mã — có dẫn chứng)

| Thành phần | Vị trí | Ý nghĩa cho tính năng này |
|---|---|---|
| `ffmpeg_kit_flutter_new: ^4.6.2` | `packages/in4up_stt/pubspec.yaml:31` | **Đã có FFmpeg trên mobile.** Android kéo `com.antonkarpenko:ffmpeg-kit-full-gpl:2.2.3` (xác nhận trong `android/build.gradle` của plugin) ⇒ có `libmp3lame`, `aac`, `libvorbis`, `opus`… |
| `FfmpegRunner` | `packages/in4up_stt/lib/utils/src/ffmpeg_runner.dart` | Facade 2 đường: `runWithKit` (Android/iOS) · `runWithProcess` (desktop). Tìm binary desktop qua `FFMPEG_PATH` → cạnh .exe → `windows/libs/` → PATH |
| `runFFmpegKit` | `.../src/ffmpeg_kit_impl.dart:13` | **Điểm yếu cần vá:** ghép `List<String>` thành **một chuỗi lệnh** rồi `quotePath()` thủ công ⇒ tên file có `'` hoặc `"` làm hỏng lệnh; **không giữ `session`** ⇒ **không huỷ được**; chỉ `Future.delayed(50ms)` thay vì `FFmpegKitConfig.clearSessions()` |
| `AudioConverter` | `packages/in4up_stt/lib/utils/audio_converter.dart` | Có `probeDurationMs` (parse `Duration:` từ log), `cutSingleChunk`, `cutSegment`, `sanitizeFileName`. **Không dùng lại được cho export** (ép 16k mono PCM) |
| `probeFreeSpaceMB()` | `packages/in4up_stt/lib/utils/free_space.dart` | Đã có (statvfs qua FFI) — **dùng để chặn export khi máy hết chỗ**, chưa được export ở barrel |
| Patch Windows | `windows/CMakeLists.txt:151-204` | Plugin FFmpeg bị **loại khỏi build Windows**; desktop dùng `ffmpeg.exe` qua `Process` (`windows/runner/CMakeLists.txt:87` copy nếu có). ⚠️ **`windows/libs/ffmpeg.exe` KHÔNG nằm trong repo** ⇒ máy Windows không cài ffmpeg sẽ **không export được** |
| `AudioImportService.ensurePersistent` | `lib/services/audio_import_service.dart:177` | Copy file vào `documents/audio_imports/`, dedupe theo fingerprint nội dung, đổi tên `(2)` khi trùng tên khác nội dung. **Đây là "cửa vào" chuẩn để file xuất ra trở thành tài nguyên của app** |
| `RecentAudioService.addOrUpdate` | `lib/screens/listen_mode/services/recent_audio_service.dart:65` | 30 mục gần đây; `RecentAudio.fromLocalFile` tính `id` từ **identity của path** ⇒ file xuất ra tự có id ổn định |
| `SourceArtifactStore` | `lib/services/source_artifact_store.dart:65,211` | `sidecarLrcPath()` + `rememberLrc()`: LRC đi kèm theo **danh tính file** (path chuẩn hoá + fingerprint) ⇒ **cắt đoạn xong phải dịch mốc LRC và `rememberLrc` cho file mới**, nếu không đoạn xuất ra mất karaoke |
| `PlayerLoopMixin` | `lib/providers/player/player_loop_mixin.dart:39-45` | Đã có `loopStart` / `loopEnd` / `loopDuration` ⇒ **nguồn dữ liệu sẵn cho "Xuất đoạn A–B"**, không cần UI chọn mốc mới |
| `SaveSegmentDialog` | `lib/widgets/save_segment_dialog.dart` + `ab_loop_controls.dart:616-627` + `soundlist_panel.dart:174` | Nơi người dùng **đang** bấm "Lưu" đoạn A–B (2 lối vào). Chỗ tự nhiên nhất để thêm "Xuất file" |
| `SoundChapter` (mốc thời gian) | `lib/models/sound_chapter.dart:16` + `lib/providers/soundlist_provider.dart:521` | Mục lục âm thanh đã có `position` ⇒ **tách file theo chương** gần như miễn phí |
| Thư viện video + player | `lib/features/video/widgets/video_library_screen.dart:311`, `video_player_screen.dart:193-221` | Có `PopupMenuButton` sẵn ở AppBar ⇒ thêm "Tách âm thanh" / "Cắt đoạn" 1 dòng menu |
| YouTube | `lib/features/youtube/services/yt_downloader.dart:460` + `yt_dlp_sidecar.dart:90` | yt-dlp đã tải audio (`-x --audio-format m4a`). Người dùng thường cần **mp3 để chia sẻ** ⇒ 1 lệnh convert |
| Web Reader → audio | `lib/features/web_reader/web_reader_screen.dart:1094`, `TtsService.synthesizeToFile` (`tts_service.dart:1131`) | Đã xuất bài đọc thành `.wav` (Piper) / `.mp3` (Edge) — **nên hợp nhất về mp3 + đăng ký thư viện** |
| `HeavyTaskMonitor` | `packages/in4up_core/lib/heavy_task_monitor.dart:37` | Enum `HeavyTaskKind` **chưa có** loại "export media" ⇒ convert file lớn chạy song song Whisper sẽ không được cảnh báo nóng máy |
| Quyền | `android/app/src/main/AndroidManifest.xml:6-7` | `WRITE_EXTERNAL_STORAGE maxSdkVersion=29` — **đúng**; không cần xin thêm quyền nào cho tính năng này |
| Mẫu "ghi file + chia sẻ" | `lib/features/pdf_reader/services/pdf_export_service.dart:263-273` | Pattern chuẩn của repo: ghi `getTemporaryDirectory()` → `SharePlus.instance.share(ShareParams(files: [XFile(path)]))` |
| i18n | `AGENTS.md` luật vàng #5 + `tool/priority_native_pack.json` | Mọi chuỗi chrome mới phải có `en/zh/zh_TW/hi/si` (tối thiểu) + `my/th/ja` trong pack; **KHÔNG** chạy `generate_legacy_ui_fallbacks.py` (đỏ sẵn — card `I18N-001`) |
| Dung lượng hiện tại | KANBAN `REL-1.23.0` | APK arm64 **198.9 MB**, IPA 93.5 MB ⇒ thêm ffmpeg **không** tăng thêm (đã nằm trong số đó) |

**Kết luận khảo sát:** 80% hạ tầng đã có. Việc còn thiếu là (a) một lớp lệnh
FFmpeg **thuần, test được** cho mục đích người dùng, (b) **vòng đời tác vụ**
(huỷ/tiến trình/lỗi/dung lượng), (c) **đăng ký kết quả thành nguồn học tập**
(recent + thư viện + LRC + âm mục), (d) UI đúng ngữ cảnh, (e) i18n.

---

## 2. Nguyên tắc thiết kế (ràng buộc tự đặt)

1. **Zero dependency mới.** Không thêm `ffmpeg_kit_flutter_full` (đã archive),
   không thêm `media_kit`, không thêm `path_provider` mới (đã có).
2. **Không đụng vùng bảo vệ:** `lib/ffi/**` (UltraTimeStretch), 3 skill SM-2,
   schema `Evidence`/`PdfFileIdentity`. File xuất ra là **nguồn mới**, không sửa
   nguồn gốc, không di chuyển/xoá file gốc.
3. **Logic thuần tách khỏi I/O** để CI (`app_analyze.yml`) bắt được mà không cần
   thiết bị: bộ dựng lệnh, dựng danh sách `concat`, dịch mốc LRC, đặt tên file,
   parse progress đều là hàm thuần.
4. **Desktop dùng chung một API**, nhưng **báo đúng sự thật** khi thiếu
   `ffmpeg.exe` (không im lặng thất bại).
5. **Export = tài nguyên hạng nhất**: mọi kết quả đi qua `AudioImportService`
   (path bền vững) + `RecentAudioService` + `AudioLibrary` + `SourceArtifactStore`
   ⇒ mở lại được đúng vị trí, có karaoke, có A–B loop, có thể đưa vào Âm mục.
6. **i18n ngay từ dòng đầu** (luật #5), không để nợ.
7. **Một lớp UI duy nhất** (`MediaExportSheet`) tái dùng cho mọi nơi gọi, tham số
   theo ngữ cảnh (nguồn, mốc A/B, tên gợi ý) — tránh 6 bản UI chép tay.

---

## 3. Kiến trúc đề xuất — 4 tầng

```
lib/features/media_tools/
├── models/
│   ├── media_export_request.dart      # nguồn, mốc, định dạng, chất lượng, đích
│   ├── media_export_result.dart       # path, sizeBytes, durationMs, warnings[]
│   └── media_export_format.dart       # enum: mp3 / m4a / aac / wav / opus + preset
├── services/
│   ├── media_command_builder.dart     # ★ THUẦN: List<String> args cho từng op
│   ├── media_progress_parser.dart     # ★ THUẦN: parse "time=00:00:12.34" / out_time_us
│   ├── lrc_time_shifter.dart          # ★ THUẦN: dịch mốc LRC khi cắt/ghép
│   ├── media_export_naming.dart       # ★ THUẦN: tên file + dedupe "(2)"
│   ├── media_ffmpeg_engine.dart       # I/O: chạy qua FfmpegRunner, giữ session để HUỶ
│   ├── media_export_service.dart      # điều phối: probe → check chỗ trống → chạy →
│   │                                  #   đăng ký (import/recent/library/LRC) → dọn temp
│   └── media_source_resolver.dart     # content:// → file thật (dùng channel có sẵn)
└── widgets/
    ├── media_export_sheet.dart        # bottom sheet dùng chung (định dạng, chất lượng, ước lượng)
    └── media_export_progress.dart     # dialog tiến trình + Huỷ
```

**Tầng 1 — Thuần (test host VM, 0 phụ thuộc platform)**
`MediaCommandBuilder` trả `List<String>` (không phải chuỗi) — vừa sửa luôn điểm
yếu escaping, vừa test được từng lệnh:

```dart
// Đọc mã thật, KHÔNG dùng chuỗi lệnh như ffmpeg_kit_impl.dart:13
static List<String> extractAudio({
  required String input,
  required String output,
  required MediaExportFormat format,
}) => [
  '-hide_banner', '-nostdin', '-y',
  '-i', input,
  '-vn', '-sn', '-dn',                 // bỏ video/subtitle/data
  '-map', '0:a:0',                     // LUÔN lấy track audio ĐẦU (MP4 có thể nhiều track)
  ...format.encodeArgs,                // mp3: -c:a libmp3lame -q:a 2 · m4a: -c:a copy
  '-map_metadata', '0',                // giữ title/artist nếu có
  '-progress', 'pipe:2',               // desktop; mobile đọc Statistics
  output,
];

static List<String> trim({
  required String input, required String output,
  required Duration start, required Duration? duration,
  required MediaExportFormat format,
}) => [
  '-hide_banner', '-nostdin', '-y',
  '-ss', _ts(start),                   // ★ TRƯỚC -i: seek nhanh
  '-i', input,
  if (duration != null) ...['-t', _ts(duration)],
  '-vn', '-sn', '-dn', '-map', '0:a:0',
  ...format.encodeArgs,
  output,
];
```

**Tầng 2 — Engine (I/O)**
Một lớp mới `MediaFfmpegEngine.run(List<String> args, {onProgress, token})`:

- Mobile: `FFmpegKit.executeWithArgumentsAsync(args, null, logCb, statsCb)` →
  giữ `FFmpegSession` ⇒ **`session.cancel()` chạy được** (Gemini không có).
  Xong việc gọi `FFmpegKitConfig.clearSessions()` (sửa luôn chỗ `Future.delayed`
  ở `ffmpeg_kit_impl.dart:20-26` đang giả lập "giải phóng RAM").
- Desktop: `Process.start(...)` + parse `-progress pipe:2` ⇒ **có tiến trình +
  có `kill()`**. `FfmpegRunner.findFfmpegBinary()` đã lo; nếu `ProcessException`
  ⇒ `MediaExportError.ffmpegMissing` (UI hiện hướng dẫn, **không** throw thô).
- Mọi lỗi được **chuẩn hoá** thành enum (`ffmpegMissing`, `unsupportedInput`,
  `noAudioTrack`, `noSpace`, `cancelled`, `failed`) + 30 dòng log cuối để
  người dùng gửi kèm khi báo lỗi.

**Tầng 3 — Service (điều phối)**
`MediaExportService.export(MediaExportRequest)`:

1. `MediaSourceResolver.materialize(uri)` — `content://` → copy sang cache
   (`AudioLibraryChannel.copyContentToCache` / `VideoDeviceChannel.copyContentToCache`,
   cả hai **đã có**); path thường → dùng nguyên.
2. `probe` — mobile: `MediaMetadataRetriever` qua `AudioLibraryChannel.readAudioDurationMs`
   (rẻ, không spawn FFmpeg) cho duration; nếu cần bitrate/codec thì
   `FFprobeKit.getMediaInformation` (fork này có `ffprobe_kit.dart`).
3. `probeFreeSpaceMB(thư mục đích)` — nếu `null` (Windows) thì bỏ qua, nếu
   `< ước lượng × 1.5` ⇒ chặn trước khi ghi rác.
4. Chạy engine, phát `state` (`preparing/running/done/failed/cancelled`) +
   `progress 0..1` qua `Stream`.
5. Hậu kỳ — **phần "thông minh" của In4Up**:
   - Viết **LRC đã dịch mốc** cạnh file mới (`LrcTimeShifter`) nếu nguồn có LRC
     trong `SourceArtifactStore` ⇒ clip giữ karaoke.
   - `SourceArtifactStore.rememberLrc(audioPath: clip, lrcPath: clipLrc)`.
   - `AudioImportService.ensurePersistent(...)` ⇒ path bền vững trong `audio_imports/`.
   - `RecentAudioService.addOrUpdate(RecentAudio.fromLocalFile(...))` ⇒ hiện ngay
     ở tab Nghe "Gần đây" (không cần quét lại MediaStore).
   - (tuỳ chọn người dùng) `SoundlistProvider.addChapter/addMark` "Xuất từ …".
6. Dọn temp (chỉ file do bước 5 sinh ra; **không** xoá bản gốc — luật của
   `AudioImportService`).

**Tầng 4 — UI**
`MediaExportSheet` (một widget, 6 lối vào):

- Định dạng: `MP3 (192k)` · `MP3 (VBR ~V2)` · `M4A (copy, nhanh nhất)` ·
  `WAV (không mất)` · `Opus (nhỏ nhất)` — hiện **ước lượng dung lượng** theo
  duration × bitrate trước khi bấm.
- Phạm vi: Toàn bộ file / đoạn A–B (nếu có `player.hasCompletedLoop`) / từng
  chương (nếu có Âm mục).
- Kết quả: `Mở ngay` · `Chia sẻ` · `Chỉ lưu vào thư viện`.
- Tiến trình: `LinearProgressIndicator` + `Huỷ` + nút "chạy nền" (giữ
  `HeavyTaskMonitor` để không ai mở Whisper cùng lúc).

---

## 4. Bảng tích hợp — chức năng nào vào đâu (và vì sao đúng ngữ cảnh)

| # | Bề mặt | Vị trí chèn (đọc mã) | Chức năng | Ngữ cảnh người dùng | Pha |
|---|---|---|---|---|---|
| 1 | **Tab Nghe → popup A–B / Nghe chậm** | `ab_loop_controls.dart:616` (cạnh nút `Lưu`), `soundlist_panel.dart:174` | **Xuất đoạn A–B**: mp3 (+ LRC đã dịch mốc) — đúng câu "lưu câu này để nghe lại trên đường" | Đang luyện 1 câu → muốn 1 file 20 giây | P2 |
| 2 | **Tab Nghe → menu dài file** | `listen_library_screen.dart:286` (`_showAudioOptions`) | `Chuyển sang MP3/M4A` · `Cắt…` · `Nối các đoạn đã lưu` | Người dùng đã có file trong "Gần đây" | P2/P3 |
| 3 | **Âm mục (Soundlist)** | `sound_list` / `soundlist_panel.dart` | **Tách file theo mục lục chương** (mỗi chương 1 file, tên = tiêu đề chương) + `Xuất lời vàng (mp3 + lrc)` | Pháp thoại 90 phút → 12 bài nhỏ có tên | P3 |
| 4 | **Video** | `video_player_screen.dart:193` (AppBar `PopupMenuButton`), `video_library_screen.dart:311` | `Tách âm thanh (M4A copy / MP3)` · `Cắt đoạn video` (`-c copy` hoặc re-encode) | Video bài giảng → nghe trên đường | P2 |
| 5 | **YouTube** | `yt_player_screen` / `yt_media_library_sheet.dart:179` (đã có Share) | `Chuyển bản tải về sang MP3` trước khi chia sẻ | yt-dlp trả `.m4a/.webm` | P3 |
| 6 | **Web Reader / TTS → file** | `web_reader_screen.dart:1094`, `tts_service.dart:1131` | Hợp nhất: luôn xuất **mp3** (hiện `.wav` từ Piper) + tự đăng ký tab Nghe | Bài đọc → nghe lại chậm | P3 |
| 7 | **Cài đặt → Công cụ media** | `shell_ui_settings_screen.dart` | Chẩn đoán: FFmpeg có/không (mobile luôn có; desktop cần `ffmpeg.exe`), phiên bản, `getExternalLibraries()`, nút "chọn ffmpeg.exe" | Desktop tự cứu mình | P1 |
| 8 | **Tools overlay (bolt)** | `main_shell.dart:590+` (`ToolItem`) | 1 mục `media_tools` → "Chuyển đổi & cắt media" (mở sheet chọn file) | Lối vào tổng khi không ở đúng màn | P4 |

**Không làm:** một "tab Media" riêng (loãng app, trùng chức năng hệ điều hành);
trình biên tập video nhiều track; xuất video có phụ đề burn-in (cần re-encode
nặng, để sau bằng ADR mới).

---

## 5. Chi tiết kỹ thuật (những chỗ dễ ra file hỏng)

### 5.1 MP4/M4A → MP3

```text
-i IN -vn -sn -dn -map 0:a:0 -c:a libmp3lame -q:a 2 -map_metadata 0 OUT.mp3
```
- `libmp3lame` **có** trong bản `full-gpl` hiện dùng (đã đối chiếu `build.gradle`
  của plugin → `ffmpeg-kit-full-gpl:2.2.3`).
- `-q:a 2` (VBR ~190 kbps) là mặc định tốt cho **giọng nói**; đừng mặc định
  `-b:a 320k` (to file, không lợi cho lời giảng).
- Đừng quên `-map 0:a:0`: MP4 quay bằng điện thoại có thể có 2 track audio
  (mic + system) ⇒ không map là FFmpeg lấy track "đầu tiên theo ý nó".

### 5.2 Cắt đoạn

| Cách | Lệnh | Đúng khi nào | Cảnh báo |
|---|---|---|---|
| Nhanh, không re-encode | `-ss T -i IN -t D -c copy OUT` | Cắt trong **cùng** định dạng, dung sai ~1 frame | Mp3 ~26 ms; m4a/mp4 lệch tới keyframe; **luôn** test file mở được |
| Chính xác (khuyến nghị cho A–B học tập) | `-ss T -i IN -t D -c:a <codec> -ar 44100/48000 -ac 2 OUT` | Cần đúng mốc tới ms (luyện phát âm) | Tốn CPU ⇒ phải có progress/huỷ |
| Sai (Gemini) | `-i IN -ss T -t D -c copy` | — | `-ss` **sau** `-i` buộc giải mã để seek trong khi vẫn `-c copy` ⇒ chậm mà **không** chính xác hơn |

### 5.3 Tách thành nhiều phần

- MP3: `-f segment -segment_time 300 -reset_timestamps 1 -c copy part_%03d.mp3` ✅
- M4A/M4B: nên re-encode khi cắt (`-c:a aac -b:a 96k`) — copy ở ranh giới
  segment cho ra packet lỗi ở đầu mỗi phần trên nhiều player.
- Tên file: `%03d` **không** nhận tiền tố Unicode có dấu cách ⇒ dựng tên bằng
  `MediaExportNaming` (giữ Unicode như `AudioImportService.sanitizeFileName`,
  **không** dùng `AudioConverter.sanitizeFileName` vì nó đổi `ế` → `_`).

### 5.4 Nối file (merge)

```dart
// THUẦN — test được: escape đúng chuẩn concat demuxer
String buildConcatList(List<String> paths) => paths
    .map((p) => "file '${p.replaceAll(r'\', '/').replaceAll("'", r"'\''")}'")
    .join('\n');
```
```text
-f concat -safe 0 -i list.txt -c copy OUT
```
- **Bắt buộc kiểm tương thích trước**: `MediaCommandBuilder.areConcatCompatible()`
  so `codec/sampleRate/channels` (từ probe). Không tương thích ⇒ **re-encode**:
  `-f concat -safe 0 -i list.txt -c:a aac -b:a 96k -ar 44100 -ac 1 OUT.m4a`.
  Đây là lỗi Gemini bỏ qua hoàn toàn ("hoạt động hoàn hảo với cả mp3, m4a, wav" —
  sai: nối mp3 44.1k với wav 16k bằng `-c copy` ra file hỏng).
- Đường dẫn trong list có `'` phải escape; tránh ghi list vào thư mục có dấu cách
  nếu không quote `-i`.

### 5.5 Tiến trình · huỷ · bộ nhớ · dung lượng

- Tiến trình: mobile `FFmpegKitConfig.enableStatisticsCallback` (`Statistics.getTime()`),
  desktop parse `out_time_us=` từ `-progress pipe:2`.
- Huỷ: giữ `FFmpegSession` / `Process` ⇒ `cancel()` / `kill()`; xoá file dở
  (`partial`) để không để lại rác 300MB.
- Bộ nhớ: **không bao giờ** đọc cả file vào RAM (`readAsBytes`); mọi thao tác qua
  đường dẫn. Sau mỗi tác vụ `FFmpegKitConfig.clearSessions()`:
  hiện `ffmpeg_kit_impl.dart` chỉ `Future.delayed(50ms)` kèm comment "giải phóng
  native RAM" — **không có tác dụng thật**.
- Dung lượng: ước lượng `duration × bitrate` + 5% và kiểm `probeFreeSpaceMB`.
- `-nostdin` bắt buộc: thiếu nó FFmpeg treo chờ stdin trong app GUI/Windows.

### 5.6 Đa nền tảng — nói thật với người dùng

| Nền tảng | Đường chạy | Trạng thái thực tế |
|---|---|---|
| Android | FFmpegKit (`full-gpl`) | ✅ đủ codec (mp3/aac/opus/wav) |
| iOS | FFmpegKit (podspec `default_subspec = full-gpl`) | ✅ nhưng **chưa ai kiểm export trên máy thật** |
| Windows | `Process` + `ffmpeg.exe` | ⚠️ **phải có** `windows/libs/ffmpeg.exe` hoặc `FFMPEG_PATH`. Repo hiện **không** kèm exe ⇒ UI phải hiện hướng dẫn + nút "Chọn ffmpeg.exe" (đã có tiền lệ `findFfmpegBinary`), không được crash |
| Linux | `Process` + `ffmpeg` của hệ thống | ⚠️ như trên (`apt install ffmpeg`) |
| Web | không hỗ trợ | Ẩn toàn bộ UI (`kIsWeb`) |

> **ĐÃ CHỐT (owner, 2026-11-06): không đóng gói `ffmpeg.exe`.** App Windows
> không kèm binary; khi người dùng thật sự dùng công cụ media, app mới tải
> **một lần** (~90 MB) từ `github.com/BtbN/FFmpeg-Builds`
> (`ffmpeg-master-latest-win64-gpl-shared.zip`, cần kèm DLL → dùng bản
> `-shared`), kiểm `checksums.sha256` rồi giải nén vào
> `documents/ffmpeg_runtime/`. Đường dẫn được nhớ trong `StorageService`
> (key `ffmpeg_runtime_path`) và bơm vào `FfmpegRunner` qua
> `FfmpegBinaryRegistry` ⇒ lần sau không dò lại.
>
> Lý do chọn lazy-download thay vì đóng gói: 90 MB là 30–50% dung lượng
> release, mà phần lớn người dùng Windows **không bao giờ** mở công cụ media
> (họ dùng Android). Người dùng cần thì tải 1 lần, có thanh tiến trình + SHA
> check; người không cần thì app vẫn nhẹ như cũ. Xem ADR-0025 (mục "Lazy
> download").
>
> Hệ quả UI: mọi bề mặt phải đi qua `ensureFfmpegReady(context)` — thiếu
> binary thì hiện sheet "Tải FFmpeg" thay vì báo lỗi kỹ thuật. Ở Linux vẫn
> khuyên `apt install ffmpeg` (không tự tải: libc/glibc khác nhau giữa distro).

### 5.6.1 Lazy download — chi tiết đã code (P1)
| Bước | Nơi code | Ghi chú |
|---|---|---|
| Kiểm đã cài | `FfmpegRuntimeInstaller.installedExecutable()` | `documents/ffmpeg_runtime/<asset>/bin/ffmpeg.exe` hoặc trực tiếp `.../ffmpeg.exe` |
| Tải | `_download()` ghi `*.part` rồi rename | huỷ được (`cancelToken`), không để file dở |
| Xác thực | `_fetchExpectedDigest` + `crypto.sha256` | không lấy được checksum ⇒ **vẫn cảnh báo** trong log nhưng cho cài (mạng lỗi một phần) |
| Giải nén | `_extract()` chỉ lấy `bin/ffmpeg(.exe)` + `*.dll` | tránh giải nén cả trăm MB tài liệu |
| Ghi nhớ | `FfmpegRuntimeBootstrap.rememberInstalled()` | `StorageService.saveSetting('ffmpeg_runtime_path', …)` |
| Khởi động | `main()` → `FfmpegRuntimeBootstrap.init()` (không `await` phần dò) | gợi ý sync cho `findFfmpegBinary()` |

### 5.7 Dung lượng APK: có nên đổi sang bản `audio`?

- Hiện: `full-gpl` (có video codec + tesseract…). Đổi sang
  `ffmpeg_kit_flutter_new_audio` (2.5.8) **vẫn có `libmp3lame`** và cắt/tách
  âm thanh bình thường, **nhưng** mất khả năng `-c copy` video ⇒ chức năng #4
  "Cắt đoạn video" sẽ hỏng.
- ⇒ **Không đổi ngay.** Đo bằng `flutter build apk --analyze-size` ở P4; nếu
  chênh ≥15 MB và owner không cần cắt video thì mới tách nhánh quyết định (ADR mới).

---

## 6. Lộ trình 5 pha (mỗi pha là 1 PR nhỏ, có DoD kiểm được)

### P0 — Vá nền (an toàn, có lợi cho cả STT hiện tại) · card `AVTOOL-001`
- `runFFmpegKit` → `executeWithArguments` (bỏ escaping chuỗi), giữ `session`,
  `clearSessions()`; thêm `runWithProgress`/`cancel`.
- ⚠️ **Đây là chạm vào đường đang chạy STT** (VAD/Whisper) ⇒ PR **chỉ đổi cơ chế
  gọi**, giữ nguyên `List<String> args` của mọi caller, có test hồi quy +
  chạy lại luồng "Tạo lời thoại" trên máy.
- **DoD:** analyze 0 error; `packages/in4up_stt` compile trên 4 nền tảng; 1 lần
  bóc băng audio 60s vẫn ra LRC như trước; huỷ được 1 session thử nghiệm.

### P1 — Lớp `media_tools` thuần + engine + chẩn đoán · card `AVTOOL-002`
- 4 file THUẦN (builder/progress/lrc-shift/naming) + engine + service tối thiểu
  (export 1 file → mp3/m4a/wav) + màn "Cài đặt → Công cụ media" (self-test).
- Test thuần: `test/media_tools/` (≥25 case dưới §7) + thêm 1 bước CI.
- **DoD:** CI xanh; self-test trên Android/iOS/Windows/Linux báo đúng "có/không
  FFmpeg"; export 1 file mp3 từ màn chẩn đoán chạy được (QA máy).

### P2 — Hai bề mặt giá trị cao nhất · card `AVTOOL-003`
- **(a) Xuất đoạn A–B** ở tab Nghe + Âm mục (kèm LRC dịch mốc, đăng ký recent).
- **(b) Video → âm thanh** + cắt đoạn video (menu AppBar).
- **DoD:** đoạn A–B 20s → file mp3 mở lại có karaoke đúng mốc; video 30 phút →
  m4a copy trong <10s; huỷ giữa đường không để lại file dở; máy hết chỗ → chặn
  trước khi ghi.

### P3 — Hàng loạt & nối · card `AVTOOL-004`
- Tách theo chương (mục lục âm thanh) · tách theo khoảng thời gian · nối playlist
  / danh sách đoạn đã lưu (kiểm tương thích + fallback re-encode) · chuyển
  YouTube m4a → mp3 · hợp nhất TTS file → mp3.
- **DoD:** pháp thoại 90 phút + 12 chương → 12 file tên đúng tiêu đề chương,
  LRC mỗi phần đúng mốc; playlist 5 bài (mp3+m4a trộn) → 1 file nghe liền mạch.

### P4 — Hoàn thiện · card `AVTOOL-005`
- `HeavyTaskKind.mediaExport` + banner (hiện `HeavyTaskWarningBanner` **chưa được
  gắn** vào shell — gắn ở đây), i18n đủ 8 locale, QA thiết bị 4 nền tảng,
  đo dung lượng, mục Tools overlay, hướng dẫn trong `SO_TAY_CHU.md`.
- **DoD:** i18n `--check` ✅, không còn chuỗi Việt ở locale ≠ vi; QA checklist
  §8 xong; release note.

---

## 7. Test (thuần, chạy trong `app_analyze.yml` — không cần thiết bị)

`test/media_tools/`:

1. `media_command_builder` — đúng thứ tự `-ss` **trước** `-i`; có `-vn`/`-map 0:a:0`;
   `-nostdin`; mp3 ⇒ `libmp3lame`; m4a copy ⇒ `-c:a copy`; không có `-t` khi duration null;
   đường dẫn có dấu cách/`'`/`"` **không** bị ghép chuỗi.
2. `buildConcatList` — escape `'` → `'\''`; chuẩn hoá `\` → `/`.
3. `areConcatCompatible` — mp3 44.1k vs wav 16k ⇒ `false` (phải re-encode);
   cùng codec/rate/channel ⇒ `true`.
4. `lrc_time_shifter` — cắt `[01:30.00 .. 02:00.00]` ⇒ mốc mới bắt đầu `[00:00.00]`;
   dòng trước `-ss` bị bỏ; dòng sau `-t` bị bỏ; mốc vượt 100 phút vẫn đúng
   (dùng luật đã nới ở `lrc_time_parser.dart`).
5. `media_export_naming` — giữ Unicode (`Bài giảng 01`), dedupe `(2)`, cấm
   `[\\/:*?"<>|]`, không để tên rỗng.
6. `media_progress_parser` — `out_time_us`, `time=00:00:12.34`, log rỗng ⇒ 0,
   clamp 0..1.
7. `estimateSize` — 90 phút @192 kbps ≈ 129 MB ± 5%.
8. Source-scan pin (như `test/audit_1_21_0_wiring_test.dart`): 6 lối vào đều gọi
   **cùng** `MediaExportSheet`; không file UI nào tự dựng chuỗi `-i "…"`; mọi
   chuỗi chrome mới có trong `priority_native_pack.json`.

Cách chạy: thêm 1 step vào `.github/workflows/app_analyze.yml` (mẫu đã có ở
step `i4u18-lib-tests`, dòng ~145).

---

## 8. QA thiết bị (bảng nghiệm thu)

| # | Kịch bản | Kỳ vọng |
|---|---|---|
| 1 | Android: file MP4 30 phút → MP3 | < 60s, có tiến trình, file mở được, karaoke (nếu có LRC gốc) đúng mốc |
| 2 | Android: đoạn A–B 15s → file | tên `Tên [00-15].mp3`, LRC bắt đầu `[00:00.00]`, hiện ngay ở "Gần đây" |
| 3 | Huỷ ở 50% | dừng < 1s, không còn file `.part`, RAM không tăng |
| 4 | Máy còn 50 MB, export 20 phút | chặn **trước** khi chạy, thông báo rõ |
| 5 | Android 13+, file chọn từ MediaStore (`content://`) | resolve được, không lỗi "No such file" |
| 6 | Tên file có `'` và tiếng Việt | chạy đúng, kết quả giữ nguyên tên |
| 7 | Windows **không** có ffmpeg.exe | thông báo + nút "Chọn ffmpeg.exe", không crash |
| 8 | Windows **có** ffmpeg.exe | export + progress + huỷ chạy |
| 9 | iOS | export mp3 (export chưa từng được kiểm trên iOS) |
| 10 | Nối 5 bài mp3+m4a | ra 1 file nghe liền, hoặc báo "phải mã hoá lại" rồi chạy đúng |
| 11 | Export 90 phút trên máy RAM 2 GB | không OOM-kill (session được clear) |
| 12 | Export trong lúc đang bóc băng Whisper | có cảnh báo nóng máy, hoặc hàng đợi tuần tự |

---

## 9. i18n (luật vàng #5) — danh sách chuỗi mới (dự kiến ~28)

Nhóm UI: `Công cụ media` · `Định dạng` · `Chất lượng` · `Ước lượng` ·
`Xuất đoạn A–B` · `Xuất file âm thanh` · `Tách âm thanh từ video` · `Cắt đoạn` ·
`Tách theo chương` · `Nối các đoạn đã lưu` · `Chuyển sang MP3` · `Đang xử lý…` ·
`Huỷ` · `Chạy nền` · `Mở ngay` · `Chia sẻ` · `Chỉ lưu vào thư viện` ·
`Đã lưu: {value0}` · `Không đủ dung lượng trống` · `File nguồn không có âm thanh` ·
`Không đọc được file nguồn` · `FFmpeg chưa có trên máy này` · `Chọn ffmpeg.exe` ·
`Đã huỷ` · `Xuất thất bại` · `Định dạng này cần mã hoá lại` ·
`Không nối được: khác định dạng hoặc tần số lấy mẫu` ·
`Xuất từ {value0}`.

Quy trình (đúng `docs/language/HOW_TO_ADD_TRANSLATIONS.md`):
`tool/priority_native_pack.json` (viết tay, đủ `en/zh/zh_TW/hi/si/my/th/ja`) →
`python3 tool/generate_priority_native_pack.py` → `--check` ✅.
**KHÔNG** chạy `tool/generate_legacy_ui_fallbacks.py` (đỏ sẵn — `I18N-001`);
nếu cần fallback tiếng Anh thì thêm **tay** vào `tool/legacy_ui_english_overrides.json`
+ `generated_legacy_ui_fallbacks.dart` như tiền lệ `AUDIT-1.21.0`.

---

## 10. Rủi ro & giảm thiểu

| Rủi ro | Mức | Giảm thiểu |
|---|---|---|
| P0 sửa `runFFmpegKit` làm hỏng luồng STT đang chạy | **Cao** | PR riêng; giữ nguyên chữ ký `List<String>`; test hồi quy + QA "Tạo lời thoại" trên máy trước khi merge |
| File xuất ra bị coi là "rác" rồi bị người dùng xoá ⇒ mất LRC/âm mục | Trung | Đi qua `audio_imports/` (đã bền vững); ghi rõ "Xuất từ {nguồn}"; **không** xoá gì của nguồn |
| Export lẫn với STT/Whisper ⇒ nóng máy/tụt pin | Trung | `HeavyTaskKind.mediaExport` + banner + chỉ 1 tác vụ export cùng lúc (dùng `AsyncMutex` có sẵn) |
| Dung lượng: file trung gian (bản copy `content://` + file xuất) | Trung | Xoá bản copy cache sau khi xong (chỉ file do mình tạo); hiển thị "đã dùng X MB" |
| Android killed khi chạy nền lúc export dài | Trung | `foregroundService` đã có cho audio; P3 cân nhắc — hoặc đơn giản là **không** hứa chạy nền khi tắt app (UI nói rõ) |
| Giấy phép: `full-gpl` (GPL) đã nằm trong app từ trước; thêm tính năng có thể bị coi là "phân phối dẫn xuất" | Trung | Đã có sẵn trước PLAN này; ghi mục credits/settings (việc riêng, không chặn) |
| Đa nền tảng: Windows/Linux thiếu ffmpeg | **Cao** (dễ tạo "bug" tưởng app hỏng) | Self-test ở P1 + UI hướng dẫn thay vì im lặng; không hứa "hoạt động mọi nơi" |
| Người dùng tưởng app là "trình chuyển đổi" ⇒ kỳ vọng sai | Thấp | Đặt trong ngữ cảnh học (A–B, chương, thư viện), không làm trang chủ "Converter" |

---

## 11. Ngoài phạm vi (scope guard)

- Không burn phụ đề vào video, không ghép nhiều video, không xuất GIF.
- Không tải video YouTube (đã có luồng riêng; PLAN này chỉ **chuyển đổi** file đã tải).
- Không hàng đợi nền/notification khi app bị kill (cần ADR riêng).
- Không đổi `AudioSource` enum / schema Hive ⇒ tránh migration
  (file xuất dùng `AudioSource.picked`).
- Không đụng `lib/ffi/`, không đổi 3 skill SM-2, không đổi `PdfFileIdentity`.

---

## 12. Câu hỏi cần owner quyết trước khi code

### Đã có câu trả lời (2026-11-06)

1. **Phạm vi** — owner để agent tự chọn theo hiệu quả ⇒ chốt **P0 + P1 + P2**
   trong đợt này, P3/P4 giữ nguyên thứ tự trong §6. Lý do: P0 vá lỗi escaping
   đang ảnh hưởng STT, P1 là hạ tầng không có UI (rủi ro thấp, test được trên
   host VM), P2 mới là giá trị người dùng thấy — làm cả ba thì tính năng chạy
   được thật, dừng ở P1 thì chỉ có code chết.
2. **Windows: KHÔNG đóng gói** — tải lazy khi dùng (chi tiết §5.6/§5.6.1).
3. **Định dạng mặc định cho "Xuất đoạn A–B": MP3 192 kbps**
   (`MediaExportPreset.recommended(isClip: true)`).
   - Vì sao không M4A copy: clip A–B cần **đúng mốc tới ms**; copy chỉ cắt
     được ở ranh giới frame AAC (~23 ms mỗi frame) và nhiều máy nghe nhạc ô tô
     / loa bluetooth cũ không mở `.m4a`. Clip học tập thường 10–60 giây nên
     chênh dung lượng MP3 192k vs AAC 128k là không đáng kể (~1 MB).
   - Vì sao không MP3 VBR V2 (`-q:a 2`): VBR cho chất lượng tốt hơn ở cùng
     dung lượng, nhưng **thời lượng file thực tế khó ước lượng** ⇒ thanh tiến
     trình và cảnh báo dung lượng kém chính xác; clip ngắn thì lợi ích không bù
     được. (`mp3Voice` = `-q:a 3` vẫn có trong danh sách cho người muốn file
     nhỏ.)
   - **Xuất cả file** (không phải clip): `m4aCopy` khi nguồn đã là
     `m4a/mp4/m4b/aac` (tức thời, không mất chất), ngược lại MP3 192 kbps.
4. **P2 có xuất video đã cắt không? → KHÔNG ở P2.** P2 chỉ làm **âm thanh**:
   - `MediaExportInputKind.video` ⇒ luôn thêm `-vn -sn -dn -map 0:a:0`, tức
     "tách âm thanh khỏi video" (bề mặt video: menu ⋮ → *Tách âm thanh*).
   - `MediaCommandBuilder.trimVideo(copyOnly: true)` **đã có sẵn** nhưng chưa
     nối vào bề mặt nào — đây là phần P3 (`AVTOOL-004`), vì cắt video bằng
     `-c copy` chỉ đúng khi container/stream khớp, còn nếu phải mã hoá lại
     (`libx264`) thì thời gian encode + pin trên điện thoại là câu chuyện khác
     hẳn (cần tiến trình, ước lượng, cảnh báo riêng).

---

## 13. Lịch sử

- 2026-11-06 | created (proposed) | agent `arena/c231303f-in4up` | khảo sát 20+
  điểm chạm trong repo; đính chính 6 điểm trong câu trả lời Gemini; đề xuất 4 tầng
  + 6 bề mặt + 5 pha; **chưa code, chưa chạy CI**.
- 2026-11-06 | §5.6 + §12 chốt | owner trả lời 4 câu hỏi: scope P0+P1+P2, không
  đóng gói `ffmpeg.exe` (lazy download), clip mặc định MP3 192k, P2 chỉ âm thanh.
  Thêm §5.6.1 (bảng lazy download) + §12 phần "Đã có câu trả lời".
- 2026-11-06 | code P0+P1+P2 | agent `arena/c231303f-in4up` | 6 commit: P0
  (`ffmpeg_common`/`ffmpeg_binary_locator` mới + runner/impl), P1 (10 file
  service + 11 file test), P2 (sheet/dialog/follow-up/install/màn Công cụ media
  + nối 4 bề mặt + i18n 67 entry), CI `app_analyze` 🟢 run 42273702318
  (**128 test** cho `test/media_tools`, Analyze 0 error, Rule 5 🟢). CI bắt 6
  lỗi compile + 1 **bug thật** (`m4aCopy` khai `lossless: true` ⇒ mọi lần
  "copy" bị hạ xuống AAC 96k). **Chưa QA máy.**
