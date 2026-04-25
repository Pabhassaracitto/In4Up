// lib/models/word_analysis.dart
import 'package:flutter/material.dart';
import 'package:vipsound_core/vocab_level_difficulty.dart';

import 'color_mode.dart';

// ===== WORD TYPE ENUM =====
enum WordType {
  noun,
  verb,
  adjective,
  adverb,
  preposition,
  conjunction,
  pronoun,
  determiner,
  interjection,
  number,
  punctuation,
  unknown;

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
      case WordType.punctuation:
        return 'Dấu câu';
      case WordType.unknown:
        return 'Khác';
    }
  }

  Color get color {
    switch (this) {
      case WordType.noun:
        return const Color(0xFF42A5F5);
      case WordType.verb:
        return const Color(0xFFEF5350);
      case WordType.adjective:
        return const Color(0xFF66BB6A);
      case WordType.adverb:
        return const Color(0xFFFFCA28);
      case WordType.preposition:
        return const Color(0xFFAB47BC);
      case WordType.conjunction:
        return const Color(0xFF26C6DA);
      case WordType.pronoun:
        return const Color(0xFFFF7043);
      case WordType.determiner:
        return const Color(0xFF78909C);
      case WordType.interjection:
        return const Color(0xFFEC407A);
      case WordType.number:
        return const Color(0xFF8D6E63);
      case WordType.punctuation:
        return const Color(0xFF546E7A);
      case WordType.unknown:
        return const Color(0xFF9E9E9E);
    }
  }
}

// ===== CEFR LEVEL ENUM =====
enum CEFRLevel {
  a1,
  a2,
  b1,
  b2,
  c1,
  c2,
  unknown;

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

  String get fullLabel {
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

  Color get color {
    switch (this) {
      case CEFRLevel.a1:
        return const Color(0xFF78909C); // Grey
      case CEFRLevel.a2:
        return const Color(0xFF42A5F5); // Blue
      case CEFRLevel.b1:
        return const Color(0xFF66BB6A); // Green
      case CEFRLevel.b2:
        return const Color(0xFFFFCA28); // Yellow
      case CEFRLevel.c1:
        return const Color(0xFFFF7043); // Orange
      case CEFRLevel.c2:
        return const Color(0xFFEF5350); // Red
      case CEFRLevel.unknown:
        return Colors.grey;
    }
  }
}

// ===== EXTENSIONS =====
extension WordTypeExtra on WordType {
  String get abbreviation {
    switch (this) {
      case WordType.noun:
        return 'N';
      case WordType.verb:
        return 'V';
      case WordType.adjective:
        return 'Adj';
      case WordType.adverb:
        return 'Adv';
      case WordType.preposition:
        return 'Prep';
      case WordType.conjunction:
        return 'Conj';
      case WordType.pronoun:
        return 'Pro';
      case WordType.determiner:
        return 'Det';
      case WordType.interjection:
        return 'Int';
      case WordType.number:
        return '#';
      case WordType.punctuation:
        return 'Punc';
      case WordType.unknown:
        return '?';
    }
  }
}

extension CEFRLevelExtra on CEFRLevel {
  String get descriptionVi {
    switch (this) {
      case CEFRLevel.a1:
        return 'Sơ cấp';
      case CEFRLevel.a2:
        return 'Căn bản';
      case CEFRLevel.b1:
        return 'Trung cấp';
      case CEFRLevel.b2:
        return 'Khá';
      case CEFRLevel.c1:
        return 'Nâng cao';
      case CEFRLevel.c2:
        return 'Thành thạo';
      case CEFRLevel.unknown:
        return 'Không rõ';
    }
  }
}

extension AnalyzedWordColoring on AnalyzedWord {
  Color getColor(ColorMode mode) {
    switch (mode) {
      case ColorMode.none:
        return Colors.white;
      case ColorMode.wordType:
        return wordType.color;
      case ColorMode.cefrLevel:
        return cefrLevel.color;
      case ColorMode.difficulty:
        return userDifficulty?.color ?? Colors.white;
    }
  }

  Color getBackgroundColor(ColorMode mode) {
    switch (mode) {
      case ColorMode.none:
        return Colors.transparent;
      case ColorMode.wordType:
        return wordType.color.withValues(alpha: 0.12);
      case ColorMode.cefrLevel:
        return cefrLevel.color.withValues(alpha: 0.12);
      case ColorMode.difficulty:
        return (userDifficulty?.color ?? Colors.transparent)
            .withValues(alpha: 0.15);
    }
  }
}

// ===== ANALYZED WORD MODEL =====
class AnalyzedWord {
  final String word;
  final String originalWord;
  final WordType wordType;
  final CEFRLevel cefrLevel;
  final DifficultyLevel? userDifficulty;
  final String? meaning;
  final String? phonetic;
  final String? example;
  final int? frequency;
  final bool isStopWord;

  const AnalyzedWord({
    required this.word,
    String? originalWord,
    this.wordType = WordType.unknown,
    this.cefrLevel = CEFRLevel.unknown,
    this.userDifficulty,
    this.meaning,
    this.phonetic,
    this.example,
    this.frequency,
    this.isStopWord = false,
  }) : originalWord = originalWord ?? word;

  AnalyzedWord copyWith({
    String? word,
    String? originalWord,
    WordType? wordType,
    CEFRLevel? cefrLevel,
    DifficultyLevel? userDifficulty,
    String? meaning,
    String? phonetic,
    String? example,
    int? frequency,
    bool? isStopWord,
  }) {
    return AnalyzedWord(
      word: word ?? this.word,
      originalWord: originalWord ?? this.originalWord,
      wordType: wordType ?? this.wordType,
      cefrLevel: cefrLevel ?? this.cefrLevel,
      userDifficulty: userDifficulty ?? this.userDifficulty,
      meaning: meaning ?? this.meaning,
      phonetic: phonetic ?? this.phonetic,
      example: example ?? this.example,
      frequency: frequency ?? this.frequency,
      isStopWord: isStopWord ?? this.isStopWord,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AnalyzedWord &&
        other.word == word &&
        other.wordType == wordType &&
        other.cefrLevel == cefrLevel &&
        other.userDifficulty == userDifficulty;
  }

  @override
  int get hashCode => Object.hash(word, wordType, cefrLevel, userDifficulty);
}
