import 'package:flutter/material.dart';

// Gốc từ enum DifficultyLevel trong word_analysis.dart [2]
enum DifficultyLevel { easy, medium, hard, veryHard }

extension DifficultyLevelExtra on DifficultyLevel {
  // Nhãn tiếng Việt [3]
  String get label {
    switch (this) {
      case DifficultyLevel.easy:
        return 'Dễ';
      case DifficultyLevel.medium:
        return 'Trung bình';
      case DifficultyLevel.hard:
        return 'Khó';
      case DifficultyLevel.veryHard:
        return 'Rất khó';
    }
  }

  // Màu sắc định dạng [3]
  Color get color {
    switch (this) {
      case DifficultyLevel.easy:
        return const Color(0xFF4CAF50);
      case DifficultyLevel.medium:
        return const Color(0xFFFF9800);
      case DifficultyLevel.hard:
        return const Color(0xFFF44336);
      case DifficultyLevel.veryHard:
        return const Color(0xFF9C27B0);
    }
  }

  // Tốc độ đọc TTS tương ứng (Dùng để đồng bộ hóa độ khó STT/Shadowing) [4]
  double get ttsSpeed {
    switch (this) {
      case DifficultyLevel.easy:
        return 1.0;
      case DifficultyLevel.medium:
        return 0.85;
      case DifficultyLevel.hard:
        return 0.70;
      case DifficultyLevel.veryHard:
        return 0.60;
    }
  }

  // Số lần lặp lại mặc định [3]
  int get repeatCount {
    switch (this) {
      case DifficultyLevel.easy:
        return 1;
      case DifficultyLevel.medium:
        return 3;
      case DifficultyLevel.hard:
        return 5;
      case DifficultyLevel.veryHard:
        return 8;
    }
  }
}
