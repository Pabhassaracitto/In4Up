# ADR-0007: Tầng Server API cho AI (cloud + LAN) — OpenAI-compatible, BYOK, offline-first

- **Ngày:** 2026-09-27
- **Trạng thái:** WP0 (API-001) ĐÃ TRIỂN KHAI + **CI XANH** (run
  36268246588: analyze + rule #5 + LHB + cabin) trên
  `arena/01a0ddd1-in4up` — còn nghiệm thu thiết bị. 38 key ARB mới thuộc
  keepEnglish (tiền lệ sound_*) chờ T3 dịch dần.
- **Phạm vi WP0:** `packages/in4up_ai/lib/src/provider/**` (mới: config +
  store + client), `lib/screens/settings/ai_providers_screen.dart` (mới),
  entry card trong `stt_model_settings_screen.dart`, 38 key ARB × 26 locale,
  `ios/Runner/Info.plist` (ATS local), `test/ai_provider_wp0_test.dart`.
  **Không** đụng engine nào (WP1–WP4 mới cắm engine remote), **không** thêm
  dependency mới, **không** đụng `lib/ffi/`.
- **Nguồn:** owner (2026-09-26/27) — yêu cầu tầng API giải phóng RAM/nhiệt
  cho app; bản tư vấn `docs/server_api_tu_van.md` (nhánh
  `arena/01a0ddd1-in4up`) + prompt `PROMPT_AGENT_SERVER_API.md`.

## Bối cảnh

- AI on-device hiện tại: Whisper tiny-q4_0 (37MB), Hy-MT GGUF (~600MB),
  Gemma GGUF (load 1–2 phút, isolate hay bị OOM thu hồi — có code `recover()`),
  Piper TTS. Nguyên nhân "app đè máy": RAM ~0,6–1,5GB + nhiệt + thời gian
  load model, không phải UI thread.
- App đã có tiền lệ engine online (Zalo/FPT TTS — API key user nhập;
  DeepLX — URL server user nhập) nhưng mỗi bên tự xử key/URL riêng.
- Owner hỏi rõ 3 mô hình (cloud / PC→Android / server trên chính Android):
  chốt **A (cloud)** + **B (PC trong LAN)** là 2 mô hình hỗ trợ chính thức;
  **C (server trên cùng chiếc Android)** KHÔNG hỗ trợ — RAM vẫn chung một máy
  (không giải phóng được gì) + bị Android kill (Doze/OOM/OEM kill app server
  nền). Chi tiết: Phụ lục B `docs/server_api_tu_van.md`.

## Quyết định

1. **Chuẩn giao tiếp duy nhất: OpenAI-compatible REST**
   (`/v1/models`, `/v1/chat/completions`, `/v1/audio/transcriptions`,
   `/v1/audio/speech`). 1 client (`OpenAiCompatClient`) chạy được với mọi
   nhà cung cấp cloud (Groq/Gemini-compat/OpenRouter/OpenAI…) và server nhà
   (Ollama/LM Studio/llama-server/Speaches/Kokoro) — chỉ khác
   `baseUrl + apiKey + model`. Tên model KHÔNG hard-code — load động qua
   `/v1/models`.

2. **BYOK (Bring Your Own Key):** app KHÔNG kèm key nào; user tự nhập key
   cloud hoặc trỏ tới server nhà (LAN không cần key). Mặc định danh sách
   provider RỖNG và mọi năng lực `offlineFirst` — **chưa cấu hình thì app
   hành xử y hệt trước khi có tầng API** (không có request mạng AI nào đi ra).

3. **Offline-first là xương sống:** mỗi năng lực (chat / STT file / dịch /
   TTS) có routing `offlineFirst` (mặc định) | `onlineFirst` | `offlineOnly`,
   tự fallback 2 chiều. **Giữ on-device:** live STT cabin/shadowing (Zipformer
   — realtime), VAD Silero (dùng cắt chunk TRƯỚC khi upload ở WP2), ML Kit +
   mọi engine offline (lớp fallback cuối).

4. **Bảo mật:**
   - http cleartext CHỈ cho host nội bộ (localhost/IP riêng RFC1918/link-local/
     hostname không dấu chấm/đuôi `.local` `.lan` `.internal` `.home`) — guard
     trong `OpenAiCompatClient.isCleartextAllowed`; cloud provider bắt buộc
     https. iOS: `NSAllowsLocalNetworking` (KHÔNG bật
     `NSAllowsArbitraryLoads`).
   - KHÔNG log key/headers; KHÔNG hard-code key (kể cả key test).
   - **apiKey tạm lưu SharedPreferences** (tiền lệ Zalo/FPT key; interface
     store thiết kế swap sang `flutter_secure_storage` sau mà không đổi
     caller — dependency mới phải owner duyệt, chưa duyệt).
   - Gửi audio lên cloud phải opt-in rõ (dialog lần đầu — làm ở WP2 khi có
     luồng gửi audio; WP0 chỉ có nút test kết nối text-only).

5. **Kiến trúc cắm — không viết lại:** engine remote implement đúng interface
   có sẵn (`AiEngine` WP1, `SttEngine` WP2, `TranslationEngine` WP3,
   `TtsEngine` WP4); mã lỗi cấu trúc theo khuôn `HyMtErrorCode`
   (`AiApiErrorCode`); single-flight/timeout/backoff tái dùng pattern Hy-MT.

## Hệ quả

- Thêm nhà cung cấp mới = 1 dòng preset trong màn cấu hình, không thêm class.
- WP1–WP4 giao cho agent topic riêng theo `PROMPT_AGENT_SERVER_API.md`;
  WP0 phải được leader 251e thu hoạch trước.
- i18n: 38 key ARB mới dịch đủ vi/en + T2 (hi/zh/zh_TW/si) ngay trong PR;
  20 locale T3 dùng giá trị en (canonical fallback — rule vàng #5).
- File generated l10n được cập nhật bằng `tool/wp0_arb_inject.py` (sandbox
  không có Flutter SDK); CI `pub get` sẽ regenerate đúng chuẩn gen-l10n —
  script chỉ để repo nhất quán, KHÔNG phải tool l10n dài hạn.
