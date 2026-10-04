# Sherpa-ONNX Spike PoC (Strategy Pattern Step 2)

Đây là **spike đánh giá** — không thay thế Whisper. Mục tiêu: đo WER / latency /
RAM / APK size của Sherpa-ONNX so với Whisper tiny/small trên use-case
**file → LRC karaoke** và **live streaming STT**.

## Kiến trúc (đã có từ Step 1)

```
SttEngine (interface)
├── WhisperSttEngine  — đường hiện tại (đã chạy ổn)
├── NativeSttEngine   — live mic (speech_to_text)
└── SherpaSttEngine   — PoC mới (file offline + online streaming)
```

Sherpa được đăng ký trong `SttEngineRegistry` với `SttEngineType.sherpa`.
Lấy engine: `SttServiceFacade.getEngine(SttEngineType.sherpa)`.

## Cài model ONNX

Sherpa dùng model `.onnx` (nhẹ hơn ggml). Cần bộ model encoder/decoder/joiner + tokens.txt.
Tải từ https://k2-fsa.github.io/sherpa/onnx/pretrained_models/
Ví dụ Zipformer streaming (EN): `sherpa-onnx-streaming-zipformer-en-...`.

Nên **dynamic download** (giống SttModelManager của Whisper) thay vì đóng gói
vào APK để tránh phình APK.

## API đang dùng (sherpa_onnx ^1.13.4)

- `OfflineRecognizer(config)` + `readWave(path)` + `createStream()` +
  `acceptWaveform()` + `decode()` + `getResult()` → text/tokens/timestamps.
- `OnlineRecognizer(config)` cho streaming (mic).

## Việc cần làm khi benchmark

1. `flutter pub get` trong `packages/in2up_stt` (đã thêm `sherpa_onnx: ^1.13.4`).
2. Đặt model ONNX vào device, truyền path qua `SherpaModelPaths`.
3. Gọi `SttServiceFacade.getEngine(SttEngineType.sherpa).transcribeFile(...)`.
4. So sánh trên 10 file EN/VN: WER, latency, RAM, APK size.

## Lưu ý

- **Chưa build/test** — sandbox không có toolchain Flutter/NDK.
- Nếu build gặp lỗi API, kiểm tra lại tên hàm theo package đã cài
  (`pub.dev/packages/sherpa_onnx`).
- Muốn tắt Sherpa khỏi APK: bỏ dòng `sherpa_onnx` trong pubspec + dòng
  `SttEngineType.sherpa: _sherpaFactory` trong registry.
