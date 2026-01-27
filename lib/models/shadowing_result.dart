// NEW - Kết quả so sánh
import 'package:flutter/material.dart';

/// Kết quả so sánh shadowing
class ShadowingResult {
  final String id;
  final String originalAudioPath;
  final String recordedAudioPath;
  final Duration originalDuration;
  final Duration recordedDuration;
  final Duration segmentStart;
  final Duration segmentEnd;

  // Waveform data
  final List<double> originalWaveform;
  final List<double> recordedWaveform;

  // Điểm số (0.0 - 1.0)
  final double rhythmScore;      // Điểm nhịp điệu
  final double durationScore;    // Điểm độ dài
  final double amplitudeScore;   // Điểm biên độ/năng lượng
  final double overallScore;     // Điểm tổng

  // Phản hồi chi tiết
  final List<ShadowingFeedback> feedbacks;

  final DateTime createdAt;

  ShadowingResult({
    required this.id,
    required this.originalAudioPath,
    required this.recordedAudioPath,
    required this.originalDuration,
    required this.recordedDuration,
    required this.segmentStart,
    required this.segmentEnd,
    required this.originalWaveform,
    required this.recordedWaveform,
    required this.rhythmScore,
    required this.durationScore,
    required this.amplitudeScore,
    required this.overallScore,
    this.feedbacks = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Đánh giá tổng quan
  ShadowingGrade get grade {
    if (overallScore >= 0.9) return ShadowingGrade.excellent;
    if (overallScore >= 0.75) return ShadowingGrade.good;
    if (overallScore >= 0.6) return ShadowingGrade.fair;
    if (overallScore >= 0.4) return ShadowingGrade.needsWork;
    return ShadowingGrade.tryAgain;
  }

  /// Thời lượng segment gốc
  Duration get segmentDuration => segmentEnd - segmentStart;

  /// Chênh lệch thời lượng
  Duration get durationDifference => recordedDuration - segmentDuration;

  /// % chênh lệch thời lượng
  double get durationDifferencePercent {
    if (segmentDuration.inMilliseconds == 0) return 0;
    return durationDifference.inMilliseconds / segmentDuration.inMilliseconds;
  }
}

/// Phản hồi chi tiết
class ShadowingFeedback {
  final FeedbackType type;
  final String message;
  final String? suggestion;
  final Duration? position; // Vị trí trong audio nếu có

  ShadowingFeedback({
    required this.type,
    required this.message,
    this.suggestion,
    this.position,
  });
}

enum FeedbackType {
  rhythm,      // Nhịp điệu
  speed,       // Tốc độ
  pause,       // Ngắt nghỉ
  energy,      // Năng lượng/biên độ
  duration,    // Độ dài
  general,     // Chung
}

extension FeedbackTypeExtension on FeedbackType {
  String get displayName {
    switch (this) {
      case FeedbackType.rhythm: return 'Nhịp điệu';
      case FeedbackType.speed: return 'Tốc độ';
      case FeedbackType.pause: return 'Ngắt nghỉ';
      case FeedbackType.energy: return 'Năng lượng';
      case FeedbackType.duration: return 'Độ dài';
      case FeedbackType.general: return 'Tổng quan';
    }
  }

  IconData get icon {
    switch (this) {
      case FeedbackType.rhythm: return Icons.music_note;
      case FeedbackType.speed: return Icons.speed;
      case FeedbackType.pause: return Icons.pause_circle_outline;
      case FeedbackType.energy: return Icons.graphic_eq;
      case FeedbackType.duration: return Icons.timer;
      case FeedbackType.general: return Icons.info_outline;
    }
  }

  Color get color {
    switch (this) {
      case FeedbackType.rhythm: return Colors.purple;
      case FeedbackType.speed: return Colors.blue;
      case FeedbackType.pause: return Colors.orange;
      case FeedbackType.energy: return Colors.green;
      case FeedbackType.duration: return Colors.teal;
      case FeedbackType.general: return Colors.grey;
    }
  }
}

enum ShadowingGrade {
  excellent,   // 90%+
  good,        // 75-89%
  fair,        // 60-74%
  needsWork,   // 40-59%
  tryAgain,    // <40%
}

extension ShadowingGradeExtension on ShadowingGrade {
  String get displayName {
    switch (this) {
      case ShadowingGrade.excellent: return 'Xuất sắc!';
      case ShadowingGrade.good: return 'Tốt lắm!';
      case ShadowingGrade.fair: return 'Khá tốt';
      case ShadowingGrade.needsWork: return 'Cần luyện thêm';
      case ShadowingGrade.tryAgain: return 'Thử lại nhé';
    }
  }

  String get emoji {
    switch (this) {
      case ShadowingGrade.excellent: return '🌟';
      case ShadowingGrade.good: return '👍';
      case ShadowingGrade.fair: return '😊';
      case ShadowingGrade.needsWork: return '💪';
      case ShadowingGrade.tryAgain: return '🔄';
    }
  }

  Color get color {
    switch (this) {
      case ShadowingGrade.excellent: return const Color(0xFFFFD700);
      case ShadowingGrade.good: return const Color(0xFF4CAF50);
      case ShadowingGrade.fair: return const Color(0xFF2196F3);
      case ShadowingGrade.needsWork: return const Color(0xFFFF9800);
      case ShadowingGrade.tryAgain: return const Color(0xFFF44336);
    }
  }
}

/// Cài đặt shadowing
class ShadowingSettings {
  final double gapDuration;        // Thời gian chờ trước khi ghi âm (giây)
  final double maxRecordDuration;  // Thời gian ghi tối đa (giây)
  final bool autoStopOnSilence;    // Tự động dừng khi im lặng
  final bool showRealTimeWaveform; // Hiển thị sóng âm real-time
  final bool playBeepOnStart;      // Phát tiếng beep khi bắt đầu ghi
  final int countdownSeconds;      // Số giây đếm ngược

  // NEW (optional)
  final int repeatCount;
  final double playbackSpeed;

  const ShadowingSettings({
    this.gapDuration = 2.0,
    this.maxRecordDuration = 30.0,
    this.autoStopOnSilence = true,
    this.showRealTimeWaveform = true,
    this.playBeepOnStart = true,
    this.countdownSeconds = 3,

    // NEW defaults
    this.repeatCount = 3,
    this.playbackSpeed = 1.0,
  });

  ShadowingSettings copyWith({
    double? gapDuration,
    double? maxRecordDuration,
    bool? autoStopOnSilence,
    bool? showRealTimeWaveform,
    bool? playBeepOnStart,
    int? countdownSeconds,
    // NEW
    int? repeatCount,
    double? playbackSpeed,
  }) {
    return ShadowingSettings(
      gapDuration: gapDuration ?? this.gapDuration,
      maxRecordDuration: maxRecordDuration ?? this.maxRecordDuration,
      autoStopOnSilence: autoStopOnSilence ?? this.autoStopOnSilence,
      showRealTimeWaveform: showRealTimeWaveform ?? this.showRealTimeWaveform,
      playBeepOnStart: playBeepOnStart ?? this.playBeepOnStart,
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
    );
  }
}