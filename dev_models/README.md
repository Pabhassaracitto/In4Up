# dev_models — chỗ đặt model cho lập trình viên (VS Code)

App **không** đóng gói VAD/Piper/Whisper trong APK. User tải/import trong
**Home → Quản lý Model AI**.

Lập trình viên muốn chạy desktop/debug mà không bấm Tải về mỗi lần:

```
dev_models/
  whisper/   ggml-tiny-q4_0.bin   (hoặc ggml-tiny.bin)
  sherpa_asr/<tên-thư-mục>/       encoder*.onnx + decoder*.onnx + joiner*.onnx + tokens.txt
  vad/       silero_vad.onnx      (>1MB)
  piper/     *.onnx + tokens.txt + espeak-ng-data/
```

`sherpa_asr/` (PARAKEET-001) nhận cả bundle Parakeet: đặt tên thư mục có chữ
`parakeet`/`nemo`/`tdt` để app nhận đúng profile, ví dụ

```
dev_models/sherpa_asr/sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8/
  encoder.int8.onnx  decoder.int8.onnx  joiner.int8.onnx  tokens.txt
```

Nguồn: https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8.tar.bz2
(~487MB; app chỉ copy khi profile **chưa** được cài và chỉ ở `kDebugMode`).

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
