// lib/screens/memory_mode/models/memory_stats.dart

import 'package:flutter/material.dart';
import 'memory_stage.dart';

class MemoryStats {
  final int totalItems;
  final Map<MemoryStage, int> stageDistribution;
  final int dueToday;
  final int reviewedToday;
  final int correctToday;
  final int streakDays;
  final double averageAccuracy;
  final Duration totalStudyTime;

  const MemoryStats({
    this.totalItems = 0,
    this.stageDistribution = const {},
    this.dueToday = 0,
    this.reviewedToday = 0,
    this.correctToday = 0,
    this.streakDays = 0,
    this.averageAccuracy = 0.0,
    this.totalStudyTime = Duration.zero,
  });

  double get completionRate =>
      dueToday > 0 ? (reviewedToday / dueToday).clamp(0.0, 1.0) : 1.0;

  int getStageCount(MemoryStage stage) => stageDistribution[stage] ?? 0;
}
