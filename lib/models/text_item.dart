// lib/models/text_item.dart
// VipSound - Text Item Model
// Không chứa WordType (được chuyển sang word_analysis.dart)

class TextItem {
  final String id;
  final String content;
  final String? translation;
  final Duration? startTime;
  final Duration? endTime;
  final List<WordItem> words;
  final bool isHighlighted;

  TextItem({
    required this.id,
    required this.content,
    this.translation,
    this.startTime,
    this.endTime,
    this.words = const [],
    this.isHighlighted = false,
  });

  TextItem copyWith({
    String? id,
    String? content,
    String? translation,
    Duration? startTime,
    Duration? endTime,
    List<WordItem>? words,
    bool? isHighlighted,
  }) {
    return TextItem(
      id: id ?? this.id,
      content: content ?? this.content,
      translation: translation ?? this.translation,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      words: words ?? this.words,
      isHighlighted: isHighlighted ?? this.isHighlighted,
    );
  }
}

class WordItem {
  final String word;
  final DifficultyMark difficulty;
  final String? note;

  WordItem({
    required this.word,
    this.difficulty = DifficultyMark.none,
    this.note,
  });
}

enum DifficultyMark {
  none,
  easy,    // Dễ - 1x
  medium,  // Vừa - 3x
  hard,    // Khó - 5x
}

class TextDocument {
  final String id;
  final String title;
  final String? audioPath;
  final List<TextItem> lines;
  final DateTime createdAt;
  final DateTime updatedAt;

  TextDocument({
    required this.id,
    required this.title,
    this.audioPath,
    this.lines = const [],
    required this.createdAt,
    required this.updatedAt,
  });
}