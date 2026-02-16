// lib/screens/memory_mode/models/review_session.dart

enum ReviewGrade {
  forgot,
  hard,
  good,
  easy,
}

extension ReviewGradeExtension on ReviewGrade {
  String get label {
    switch (this) {
      case ReviewGrade.forgot:
        return 'Quên';
      case ReviewGrade.hard:
        return 'Khó';
      case ReviewGrade.good:
        return 'Nhớ';
      case ReviewGrade.easy:
        return 'Dễ';
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
