// packages/vipsound_stt/lib/models/stt_isolate_payload.dart
//
// Plain-data container truyền vào Isolate.
// KHÔNG chứa bất kỳ instance nào — chỉ primitives + List/Map.
// Dart's compute() serialize object qua SendPort, nên phải serializable.

/// Payload truyền vào Isolate — hoàn toàn stateless.
class SttIsolatePayload {
  /// Đường dẫn tuyệt đối đến file audio cần transcribe.
  final String audioPath;

  /// Đường dẫn tuyệt đối đến file model Whisper (.bin).
  /// Được resolve TRƯỚC khi spawn Isolate trên Main Thread.
  final String modelPath;

  /// Ngôn ngữ BCP-47 ('en', 'vi', ...).
  final String language;

  /// Có trả về word-level timestamps không.
  final bool wordTimestamps;

  /// Level của model (để ghi vào SttResult.engineUsed metadata).
  final String modelLevelName;

  /// Audio fingerprint — tính sẵn trên Main Thread.
  final String audioFingerprint;

  /// Config flags cần thiết trong Isolate.
  final bool generateLrc;

  /// Đường dẫn thư mục lưu LRC (nếu generateLrc = true).
  /// Isolate tự write file nếu có đủ quyền.
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

  /// Convert sang Map để verify serialization an toàn.
  Map<String, dynamic> toMap() => {
        'audioPath': audioPath,
        'modelPath': modelPath,
        'language': language,
        'wordTimestamps': wordTimestamps,
        'modelLevelName': modelLevelName,
        'audioFingerprint': audioFingerprint,
        'generateLrc': generateLrc,
        'lrcOutputDirectory': lrcOutputDirectory,
      };
}

/// Kết quả trả về từ Isolate — cũng phải serializable.
class SttIsolateResult {
  final bool success;
  final String? errorMessage;

  // SttResult fields (flatten để tránh serialize class phức tạp)
  final String fullText;
  final String engineUsed; // SttEngineType.name
  final String language;
  final int processingTimeMs;
  final bool hasWordTimestamps;
  final String audioFingerprint;

  /// Segments dưới dạng List<Map> — tránh truyền class qua Isolate.
  final List<Map<String, dynamic>> segmentsJson;

  /// Path đến file LRC đã được write bởi Isolate (nếu có).
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

  Map<String, dynamic> toMap() => {
        'success': success,
        'errorMessage': errorMessage,
        'fullText': fullText,
        'engineUsed': engineUsed,
        'language': language,
        'processingTimeMs': processingTimeMs,
        'hasWordTimestamps': hasWordTimestamps,
        'audioFingerprint': audioFingerprint,
        'segmentsJson': segmentsJson,
        'lrcFilePath': lrcFilePath,
      };
}
