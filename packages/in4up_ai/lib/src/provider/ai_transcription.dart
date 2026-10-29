// packages/in4up_ai/lib/src/provider/ai_transcription.dart
//
// WP2 (API-003) — Model + parser kết quả POST /v1/audio/transcriptions
// (chuẩn OpenAI-compatible: OpenAI/Groq/Speaches/whisper-server).
//
// `response_format: verbose_json` trả:
//   { "text": "...", "language": "en", "duration": 123.4,
//     "segments": [ { "id": 0, "start": 0.0, "end": 3.2, "text": "...",
//                     "words": [ { "word": "Hello", "start": 0.0, "end": 0.4 } ] } ] }
//
// `words` chỉ một số server trả (OpenAI whisper-1, Groq whisper-large-v3) —
// khi thiếu, `words` rỗng (KHÔNG fake word timestamps — nguyên tắc Meetily).
//
// Thuần logic (không network) để test bằng fixture JSON thật.

/// 1 từ kèm timestamp (giây, tính từ ĐẦU file ĐƯỢC GỬI — caller tự offset
/// khi file dài được cắt chunk).
class AiTranscriptionWord {
  final String word;
  final double start;
  final double end;

  const AiTranscriptionWord({required this.word, required this.start, required this.end});
}

/// 1 đoạn transcript kèm timestamp (giây).
class AiTranscriptionSegment {
  final int id;
  final double start;
  final double end;
  final String text;
  final List<AiTranscriptionWord> words;

  const AiTranscriptionSegment({
    required this.id,
    required this.start,
    required this.end,
    required this.text,
    this.words = const [],
  });
}

/// Kết quả transcribe 1 file (hoặc 1 chunk) — đã parse từ verbose_json.
class AiTranscription {
  /// Toàn bộ text (nối các segment) — rỗng là BẤT THƯỜNG (server 200 mà
  /// không có nội dung ⇒ caller phải coi là lỗi, không fake success).
  final String text;

  /// Ngôn ngữ server nhận diện (vd 'en', 'vi').
  final String language;

  /// Tổng thời lượng audio (giây) server báo.
  final double? durationSeconds;

  final List<AiTranscriptionSegment> segments;

  const AiTranscription({
    required this.text,
    required this.language,
    required this.segments,
    this.durationSeconds,
  });

  bool get hasWords => segments.any((s) => s.words.isNotEmpty);

  static AiTranscription fromJson(Map<String, dynamic> j) {
    final rawSegments = j['segments'];
    final segments = <AiTranscriptionSegment>[];
    if (rawSegments is List) {
      for (final s in rawSegments) {
        if (s is! Map) continue;
        final text = (s['text'] as String?)?.trim() ?? '';
        if (text.isEmpty) continue;
        final rawWords = s['words'];
        final words = <AiTranscriptionWord>[];
        if (rawWords is List) {
          for (final w in rawWords) {
            if (w is! Map) continue;
            final word = w['word'] as String?;
            final start = (w['start'] as num?)?.toDouble();
            final end = (w['end'] as num?)?.toDouble();
            if (word == null || word.isEmpty || start == null || end == null) {
              continue;
            }
            words.add(AiTranscriptionWord(word: word, start: start, end: end));
          }
        }
        segments.add(AiTranscriptionSegment(
          id: s['id'] as int? ?? segments.length,
          start: (s['start'] as num?)?.toDouble() ?? 0.0,
          end: (s['end'] as num?)?.toDouble() ?? 0.0,
          text: text,
          words: words,
        ));
      }
    }
    return AiTranscription(
      text: ((j['text'] as String?) ?? '').trim(),
      language: (j['language'] as String?) ?? '',
      durationSeconds: (j['duration'] as num?)?.toDouble(),
      segments: segments,
    );
  }
}
