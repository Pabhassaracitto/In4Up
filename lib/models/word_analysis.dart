// lib/models/word_analysis.dart
// VipSound - Word Analysis Models
// Hệ thống phân tích từ: Loại từ, Cấp độ CEFR, Độ khó

import 'package:flutter/material.dart';

// ============================================================================
// WORD TYPE - Loại từ (Tham khảo edward.io)
// ============================================================================

enum WordType {
  noun,        // Danh từ - Xanh dương
  verb,        // Động từ - Đỏ
  adjective,   // Tính từ - Xanh lá
  adverb,      // Trạng từ - Cam
  preposition, // Giới từ - Tím
  conjunction, // Liên từ - Nâu
  pronoun,     // Đại từ - Xanh ngọc
  determiner,  // Mạo từ/Từ hạn định - Xám
  interjection,// Thán từ - Hồng
  number,      // Số - Vàng đậm
  unknown,     // Chưa xác định - Trắng
}

extension WordTypeExtension on WordType {
  /// Màu sắc tương ứng với loại từ
  Color get color {
    switch (this) {
      case WordType.noun:
        return const Color(0xFF2196F3); // Blue
      case WordType.verb:
        return const Color(0xFFF44336); // Red
      case WordType.adjective:
        return const Color(0xFF4CAF50); // Green
      case WordType.adverb:
        return const Color(0xFFFF9800); // Orange
      case WordType.preposition:
        return const Color(0xFF9C27B0); // Purple
      case WordType.conjunction:
        return const Color(0xFF795548); // Brown
      case WordType.pronoun:
        return const Color(0xFF00BCD4); // Cyan
      case WordType.determiner:
        return const Color(0xFF607D8B); // Blue Grey
      case WordType.interjection:
        return const Color(0xFFE91E63); // Pink
      case WordType.number:
        return const Color(0xFFFFC107); // Amber
      case WordType.unknown:
        return const Color(0xFFFFFFFF); // White
    }
  }

  /// Màu nền nhạt
  Color get backgroundColor => color.withOpacity(0.15);

  /// Tên tiếng Việt
  String get labelVi {
    switch (this) {
      case WordType.noun:
        return 'Danh từ';
      case WordType.verb:
        return 'Động từ';
      case WordType.adjective:
        return 'Tính từ';
      case WordType.adverb:
        return 'Trạng từ';
      case WordType.preposition:
        return 'Giới từ';
      case WordType.conjunction:
        return 'Liên từ';
      case WordType.pronoun:
        return 'Đại từ';
      case WordType.determiner:
        return 'Mạo từ';
      case WordType.interjection:
        return 'Thán từ';
      case WordType.number:
        return 'Số';
      case WordType.unknown:
        return 'Khác';
    }
  }

  /// Viết tắt tiếng Anh
  String get abbreviation {
    switch (this) {
      case WordType.noun:
        return 'n';
      case WordType.verb:
        return 'v';
      case WordType.adjective:
        return 'adj';
      case WordType.adverb:
        return 'adv';
      case WordType.preposition:
        return 'prep';
      case WordType.conjunction:
        return 'conj';
      case WordType.pronoun:
        return 'pron';
      case WordType.determiner:
        return 'det';
      case WordType.interjection:
        return 'interj';
      case WordType.number:
        return 'num';
      case WordType.unknown:
        return '?';
    }
  }
}

// ============================================================================
// CEFR LEVEL - Cấp độ ngôn ngữ (Tham khảo Language Reactor)
// ============================================================================

enum CEFRLevel {
  a1,  // Beginner - Xanh nhạt nhất
  a2,  // Elementary - Xanh nhạt
  b1,  // Intermediate - Xanh đậm
  b2,  // Upper Intermediate - Vàng cam
  c1,  // Advanced - Cam đỏ
  c2,  // Proficiency - Đỏ đậm
  unknown, // Chưa xác định
}

extension CEFRLevelExtension on CEFRLevel {
  /// Màu sắc gradient từ dễ đến khó
  Color get color {
    switch (this) {
      case CEFRLevel.a1:
        return const Color(0xFF81D4FA); // Light Blue 200
      case CEFRLevel.a2:
        return const Color(0xFF4FC3F7); // Light Blue 300
      case CEFRLevel.b1:
        return const Color(0xFF29B6F6); // Light Blue 400
      case CEFRLevel.b2:
        return const Color(0xFFFFB74D); // Orange 300
      case CEFRLevel.c1:
        return const Color(0xFFFF8A65); // Deep Orange 300
      case CEFRLevel.c2:
        return const Color(0xFFE57373); // Red 300
      case CEFRLevel.unknown:
        return const Color(0xFFBDBDBD); // Grey 400
    }
  }

  /// Màu nền nhạt
  Color get backgroundColor => color.withOpacity(0.2);

  /// Tên đầy đủ
  String get label {
    switch (this) {
      case CEFRLevel.a1:
        return 'A1 - Beginner';
      case CEFRLevel.a2:
        return 'A2 - Elementary';
      case CEFRLevel.b1:
        return 'B1 - Intermediate';
      case CEFRLevel.b2:
        return 'B2 - Upper Intermediate';
      case CEFRLevel.c1:
        return 'C1 - Advanced';
      case CEFRLevel.c2:
        return 'C2 - Proficiency';
      case CEFRLevel.unknown:
        return 'Unknown';
    }
  }

  /// Tên ngắn
  String get shortLabel {
    switch (this) {
      case CEFRLevel.a1:
        return 'A1';
      case CEFRLevel.a2:
        return 'A2';
      case CEFRLevel.b1:
        return 'B1';
      case CEFRLevel.b2:
        return 'B2';
      case CEFRLevel.c1:
        return 'C1';
      case CEFRLevel.c2:
        return 'C2';
      case CEFRLevel.unknown:
        return '?';
    }
  }

  /// Mô tả tiếng Việt
  String get descriptionVi {
    switch (this) {
      case CEFRLevel.a1:
        return 'Mới bắt đầu';
      case CEFRLevel.a2:
        return 'Cơ bản';
      case CEFRLevel.b1:
        return 'Trung cấp';
      case CEFRLevel.b2:
        return 'Trung cấp cao';
      case CEFRLevel.c1:
        return 'Nâng cao';
      case CEFRLevel.c2:
        return 'Thành thạo';
      case CEFRLevel.unknown:
        return 'Chưa xác định';
    }
  }

  /// Số lần nên lặp khi học
  int get suggestedRepeatCount {
    switch (this) {
      case CEFRLevel.a1:
        return 1;
      case CEFRLevel.a2:
        return 1;
      case CEFRLevel.b1:
        return 2;
      case CEFRLevel.b2:
        return 3;
      case CEFRLevel.c1:
        return 4;
      case CEFRLevel.c2:
        return 5;
      case CEFRLevel.unknown:
        return 2;
    }
  }

  /// Tốc độ TTS gợi ý
  double get suggestedTtsSpeed {
    switch (this) {
      case CEFRLevel.a1:
        return 1.0;
      case CEFRLevel.a2:
        return 1.0;
      case CEFRLevel.b1:
        return 0.9;
      case CEFRLevel.b2:
        return 0.85;
      case CEFRLevel.c1:
        return 0.8;
      case CEFRLevel.c2:
        return 0.75;
      case CEFRLevel.unknown:
        return 0.9;
    }
  }
}

// ============================================================================
// DIFFICULTY LEVEL - Độ khó (cho người dùng tự đánh giá)
// ============================================================================

enum DifficultyLevel {
  known,    // Đã biết - Xanh lá đậm
  easy,     // Dễ - Xanh lá nhạt
  medium,   // Vừa - Vàng
  hard,     // Khó - Cam
  veryHard, // Rất khó - Đỏ
}

extension DifficultyLevelExtension on DifficultyLevel {
  Color get color {
    switch (this) {
      case DifficultyLevel.known:
        return const Color(0xFF2E7D32); // Green 800
      case DifficultyLevel.easy:
        return const Color(0xFF66BB6A); // Green 400
      case DifficultyLevel.medium:
        return const Color(0xFFFFCA28); // Amber 400
      case DifficultyLevel.hard:
        return const Color(0xFFFF7043); // Deep Orange 400
      case DifficultyLevel.veryHard:
        return const Color(0xFFE53935); // Red 600
    }
  }

  Color get backgroundColor => color.withOpacity(0.2);

  String get label {
    switch (this) {
      case DifficultyLevel.known:
        return 'Đã biết';
      case DifficultyLevel.easy:
        return 'Dễ';
      case DifficultyLevel.medium:
        return 'Vừa';
      case DifficultyLevel.hard:
        return 'Khó';
      case DifficultyLevel.veryHard:
        return 'Rất khó';
    }
  }

  int get repeatCount {
    switch (this) {
      case DifficultyLevel.known:
        return 0;
      case DifficultyLevel.easy:
        return 1;
      case DifficultyLevel.medium:
        return 3;
      case DifficultyLevel.hard:
        return 5;
      case DifficultyLevel.veryHard:
        return 7;
    }
  }

  double get ttsSpeed {
    switch (this) {
      case DifficultyLevel.known:
        return 1.0;
      case DifficultyLevel.easy:
        return 1.0;
      case DifficultyLevel.medium:
        return 0.9;
      case DifficultyLevel.hard:
        return 0.8;
      case DifficultyLevel.veryHard:
        return 0.7;
    }
  }
}

// ============================================================================
// ANALYZED WORD - Từ đã được phân tích
// ============================================================================

class AnalyzedWord {
  final String word;
  final String originalForm; // Dạng gốc (vd: "running" -> "run")
  final WordType wordType;
  final CEFRLevel cefrLevel;
  final DifficultyLevel? userDifficulty; // Người dùng tự đánh dấu
  final String? phonetic; // Phiên âm IPA
  final String? meaning; // Nghĩa tiếng Việt
  final List<String> examples; // Câu ví dụ
  final int frequency; // Tần suất xuất hiện (1-10000)

  AnalyzedWord({
    required this.word,
    String? originalForm,
    this.wordType = WordType.unknown,
    this.cefrLevel = CEFRLevel.unknown,
    this.userDifficulty,
    this.phonetic,
    this.meaning,
    this.examples = const [],
    this.frequency = 0,
  }) : originalForm = originalForm ?? word;

  /// Màu hiển thị dựa trên chế độ
  Color getColor(ColorMode mode) {
    switch (mode) {
      case ColorMode.wordType:
        return wordType.color;
      case ColorMode.cefrLevel:
        return cefrLevel.color;
      case ColorMode.difficulty:
        return userDifficulty?.color ?? Colors.white;
      case ColorMode.none:
        return Colors.white;
    }
  }

  /// Màu nền dựa trên chế độ
  Color getBackgroundColor(ColorMode mode) {
    switch (mode) {
      case ColorMode.wordType:
        return wordType.backgroundColor;
      case ColorMode.cefrLevel:
        return cefrLevel.backgroundColor;
      case ColorMode.difficulty:
        return userDifficulty?.backgroundColor ?? Colors.transparent;
      case ColorMode.none:
        return Colors.transparent;
    }
  }

  AnalyzedWord copyWith({
    String? word,
    String? originalForm,
    WordType? wordType,
    CEFRLevel? cefrLevel,
    DifficultyLevel? userDifficulty,
    String? phonetic,
    String? meaning,
    List<String>? examples,
    int? frequency,
  }) {
    return AnalyzedWord(
      word: word ?? this.word,
      originalForm: originalForm ?? this.originalForm,
      wordType: wordType ?? this.wordType,
      cefrLevel: cefrLevel ?? this.cefrLevel,
      userDifficulty: userDifficulty ?? this.userDifficulty,
      phonetic: phonetic ?? this.phonetic,
      meaning: meaning ?? this.meaning,
      examples: examples ?? this.examples,
      frequency: frequency ?? this.frequency,
    );
  }
}

// ============================================================================
// COLOR MODE - Chế độ hiển thị màu
// ============================================================================

enum ColorMode {
  none,      // Không tô màu
  wordType,  // Tô theo loại từ
  cefrLevel, // Tô theo cấp độ CEFR
  difficulty,// Tô theo độ khó (user defined)
}

extension ColorModeExtension on ColorMode {
  String get label {
    switch (this) {
      case ColorMode.none:
        return 'Không tô màu';
      case ColorMode.wordType:
        return 'Loại từ';
      case ColorMode.cefrLevel:
        return 'Cấp độ CEFR';
      case ColorMode.difficulty:
        return 'Độ khó';
    }
  }

  IconData get icon {
    switch (this) {
      case ColorMode.none:
        return Icons.format_color_reset;
      case ColorMode.wordType:
        return Icons.category;
      case ColorMode.cefrLevel:
        return Icons.signal_cellular_alt;
      case ColorMode.difficulty:
        return Icons.fitness_center;
    }
  }
}

// ============================================================================
// WORD DATABASE - Mock database cho từ vựng phổ biến
// ============================================================================

class WordDatabase {
  // Singleton
  static final WordDatabase _instance = WordDatabase._internal();
  factory WordDatabase() => _instance;
  WordDatabase._internal();

  // Mock data cho một số từ phổ biến
  static final Map<String, AnalyzedWord> _commonWords = {
    // A1 words - Determiner
    'the': AnalyzedWord(word: 'the', wordType: WordType.determiner, cefrLevel: CEFRLevel.a1),
    'a': AnalyzedWord(word: 'a', wordType: WordType.determiner, cefrLevel: CEFRLevel.a1),
    'an': AnalyzedWord(word: 'an', wordType: WordType.determiner, cefrLevel: CEFRLevel.a1),
    'this': AnalyzedWord(word: 'this', wordType: WordType.determiner, cefrLevel: CEFRLevel.a1),
    'that': AnalyzedWord(word: 'that', wordType: WordType.determiner, cefrLevel: CEFRLevel.a1),

    // A1 words - Pronoun
    'i': AnalyzedWord(word: 'i', wordType: WordType.pronoun, cefrLevel: CEFRLevel.a1),
    'you': AnalyzedWord(word: 'you', wordType: WordType.pronoun, cefrLevel: CEFRLevel.a1),
    'he': AnalyzedWord(word: 'he', wordType: WordType.pronoun, cefrLevel: CEFRLevel.a1),
    'she': AnalyzedWord(word: 'she', wordType: WordType.pronoun, cefrLevel: CEFRLevel.a1),
    'it': AnalyzedWord(word: 'it', wordType: WordType.pronoun, cefrLevel: CEFRLevel.a1),
    'we': AnalyzedWord(word: 'we', wordType: WordType.pronoun, cefrLevel: CEFRLevel.a1),
    'they': AnalyzedWord(word: 'they', wordType: WordType.pronoun, cefrLevel: CEFRLevel.a1),

    // A1 words - Verb
    'is': AnalyzedWord(word: 'is', originalForm: 'be', wordType: WordType.verb, cefrLevel: CEFRLevel.a1),
    'am': AnalyzedWord(word: 'am', originalForm: 'be', wordType: WordType.verb, cefrLevel: CEFRLevel.a1),
    'are': AnalyzedWord(word: 'are', originalForm: 'be', wordType: WordType.verb, cefrLevel: CEFRLevel.a1),
    'was': AnalyzedWord(word: 'was', originalForm: 'be', wordType: WordType.verb, cefrLevel: CEFRLevel.a1),
    'were': AnalyzedWord(word: 'were', originalForm: 'be', wordType: WordType.verb, cefrLevel: CEFRLevel.a1),
    'be': AnalyzedWord(word: 'be', wordType: WordType.verb, cefrLevel: CEFRLevel.a1),
    'have': AnalyzedWord(word: 'have', wordType: WordType.verb, cefrLevel: CEFRLevel.a1),
    'has': AnalyzedWord(word: 'has', originalForm: 'have', wordType: WordType.verb, cefrLevel: CEFRLevel.a1),
    'had': AnalyzedWord(word: 'had', originalForm: 'have', wordType: WordType.verb, cefrLevel: CEFRLevel.a1),
    'do': AnalyzedWord(word: 'do', wordType: WordType.verb, cefrLevel: CEFRLevel.a1),
    'does': AnalyzedWord(word: 'does', originalForm: 'do', wordType: WordType.verb, cefrLevel: CEFRLevel.a1),
    'did': AnalyzedWord(word: 'did', originalForm: 'do', wordType: WordType.verb, cefrLevel: CEFRLevel.a1),
    'go': AnalyzedWord(word: 'go', wordType: WordType.verb, cefrLevel: CEFRLevel.a1),
    'come': AnalyzedWord(word: 'come', wordType: WordType.verb, cefrLevel: CEFRLevel.a1),
    'see': AnalyzedWord(word: 'see', wordType: WordType.verb, cefrLevel: CEFRLevel.a1),
    'know': AnalyzedWord(word: 'know', wordType: WordType.verb, cefrLevel: CEFRLevel.a1),
    'get': AnalyzedWord(word: 'get', wordType: WordType.verb, cefrLevel: CEFRLevel.a1),
    'make': AnalyzedWord(word: 'make', wordType: WordType.verb, cefrLevel: CEFRLevel.a1),
    'say': AnalyzedWord(word: 'say', wordType: WordType.verb, cefrLevel: CEFRLevel.a1),
    'think': AnalyzedWord(word: 'think', wordType: WordType.verb, cefrLevel: CEFRLevel.a1),
    'take': AnalyzedWord(word: 'take', wordType: WordType.verb, cefrLevel: CEFRLevel.a1),
    'want': AnalyzedWord(word: 'want', wordType: WordType.verb, cefrLevel: CEFRLevel.a1),
    'like': AnalyzedWord(word: 'like', wordType: WordType.verb, cefrLevel: CEFRLevel.a1),
    'use': AnalyzedWord(word: 'use', wordType: WordType.verb, cefrLevel: CEFRLevel.a1),
    'find': AnalyzedWord(word: 'find', wordType: WordType.verb, cefrLevel: CEFRLevel.a1),
    'give': AnalyzedWord(word: 'give', wordType: WordType.verb, cefrLevel: CEFRLevel.a1),
    'tell': AnalyzedWord(word: 'tell', wordType: WordType.verb, cefrLevel: CEFRLevel.a1),
    'work': AnalyzedWord(word: 'work', wordType: WordType.verb, cefrLevel: CEFRLevel.a1),
    'call': AnalyzedWord(word: 'call', wordType: WordType.verb, cefrLevel: CEFRLevel.a1),
    'try': AnalyzedWord(word: 'try', wordType: WordType.verb, cefrLevel: CEFRLevel.a1),
    'ask': AnalyzedWord(word: 'ask', wordType: WordType.verb, cefrLevel: CEFRLevel.a1),
    'need': AnalyzedWord(word: 'need', wordType: WordType.verb, cefrLevel: CEFRLevel.a1),
    'feel': AnalyzedWord(word: 'feel', wordType: WordType.verb, cefrLevel: CEFRLevel.a1),
    'become': AnalyzedWord(word: 'become', wordType: WordType.verb, cefrLevel: CEFRLevel.a2),
    'leave': AnalyzedWord(word: 'leave', wordType: WordType.verb, cefrLevel: CEFRLevel.a2),
    'put': AnalyzedWord(word: 'put', wordType: WordType.verb, cefrLevel: CEFRLevel.a1),
    'mean': AnalyzedWord(word: 'mean', wordType: WordType.verb, cefrLevel: CEFRLevel.a2),
    'keep': AnalyzedWord(word: 'keep', wordType: WordType.verb, cefrLevel: CEFRLevel.a2),
    'let': AnalyzedWord(word: 'let', wordType: WordType.verb, cefrLevel: CEFRLevel.a2),
    'begin': AnalyzedWord(word: 'begin', wordType: WordType.verb, cefrLevel: CEFRLevel.a2),
    'seem': AnalyzedWord(word: 'seem', wordType: WordType.verb, cefrLevel: CEFRLevel.a2),
    'help': AnalyzedWord(word: 'help', wordType: WordType.verb, cefrLevel: CEFRLevel.a1),
    'show': AnalyzedWord(word: 'show', wordType: WordType.verb, cefrLevel: CEFRLevel.a2),
    'hear': AnalyzedWord(word: 'hear', wordType: WordType.verb, cefrLevel: CEFRLevel.a1),
    'play': AnalyzedWord(word: 'play', wordType: WordType.verb, cefrLevel: CEFRLevel.a1),
    'run': AnalyzedWord(word: 'run', wordType: WordType.verb, cefrLevel: CEFRLevel.a1),
    'move': AnalyzedWord(word: 'move', wordType: WordType.verb, cefrLevel: CEFRLevel.a2),
    'live': AnalyzedWord(word: 'live', wordType: WordType.verb, cefrLevel: CEFRLevel.a1),
    'believe': AnalyzedWord(word: 'believe', wordType: WordType.verb, cefrLevel: CEFRLevel.a2),

    // A1-A2 words - Noun
    'time': AnalyzedWord(word: 'time', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),
    'year': AnalyzedWord(word: 'year', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),
    'people': AnalyzedWord(word: 'people', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),
    'way': AnalyzedWord(word: 'way', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),
    'day': AnalyzedWord(word: 'day', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),
    'man': AnalyzedWord(word: 'man', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),
    'woman': AnalyzedWord(word: 'woman', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),
    'child': AnalyzedWord(word: 'child', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),
    'world': AnalyzedWord(word: 'world', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),
    'life': AnalyzedWord(word: 'life', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),
    'hand': AnalyzedWord(word: 'hand', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),
    'part': AnalyzedWord(word: 'part', wordType: WordType.noun, cefrLevel: CEFRLevel.a2),
    'place': AnalyzedWord(word: 'place', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),
    'case': AnalyzedWord(word: 'case', wordType: WordType.noun, cefrLevel: CEFRLevel.b1),
    'week': AnalyzedWord(word: 'week', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),
    'company': AnalyzedWord(word: 'company', wordType: WordType.noun, cefrLevel: CEFRLevel.a2),
    'system': AnalyzedWord(word: 'system', wordType: WordType.noun, cefrLevel: CEFRLevel.b1),
    'program': AnalyzedWord(word: 'program', wordType: WordType.noun, cefrLevel: CEFRLevel.a2),
    'question': AnalyzedWord(word: 'question', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),
    'government': AnalyzedWord(word: 'government', wordType: WordType.noun, cefrLevel: CEFRLevel.b1),
    'number': AnalyzedWord(word: 'number', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),
    'night': AnalyzedWord(word: 'night', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),
    'point': AnalyzedWord(word: 'point', wordType: WordType.noun, cefrLevel: CEFRLevel.a2),
    'home': AnalyzedWord(word: 'home', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),
    'water': AnalyzedWord(word: 'water', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),
    'room': AnalyzedWord(word: 'room', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),
    'mother': AnalyzedWord(word: 'mother', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),
    'father': AnalyzedWord(word: 'father', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),
    'area': AnalyzedWord(word: 'area', wordType: WordType.noun, cefrLevel: CEFRLevel.a2),
    'money': AnalyzedWord(word: 'money', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),
    'story': AnalyzedWord(word: 'story', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),
    'fact': AnalyzedWord(word: 'fact', wordType: WordType.noun, cefrLevel: CEFRLevel.a2),
    'month': AnalyzedWord(word: 'month', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),
    'lot': AnalyzedWord(word: 'lot', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),
    'right': AnalyzedWord(word: 'right', wordType: WordType.noun, cefrLevel: CEFRLevel.a2),
    'study': AnalyzedWord(word: 'study', wordType: WordType.noun, cefrLevel: CEFRLevel.a2),
    'book': AnalyzedWord(word: 'book', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),
    'eye': AnalyzedWord(word: 'eye', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),
    'job': AnalyzedWord(word: 'job', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),
    'word': AnalyzedWord(word: 'word', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),
    'business': AnalyzedWord(word: 'business', wordType: WordType.noun, cefrLevel: CEFRLevel.a2),
    'issue': AnalyzedWord(word: 'issue', wordType: WordType.noun, cefrLevel: CEFRLevel.b1),
    'side': AnalyzedWord(word: 'side', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),
    'kind': AnalyzedWord(word: 'kind', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),
    'head': AnalyzedWord(word: 'head', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),
    'house': AnalyzedWord(word: 'house', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),
    'service': AnalyzedWord(word: 'service', wordType: WordType.noun, cefrLevel: CEFRLevel.a2),
    'friend': AnalyzedWord(word: 'friend', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),
    'power': AnalyzedWord(word: 'power', wordType: WordType.noun, cefrLevel: CEFRLevel.b1),
    'hour': AnalyzedWord(word: 'hour', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),
    'game': AnalyzedWord(word: 'game', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),
    'line': AnalyzedWord(word: 'line', wordType: WordType.noun, cefrLevel: CEFRLevel.a2),
    'end': AnalyzedWord(word: 'end', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),
    'member': AnalyzedWord(word: 'member', wordType: WordType.noun, cefrLevel: CEFRLevel.a2),
    'law': AnalyzedWord(word: 'law', wordType: WordType.noun, cefrLevel: CEFRLevel.b1),
    'car': AnalyzedWord(word: 'car', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),
    'city': AnalyzedWord(word: 'city', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),
    'community': AnalyzedWord(word: 'community', wordType: WordType.noun, cefrLevel: CEFRLevel.b1),
    'name': AnalyzedWord(word: 'name', wordType: WordType.noun, cefrLevel: CEFRLevel.a1),

    // A1-A2 words - Adjective
    'good': AnalyzedWord(word: 'good', wordType: WordType.adjective, cefrLevel: CEFRLevel.a1),
    'new': AnalyzedWord(word: 'new', wordType: WordType.adjective, cefrLevel: CEFRLevel.a1),
    'first': AnalyzedWord(word: 'first', wordType: WordType.adjective, cefrLevel: CEFRLevel.a1),
    'last': AnalyzedWord(word: 'last', wordType: WordType.adjective, cefrLevel: CEFRLevel.a1),
    'long': AnalyzedWord(word: 'long', wordType: WordType.adjective, cefrLevel: CEFRLevel.a1),
    'great': AnalyzedWord(word: 'great', wordType: WordType.adjective, cefrLevel: CEFRLevel.a1),
    'little': AnalyzedWord(word: 'little', wordType: WordType.adjective, cefrLevel: CEFRLevel.a1),
    'own': AnalyzedWord(word: 'own', wordType: WordType.adjective, cefrLevel: CEFRLevel.a2),
    'other': AnalyzedWord(word: 'other', wordType: WordType.adjective, cefrLevel: CEFRLevel.a1),
    'old': AnalyzedWord(word: 'old', wordType: WordType.adjective, cefrLevel: CEFRLevel.a1),
    'right': AnalyzedWord(word: 'right', wordType: WordType.adjective, cefrLevel: CEFRLevel.a1),
    'big': AnalyzedWord(word: 'big', wordType: WordType.adjective, cefrLevel: CEFRLevel.a1),
    'high': AnalyzedWord(word: 'high', wordType: WordType.adjective, cefrLevel: CEFRLevel.a1),
    'different': AnalyzedWord(word: 'different', wordType: WordType.adjective, cefrLevel: CEFRLevel.a2),
    'small': AnalyzedWord(word: 'small', wordType: WordType.adjective, cefrLevel: CEFRLevel.a1),
    'large': AnalyzedWord(word: 'large', wordType: WordType.adjective, cefrLevel: CEFRLevel.a1),
    'next': AnalyzedWord(word: 'next', wordType: WordType.adjective, cefrLevel: CEFRLevel.a1),
    'early': AnalyzedWord(word: 'early', wordType: WordType.adjective, cefrLevel: CEFRLevel.a1),
    'young': AnalyzedWord(word: 'young', wordType: WordType.adjective, cefrLevel: CEFRLevel.a1),
    'important': AnalyzedWord(word: 'important', wordType: WordType.adjective, cefrLevel: CEFRLevel.a2),
    'few': AnalyzedWord(word: 'few', wordType: WordType.adjective, cefrLevel: CEFRLevel.a2),
    'public': AnalyzedWord(word: 'public', wordType: WordType.adjective, cefrLevel: CEFRLevel.b1),
    'bad': AnalyzedWord(word: 'bad', wordType: WordType.adjective, cefrLevel: CEFRLevel.a1),
    'same': AnalyzedWord(word: 'same', wordType: WordType.adjective, cefrLevel: CEFRLevel.a1),
    'able': AnalyzedWord(word: 'able', wordType: WordType.adjective, cefrLevel: CEFRLevel.a2),
    'beautiful': AnalyzedWord(word: 'beautiful', wordType: WordType.adjective, cefrLevel: CEFRLevel.a1),
    'happy': AnalyzedWord(word: 'happy', wordType: WordType.adjective, cefrLevel: CEFRLevel.a1),
    'sad': AnalyzedWord(word: 'sad', wordType: WordType.adjective, cefrLevel: CEFRLevel.a1),
    'hot': AnalyzedWord(word: 'hot', wordType: WordType.adjective, cefrLevel: CEFRLevel.a1),
    'cold': AnalyzedWord(word: 'cold', wordType: WordType.adjective, cefrLevel: CEFRLevel.a1),
    'easy': AnalyzedWord(word: 'easy', wordType: WordType.adjective, cefrLevel: CEFRLevel.a1),
    'hard': AnalyzedWord(word: 'hard', wordType: WordType.adjective, cefrLevel: CEFRLevel.a1),
    'fast': AnalyzedWord(word: 'fast', wordType: WordType.adjective, cefrLevel: CEFRLevel.a1),
    'slow': AnalyzedWord(word: 'slow', wordType: WordType.adjective, cefrLevel: CEFRLevel.a1),

    // A1-A2 words - Adverb
    'not': AnalyzedWord(word: 'not', wordType: WordType.adverb, cefrLevel: CEFRLevel.a1),
    'also': AnalyzedWord(word: 'also', wordType: WordType.adverb, cefrLevel: CEFRLevel.a1),
    'very': AnalyzedWord(word: 'very', wordType: WordType.adverb, cefrLevel: CEFRLevel.a1),
    'just': AnalyzedWord(word: 'just', wordType: WordType.adverb, cefrLevel: CEFRLevel.a1),
    'now': AnalyzedWord(word: 'now', wordType: WordType.adverb, cefrLevel: CEFRLevel.a1),
    'then': AnalyzedWord(word: 'then', wordType: WordType.adverb, cefrLevel: CEFRLevel.a1),
    'more': AnalyzedWord(word: 'more', wordType: WordType.adverb, cefrLevel: CEFRLevel.a1),
    'here': AnalyzedWord(word: 'here', wordType: WordType.adverb, cefrLevel: CEFRLevel.a1),
    'there': AnalyzedWord(word: 'there', wordType: WordType.adverb, cefrLevel: CEFRLevel.a1),
    'well': AnalyzedWord(word: 'well', wordType: WordType.adverb, cefrLevel: CEFRLevel.a1),
    'only': AnalyzedWord(word: 'only', wordType: WordType.adverb, cefrLevel: CEFRLevel.a1),
    'even': AnalyzedWord(word: 'even', wordType: WordType.adverb, cefrLevel: CEFRLevel.a2),
    'back': AnalyzedWord(word: 'back', wordType: WordType.adverb, cefrLevel: CEFRLevel.a1),
    'still': AnalyzedWord(word: 'still', wordType: WordType.adverb, cefrLevel: CEFRLevel.a2),
    'never': AnalyzedWord(word: 'never', wordType: WordType.adverb, cefrLevel: CEFRLevel.a1),
    'always': AnalyzedWord(word: 'always', wordType: WordType.adverb, cefrLevel: CEFRLevel.a1),
    'often': AnalyzedWord(word: 'often', wordType: WordType.adverb, cefrLevel: CEFRLevel.a1),
    'sometimes': AnalyzedWord(word: 'sometimes', wordType: WordType.adverb, cefrLevel: CEFRLevel.a1),
    'usually': AnalyzedWord(word: 'usually', wordType: WordType.adverb, cefrLevel: CEFRLevel.a1),
    'really': AnalyzedWord(word: 'really', wordType: WordType.adverb, cefrLevel: CEFRLevel.a1),
    'already': AnalyzedWord(word: 'already', wordType: WordType.adverb, cefrLevel: CEFRLevel.a2),
    'again': AnalyzedWord(word: 'again', wordType: WordType.adverb, cefrLevel: CEFRLevel.a1),
    'too': AnalyzedWord(word: 'too', wordType: WordType.adverb, cefrLevel: CEFRLevel.a1),
    'almost': AnalyzedWord(word: 'almost', wordType: WordType.adverb, cefrLevel: CEFRLevel.a2),
    'quickly': AnalyzedWord(word: 'quickly', wordType: WordType.adverb, cefrLevel: CEFRLevel.a2),
    'slowly': AnalyzedWord(word: 'slowly', wordType: WordType.adverb, cefrLevel: CEFRLevel.a2),

    // A1-A2 words - Preposition
    'to': AnalyzedWord(word: 'to', wordType: WordType.preposition, cefrLevel: CEFRLevel.a1),
    'of': AnalyzedWord(word: 'of', wordType: WordType.preposition, cefrLevel: CEFRLevel.a1),
    'in': AnalyzedWord(word: 'in', wordType: WordType.preposition, cefrLevel: CEFRLevel.a1),
    'for': AnalyzedWord(word: 'for', wordType: WordType.preposition, cefrLevel: CEFRLevel.a1),
    'on': AnalyzedWord(word: 'on', wordType: WordType.preposition, cefrLevel: CEFRLevel.a1),
    'with': AnalyzedWord(word: 'with', wordType: WordType.preposition, cefrLevel: CEFRLevel.a1),
    'at': AnalyzedWord(word: 'at', wordType: WordType.preposition, cefrLevel: CEFRLevel.a1),
    'by': AnalyzedWord(word: 'by', wordType: WordType.preposition, cefrLevel: CEFRLevel.a1),
    'from': AnalyzedWord(word: 'from', wordType: WordType.preposition, cefrLevel: CEFRLevel.a1),
    'about': AnalyzedWord(word: 'about', wordType: WordType.preposition, cefrLevel: CEFRLevel.a1),
    'into': AnalyzedWord(word: 'into', wordType: WordType.preposition, cefrLevel: CEFRLevel.a1),
    'over': AnalyzedWord(word: 'over', wordType: WordType.preposition, cefrLevel: CEFRLevel.a1),
    'after': AnalyzedWord(word: 'after', wordType: WordType.preposition, cefrLevel: CEFRLevel.a1),
    'before': AnalyzedWord(word: 'before', wordType: WordType.preposition, cefrLevel: CEFRLevel.a1),
    'between': AnalyzedWord(word: 'between', wordType: WordType.preposition, cefrLevel: CEFRLevel.a2),
    'under': AnalyzedWord(word: 'under', wordType: WordType.preposition, cefrLevel: CEFRLevel.a1),
    'through': AnalyzedWord(word: 'through', wordType: WordType.preposition, cefrLevel: CEFRLevel.a2),
    'during': AnalyzedWord(word: 'during', wordType: WordType.preposition, cefrLevel: CEFRLevel.a2),
    'without': AnalyzedWord(word: 'without', wordType: WordType.preposition, cefrLevel: CEFRLevel.a2),
    'against': AnalyzedWord(word: 'against', wordType: WordType.preposition, cefrLevel: CEFRLevel.b1),
    'within': AnalyzedWord(word: 'within', wordType: WordType.preposition, cefrLevel: CEFRLevel.b1),

    // A1-A2 words - Conjunction
    'and': AnalyzedWord(word: 'and', wordType: WordType.conjunction, cefrLevel: CEFRLevel.a1),
    'but': AnalyzedWord(word: 'but', wordType: WordType.conjunction, cefrLevel: CEFRLevel.a1),
    'or': AnalyzedWord(word: 'or', wordType: WordType.conjunction, cefrLevel: CEFRLevel.a1),
    'if': AnalyzedWord(word: 'if', wordType: WordType.conjunction, cefrLevel: CEFRLevel.a1),
    'because': AnalyzedWord(word: 'because', wordType: WordType.conjunction, cefrLevel: CEFRLevel.a1),
    'when': AnalyzedWord(word: 'when', wordType: WordType.conjunction, cefrLevel: CEFRLevel.a1),
    'while': AnalyzedWord(word: 'while', wordType: WordType.conjunction, cefrLevel: CEFRLevel.a2),
    'although': AnalyzedWord(word: 'although', wordType: WordType.conjunction, cefrLevel: CEFRLevel.b1),
    'so': AnalyzedWord(word: 'so', wordType: WordType.conjunction, cefrLevel: CEFRLevel.a1),
    'than': AnalyzedWord(word: 'than', wordType: WordType.conjunction, cefrLevel: CEFRLevel.a1),
    'however': AnalyzedWord(word: 'however', wordType: WordType.conjunction, cefrLevel: CEFRLevel.b1),
    'whether': AnalyzedWord(word: 'whether', wordType: WordType.conjunction, cefrLevel: CEFRLevel.b1),

    // B1-B2 words
    'however': AnalyzedWord(word: 'however', wordType: WordType.adverb, cefrLevel: CEFRLevel.b1),
    'although': AnalyzedWord(word: 'although', wordType: WordType.conjunction, cefrLevel: CEFRLevel.b1),
    'therefore': AnalyzedWord(word: 'therefore', wordType: WordType.adverb, cefrLevel: CEFRLevel.b1),
    'significant': AnalyzedWord(word: 'significant', wordType: WordType.adjective, cefrLevel: CEFRLevel.b1),
    'particularly': AnalyzedWord(word: 'particularly', wordType: WordType.adverb, cefrLevel: CEFRLevel.b1),
    'according': AnalyzedWord(word: 'according', wordType: WordType.preposition, cefrLevel: CEFRLevel.b1),
    'available': AnalyzedWord(word: 'available', wordType: WordType.adjective, cefrLevel: CEFRLevel.b1),
    'especially': AnalyzedWord(word: 'especially', wordType: WordType.adverb, cefrLevel: CEFRLevel.b1),
    'international': AnalyzedWord(word: 'international', wordType: WordType.adjective, cefrLevel: CEFRLevel.b1),
    'development': AnalyzedWord(word: 'development', wordType: WordType.noun, cefrLevel: CEFRLevel.b1),
    'economic': AnalyzedWord(word: 'economic', wordType: WordType.adjective, cefrLevel: CEFRLevel.b1),
    'environment': AnalyzedWord(word: 'environment', wordType: WordType.noun, cefrLevel: CEFRLevel.b1),
    'individual': AnalyzedWord(word: 'individual', wordType: WordType.noun, cefrLevel: CEFRLevel.b1),
    'policy': AnalyzedWord(word: 'policy', wordType: WordType.noun, cefrLevel: CEFRLevel.b1),
    'research': AnalyzedWord(word: 'research', wordType: WordType.noun, cefrLevel: CEFRLevel.b1),
    'analysis': AnalyzedWord(word: 'analysis', wordType: WordType.noun, cefrLevel: CEFRLevel.b2),
    'approach': AnalyzedWord(word: 'approach', wordType: WordType.noun, cefrLevel: CEFRLevel.b2),
    'benefit': AnalyzedWord(word: 'benefit', wordType: WordType.noun, cefrLevel: CEFRLevel.b1),
    'concept': AnalyzedWord(word: 'concept', wordType: WordType.noun, cefrLevel: CEFRLevel.b2),
    'context': AnalyzedWord(word: 'context', wordType: WordType.noun, cefrLevel: CEFRLevel.b2),
    'create': AnalyzedWord(word: 'create', wordType: WordType.verb, cefrLevel: CEFRLevel.a2),
    'definition': AnalyzedWord(word: 'definition', wordType: WordType.noun, cefrLevel: CEFRLevel.b1),
    'derive': AnalyzedWord(word: 'derive', wordType: WordType.verb, cefrLevel: CEFRLevel.b2),
    'establish': AnalyzedWord(word: 'establish', wordType: WordType.verb, cefrLevel: CEFRLevel.b1),
    'estimate': AnalyzedWord(word: 'estimate', wordType: WordType.verb, cefrLevel: CEFRLevel.b1),
    'evidence': AnalyzedWord(word: 'evidence', wordType: WordType.noun, cefrLevel: CEFRLevel.b1),
    'factor': AnalyzedWord(word: 'factor', wordType: WordType.noun, cefrLevel: CEFRLevel.b1),

    // C1-C2 words
    'notwithstanding': AnalyzedWord(word: 'notwithstanding', wordType: WordType.preposition, cefrLevel: CEFRLevel.c1),
    'hitherto': AnalyzedWord(word: 'hitherto', wordType: WordType.adverb, cefrLevel: CEFRLevel.c2),
    'albeit': AnalyzedWord(word: 'albeit', wordType: WordType.conjunction, cefrLevel: CEFRLevel.c1),
    'whereby': AnalyzedWord(word: 'whereby', wordType: WordType.adverb, cefrLevel: CEFRLevel.c1),
    'nonetheless': AnalyzedWord(word: 'nonetheless', wordType: WordType.adverb, cefrLevel: CEFRLevel.c1),
    'furthermore': AnalyzedWord(word: 'furthermore', wordType: WordType.adverb, cefrLevel: CEFRLevel.b2),
    'subsequently': AnalyzedWord(word: 'subsequently', wordType: WordType.adverb, cefrLevel: CEFRLevel.c1),
    'predominantly': AnalyzedWord(word: 'predominantly', wordType: WordType.adverb, cefrLevel: CEFRLevel.c1),
    'inherent': AnalyzedWord(word: 'inherent', wordType: WordType.adjective, cefrLevel: CEFRLevel.c1),
    'paradigm': AnalyzedWord(word: 'paradigm', wordType: WordType.noun, cefrLevel: CEFRLevel.c1),
    'pragmatic': AnalyzedWord(word: 'pragmatic', wordType: WordType.adjective, cefrLevel: CEFRLevel.c1),
    'comprehensive': AnalyzedWord(word: 'comprehensive', wordType: WordType.adjective, cefrLevel: CEFRLevel.b2),
    'constitute': AnalyzedWord(word: 'constitute', wordType: WordType.verb, cefrLevel: CEFRLevel.c1),
    'facilitate': AnalyzedWord(word: 'facilitate', wordType: WordType.verb, cefrLevel: CEFRLevel.c1),
    'implication': AnalyzedWord(word: 'implication', wordType: WordType.noun, cefrLevel: CEFRLevel.b2),
    'integrate': AnalyzedWord(word: 'integrate', wordType: WordType.verb, cefrLevel: CEFRLevel.b2),
    'outcome': AnalyzedWord(word: 'outcome', wordType: WordType.noun, cefrLevel: CEFRLevel.b2),
    'perspective': AnalyzedWord(word: 'perspective', wordType: WordType.noun, cefrLevel: CEFRLevel.b2),
    'potential': AnalyzedWord(word: 'potential', wordType: WordType.noun, cefrLevel: CEFRLevel.b1),
    'prior': AnalyzedWord(word: 'prior', wordType: WordType.adjective, cefrLevel: CEFRLevel.b2),
    'pursue': AnalyzedWord(word: 'pursue', wordType: WordType.verb, cefrLevel: CEFRLevel.b2),
    'require': AnalyzedWord(word: 'require', wordType: WordType.verb, cefrLevel: CEFRLevel.b1),
    'restrict': AnalyzedWord(word: 'restrict', wordType: WordType.verb, cefrLevel: CEFRLevel.b2),
    'strategy': AnalyzedWord(word: 'strategy', wordType: WordType.noun, cefrLevel: CEFRLevel.b2),
    'structure': AnalyzedWord(word: 'structure', wordType: WordType.noun, cefrLevel: CEFRLevel.b1),
    'sufficient': AnalyzedWord(word: 'sufficient', wordType: WordType.adjective, cefrLevel: CEFRLevel.b2),
    'theory': AnalyzedWord(word: 'theory', wordType: WordType.noun, cefrLevel: CEFRLevel.b1),

    // Buddhism terms
    'buddha': AnalyzedWord(word: 'buddha', wordType: WordType.noun, cefrLevel: CEFRLevel.b1, meaning: 'Đức Phật'),
    'dharma': AnalyzedWord(word: 'dharma', wordType: WordType.noun, cefrLevel: CEFRLevel.c1, meaning: 'Pháp'),
    'sangha': AnalyzedWord(word: 'sangha', wordType: WordType.noun, cefrLevel: CEFRLevel.c1, meaning: 'Tăng đoàn'),
    'karma': AnalyzedWord(word: 'karma', wordType: WordType.noun, cefrLevel: CEFRLevel.b2, meaning: 'Nghiệp'),
    'nirvana': AnalyzedWord(word: 'nirvana', wordType: WordType.noun, cefrLevel: CEFRLevel.c1, meaning: 'Niết bàn'),
    'samsara': AnalyzedWord(word: 'samsara', wordType: WordType.noun, cefrLevel: CEFRLevel.c2, meaning: 'Luân hồi'),
    'sutra': AnalyzedWord(word: 'sutra', wordType: WordType.noun, cefrLevel: CEFRLevel.c1, meaning: 'Kinh'),
    'meditation': AnalyzedWord(word: 'meditation', wordType: WordType.noun, cefrLevel: CEFRLevel.b1, meaning: 'Thiền định'),
    'enlightenment': AnalyzedWord(word: 'enlightenment', wordType: WordType.noun, cefrLevel: CEFRLevel.b2, meaning: 'Giác ngộ'),
    'suffering': AnalyzedWord(word: 'suffering', wordType: WordType.noun, cefrLevel: CEFRLevel.b1, meaning: 'Khổ đau'),
    'compassion': AnalyzedWord(word: 'compassion', wordType: WordType.noun, cefrLevel: CEFRLevel.b2, meaning: 'Từ bi'),
    'mindfulness': AnalyzedWord(word: 'mindfulness', wordType: WordType.noun, cefrLevel: CEFRLevel.b2, meaning: 'Chánh niệm'),
    'impermanence': AnalyzedWord(word: 'impermanence', wordType: WordType.noun, cefrLevel: CEFRLevel.c1, meaning: 'Vô thường'),
    'attachment': AnalyzedWord(word: 'attachment', wordType: WordType.noun, cefrLevel: CEFRLevel.b2, meaning: 'Chấp trước'),
    'wisdom': AnalyzedWord(word: 'wisdom', wordType: WordType.noun, cefrLevel: CEFRLevel.b1, meaning: 'Trí tuệ'),
  };

  /// Phân tích một từ
  AnalyzedWord analyze(String word) {
    final lowerWord = word.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
    return _commonWords[lowerWord] ?? AnalyzedWord(word: word);
  }

  /// Phân tích một câu
  List<AnalyzedWord> analyzeSentence(String sentence) {
    final words = sentence.split(RegExp(r'\s+'));
    return words.map((w) {
      final clean = w.replaceAll(RegExp(r'[^\w]'), '');
      final analyzed = analyze(clean);
      // Giữ nguyên dấu câu
      return analyzed.copyWith(word: w);
    }).toList();
  }
}