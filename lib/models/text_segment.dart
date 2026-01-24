// lib/models/text_segment.dart

import 'package:flutter/material.dart';

/// Độ khó của đoạn text
enum TextSegmentDifficulty {
  easy,    // Dễ - repeat 1-2x, speed 1.0-1.2x
  medium,  // Vừa - repeat 3x, speed 0.9-1.0x
  hard,    // Khó - repeat 5x, speed 0.6-0.8x
}

/// Loại đoạn text (để phân loại và filter)
enum TextSegmentType {
  vocabulary,   // Từ vựng đơn lẻ
  phrase,       // Cụm từ/thành ngữ
  sentence,     // Câu hoàn chỉnh
  paragraph,    // Đoạn văn
  dharma,       // Thuật ngữ Phật Pháp
  grammar,      // Cấu trúc ngữ pháp
}

/// Đoạn text đã đánh dấu để học
class TextSegment {
  final String id;
  final String content;
  final int startOffset;
  final int endOffset;
  final TextSegmentDifficulty difficulty;
  final TextSegmentType type;
  final int repeatCount;
  final double ttsSpeed;
  final String? note;
  final String? translation;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime? lastPracticed;
  final int practiceCount;
  final double masteryLevel; // 0.0 - 1.0

  TextSegment({
    required this.id,
    required this.content,
    required this.startOffset,
    required this.endOffset,
    this.difficulty = TextSegmentDifficulty.medium,
    this.type = TextSegmentType.phrase,
    this.repeatCount = 3,
    this.ttsSpeed = 1.0,
    this.note,
    this.translation,
    this.tags = const [],
    DateTime? createdAt,
    this.lastPracticed,
    this.practiceCount = 0,
    this.masteryLevel = 0.0,
  }) : createdAt = createdAt ?? DateTime.now();

  TextSegment copyWith({
    String? id,
    String? content,
    int? startOffset,
    int? endOffset,
    TextSegmentDifficulty? difficulty,
    TextSegmentType? type,
    int? repeatCount,
    double? ttsSpeed,
    String? note,
    String? translation,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? lastPracticed,
    int? practiceCount,
    double? masteryLevel,
  }) {
    return TextSegment(
      id: id ?? this.id,
      content: content ?? this.content,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      difficulty: difficulty ?? this.difficulty,
      type: type ?? this.type,
      repeatCount: repeatCount ?? this.repeatCount,
      ttsSpeed: ttsSpeed ?? this.ttsSpeed,
      note: note ?? this.note,
      translation: translation ?? this.translation,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      lastPracticed: lastPracticed ?? this.lastPracticed,
      practiceCount: practiceCount ?? this.practiceCount,
      masteryLevel: masteryLevel ?? this.masteryLevel,
    );
  }

  /// Màu theo độ khó
  Color get difficultyColor {
    switch (difficulty) {
      case TextSegmentDifficulty.easy:
        return const Color(0xFF4CAF50);
      case TextSegmentDifficulty.medium:
        return const Color(0xFFFF9800);
      case TextSegmentDifficulty.hard:
        return const Color(0xFFF44336);
    }
  }

  /// Icon theo loại
  IconData get typeIcon {
    switch (type) {
      case TextSegmentType.vocabulary:
        return Icons.abc;
      case TextSegmentType.phrase:
        return Icons.format_quote;
      case TextSegmentType.sentence:
        return Icons.short_text;
      case TextSegmentType.paragraph:
        return Icons.subject;
      case TextSegmentType.dharma:
        return Icons.spa;
      case TextSegmentType.grammar:
        return Icons.rule;
    }
  }

  /// Tính toán thời gian ôn tập tiếp theo (SRS)
  DateTime? get nextReviewDate {
    if (lastPracticed == null) return DateTime.now();

    // Fibonacci-like intervals based on mastery
    final intervals = [1, 1, 2, 3, 5, 8, 13, 21, 34]; // days
    final intervalIndex = (masteryLevel * (intervals.length - 1)).round();
    final days = intervals[intervalIndex];

    return lastPracticed!.add(Duration(days: days));
  }

  /// Cần ôn tập không?
  bool get needsReview {
    if (lastPracticed == null) return true;
    return DateTime.now().isAfter(nextReviewDate!);
  }
}

/// Thông tin về đoạn text đang được chọn
class SelectedTextInfo {
  final String text;
  final int startOffset;
  final int endOffset;
  final int lineIndex; // Dòng chứa đoạn chọn

  SelectedTextInfo({
    required this.text,
    required this.startOffset,
    required this.endOffset,
    required this.lineIndex,
  });
}