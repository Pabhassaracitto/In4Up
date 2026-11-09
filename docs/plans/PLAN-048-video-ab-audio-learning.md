# PLAN-048 — I4U Tab Video: A–B loop và luyện nghe bằng audio engine

> **Trạng thái:** 🔨 doing — V1 A/B thủ công + V2 lặp câu đã được nối vào player; đã thêm entry point export range A/B (một phần V3). Unit tests mới đã thêm, chờ chạy Flutter CI và QA thiết bị.
> **Ngày khảo sát:** 2026-11-09. Phạm vi là video local trong In4Up, không phải YouTube.
> **Liên quan:** `VID-001`, `I4U18-VIDEO-LIB-001`, `AVTOOL-003`; PLAN-025 gốc được ghi trong KANBAN nhưng hiện không có file PLAN-025 riêng.

## 1. Mục tiêu

Hoàn thiện Tab Video thành công cụ luyện nghe, không chỉ là player xem file:

1. Đặt hai mốc A/B thủ công, lặp đúng đoạn đang luyện và xóa/đặt lại dễ dàng.
2. Dùng câu phụ đề hiện tại làm đoạn lặp một chạm (khi file có phụ đề).
3. Tận dụng quy trình audio In4Up tốc độ chậm/chất lượng cao khi cần nghe kỹ, nhưng không tuyên bố engine đã xử lý trực tiếp tiếng video cho đến khi đường âm thanh realtime được kiểm chứng.
4. Giữ nguyên khả năng xem, phụ đề, resume, thư viện và xuất audio đã có.

**Định vị:** VLC/mpv là chuẩn tiện ích media; lợi thế In4Up nên là vòng lặp *video → phụ đề/câu → luyện nghe sâu → lưu lại thành tài nguyên học*, không phải chép mọi tuỳ chọn của media player.

## 2. Khảo sát nội bộ

| Hiện trạng | Bằng chứng trong repo | Kết luận / khe hở |
|---|---|---|
| Thư viện video local, SAF/MediaStore, ghép phụ đề, recent/favorite, resume | `lib/features/video/models/video_info.dart`, `video_library_service.dart`, `video_library_logic.dart`; card `I4U18-VIDEO-LIB-001` trong `docs/project/KANBAN.md` | Nền thư viện đã có; cần giữ các ID/URI và lịch sử hiện tại. |
| Player có play/pause, ±10s, seek bar, 0.5×–2× và resume vị trí | `lib/features/video/widgets/video_player_screen.dart`, dùng `VideoPlayerController` | Tốc độ hiện tại là `controller.setPlaybackSpeed`; không có A/B state/loop. Chưa thấy auto-pause/loop theo subtitle trong local player. |
| Phụ đề parse SRT/VTT/ASS/SSA/SUB/LRC thành cue có `start/end` | `lib/features/video/services/subtitle_parser.dart` | Có sẵn dữ liệu thời gian cho “lặp câu hiện tại”; parser là pure Dart và có thể kiểm thử riêng. |
| Xuất audio toàn video/đoạn từ player đã có | `lib/features/media_tools/media_export_actions.dart` → `exportAudioFromVideo`; menu hiện tại ở `video_player_screen.dart` | Không cần xây converter mới cho bản đầu. Đã có đường xuất clip; cần nối UX “tiếp tục luyện trong tab Nghe” và xác minh đường mở lại. |
| Audio player có `UltraEngineFFIV2`, dải tốc độ 0.05×–10×; `AudioPlayerService` đồng thời điều khiển `just_audio` | `lib/ffi/ultra_engine_ffi_v2.dart`, `lib/audio/audio_player_service.dart` | Có hạ tầng xử lý/tốc độ audio trong app. Tuy nhiên **không thấy `processAudio()` được gọi ở bất kỳ call-site nào ngoài khai báo FFI** (`grep` repo 2026-11-09); `setSpeed()` gọi engine và `just_audio.setSpeed()`. Cần kiểm chứng thực tế trước khi gọi đây là DSP output áp dụng cho mọi audio. |
| Video không đi qua UltraTimeStretch | `video_player_screen.dart` chỉ gọi `VideoPlayerController.setPlaybackSpeed`; không inject audio sink/PCM | Chưa thể tái sử dụng engine trực tiếp chỉ bằng cách thêm một nút. Ghép một audio renderer khác với hình ảnh đòi hỏi mute track gốc, demux/decode PCM, đồng bộ clock/seek/pause/rate và chống drift. Đây là spike riêng, không gắn vào A/B MVP. |
| Phụ thuộc video hiện tại | `pubspec.yaml` dùng `video_player`; `pubspec.lock` có Android/iOS/AVFoundation/Web nhưng không có plugin Windows/Linux | Không giả định coverage desktop. Cần ghi rõ platform thực sự chạy được; Windows/Linux là gate riêng trước khi hứa hỗ trợ. |
| FFmpeg/export | PLAN-047 + ADR-0026; `lib/features/media_tools/` đã có export/cancel/progress/lazy desktop runtime | Tái sử dụng các dịch vụ hiện có; không thêm dependency hoặc tự dựng command FFmpeg ở UI. |

### Kết luận nội bộ

- **A–B local video là phần còn thiếu rõ ràng và làm được trước**, dùng clock/seek player hiện tại.
- “Tốc độ 0.5×–2×” sẵn có là playback speed của backend video, không đồng nghĩa với chất lượng UltraTimeStretch của Tab Nghe.
- Có thể ship sớm luồng an toàn **xuất đoạn A–B → mở ở Tab Nghe**. Luyện âm thanh thời gian thực với hình ảnh đồng bộ là mục tiêu sau, có điều kiện kỹ thuật.
- Không sửa `lib/ffi/`, C++ UltraTimeStretch hay kiến trúc audio playback nền trong phase này.

## 3. Khảo sát ngoại bộ

| Sản phẩm / nguồn | Pattern quan sát được | Bài học cho In4Up |
|---|---|---|
| [VLC for Android — tài liệu player](https://docs.videolan.me/vlc-android-user/video/video_player.html) | Có A–B repeat trong nhóm điều khiển video; tài liệu cũng chỉ rõ chọn audio/subtitle track và chỉnh audio/subtitle delay. | A/B phải dễ tìm trong lúc xem; marker và trạng thái lặp phải nhìn thấy, đồng thời vẫn có hành động xóa/reset. |
| [mpv — manual chính thức](https://mpv.io/manual/master/) | A/B là hai timestamp; playback seek về A khi vượt B; có đếm vòng lặp; hỗ trợ speed/pitch correction qua audio filter và thao tác subtitle seek. | Mô hình range `A < B` là đơn giản, dễ test. Nên tách repeat vô hạn/lặp có số lần và tránh xử lý vòng lặp bằng timer độc lập với media clock. |
| [Language Reactor — trang chính thức](https://www.languagereactor.com/) | Nhấn mạnh subtitle tương tác, precise playback, speed, keyboard/gesture, auto-pause đến khi người học tiếp tục, từ điển và vocabulary tools. | Điểm khác biệt học ngôn ngữ là cue-aware controls + từ vựng, không chỉ A/B. Ưu tiên “lặp câu” và điều hướng từ phụ đề sau khi A/B thủ công chạy ổn. |
| [Flutter `video_player` — tài liệu package chính thức](https://pub.dev/packages/video_player) | Plugin video surface dùng native backend; speed qua `setPlaybackSpeed`; docs công bố Android/iOS/macOS/Web, và khả năng format/phát trên Web phụ thuộc browser. | Giữ API hiện tại cho MVP, kiểm tra từng nền tảng; không giả định video_player cấp PCM samples để xử lý bằng UltraTimeStretch. |

### So sánh cơ hội

| Năng lực | VLC/mpv | Language Reactor | In4Up hiện tại | Đề xuất |
|---|---:|---:|---:|---|
| A–B thủ công trong video local | Mạnh | Có replay/precise controls | Chưa có | Bổ sung ngay |
| Tạo loop từ cue phụ đề | Có thao tác theo subtitle ở mức player/keyboard | Mạnh về subtitle line | Cue parser + overlay sẵn | Là ưu tiên học tập kế tiếp |
| Tra từ/lưu từ theo ngữ cảnh | Hạn chế/cần plugin | Có | Đã là mục tiêu VID-001; các bề mặt video hiện có | Giữ sâu liên kết video + timestamp + cue |
| Audio slow/high-quality của In4Up trong video đang phát | Không phải lợi thế In4Up | Không phải lợi thế cốt lõi | Chưa tích hợp vào player video | Spike đồng bộ; trước mắt xuất clip sang Tab Nghe |
| Offline/local-first | Có | Một phần qua web/extension | Có, thư viện local | Giữ local-first, không gửi media lên server |

## 4. Đề xuất UX

### 4.1 Player cơ bản — A–B

- Thêm nhóm điều khiển gọn **A · B · Clear** trong chrome player đang hiện (không tạo tab/màn hình mới).
- Tap **A**: lưu vị trí hiện tại, hiện marker A + trạng thái “chờ B”. Nếu đã có B, đặt A mới sẽ xóa B cũ.
- Tap **B**: hợp lệ khi `B > A` và độ dài tối thiểu 300 ms; bật loop và seek về A. Nếu thiếu A, lần bấm đầu đặt A thay vì báo lỗi.
- Đến B: dùng position từ `VideoPlayerController` để seek về A; tránh seek lặp liên tục trong cùng một lần vượt ngưỡng.
- Hiển thị badge `A 00:12.4 → B 00:16.8 · Lặp` cùng Clear. Clear giữ nguyên playhead, không tự seek.
- Hỗ trợ progress bar kéo bằng tay; khi A/B tồn tại có marker trên track nếu khả thi, nhưng marker chip là bắt buộc cho MVP.
- Mốc A/B chỉ sống theo phiên player ban đầu; chưa thêm persistence/schema cho đến khi có bằng chứng người dùng cần lưu nhiều loop.

### 4.2 Lặp theo câu phụ đề

- Khi có subtitle cue hiện hành, thêm lối tắt **“Lặp câu”** đặt A=cue.start, B=cue.end, seek A và bật loop.
- Cho phép chỉnh A/B thủ công sau khi dùng cue; Clear đưa về trạng thái thường.
- Với phụ đề không có cue ở thời điểm hiện tại, ẩn hoặc disable lối tắt, không tạo loop ngầm.
- Mở rộng sau MVP: repeat count ×1/×3/∞ và auto-pause/gap để shadowing; không làm chung với bộ lặp nền đầu tiên.

### 4.3 Luyện audio chất lượng cao

- Pha đầu: thêm hành động có ngữ cảnh **“Luyện audio đoạn này trong tab Nghe”** cho range A/B (gọi `exportAudioFromVideo` hiện có với start/duration, sau đó mở kết quả trong luồng audio/recent phù hợp). Giữ video gốc không đổi; không upload.
- Pha realtime: chỉ làm sau feasibility spike chứng minh được decode PCM + thay audio output + giữ sync video. Nếu cần một backend/decoder mới hoặc thay video plugin, quay lại xin quyết định kiến trúc và đo dung lượng trước.
- Không làm giả nút “UltraTimeStretch cho video” bằng cách đổi tốc độ video native; không tuyên bố pitch/voice preservation khi chưa A/B nghe trên máy.

## 5. Phương án kỹ thuật và state

### A/B controller thuần

Tạo `VideoLoopRange` hoặc `VideoAbLoopController` tách khỏi widget, với state tối thiểu:

- `a`, `b`, `enabled`, `repeatCount` (giai đoạn đầu `repeatCount = infinite`).
- Các hàm thuần `setA(position)`, `setB(position, duration)`, `clear()`, `shouldWrap(position)`, `clampToDuration(duration)`.
- Invariants: `0 <= A < B <= duration`; B−A ≥ 300 ms; thay file/dispose/duration invalid thì clear; các thao tác seek/drag không tạo vòng seek lặp.
- UI widget không sở hữu logic thời điểm loop; nhận range state và dispatch position.

Không đổi `VideoInfo` schema ở phase đầu. Nếu sau này lưu loop, dùng storage versioned keyed bởi `VideoInfo.id` và tránh đụng playback-position field hiện có.

## 6. Lộ trình triển khai

### V0 — Xác minh hành vi và nền tảng (spike ngắn)

1. Trên thiết bị, đo listener tick/seek accuracy của `video_player`, A/B loop 2–5s trên Android/iOS; ghi sai số thực tế.
2. Xác nhận `UltraEngineFFIV2.processAudio` có output path thật trong Tab Nghe; so sánh 0.5×/0.8× với just_audio native, kiểm pitch, underrun, CPU/battery. Repo source hiện chưa có call-site tới `processAudio()`.
3. Ghi ma trận supported platform của local file/content URI và video controls; xem xét Windows/Linux riêng.

**Gate:** nếu lặp trên native video player ổn, tiến hành V1. Realtime DSP không phải điều kiện chặn V1.

### V1 — A/B thủ công trong local player

- Pure state/controller + unit tests.
- A/B/Clear controls, active state, loop khi vượt B, reset khi file/player dispose.
- Giữ nguyên `VideoPlayerController`, subtitles, speed, resume, SAF URI.

**DoD:** đặt A/B lặp ổn định 20 vòng; Clear dừng loop không đổi file/position bất ngờ; A≥B/boundary/seek-to-end không crash/kẹt; không mất subtitle/resume.

### V2 — Subtitle-to-loop và học từ câu

- Lặp cue hiện hành bằng một thao tác; marker có thể chỉnh lại.
- Nối cue timestamp vào hành động lưu từ/WordList để context không mất mốc video.
- Tùy chọn auto-pause sau cue / số vòng lặp chỉ sau khi kiểm thử UX riêng.

**DoD:** cue SRT/VTT/ASS/LRC bắt đúng start/end; không có cue thì nút không làm gì sai; mốc lưu từ trỏ đúng câu/video/time.

### V3 — “Luyện audio đoạn này” (tái dùng export)

- Với A/B đang đặt, gọi helper export hiện có; trên export success điều hướng/mở file trong flow audio đã hỗ trợ playback engine; quay lại video giữ video ID và vị trí.
- Nếu export dài/chưa có storage, dùng progress/cancel/current media tooling, không chạy FFmpeg trên UI thread.

**DoD:** clip 10–30s xuất đúng range; mở được ở Tab Nghe, giữ liên kết title + timestamp gốc; back về video không reset library/resume.

### V4 — Realtime UltraTimeStretch cho video (chỉ sau quyết định mới)

Spike/ADR bổ sung xem xét 2 kiến trúc:

1. **Dual renderer:** mute native audio video + decode audio PCM riêng + UltraTimeStretch + đồng bộ audio clock với video seek/rate/pause. Rủi ro cao nhất là drift/latency/platform parity.
2. **Unified media backend:** dùng backend player có audio filter/PCM routing xuyên các nền tảng được hỗ trợ; đánh giá kích thước binary, license, codec, DRM (local media), hardware decode và migration cost.

Chỉ đầu tư khi có prototype Android+iOS chạy >10 phút, drift <100 ms (mục tiêu đo, không cam kết trước), pause/seek/A-B không lệch tiếng, và xác nhận engine thực sự tạo ra audio output đã time-stretch. Nếu không đạt, giữ trải nghiệm V3 xuất đoạn → Tab Nghe.

## 7. Test và nghiệm thu

### Unit tests không cần thiết bị

- Range valid/invalid; A/B thiếu, đảo thứ tự, duration 0, B ngoài cuối file; clamp; min range.
- Loop decision tại B−epsilon, B, B+epsilon; chỉ wrap một lần cho mỗi lần chạm boundary; clear giữa lúc wrap; drag seek vượt B.
- Cue-to-loop cho cue sát đầu/cuối file, cue duration rất ngắn, không cue, timestamp ngoài duration.
- Source-scan: player dùng controller/service mới; loop state được clear khi thay source/dispose; không thay `VideoInfo` serialization.

### QA thiết bị

| # | Kịch bản | Tiêu chí đạt |
|---|---|---|
| 1 | A/B 3 giây trên MP4 local Android | Quay về A đều; marker/status rõ; không seek liên tục ở B |
| 2 | A/B 3 giây trên iOS | Hành vi và seek gần tương đương Android |
| 3 | A/B khi đang playback 0.5×, 1×, 2× | Không treo; loop vẫn theo media position |
| 4 | Kéo seek bar qua B / ra ngoài range | Phản hồi có chủ đích; không loop nhầm hoặc mắc kẹt |
| 5 | File có SRT/VTT và không có subtitle | Lặp câu đúng range; khi thiếu cue lối tắt disabled/ẩn |
| 6 | SAF `content://`, quyền bị thu hồi | Dùng fallback URI hiện có; lỗi có thông báo; không crash |
| 7 | Đóng/mở player và resume | Không hồi sinh loop session cũ; resume video hiện tại vẫn đúng |
| 8 | Export A/B sang Tab Nghe | Clip đúng duration/range; nguồn gốc video + timestamp vẫn tìm được |
| 9 | Nền tảng desktop/web | Hiện rõ support thực tế; không quảng bá hỗ trợ nếu plugin không có implementation |
| 10 | Realtime DSP spike | So sánh blind/native, đo drift, CPU, nhiệt và pitch; chưa đạt thì không bật tính năng |

## 8. Rủi ro và nguyên tắc

- Polling/seek trên listener có thể dao động theo cadence decoder; debounce/one-shot guard, không dùng `Timer` làm clock chính.
- Exact seek tùy codec/keyframe/backend; đo thật và không hứa frame-accurate trước khi benchmark.
- Audio decoder + UltraTimeStretch realtime có nguy cơ A/V drift, double audio và tăng CPU; tắt/rollback bằng capability flag nếu prototype fail.
- Không thêm package/native dependency trong V1–V3; không đổi FFmpeg runner/media export hoặc C++ DSP nếu không có scope/ADR mới.
- Mọi chuỗi UI mới cần theo luật i18n trong `AGENTS.md` (English fallback/priority locales) từ PR đầu; không hardcode chrome.
- Không thay video gốc; không tự tải phụ đề hoặc upload nội dung local.

## 9. Quyết định cần giữ

Đề xuất triển khai thứ tự **V1 A/B thủ công → V2 lặp câu → V3 xuất đoạn sang Tab Nghe → V4 realtime DSP chỉ sau spike**. Đây là đường mang lại giá trị ngay, giảm rủi ro sync và tận dụng hạ tầng sẵn có mà không khẳng định sai năng lực hiện tại.

### Tiến độ triển khai trên nhánh

- **Đã code:** pure `VideoAbLoopState` (clamp/invariants/minimum 300 ms/wrap target); A/B/Clear controls; loop boundary dựa trên player position với one-shot rewind guard; repeat current subtitle cue; menu export audio đúng A/B range.
- **Đã thêm:** unit tests cho model/range/boundary/clear; nguồn UI tái dùng các bản dịch có sẵn và thêm hai key vào priority pack (8 locale): `Xuất đoạn A-B`, thông báo B cần cách A tối thiểu 0,3 giây.
- **V3 đã nối code:** export success có follow-up “Mở trong tab Nghe”; chọn sẽ nạp file vào `PlayerProvider`, phát audio, chuyển sang chế độ Nghe, pause video và đóng player. Trong embedded “Xem” vẫn ở shell; từ màn VideoLibrary route độc lập sẽ đóng cả route thư viện để về shell. Title audio giữ tên video và timestamp bắt đầu clip; nếu không chọn hành động này, video vẫn tiếp tục như trước.
- **CI đã xác minh:** app analyze/locale + video A/B, wiring và media tests xanh tại run `42693444830`; workflow build, Android resolver và các regression suite liên quan cũng xanh trên PR #164.
- **Còn chờ nghiệm thu:** export/playback thực tế và A/V seek accuracy trên Android/iOS. Liên kết nguồn hiện được giữ ở title (chưa có affordance mở ngược video trực tiếp). V4 realtime DSP vẫn cần spike/ADR; không gọi playback này là UltraTimeStretch.

## 10. Nguồn

- Nội bộ: `lib/features/video/widgets/video_player_screen.dart`; `lib/features/video/services/subtitle_parser.dart`; `lib/features/media_tools/media_export_actions.dart`; `lib/audio/audio_player_service.dart`; `lib/ffi/ultra_engine_ffi_v2.dart`; `docs/plans/PLAN-047-cong-cu-am-thanh-video.md`; `docs/adr/0026-cong-cu-media-tren-ffmpeg-co-san.md`; cards `VID-001`, `I4U18-VIDEO-LIB-001`, `AVTOOL-003` trong `docs/project/KANBAN.md`.
- Ngoại bộ: [VLC Android player docs](https://docs.videolan.me/vlc-android-user/video/video_player.html), [mpv manual](https://mpv.io/manual/master/), [Language Reactor](https://www.languagereactor.com/), [Flutter video_player](https://pub.dev/packages/video_player).
