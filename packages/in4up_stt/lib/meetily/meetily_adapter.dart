// in4up v11.0 — Adapter Meetily Rust → SttResult + SpeakerAnnotation

import '../models/content_id.dart';
import '../models/stt_result.dart';
import '../diarization/speaker_annotation.dart';

/// Hợp đồng kỹ thuật với Meetily Rust Core
class MeetilyResult {
  final String text;
  final int speakerId; // 0, 1, 2...
  final Duration timestamp;
  final Duration? endTimestamp;
  final double confidence;

  const MeetilyResult({
    required this.text,
    required this.speakerId,
    required this.timestamp,
    this.endTimestamp,
    required this.confidence,
  });
}

/// Adapter duy nhất: Meetily data → in4up data model
///
/// Nguyên tắc:
/// - Không fake word timestamps
/// - Không mutate SttSegment
/// - Speaker data là overlay riêng
class MeetilyAdapter {
  MeetilyAdapter._();

  /// Chuyển đổi List<MeetilyResult> → SttResult (bất biến)
  static SttResult convert({
    required List<MeetilyResult> rawResults,
    required String audioFingerprint,
    required Duration processingTime,
    String language = 'en',
  }) {
    if (rawResults.isEmpty) {
      return SttResult.empty(SttEngineType.whisper);
    }

    final segments = <SttSegment>[];

    for (var i = 0; i < rawResults.length; i++) {
      final item = rawResults[i];
      final startSec = item.timestamp.inMilliseconds / 1000.0;

      // endSec: dùng endTimestamp nếu có, không thì startSec của item tiếp
      final endSec = item.endTimestamp != null
          ? item.endTimestamp!.inMilliseconds / 1000.0
          : (i + 1 < rawResults.length
              ? rawResults[i + 1].timestamp.inMilliseconds / 1000.0
              : startSec + 3.0); // fallback +3s

      final text = item.text.trim();

      segments.add(SttSegment(
        id: i,
        uid: ContentId.segmentUid(
          audioFingerprint: audioFingerprint,
          startMs: item.timestamp.inMilliseconds,
          text: text,
        ),
        startSeconds: startSec,
        endSeconds: endSec,
        text: text,
        words: const [], // ★ Không fake word-level timestamps
        avgConfidence: item.confidence,
      ));
    }

    return SttResult(
      fullText: segments.map((s) => s.text).join(' '),
      segments: segments,
      engineUsed: SttEngineType.whisper,
      language: language,
      processingTime: processingTime,
      audioFingerprint: audioFingerprint,
      hasWordTimestamps: false,
    );
  }

  /// Trích xuất Speaker overlay từ Meetily (đã có speakerId)
  static List<SpeakerAnnotation> extractSpeakers({
    required List<MeetilyResult> rawResults,
    required SttResult convertedResult,
  }) {
    final annotations = <SpeakerAnnotation>[];
    final len = rawResults.length < convertedResult.segments.length
        ? rawResults.length
        : convertedResult.segments.length;

    for (var i = 0; i < len; i++) {
      final raw = rawResults[i];
      final seg = convertedResult.segments[i];

      annotations.add(SpeakerAnnotation(
        segmentUid: seg.uid,
        joinKey: seg.joinKey,
        speakerId: raw.speakerId,
        confidence: raw.confidence,
        engine: 'meetily_rust',
        pipelineVersion: 'meetily-v1',
      ));
    }

    return annotations;
  }
}
