// packages/in4up_stt/lib/stt_remote_response_parser.dart
//
// Parse JSON thô trả về từ OpenAiCompatClient.transcribeAudio() (chuẩn
// OpenAI-compatible `verbose_json`) → List<SttSegment>, dịch timestamp
// theo offset của chunk trong file gốc — WP2 (API-003).
//
// Nguyên tắc (MeetilyAdapter): KHÔNG fake word-level timestamps — provider
// chỉ trả segment-level thì `words` để RỖNG, `id`/`uid` tính theo đúng
// Content-Anchored UID hiện có (ContentId.segmentUid) để hoà chung với
// cache/LRC/transcript search sẵn có.
//
// Pure (không Flutter/IO/network) — test bằng `flutter test` không cần
// server thật.

import 'models/content_id.dart';
import 'models/stt_result.dart';

class SttRemoteResponseParser {
  SttRemoteResponseParser._();

  /// [offsetMs] = mốc bắt đầu (ms, trong file gốc) của chunk đã gửi API —
  /// mọi timestamp trong response (vốn tính từ 0 của riêng chunk) được
  /// cộng dồn để ra đúng mốc trên file gốc (đúng kỷ luật ghép của
  /// `hymt_chunking`: không lặp/mất đoạn).
  static List<SttSegment> parseSegments(
    Map<String, dynamic> json, {
    required int offsetMs,
    required String audioFingerprint,
    int idOffset = 0,
  }) {
    final raw = json['segments'];
    if (raw is! List || raw.isEmpty) {
      // Server chỉ trả 'text' phẳng (không hỗ trợ verbose_json đầy đủ) —
      // vẫn hữu ích: 1 segment phủ hết chunk, mốc = biên chunk (không bịa
      // thời lượng vì không biết thật).
      final text = (json['text'] as String?)?.trim() ?? '';
      if (text.isEmpty) return const <SttSegment>[];
      return <SttSegment>[
        SttSegment(
          id: idOffset,
          uid: ContentId.segmentUid(
            audioFingerprint: audioFingerprint,
            startMs: offsetMs,
            text: text,
          ),
          startSeconds: offsetMs / 1000.0,
          endSeconds: offsetMs / 1000.0,
          text: text,
          words: const [],
          avgConfidence: 1.0,
        ),
      ];
    }

    final segments = <SttSegment>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final text = (map['text'] as String? ?? '').trim();
      if (text.isEmpty) continue;

      final startSec = (map['start'] as num?)?.toDouble() ?? 0.0;
      final endSec = (map['end'] as num?)?.toDouble() ?? startSec;
      final startMs = offsetMs + (startSec * 1000).round();
      final endMs = offsetMs + (endSec * 1000).round();

      // avg_logprob (chuẩn whisper): ~0 = tin cậy cao, càng âm càng thấp —
      // heuristic quy đổi thô về [0,1], KHÔNG phải xác suất thật.
      final avgLogProb = (map['avg_logprob'] as num?)?.toDouble();
      final double confidence = avgLogProb != null
          ? (1.0 + avgLogProb).clamp(0.0, 1.0).toDouble()
          : 1.0;

      segments.add(SttSegment(
        id: idOffset + segments.length,
        uid: ContentId.segmentUid(
          audioFingerprint: audioFingerprint,
          startMs: startMs,
          text: text,
        ),
        startSeconds: startMs / 1000.0,
        endSeconds: endMs / 1000.0,
        text: text,
        words: const [], // ★ KHÔNG fake word-level timestamps
        avgConfidence: confidence,
      ));
    }
    return segments;
  }
}
