// lib/screens/memory_mode/models/memory_item.dart

import 'package:flutter/material.dart';
import 'memory_stage.dart';

class MemoryItem {
  final String id;
  final String word;
  final String? meaning;
  final String? phonetic;
  final String? example;
  final String? context;
  final String? audioPath;
  final Duration? audioStart;
  final Duration? audioEnd;

  // ===== MEMORY STATE =====
  final MemoryStage stage;
  final int correctCount;
  final int totalReviews;
  final int incorrectCount;
  final double easeFactor;
  final DateTime createdAt;
  final DateTime? lastReviewedAt;
  final DateTime? nextReviewAt;

  // ===== METADATA =====
  final String? wordType;
  final String? cefrLevel;
  final String? sourceFile;
  final int? sourceLine;
  final List<String> tags;

  const MemoryItem({
    required this.id,
    required this.word,
    this.meaning,
    this.phonetic,
    this.example,
    this.context,
    this.audioPath,
    this.audioStart,
    this.audioEnd,
    this.stage = MemoryStage.seed,
    this.correctCount = 0,
    this.totalReviews = 0,
    this.incorrectCount = 0,
    this.easeFactor = 2.5,
    required this.createdAt,
    this.lastReviewedAt,
    this.nextReviewAt,
    this.wordType,
    this.cefrLevel,
    this.sourceFile,
    this.sourceLine,
    this.tags = const [],
  });

  // ==================== COMPUTED PROPERTIES ====================
  bool get needsReview {
    if (nextReviewAt == null) return true;
    return DateTime.now().isAfter(nextReviewAt!);
  }

  double get overdueHours {
    if (nextReviewAt == null) return 999;
    return DateTime.now().difference(nextReviewAt!).inMinutes / 60.0;
  }

  double get urgencyScore {
    final stageWeight = 1.0 - stage.progressRatio;
    final overdueWeight =
        overdueHours > 0 ? (overdueHours / 24.0).clamp(0.0, 1.0) : 0.0;
    return (overdueWeight * 0.6 + stageWeight * 0.4).clamp(0.0, 1.0);
  }

  double get accuracy {
    if (totalReviews == 0) return 0.0;
    return correctCount / totalReviews;
  }

  double get strength {
    final stageStrength = stage.progressRatio;
    final accuracyStrength = accuracy;

    double recencyStrength = 0.0;
    if (lastReviewedAt != null) {
      final hoursSinceReview =
          DateTime.now().difference(lastReviewedAt!).inHours;
      final halfLife = stage.reviewIntervalHours.toDouble();
      recencyStrength =
          (1.0 * _exp(-0.693 * hoursSinceReview / halfLife)).clamp(0.0, 1.0);
    }

    return (stageStrength * 0.4 +
            accuracyStrength * 0.3 +
            recencyStrength * 0.3)
        .clamp(0.0, 1.0);
  }

  static double _exp(double x) {
    if (x > 0) return 1.0;
    if (x < -10) return 0.0;
    double result = 1.0;
    double term = 1.0;
    for (int i = 1; i <= 10; i++) {
      term *= x / i;
      result += term;
    }
    return result.clamp(0.0, 1.0);
  }

  // ==================== VISUAL PROPERTIES ====================
  double getFontSize(double baseFontSize) {
    return baseFontSize * stage.fontScale * (0.85 + urgencyScore * 0.3);
  }

  Color get displayColor {
    return stage.primaryColor.withValues(alpha: stage.textOpacity);
  }

  Color get displayBackgroundColor {
    if (needsReview && overdueHours > 24) {
      return const Color(0xFFFF1744).withValues(alpha: 0.25);
    }
    return stage.backgroundColor;
  }

  // ==================== SRS ENGINE ====================
  MemoryItem markCorrect() {
    final newCorrectCount = correctCount + 1;
    final newTotalReviews = totalReviews + 1;

    final newEase =
        (easeFactor + 0.1 - (5 - 4) * (0.08 + (5 - 4) * 0.02)).clamp(1.3, 2.5);

    MemoryStage newStage = stage;
    int resetCorrect = newCorrectCount;
    if (newCorrectCount >= stage.requiredCorrectReviews) {
      final nextStage = stage.next;
      if (nextStage != null) {
        newStage = nextStage;
        resetCorrect = 0;
      }
    }

    final intervalHours = (newStage.reviewIntervalHours * newEase).round();
    final nextReview = DateTime.now().add(Duration(hours: intervalHours));

    return _copyWith(
      stage: newStage,
      correctCount: resetCorrect,
      totalReviews: newTotalReviews,
      easeFactor: newEase,
      lastReviewedAt: DateTime.now(),
      nextReviewAt: nextReview,
    );
  }

  MemoryItem markIncorrect() {
    final newEase = (easeFactor - 0.2).clamp(1.3, 2.5);
    final newStage = stage.demoted;
    final nextReview = DateTime.now().add(const Duration(hours: 1));

    return _copyWith(
      stage: newStage,
      correctCount: 0,
      totalReviews: totalReviews + 1,
      incorrectCount: incorrectCount + 1,
      easeFactor: newEase,
      lastReviewedAt: DateTime.now(),
      nextReviewAt: nextReview,
    );
  }

  MemoryItem markHard() {
    final newEase = (easeFactor - 0.05).clamp(1.3, 2.5);
    final intervalHours = (stage.reviewIntervalHours * newEase * 0.6).round();
    final nextReview = DateTime.now().add(
      Duration(hours: intervalHours.clamp(1, 720)),
    );

    return _copyWith(
      correctCount: correctCount + 1,
      totalReviews: totalReviews + 1,
      easeFactor: newEase,
      lastReviewedAt: DateTime.now(),
      nextReviewAt: nextReview,
    );
  }

  // ==================== SERIALIZATION ====================
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'word': word,
      'meaning': meaning,
      'phonetic': phonetic,
      'example': example,
      'context': context,
      'audioPath': audioPath,
      'audioStart': audioStart?.inMilliseconds,
      'audioEnd': audioEnd?.inMilliseconds,
      'stage': stage.name,
      'correctCount': correctCount,
      'totalReviews': totalReviews,
      'incorrectCount': incorrectCount,
      'easeFactor': easeFactor,
      'createdAt': createdAt.toIso8601String(),
      'lastReviewedAt': lastReviewedAt?.toIso8601String(),
      'nextReviewAt': nextReviewAt?.toIso8601String(),
      'wordType': wordType,
      'cefrLevel': cefrLevel,
      'sourceFile': sourceFile,
      'sourceLine': sourceLine,
      'tags': tags,
    };
  }

  factory MemoryItem.fromJson(Map<String, dynamic> json) {
    return MemoryItem(
      id: json['id'] as String,
      word: json['word'] as String,
      meaning: json['meaning'] as String?,
      phonetic: json['phonetic'] as String?,
      example: json['example'] as String?,
      context: json['context'] as String?,
      audioPath: json['audioPath'] as String?,
      audioStart: json['audioStart'] != null
          ? Duration(milliseconds: json['audioStart'] as int)
          : null,
      audioEnd: json['audioEnd'] != null
          ? Duration(milliseconds: json['audioEnd'] as int)
          : null,
      stage: MemoryStage.values.firstWhere(
        (s) => s.name == json['stage'],
        orElse: () => MemoryStage.seed,
      ),
      correctCount: json['correctCount'] as int? ?? 0,
      totalReviews: json['totalReviews'] as int? ?? 0,
      incorrectCount: json['incorrectCount'] as int? ?? 0,
      easeFactor: (json['easeFactor'] as num?)?.toDouble() ?? 2.5,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      lastReviewedAt: json['lastReviewedAt'] != null
          ? DateTime.parse(json['lastReviewedAt'] as String)
          : null,
      nextReviewAt: json['nextReviewAt'] != null
          ? DateTime.parse(json['nextReviewAt'] as String)
          : null,
      wordType: json['wordType'] as String?,
      cefrLevel: json['cefrLevel'] as String?,
      sourceFile: json['sourceFile'] as String?,
      sourceLine: json['sourceLine'] as int?,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              [],
    );
  }

  MemoryItem _copyWith({
    MemoryStage? stage,
    int? correctCount,
    int? totalReviews,
    int? incorrectCount,
    double? easeFactor,
    DateTime? lastReviewedAt,
    DateTime? nextReviewAt,
  }) {
    return MemoryItem(
      id: id,
      word: word,
      meaning: meaning,
      phonetic: phonetic,
      example: example,
      context: context,
      audioPath: audioPath,
      audioStart: audioStart,
      audioEnd: audioEnd,
      stage: stage ?? this.stage,
      correctCount: correctCount ?? this.correctCount,
      totalReviews: totalReviews ?? this.totalReviews,
      incorrectCount: incorrectCount ?? this.incorrectCount,
      easeFactor: easeFactor ?? this.easeFactor,
      createdAt: createdAt,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
      wordType: wordType,
      cefrLevel: cefrLevel,
      sourceFile: sourceFile,
      sourceLine: sourceLine,
      tags: tags,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MemoryItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
