// lib/models/sound_transcript.dart
// Soundlist – Bản ghi nội dung (transcript) của một file âm thanh.
//
// Lưu text + timestamp từng dòng (nguồn: Whisper khi Tự tạo mục lục,
// hoặc LRC có sẵn). Dùng cho tính năng "Tìm trong audio" — tìm chữ là
// nhảy thẳng tới đúng vị trí phát.

class TranscriptLine {
  final Duration start;
  final Duration end;
  final String text;

  const TranscriptLine({
    required this.start,
    required this.end,
    required this.text,
  });

  Map<String, dynamic> toJson() => {
        'start': start.inMilliseconds,
        'end': end.inMilliseconds,
        'text': text,
      };

  factory TranscriptLine.fromJson(Map<String, dynamic> j) => TranscriptLine(
        start: Duration(milliseconds: (j['start'] as num).toInt()),
        end: Duration(milliseconds: (j['end'] as num).toInt()),
        text: (j['text'] as String?) ?? '',
      );
}

class SoundTranscript {
  final String audioPath;
  final List<TranscriptLine> lines;
  final DateTime updatedAt;

  const SoundTranscript({
    required this.audioPath,
    required this.lines,
    required this.updatedAt,
  });

  /// Toàn bộ text nối lại (cho tìm kiếm toàn file).
  String get fullText => lines.map((l) => l.text).join(' ');

  int get lineCount => lines.length;

  Map<String, dynamic> toJson() => {
        'audioPath': audioPath,
        'lines': lines.map((l) => l.toJson()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory SoundTranscript.fromJson(Map<String, dynamic> j) => SoundTranscript(
        audioPath: j['audioPath'] as String,
        lines: (j['lines'] as List<dynamic>? ?? const [])
            .map((e) => TranscriptLine.fromJson(e as Map<String, dynamic>))
            .toList(),
        updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
