// lib/features/learn_by_heart/models/line_timestamp.dart

class LineTimestamp {
  /// Số thứ tự dòng (1-based index)
  final int line;

  /// Thời điểm bắt đầu (giây)
  final double start;

  /// Thời điểm kết thúc (giây)
  final double end;

  /// Văn bản dòng (Pali hoặc Việt)
  final String? text;

  /// Văn bản dòng Pali đối ứng (nếu có)
  final String? paliText;

  const LineTimestamp({
    required this.line,
    required this.start,
    required this.end,
    this.text,
    this.paliText,
  });

  Duration get startDuration => Duration(milliseconds: (start * 1000).round());
  Duration get endDuration => Duration(milliseconds: (end * 1000).round());
  Duration get lineDuration => Duration(milliseconds: ((end - start) * 1000).round());

  LineTimestamp copyWith({
    int? line,
    double? start,
    double? end,
    String? text,
    String? paliText,
  }) {
    return LineTimestamp(
      line: line ?? this.line,
      start: start ?? this.start,
      end: end ?? this.end,
      text: text ?? this.text,
      paliText: paliText ?? this.paliText,
    );
  }

  Map<String, dynamic> toJson() => {
        'line': line,
        'start': start,
        'end': end,
        if (text != null) 'text': text,
        if (paliText != null) 'paliText': paliText,
      };

  factory LineTimestamp.fromJson(Map<String, dynamic> json) {
    return LineTimestamp(
      line: json['line'] as int? ?? 1,
      start: (json['start'] as num?)?.toDouble() ?? 0.0,
      end: (json['end'] as num?)?.toDouble() ?? 0.0,
      text: json['text'] as String?,
      paliText: json['paliText'] as String?,
    );
  }
}
