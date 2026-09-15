# Prompt giao Arena agent — hoàn thiện Video local / tab phụ Xem (VID-001)

> Copy nguyên khối `PROMPT` bên dưới để giao một Arena agent. Prompt này được
> tổng hợp từ `docs/Bangiao/bangiao_video.md`, `docs/project/PLAN.md` PLAN-025,
> `docs/project/KANBAN.md` card `VID-001` và lỗi hồi quy `LISTEN-VIEW-001`.
>
> Tính đến 2026-09-16, phần video trong repo mới ở mức scaffold: model và
> manifest đã có, navigation A/B đã nối, nhưng player còn placeholder; chưa có
> import/quét video hoàn chỉnh, SRT overlay, dictionary tap, speed thật hoặc
> A-B loop thật.

## PROMPT

```text
Bạn là Arena coding agent phụ trách VID-001 — Video local + học ngôn ngữ trong
In4Up. Mục tiêu là biến tab phụ “Xem” thành tính năng chạy thật, không để lại
placeholder/mock. Đây là tính năng local-first; không tải video/phụ đề tự động từ
mạng.

ĐỌC BẮT BUỘC TRƯỚC KHI CODE
1. AGENTS.md và docs/GOVERNANCE.md.
2. docs/Bangiao/bangiao_video.md.
3. docs/project/PLAN.md mục PLAN-025.
4. docs/project/KANBAN.md:
   - VID-001 — trạng thái doing, WP0-WP3 mới ghi là đã có code;
   - LISTEN-VIEW-001 — lỗi Nghe → Xem → quay lại bị màn hình đen;
   - SHADOW-FILE-001 nếu cần tham khảo quy tắc file cache/persistent.
5. Kiểm tra code hiện tại, không giả định scaffold đã là implementation:
   - lib/features/video/models/video_info.dart
   - lib/features/video/services/video_library_service.dart
   - lib/features/video/widgets/video_library_screen.dart
   - lib/features/video/widgets/video_player_screen.dart
   - lib/screens/main_shell.dart
   - lib/screens/tools/tools_overlay*.dart
   - pubspec.yaml (`video_player: ^2.8.0` đã có)

BASELINE ĐÃ CÓ / KHÔNG ĐƯỢC LÀM LẠI MÙ
- `main_shell.dart` đã có IndexedStack 3 sub-mode Listen: Nghe, Nói, Xem.
- Quick-action ⚡ đã có tool Video với id `video_player` và route tới
  VideoLibraryScreen.
- `VideoInfo` và manifest JSON đã có nhưng phải audit persistence/error handling.
- `VideoPlayerScreen` hiện còn TODO/placeholder, chưa được coi là WP1 hoàn tất.
- Không cherry-pick lại cả branch cũ; lấy đúng phần cần thiết sau khi diff với
  tip nhánh đích.

MỤC TIÊU CHỨC NĂNG
- Người dùng thêm video local được hỗ trợ, thấy trong thư viện, tìm/lọc và mở.
- Video phát thật bằng `video_player`, có play/pause, seek, progress, ±10s,
  tốc độ 0.5x/0.75x/1x/1.25x/1.5x/2x và lỗi hiển thị rõ.
- Tự tìm phụ đề `.srt` cùng basename hoặc cho phép chọn file SRT local; parse
  được timestamp chuẩn, BOM/UTF-8 và fallback encoding hợp lý; cue active đồng bộ
  với position video; phụ đề hiển thị overlay.
- Tap vào từ/cụm trong cue mở tra từ điển hiện có; nếu user xác nhận thì lưu
  WordList. Nội dung subtitle giữ nguyên ngôn ngữ gốc, không dịch tự động trong
  scope này.
- A-B loop theo cue subtitle: chọn câu A/B hoặc “câu hiện tại”, lặp đúng khoảng
  thời gian; nếu không có subtitle thì cho phép toàn track hoặc báo rõ.
- Cả hai đường vào hoạt động:
  A. Listen → sub-tab Xem.
  B. ⚡ → Video → VideoLibraryScreen full-screen.
- Khi rời tab Xem hoặc quay lại Listen, không màn hình đen, không texture treo,
  không controller cũ phát ngầm. Đây là acceptance bắt buộc của LISTEN-VIEW-001.

PHẠM VI FILE / KIẾN TRÚC
- Code chính nằm trong `lib/features/video/**`; chỉ chạm
  `lib/screens/main_shell.dart` và tools overlay để nối route/lifecycle cần thiết.
- Tạo model/service thuần Dart cho subtitle để test không cần platform video.
- Không đưa logic parse SRT, dictionary hoặc A-B loop vào một widget khổng lồ.
- Nếu cần truyền visibility vào VideoLibraryScreen, dùng API rõ ràng như
  `isActive`/lifecycle callback từ MainShell; không dựa vào `dispose()` của
  IndexedStack vì offstage widget vẫn còn sống.
- `VideoPlayerController` phải được tạo async, có loading/error state, lắng nghe
  initialized/value, pause/dispose đúng; mọi async callback phải guard mounted.
- Embedded mode và full-screen mode phải phân biệt: không hiện nút back làm pop
  MainShell ngoài ý muốn khi đang ở sub-tab; full-screen mới có back phù hợp.
- File picker không được lưu path chỉ nằm trong cache. Chọn một chiến lược
  bền vững và ghi rõ trong PR:
  (a) copy vào application documents/video_imports với progress + dedup + tên
      an toàn, hoặc
  (b) giữ content URI/reopenable reference nếu platform plugin hỗ trợ ổn định.
  Không để manifest trỏ vào file cache chết. Nếu file đã mất, tile phải báo
  “file unavailable” và cho chọn lại, không crash.
- Chỉ hứa format mà platform kiểm chứng được. MP4/H.264 là baseline Android;
  MKV/WebM tùy decoder của nền tảng, phải báo unsupported rõ thay vì giả vờ
  hỗ trợ. Không parse binary video và không thêm native codec ngoài scope.

WORK PACKAGE VÀ COMMIT/PR PLAN
Không tạo một diff khổng lồ. Có thể một agent thực hiện tuần tự, nhưng giữ
commit logic và ưu tiên tách PR theo các nhóm sau:

WP0 — Library/import/persistence
- Rà `VideoInfo` id ổn định (không chỉ hashCode/path tạm), title, duration,
  source path/URI, addedAt.
- Nút Add/Import video; filter extension hợp lý; copy/reference persistent;
  manifest atomic, corrupt entry/missing file không làm mất toàn thư viện.
- Browse/search/sort local library; refresh và remove có confirm.
- Test model round-trip, manifest corrupt/missing file, duplicate import, path
  cache không được dùng sau restart.

WP1 — Player thật + lifecycle
- Dùng `VideoPlayerController.file` hoặc source abstraction đã chọn; không còn
  icon placeholder.
- Controls: play/pause, seek slider, ±10s, position/duration, speed, loading,
  error/retry.
- Xử lý app pause/resume và Listen IndexedStack offstage. Khi chuyển Nghe/Xem
  10 lần, video không phủ texture đen lên Listen và không phát ngầm.
- Test controller/lifecycle qua fake platform seam; nghiệm thu Android debug
  và release với file MP4 thật.

WP2 — SRT parser + overlay
- Tạo `SubtitleCue` immutable và parser thuần Dart.
- Parse `HH:MM:SS,mmm` và dấu chấm; bỏ cue hỏng có log/count, không crash; xử lý
  BOM/line ending/UTF-8; không coi text subtitle là chrome UI.
- Binary search hoặc index hiệu quả cho cue active; tránh rebuild toàn list mỗi
  frame nếu không cần.
- Overlay an toàn khi cue dài/nhiều dòng, portrait/landscape, controls hiện/ẩn.
- Test parser, timestamp, overlap, cue boundary, malformed file, active cue.

WP3 — Navigation A + B và UX tab
- Xác nhận sub-tab Xem mở thư viện đúng, quick-action Video mở full-screen đúng.
- Không tạo route trùng hoặc navigator pop sai.
- Nếu sửa `main_shell.dart`, giữ mode index 0/1/2 và persistence sub-mode.
- Sửa đúng lỗi LISTEN-VIEW-001: player/list screen có lifecycle contract rõ;
  lỗi native/video init phải thành error UI chứ không màn hình đen.

WP4 — Dictionary/WordList integration
- Tap từ trong subtitle mở service từ điển hiện có (không tự viết MDX parser).
- Sanitize/hiển thị entry an toàn; giữ HTML/source dictionary theo quy định
  existing dictionary service.
- Nút Save dùng flow WordList hiện có, giữ subtitle/source evidence nếu model
  hỗ trợ; không tự dịch subtitle.
- Nếu DictionaryService/WP đang ở branch khác, tạo seam interface và ghi
  dependency rõ; không kéo cả branch dictionary vào PR video.

WP5 — A-B loop + i18n
- Cue hiện tại/đoạn chọn được làm A-B; seek về A khi tới B; stop/cancel sạch;
  fallback full track khi không có SRT.
- Các label/tooltip/dialog/empty/error đều dùng ARB hoặc `uiText`; locale khác
  vi không được hiện chrome Vietnamese. Bắt buộc kiểm tra en/hi/zh/zh_TW/si.
- Nội dung subtitle, title file và dictionary meaning là user/source content,
  không dịch tự động để thỏa rule chrome.

NGOÀI PHẠM VI — TUYỆT ĐỐI KHÔNG LÀM TRONG PR NÀY
- ASS/SSA styling phức tạp.
- Extract subtitle nhúng trong MKV.
- Video → audio extraction.
- Chapters, PiP, streaming/network video, auto-download subtitle.
- Sửa UltraTimeStretch hoặc `lib/ffi/`.
- Đổi kiến trúc MainShell ngoài lifecycle/route cần thiết.
- Reformat toàn repo hoặc sửa workflow CI chỉ để né lỗi.

TEST VÀ NGHIỆM THU BẮT BUỘC
1. Test thuần Dart:
   - VideoInfo JSON/identity;
   - persistent import/manifest;
   - SRT parser + active cue;
   - speed clamp;
   - A-B boundaries.
2. Widget/controller test có fake video platform hoặc seam; CI không phụ thuộc
   file video binary thật.
3. `flutter analyze --no-fatal-infos --no-fatal-warnings` xanh.
4. Test video liên quan và `test/locale_chrome_no_vietnamese_test.dart` xanh.
5. App Analyze + Locale Test CI xanh; nếu chạm `packages/**` phải thấy workflow
   thật sự trigger, không dùng “workflow không chạy” làm bằng chứng.
6. Device AT Android:
   - ⚡ → Video → import MP4 → phát/seek/speed/back;
   - Listen → Xem → phát → quay lại Nghe, lặp 10 lần không đen/kẹt;
   - SRT cùng basename hiện đúng tại cue; cue dài không overflow;
   - tap từ → dictionary/WordList hoặc thông báo unavailable rõ;
   - A-B lặp đúng câu; không có SRT vẫn chạy toàn track;
   - app background/resume và file bị xóa cho error UI đúng.
7. Ghi rõ platform nào đã nghiệm thu. Không tuyên bố MKV/WebM hỗ trợ nếu chưa
   có thiết bị/decoder chứng minh.

COMMIT MAP VÀ PR
- Commit 1: WP0 models/library/persistence + tests.
- Commit 2: WP1 player/lifecycle + tests.
- Commit 3: WP2 parser/overlay + tests.
- Commit 4: WP3/WP4 navigation/dictionary (nếu dependency đã sẵn sàng).
- Commit 5: WP5 A-B/i18n + KANBAN checkpoint.

Mỗi commit phải có scope rõ, không WIP/fixup/generated files. Không squash các
commit logic. PR phải dùng `.github/pull_request_template.md`, ghi:
- VID-001 và LISTEN-VIEW-001 nếu chạm lifecycle;
- files changed đúng ownership;
- CI run URL, test commands, screenshots/logcat/video;
- AT portrait/landscape, embedded/full-screen, restart/cache;
- platform limitations và phần còn chờ owner nghiệm thu.

BÁO CÁO CUỐI
Gửi commit map, diff file list, test/analyze/CI evidence, platform AT, rủi ro,
phần ngoài scope và đề xuất cập nhật KANBAN. Nếu không tái hiện được lỗi màn
hình đen hoặc video plugin không chạy trên platform, báo BLOCKED kèm log; không
để placeholder nhưng cũng không đoán sửa ngoài scope.
```
