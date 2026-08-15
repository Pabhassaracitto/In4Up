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
        'overallGrade': overallGrade,
        'feedbackMessage': feedbackMessage,
        'correctWordCount': correctWordCount,
        'totalWordCount': totalWordCount,
        'tempoRatio': tempoRatio,
        'timestamp': timestamp.toIso8601String(),
        'acoustic': acousticAnalysis == null
            ? null
            : {
                'pitchScore': acousticAnalysis!.pitchScore,
                'energyScore': acousticAnalysis!.energyScore,
                'rhythmScore': acousticAnalysis!.rhythmScore,
                'spectralScore': acousticAnalysis!.spectralScore,
              },
        'wordBreakdown': wordResults
            .map(
              (w) => {
                'expectedWord': w.expectedWord,
                'recognizedWord': w.recognizedWord,
                'status': w.status.name,
                'scorePercent': w.scorePercent,
                'phonemeIssues': w.phonemeScores
                    .where((p) => p.score < 0.7)
                    .take(3)
                    .map((p) => '${p.phoneme}:${p.scorePercent}%')
                    .toList(),
              },
            )
            .toList(),
      };
}

class ShadowingHistoryEntry {
  final String id;
  final String originalText;
  final String? recognizedText;
  final int overallScorePercent;
  final String? overallGradeLabel;
  final String? feedbackMessage;
  final int correctWordCount;
  final int totalWordCount;
  final double tempoRatio;
  final DateTime timestamp;
  final ShadowingAcousticSnapshot? acoustic;
  final List<ShadowingWordBreakdown> wordBreakdown;

  const ShadowingHistoryEntry({
    required this.id,
    required this.originalText,
    required this.recognizedText,
    required this.overallScorePercent,
    this.overallGradeLabel,
    this.feedbackMessage,
    required this.correctWordCount,
    required this.totalWordCount,
    required this.tempoRatio,
    required this.timestamp,
    this.acoustic,
    this.wordBreakdown = const [],
  });

  factory ShadowingHistoryEntry.fromJson(Map<String, dynamic> json) {
    final acousticMap = json['acoustic'] as Map<String, dynamic>?;
    final rawBreakdown = (json['wordBreakdown'] as List?) ?? const [];

    return ShadowingHistoryEntry(
      id: json['id']?.toString() ?? '',
      originalText: json['originalText']?.toString() ?? '',
      recognizedText: json['recognizedText']?.toString(),
      overallScorePercent: (json['overallScorePercent'] as num?)?.toInt() ??
          (((json['overallScore'] as num?)?.toDouble() ?? 0.0) * 100).round(),
      overallGradeLabel: json['overallGrade']?.toString(),
      feedbackMessage: json['feedbackMessage']?.toString(),
      correctWordCount: (json['correctWordCount'] as num?)?.toInt() ?? 0,
      totalWordCount: (json['totalWordCount'] as num?)?.toInt() ?? 0,
      tempoRatio: (json['tempoRatio'] as num?)?.toDouble() ?? 1.0,
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      acoustic: acousticMap == null
          ? null
          : ShadowingAcousticSnapshot.fromJson(acousticMap),
      wordBreakdown: rawBreakdown
          .whereType<Map>()
          .map((e) => ShadowingWordBreakdown.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

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

  String get gradeLabel => overallGradeLabel ?? overallGrade;

  Color get scoreColor {
    final score = overallScorePercent;
    if (score >= 85) return const Color(0xFF4CAF50);
    if (score >= 70) return const Color(0xFFFFB300);
    if (score >= 50) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }
}

class ShadowingAcousticSnapshot {
  final double pitchScore;
  final double energyScore;
  final double rhythmScore;
  final double spectralScore;

  const ShadowingAcousticSnapshot({
    required this.pitchScore,
    required this.energyScore,
    required this.rhythmScore,
    required this.spectralScore,
  });

  factory ShadowingAcousticSnapshot.fromJson(Map<String, dynamic> json) {
    return ShadowingAcousticSnapshot(
      pitchScore: (json['pitchScore'] as num?)?.toDouble() ?? 0.0,
      energyScore: (json['energyScore'] as num?)?.toDouble() ?? 0.0,
      rhythmScore: (json['rhythmScore'] as num?)?.toDouble() ?? 0.0,
      spectralScore: (json['spectralScore'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ShadowingWordBreakdown {
  final String expectedWord;
  final String? recognizedWord;
  final String status;
  final int scorePercent;
  final List<String> phonemeIssues;

  const ShadowingWordBreakdown({
    required this.expectedWord,
    required this.recognizedWord,
    required this.status,
    required this.scorePercent,
    this.phonemeIssues = const [],
  });

  factory ShadowingWordBreakdown.fromJson(Map<String, dynamic> json) {
    return ShadowingWordBreakdown(
      expectedWord: json['expectedWord']?.toString() ?? '',
      recognizedWord: json['recognizedWord']?.toString(),
      status: json['status']?.toString() ?? 'unknown',
      scorePercent: (json['scorePercent'] as num?)?.toInt() ?? 0,
      phonemeIssues: ((json['phonemeIssues'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  String get shortStatus {
    switch (status) {
      case 'correct':
        return 'Đúng';
      case 'substituted':
        return 'Lệch';
      case 'missed':
        return 'Bỏ lỡ';
      default:
        return status;
    }
  }
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
