//shadowing_result.dart
// NEW - Mô hình dữ liệu kết quả shadowing, bao gồm điểm số và phân tích chi tiết
// lib/models/shadowing_result.dart

import 'phoneme_models.dart';
import 'package:flutter/material.dart';

/// Kết quả một phiên shadowing
class ShadowingResult {
  final String id;
  final String originalText;
  final String? recognizedText;
  final List<WordResult> wordResults;
  final AcousticAnalysis? acousticAnalysis;
  final List<double> originalWaveform;
  final List<double> userWaveform;
  final Duration originalDuration;
  final Duration userDuration;
  final DateTime timestamp;

  ShadowingResult({
    String? id,
    required this.originalText,
    this.recognizedText,
    required this.wordResults,
    this.acousticAnalysis,
    required this.originalWaveform,
    required this.userWaveform,
    required this.originalDuration,
    required this.userDuration,
    DateTime? timestamp,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp = timestamp ?? DateTime.now();

  /// Điểm trung bình các từ
  double get averageWordScore {
    if (wordResults.isEmpty) return 0.0;
    final sum = wordResults.fold(0.0, (sum, w) => sum + w.score);
    return sum / wordResults.length;
  }

  /// Điểm tổng hợp (kết hợp text và acoustic)
  double get overallScore {
    final textScore = averageWordScore;
    final acousticScore = acousticAnalysis?.overallScore ?? textScore;
    return (textScore * 0.7 + acousticScore * 0.3);
  }

  int get overallScorePercent => (overallScore * 100).round();

  /// Số từ đúng
  int get correctWordCount =>
      wordResults.where((w) => w.status == WordStatus.correct).length;

  /// Tổng số từ
  int get totalWordCount => wordResults.length;

  /// Tỷ lệ tempo (user/original)
  double get tempoRatio {
    if (originalDuration.inMilliseconds == 0) return 1.0;
    return userDuration.inMilliseconds / originalDuration.inMilliseconds;
  }

  /// Grade tổng
  String get overallGrade {
    final score = overallScorePercent;
    if (score >= 95) return 'A+';
    if (score >= 90) return 'A';
    if (score >= 85) return 'B+';
    if (score >= 80) return 'B';
    if (score >= 75) return 'C+';
    if (score >= 70) return 'C';
    if (score >= 60) return 'D';
    return 'F';
  }

  /// Màu theo điểm
  int get scoreColorValue {
    final score = overallScorePercent;
    if (score >= 85) return 0xFF4CAF50;
    if (score >= 70) return 0xFFFFB300;
    if (score >= 50) return 0xFFFF9800;
    return 0xFFF44336;
  }

  /// Màu Color object
  Color get scoreColor => Color(scoreColorValue);

  /// Feedback message
  String get feedbackMessage {
    final score = overallScorePercent;
    if (score >= 95) {
      return 'Outstanding! Nearly perfect! 🎯';
    }
    if (score >= 85) {
      return 'Excellent pronunciation! ⭐';
    }
    if (score >= 75) {
      return 'Very good! Keep practicing! 👍';
    }
    if (score >= 65) {
      return 'Good effort! Focus on red sounds. 📚';
    }
    if (score >= 50) {
      return 'Fair. Try speaking slower. 🎯';
    }
    return 'Keep trying! Practice daily. 💪';
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() => {
        'id': id,
        'originalText': originalText,
        'recognizedText': recognizedText,
        'overallScore': overallScore,
        'overallScorePercent': overallScorePercent,
        'correctWordCount': correctWordCount,
        'totalWordCount': totalWordCount,
        'tempoRatio': tempoRatio,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Trạng thái của Shadowing Session
enum ShadowingState {
  idle, // Chờ bắt đầu
  playingOriginal, // Đang phát audio gốc
  countdown, // Đếm ngược trước khi ghi
  recording, // Đang ghi âm
  analyzing, // Đang phân tích
  showingResults, // Hiển thị kết quả
}
