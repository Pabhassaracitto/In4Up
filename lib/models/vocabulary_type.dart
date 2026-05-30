import 'package:flutter/material.dart';

/// Phân loại thực thể từ vựng theo cấp bậc:
///   Sentence ⊃ Phrase ⊃ Word
enum VocabularyType {
  word,
  phrase,
  sentence,
  paragraph;

  String get label {
    switch (this) {
      case VocabularyType.word:
        return 'Từ';
      case VocabularyType.phrase:
        return 'Cụm từ';
      case VocabularyType.sentence:
        return 'Câu';
      case VocabularyType.paragraph:
        return 'Đoạn';
    }
  }

  String get labelEn {
    switch (this) {
      case VocabularyType.word:
        return 'Word';
      case VocabularyType.phrase:
        return 'Phrase';
      case VocabularyType.sentence:
        return 'Sentence';
      case VocabularyType.paragraph:
        return 'Paragraph';
    }
  }

  Color get color {
    switch (this) {
      case VocabularyType.word:
        return const Color(0xFF4CAF50);
      case VocabularyType.phrase:
        return const Color(0xFF2196F3);
      case VocabularyType.sentence:
        return const Color(0xFFFF9800);
      case VocabularyType.paragraph:
        return const Color(0xFF9C27B0);
    }
  }

  Color get bgColor {
    switch (this) {
      case VocabularyType.word:
        return const Color(0xFF4CAF50).withValues(alpha: 0.12);
      case VocabularyType.phrase:
        return const Color(0xFF2196F3).withValues(alpha: 0.12);
      case VocabularyType.sentence:
        return const Color(0xFFFF9800).withValues(alpha: 0.12);
      case VocabularyType.paragraph:
        return const Color(0xFF9C27B0).withValues(alpha: 0.12);
    }
  }

  IconData get icon {
    switch (this) {
      case VocabularyType.word:
        return Icons.text_fields;
      case VocabularyType.phrase:
        return Icons.short_text;
      case VocabularyType.sentence:
        return Icons.notes;
      case VocabularyType.paragraph:
        return Icons.view_headline;
    }
  }

  String get badge {
    switch (this) {
      case VocabularyType.word:
        return 'W';
      case VocabularyType.phrase:
        return 'P';
      case VocabularyType.sentence:
        return 'S';
      case VocabularyType.paragraph:
        return 'D';
    }
  }
}
