# ADR-0022 — TTS native VieNeu-TTS v3 Turbo qua audio.cpp (GGUF, C ABI)

- **Trạng thái:** đề xuất trên nhánh `arena/5f49ec81-in4up` (ticket `TTS-VIENEU-001`);
  chưa merge. Chưa có CI/nhiệm thu thiết bị thật (sandbox không có Flutter SDK
  và Android NDK ⇒ không build APK local; owner builds trên máy dev/CI theo
  phần "Kiểm thử" bên dưới).
- **Bối cảnh:** in4up hiện có hệ thống TTS phụ thuộc platform (Windows TTS /
  Edge voice qua PR #98) — không có giọng Việt chất lượng cao, ổn định, chạy
  offline trên Android/Linux cho module Tipiṭaka. Có tiền lệ kiến trúc GGUF +
  native C++ + FFI: UltraTimeStretch Engine V2, Gemma-IT backend (llama.cpp,
  PR #23 fix timeout), Hy-MT (dịch, import file .gguf thủ công).

## Quyết định

### D1 — Engine mới: audio.cpp + VieNeu-TTS v3 Turbo GGUF (Q8_0)

- Dùng runtime **audio.cpp** (github.com/0xShug0/audio.cpp, commit be1286e0,
  Apache-2.0) — pure C++ inference trên ggml, có **C ABI ổn định**
  (`include/audiocpp.h`: registry → model → session → request → result), không
  cần viết lại lớp C API từ zéro (trả lời câu hỏi 1 của ticket: audio.cpp đã
  có C API/library mode, ngoài CLI `audiocpp_cli`).
- Model: `vieneu-v3-turbo-q8_0.gguf` (~170 MB) từ
  `pnnbao-ump/VieNeu-TTS-v3-Turbo-GGUF` (Apache-2.0, 0.1B params, 48 kHz,
  tiếng Việt + Anh, 23 giọng preset). **Không bundle vào APK**; người dùng
  import file .gguf thủ công vào `documents/vieneu_tts/` giống Hy-MT, sau đó
  engine mới khả dụng.
- **Tại sao Q8_0 thay vì bf16 (292 MB):** trên thiết bị Android midpoint
  (RAM phổ biến, CPU trung bình), Q8_0 đã đủ chất lượng đọc văn bản
  Tipiṭaka (không cần độ chính xác trọng số của bf16), gấp gần 2 lần nhỏ hơn
  ⇒ tải nhanh hơn, chiếm ít RAM hơn, ít nguy cơ OOM khi nạp vào ngữ cảnh
  ứng dụng cùng UltraTimeStretch. bf16 giữ làm tùy chọn sau nếu owner muốn.
- Chỉ dùng engine này để đọc **bản dịch tiếng Việt** — lọc theo trường ngôn
  ngữ của schema Tipiṭaka (chunks `languageCode = 'vi'`/`vi-VN`); Pali (mūla,
  chuyển sang 'hi' trong tipitaka_tts.dart) và Anh **không** đọc bằng engine
  này ⇒ fallback tự động qua engine khác (không crash).

### D2 — Native: CPU backend, Android arm64-v8a đầu tiên

- Build `libvieneu_tts.so` qua `android/app/src/main/cpp/ai/CMakeLists.txt`
  (submodule `third_party/audio.cpp`, auto-init nếu thiếu, cùng mẫu
  `third_party/llama.cpp`): `AUDIOCPP_BUILD_C_API=ON`,
  `AUDIOCPP_MODEL_SET=custom` (chỉ `vieneu_v3_turbo`), tắt CUDA/HIP/Vulkan/
  Metal/WebGPU/RKNN, `ENGINE_ENABLE_NATIVE_CPU=OFF` (cross-compile NDK),
  `ENGINE_ENABLE_OPENMP=OFF`, `ENGINE_ENABLE_LLAMAFILE=OFF` (tránh lỗi fp16
  NEON trên armeabi-v7a). Wrapper C `native/tts_vieneu/vieneu_tts.{h,cpp}`
  exposes `init(model_path, voice_files)` /
  `synthesize(text, language, rate, pitch) -> pcm` /
  `destroy`, mappingonto audiocpp C ABI.
- Nếu audio.cpp submodule chưa init ⇒ CMake chỉ WARNING, app vẫn build và
  Dart engine báo chưa sẵn sàng ⇒ fallback về TTS cũ, **không crash**.
- **Ngoài phạm vi bản đầu:** GPU backend (Vulkan/CUDA), voice cloning từ mẫu
  thu âm (ticket riêng sau).

### D3 — Dart FFI: worker isolate riêng

- `packages/in4up_stt/lib/tts/vieneu_tts_core.dart` + `vieneu_tts_worker.dart`:
  toàn bộ lệnh nạp model/synthesize chạy trong **worker isolate riêng** qua
  `Isolate.spawn`, giao tiếp JSON-like qua `SendPort`; WAV 16-bit encode ở
  Dart rồi pipe vào pipeline phát âm hiện có (`TtsCache` + `just_audio`
  `AudioPlayer` — tái dùng UI play/pause/seek của Windows TTS/Edge).
- Trả lời câu hỏi 2 của ticket: ✅ cần isolate riêng để tránh block UI thread
  khi synthesize đoạn dài (TTS engine là synchronous native call), tương tự
  Gemma-IT generate (abort/timeout, PR #23).

### D4 — UI/Settings + i18n

- Đăng ký engine `vieneu_tts` trong `TtsService._buildDefaultEngineOrder`
  (priority 0, cạnh Piper/Offline/Edge), xuất hiện tự động trong section
  Cài đặt đọc (`TtsSettingsSection` → engine order, check engine status).
- `speak()` lọc theo ngôn ngữ: vieneu_tts chỉ lấy khi `lang.startsWith('vi')`
  (tiết kiệm cố gắng synthesize Pali/Anh và phải fallback).
- Fallback an toàn: `isAvailable()` = false khi lib/model thiếu ⇒ chuỗi engine
  kế tiếp chạy bình thường; mọi lỗi synthesize bắt `catch` → `TtsResult.failure`
  ⇒ không crash app.
- Chuỗi UI mới đã vào ARB (`app_en`/`app_vi` + 4 locale ưu tiên `hi`/`zh`/
  `zh_TW`/`si` theo rule #5), regeneration `generated_ui_translations.dart`;
  credits license Apache-2.0 (audio.cpp + VieNeu-TTS) trong Settings → License.

### D5 — License

- audio.cpp (Apache-2.0, ShugoAI LLC) + VieNeu-TTS v3 Turbo (Apache-2.0,
  Phạm Nguyễn Ngọc Bảo/pnnbao-ump) → tương thích với giấy phép
  Source-Available Non-Commercial của in4up (không sản phẩm thương mại mở,
  không xung đột). Ghi credit trong About/Licenses (Settings → TTS → License)
  và KANBAN card.

## Các lựa chọn đã xét

| Lựa chọn | Lý do bỏ |
|---|---|
| Giữ 2 hệ TTS (Windows/Edge + Piper) | Không giải quyết được giọng Việt ổn định offline trên Android (mục tiêu ticket). |
| Edge TTS online cho tiếng Việt | Cần mạng, không thỏa "offline hoàn toàn, không cần Python runtime". |
| Viết lớp C API mỏng bao quanh `audiocpp_cli` (CLI mode) | audio.cpp đã có C ABI ổn định (`audiocpp.h`) ⇒ không cần, giảm sai sót. |
| Build audio.cpp full model set | Kéo nhiều phụ thuộc model không liên quan ⇒ build chậm, APK lớn; dùng `MODEL_SET=custom` chỉ vieneu_v3_turbo. |
| `ENGINE_ENABLE_NATIVE_CPU=ON` | `-march=native` sai khi cross-compile NDK ⇒ tắt, dùng kernel CPU portable của ggml (runtime CPU detection). |

## Kiểm thử (pending — cần máy thật + NDK)

- `flutter analyze` + `flutter test` rule #5 (locale chrome) xanh.
- CI GitHub Actions "App Analyze + Locale Test" pass.
- Đọc thử ≥ 3 đoạn Tipiṭaka tiếng Việt khác nhau bằng giọng VieNeu trên
  thiết bị Android thật; đính kèm log/benchmark: thời gian load model +
  thời gian tổng hợp mỗi đoạn vào PR (thói quen các PR trước).
- Fallback: gỡ model .gguf ⇒ app vẫn đọc được bằng Piper/Offline/Edge, không
  crash.
- Ticket tracking: KANBAN card `TTS-VIENEU-001` (append theo luật
  GOVERNANCE.md §3) kèm ghi chú quyết định này.
