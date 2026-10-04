/// ═══════════════════════════════════════════════════════════════
///  SM-2 ALGORITHM (SuperMemo 2)
///  
///  Thuật toán Spaced Repetition chuẩn Anki
///  
///  Quality (q): 0-5
///    0-2: Fail (reset)
///    3: Hard (repeat soon)
///    4: Good (normal interval)
///    5: Easy (longer interval)
///  
///  EaseFactor (EF): >= 1.3, default 2.5
///  Interval: số ngày đến lần review tiếp
/// ═══════════════════════════════════════════════════════════════
library;

class SM2Result {
  final double easeFactor;
  final int interval;
  final int repetitions;
  final DateTime nextReview;

  const SM2Result({
    required this.easeFactor,
    required this.interval,
    required this.repetitions,
    required this.nextReview,
  });
}

class SM2Algorithm {
  /// Tính toán lịch review tiếp theo
  /// 
  /// [quality]: 0-5 (0-2: fail, 3: hard, 4: good, 5: easy)
  /// [currentEF]: EaseFactor hiện tại (default 2.5)
  /// [currentInterval]: Interval hiện tại (ngày)
  /// [currentReps]: Số lần đã nhớ đúng liên tiếp
  static SM2Result calculate({
    required int quality,
    double currentEF = 2.5,
    int currentInterval = 0,
    int currentReps = 0,
  }) {
    assert(quality >= 0 && quality <= 5);

    double newEF = currentEF;
    int newInterval;
    int newReps;

    if (quality < 3) {
      // ══ FAIL: Reset về đầu ══
      newReps = 0;
      newInterval = 1;
      // Giảm EF nhưng không dưới 1.3
      newEF = (currentEF - 0.2).clamp(1.3, 2.5);
    } else {
      // ══ PASS: Tăng interval ══
      newReps = currentReps + 1;

      if (newReps == 1) {
        newInterval = 1;
      } else if (newReps == 2) {
        newInterval = 6;
      } else {
        newInterval = (currentInterval * currentEF).round();
      }

      // Cập nhật EaseFactor
      newEF = currentEF + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
      newEF = newEF.clamp(1.3, 2.5);

      // Bonus cho quality cao
      if (quality == 5) {
        newInterval = (newInterval * 1.3).round();
      } else if (quality == 3) {
        newInterval = (newInterval * 0.8).round().clamp(1, newInterval);
      }
    }

    final nextReview = DateTime.now().add(Duration(days: newInterval));

    return SM2Result(
      easeFactor: newEF,
      interval: newInterval,
      repetitions: newReps,
      nextReview: nextReview,
    );
  }

  /// Chuyển đổi điểm 0-1 thành quality 0-5
  static int scoreToQuality(double score, bool remembered) {
    if (!remembered) {
      return score < 0.3 ? 0 : (score < 0.5 ? 1 : 2);
    }
    if (score >= 0.9) return 5; // Easy
    if (score >= 0.7) return 4; // Good
    return 3; // Hard
  }

  /// Kiểm tra từ có cần review không
  static bool isDue(DateTime? nextReview) {
    if (nextReview == null) return true;
    return DateTime.now().isAfter(nextReview) || 
           DateTime.now().difference(nextReview).inHours.abs() < 12;
  }

  /// Tính độ ưu tiên review (số âm = overdue)
  static int daysUntilDue(DateTime? nextReview) {
    if (nextReview == null) return -999;
    return nextReview.difference(DateTime.now()).inDays;
  }
}
