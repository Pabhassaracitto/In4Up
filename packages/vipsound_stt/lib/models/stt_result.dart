/// Một từ đơn với timestamp từ Whisper
class SttWord {
  final String word;
  final double startSeconds;
  final double endSeconds;
  final double confidence;

  const SttWord({
    required this.word,
    required this.startSeconds,
    required this.endSeconds,
    this.confidence = 1.0,
  });

  Duration get startDuration =>
      Duration(milliseconds: (startSeconds * 1000).round());
  Duration get endDuration =>
      Duration(milliseconds: (endSeconds * 1000).round());

  @override
  String toString() =>
      'SttWord("$word", ${startSeconds.toStringAsFixed(2)}s-'
      '${endSeconds.toStringAsFixed(2)}s, conf=${confidence.toStringAsFixed(2)})';
}

/// Một đoạn câu với danh sách từ
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

  Duration get startDuration =>
      Duration(milliseconds: (startSeconds * 1000).round());
  Duration get endDuration =>
      Duration(milliseconds: (endSeconds * 1000).round());
}

/// Kết quả tổng hợp từ bất kỳ engine nào
class SttResult {
  /// Toàn bộ văn bản phiên âm
  final String fullText;

  /// Danh sách segment (câu/đoạn)
  final List<SttSegment> segments;

  /// Engine đã sử dụng để tạo kết quả này
  final SttEngineType engineUsed;

  /// Ngôn ngữ được nhận diện
  final String language;

  /// Thời gian xử lý
  final Duration processingTime;

  /// Có timestamp chi tiết từng từ không
  final bool hasWordTimestamps;

  const SttResult({
    required this.fullText,
    required this.segments,
    required this.engineUsed,
    required this.language,
    required this.processingTime,
    this.hasWordTimestamps = false,
  });

  /// Lấy tất cả từ từ tất cả segments (dùng cho LRC)
  List<SttWord> get allWords =>
      segments.expand((seg) => seg.words).toList();

  /// Kết quả rỗng
  static SttResult empty(SttEngineType engine) => SttResult(
        fullText: '',
        segments: const [],
        engineUsed: engine,
        language: 'en',
        processingTime: Duration.zero,
        hasWordTimestamps: false,
      );

  @override
  String toString() =>
      'SttResult(engine=$engineUsed, words=${allWords.length}, '
      'duration=${processingTime.inSeconds}s)';
}

enum SttEngineType { native, whisper }
