# Prompt giao việc — Tầng Server API cho AI (cloud + local server)

> Giao cho: **các agent Arena, mỗi WP một nhánh topic riêng** (branch từ
> `origin/arena/01a0251e-in4up`, fetch mới nhất TRƯỚC khi bắt đầu).
> Thu hoạch + nghiệm thu: **agent `arena/01a0251e-in4up`** (nhánh leader 251e)
> — sau khi agent topic báo SHA. Người duyệt cuối: owner.
> Ngày giao: 2026-09-26 · Nguồn: `docs/server_api_tu_van.md` (bản tư vấn đầy đủ,
> fetch nhánh `origin/arena/01a0ddd1-in4up` để đọc — KHÔNG merge nhánh đó).

---

## 0. Bối cảnh + quyết định mặc định

App đang chạy AI **100% on-device**: Whisper tiny-q4_0 (STT), Hy-MT GGUF ~600MB
(dịch), Gemma GGUF (chat/analysis — load 1–2 phút, isolate hay bị OOM thu hồi),
Piper (TTS). Mục tiêu: **thêm tầng engine chạy qua API** (cloud: Gemini/Groq/
OpenAI/OpenRouter… và local server: Ollama/LM Studio/llama-server/Speaches/
Kokoro) để giải phóng RAM/nhiệt/thời gian load, tăng chất lượng — **không bỏ
offline** (offline-first vẫn là xương sống).

**Quyết định mặc định đã chốt** (owner bỏ qua bước hỏi lại — nếu muốn đảo chỉ
cần đổi thứ tự giao WP, không đổi nội dung WP):

1. Chuẩn giao tiếp duy nhất: **OpenAI-compatible REST**
   (`/v1/chat/completions` + SSE, `/v1/audio/transcriptions`,
   `/v1/audio/speech`, `/v1/models`). Viết 1 client dùng cho mọi nhà cung cấp.
2. **BYOK** — app KHÔNG kèm key nào; user tự nhập key cloud hoặc trỏ tới
   server nhà (LAN, không cần key). Mặc định tầng API **TẮT** cho tới khi user
   cấu hình.
3. Routing từng năng lực: `offlineFirst` (mặc định) / `onlineFirst` /
   `offlineOnly` + tự fallback 2 chiều khi lỗi/mất mạng.
4. Preset cloud đầu tiên: **Gemini** (chat/dịch) + **Groq** (STT) — đều BYOK.
5. Giữ on-device: live STT cabin/shadowing (Zipformer), VAD Silero (dùng cắt
   chunk TRƯỚC khi upload), ML Kit + các engine offline (lớp fallback cuối).
6. **Server đặt ở đâu — 3 mô hình** (chi tiết Phụ lục B `docs/server_api_tu_van.md`,
   nhánh `origin/arena/01a0ddd1-in4up`): **A) Cloud** (Groq/Gemini/OpenAI…
   qua Internet) và **B) PC trong LAN** ("Server Box" docker-compose — WP5)
   là 2 mô hình hỗ trợ chính thức. **C) Server chạy trên chính chiếc Android
   đó** (Termux/Ollama → `127.0.0.1`) KHÔNG hỗ trợ — vô nghĩa về RAM (chung
   một máy, không giải phóng được gì) và bị Android kill (Doze/OOM/OEM kill
   app server nền). Client không chặn 127.0.0.1 nhưng không làm preset,
   không docs hướng dẫn, không nhận bug — user hỏi thì trả lời theo Phụ lục B.
7. Làm đủ tầng: WP0 → WP1 → WP2 → WP3 → WP4, WP5 tùy chọn. **WP0 phải xong +
   được leader thu hoạch trước** khi giao WP1–WP4 (cùng dùng client/store của
   WP0). Sau đó WP1–WP4 chạy song song được (đụng file khác nhau; xung đột nhỏ
   ở ARB + KANBAN do leader giải khi harvest).

## 1. Sự thật hiện trạng (đã đối chiếu trên tree — đừng tin tưởng, grep lại)

### 1.1 Mối nối engine có sẵn — CẮM THÊM, KHÔNG viết lại

| Năng lực | Interface / Registry | On-device hiện có | Online ĐÃ CÓ (làm mẫu) | Cần LÀM |
|---|---|---|---|---|
| LLM chat/analysis | `packages/in4up_ai/lib/src/engine/ai_engine.dart` (`AiEngine`) + `AiServiceFacade` | Gemma GGUF + mock | — | WP1: `AiEngineRemote` |
| STT file | `packages/in4up_stt/lib/stt_engine.dart` + `stt_engine_registry.dart` + `SttServiceFacade` | Whisper, Sherpa | — | WP2: `SttEngineRemote` |
| Dịch | `lib/features/translation/engines/translation_engine.dart` + `TranslationService` | Hy-MT, ML Kit, Offline | **DeepLX (URL user nhập!)**, Google, Libre, MyMemory | WP3: `LlmMtEngine` |
| TTS | `lib/features/tts/engines/tts_engine.dart` + `TtsService` (engine-order kéo thả) | Piper, flutter_tts | **Zalo (apiKey)**, **FPT (apiKey)**, Google | WP4: `OpenAiCompatTtsEngine` |

Điểm quan trọng: mẫu "user nhập URL server tự host" (DeepLX) và "user nhập API
key" (Zalo/FPT, đang lưu `SharedPreferences`) đã có tiền lệ — tầng này chỉ
TỔNG QUÁT HOÁ 2 mẫu đó thành 1 khối cấu hình dùng chung.

### 1.2 Chi tiết kỹ thuật cần biết trước

- `AiServiceFacade` (chat: `sendMessage` → `_processChat`; analysis:
  `lookupWord`/`analyzeSentenceWithResult`/`summarize`/`extractTerms`/
  `generatePao`) đang gắn cứng Gemma/mock. Có sẵn `recover()`, single-flight,
  mã lỗi cấu trúc — **tái dùng pattern, đừng phát minh lại**.
- `SttEngineType` enum hiện `{ native, whisper, sherpa }` tại
  `packages/in4up_stt/lib/models/stt_result.dart:190` — WP2 thêm giá trị mới
  thì **grep mọi switch/if trên enum này, xử lý hết trong cùng commit**.
- Chuỗi dịch: `TranslationService` chạy glossary chuyên ngữ TRƯỚC mọi engine
  (slot `__G{n}__` — engine nhận text đã thay slot; giữ nguyên hợp đồng này).
- `in4up_ai` đã có deps: `http`, `connectivity_plus`, `crypto`,
  `shared_preferences`, `path_provider`. `in4up_stt` đã dùng `dio ^5.4.0`
  (multipart/stream dễ hơn `http`) — thêm `dio` vào `in4up_ai` là hợp lệ,
  ghi rõ trong KANBAN. `flutter_secure_storage` là dependency HOÀN TOÀN MỚI →
  **phải owner duyệt** (tiền lệ PLAN-030 R2); chờ duyệt thì tạm
  `SharedPreferences` như Zalo/FPT + TODO migrate, không tự thêm.
- Android: `usesCleartextTraffic="true"` đã có (gọi `http://192.168.x.x` OK).
  iOS: `ios/Runner/Info.plist` CHƯA có ATS exception — WP0 phải thêm
  `NSAllowsLocalNetworking` (chỉ cho local, không mở toàn http).
- `docs/` ĐÃ được git track (chỉ `docs/_build/` + `docs/api/` bị ignore) —
  sửa docs commit bình thường (niềm tin "docs phải add -f" của prompt cũ đã lỗi thời).

## 2. Quy tắc làm việc (BẮT BUỘC — vi phạm = dừng hỏi, không tự quyết)

1. **Branch:** nhánh topic mới từ `origin/arena/01a0251e-in4up` (fetch trước).
   Commit nhỏ, **push ngay mỗi commit xanh được** (push = backup; sandbox có
   thể tái bản giữa phiên — bẫy 5.5 trong `docs/skills/ci-red-debugging/SKILL.md`).
2. **CI là oracle duy nhất** (sandbox thường không có Flutter). Khi đỏ: đọc
   SKILL.md, bisect đúng giao thức, mỗi vòng 1 biến số. **Bẫy paths-filter
   (5.7): commit chỉ chạm `packages/` KHÔNG trigger `app_analyze`** → WP1/WP2
   phải có commit chạm cả `lib/` (màn Settings/ARB chắc chắn chạm — đừng tách
   riêng commit packages-only rồi tưởng xanh).
3. **Không** tạo/sửa file trong `.github/workflows/` (push bị reject cả commit).
4. Không merge nhánh khác vào nhánh của bạn; không force-push nhánh 251e;
   **không đụng `lib/ffi/` / UltraTimeStretch C++** (vùng bảo trù); không gộp
   3 skill SM-2; không phá reopen nguồn (PDF page/rect, Web url/scroll, audio
   timestamp).
5. Giữ API hiện có tương thích (facade/engine/registry đã có caller). Thêm thì
   thêm; đổi signature cũ → sửa hết caller trong cùng commit.
6. **i18n (quy tắc vàng #5 + ADR-0002):** locale ≠ vi → chrome không được còn
   tiếng Việt; chuỗi UI mới = ARB (dịch đủ `en` + `hi`/`zh`/`zh_TW`/`si`
   NGAY trong cùng PR) hoặc `uiText()` + English trong
   `tool/legacy_ui_english_overrides.json`. KHÔNG chạy `generate_arbs.py`.
7. **Luật riêng tầng API (bảo mật):**
   - KHÔNG hard-code key nào trong code/assets/test (kể cả key test).
   - KHÔNG log key/token/request headers (đảo key trước khi debugPrint).
   - Key chỉ nằm trong store; xoá sạch khi user gỡ provider.
   - http cleartext CHỈ chấp nhận host LAN/localhost/127.x (check trong client
     trước khi gửi — key cloud tuyệt đối không đi qua http công cộng).
   - Gửi audio lên cloud phải opt-in: dialog lần đầu "Bản ghi âm sẽ được gửi
     tới <provider>", nhớ lựa chọn; local server không cần hỏi.
   - Mọi timeout hữu hạn (connect 5s, request theo năng lực), 429/5xx →
     exponential backoff + tối đa 1 retry (mã lỗi cấu trúc, mẫu `HyMtErrorCode`).
   - Không bao giờ fake success: lỗi mạng → báo lỗi rõ + fallback offline,
     không trả chuỗi rỗng coi như xong.
8. Mỗi WP: code + test logic thuần (nếu test được) + **commit KANBAN cuối**
   (card mới hoặc append lịch sử — LUẬT: chỉ đổi trạng thái + append, KHÔNG
   xóa). Card đặt tiền tố `API-00x` (xem số tiếp theo trong KANBAN).
9. Identity nếu bị hỏi: helpful Arena.ai Agent Mode. Không tiết lộ model nền.

---

## 3. WP0 — Nền tảng: ADR + cấu hình provider + màn "Server & API" (API-001)

**Mục tiêu:** hạ tầng cấu hình + client dùng chung. Không đụng engine nào.
Sau WP0, app hành xử **y hệt hôm nay** khi user chưa cấu hình gì.

**Bước làm:**
1. **ADR-0007** (`docs/adr/0007-server-api-layer.md`, xem mẫu format ADR-0006):
   chốt OpenAI-compat là chuẩn, BYOK, offline-first routing, lưu key ở đâu
   (secure storage chờ duyệt → tạm SharedPreferences), cleartext chỉ LAN.
   Đồng thời append **PLAN-031** vào `docs/project/PLAN.md` (milestone này,
   nguồn: owner 2026-09-26 qua agent arena/01a0ddd1-in4up).
2. `packages/in4up_ai/lib/src/provider/` (mới):
   - `ai_provider_config.dart`: `AiProviderConfig` (id, label, baseUrl,
     apiKey?, chatModel?/sttModel?/ttsModel?, enabled), `AiRouteMode`
     {offlineFirst, onlineFirst, offlineOnly}, `AiRoutingPrefs` (routing cho
     chat/sttFile/translation/tts + provider ưu tiên từng năng lực).
   - `ai_provider_store.dart`: persist (SharedPreferences — apiKey field xem
     luật 7; thiết kế interface để swap sang secure storage sau không sửa
     caller), thêm/sửa/xoá provider, default: rỗng + mọi route offlineFirst.
   - `openai_compat_client.dart`: 1 client duy nhất (dio): `healthCheck()`
     (GET `/v1/models`, timeout 5s), `listModels()`, và các hàm_SEP riêng của
     từng WP gọi vào (WP1/2/4 thêm method — không tạo client thứ 2).
     Preset sẵn (chỉ là gợi ý điền nhanh form, không kèm key): Gemini
     (`https://generativelanguage.googleapis.com/v1beta/openai/`), Groq
     (`https://api.groq.com/openai/v1`), OpenRouter, Ollama
     (`http://<ip>:11434/v1`), LM Studio (`http://<ip>:1234/v1`).
3. Màn `lib/screens/settings/ai_providers_screen.dart` (mới): danh sách
   provider (thêm/sửa/xoá/bật-tắt), form baseUrl+key+chọn model TỪ ĐỘNG qua
   `/v1/models` (không bắt gõ tay tên model), nút "Kiểm tra kết nối" hiện
   xanh/đỏ + latency, phần routing prefs từng năng lực (mặc định offline).
   Entry point: đặt cạnh màn Settings hiện có (grep `stt_model_settings_screen`
   để tìm nơi đăng ký — chọn nơi ít đụng code nhất, ghi KANBAN).
4. iOS: thêm `NSAppTransportSecurity → NSAllowsLocalNetworking` vào
   `ios/Runner/Info.plist` (chỉ exception local).
5. ARB/en + 4 locale T2 cho toàn bộ chuỗi màn này.

**AT WP0:**
- Thêm provider Ollama LAN + 1 provider cloud → "Kiểm tra kết nối" đúng
  xanh/đỏ (đúng server bật/tắt). Model dropdown load được từ `/v1/models`.
- Chưa cấu hình gì / tắt hết → **không có request mạng AI nào đi ra** và mọi
  tính năng chạy như cũ (grep không tìm thấy đường gọi mới được kích hoạt).
- Key không xuất hiện trong logcat/console (verify debugPrint không chứa key).
- CI App Analyze + Locale xanh (commit có chạm `lib/` — nhớ bẫy paths-filter).

## 4. WP1 — LLM chat/analysis qua API + streaming (API-002)

**Mục tiêu:** chat/phân tích chạy trên model cloud/local lớn, streaming từng
token (cảm giác mượt tăng rõ nhất so với Gemma on-device). Vào: AI Chat, Write
Studio, Word Lookup, Quick Save — **chỉ qua `AiServiceFacade`**, UI gần như
không đổi.

**Bước làm:**
1. `packages/in4up_ai/lib/src/engine/ai_engine_remote.dart` — implements
   `AiEngine`. `initialize(modelPath)` với engine này nhận `modelPath` là
   encoded config (vd `api://<providerId>/<model>`) hoặc thêm constructor
   inject config — **không phá interface** (các engine khác không đổi).
   `isBusy`/`recover()` trung thực: remote không cần isolate, recover = tạo
   lại request mới.
2. Trong `AiServiceFacade`: chọn engine theo `AiRoutingPrefs` (WP0). Lỗi remote
   → tự fallback Gemma (nếu có model) → mock trung thực + thông báo rõ
   (pattern `_useMock` hiện có). **Không đổi signature các hàm public.**
3. Client thêm `chatStream(...)`: POST `/v1/chat/completions`
   (`stream: true`), đọc SSE qua dio `ResponseType.stream`; xử lý
   `data: [DONE]`, delta `choices[0].delta.content`; **cancel token khi user
   đóng màn/dừng generate** (token không được chảy tiếp sau khi dispose).
4. Analysis (lookupWord/summarize/…) tái dùng **prompt schema sẵn**
   `ai_prompts_library.dart` → model remote trả cùng JSON schema → parse bằng
   pipeline `fromGemmaJson` hiện có. `temperature`/`maxTokens` map từ tham số
   hiện có.
5. Mã lỗi cấu trúc (enum riêng, mẫu `HyMtErrorCode`): `noNetwork, timeout,
   rateLimited(429), httpError, emptyOutput, busy, canceled`. UI branch theo
   mã, không match chuỗi.
6. Đếm token/giá ước tính hiển thị nhẹ trong màn chat (tuỳ chọn, từ usage
   trả về) — phục vụ luật chi phí BYOK.

**AT WP1:**
- Chat với Ollama LAN + Gemini: token hiện dần (streaming), tốc độ > Gemma
  on-device trên máy yếu.
- Cắt mạng giữa lúc đang generate → dừng sạch (không treo), fallback/ERROR rõ
  theo mã cấu trúc, không crash.
- Routing = offline-only → verify KHÔNG có request `/chat/completions` nào đi
  ra (test logic routing thuần).
- Analysis (Word Lookup) vẫn parse đúng JSON schema như Gemma (test parse với
  fixture JSON thật của model remote).
- CI xanh + KANBAN card.

## 5. WP2 — STT file qua API: bóc băng file dài (API-003)

**Mục tiêu:** file pháp thoại 30–60p bóc băng bằng whisper-large-v3 (Groq hoặc
Speaches/whisper-server local) thay whisper-tiny on-device — nhanh hơn, chính
xác hơn, máy không nóng. Kết quả ghi **cùng LRC cache** như hiện tại (offline
vẫn đọc được, karaoke timestamps không đổi).

**Bước làm:**
1. `packages/in4up_stt/lib/stt_engine_remote.dart` — implements `SttEngine`:
   `transcribeFile` qua POST `/v1/audio/transcriptions` (multipart). Thêm
   `SttEngineType.remote` vào enum (`stt_result.dart:190`) — **grep toàn bộ
   switch/so sánh trên enum, cập nhật hết cùng commit**. Đăng ký trong
   `stt_engine_registry.dart`.
2. `SttEngineCapabilities` trung thực: `supportsFileTranscription: true`,
   `supportsOffline: false`, `supportsLiveMic: false` (live mic GIỮ
   on-device — quyết định đã chốt). Facade không được chọn remote khi
   offline-only/không mạng.
3. Chunking file dài: tái dùng **VAD có sẵn** (`SherpaVadService`) cắt theo
   khoảng lặng thành chunk ~10–15 phút (giới hạn upload ~25MB của OpenAI);
   payload chuyển WAV 16k mono bằng `audio_converter.dart` có sẵn — **KHÔNG
   upload file gốc lossless**; stream file từ đĩa vào multipart (không load
   cả file vào RAM). Ghép kết quả đúng thứ tự, offset timestamp từng chunk
   (không lặp/mất đoạn — cùng kỷ luật `hymt_chunking`).
4. Progress % từng chunk qua `progressStream` của facade (đã có cơ chế
   chunkIndex/chunkCount). Single-flight: 1 job transcribe tại một thời điểm
   (mẫu `hymt_slot`), request kế tiếp → mã `busy`.
5. Kết quả ghi LRC qua luồng HIỆN CÓ của facade (`SttLrcConverter`, cache,
   transcript search) — remote chỉ là nguồn segment, mọi thứ phía sau giữ
   nguyên. **Không fake word timestamps** (nguyên tắc MeetilyAdapter).
6. UI: trong luồng "Tạo lời thoại"/auto-TOC hiện có, thêm lựa chọn engine
   (offline Whisper vs API) khi routing cho phép — tìm chỗ chọn engine hiện
   có để cắm cạnh, không dựng màn mới.

**AT WP2:**
- File ~30p: bóc băng bằng Groq whisper-large-v3 hoặc Speaches local hoàn
  thành nhanh hơn whisper-tiny on-device; LRC khớp timestamp để karaoke
  highlight đúng chỗ; transcript search hoạt động như thường.
- Mất mạng giữa chừng → job dừng sạch có mã lỗi, không treo progress; user
  chạy lại bằng whisper on-device được ngay (fallback).
- LRC đã cache từ lần remote → mở offline vẫn thấy (cùng cache, không duplicate).
- Chưa cấu hình provider/tắt API → luồng STT chạy y hệt hôm nay.
- CI xanh + KANBAN card.

## 6. WP3 — Dịch bằng LLM (API-004)

**Mục tiêu:** chất lượng dịch (nhất là Pali/chuyên ngữ Phật học) tốt hơn
Hy-MT; giảm nhu cầu giữ model 600MB trên máy.

**Bước làm:**
1. `lib/features/translation/engines/llm_mt_engine.dart` — implements
   `TranslationEngine` (đối chiếu interface: `name`, `id`, `isAvailable()`,
   `translate(...)`, `maxCharsPerRequest`, `requestDelay`).
2. Prompt nghiêm ngặt: "chỉ dịch, không giải thích, giữ nguyên chỗ trống
   `__G{n}__`" — **glossary chuyên ngữ layer chạy TRƯỚC đã thay slot; engine
   phải giữ nguyên slot trong output** (hợp đồng hiện có của TranslationService).
   `maxCharsPerRequest` ~2000 (chunking sẵn của service tự xử lý phần còn lại).
3. `isAvailable()` = có provider bật + có chatModel + có mạng. Cắm vào chuỗi
   engine theo routing (chèn vị trí theo prefs, không phá thứ tự online→offline
   hiện có khi tầng tắt). `TranslationResult.errorCode` cấu trúc (mã chung
   tầng API).
4. Không thêm màn hình mới — engine hiện trong chuỗi + thứ tự ưu tiên như UI
   dịch hiện có (nếu UI dịch chưa có kéo-thả thứ tự như TTS thì chỉ cần hiện
   engine khi available, ghi chú KANBAN đề xuất UI sau).

**AT WP3:**
- Đoạn Pali/tiếng Anh chuyên ngữ dịch tốt hơn Hy-MT (owner nghiệm thu chất
  lượng trên 3 đoạn mẫu).
- Output KHÔNG chứa giải thích/giải nghĩa thêm (test prompt + parse).
- Tắt mạng → chuỗi fallback nguyên vẹn (DeepLX→…→Hy-MT→ML Kit→Offline), không
  regression test dịch hiện có.
- CI xanh + KANBAN card.

## 7. WP4 — TTS qua API (API-005)

**Mục tiêu:** thêm engine TTS cloud/local (OpenAI tts-1, Kokoro local) vào
chuỗi engine-order có sẵn — pattern Zalo/FPT đã chứng minh, WP nhẹ nhất.

**Bước làm:**
1. `lib/features/tts/engines/openai_compat_tts_engine.dart` — implements
   `TtsEngine` (xem `zalo_tts_engine.dart` làm mẫu trực tiếp nhất).
2. POST `/v1/audio/speech` → stream audio về file temp → phát qua AudioPlayer
   như engine khác; model per provider (tts-1/kokoro/…); voices list nếu API có.
3. Cắm vào `_buildDefaultEngineOrder` trong `tts_service.dart` — **thứ tự mặc
   định KHÔNG đổi** cho user cũ (engine API nằm sau offline/Zalo/FPT mặc định;
   user kéo lên nếu muốn — UI kéo thả đã có).
4. Không lưu key riêng — dùng store chung WP0 (khác với Zalo/FPT key cục bộ cũ).

**AT WP4:**
- Chọn Kokoro (local) hoặc OpenAI tts-1 → đọc được text VI/EN; kéo thứ tự ưu
  tiên hoạt động như engine khác.
- Không cấu hình → chuỗi TTS + mặc định y hệt hôm nay.
- CI xanh + KANBAN card.

## 8. WP5 (tùy chọn, docs-only) — "In4Up Server Box" (API-006)

**Mục tiêu:** bộ docker-compose 1 lệnh cho máy tính trong chà/LAN chạy đủ
Ollama (chat/dịch) + Speaches (STT faster-whisper) + Kokoro-FastAPI (TTS);
owner cắm URL vào app là mọi năng lực bật được. **Không code app.**

**Bước làm:** `docs/server_box/README.md` (hướng dẫn tiếng Việt: yêu cầu RAM/
GPU, lệnh lên, lấy IP:port, health-check từng service, cách nhập vào app) +
`docker-compose.yml` + script health-check (curl `/v1/models` từng service).
Ghi rõ cấu hình tối thiểu (VD: 8GB RAM không GPU chạy được model nào).

**AT WP5:** 1 máy LAN sạch chạy compose lên đủ 3 service xanh; README dán URL
vào app (WP0 screen) → test kết nối xanh cả 3.

## 9. Báo cáo khi xong mỗi WP (định dạng bắt buộc)

```
WPx DONE
- Nhánh: <branch> · SHA: <sha-tip-WP> (.. <sha-base>)
- Commits: <danh sách sha + 1 dòng mỗi cái>
- CI: <run id xanh> (App Analyze + Locale)
- AT đạt: <điểm nào đạt / điểm nào chờ owner thiết bị>
- File mới/sửa: <tóm tắt>
- Điểm chờ owner: <dependency mới cần duyệt? nghiệm thu thiết bị? quyết định UI?>
```

Gửi vào chat owner → owner chuyển cho agent `arena/01a0251e-in4up` → agent đó
**thu hoạch** (cherry-pick có `-x`, đối chiếu blob từng file, fix compile nếu
cần — bài học từ WP các nhánh trước: lỗi compile chỉ lộ qua oracle, **đỏ sẵn
cũng phải báo trung thực**) → **nghiệm thu** (review + CI + thiết bị cùng
owner) → KANBAN đóng card.

## 10. Bẫy đã trả giá thật (nhắc lại) + bẫy MỚI của tầng API

1. **paths-filter (5.7):** commit chỉ chạm `packages/` không trigger
   `app_analyze` → tưởng xanh, thực ra chưa chạy. WP1/WP2 luôn kèm chạm `lib/`.
2. **API nhớ sai (5.16):** verify `dart:io`/`dio`/`http` theo docs trước khi
   push (`File.openRead()` trả `Stream`…). Đặc biệt: dio `ResponseType.stream`
   vs `receiveWhenDone`, multipart `MultipartFile.fromStream` (không
   `fromPath` file 30MB rồi out-of-memory).
3. **Sandbox tái bản (5.5):** `cp` file đang sửa ra `/tmp` trước khi fetch/reset.
4. **Bisect tự vỡ (5.8):** balance-check nháy đơn/kép trước khi push.
5. **Export-chain (5.2/5.10):** import trực tiếp + qua export cùng file →
   analyze đỏ khó hiểu; `show` tên không dùng thật cũng đỏ.
6. **MỚI — key lộ:** debugPrint log header/request → lộ key. Luật 7 mục 2.
7. **MỚI — SSE:** không xử lý `data: [DONE]` → stream không bao giờ complete;
   không cancel khi đóng màn → token chảy tiếp tốn tiền.
8. **MỚI — 429/backoff:** gọi liền 10 chunk STT không delay → bị rate limit
   cả loạt; dùng lại `requestDelay`/slot pattern đã có.
9. **MỚI — model name bịa:** KHÔNG hard-code tên model vào code — luôn load
   `/v1/models` (tên model cloud đổi liên tục; local mỗi bản tên khác).
10. **MỚI — timestamp offset chunk STT:** quên cộng offset chunk thứ N →
    LRC lệch dần, karaoke sai hoàn toàn từ giữa file (test file 2 chunk trở lên).

## 11. Tài liệu tham khảo trong repo

- `docs/server_api_tu_van.md` (nhánh `origin/arena/01a0ddd1-in4up`) — bản tư
  vấn đầy đủ: bảng nhà cung cấp, kiến trúc router, rủi ro/đối sách.
- `AGENTS.md` + `docs/GOVERNANCE.md` — quy tắc vàng, KANBAN/PLAN.
- `docs/project/MODELS.md` — model offline đang dùng + thư mục đặt model.
- `docs/skills/ci-red-debugging/SKILL.md` — debug CI đỏ không có log/SDK.
- Engine làm mẫu (đọc trước khi viết engine mới):
  `lib/features/tts/engines/zalo_tts_engine.dart` (apiKey + HTTP),
  `lib/features/translation/engines/deeplx_engine.dart` (serverUrl user nhập),
  `lib/features/translation/engines/hymt_engine.dart` (slot + chunk + mã lỗi),
  `packages/in4up_stt/lib/stt_engine_sherpa.dart` (capabilities + registry).
- `PROMPT_AGENT_MEETILY_SHERPA.md` — quy trình thu hoạch/nghiệm thu chi tiết.
