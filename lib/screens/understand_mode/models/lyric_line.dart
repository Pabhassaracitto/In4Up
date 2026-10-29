// lib/models/lyric_line.dart

class LyricLine {
  final String content;
  final String? translation;
  final Duration? startTime;
  final Duration? endTime;
  final bool isHighlighted;
  final Map<String, dynamic> metadata;

  LyricLine({
    required this.content,
    this.translation,
    this.startTime,
    this.endTime,
    this.isHighlighted = false,
    this.metadata = const {},
  });

  // Copy with method
  LyricLine copyWith({
    String? content,
    String? translation,
    Duration? startTime,
    Duration? endTime,
    bool? isHighlighted,
    Map<String, dynamic>? metadata,
  }) {
    return LyricLine(
      content: content ?? this.content,
      translation: translation ?? this.translation,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isHighlighted: isHighlighted ?? this.isHighlighted,
      metadata: metadata ?? this.metadata,
    );
  }

  // Factory constructor từ JSON
  factory LyricLine.fromJson(Map<String, dynamic> json) {
    return LyricLine(
      content: json['content'] ?? '',
      translation: json['translation'],
      startTime: json['startTime'] != null
          ? Duration(milliseconds: json['startTime'])
          : null,
      endTime: json['endTime'] != null
          ? Duration(milliseconds: json['endTime'])
          : null,
      isHighlighted: json['isHighlighted'] ?? false,
      metadata: json['metadata'] ?? {},
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'translation': translation,
      'startTime': startTime?.inMilliseconds,
      'endTime': endTime?.inMilliseconds,
      'isHighlighted': isHighlighted,
      'metadata': metadata,
    };
  }

  // Kiểm tra có thời gian đồng bộ không
  bool get isSynced => startTime != null;

  // Lấy độ dài của dòng (số từ)
  int get wordCount =>
      content.trim().isEmpty ? 0 : content.trim().split(RegExp(r'\s+')).length;

  // Lấy độ dài của dòng (số ký tự)
  int get characterCount => content.length;

  @override
  String toString() {
    return 'LyricLine(content: $content, startTime: $startTime, endTime: $endTime)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LyricLine &&
        other.content == content &&
        other.translation == translation &&
        other.startTime == startTime &&
        other.endTime == endTime;
  }

  @override
  int get hashCode {
    return content.hashCode ^
        translation.hashCode ^
        startTime.hashCode ^
        endTime.hashCode;
  }
}

// Extension để xử lý List<LyricLine>
extension LyricLineListExtension on List<LyricLine> {
  // Lọc các dòng có đồng bộ thời gian
  List<LyricLine> get syncedLines => where((line) => line.isSynced).toList();

  // Lọc các dòng chưa đồng bộ
  List<LyricLine> get unsyncedLines => where((line) => !line.isSynced).toList();

  // Tìm dòng theo thời gian
  int findIndexByTime(Duration position) {
    for (int i = 0; i < length; i++) {
      final line = this[i];
      if (line.startTime != null && position >= line.startTime!) {
        if (line.endTime == null || position <= line.endTime!) {
          return i;
        }
      }
    }
    return -1;
  }

  // Tìm dòng theo nội dung
  List<int> findIndicesByContent(String keyword) {
    final indices = <int>[];
    for (int i = 0; i < length; i++) {
      if (this[i].content.toLowerCase().contains(keyword.toLowerCase())) {
        indices.add(i);
      }
    }
    return indices;
  }

  // Lấy đoạn text từ startIndex đến endIndex
  String getSegment(int startIndex, int endIndex) {
    if (startIndex < 0 || endIndex >= length || startIndex > endIndex) {
      return '';
    }

    return sublist(startIndex, endIndex + 1)
        .map((line) => line.content)
        .join(' ');
  }

  // Tính tổng duration của các dòng đã đồng bộ
  Duration get totalDuration {
    Duration total = Duration.zero;
    for (final line in syncedLines) {
      if (line.startTime != null && line.endTime != null) {
        total += line.endTime! - line.startTime!;
      }
    }
    return total;
  }
}
