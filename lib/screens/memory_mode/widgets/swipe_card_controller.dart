// Logic tách riêng khỏi UI để dễ test

import '../models/review_session.dart';

class SwipeCardController {
  // ── Timer tracking ──
  DateTime? _cardShownAt;

  void onCardShown() {
    _cardShownAt = DateTime.now();
  }

  Duration get responseTime {
    if (_cardShownAt == null) return const Duration(seconds: 99);
    return DateTime.now().difference(_cardShownAt!);
  }

  // ── Swipe → Grade mapping với timer ngầm ──
  ReviewGrade resolveGrade(SwipeDirection direction) {
    final seconds = responseTime.inSeconds;

    switch (direction) {
      case SwipeDirection.right:
        // Nhớ: phân biệt Easy vs Good bằng thời gian
        return seconds <= 3 ? ReviewGrade.easy : ReviewGrade.good;

      case SwipeDirection.left:
        // Quên: phân biệt Hard vs Forgot bằng thời gian
        // < 2s: nhớ mang máng rồi quên ngay → Hard
        // > 2s: suy nghĩ lâu vẫn không ra → Forgot
        return seconds <= 2 ? ReviewGrade.hard : ReviewGrade.forgot;

      case SwipeDirection.up:
        return ReviewGrade.retired; // Luôn là retired

      case SwipeDirection.down:
        return ReviewGrade.snoozed; // Luôn là snoozed
    }
  }

  // ── Snooze duration theo số lần snoozed ──
  int getSnoozeDays(int snoozeCount) {
    // Snooze nhiều lần → thời gian hoãn tăng dần
    if (snoozeCount <= 1) return 7;
    if (snoozeCount <= 3) return 14;
    return 30;
  }
}
