# VAD + Whisper + Future TTS/Streaming Architecture

Dự án: Flutter Audio Processing App (Android Tablet ARM64 & iOS)
Trạng thái: whisper.cpp offline GGML .bin ~37/75MB đã chạy, VAD pipeline vừa tích hợp.

## SECTION 1 — Fix lỗi cũ HttpException: Connection closed

**RCA:**
- Sai đường dẫn filePath local trên Android Tablet làm wrapper whisper.cpp không tìm thấy file -> fallback tự gọi HTTP GET HuggingFace CDN -> timeout / Battery Saver cắt -> HttpException.

**Fix triệt để (đã áp dụng):**

1. **Rule 1 Absolute Path:**
   ```dart
   final dir = await getApplicationDocumentsDirectory();
   final modelPath = '${dir.path}/in4up_whisper_models/ggml-tiny-q4_0.bin';
   // Hoặc ggml-tiny.bin tùy model đã chép
   ```
   - SttModelManager._resolveModelDirectory() đổi từ getApplicationSupportDirectory() sang getApplicationDocumentsDirectory()
   - Thêm fallback scan legacy support dir để không mất model cũ
   - SttServiceFacade._runWhisperViaIsolate() có fallback tìm trực tiếp tại documents/in4up_whisper_models/

2. **Rule 2 Disable Auto-Download:**
   - SttModelManager.downloadModel() thêm flag _kDisableAutoDownload = true -> return false ngay, không gọi Dio download HuggingFace
   - main.dart _sttModelUrls đặt rỗng [] để không trigger fallback
   - ensureModel() chỉ kiểm tra local, báo lỗi thân thiện yêu cầu chép thủ công

3. **Rule 3 Local Verification:**
   - File(modelPath).existsSync() + lengthSync() > 1_000_000 trước init Whisper instance
   - SttModelManager._verifyFileWithAbsoluteCheck() + SttServiceFacade check existsSync + size
   - Tránh crash khi file corrupt / hardcode sai path

## SECTION 2 — Pipeline tối ưu VAD + Whisper.cpp

**Mục tiêu:** giảm file 1h từ 20 phút xuống 8-10 phút, tránh OOM trên Tablet.

### Kiến trúc pipeline (Sequential Processing)

```
[File Audio Gốc (.wav/.mp3)]
         │
         ▼
[1. Sherpa-VAD Segmenter] ──► List<SpeechSegment> (start_time, end_time)
         │
         ▼
[2. Chunk Audio Extractor] ──► Cắt file nhỏ/buffer tạm theo List Segment
         │
         ▼
[3. Whisper.cpp Loop] ──► Xử lý từng Chunk (.bin model) trong Isolate riêng
         │
         ▼
[4. Offset Corrector] ──► Absolute_Time = Chunk_Text_Time + Segment_Start_Time
         │
         ▼
[5. UI Stream / File Output] ──► Render real-time progress & Clean file tạm (delete ngay)
```

**Files đã tạo:**
- `lib/features/vad/models/speech_segment.dart` — SpeechSegment, VadResult
- `lib/features/vad/services/sherpa_vad_service.dart` — SherpaVadService (singleton, absolute path, verification, fallback EnergyVad)
- `lib/features/vad/services/chunk_audio_extractor.dart` — cắt file nhỏ, không nạp cả file 1h vào RAM, delete ngay sau whisper
- `lib/features/vad/pipeline/vad_whisper_pipeline.dart` — orchestrator chạy trong Isolate, stream progress, offset corrector, ETA
- `lib/features/vad/pipeline/vad_pipeline_integration.dart` — wrapper cho PlayerSttMixin

**Quy định kỹ thuật khi triển khai VAD:**
- Library khuyên dùng: `sherpa_onnx` (chỉ load VAD module, rất nhẹ ~2-5MB — file `silero_vad.onnx`)
- Quản lý Memory & Cleanup:
  - Không nạp nguyên file 1h vào RAM: chỉ probe duration, cắt lazy từng chunk
  - Mỗi Chunk sau khi whisper xong gọi file.delete() ngay (ChunkAudioExtractor, VadWhisperPipeline)
  - Nhường event loop 100-500ms mỗi 3 chunks để GC thu hồi Scudo native memory (fix OOM 38s đã áp dụng)
  - Ép whisper.cpp chạy trong Flutter Isolate riêng (SttServiceFacade dùng compute() cho desktop, transcribeMobileChunked vẫn là known-good path cho Android)
- Giảm thời gian: skip silence (VAD loại bỏ im lặng) + chunk 14-15s thay vì 30s + tiny fallback cho file >60s

**Tích hợp hiện tại:**
- PlayerSttMixin.generateLrcForCurrentAudio() tự động chuyển sang VAD pipeline nếu file >5MB (~60s+)
- Có thêm generateLrcWithVadPipeline() riêng để UI gọi trực tiếp với skipSilence=true

## SECTION 3 — Lộ trình tương lai (ONNX cho TTS & Streaming)

Định hướng Format Model (đã thống nhất):

| Module Feature | Engine / Library | Format Model | Vai trò |
|---|---|---|---|
| STT File / Bóc băng | whisper.cpp | .bin (GGML/GGUF) q4_0 | Offline chính xác cao, xử lý từng Chunk qua VAD |
| Silence Detection (VAD) | sherpa-onnx | .onnx (Silero VAD ~2-5MB) | Quét mốc im lặng/tiếng nói hỗ trợ Whisper cắt file |
| Live Streaming STT | sherpa-onnx | .onnx (Zipformer RNN-T ~20-32MB) | Mic trực tiếp <100ms latency cho cabin STS & shadowing |
| Text-to-Speech (TTS) | sherpa-onnx | .onnx (VITS / Piper) | Đọc văn bản Việt/Anh offline |

**Lưu ý tránh xung đột Native khi nâng cấp (Section 3 — đã áp dụng Singleton):**

- Cả whisper.cpp và sherpa-onnx đều gọi qua FFI. Không re-init liên tục, giữ Pointer C-struct trong Singleton:
  - SherpaVadService._instance singleton
  - ChunkAudioExtractor._instance singleton
  - VadWhisperPipeline._instance singleton
  - WhisperService._instance singleton
- Kiểm tra quyền trong AndroidManifest.xml:
  - `RECORD_AUDIO` (vừa thêm) cho Stream Mic
  - `WRITE_EXTERNAL_STORAGE`, `READ_EXTERNAL_STORAGE`, `READ_MEDIA_AUDIO` đã có
  - `FOREGROUND_SERVICE`, `WAKE_LOCK`, `largeHeap=true` đã có để chạy background + tránh OOM

**Branch tiếp theo (khi nghiệm thu xong 2 task đầu):**
- Người dùng sẽ cho xem branch thực tế đã bắt đầu sherpa (TTS, Live Streaming) để tích hợp
- Khi đó chỉ cần thay EnergyVad fallback bằng sherpa_onnx Vad thật trong `SherpaVadService._ensureInitialized()`:
  ```dart
  _nativeVadPointer = sherpa_onnx.Vad(config: ...)
  ```
  và giữ nguyên pipeline, offset corrector, cleanup logic.

## Checklist kiểm thử

- [ ] Chép file `ggml-tiny-q4_0.bin` hoặc `ggml-tiny.bin` vào `getApplicationDocumentsDirectory()/in4up_whisper_models/` trên Android Tablet, size >1MB
- [ ] Mở app, vào Settings → kiểm tra model dir hiển thị đúng documents path, không gọi HuggingFace
- [ ] Thử bóc băng file 1h: quan sát log VAD -> N segments, mỗi chunk xong file temp bị delete ngay, RAM không tăng vọt
- [ ] Kiểm tra thời gian: file 1h nên xuống ~8-10p (nếu VAD loại được 30-40% silence)
- [ ] Kiểm tra RECORD_AUDIO permission khi thử mic streaming (tương lai)

## Ghi chú cho Agent tiếp theo

- Đọc `AGENTS.md` và `docs/skills/ci-red-debugging/SKILL.md` trước khi debug CI đỏ
- Khi tích hợp sherpa_onnx thật, nhớ thêm dependency `sherpa_onnx: ^x.y.z` vào pubspec, và copy `silero_vad.onnx` vào `assets/` hoặc download một lần rồi chép vào documents folder với verification tương tự Whisper
- Không gộp SM-2, không đụng UltraTimeStretch FFI
