// lib/models/text_item.dart
// in2up - Text Item Model
// Không chứa WordType (được chuyển sang word_analysis.dart)

class TextItem {
  final String id;
  final String content;
  final String? translation;
  final String? sourceLanguageCode;
  final String? translationLanguageCode;
  final Duration? startTime;
  final Duration? endTime;
  final List<WordItem> words;
  final bool isHighlighted;

  TextItem({
    required this.id,
    required this.content,
    this.translation,
    this.sourceLanguageCode,
    this.translationLanguageCode,
    this.startTime,
    this.endTime,
    this.words = const [],
    this.isHighlighted = false,
  });

  static const _unset = Object();

  TextItem copyWith({
    String? id,
    String? content,
    Object? translation = _unset,
    String? sourceLanguageCode,
    String? translationLanguageCode,
    Duration? startTime,
    Duration? endTime,
    List<WordItem>? words,
    bool? isHighlighted,
    bool clearTranslation = false,
    bool clearSourceLanguage = false,
  }) {
    String? newTranslation;
    if (clearTranslation) {
      newTranslation = null;
    } else if (translation == _unset) {
      newTranslation = this.translation;
    } else {
      newTranslation = translation as String?;
    }
    return TextItem(
      id: id ?? this.id,
      content: content ?? this.content,
      translation: newTranslation,
      sourceLanguageCode: clearSourceLanguage
          ? null
          : sourceLanguageCode ?? this.sourceLanguageCode,
      translationLanguageCode: clearTranslation
          ? null
          : translationLanguageCode ?? this.translationLanguageCode,
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
  easy, // Dễ - 1x
  medium, // Vừa - 3x
  hard, // Khó - 5x
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
