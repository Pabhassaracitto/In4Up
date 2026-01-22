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
  final WordType type;
  final DifficultyMark difficulty;
  final String? note;

  WordItem({
    required this.word,
    this.type = WordType.unknown,
    this.difficulty = DifficultyMark.none,
    this.note,
  });
}

enum WordType {
  noun,       // Danh từ - Xanh dương
  verb,       // Động từ - Đỏ
  adjective,  // Tính từ - Xanh lá
  adverb,     // Trạng từ - Cam
  preposition,// Giới từ - Tím
  determiner, // Mạo từ - Xám
  conjunction,// Liên từ - Nâu
  pronoun,    // Đại từ - Xanh ngọc
  unknown,    // Không xác định
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