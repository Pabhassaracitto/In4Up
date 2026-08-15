// lib/models/color_mode.dart
import 'package:flutter/material.dart';

/// Chế độ tô màu text trong Read Mode
enum ColorMode {
  none,
  wordType,
  cefrLevel,
  difficulty;

  String get label {
    switch (this) {
      case ColorMode.none:
        return 'Content';
      case ColorMode.wordType:
        return 'Content';
      case ColorMode.cefrLevel:
        return 'CEFR';
      case ColorMode.difficulty:
        return 'Content';
    }
  }

  IconData get icon {
    switch (this) {
      case ColorMode.none:
        return Icons.format_color_reset;
      case ColorMode.wordType:
        return Icons.category;
      case ColorMode.cefrLevel:
        return Icons.school;
      case ColorMode.difficulty:
        return Icons.trending_up;
    }
  }

  ColorMode get next {
    final values = ColorMode.values;
    return values[(index + 1) % values.length];
  }
}