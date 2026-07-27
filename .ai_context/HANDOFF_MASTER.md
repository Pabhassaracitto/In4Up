còn tồn tại ở dạng uncommitted trong working tree.
⚠️ Quan trọng: working tree đang CHỒNG LÊN c7aa828

Vì sandbox revert về 0483df7, working tree của tôi re-chứa cả phần đã có ở c7aa828. Nếu session mới "commit hết rồi push" → sẽ trùng lặp. Cần tách rõ:

Đã có trên GitHub (c7aa828) — KHÔNG push lại:

    packages/vipsound_stt/lib/utils/audio_converter.dart (FFmpegKit + sanitize)
    packages/vipsound_stt/lib/stt_service_facade.dart (bỏ _whisperEngine, try/catch)
    packages/vipsound_stt/test/utils/audio_converter_test.dart

Net-new (mới kể từ c7aa828) — cần đưa lên:

    packages/vipsound_stt/lib/stt_engine_whisper.dart → whisper_init_from_file_with_params + WhisperContextParams + DynamicLibrary.process() + loadWavAsPcm
    lib/main.dart → bỏ import/call WhisperService
    lib/native/whisper_bindings.dart → xóa
    lib/services/whisper_service.dart → xóa
    packages/vipsound_stt/test/stt_engine_whisper_test.dart → test WAV decoder
    .ai_context/KANBAN.md · HANDOFF_MASTER.md · MILESTONES.md

Kế hoạch đúng cho session mới

Session này đã đóng remote → mở coding session mới cho repo vipsound. Khi đó tôi sẽ:

    git fetch + checkout branch có c7aa828 (base đã cập nhật).
    Áp dụng chỉ phần net-new ở bảng trên (không đụng audio_converter/facade/test cũ để tránh trùng).
    Commit + push lên arena/019f9fde-vipsound + mở PR (base meetily) để bạn merge.

    Lý do tôi không push thẳng main: chính sách Arena gắn session vào branch arena/019f9fde-vipsound, agent chỉ push branch đó rồi PR — không push trực tiếp main để bảo vệ review. Bạn merge PR là code vào main.

Tóm lại: c7aa828 đúng là đã lên (cảm ơn bạn check); 3 task sau (FFI symbol, WAV loader, docs .ai_context) vẫn kẹt ở local và cần session mới để lên sạch không trùng. Bạn muốn tôi tóm tắt lại diff chính xác của 3 task đó để session mới áp dụng nhanh không?
Tác vụ này có thành công không?
Esc
Workspace

Diff

# HANDOFF_MASTER — Kiến trúc & Nguyên tắc bất biến

> **Tài liệu handoff cho mọi AI Contributor.** Tổng hợp các quyết định kỹ thuật tinh hoa của VipSound / INUP v11.0.
> **NGUYÊN TẮC SỐ 0:** Không bao giờ phá vỡ các nguyên tắc dưới đây trừ khi có quyết định ghi đè rõ ràng. Khi sửa code, đối chiếu từng mục.

---

## 1. Ba Trụ cột kiến trúc

### Trụ cột 1 — Content-Anchored UID (Hash-based)
UID của mọi entity (segment, annotation, vocab) **bắt nguồn từ nội dung**, không phải vị trí/index → bất biến khi layout/UI đổi.

- Nguồn duy nhất: `packages/vipsound_stt/lib/models/content_id.dart` → `ContentId`.
- `audioFingerprint` = `md5(fileSizeBytes | durationMs | basename)`[:16].
- `segmentUid` = `md5(audioFingerprint | startMs | textNorm)`[:12] — cross-file unique.
- `textNorm` = lowercase + collapse whitespace.
- **JoinKey** bridge LrcLine ↔ SpeakerAnnotation sidecar (`startMs|textNorm`).
- ❌ Cấm: sinh UID bằng UUID ngẫu nhiên/sequence cho nội dung đã có.

### Trụ cột 2 — Native Rendering / DSP First
Tính toán nặng và render ưu tiên native, không ép Flutter widget làm việc không phù hợp.

- **Audio DSP**: `UltraTimeStretch` (C++, V1+V2, SIMD NEON/AVX, pfffft) — time-stretch 0.05x–10x bảo toàn formant, gọi qua Dart FFI. `native/src/`, `native/include/`.
- **Text/READ render**: dùng native webview (`webview_flutter`/`webview_win_floating`) + `pdfrx`, highlight CEFR/POS inject qua CSS/Annotation API thay vì rebuild bằng widget.
- ❌ Cấm: parse/vẽ waveform hay decode audio nặng trên UI isolate của Flutter.

### Trụ cột 3 — Database as Source of Truth
Trạng thái học tập/vocab/annotation lưu local-first (Hive), Firestore chỉ đồng bộ.

- Local: Hive boxes ở `lib/services/storage_service.dart`, `vocabulary_provider.dart`, `memory_bridge.dart`, `pdf_annotation_storage.dart`, `vocab_sync_service.dart`.
- Sync: Firebase Auth + Cloud Firestore (vocab + progress). Offline-first: đọc local tức thì, sync khi có mạng.
- ❌ Cấm: giữ state đáng tin cậy duy nhất trong memory/bloc mà không persist xuống Hive.

---

## 2. Quy tắc Isolate-Safety (TUYỆT ĐỐI)

STT/Whisper chạy trong Isolate riêng (qua `compute()`). Trong Isolate **KHÔNG được** chạm Platform Channel.

| Việc | Luồng | Lý do |
|------|-------|-------|
| `AudioConverter.convertToWhisperCompatible()` (FFmpegKit/Process) | **Main Thread** | Plugin FFmpegKit = method channel; không gọi được trong Isolate. |
| Resolve `modelPath`, `lrcDirectory` (`path_provider`) | **Main Thread** | `path_provider` = platform channel. |
| Diarization + SpeakerSidecar | **Main Thread** | phụ thuộc service của Main. |
| `SttEngineWhisper.runInIsolate()` → `_transcribeCore` | **Isolate** | compute nặng (whisper_full). |
| `_loadAudioAsPcm` / `loadWavAsPcm` (đọc WAV thuần Dart) | **Isolate OK** | chỉ `dart:io` + `dart:typed_data`, không Platform Channel. |
| Load libwhisper (`DynamicLibrary`) + FFI calls | **Isolate OK** | FFI không phải platform channel. |

- ❌ Cấm: gọi `path_provider`, `FFmpegKit`, `MethodChannel`, hay bất kỳ Flutter plugin nào bên trong `_isolateEntryPoint` / `_transcribeCore`.
- ✅ Pattern đúng (đã thực thi trong `SttServiceFacade._runWhisperViaIsolate`): resolve mọi tài nguyên platform trên Main → đóng gói vào `SttIsolatePayload` (plain data) → `compute()` → Isolate chỉ nhận plain data.

### Nạp thư viện native (Isolate-safe)
```dart
// Android/iOS: process() — plugin whisper_flutter_new đã load libwhisper vào process space.
// Windows: open('whisper.dll').
dylib = Platform.isWindows
    ? DynamicLibrary.open('whisper.dll')
    : DynamicLibrary.process(); // mobile
```
Dùng `DynamicLibrary.open('libwhisper.so')` riêng trên mobile → `undefined symbol` / mở sai lib.

---

## 3. Stateless Engine

`SttEngineWhisper` **không giữ instance state**:
- Không field nào lưu context/pointer giữa các lần gọi.
- Mọi thực thi qua **hàm tĩnh** `runInIsolate(SttIsolatePayload)` → `_transcribeCore()`.
- Vòng đời context: `_initWhisperContext` (load) → `whisper_full` → `_freeWhisperContext` (free trong `finally`).
- ❌ Cấm: cache `whisper_context` vào instance field; giữ `Pointer` thoát ra khỏi `_transcribeCore`.

---

## 4. An toàn bộ nhớ FFI (Whisper)

1. Mọi `calloc.alloc()` có `calloc.free()` tương ứng trong `finally`.
2. `whisper_context` free trong `finally` của `_transcribeCore`.
3. Không giữ `Pointer` qua ranh giới hàm (no escaping pointers).
4. `const char*` trả về từ Whisper **KHÔNG được free** — thuộc về context, giải phóng cùng `whisper_free()`.
5. Struct params (`WhisperFullParams`) cấp phát calloc, free sau `whisper_full()`.
6. Struct truyền by-value (`WhisperContextParams` vào `whisper_init_from_file_with_params`) phải khớp C ABI (xem comment offset trong file).

---

## 5. Quy ước API symbol (snake_case)

Toàn bộ lookup symbol native **phải** snake_case và khớp `windows/libs/whisper.h`:
`whisper_init_from_file_with_params`, `whisper_context_default_params`, `whisper_full`, `whisper_free`,
`whisper_full_default_params`, `whisper_full_n_segments`, `whisper_full_get_segment_t0/t1/text`,
`whisper_full_n_tokens`, `whisper_full_get_token_data/text`.
- ❌ Hàm deprecated `whisper_init_from_file` (không export) → đã xóa khỏi codebase.

---

## 6. Cấu trúc gói (packages)

| Package | Vai trò | Entry |
|---------|---------|-------|
| `vipsound_stt` | STT: Native + Whisper FFI + Diarization + LRC + ContentId | `stt_service_facade.dart` (barrel `vipsound_stt.dart`) |
| `vipsound_core` | SM-2 SRS, text_parser, CEFR vocab level | `vipsound_core.dart` |
| `vipsound_ai` | AI facade, Gemma/mock engine, model loader, error handler | `vipsound_ai.dart` |

**Luồng STT duy nhất (đã chuẩn hóa):**
`UI/Mixin` → `SttServiceFacade.transcribeFile()` → (cache?) → `_runWhisperViaIsolate()` → `compute(_isolateEntryPoint)` → `SttEngineWhisper.runInIsolate()` → kết quả + LRC + Diarization.

---

## 7. Phiên bản & danh tính
- `pubspec.yaml`: `name: vipsound`, `version: 1.4.1+3`.
- Architecture/STT version: **v11.0** (theo header comment trong `stt_*.dart`, `content_id.dart`).
- Codename: **INUP** (rebrand). Platform: Android, iOS, Windows (+ web skeleton).
- Xem lộ trình: [`MILESTONES.md`](./MILESTONES.md) · Trạng thái: [`KANBAN.md`](./KANBAN.md).