// lib/features/learn_by_heart/models/fsrs_models.dart

import 'package:flutter/material.dart';

/// 4 mức đánh giá ôn tập theo FSRS
enum FSRSRating {
  /// Không nhớ gì → Reset, ôn lại sớm
  again,

  /// Nhớ nhưng vật vã → Tăng nhẹ khoảng cách
  hard,

  /// Nhớ bình thường → Tăng khoảng cách chuẩn
  good,

  /// Nhớ ngay, trôi chảy → Tăng mạnh khoảng cách
  easy,
}

extension FSRSRatingExtension on FSRSRating {
  String get label {
    switch (this) {
      case FSRSRating.again:
        return 'Quên';
      case FSRSRating.hard:
        return 'Khó';
      case FSRSRating.good:
        return 'Được';
      case FSRSRating.easy:
        return 'Dễ';
    }
  }

  Color get color {
    switch (this) {
      case FSRSRating.again:
        return const Color(0xFFE53935); // Đỏ
      case FSRSRating.hard:
        return const Color(0xFFFB8C00); // Cam
      case FSRSRating.good:
        return const Color(0xFF43A047); // Xanh lá
      case FSRSRating.easy:
        return const Color(0xFF1E88E5); // Xanh dương
    }
  }

  int get scoreValue {
    switch (this) {
      case FSRSRating.again:
        return 1;
      case FSRSRating.hard:
        return 2;
      case FSRSRating.good:
        return 3;
      case FSRSRating.easy:
        return 4;
    }
  }
}

/// 3 mức tự đánh giá trong Assessment Layer (Kiểm tra thực chất)
enum AssessmentRating {
  /// Sai nhiều → Coi như lapse, cần học lại
  heavyMistake,

  /// Gần đúng (vấp vài từ) → Giữ độ khó cao
  nearCorrect,

  /// Đúng hoàn toàn → Tăng vọt độ bền vững (trọng số x2)
  perfect,
}

extension AssessmentRatingExtension on AssessmentRating {
  String get label {
    switch (this) {
      case AssessmentRating.heavyMistake:
        return 'Sai nhiều';
      case AssessmentRating.nearCorrect:
        return 'Gần đúng';
      case AssessmentRating.perfect:
        return 'Đúng hoàn toàn';
    }
  }

  Color get color {
    switch (this) {
      case AssessmentRating.heavyMistake:
        return const Color(0xFFE53935);
      case AssessmentRating.nearCorrect:
        return const Color(0xFFFB8C00);
      case AssessmentRating.perfect:
        return const Color(0xFF43A047);
    }
  }
}

/// Tham số lưu trữ FSRS
class FSRSParams {
  /// Độ bền trí nhớ (Stability tính bằng ngày)
  final double stability;

  /// Độ khó (Difficulty thang điểm 1.0 -> 10.0)
  final double difficulty;

  /// Số lần ôn tập thành công liên tiếp
  final int reps;

  /// Số lần bị quên (lapses)
  final int lapses;

  /// Khoảng cách ngày của lần ôn trước
  final int lastIntervalDays;

  const FSRSParams({
    this.stability = 1.0,
    this.difficulty = 5.0,
    this.reps = 0,
    this.lapses = 0,
    this.lastIntervalDays = 0,
  });

  FSRSParams copyWith({
    double? stability,
    double? difficulty,
    int? reps,
    int? lapses,
    int? lastIntervalDays,
  }) {
    return FSRSParams(
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      reps: reps ?? this.reps,
      lapses: lapses ?? this.lapses,
      lastIntervalDays: lastIntervalDays ?? this.lastIntervalDays,
    );
  }

  Map<String, dynamic> toJson() => {
        'stability': stability,
        'difficulty': difficulty,
        'reps': reps,
        'lapses': lapses,
        'lastIntervalDays': lastIntervalDays,
      };

  factory FSRSParams.fromJson(Map<String, dynamic> json) {
    return FSRSParams(
      stability: (json['stability'] as num?)?.toDouble() ?? 1.0,
      difficulty: (json['difficulty'] as num?)?.toDouble() ?? 5.0,
      reps: json['reps'] as int? ?? 0,
      lapses: json['lapses'] as int? ?? 0,
      lastIntervalDays: json['lastIntervalDays'] as int? ?? 0,
    );
  }
}

/// Bản ghi lịch sử ôn tập
class ReviewLog {
  final DateTime timestamp;
  final String rating;
  final int intervalDays;
  final double stability;
  final double difficulty;
  final bool isAssessment;

  const ReviewLog({
    required this.timestamp,
    required this.rating,
    required this.intervalDays,
    required this.stability,
    required this.difficulty,
    this.isAssessment = false,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'rating': rating,
        'intervalDays': intervalDays,
        'stability': stability,
        'difficulty': difficulty,
        'isAssessment': isAssessment,
      };

  factory ReviewLog.fromJson(Map<String, dynamic> json) {
    return ReviewLog(
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      rating: json['rating'] as String? ?? 'good',
      intervalDays: json['intervalDays'] as int? ?? 1,
      stability: (json['stability'] as num?)?.toDouble() ?? 1.0,
      difficulty: (json['difficulty'] as num?)?.toDouble() ?? 5.0,
      isAssessment: json['isAssessment'] as bool? ?? false,
    );
  }
}
