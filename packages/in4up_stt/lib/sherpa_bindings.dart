// packages/in4up_stt/lib/sherpa_bindings.dart
//
// Init FFI sherpa-onnx MỘT lần cho toàn bộ package (VAD, TTS, STT...).
// API v1.13.4 (verify từ source k2-fsa/sherpa-onnx tag v1.13.4):
//   "Call this exactly once before using any other API from this package."
//
// Section 3 handover: pointer native GIỮ TRONG SINGLETON — không
// re-init liên tục, tránh xung đột FFI giữa whisper.cpp và sherpa_onnx.

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

bool _sherpaInitialized = false;

/// Idempotent — gọi trước mọi API sherpa_onnx (Vad/OfflineTts/Recognizer).
void ensureSherpaBindings() {
  if (_sherpaInitialized) return;
  sherpa.initBindings();
  _sherpaInitialized = true;
}
