# Tư vấn: Tầng Server API cho AI (cloud + local server)

> Trạng thái: **BẢN TƯ VẤN — chưa phải quyết định.** Chờ owner chốt các câu hỏi
> ở mục 8, sau đó quy trình đúng theo GOVERNANCE là viết ADR trong `docs/adr/`
> rồi mới code.
> Ngày: 2026-09-26 · Nhánh làm việc: `arena/01a0ddd1-in4up`

## 0. Tóm tắt cho người bận

**Không cần viết lại app.** In4Up đã có sẵn 4 "mối nối" (Strategy Pattern) ở
tầng engine — chuyện cần làm chỉ là **cắm thêm engine chạy qua API** vào đúng
mối nối đó, theo đúng cách app đã từng làm với Zalo TTS / FPT TTS / DeepLX.

Khuyến nghị cốt lõi — **3 nguyên tắc**:

1. **Chuẩn giao thức duy nhất: OpenAI-compatible REST**
   (`/v1/chat/completions`, `/v1/audio/transcriptions`, `/v1/audio/speech`,
   `/v1/models`). Viết **1 client** là chạy được với gần như mọi thứ: OpenAI,
   Groq, OpenRouter, DeepSeek, Google Gemini (có lớp compat), và local server:
   Ollama, LM Studio, `llama-server` (llama.cpp), Speaches, LocalAI, Kokoro.
   User chỉ đổi `baseUrl` + `apiKey` + tên model.
2. **Offline-first giữ nguyên** — API là *tầng tăng tốc tuỳ chọn*, không phải
   phụ thuộc. Mỗi năng lực có chế độ định tuyến: `offline-first` / `online-first`
   / `offline-only`, có tự fallback khi mất mạng/lỗi 429.
3. **BYOK** (Bring Your Own Key): app không kèm key nào; user tự nhập key cloud
   hoặc trỏ vào server nhà (LAN, không cần key). Mặc định: tầng API **tắt** cho
   tới khi user cấu hình.

Hai mối nối còn **thiếu** engine remote: **LLM** (`in4up_ai` đang chỉ có
Gemma on-device + mock) và **STT file** (đang chỉ whisper.cpp/sherpa on-device).
Đây chính là 2 nơi hứa hẹn lợi ích lớn nhất (xem mục 4).

---

## 1. Hiện trạng đã đối chiếu trên tree (2026-09-26)

### 1.1 Các "mối nối" engine đã có — chỗ cắm engine API

| Năng lực | Interface / Registry | Engine on-device | Engine online/local-server ĐÃ CÓ | Engine API còn thiếu |
|---|---|---|---|---|
| **Dịch** | `lib/features/translation/engines/translation_engine.dart` + `TranslationService` (chuỗi online → fallback offline: Hy-MT → ML Kit → Offline) | Hy-MT 1.5 (GGUF ~600MB, llama.cpp trong isolate), ML Kit | **DeepLX (user nhập URL server tự host!)**, Google free, Libre, MyMemory | LLM-dịch qua chat API (tuỳ chọn) |
| **TTS** | `lib/features/tts/engines/tts_engine.dart` + `TtsService` (engine order lưu prefs, kéo-thả ưu tiên) | Piper (sherpa-onnx, ~75MB/giọng), flutter_tts | **Zalo (API key)**, **FPT (API key)**, Google | OpenAI-compat `/v1/audio/speech` (phục vụ LM Studio/Kokoro/OpenAI) |
| **STT** | `packages/in4up_stt/lib/stt_engine.dart` + `stt_engine_registry.dart` + `SttServiceFacade` | Whisper (whisper.cpp, tiny-q4_0 37MB…), Sherpa Zipformer (live), `speech_to_text` (native) | — ❌ chưa có | **`RemoteSttEngine`** (`/v1/audio/transcriptions`) — thiếu lớn nhất |
| **LLM phân tích/chat** | `packages/in4up_ai/lib/src/engine/ai_engine.dart` + `AiServiceFacade` | Gemma (GGUF llama.cpp, load 1–2 phút, isolate hay bị OOM thu hồi — có sẵn code `recover()`) | — ❌ chưa có | **`RemoteChatEngine`** (`/v1/chat/completions` + streaming) — thiếu lớn thứ hai |

Điểm quan trọng: **mẫu "user tự nhập URL server tự host" đã có tiền lệ trong
app** (`DeepLXEngine(serverUrl: ...)`), và mẫu "user nhập API key" cũng vậy
(`ZaloTtsEngine(apiKey: ...)`, key đang lưu `SharedPreferences`). Tầng mới chỉ
là tổng quát hoá 2 mẫu này thành 1 khối cấu hình dùng chung.

### 1.2 Trọng lượng AI on-device hiện tại (vì sao app "đè" máy)

| Model | Dung lượng file | RAM khi chạy | Vấn đề quan sát được trong code |
|---|---|---|---|
| Whisper tiny-q4_0 / base | 37–75MB | ~200–400MB context | Bóc băng file 30p chậm, chạy isolate |
| Hy-MT 1.5 (dịch) | ~600MB | nặng | Có code chống `isolateDead` (OOM/kill), single-flight slot, chunk timeout — dấu hiệu đã "đau" |
| Gemma (chat/analysis) | GGUF lớn | nặng | `recover()` vì FFI blocking + isolate bị thu hồi; load model 1–2 phút |
| Piper + espeak | ~75MB/giọng | vừa | OK, giữ lại |
| Zipformer live ASR | 20–32MB | nhẹ | OK — realtime, **nên giữ on-device** |

Kết luận: "kém mượt" đến từ **RAM/ nhiệt / thời gian load model / OOM** của
Whisper + Hy-MT + Gemma — không phải do UI thread bị chặn (whisper đã chạy
isolate). Tầng API giải đúng các điểm đó.

---

## 2. Chuẩn giao dịch: vì sao chọn OpenAI-compatible

Một cấu hình duy nhất `baseUrl + apiKey + model` chạy được ở cả cloud lẫn local:

| Nhà cung cấp | baseUrl | Chat | STT `/v1/audio/transcriptions` | TTS `/v1/audio/speech` | `/v1/models` (líst model tự động) |
|---|---|---|---|---|---|
| OpenAI | `https://api.openai.com/v1` | ✅ | ✅ (whisper-1, gpt-4o-transcribe) | ✅ | ✅ |
| Groq (nhanh, giá thấp) | `https://api.groq.com/openai/v1` | ✅ | ✅ **whisper-large-v3** | — | ✅ |
| OpenRouter (1 key, nhiều hãng) | `https://openrouter.ai/api/v1` | ✅ | tuỳ model | — | ✅ |
| Google Gemini (lớp compat) | `https://generativelanguage.googleapis.com/v1beta/openai/` | ✅ (free tier hào phóng, tiếng Việt tốt) | tuỳ | tuỳ | ✅ |
| Ollama (local) | `http://<ip-máy>:11434/v1` | ✅ | — (STT dùng server khác, xem dưới) | — | ✅ |
| LM Studio (local, GUI) | `http://<ip-máy>:1234/v1` | ✅ | tuỳ phiên bản | tuỳ | ✅ |
| llama.cpp `llama-server` (local) | `http://<ip-máy>:8080/v1` | ✅ | — | — | ✅ |
| Speaches / whisper.cpp server (local STT) | `http://<ip-máy>:8000/v1` | — | ✅ faster-whisper / whisper.cpp | — | ✅ |
| Kokoro-FastAPI / LocalAI (local TTS) | `http://<ip-máy>:8880/v1` | — | — | ✅ | ✅ |

*(Giá/model đổi liên tục — kiểm tra lại bảng giá tại thời điểm tích hợp; đây
là lý do UI nên load danh sách model động qua `/v1/models` thay vì hard-code.)*

Chiến lược "1 client": viết **`OpenAiCompatClient`** duy nhất (dùng `dio` —
đã có sẵn trong deps) + thin adapter cho các lẻ không theo chuẩn (Gemini
native API, Zalo AI native) chỉ khi thật sự cần. Thêm nhà cung cấp mới =
thêm 1 dòng preset, không thêm class mới.

---

## 3. Kiến trúc đề xuất

### 3.1 Sơ đồ

```
UI (screens — gần như KHÔNG đổi)
   │
   ▼
Facades HIỆN CÓ (giữ nguyên API)
   AiServiceFacade · SttServiceFacade · TranslationService · TtsService
   │
   ▼
★ MỚI: AiProviderRouter  ── đọc AiProviderStore (cấu hình) + connectivity_plus
   │   chính sách định tuyến từng năng lực:
   │   offlineFirst | onlineFirst | offlineOnly  (+ tự fallback 2 chiều)
   │
   ├─────────────────────────► Engine on-device (HIỆN CÓ, giữ nguyên)
   │                            Gemma · Whisper · Sherpa · Piper · Hy-MT · ML Kit
   │
   └─────────────────────────► ★ Engine remote (MỚI — implement interface có sẵn)
        RemoteChatEngine  : AiEngine          (chat/analyze, streaming SSE)
        RemoteSttEngine   : SttEngine          (bóc băng file)
        LlmMtEngine       : TranslationEngine  (dịch bằng LLM)
        OpenAiCompatTts   : TtsEngine          (TTS cloud/local)
                │
                ▼
        ★ OpenAiCompatClient (1 client duy nhất — baseUrl + apiKey + model)
                │
                ├── Cloud:  OpenAI · Groq · Gemini · OpenRouter · Zalo…
                └── Local:  Ollama · LM Studio · llama-server · Speaches · Kokoro
```

### 3.2 Các class mới (đề xuất đặt trong package `in4up_ai` để không tạo vòng phụ thuộc)

```dart
/// Cấu hình 1 nhà cung cấp (cloud hoặc server nhà)
class AiProviderConfig {
  final String id;
  final String label;            // "Ollama nhà", "Groq", "Gemini free"…
  final String baseUrl;          // http://192.168.1.10:11434/v1
  final String? apiKey;          // local server → bỏ trống
  // model theo năng lực (lấy động từ /v1/models, user chọn trong dropdown)
  final String? chatModel;       // "llama3.1:8b" / "gemini-2.0-flash"
  final String? sttModel;        // "whisper-large-v3"
  final String? ttsModel;        // "kokoro" / "tts-1"
  final bool enabled;
}

/// Chính sách định tuyến cho TỪNG năng lực — mặc định offlineFirst
enum AiRouteMode { offlineFirst, onlineFirst, offlineOnly }

class AiRoutingPrefs {
  AiRouteMode chat;          // AI Chat / Write Studio / Word Lookup
  AiRouteMode sttFile;       // bóc băng audio → LRC / auto-TOC
  AiRouteMode translation;
  AiRouteMode tts;
  String? providerIdFor(AiRouteCapability c); // ưu tiên provider nào
}
```

### 3.3 Kỷ luật vận hành (tái dùng code/pattern đã có trong repo — đừng phát minh lại)

| Vấn đề | Pattern đã có trong repo để tái dùng |
|---|---|
| 1 request/1 slot, chống treo, queue có hạn | `hymt_slot.dart` (single-flight + busy code có cấu trúc) |
| Timeout hữu hạn từng chunk, retry 1 lần | `hymt_engine.dart` HYMT-002 |
| Cache kết quả | `translation_cache.dart`, LRC cache trong `SttServiceFacade` — kết quả remote ghi vào **cùng cache** để offline vẫn đọc được |
| Mã lỗi cấu trúc (không match chuỗi) | `HyMtErrorCode` / `TranslationResult.errorCode` |
| Kiểm tra mạng | `connectivity_plus` (đã có trong pubspec) |
| Đơn vị async không chặn UI | isolate hiện chỉ cần cho FFI; HTTP client thuần là async — không cần isolate mới |

Thêm 2 thứ mới: **exponential backoff khi 429/5xx** và **SSE streaming**
(`chat` trả token dần — cảm giác "mượt" tăng rõ rệt nhất so với Gemma on-device).

### 3.4 Bảo mật & quyền

- **API key**: dùng `flutter_secure_storage` (Android Keystore / iOS Keychain /
  Windows DPAPI) cho tầng mới. (Zalo/FPT key cũ đang nằm `SharedPreferences` —
  nên migrate cùng lúc, không bắt buộc.)
- **HTTP nội bộ**: `AndroidManifest` đã có `usesCleartextTraffic="true"` nên
  gọi `http://192.168.x.x:11434` không bị chặn — giữ nguyên, nhưng **không
  cho phép key cloud đi qua http cleartext**, chỉ cho cleartext khi baseUrl là
  IP riêng/LAN (thêm check trong client).
- **Privacy**: gửi audio pháp thoại/giọng đọc lên cloud phải là **opt-in rõ
  ràng** — dialog lần đầu: "Bản ghi âm sẽ được gửi tới <tên provider>". Ai cần
  riêng tư tuyệt đối → dùng local server (đây chính là lý do tồn tại option
  server nhà).
- **Không hard-code key nào trong code**, kể cả key test.

---

## 4. Cái gì được giải phóng — và cái gì KHÔNG nên đưa lên server

### 4.1 Được giải phóng khi bật tầng API

| Điểm nghẽn hiện tại | Khi dùng API |
|---|---|
| RAM ~0.6–1.5GB cho Hy-MT + Gemma + Whisper → OOM kill isolate | 0MB — app nhẹ như app nghe nhạc thường |
| Load model 1–2 phút (Gemma), tải model 37–600MB về máy | Không load, không tốn dung lượng; xóa được model nặng khi hết cần |
| Máy nóng, pin tụt khi bóc băng file dài | Nhiệt/pin gần như không đổi |
| Chất lượng: whisper-tiny-q4_0 sai nhiều tiếng không phổ thông (Pali, giọng đọc kinh) | whisper-large-v3 / gpt-4o-transcribe tốt hơn hẳn |
| Chat on-device sinh token chậm | Streaming SSE + model lớn → nhanh, viết tiếng Việt tốt hơn |
| Máy yếu (điện thoại cũ) gần như không chạy nổi LLM | Chạy tốt — việc nặng ở server |

### 4.2 Nên GIỮ on-device (không đưa lên API)

| Năng lực | Lý do |
|---|---|
| **Live STT cabin / shadowing** (Zipformer streaming) | Realtime + mic luôn bật; độ trễ WAN + chi phí + riêng tư → giữ nguyên. (Nếu sau này muốn: WebSocket streaming, phase sau.) |
| **VAD Silero** (auto-TOC, tách khoảng lặng) | Chạy trước khi quyết định gửi chunk nào lên server — VAD nhẹ, giữ trên máy để cắt bớt dữ liệu gửi lên (tiết kiệm phí + riêng tư). |
| **ML Kit / offline engine** | Là lớp fallback cuối — bắt buộc còn để app hoạt động khi không có mạng. |
| **Piper TTS** (nếu user đã tải giọng) | Vẫn là lựa chọn offline; API TTS chỉ là engine tuỳ chọn thêm vào chuỗi. |

> Net-effect: kiến trúc **hybrid có chủ đích** — realtime & fallback ở máy,
  việc nặng hụt (file dài, LLM) đẩy lên cloud/server. Đây là mô hình chuẩn của
  các app học ngôn ngữ lớn (ELSA, LingQ…).

---

## 5. Rủi ro & đối sách

| Rủi ro | Mức độ | Đối sách |
|---|---|---|
| Chi phí API (user bỏ tiền, hoặc app bị lạm dụng nếu sau này có key chung) | Cao | BYOK; đếm token/giây-audio hiển thị trong Settings; cảnh báo trước khi gửi file dài; ưu tiên free tier (Gemini) |
| Riêng tư: audio/text pháp thoại gửi ra ngoài | Cao | Opt-in từng năng lực; hiển thị rõ đích; local server = lối thoát riêng tư |
| Mất mạng giữa chừng | Vừa | Fallback tự động về offline engine (đã có pattern trong `TranslationService`) |
| Giới hạn upload (OpenAI 25MB/file) | Vừa | Chia audio theo segment VAD (đã có VAD!) ~10–15 phút/chunk, ghép kết quả — tái dụng `hymt_chunking`-style |
| 429 rate limit | Vừa | Backoff + single-flight slot (pattern HyMt) |
| Key bị lộ (root device, backup) | Vừa | secure storage; không log key; XOÁ key khi user gỡ provider |
| Server nhà đổi IP/tắt máy | Thường xuyên | Nút "Kiểm tra kết nối" (`GET /v1/models`) trong UI cấu hình + timeout ngắn 5s + hiện trạng thái online/offline từng provider |
| Trôi chất lượng bản dịch LLM (thêm/bớt chữ) | Thấp | Prompt nghiêm ngặt "chỉ dịch, không giải thích" + so sánh engine như UI dịch hiện có |
| Quy trình repo | Bắt buộc | ADR mới trong `docs/adr/` (quy tắc vàng #4); chuỗi UI mới phải có ARB đủ `hi/zh/zh_TW/si` (quy tắc i18n); cập nhật `KANBAN.md` |

---

## 6. Lộ trình đề xuất (mỗi phase = 1 PR nghiệm thu được, không phá app)

| Phase | Nội dung | Size | Nghiệm thu |
|---|---|---|---|
| **P0 — Nền** | ADR + `AiProviderConfig`/`AiProviderStore` + secure storage + **màn "Server & API"** (thêm/sửa/xoá provider, nhập baseUrl/key, nút test `/v1/models`, chọn model từng năng lực, routing prefs). Không đụng engine nào. | M | Thêm 1 provider Ollama LAN + 1 Groq, test kết nối xanh/đỏ; tắt tính năng → app chạy y hệt hôm nay |
| **P1 — LLM** | `RemoteChatEngine implements AiEngine` (chat/analyze + streaming SSE); `AiServiceFacade` chọn engine theo routing. Vào: AI Chat, Write Studio, Word Lookup, Quick Save. | M | Chat streaming mượt; tắt mạng giữa chừng → tự về Gemma/mock với thông báo rõ |
| **P2 — STT file** | `RemoteSttEngine implements SttEngine` (`/v1/audio/transcriptions`), upload theo chunk VAD + progress %, kết quả ghi **cùng LRC cache** như hiện tại. Vào: Tạo lời thoại, auto-TOC, Tìm kiếm trong audio. | M | File 30p bóc băng bằng whisper-large-v3 (Groq/local) nhanh hơn tiny on-device, LRC khớp timestamp để karaoke; offline vẫn chạy whisper cũ |
| **P3 — Dịch LLM** | `LlmMtEngine implements TranslationEngine` (chat + prompt dịch) — bổ sung vào chuỗi engine, user kéo thứ tự ưu tiên như UI TTS hiện có. Giải phóng dần nhu cầu Hy-MT 600MB. | S | Dịch đoạn khó (Pali↔Việt) tốt hơn Hy-MT; chuỗi fallback còn hoạt động khi mất mạng |
| **P4 — TTS API** | `OpenAiCompatTtsEngine implements TtsEngine` — cắm vào engine-order có sẵn (Zalo/FPT đã chứng minh pattern). | S | Đọc offline vẫn mặc định; chọn Kokoro/OpenAI thì phát được |
| **P5 (tùy chọn) — "In4Up Server Box"** | Docs + docker-compose 1 lệnh cho chà/nhà: Ollama (chat) + Speaches (STT) + Kokoro (TTS) trên 1 máy LAN; QR/nhập URL nhanh từ app. | M | Máy tính trong LAN bật compose → app phát hiện, mọi năng lực bật được |

Thứ tự P1 trước P2 vì: LLM ít rủi ro nhất (text-only, không upload), giá trị
cảm nhận ngay (chat streaming), và prove toàn bộ nền P0 hoạt động.

---

## 7. Gợi ý chọn nhà cung cấp cho từng năng lực (người dùng cuối)

| Năng lực | Cloud khuyến nghị | Local khuyến nghị |
|---|---|---|
| Chat/phân tích (tiếng Việt tốt, rẻ) | **Gemini Flash** (free tier) → GPT-4o-mini/OpenRouter → Claude Haiku; Zalo AI (đã có quan hệ trong app) | Ollama (llama3.1-8b / qwen2.5:7b — tiếng Việt tốt) |
| Bóc băng STT | **Groq whisper-large-v3** (nhanh + giá thấp) → OpenAI gpt-4o-transcribe | Speaches (faster-whisper) hoặc whisper.cpp server — cùng model large-v3, mạnh hơn tiny on-device |
| Dịch | LLM ở trên | Ollama qwen (Pali/Sanskrit phụ thuộc model — nên giữ glossary chuyên ngành hiện có làm lớp tiền xử lý) |
| TTS | Zalo/FPT (đã có, tiếng Việt tốt) hoặc OpenAI tts-1 | Kokoro-FastAPI / Piper server; Piper on-device vẫn là mặc định offline |

---

## 8. Câu hỏi cần owner chốt trước khi viết ADR + code

1. **Ưu tiên đầu tiên** cho user là gì — Chat/LLM mượt, bóc băng file dài nhanh,
   hay giải phóng dung lượng (bỏ Hy-MT 600MB)? → quyết định P1/P2/P3 đảo thứ tự.
2. **Đối tượng**: tầng API chỉ dùng nội bộ (mình + vài sư trong chà) hay tính
   vào bản phát hành cho mọi user (khi đó opt-in + đếm chi phí phải kỹ hơn)?
3. **Local server**: đã có sẵn máy nào chạy Ollama/LM Studio trong LAN chưa,
   hay cần xuất luôn bộ docker-compose (P5) từ đầu?
4. **Cloud mặc định đề xuất** ai: Gemini (free tier) làm preset đầu tiên có
   ổn với direction riêng tư của app không, hay chỉ nhận local-server?

---

*Phụ lục A — các file sẽ bị chạm khi code (tham khảo, chưa cam kết):*
`packages/in4up_ai/lib/src/` (client + remote engine + provider store),
`packages/in4up_stt/lib/stt_engine_registry.dart` (đăng ký `RemoteSttEngine`),
`lib/screens/settings/` (màn Server & API mới), `lib/l10n/*.arb` (chuỗi mới,
đủ 4 locale T2), `docs/adr/0007-server-api-layer.md`, `docs/project/KANBAN.md`.

---

## Phụ lục B (2026-09-27) — Server đặt Ở ĐÂU? 3 mô hình & câu hỏi "Android có kill không?"

> Trả lời câu hỏi owner 2026-09-27: "API từ mây hay từ PC → Android, hay app
> server chạy model → app in4up trên chính Android đó? Nếu app→app thì có
> sợ Android kill không?"

### B.1 Nguyên tắc: in4up luôn là CLIENT — server nằm ở 1 trong 3 chỗ

Tầng API sau khi làm chỉ thêm cho in4up một **cổng cắm HTTP** (chuẩn
OpenAI-compatible). Cắm vào đâu là lựa chọn của user — code app giống hệt
nhau, chỉ khác `baseUrl`:

```
A) CLOUD — máy chủ của hãng (qua Internet)
   ┌──────────────┐  HTTPS    ┌──────────────────────────────┐
   │ Android      │ ────────▶ │ api.groq.com / Gemini /      │
   │ (in4up)      │ ◀──────── │ OpenAI…  (GPU của họ)        │
   └──────────────┘           └──────────────────────────────┘
   Cần Internet + API key. Trả phí theo mức dùng. Audio/text rời khỏi máy.

B) PC trong LAN — "Server Box" (khuyên dùng cho chà/nhà)
   ┌──────────────┐  WiFi LAN ┌──────────────────────────────┐
   │ Android      │ ────────▶ │ PC / mini-PC (docker-compose)│
   │ (in4up)      │ ◀──────── │ Ollama(chat) + Speaches(STT) │
   └──────────────┘ http://   │ + Kokoro(TTS)                │
                    192.168.x.x:11434/v1
   KHÔNG cần Internet. Miễn phí. Audio không rời khỏi LAN. PC phải bật.

C) Server app TRÊN CHÍNH CHIẾC ANDROID ĐÓ (Termux/Ollama → 127.0.0.1)
   ┌────────────────────────────────────┐
   │ Một chiếc Android                  │
   │   in4up ──http://127.0.0.1:port──▶ │ app khác chạy model
   │   (RAM vẫn CHUNG một máy!)         │
   └────────────────────────────────────┘
   ❌ KHÔNG khuyến nghị — xem B.2.
```

### B.2 Vì sao KHÔNG chạy server trên chính Android (option C)

1. **Vô nghĩa về mục tiêu.** Mục tiêu của tầng API là đẩy việc nặng
   (RAM/CPU/nhiệt) **KHỎI thiết bị**. Server chạy trên cùng một chiếc điện
   thoại thì RAM vẫn ăn chung của hệ thống — in4up nhẹ đi bao nhiêu thì app
   server nặng lên bấy nhiêu: máy vẫn chật, vẫn nóng, pin vẫn tụt. Hôm nay
   in4up đã chạy model trong isolate tách riêng — đó đã là thiết kế đúng cho
   chế độ on-device; chuyển model sang process khác cùng máy không cải thiện gì.
2. **Android sẽ kill — nỗi lo của owner là chính đáng.** 4 cơ chế:
   - **Doze / App Standby:** máy idle (tắt màn hình, không sạc) → cắt mạng,
     freeze app nền.
   - **OOM killer:** hết RAM → giết app nền trước tiên — mà app server giữ
     model 600MB+ là ứng viên số 1.
   - **Android 8+ hạn chế background service:** muốn chạy nền dai phải bám
     foreground service + thông báo thường trực.
   - **OEM aggressive hơn nữa** (Xiaomi/Oppo/Vivo/Samsung "put apps to
     sleep") — kill cả khi đã whitelist.
   Termux+Ollama phải `termux-wake-lock` + tắt tối ưu pin + khoá app chạy nền
   — và vẫn không chắc chắn 100% trên mọi máy. Quan trọng: **in4up là client
   không thể giữ app khác sống** — việc xin quyền/tắt tối ưu pin phải do app
   server tự làm, ngoài tầm kiểm soát của mình.
3. **Kết luận:** option C không hỗ trợ chính thức (client không chặn
   `127.0.0.1` — user muốn thử vẫn được — nhưng không có trong preset, không
   có trong docs hướng dẫn, không nhận bug). Muốn server "trong nhà, không
   mây" → option B với PC/mini-PC cũ (Raspberry Pi cũng chạy được model nhỏ).

### B.3 Vì sao option A/B KHÔNG sợ Android kill

- in4up chỉ là **HTTP client**: gửi request → nhận kết quả → xong. Mỗi
  request kéo dài vài giây (chat) tới vài phút (1 chunk audio). **Không có
  process server nào trên Android cần giữ sống.**
- Job dài (bóc băng file 30–60p) đã tách thành chunk 10–15p, mỗi chunk một
  request riêng + progress + cache (WP2): app bị kill giữa chừng cũng chỉ mất
  đúng chunk đang chạy — **khả quan hơn** whisper on-device hôm nay (chạy
  trong isolate của app, app chết là mất cả job).
- Nguồn điện của server: cloud = dãy máy chủ hãng; option B = điện lưới PC.
  Android không liên quan.

### B.4 Bảng so sánh 3 mô hình

| | A. Cloud | B. PC trong LAN | C. Server trên cùng Android |
|---|---|---|---|
| Cần Internet? | ✅ | ❌ chỉ cần WiFi LAN | ❌ |
| Chi phí | theo mức dùng (free tier Gemini) | 0 (tiền điện PC) | 0 |
| Audio rời khỏi nhà? | ✅ (tới hãng) | ❌ | ❌ |
| Chất lượng model | lớn nhất (GPU hãng) | theo PC (CPU chạy được 7–8B) | yếu nhất (RAM điện thoại) |
| Yêu cầu khác | API key (BYOK) | PC bật khi dùng | hack wake-lock, tắt tối ưu pin |
| Giải phóng RAM/pin Android | ✅ hoàn toàn | ✅ hoàn toàn | ❌ RAM vẫn chung máy |
| Rủi ro Android kill server | không tồn tại server trên máy | không tồn tại server trên máy | **CAO** (Doze/OOM/OEM) |
| **Khuyến nghị** | ✅ | ✅ (chùa/nhà có PC cũ) | ❌ bỏ |

### B.5 Sau khi làm xong — user nhìn thấy gì (theo tình huống)

| Tình huống | Hôm nay | Sau khi có tầng API |
|---|---|---|
| Bóc băng pháp thoại 45p, ở chà có PC Server Box | whisper-tiny trên máy: chậm gần bằng thời lượng file, máy nóng, sai nhiều tên riêng/Pali | whisper-large-v3 trên PC: chỉ vài phút, điện thoại mát, chính xác hơn hẳn |
| AI Chat / hỏi nghĩa từ (đi đường, có 4G + key Gemini free) | lần đầu chờ load Gemma 1–2 phút, generate chậm, isolate hay OOM | hỏi ngay, streaming từng chữ, model lớn hơn nhiều |
| Dịch Pali↔Việt tài liệu dài | Hy-MT 600MB trên máy | LLM cloud/PC; **tuỳ chọn xoá 600MB** giải phóng bộ nhớ |
| Không có mạng (đi tàu, lên rừng) | offline như hiện tại | **GIỮ NGUYÊN như hiện tại** (offline-first, cache dùng chung) |
| Điện thoại cũ 2–3GB RAM | gần như không chạy nổi LLM | chạy tốt — việc nặng ở server |
| Chưa cấu hình gì / tắt tầng API | — | app hành xử **y hệt hôm nay** |

Giá trị giải phóng khi dùng remote: RAM AI ~0,6–1,5GB → ~0; nhiệt/pin gần
như không đổi; không còn bắt buộc tải/lưu model 37–600MB trên máy (tuỳ chọn
xoá); chat streaming thay vì chờ load model.

