# Prompt giao Arena agent — Cabin tùy chọn lưu bản ghi âm (CABIN-REC-001)

> Ý tưởng này bổ sung cho `PLAN-008`, `PLAN-023`, `CABIN-001` và
> `SHERPA-WP4-01`. Mục tiêu là cabin vẫn hiển thị text/dịch như hiện tại nhưng
> người dùng có thể chủ động lưu audio của một phiên ngay trên máy.

## Định hướng sản phẩm đã đề xuất

- Toggle **Lưu bản ghi cabin** mặc định **tắt** để bảo vệ riêng tư.
- Khi bật, lưu **âm thanh gốc từ microphone**, không tự ghi tiếng TTS/dubbing
  phát ra loa vào cùng file.
- Lưu trong app storage bền vững, không dùng cache:
  `<application documents>/cabin_recordings/`.
- Sau khi dừng phiên, lưu audio cùng metadata/caption sidecar để có thể mở lại,
  phát, chia sẻ hoặc xóa.
- Không upload, không auto-sync cloud, không tự động ghi khi mở app.
- Có thể xuất/chia sẻ ra Downloads/Files khi người dùng bấm rõ ràng.

## PROMPT

```text
Bạn là Arena coding agent phụ trách CABIN-REC-001 — tùy chọn lưu bản ghi âm
cho Dịch Live Cabin của In4Up.

ĐỌC BẮT BUỘC
1. AGENTS.md và docs/GOVERNANCE.md.
2. docs/project/KANBAN.md: PLAN-008/CABIN-001, SHERPA-WP4-01,
   CABIN-REC-001, SHADOW-FILE-001.
3. docs/project/PLAN.md: PLAN-008 và PLAN-023.
4. docs/Bangiao/bangiao_sherpa_wp4_live_stt.md.
5. Code hiện tại:
   - lib/features/cabin/services/stts_cabin_service.dart
   - lib/features/cabin/models/cabin_caption.dart
   - lib/features/cabin/screens/live_cabin_screen.dart
   - packages/in4up_stt/lib/stt_engine_sherpa.dart
   - packages/in4up_stt/lib/stt_service_facade.dart
   - lib/features/shadowing/services/recording_service.dart
   - pubspec.yaml (`record` đã có)

BỐI CẢNH KỸ THUẬT PHẢI TÔN TRỌNG
- Sherpa cabin hiện dùng `AudioRecorder.startStream()` để lấy PCM 16 kHz mono
  rồi đưa vào `SherpaSttEngine`; đây là đường tốt nhất để tee cùng một luồng
  PCM vào file mà không mở thêm một microphone session.
- System STT hiện do `SttServiceFacade`/speech service sở hữu microphone và
  không trả raw PCM cho Dart. Không tự mở recorder thứ hai rồi tuyên bố chắc
  chắn chạy được: phải probe trên thiết bị. Nếu chưa đảm bảo, UI phải báo
  recording chỉ hỗ trợ chắc chắn ở engine Sherpa offline hoặc tách capability
  rõ ràng; không làm hỏng session STT hiện tại.
- `RecordingService` của Shadowing đang có semantics riêng và dùng temporary
  path cho một số flow. Không copy nguyên singleton đó cho Cabin. Tạo service
  có ownership/session lifecycle riêng, persistent path và test riêng.
- Mic permission đã có trong cabin; không thêm permission storage rộng nếu app
  documents/SAF đủ. iOS/Android/Windows phải ghi rõ capability thực tế.

MỤC TIÊU MVP
1. Trong UI Cabin có setting/toggle “Lưu bản ghi âm” mặc định OFF; trạng thái
   được persist. Khi đang ghi có REC dot, timer và nút stop/pause rõ.
2. Start cabin + recording phải là một session có id. Stop, lỗi, đổi engine,
   app pause hoặc dispose phải finalize/close file sạch, không để file hỏng
   hoặc recorder/mic treo.
3. Audio gốc được lưu persistent, không dùng `getTemporaryDirectory()` và
   không lưu path dưới `cache/file_picker`. Tùy platform dùng m4a/AAC compact
   hoặc WAV/PCM fallback đã kiểm chứng; không hứa format nếu plugin không hỗ trợ.
4. Sau stop, hiển thị bản ghi vừa lưu với tên, thời lượng, dung lượng, nguồn/đích
   và engine. Có play, share/export, rename nếu đơn giản, delete có confirm.
5. Lưu sidecar JSON cho session/caption: id, createdAt, sourceLang, targetLang,
   engine, audioPath, duration, và danh sách caption. Mỗi caption phải có
   `offsetMs` tương đối từ đầu phiên; không chỉ lưu DateTime wall-clock.
   Translation text và source text giữ nguyên nội dung; chỉ chrome UI mới i18n.
6. Không ghi audio TTS/dubbing vào bản ghi gốc. Nếu muốn mix/dub là card riêng,
   không làm trong PR này.

KIẾN TRÚC ĐỀ XUẤT
- `CabinRecordingEntry`: model immutable, JSON round-trip, schemaVersion để
  migration sau này.
- `CabinRecordingService`: start/append/finalize/cancel/list/delete/share,
  quản lý persistent directory và atomic metadata write.
- `CabinRecordingSink` hoặc adapter platform:
  - Sherpa: nhận cùng PCM stream với STT, ghi tuần tự, không giữ toàn audio trong
    RAM; WAV writer phải patch header khi finalize hoặc encoder phải close đúng.
  - System STT: capability probe rõ; chỉ bật nếu recorder song song đã được
    kiểm chứng trên thiết bị và không làm speech recognizer mất mic. Nếu không,
    hiển thị lý do và giữ cabin text hoạt động bình thường.
- `SttsCabinService`: start/stop recording theo session; không tạo recorder
  duplicate; cập nhật offset cho caption finalized/partial; stop recording
  không được chặn translation/TTS cleanup vô hạn.
- `LiveCabinScreen`: toggle trước khi start, REC indicator, elapsed time, save
  result/error, list bản ghi. Không đưa logic file I/O lớn vào build().

WORK PACKAGE / COMMIT MAP

WP0 — Audit và capture proof
- Chứng minh Sherpa PCM stream có thể tee vào sink không đổi kết quả STT.
- Probe system STT recording trên thiết bị; nếu không an toàn, ghi capability
  limitation thay vì workaround mở hai mic.
- Tạo pure model/writer seam + tests trước.

WP1 — Persistent recording service
- Directory `cabin_recordings`, file naming an toàn, session id ổn định.
- Atomic finalize/metadata, cancel xóa đúng file tạm, missing/corrupt entry
  không làm crash list.
- Xử lý pause: nếu encoder không append an toàn, dùng segment files trong một
  session và metadata nối nhóm; không tạo file giả hoặc mất đoạn.
- Test restart, stop hai lần, lỗi write, file rỗng, duplicate session.

WP2 — Nối vào Sherpa cabin
- Khi engine Sherpa + toggle ON: cùng PCM feed STT và recording sink.
- Toggle OFF: hành vi hiện tại không đổi, không tạo file.
- Stop/keep-alive/restart Sherpa không làm mất handle hoặc đóng nhầm recorder.
- Nếu cabin đang dubbing, bản ghi mặc định vẫn là microphone source.

WP3 — Caption sidecar / replay
- Ghi `offsetMs` cho caption; source text, translated text, language pair,
  engineUsed và isFinal.
- Sau khi mở lại bản ghi, phát audio và xem caption theo timeline nếu UI hiện
  tại đủ seam; nếu chưa đủ thì ít nhất metadata không mất và có test round-trip.
- Không gọi dịch lại khi mở bản ghi đã có translated text.

WP4 — UI, list, share/export
- Toggle + REC/timer + stop/save result.
- Danh sách Cabin recordings trong Cabin hoặc một entry point rõ ràng; play,
  share/export qua user action, delete confirm.
- File không còn tồn tại phải hiện trạng thái unavailable + nút xóa/relink,
  không red screen.
- i18n theo rule #5; key mới có English fallback và đủ hi/zh/zh_TW/si nếu
  thuộc T2. Không hard-code chrome tiếng Việt.

NGOÀI PHẠM VI
- Không tự động ghi âm lúc mở app.
- Không upload/cloud sync.
- Không trộn source mic với Piper/system TTS.
- Không mở hai microphone recorder nếu chưa có device proof.
- Không thay toàn bộ System STT bằng Sherpa trong card này.
- Không đụng UltraTimeStretch, `lib/ffi/` hoặc native FFI ngoài adapter cần thiết.
- Không sửa Shadowing recording path trừ khi có card riêng.

AT / ACCEPTANCE TEST
1. Toggle OFF: cabin Sherpa vẫn start/stop/dịch như trước, không sinh file.
2. Toggle ON + Sherpa VI offline: nói 30–60 giây → text vẫn ra → stop → file
   persistent phát lại được sau restart app.
3. Toggle ON + Sherpa EN streaming: nếu capability đã verify → tương tự; nếu
   chưa hỗ trợ phải hiện message rõ, không chặn text STT.
4. Pause/resume/stop hai lần/keep-alive restart: file hoặc segment metadata
   không hỏng, duration không âm, không có recorder treo.
5. Caption sidecar round-trip: source/translation/language/offset giữ đúng;
   mở lại không dịch mạng lại.
6. Dubbing ON: file mặc định không chứa tiếng TTS được phát từ loa (ghi rõ
   cách kiểm chứng trên thiết bị/headphone).
7. Xóa cache/restart app: cabin recording vẫn tồn tại vì không nằm trong cache.
8. Xóa/share/export hoạt động; file mất hiện error UI, không crash.
9. Permission microphone denied: cabin báo đúng; recording không lén tạo file.
10. CI: analyze, unit/widget tests, locale test và App Analyze + Locale xanh;
    device AT Android debug/release ghi rõ model/engine/format.

COMMIT/PR RULE
- Tách commit theo WP: model/test → persistent service → Sherpa integration →
  caption/UI/i18n. Không squash các commit logic, không WIP/fixup/generated.
- Chỉ sửa file thuộc CABIN-REC-001; nếu chạm `SttsCabinService` phải ghi rõ
  không hồi quy CABIN-001/CABIN-ASR-002/SHERPA-STREAM-001.
- PR dùng `.github/pull_request_template.md`, có commit map, CI run, log/screenshot,
  audio playback evidence, storage path proof và checklist AT.
- Nếu system STT chưa thể record an toàn, báo BLOCKED/partial support với bằng
  chứng; không đánh dấu done bằng cách mở recorder thứ hai đoán mò.
```
