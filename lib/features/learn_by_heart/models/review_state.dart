import 'package:flutter/material.dart';

/// Trạng thái học tập theo chu kỳ SRS / FSRS
enum ReviewState {
  /// Bài mới, chưa bắt đầu học
  newItem,

  /// Đang trong quá trình học mới / cuốn chiếu
  learning,

  /// Đang trong chu kỳ ôn tập ngắt quãng (Spaced Repetition)
  review,

  /// Đã quên (cần ôn tập lại gấp)
  lapse,

  /// Đang ôn tập lại sau khi quên
  relearning,
}

extension ReviewStateExtension on ReviewState {
  String get displayName {
    switch (this) {
      case ReviewState.newItem:
        return 'Mới';
      case ReviewState.learning:
        return 'Đang học';
      case ReviewState.review:
        return 'Đang ôn';
      case ReviewState.lapse:
        return 'Cần củng cố';
      case ReviewState.relearning:
        return 'Học lại';
    }
  }

  Color get color {
    switch (this) {
      case ReviewState.newItem:
        return const Color(0xFF42A5F5); // Blue
      case ReviewState.learning:
        return const Color(0xFFFFB300); // Amber
      case ReviewState.review:
        return const Color(0xFF66BB6A); // Green
      case ReviewState.lapse:
        return const Color(0xFFEF5350); // Red
      case ReviewState.relearning:
        return const Color(0xFFAB47BC); // Purple
    }
  }

  IconData get icon {
    switch (this) {
      case ReviewState.newItem:
        return Icons.fiber_new_rounded;
      case ReviewState.learning:
        return Icons.auto_stories_rounded;
      case ReviewState.review:
        return Icons.psychology_rounded;
      case ReviewState.lapse:
        return Icons.warning_amber_rounded;
      case ReviewState.relearning:
        return Icons.replay_rounded;
    }
  }
}
