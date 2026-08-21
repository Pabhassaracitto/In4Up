// packages/in2up_stt/lib/stt_engine_whisper_strategy.dart
//
// WhisperSttEngine — adapter của SttEngineWhisper theo interface SttEngine
// (Strategy Pattern). Giữ nguyên mọi logic hiện có (chunking, karaoke,
// mobile plugin / desktop FFI/CLI); chỉ bọc lại để facade switch được.

import 'models/stt_config.dart';
import 'models/stt_model_info.dart';
import 'models/stt_result.dart';
import 'stt_engine.dart';
import 'stt_engine_whisper.dart';

class WhisperSttEngine implements SttEngine {
  /// Nơi đặt model (modelDir cho mobile plugin).
  final String modelDir;

  /// Model mặc định.
  final WhisperModelLevel defaultLevel;

  WhisperSttEngine({
    required this.modelDir,
    this.defaultLevel = WhisperModelLevel.tiny,
  });

  @override
  String get engineName => 'whisper';

  @override
  SttEngineCapabilities get capabilities => const SttEngineCapabilities(
        supportsFileTranscription: true,
        supportsWordTimestamps: true,
        supportsOffline: true,
        supportsChunking: true,
      );

  @override
  Future<void> initialize() async {}

  @override
  Future<SttResult> transcribeFile(
    String audioPath, {
    Map<String, dynamic>? options,
  }) {
    // Các option tùy engine — parse từ map, giữ mặc định an toàn.
    final level = (options?['level'] as WhisperModelLevel?) ?? defaultLevel;
    final language = (options?['language'] as String?) ?? 'en';
    final grouping =
        (options?['grouping'] as SttSegmentGrouping?) ??
            SttSegmentGrouping.sentence;
    final chunkSeconds = (options?['chunkDurationSeconds'] as int?) ?? 30;
    final maxChunks = (options?['maxChunks'] as int?) ?? 0;
    final audioFingerprint = (options?['audioFingerprint'] as String?) ?? '';

    // Mobile: dùng plugin (chunked progressive). Desktop: FFI/CLI.
    if (SttEngineWhisper.isMobilePluginSupported) {
      return SttEngineWhisper.transcribeMobileChunked(
        audioPath: audioPath,
        modelDir: modelDir,
        level: level,
        language: language,
        wordTimestamps: true,
        audioFingerprint: audioFingerprint,
        chunkDurationSeconds: chunkSeconds,
        maxChunks: maxChunks,
        grouping: grouping,
      );
    }

    // Desktop: engine trực tiếp (FFI/CLI). Cần modelPath.
    final modelPath = (options?['modelPath'] as String?) ?? '';
    return SttEngineWhisper().transcribe(
      audioPath,
      level: level,
      language: language,
      wordTimestamps: true,
      modelPath: modelPath,
      audioFingerprint: audioFingerprint,
    );
  }

  @override
  Future<void> dispose() async {}
}
