# KANBAN — VipSound / INUP v11.0

> **Single Source of Truth cho trạng thái thực thi.**
> Cập nhật dựa trên mã nguồn thực tế tại `packages/`, `lib/`, `native/` và lịch sử commit.
> App version: `1.4.1+3` (`pubspec.yaml`) · Architecture version: **v11.0** (theo comment trong code).
>
> Quy ước trạng thái: `[x]` = Seal/DONE · `[~]` = DOING · `[ ]` = BACKLOG.

---

## ✅ DONE — Đã "Seal" (không đảo lộn)

### Kiến trúc lõi
- [x] **Stateless Whisper Engine** — `SttEngineWhisper` không giữ instance state; thực thi qua hàm tĩnh `runInIsolate()` → `compute(_isolateEntryPoint)`.
  - `packages/vipsound_stt/lib/stt_engine_whisper.dart`
- [x] **Content-Anchored UID System (Hash-based)** — `ContentId`: `audioFingerprint`, `segmentUid`, `textNorm`, JoinKey (MD5, content-anchored → bất biến khi layout đổi).
  - `packages/vipsound_stt/lib/models/content_id.dart`
- [x] **Database as Source of Truth (local-first Hive)** — storage/vocab/memory/annotation đều qua Hive.
  - `lib/services/storage_service.dart`, `lib/providers/vocabulary_provider.dart`, `lib/bridges/memory_bridge.dart`, `lib/features/pdf_reader/services/pdf_annotation_storage.dart`, `lib/services/vocab_sync_service.dart`
- [x] **Native Rendering / DSP First** — engine C++ `UltraTimeStretch` (V1+V2, SIMD NEON/AVX, pffft) qua Dart FFI; READ mode render native (webview_flutter + pdfrx) + inject highlight CEFR.
  - `native/src/V1/Engine.cpp`, `native/include/UltraTimeStretch.h`, `lib/features/web_reader/`, `lib/features/pdf_reader/`

### STT pipeline (Isolate-safe)
- [x] **FFmpeg Mobile fix** — `AudioConverter` dùng `FFmpegKit` trên Android/iOS (thay `Process`), bọc path trong `"..."`, `sanitizeFileName()` xóa khoảng trắng.
  - `packages/vipsound_stt/lib/utils/audio_converter.dart`
- [x] **FFI Symbol `_with_params` fix** — `whisper_init_from_file_with_params()` + `whisper_context_default_params()` (struct by-value); `DynamicLibrary.process()` cho Android/iOS.
  - `packages/vipsound_stt/lib/stt_engine_whisper.dart`
- [x] **WAV PCM→Float32 loader (thuần Dart)** — `loadWavAsPcm()` + `_loadAudioAsPcm()` thay dummy; chunk-based RIFF parser, Isolate-safe (không Platform Channel).
  - `packages/vipsound_stt/lib/stt_engine_whisper.dart`
- [x] **Cleanup legacy FFI** — xóa `lib/native/whisper_bindings.dart` + `lib/services/whisper_service.dart`; `main.dart` chỉ còn 1 nguồn STT (`SttServiceFacade` → `SttEngineWhisper`).
- [x] **Diarization Sprint 1 (Heuristic)** — `HeuristicDiarizationService` (silence gap + question pattern) đang active.
  - `packages/vipsound_stt/lib/diarization/diarization_service.dart`

### Learning features (4 tabs)
- [x] **Chế độ Đọc (📖)** — reader CEFR (A1–C2) + POS highlight, multi-engine translate (Google/DeepLX/Libre/Zalo AI), Web/PDF native render.
- [x] **Chế độ Nghe (🎧)** — waveform cuộn + fixed playhead, A-B loop, gap duration; speed 0.05x–10x qua UltraTimeStretch.
- [x] **Chế độ Hiểu (💡)** — đồng bộ audio–text (LRC/SRT), Shadowing mode + ghi âm.
- [x] **Vườn Trí Nhớ (🧠)** — vocab SRS SM-2; growth stages Seed→Sprout→Tree→Branch→Bud→Bloom.
  - `packages/vipsound_core/lib/sm2_algorithm.dart`, `packages/vipsound_core/lib/vocab_level_difficulty.dart`
- [x] **Tools overlay** — YouTube, YouGlish, Word List, Timeline, Stats, Word Map, Triangle, Venn.

---

## 🔧 DOING — Đang dang dở

- [~] **Word-level timestamp parsing** — FFI đã bind `whisper_full_get_token_data` / `whisper_full_get_token_text` và `token_timestamps`, nhưng `_parseWhisperSegments()` đang xuất `words: []` (helper `_parseWordTokens` chưa được gọi). Cần tích hợp parse token → `SttWord`.
  - `packages/vipsound_stt/lib/stt_engine_whisper.dart`
- [~] **On-device integration test** của pipeline STT mới (FFI symbol + WAV loader) — không chạy được trong CI/HEAD-less, cần test thật trên Android/iOS/Windows.
- [~] **Dọn placeholder còn sót** trong engine: `_quickFingerprint`, `_writeLrcFile`, `_validatePaths` (unused, gây `unused_element`).

> Lưu ý: **i18n chưa bắt đầu** (chỉ có dep `flutter_localizations` + `intl: 0.20.2`, không có `.arb`/`l10n.yaml`/`AppLocalizations`). Các string UI đang hard-code tiếng Việt. → chuyển xuống BACKLOG (v11.1).

---

## 📋 BACKLOG — Tương lai

- [ ] **v11.1 — Quốc tế hóa (i18n)**: trích xuất chuỗi → `.arb`, setup `l10n.yaml` + `generate: true`. Ngôn ngữ: English, 中文, Sinhala/Tamil (Sri Lanka), Hindi/Indian languages.
- [ ] **v11.2 — "Địa hình tri thức" (Memory Garden)**: thêm trạng thái `UNBORN` + easing `smoothstep()` cho transition giữa các growth stage.
- [ ] **Diarization Sprint 2 (Rust)** — `MeetilyRustDiarizationService` thay heuristic (đã có interface `abstract class DiarizationService`).
- [ ] **v12.0 — Local AI Chat (Gemma/Llama)** — nền tảng đã có: `vipsound_ai` (`AiEngine`, `AiEngineGemma` isolate + system prompt, `AiEngineMock`, `AiModelLoader`).
- [ ] **Tối ưu UI tab Nghe** — waveform/render performance ở tốc độ cực chậm.
- [ ] **Micro-opt STT** — bỏ bản copy thừa `Float32List.fromList(pcmSamples)` vì `_loadAudioAsPcm` đã trả `Float32List`.