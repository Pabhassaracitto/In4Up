// packages/in4up_stt/lib/vad/sherpa_vad_core.dart
//
// SherpaVadCore — bọc sherpa_onnx.VoiceActivityDetector (API v1.13.4 đã
// verify từ source chính thức k2-fsa/sherpa-onnx tag v1.13.4).
//
// PLAN-008 (step: thay EnergyVad fallback bằng sherpa_onnx.Vad thật):
//   - File transcription: WAV 16kHz mono (AudioConverter đã chuẩn hóa)
//   - Pointer C-struct GIỮ TRONG SINGLETON (Section 3 handover) — không
//     re-init liên tục, tránh xung đột FFI với whisper.cpp
//   - Model: silero_vad.onnx (~2-5MB) — dynamic file trên device, KHÔNG
//     đóng gói APK (tránh phình)
//
// API dùng (v1.13.4):
//   initBindings()            — gọi MỘT LẦN trước mọi API native
//   VoiceActivityDetector(
//     config: VadModelConfig(
//       sileroVad: SileroVadModelConfig(model, threshold, minSilenceDuration,
//                                        minSpeechDuration, maxSpeechDuration,
//                                        windowSize),
//       sampleRate: 16000,
//     ),
//     bufferSizeInSeconds: N,
//   )
//   vad.acceptWaveform(Float32List) / isDetected() / isEmpty() /
//   front() -> SpeechSegment{samples, start} / pop() / flush() / free()

import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// Một đoạn speech phát hiện được (thời gian tính bằng giây trong file).
class SherpaVadSegment {
  final double startTime;
  final double endTime;

  const SherpaVadSegment({
    required this.startTime,
    required this.endTime,
  });

  double get duration => endTime - startTime;

  @override
  String toString() =>
      'SherpaVadSegment(${startTime.toStringAsFixed(3)}s -> '
      '${endTime.toStringAsFixed(3)}s)';
}

/// Sherpa Silero VAD core — singleton holder (Section 3).
class SherpaVadCore {
  static const int sampleRate = 16000;
  static const int windowSize = 512; // 1 frame silero = 32ms @16kHz

  static bool _bindingsInitialized = false;

  sherpa.VoiceActivityDetector? _vad;
  final String modelPath;

  bool get isReady => _vad != null;

  SherpaVadCore._(this.modelPath, sherpa.VoiceActivityDetector vad)
      : _vad = vad;

  /// Init FFI bindings MỘT lần (idempotent).
  static void ensureBindings() {
    if (_bindingsInitialized) return;
    sherpa.initBindings();
    _bindingsInitialized = true;
  }

  /// Tạo detector từ model silero_vad.onnx.
  /// Ném exception nếu model hỏng — caller tự fallback sang EnergyVad.
  factory SherpaVadCore({
    required String modelPath,
    double threshold = 0.5,
    double minSilenceDuration = 0.1,
    double minSpeechDuration = 0.25,
    double maxSpeechDuration = 14.0,
    int numThreads = 2,
  }) {
    ensureBindings();
    final config = sherpa.VadModelConfig(
      sileroVad: sherpa.SileroVadModelConfig(
        model: modelPath,
        threshold: threshold,
        minSilenceDuration: minSilenceDuration,
        minSpeechDuration: minSpeechDuration,
        maxSpeechDuration: maxSpeechDuration,
        windowSize: windowSize,
      ),
      sampleRate: sampleRate,
      numThreads: numThreads,
      debug: kDebugMode,
    );
    final vad = sherpa.VoiceActivityDetector(
      config: config,
      // Circular buffer chứa đủ segment dài nhất + biên an toàn
      bufferSizeInSeconds: maxSpeechDuration.toInt() + 8,
    );
    debugPrint('🚀 SherpaVadCore ready: $modelPath');
    return SherpaVadCore._(modelPath, vad);
  }

  /// Chạy VAD trên file WAV 16kHz mono → các đoạn speech.
  /// File sai chuẩn (không đọc được / sai sample rate) → trả [].
  List<SherpaVadSegment> detect(String wav16kPath) {
    final vad = _vad;
    if (vad == null) throw StateError('SherpaVadCore đã dispose');

    final wave = sherpa.readWave(wav16kPath);
    if (wave.samples.isEmpty) {
      debugPrint('⚠️ SherpaVadCore: readWave trả về rỗng: $wav16kPath');
      return const [];
    }
    if (wave.sampleRate != sampleRate) {
      debugPrint(
        '⚠️ SherpaVadCore: cần 16000Hz, nhận được ${wave.sampleRate}Hz '
        '($wav16kPath) — caller nên convert trước',
      );
      return const [];
    }

    vad.clear();
    final out = <SherpaVadSegment>[];
    final numIter = wave.samples.length ~/ windowSize;
    for (var i = 0; i < numIter; i++) {
      final start = i * windowSize;
      vad.acceptWaveform(
        Float32List.sublistView(wave.samples, start, start + windowSize),
      );
      _drain(vad, out);
    }
    // Flush phần speech cuối file (chưa kết thúc bằng silence)
    vad.flush();
    _drain(vad, out);
    return out;
  }

  void _drain(sherpa.VoiceActivityDetector vad, List<SherpaVadSegment> out) {
    while (!vad.isEmpty()) {
      final seg = vad.front();
      vad.pop();
      out.add(SherpaVadSegment(
        startTime: seg.start / sampleRate,
        endTime: (seg.start + seg.samples.length) / sampleRate,
      ));
    }
  }

  /// Xóa state giữa 2 file audio (giữ pointer — không re-init).
  void reset() => _vad?.clear();

  /// Giải phóng pointer native — gọi MỘT LÚC khi app dừng hẳn
  /// (không gọi giữa phiên — Section 3: giữ pointer trong singleton).
  void dispose() {
    _vad?.free();
    _vad = null;
  }
}
