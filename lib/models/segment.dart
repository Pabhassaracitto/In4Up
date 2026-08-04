// lib/models/segment.dart
import 'package:flutter/material.dart'; // ← THÊM (fix Color/Icons undefined)
import 'package:in2up_core/vocab_level_difficulty.dart'; // ← THÊM (dùng DifficultyLevel từ core)

class Segment {
  final String id;
  final String audioPath;
  final String title;
  final Duration startTime;
  final Duration endTime;
  final SegmentType type;
  final DifficultyLevel difficulty;
  final int repeatCount;
  final String? note;
  final DateTime createdAt;
  final List<String> tags;

  Segment({
    required this.id,
    required this.audioPath,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.type = SegmentType.favorite,
    this.difficulty = DifficultyLevel.medium,
    this.repeatCount = 1,
    this.note,
    required this.createdAt,
    this.tags = const [],
  });

  Duration get duration => endTime - startTime;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'audioPath': audioPath,
      'title': title,
      'startTime': startTime.inMilliseconds,
      'endTime': endTime.inMilliseconds,
      'type': type.name,
      'difficulty': difficulty.name,
      'repeatCount': repeatCount,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'tags': tags,
    };
  }

  factory Segment.fromJson(Map<String, dynamic> json) {
    return Segment(
      id: json['id'],
      audioPath: json['audioPath'],
      title: json['title'],
      startTime: Duration(milliseconds: json['startTime']),
      endTime: Duration(milliseconds: json['endTime']),
      type: SegmentType.values.firstWhere(
        (e) => e.name == json['type'],
      ),
      difficulty: DifficultyLevel.values.firstWhere(
        (e) => e.name == json['difficulty'],
        orElse: () =>
            DifficultyLevel.medium, // ← THÊM fallback (vì core có veryHard)
      ),
      repeatCount: json['repeatCount'],
      note: json['note'],
      createdAt: DateTime.parse(json['createdAt']),
      tags: List<String>.from(json['tags'] ?? []),
    );
  }
}

enum SegmentType {
  dharma, // Pháp thoại
  english, // Luyện tiếng Anh
  favorite, // Yêu thích
  practice, // Cần luyện tập
}

// ← XÓA toàn bộ enum DifficultyLevel + extension DifficultyLevelX
// Dùng DifficultyLevel từ in2up_core (có đầy đủ label/color/icon/repeatCount/ttsSpeed)
// NHƯNG in2up_core chưa có .icon → thêm extension riêng ở đây:

extension SegmentDifficultyIcon on DifficultyLevel {
  IconData get icon {
    switch (this) {
      case DifficultyLevel.easy:
        return Icons.sentiment_satisfied_rounded;
      case DifficultyLevel.medium:
        return Icons.sentiment_neutral_rounded;
      case DifficultyLevel.hard:
        return Icons.sentiment_very_dissatisfied_rounded;
      case DifficultyLevel.veryHard:
        return Icons.sentiment_very_dissatisfied_rounded;
    }
  }
}
