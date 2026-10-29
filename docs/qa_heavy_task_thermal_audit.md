# QA-PERF-001 — Audit hiệu năng khi chạy nhiều tác vụ nặng cùng lúc (nóng máy / pin / crash)

**Vai trò:** QA kiểm thử + "thám tử" rà kiến trúc (code audit), không phải báo cáo từ
chạy app thật trên thiết bị (xem mục 1 — giới hạn môi trường).

**Phạm vi:** Rủi ro khi 2+ tác vụ CPU/pin nặng (AI chat local, dịch offline Hy-MT,
Whisper on-device, TTS) chạy chồng lên nhau, đặc biệt sau khi người dùng bật
"Dừng tối ưu mức sử dụng pin" (`lib/services/battery_optimization_service.dart`,
BATTERY-OPT-001) — tính năng này cố tình gỡ bỏ lưới an toàn Doze/App Standby của
Android để STT/AI chạy nền không bị hệ thống giết, nhưng đồng thời cũng gỡ luôn
giới hạn mà hệ thống dùng để NGĂN app tự đốt CPU/pin quá mức.

---

## 1. Giới hạn môi trường kiểm thử (đọc trước khi tin số liệu)

Sandbox agent **không có** Flutter/Dart SDK cài sẵn, và mạng bị chặn tới
`storage.googleapis.com` / `pub.dev` / `dl.google.com` (chỉ `github.com` mở) —
đã xác nhận bằng `curl` (xem `docs/skills/ci-red-debugging/SKILL.md`, ghi nhận
từ trước). Hệ quả:

- **Không build/run được app**, không có thiết bị/emulator Android → **không đo
  được nhiệt độ pin/CPU thật, không ép crash/OOM thật** trong phiên làm việc này.
- Mọi phát hiện dưới đây đến từ **đọc code + truy vết luồng gọi** (grep/đọc toàn
  bộ các file liên quan), không phải log runtime.
- Oracle duy nhất xác minh được: `flutter analyze` qua CI (`app_analyze.yml`,
  chạy khi push nhánh `arena/**`) — xác nhận code MỚI không có lỗi biên dịch,
  **không** xác nhận hành vi runtime (nhiệt độ, crash thật).
- **Khuyến nghị bắt buộc:** chạy `scripts/qa/thermal_soak_test.sh` (thêm trong
  PR này) trên **thiết bị Android thật, RAM thấp/tầm trung** (không phải
  flagship) trước khi coi vấn đề này đã đóng — xem mục 6.

---

## 2. Phát hiện (xếp theo mức độ nghiêm trọng)

### 🔴 #1 — CRITICAL: 2 engine llama.cpp độc lập không biết sự tồn tại của nhau

- `AiServiceFacade` (`packages/in4up_ai/lib/src/facade/ai_service_facade.dart`)
  giữ **1 isolate Gemma** (`AiEngineGemma`, `packages/in4up_ai/lib/src/engine/ai_engine_gemma.dart`),
  `native.create(modelPath)` mặc định `threads: 4` (`ai_native_bindings.dart:89`).
- `HyMtEngine` (`lib/features/translation/engines/hymt_engine.dart`) spawn
  **một isolate llama.cpp RIÊNG** cho dịch offline, gọi
  `native.create(init.modelPath, contextSize: 2048, threads: 4)`
  (dòng 301) — **cùng thư viện native** (`AiNativeBindings`/`in4up_ai_native`)
  nhưng là **model GGUF khác, isolate khác, process-thread khác** với Gemma chat.
- Mỗi engine tự có kỷ luật single-flight RIÊNG (hàng đợi chat của
  `AiServiceFacade`, `HyMtSlot` của Hy-MT) — nhưng **không ai biết về nhau**.
  Không có file nào trong `lib/features/translation/**` import
  `AiServiceFacade`, và ngược lại (`grep` xác nhận 0 kết quả).
- **Kịch bản thực tế rất dễ xảy ra:** người dùng đang nghe audio nước ngoài →
  bấm dịch nhanh 1 câu (Hy-MT) → trong lúc đó mở tab AI Chat hỏi 1 câu → 2
  isolate llama.cpp cùng chạy đồng thời, mỗi cái đòi 4 luồng CPU + load model
  GGUF trăm MB–GB riêng vào RAM. Trên máy 6-8 lõi tầm trung, đây là bão hoà CPU
  đa lõi kéo dài hàng chục giây tới vài phút — đúng kiểu tải sinh nhiệt nhiều
  nhất (sustained multi-core), không phải burst ngắn.
- **Bằng chứng gián tiếp rằng kịch bản "nhiều engine nặng cùng lúc → hết
  RAM/CPU" ĐÃ xảy ra trong thực tế:** `AiEngineGemma` có hẳn cơ chế phát hiện +
  tự phục hồi khi "isolate bị OOM killer thu hồi" (`_isolateExitPort`,
  `_backendLostReason`, comment "hay gặp khi nạp model 600MB+ trên tablet RAM
  hạn chế" — `ai_engine_gemma.dart` dòng ~300). Cơ chế này mang tính **phản
  ứng** (restart sau khi chết), không phải **phòng ngừa** (tránh để nó chết).
- **Đã sửa (một phần) trong PR này:** thêm `HeavyTaskMonitor` (xem mục 4) để
  ít nhất PHÁT HIỆN được tình huống chồng chéo và có chỗ cảnh báo UI. **CHƯA
  sửa tận gốc** — xem khuyến nghị mục 5.1.

### 🟠 #2 — HIGH: `SttServiceFacade.transcribeFile` không có single-flight (đã vá)

- Khác với `AiServiceFacade` (hàng đợi chat tuần tự) và `HyMtEngine`
  (`HyMtSlot`), `transcribeFile()` (`packages/in4up_stt/lib/stt_service_facade.dart`)
  **không có cơ chế nào** ngăn 2 lời gọi chồng nhau spawn 2 Isolate Whisper độc
  lập — mỗi isolate tự load model GGML + chạy FFI blocking.
- Có ít nhất 5 nơi trong `lib/` gọi `transcribeFile`/`transcribeAuto`/
  `transcribeDeep`/`transcribeQuick` từ các luồng tính năng khác nhau (shadowing,
  learn-by-heart voice recitation, VAD pipeline, player STT, auto-TOC nền) —
  hoàn toàn có thể trùng thời điểm nếu người dùng thao tác nhanh hoặc một tác
  vụ nền (auto-TOC) đang chạy lúc người dùng bấm bóc băng tay.
- Comment trong chính code (`stt_engine_remote.dart:7`) đã thừa nhận: Whisper
  on-device "vừa chậm vừa kém chính xác và **làm nóng máy**" — lý do chính
  team chọn ưu tiên remote API cho file dài. Tức là rủi ro nhiệt đã được đội
  dev nhận biết ở CẤP ĐỘ 1 engine; nguy cơ lớn hơn là **2+ lượt cùng lúc**.
- **Đã sửa trong PR này:** thêm `AsyncMutex` (`packages/in4up_stt/lib/utils/async_mutex.dart`)
  — mọi lời gọi Whisper on-device giờ đi qua `_runWhisperExclusive()`, xếp
  hàng tuần tự app-wide. Engine remote (network, không tốn CPU cục bộ) và
  native (OS speech recognizer, nhẹ) **không** bị ảnh hưởng — giữ nguyên tốc
  độ các luồng đó.
- **Gap còn lại (chưa sửa — ghi nhận để theo dõi):**
  `packages/in4up_stt/lib/stt_engine_whisper_strategy.dart` (`WhisperSttEngine`,
  truy cập qua `SttEngineRegistry`/`SttServiceFacade.getEngine()`) gọi thẳng
  `SttEngineWhisper.transcribeMobileChunked` **KHÔNG qua** `transcribeFile()` —
  hiện **không có caller nào trong `lib/`** dùng đường này (đã `grep` xác nhận),
  nên không phải rủi ro đang hoạt động, nhưng nếu tính năng tương lai dùng
  `getEngine(SttEngineType.whisper)` trực tiếp sẽ bỏ qua khoá mới thêm.

### 🟡 #3 — MEDIUM: Không có cơ chế nhận biết nhiệt độ/throttle thiết bị

- Toàn bộ `lib/` + `packages/` **không có** bất kỳ tích hợp nào với
  `PowerManager.getThermalHeadroom()` / broadcast `ACTION_BATTERY_CHANGED`
  (nhiệt độ pin) / `ACTION_POWER_CONNECTED` để app tự biết máy đang nóng và
  chủ động giảm tải (hạ `n_threads`, hoãn tác vụ nền không khẩn cấp).
- Vì app đã xin miễn tối ưu pin, đây là lớp phòng vệ "tốt nên có" nhưng đang
  thiếu hoàn toàn — không nằm trong phạm vi sửa của PR này (cần platform
  channel + code Kotlin mới trong `MainActivity.kt`, cần test trên thiết bị
  thật để không hiểu sai threshold).

### 🟡 #4 — MEDIUM: Không có lưới bắt crash toàn cục (crash reporting)

- `grep -rn "runZonedGuarded\|FlutterError.onError\|PlatformDispatcher.instance.onError"`
  trên toàn bộ `lib/` → **0 kết quả**. `lib/main.dart` gọi thẳng `runApp()` mà
  không bọc `runZonedGuarded`, và không override `FlutterError.onError`.
- `pubspec.yaml` không có `firebase_crashlytics`/`sentry` dù app đã tích hợp
  Firebase cho auth/Firestore — nghĩa là nếu app crash/ANR ngoài thực tế do
  quá tải CPU/RAM (kịch bản #1), **đội dev sẽ không biết** trừ khi người dùng
  chủ động báo cáo. Đây là lỗ hổng quan sát (observability), không phải lỗi
  gây crash trực tiếp, nhưng làm giảm khả năng phát hiện sớm chính vấn đề mà
  audit này đang tìm.
- Không nằm trong phạm vi sửa của PR này (thêm Crashlytics cần cấu hình
  Firebase Console + thay đổi `build.gradle`, rủi ro ngoài khả năng xác minh
  không có Android SDK).

### 🟢 #5 — LOW: Dọn rác kiến trúc liên quan

- `packages/vipsound_ai/` và `packages/vipsound_core/` là bản sao gần như
  trùng với `in4up_ai`/`in4up_core` nhưng **không phải dependency** của app
  (xác nhận qua `pubspec.yaml` + `analysis_options.yaml` đã tự loại trừ 2
  package này với lý do "không phải dependency của app"). Không rủi ro runtime
  nhưng là rác kiến trúc dễ gây nhầm lẫn khi audit/khi onboard người mới.
- `packages/in4up_ai/lib/src/facade/ai_service_facade.dart` có dòng comment
  đầu file ghi nhầm đường dẫn `vipsound_ai` (copy-paste sót lại) — vô hại về
  hành vi nhưng nên sửa 1 dòng khi tiện tay.

---

## 3. Vì sao đây KHÔNG phải rủi ro lý thuyết suông

Ba bằng chứng cụ thể trong chính code (không phải suy đoán):

1. `ai_engine_gemma.dart` có nguyên một cơ chế watchdog 5 phút + tự phục hồi
   isolate khi bị "OOM killer thu hồi" — code comment nói thẳng: *"hay gặp khi
   nạp model 600MB+ trên tablet RAM hạn chế"*.
2. `stt_engine_remote.dart` dòng 7 nói thẳng Whisper on-device *"làm nóng
   máy"* — đây là lý do kỹ thuật được ghi lại, không phải suy diễn của audit
   này.
3. `hymt_engine.dart` có hẳn 1 lớp "HYMT-002" xử lý isolate chết/treo + restart
   — tức là đội dev đã từng gặp và vá triệu chứng (isolate treo/chết) của
   CHÍNH engine Hy-MT khi chạy một mình; audit này chỉ ra thêm là triệu chứng
   đó CÓ THỂ XUẤT HIỆN THƯỜNG XUYÊN HƠN khi Hy-MT chạy cùng lúc với Gemm a
   chat, vì cả hai cùng cạnh tranh CPU/RAM.

---

## 4. Các thay đổi đã triển khai trong PR này

| File | Thay đổi |
|---|---|
| `packages/in4up_core/lib/heavy_task_monitor.dart` *(mới)* | `HeavyTaskMonitor` — singleton CHỈ QUAN SÁT (không chặn), đếm tác vụ nặng đang chạy theo loại (`HeavyTaskKind`), expose `hasOverlappingHeavyTasks` khi ≥2 loại chạy chồng. |
| `packages/in4up_core/test/heavy_task_monitor_test.dart` *(mới)* | Unit test cho logic đếm/track (begin/end cặp đúng, không âm, track() luôn nhả khi lỗi, overlap detection). |
| `packages/in4up_stt/lib/utils/async_mutex.dart` *(mới)* | `AsyncMutex` — khoá FIFO thuần Dart, dùng cho Whisper on-device. |
| `packages/in4up_stt/test/utils/async_mutex_test.dart` *(mới)* | Unit test cho thứ tự chạy tuần tự + lỗi 1 lượt không kẹt hàng đợi. |
| `packages/in4up_stt/lib/stt_service_facade.dart` | Thêm `_whisperMutex` + `_runWhisperExclusive()` — MỌI lời gọi Whisper on-device (2 call site) đi qua khoá này + báo `HeavyTaskMonitor`. Thêm getter `isWhisperBusy`. Không đổi public API/behaviour của từng lượt transcribe riêng lẻ. |
| `packages/in4up_ai/lib/src/facade/ai_service_facade.dart` | Bọc `_processChat(item)` trong `HeavyTaskMonitor.instance.track(HeavyTaskKind.aiChatLocal, …)` — 1 dòng, không đổi logic hàng đợi/timeout hiện có. |
| `lib/features/translation/engines/hymt_engine.dart` | Thêm `HeavyTaskMonitor.instance.begin/end(HeavyTaskKind.translateOffline)` quanh đúng vùng đã có `slotGuard.acquire()/release()` — không đổi logic single-flight/retry hiện có. |
| `lib/widgets/heavy_task_warning_banner.dart` *(mới)* | Widget banner cảnh báo, ĐỘC LẬP — tự ẩn/hiện theo `HeavyTaskMonitor`. **CHƯA gắn vào `main_shell.dart`** (xem mục 7 — lý do + hướng dẫn gắn). |
| `test/heavy_task_warning_banner_test.dart` *(mới)* | Widget test cho banner (ẩn khi 0-1 loại tác vụ, hiện khi ≥2 loại, nút dismiss). |
| `scripts/qa/thermal_soak_test.sh` *(mới)* | Script adb đo nhiệt độ pin/%CPU/RAM theo thời gian trên thiết bị thật — kèm kịch bản tái hiện rủi ro #1 và tiêu chí pass/fail gợi ý. |

**Nguyên tắc thiết kế xuyên suốt:** mọi thay đổi đều CHỈ QUAN SÁT (observe),
không chặn (block) hay đổi timeout/kết quả của bất kỳ luồng hiện có nào — trừ
`AsyncMutex` cho Whisper (mục đích rõ ràng là xếp hàng, đã ghi trong mục #2).
Lý do: không có Flutter SDK/thiết bị để chạy lại toàn bộ test suite hiện có
(`test/`, `packages/*/test/`), nên MỌI thay đổi có khả năng đổi hành vi cần
được giữ ở mức tối thiểu, dễ review bằng mắt, và không đụng vào logic
try/catch/timeout đã được vá nhiều lần (xem các comment "FIX AI-CHAT-0x",
"HYMT-00x" trong code — dấu hiệu rõ đây là vùng code đã "trả giá thật" nhiều
lần).

---

## 5. Khuyến nghị tiếp theo (CHƯA làm trong PR này — cần thiết bị thật để xác minh)

### 5.1 — Điều phối thật giữa 2 isolate llama.cpp (không chỉ quan sát)

Có 2 hướng, cả hai đều cần sửa sâu vào `AiEngineGemma`/`HyMtEngine` (vùng
nhiều `FIX AI-CHAT-0x`/`HYMT-00x`) — **nên làm trên máy có Flutter SDK thật +
test runtime**, không nên làm mù trong sandbox không build được:

- **(a) Gộp engine:** `HyMtEngine` dùng chung 1 isolate với `AiEngineGemma`
  thay vì tự load model riêng (cần 1 isolate load được NHIỀU model tuần tự,
  hoặc 1 request router). Giảm RAM (1 model resident thay vì 2) nhưng đổi lại
  dịch + chat phải xếp hàng chờ nhau (trade-off UX cần bàn với sản phẩm).
- **(b) Token điều phối liên-isolate:** main isolate giữ 1 "lượt generate" duy
  nhất; cả 2 isolate con phải xin phép qua SendPort trước khi gọi
  `native.generate()` (không phải trước khi load model — load có thể song
  song, chỉ generate cần tuần tự vì đó là lúc CPU bị chiếm nặng nhất).

### 5.2 — Hạ `n_threads` động khi phát hiện chồng chéo

`HeavyTaskMonitor.instance.hasOverlappingHeavyTasks` đã có sẵn — có thể dùng
tín hiệu này để truyền `threads: 2` thay vì `threads: 4` vào
`native.create()`/mỗi lượt generate khi phát hiện ≥2 engine cùng chạy, giảm
đỉnh CPU dù chạy chậm hơn đôi chút. Cần đo trên thiết bị thật để chọn số
luồng hợp lý theo số lõi thực tế (`Platform.numberOfProcessors` hiện chưa
được dùng ở đâu trong 2 file native binding).

### 5.3 — Thêm cảm biến nhiệt độ pin thật (platform channel)

Thêm `BroadcastReceiver` cho `Intent.ACTION_BATTERY_CHANGED` trong
`MainActivity.kt` (đã có sẵn pattern MethodChannel trong file này, xem
`in4up/audiolib`/`in4up/textlib`) → expose `getBatteryTemperature()` → Dart
service mới có thể hoãn tác vụ nền (auto-TOC, auto-fallback Whisper) khi nhiệt
độ vượt ngưỡng (gợi ý 42-45°C, cần hiệu chỉnh theo dữ liệu
`thermal_soak_test.sh` thu được trên vài dòng máy thật).

### 5.4 — Crash reporting

Thêm `firebase_crashlytics` (Firebase đã có sẵn trong app) +
`runZonedGuarded`/`FlutterError.onError`/`PlatformDispatcher.instance.onError`
trong `main.dart` để đội dev THẤY được crash/ANR thật từ người dùng — kể cả
không liên quan trực tiếp tới audit này, đây là lỗ hổng quan sát nên vá sớm.

### 5.5 — Đóng gap `WhisperSttEngine` (mục #2)

Khi có thời gian: hoặc xoá hẳn `WhisperSttEngine`/`SttEngineRegistry` nếu
thật sự không còn dùng, hoặc chuyển `AsyncMutex`/`HeavyTaskMonitor` xuống bên
trong `SttEngineWhisper` (thấp hơn 1 tầng) để MỌI đường gọi (kể cả tương lai)
đều được bảo vệ, không phụ thuộc việc caller có đi qua `SttServiceFacade` hay
không.

---

## 6. Quy trình kiểm thử thủ công đề xuất (bắt buộc trước khi đóng audit)

Chạy `scripts/qa/thermal_soak_test.sh <package> <giây>` trong lúc thao tác
theo kịch bản ghi trong chính script (dịch Hy-MT + AI chat + bóc băng Whisper
cùng lúc, lặp lại 3-5 lần trong 10 phút) trên **ít nhất 1 máy Android tầm
trung/thấp** (ưu tiên máy đã có dấu hiệu nóng/giật trong phản hồi người dùng
trước đây, nếu có). Script xuất CSV nhiệt độ pin + %CPU + RAM tiến trình theo
thời gian — xem tiêu chí PASS/FAIL ngay trong header của script.

Khuyến nghị bổ sung khi có thiết bị: bật `adb shell dumpsys batterystats
--reset` trước phiên test, so sánh pin tiêu thụ ("Estimated power use") của
app TRƯỚC/SAU khi có bản vá single-flight Whisper (mục 4) để định lượng cải
thiện thật, không chỉ dựa vào suy luận code.

---

## 7. Cách tích hợp `HeavyTaskWarningBanner` vào UI thật (chưa làm — cố ý)

`lib/widgets/heavy_task_warning_banner.dart` **cố tình chưa được gắn** vào
`lib/screens/main_shell.dart` (2300+ dòng, cấu trúc `Stack`/`Column` lồng
nhau) vì không có cách render/kiểm tra bằng mắt trong môi trường này — sửa mù
vào 1 file UI lớn như vậy có rủi ro vỡ layout không ai lường trước được khi
không build/run được.

**Hướng dẫn gắn (làm trên máy có Flutter SDK + chạy thử trực quan):**

```dart
// Trong MainShell.build(), thêm vào đầu Column bên trong Scaffold.body:
Column(
  children: [
    HeavyTaskWarningBanner(
      message: context.uiText('Nhiều tác vụ AI/dịch/giọng nói đang chạy '
          'cùng lúc — máy có thể nóng và tốn pin hơn bình thường.'),
    ),
    _buildAppBar(context),
    // ...phần còn lại giữ nguyên
  ],
),
```

Nhớ đăng ký chuỗi `message` qua đúng luật i18n ở AGENTS.md mục 5 (ARB hoặc
`uiText('…')` + bản `en` trong `tool/legacy_ui_english_overrides.json`) khi
gắn vào UI thật — widget bản thân KHÔNG chứa chuỗi hiển thị nào để tránh vi
phạm luật này khi còn ở trạng thái "chưa gắn".
