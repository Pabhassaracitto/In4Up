# dev_models — chỗ đặt model cho lập trình viên (VS Code)

App **không** đóng gói VAD/Piper/Whisper trong APK. User tải/import trong
**Home → Quản lý Model AI**.

Lập trình viên muốn chạy desktop/debug mà không bấm Tải về mỗi lần:

```
dev_models/
  whisper/   ggml-tiny-q4_0.bin   (hoặc ggml-tiny.bin)
  vad/       silero_vad.onnx      (>1MB)
  piper/     *.onnx + tokens.txt + espeak-ng-data/
```

Chỉ chạy khi `kDebugMode`. App tìm theo thứ tự:

1. Biến môi trường `IN4UP_MODELS_DIR` (trỏ vào folder này)
2. Đi lên từ thư mục chạy, gặp `dev_models/`

`.vscode/launch.json` đã set `IN4UP_MODELS_DIR=${workspaceFolder}/dev_models`.

Mở Quản lý Model AI một lần — app copy file còn thiếu vào documents của flavor
đang chạy. **Không** dùng `Android/data/com.in4up.dev` trừ khi bạn đang cài
đúng flavor `dev`.

Nguồn:

- VAD: https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx
- Piper: https://github.com/k2-fsa/sherpa-onnx/releases/tag/tts-models
