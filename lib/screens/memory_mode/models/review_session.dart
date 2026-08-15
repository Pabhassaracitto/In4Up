// lib/screens/memory_mode/models/review_session.dart

enum ReviewGrade {
  forgot,
  hard,
  good,
  easy,
  retired, // ← THÊM: Vuốt lên - đã thuộc lòng
  snoozed, // ← THÊM: Vuốt xuống - hoãn học
}

extension ReviewGradeExtension on ReviewGrade {
  String get label {
    switch (this) {
      case ReviewGrade.forgot:
        return 'Content';
      case ReviewGrade.hard:
        return 'Content';
      case ReviewGrade.good:
        return 'Remember';
      case ReviewGrade.easy:
        return 'Content';
      case ReviewGrade.retired:
        return 'Content'; // ← THÊM
      case ReviewGrade.snoozed:
        return 'Content'; // ← THÊM
    }
  }

  String get emoji {
    switch (this) {
      case ReviewGrade.forgot:
        return '😵';
      case ReviewGrade.hard:
        return '😓';
      case ReviewGrade.good:
        return '😊';
      case ReviewGrade.easy:
        return '😎';
      case ReviewGrade.retired:
        return '⭐'; // ← THÊM
      case ReviewGrade.snoozed:
        return '💤'; // ← THÊM
    }
  }

  int get buttonColor {
    switch (this) {
      case ReviewGrade.forgot:
        return 0xFFF44336;
      case ReviewGrade.hard:
        return 0xFFFF9800;
      case ReviewGrade.good:
        return 0xFF4CAF50;
      case ReviewGrade.easy:
        return 0xFF2196F3;
      case ReviewGrade.retired:
        return 0xFFFFD700; // ← THÊM vàng
      case ReviewGrade.snoozed:
        return 0xFF9E9E9E; // ← THÊM xám
    }
  }

  // ← THÊM: Mapping grade → swipe direction (để UI hiển thị hint)
  SwipeDirection? get swipeDirection {
    switch (this) {
      case ReviewGrade.forgot:
        return SwipeDirection.left;
      case ReviewGrade.hard:
        return SwipeDirection.left;
      case ReviewGrade.good:
        return SwipeDirection.right;
      case ReviewGrade.easy:
        return SwipeDirection.right;
      case ReviewGrade.retired:
        return SwipeDirection.up;
      case ReviewGrade.snoozed:
        return SwipeDirection.down;
    }
  }
}

class ReviewSession {
  final String id;
  final DateTime startedAt;
  final DateTime? completedAt;
  final List<ReviewRecord> records;
  final ReviewMode mode;

  const ReviewSession({
    required this.id,
    required this.startedAt,
    this.completedAt,
    this.records = const [],
    this.mode = ReviewMode.spaced,
  });

  int get totalCards => records.length;
  int get correctCards => records
      .where(
        (r) => r.grade == ReviewGrade.good || r.grade == ReviewGrade.easy,
      )
      .length;
  int get incorrectCards =>
      records.where((r) => r.grade == ReviewGrade.forgot).length;

  double get accuracy => totalCards > 0 ? correctCards / totalCards : 0.0;

  Duration get duration {
    if (completedAt == null) return Duration.zero;
    return completedAt!.difference(startedAt);
  }
}

class ReviewRecord {
  final String itemId;
  final ReviewGrade grade;
  final Duration responseTime;
  final DateTime timestamp;

  const ReviewRecord({
    required this.itemId,
    required this.grade,
    required this.responseTime,
    required this.timestamp,
  });
}

enum ReviewMode {
  spaced,
  cram,
  stage,
  difficult,
  random,
}

enum SwipeDirection { left, right, up, down }