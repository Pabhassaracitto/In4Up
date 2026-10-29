// packages/in4up_stt/lib/models/stt_isolate_payload.dart
import 'stt_result.dart'; // Giả định SttResult có fromJson/toJson

class SttIsolatePayload {
  final String audioPath;
  final String modelPath;
  final String language;
  final bool wordTimestamps;
  final String modelLevelName;
  final String audioFingerprint;
  final bool generateLrc;
  final String? lrcOutputDirectory;

  const SttIsolatePayload({
    required this.audioPath,
    required this.modelPath,
    required this.language,
    required this.wordTimestamps,
    required this.modelLevelName,
    required this.audioFingerprint,
    required this.generateLrc,
    this.lrcOutputDirectory,
  });
}

class SttIsolateResult {
  final bool success;
  final String? errorMessage;
  final String fullText;
  final String engineUsed;
  final String language;
  final int processingTimeMs;
  final bool hasWordTimestamps;
  final String audioFingerprint;
  final List<Map<String, dynamic>> segmentsJson;
  final String? lrcFilePath;

  const SttIsolateResult({
    required this.success,
    this.errorMessage,
    required this.fullText,
    required this.engineUsed,
    required this.language,
    required this.processingTimeMs,
    required this.hasWordTimestamps,
    required this.audioFingerprint,
    required this.segmentsJson,
    this.lrcFilePath,
  });

  /// Factory lỗi
  factory SttIsolateResult.failure(String error) => SttIsolateResult(
        success: false,
        errorMessage: error,
        fullText: '',
        engineUsed: 'whisper',
        language: 'en',
        processingTimeMs: 0,
        hasWordTimestamps: false,
        audioFingerprint: '',
        segmentsJson: const [],
      );

  SttResult toSttResult() {
    return SttResult(
      fullText: fullText,
      segments: segmentsJson
          .map((j) => SttSegment.fromJson(j, audioFingerprint))
          .toList(),
      engineUsed: SttEngineType.whisper,
      language: language,
      processingTime: Duration(milliseconds: processingTimeMs),
      audioFingerprint: audioFingerprint,
      hasWordTimestamps: hasWordTimestamps,
    );
  }
}
