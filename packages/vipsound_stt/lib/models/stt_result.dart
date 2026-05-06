// packages/vipsound_stt/lib/models/stt_result.dart

import 'stt_model_info.dart'; // For SttEngineType

class SttResult {
  final String fullText;
  final List<SttSegment> segments;
  final SttEngineType engineUsed;
  final String language;
  final Duration processingTime;
  final bool hasWordTimestamps;
  final String? errorMessage; // ★ THÊM: Trường thông báo lỗi

  const SttResult({
    required this.fullText,
    required this.segments,
    required this.engineUsed,
    required this.language,
    required this.processingTime,
    required this.hasWordTimestamps,
    this.errorMessage, // ★ THÊM
  });

  bool get hasError =>
      errorMessage != null && errorMessage!.isNotEmpty; // ★ THÊM

  /// Lấy toàn bộ danh sách từ từ tất cả các segments
  List<SttWord> get allWords =>
      segments.expand((segment) => segment.words).toList();

  factory SttResult.empty(SttEngineType engine, {String? errorMessage}) =>
      SttResult(
        // ★ SỬA: Thêm errorMessage
        fullText: '',
        segments: const [],
        engineUsed: engine,
        language: 'en',
        processingTime: Duration.zero,
        hasWordTimestamps: false,
        errorMessage: errorMessage, // ★ THÊM
      );
}

class SttSegment {
  final int id;
  final double startSeconds;
  final double endSeconds;
  final String text;
  final List<SttWord> words;
  final double avgConfidence;

  const SttSegment({
    required this.id,
    required this.startSeconds,
    required this.endSeconds,
    required this.text,
    required this.words,
    required this.avgConfidence,
  });
}

class SttWord {
  final String word;
  final double startSeconds;
  final double endSeconds;
  final double confidence;

  const SttWord({
    required this.word,
    required this.startSeconds,
    required this.endSeconds,
    required this.confidence,
  });
}
