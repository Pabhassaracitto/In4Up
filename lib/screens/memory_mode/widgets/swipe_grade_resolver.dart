// lib/screens/memory_mode/widgets/swipe_grade_resolver.dart
//
// PSRC-197 — tách phần "timer ngầm" (đọc vị tốc độ phản hồi khi vuốt) khỏi
// widget để test được bằng logic thuần, không cần widget test.
//
// Ngữ nghĩa GIỮ NGUYÊN như bản cũ trong `flashcard_presenter.dart`:
//   • vuốt PHẢI: ≤3s → Dễ, lâu hơn → Nhớ
//   • vuốt TRÁI: ≤2s → Khó, lâu hơn → Quên
//   • vuốt LÊN: thuộc lòng · vuốt XUỐNG: hoãn học (không phụ thuộc thời gian)

import '../models/review_session.dart';

class SwipeGradeResolver {
  const SwipeGradeResolver._();

  static const Duration easyWindow = Duration(seconds: 3);
  static const Duration hardWindow = Duration(seconds: 2);

  /// [elapsed] là thời gian thẻ hiện tại đã hiện (kể từ lúc đổi thẻ).
  static ReviewGrade resolve(SwipeDirection direction, Duration elapsed) {
    switch (direction) {
      case SwipeDirection.right:
        return elapsed > easyWindow ? ReviewGrade.good : ReviewGrade.easy;
      case SwipeDirection.left:
        return elapsed > hardWindow ? ReviewGrade.forgot : ReviewGrade.hard;
      case SwipeDirection.up:
        return ReviewGrade.retired;
      case SwipeDirection.down:
        return ReviewGrade.snoozed;
    }
  }
}
