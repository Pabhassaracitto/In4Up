// lib/features/vad/models/speech_segment.dart
// Handover SECTION 2 — Pipeline VAD + Whisper
// [File Audio] -> [Sherpa-VAD] -> List<SpeechSegment> (start_time, end_time)

/// Đại diện một đoạn có tiếng nói được VAD phát hiện
/// start/end tính bằng giây (absolute time của file gốc)
class SpeechSegment {
  /// Thời gian bắt đầu (giây)
  final double startTime;

  /// Thời gian kết thúc (giây)
  final double endTime;

  /// Độ tin cậy VAD (0..1) — optional, sherpa_onnx trả về
  final double confidence;

  /// Có phải là speech hay không (true) hay silence/noise
  final bool isSpeech;

  const SpeechSegment({
    required this.startTime,
    required this.endTime,
    this.confidence = 1.0,
    this.isSpeech = true,
  });

  double get duration => endTime - startTime;

  Duration get startDuration =>
      Duration(milliseconds: (startTime * 1000).round());

  Duration get endDuration =>
      Duration(milliseconds: (endTime * 1000).round());

  /// Absolute_Time = Chunk_Text_Time + Segment_Start_Time (Offset Corrector)
  double correctTimestamp(double chunkRelativeTime) {
    return startTime + chunkRelativeTime;
  }

  @override
  String toString() =>
      'SpeechSegment(${startTime.toStringAsFixed(2)}s -> ${endTime.toStringAsFixed(2)}s, '
      '${duration.toStringAsFixed(2)}s, conf: $confidence)';

  Map<String, dynamic> toJson() => {
        'start': startTime,
        'end': endTime,
        'confidence': confidence,
        'isSpeech': isSpeech,
      };

  factory SpeechSegment.fromJson(Map<String, dynamic> json) => SpeechSegment(
        startTime: (json['start'] as num).toDouble(),
        endTime: (json['end'] as num).toDouble(),
        confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
        isSpeech: json['isSpeech'] as bool? ?? true,
      );
}

/// Kết quả VAD toàn file
class VadResult {
  final List<SpeechSegment> segments;
  final double totalAudioDuration; // giây
  final double totalSpeechDuration; // giây sau khi loại bỏ silence
  final Duration processingTime;
  final String engineUsed; // e.g. sherpa_onnx, energy_fallback

  const VadResult({
    required this.segments,
    required this.totalAudioDuration,
    required this.totalSpeechDuration,
    required this.processingTime,
    this.engineUsed = 'unknown',
  });

  double get speechRatio =>
      totalAudioDuration > 0 ? totalSpeechDuration / totalAudioDuration : 0;

  @override
  String toString() =>
      'VadResult(${segments.length} segments, '
      'audio: ${totalAudioDuration.toStringAsFixed(1)}s, '
      'speech: ${totalSpeechDuration.toStringAsFixed(1)}s, '
      'ratio: ${(speechRatio * 100).toStringAsFixed(1)}%, '
      'engine: $engineUsed)';
}
