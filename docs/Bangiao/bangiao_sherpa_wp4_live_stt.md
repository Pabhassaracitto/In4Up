# PROMPT_AGENT_SHERPA_WP4_LIVE_STT_HANDOFF.md
# Prompt giao việc — WP4: Live STT OFFLINE qua sherpa Zipformer (cabin không phụ thuộc speech service hệ thống)

Bạn là agent tiếp nhận trên **branch mới từ tip DEV** (`arena/01a0251e-in4up`).
KHÔNG làm trên DEV, KHÔNG cherry-pick gì từ DEV ngoài việc bắt đầu từ tip.

## Bối cảnh bắt buộc (đọc TRƯỚC khi code)
- `AGENTS.md` + rule vàng #5 (i18n: EN fallback + vi/hi/zh/zh_TW/si,
  không bao giờ fallback về VI khi locale khác).
- `docs/project/PLAN.md` — **PLAN-008** (lộ trình sherpa: VAD ✅ →
  **Live STT (WP này)** → TTS VITS ✅ → STS cabin ✅), **PLAN-022**
  (WP2/WP3 đã harvest + bẫy), **PLAN-023** (mục của WP4).
- `docs/project/KANBAN.md` — SHERPA-001/002/003, SHERPA-WP23-01,
  **CABIN-001** (cabin hiện chạy bằng speech service hệ thống — WP4
  giải quyết hạn chế đó), SHERPA-WP4-01.
- `docs/project/MODELS.md` — quy ước đặt/tải model trong app
  (folder + tên file + KHÔNG auto-download + size guard).
- `docs/Bangiao/bangiao_sherpa.md` — handoff WP2/WP3 (format báo cáo
  "WP DONE" + bẫy không lặp lại).
- `lib/features/vad/README_VAD_TTS_STREAMING.md`.

### Code tham khảo BẮT BUỘC đọc trước (đã chạy trong DEV)
- `packages/in4up_stt/lib/stt_engine.dart` — interface `SttEngine`
  (`startListening`/`stopListening`/`liveResultStream`/`capabilities`/
  `transcribeFile`) + `SttFileResult`.
- `packages/in4up_stt/lib/stt_engine_sherpa.dart` — **PoC** `SherpaSttEngine`
  (đã có `OfflineRecognizer`/`OnlineRecognizer` skeleton — WP4 hoàn thiện
  thành engine live thật; đừng viết lại từ đầu, build trên PoC).
- `packages/in4up_stt/lib/vad/sherpa_vad_core.dart` — **API plugin
  sherpa_onnx v1.13.4 ĐÃ VERIFY từ source k2-fsa** (initBindings() một
  lần, `VoiceActivityDetector`, `acceptWaveform`, `isDetected`,
  `front()/pop()/flush()/free()`, `readWave`) — MẪU chuẩn cho mọi API
  sherpa trong repo.
- `packages/in4up_stt/lib/sherpa_model_manager.dart` — pattern
  download/import/verify/watch model (VAD + Piper): `SherpaModelInfo`,
  BehaviorSubject state, size guard kiểu `vadMinBytes/vadMaxBytes`,
  URL fallback list, KHÔNG auto-download.
- `packages/in4up_stt/lib/stt_service_facade.dart` — `startListening`/
  `startConversation` (CABIN-001), `liveResultStream`, routing engine.
- `lib/features/cabin/services/stts_cabin_service.dart` — consumer
  (CABIN-001: self-heal + keep-alive 4s + message lỗi hành động được).
- `lib/features/shadowing/services/recording_service.dart` — pattern
  mic với `record` 6.x (APP-level dependency).
- `lib/features/tts/widgets/tts_settings_section.dart` — UI model
  sherpa trong "Quản lý Model AI" (pattern cho UI ASR model mới).
- `lib/screens/settings/stt_model_settings_screen.dart` — UI model
  Whisper (tham khảo UX).

## Vấn đề gốc (tại sao có WP4)
Cabin (CABIN-001, CI xanh @ a1a36e5) dùng `speech_to_text` = **speech
service HỆ THỐNG**: máy không có Google/Speech Services → không khởi
động được mic; một số engine hệ thống cần mạng. WP4 = live STT
**OFFLINE** qua sherpa-onnx Zipformer → cabin chạy trên mọi máy,
airplane mode, không phụ thuộc Google.

## Thực tế model — ĐÃ VERIFY từ docs chính thức k2-fsa (2026-09-05)
> KHÔNG bịa thêm URL/model ngoài danh sách này. Size/giải nén kiểm tra
> lại khi cài (guard kiểu `vadMinBytes`), không hard-code size từ trí nhớ.

### 1) Offline Zipformer TIẾNG VIỆT — cho "simulated streaming" (VAD endpointing)
- **`sherpa-onnx-zipformer-vi-30M-int8-2026-02-09`** (ƯU TIÊN — nhỏ, int8):
  - URL: `https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-zipformer-vi-30M-int8-2026-02-09.tar.bz2`
  - File (đã verify từ docs): `tokens.txt` (23K) + `encoder.int8.onnx`
    (26M) + `decoder.onnx` (4.9M) + `joiner.int8.onnx` (1.0M) ≈ **32MB**
    + `bpe.model` + `test_wavs/`.
  - 6000h data VI chất lượng cao (HF: hynt/Zipformer-30M-RNNT-6000h),
    RTF ~0.011 — chạy real-time dư dả trên tablet.
- Dự phòng (nếu 30M thiếu chính xác ở giọng vùng miền):
  `sherpa-onnx-zipformer-vi-int8-2025-04-20` /
  `sherpa-onnx-zipformer-vi-2025-04-20` (cùng pattern URL).
- **KHÔNG tồn tại** Zipformer **streaming-thật** tiếng Việt — VI phải
  dùng simulated streaming (offline + VAD), như binary chính thức
  `sherpa-onnx-vad-microphone-simulated-streaming-asr`.

### 2) Streaming-thật Zipformer TIẾNG ANH (OnlineRecognizer, token-by-token)
- **`csukuangfj/sherpa-onnx-streaming-zipformer-en-20M-2023-02-17`**
  (20M params — ĐỦ NHỎ cho mobile; int8). URL pattern:
  `https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-zipformer-en-20M-2023-02-17.tar.bz2`
  (file layout + size verify trên release page khi cài).
- Các EN 2023 khác (en-2023-02-21, en-2023-06-21/26, bilingual zh-en
  2023-02-20) có encoder int8 **174-180MB** — KHÔNG dùng làm mặc định
  (quá nặng cho mobile); chỉ dùng nếu owner yêu cầu chất lượng cao.
- Endpoint rules mặc định của OnlineRecognizer (verify từ docs):
  rule1 (im lặng 2.4s), rule2 (có speech + im lặng 1.2s),
  rule3 (câu tối đa 20s) — **tune rule1/rule2 xuống ~1.2s/0.8s** cho
  nhịp hội thoại cabin (tham số trong `OnlineRecognizerConfig`).

### 3) Kiến trúc endpointing (quyết định đã chốt — agent thực thi)
- **Source = VI** → simulated streaming: `OfflineRecognizer` (vi-30M-int8)
  + **Silero VAD** (model đã có sẵn trong app:
  `sherpa_vad_models/silero_vad.onnx` — tái dùng `SherpaVadCore` hoặc
  `sherpa.VoiceActivityDetector` trực tiếp trên PCM stream):
  - PCM 16kHz mono 16-bit → feed VAD + tích luỹ theo speech segment;
  - khi VAD `isDetected()` (kết thúc đoạn nói) → decode OfflineRecognizer
    cho segment → **final result** vào `liveResultStream`;
  - **partial**: decode tăng dần mỗi ~0.4-0.6s trong segment đang nói
    (tối ưu: chỉ decode phần mới nếu recognizer cho phép, nếu không thì
    re-decode segment — ghi rõ trade-off trong báo cáo);
  - ghi rõ trong UI/báo cáo: partial của VI là **theo chunk**, không
    token-by-token (hạn chế nội tại của simulated streaming).
- **Source = EN** → streaming thật: `OnlineRecognizer`
  (en-20M int8) + endpoint rules tune → partial token-by-token +
  final khi endpoint (rule1/2/3) — đúng nghĩa "Zipformer streaming".
- **Source khác** (zh/th/hi...) → chưa có model → trả lỗi rõ
  "Chưa có model offline cho ngôn ngữ này — dùng engine Hệ thống",
  KHÔNG crash, KHÔNG auto-download.

## Nhiệm vụ
### N1 — Engine sherpa live (`packages/in4up_stt`, TRÊN PoC có sẵn)
1. Hoàn thiện `SherpaSttEngine` (hoặc tách class mới nếu rõ ràng hơn)
   implement `SttEngine`:
   - `capabilities`: `supportsLiveMic: true`, `supportsOffline: true`.
   - **Engine nhận PCM, không tự mở mic** (mic thuộc APP — package
     `record` ở app-level, in4up_stt KHÔNG thêm dependency record):
     - API gợi ý: `Future<bool> startLive({required String language,
       required Stream<List<int>> pcm16k16bit})` +
     - `liveResultStream` phát `SttResult` (partial + final,
       `hasWordTimestamps` khi có) — facade bridge sang
       `startListening()` hiện có (giữ interface cũ để cabin/voice
       command không phải sửa).
   - `initialize()`: chỉ khi model ĐÃ NẰM SẴN trên device
     (thông qua `SherpaModelManager` state) — KHÔNG download trong
     function, KHÔNG tạo model nếu thiếu (trả lỗi rõ).
   - Singleton theo session + **Pointer C-struct giữ đúng thứ tự
     init/free** (bẫy FFI PLAN-008: initBindings() 1 lần; free
     recognizer/stream trước khi tạo mới; không re-init liên tục).
   - `dispose()` sạch: stream cancel, recognizer.free(), không leak
     (test: start/stop 50 lần không leak — đo bằng log).
2. Unit test (chạy được không cần device):
   - feed PCM tổng hợp (sine/silence/speech-like) qua engine mock →
     đúng thứ tự partial/final, endpoint đúng ngưỡng;
   - engine selection: VI→offline+VAD, EN→online, khác→lỗi rõ;
   - `SttResult` mapping (text, timestamps, isFinal).

### N2 — Model management (mở rộng `SherpaModelManager` + UI)
1. Model type mới **"Zipformer ASR (Live STT)"**:
   - folder: `<documents>/sherpa_asr_models/` (theo convention
     MODELS.md — cập nhật bảng tổng hợp trong MODELS.md).
   - 2 profile mặc định:
     - `asr-vi-30M-int8` ← `sherpa-onnx-zipformer-vi-30M-int8-2026-02-09`
       (tokens.txt + encoder.int8.onnx + decoder.onnx + joiner.int8.onnx);
     - `asr-en-20M-streaming-int8` ←
       `csukuangfj/sherpa-onnx-streaming-zipformer-en-20M-2023-02-17`
       (tokens.txt + encoder*.int8.onnx + decoder*.onnx + joiner*.int8.onnx —
       tên file thật verify từ release khi cài).
   - **Import** (thư mục đã giải nén / file lẻ) + **Tải về** (chỉ khi
     user bấm — quy tắc MODELS.md, KHÔNG auto-download) + verify
     (đủ file + size guard — size thật verify khi cài) + watch state
     (BehaviorSubject như VAD/Piper) + tiến độ tải.
   - UI trong "Quản lý Model AI" (home): section mới pattern như
     Piper (tts_settings_section.dart): trạng thái model, nút
     Import/Tải/Xoá, message lỗi hành động được.
2. Cabin/Shadowing thiếu model → **message dẫn đường** (vào Quản lý
   Model AI để import/tải) — KHÔNG crash, KHÔNG fallback im lặng.

### N3 — Routing + Cabin
1. `SttServiceFacade`: thêm **live engine selection**
   (`system` | `sherpa-offline`) — lưu SharedPreferences
   (key rõ, default `system`); `startListening`/`startConversation`
   route tới engine đã chọn (system = `SttEngineNative` hiện tại —
   CABIN-001 giữ nguyên; sherpa = engine mới). Engine sherpa thiếu
   model → trả false + `liveLastError` cụ thể (cabin hiện message).
2. `SttsCabinService`: KHÔNG đổi pipeline (STT→translate→TTS); chỉ
   chọn engine. Thêm **chip/toggle "Engine mic: Hệ thống | Offline
   (sherpa)"** trong cabin UI (gần ngôn ngữ nguồn) — đổi engine khi
   đang nghe → stop + start lại. i18n đủ 6 locale.
3. **Scope KHÔNG làm (tránh phình):** Voice command (WP3) + Shadowing
   giữ engine `system` (chỉ cabin đổi được engine); không nối engine
   sherpa vào LRC pipeline (file transcription vẫn Whisper); không làm
   direct S2S (WP sau).

### N4 — Docs + i18n + KANBAN
- Cập nhật `MODELS.md` (bảng model + URL + cách đặt + size) +
  `README_VAD_TTS_STREAMING.md` (kiến trúc live STT) + KANBAN
  SHERPA-WP4-01 (trạng thái + SHA + AT).
- Mọi chrome mới (toggle engine, state model, message thiếu model):
  rule #5 — EN fallback hợp lệ + vi/hi/zh/zh_TW/si.

## Bẫy không được lặp lại (từ CABIN-001 + WP3 + PLAN-022)
- **KHÔNG bịa URL/model Zipformer** — chỉ dùng danh sách "Thực tế
  model" ở trên; **KHÔNG auto-download** (quy tắc MODELS.md).
- **KHÔNG khai báo trùng** dependency `sherpa_onnx` (đã có ^1.13.6
  trong in4up_stt pubspec) — thêm dependency là sửa 1 chỗ, không
  duplicate key (pub get lỗi).
- `record` là dependency **APP** — engine sherpa nhận PCM stream,
  app pipe mic; KHÔNG thêm `record` vào in4up_stt.
- **Pointer C-struct**: initBindings 1 lần/session, free đúng thứ tự,
  không re-init liên tục (bẫy FFI — PLAN-008 + SherpaVadCore).
- **`Timer.periodic` closure phải 1-arg `(_)`** — bản 0-arg `()` bị
  analyze đỏ (bẫy thực tế vừa gặp ở CABIN-001, mất ~15 CI run để cô lập).
- **`Map.map()` trả `Iterable`, KHÔNG phải `Map`** — cần
  `{for (...)}` hoặc `.toMap()` (bẫy thực tế vừa gặp).
- **Một mic pipeline**: một phiên một engine; không tạo recorder
  song song; stop/cancel sạch trước khi start lại (bẫy CABIN-001:
  mic treo chiếm phiên).
- **CI là oracle** (sandbox không có Flutter SDK — skill
  `docs/skills/ci-red-debugging/SKILL.md`); chạm path `lib/**` để
  paths-filter trigger workflow; docs bị ignore thì `git add -f`.
- **Không sửa `.github/workflows/`.** Không chèn snippet vào file bằng
  mắt khi đã có conflict — kiểm tra `git diff` sau mỗi bước.
- API sherpa_onnx: chỉ dùng API **đã verify** (mẫu: header
  `sherpa_vad_core.dart` ghi rõ API v1.13.4 verify từ source); nếu
  cần API khác (OnlineRecognizer/OfflineRecognizer/Vad live) → verify
  từ source plugin (github k2-fsa/sherpa-onnx, api-dart/examples)
  TRƯỚC khi code, ghi chú verify trong commit message.

## Kiểm tra và báo cáo
- `flutter analyze` sạch (CI **App Analyze + Locale Test** xanh) —
  CI là oracle; test unit N1 chạy trong `flutter test`.
- Báo cáo format (copy chính xác):

```
WP4 DONE
- Branch/SHA:
- CI run:
- AT đạt/chờ thiết bị:
- Known limitation:
  (VD: partial của VI là theo chunk VAD, không token-by-token;
   EN streaming cần model ~30-60MB; nguồn khác chưa có model)
- Files:
```

- **AT thiết bị (owner chạy — nghiệm thu):**
  1. Cabin, source VI, engine Offline: nói → caption hiện sau khi dừng
     nói ~0.5-1.5s (simulated streaming) + partial theo chunk.
  2. Cabin, source EN, engine Offline: nói → partial hiện LIVE
     (token-by-token) + final khi im lặng.
  3. **Airplane mode** → cả 2 vẫn chạy (offline thật).
  4. Máy KHÔNG có speech service (hoặc tắt) + engine Hệ thống → lỗi cũ;
     engine Offline → vẫn chạy (điểm khác biệt cốt lõi).
  5. Thiếu model → message dẫn đường tới Quản lý Model AI, không crash.
  6. Dịch + dubbing (TTS Piper) + bubble 1 chữ/1 dòng/full — đúng như
     CABIN-001 (không regression).
  7. Start/stop cabin 10 lần → không leak (log), không mic treo
     (bấm mic engine Hệ thống sau đó vẫn chạy).
- Gửi SHA cho **leader DEV (`arena/01a0251e-in4up`)** để cherry-pick `-x`
  harvest + nghiệm thu thiết bị. **Không tuyên bố done nếu chỉ có code
  mà chưa báo trạng thái CI trung thực.**
