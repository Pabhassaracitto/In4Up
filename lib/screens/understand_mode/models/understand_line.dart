// lib/screens/understand_mode/models/understand_line.dart

import '../../../models/text_item.dart';

class UnderstandLine {
  final String content;
  final String? translation;
  final Duration? startTime;
  final Duration? endTime;
  final bool isDifficult;
  final int repetitionCount;
  final double comprehensionScore;
  final List<String> notes;

  UnderstandLine({
    required this.content,
    this.translation,
    this.startTime,
    this.endTime,
    this.isDifficult = false,
    this.repetitionCount = 0,
    this.comprehensionScore = 0.0,
    this.notes = const [],
  });

  factory UnderstandLine.fromTextItem(TextItem line) {
    return UnderstandLine(
      content: line.content,
      translation: line.translation,
      startTime: line.startTime,
      endTime: line.endTime,
    );
  }

  UnderstandLine copyWith({
    String? content,
    String? translation,
    Duration? startTime,
    Duration? endTime,
    bool? isDifficult,
    int? repetitionCount,
    double? comprehensionScore,
    List<String>? notes,
  }) {
    return UnderstandLine(
      content: content ?? this.content,
      translation: translation ?? this.translation,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isDifficult: isDifficult ?? this.isDifficult,
      repetitionCount: repetitionCount ?? this.repetitionCount,
      comprehensionScore: comprehensionScore ?? this.comprehensionScore,
      notes: notes ?? this.notes,
    );
  }
}
