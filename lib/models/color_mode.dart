// lib/models/color_mode.dart
import 'package:flutter/material.dart';

/// Chế độ tô màu text trong Read Mode
enum ColorMode {
  none,
  wordType,
  cefrLevel,
  difficulty,
  svo;

  String get label {
    switch (this) {
      case ColorMode.none:
        return 'Không màu';
      case ColorMode.wordType:
        return 'Loại từ';
      case ColorMode.cefrLevel:
        return 'CEFR';
      case ColorMode.difficulty:
        return 'Độ khó';
      case ColorMode.svo:
        return 'SVO';
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
      case ColorMode.svo:
        return Icons.center_focus_strong;
    }
  }

  ColorMode get next {
    final values = ColorMode.values;
    return values[(index + 1) % values.length];
  }
}
