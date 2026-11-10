import 'memory_item.dart';
import 'review_session.dart';

/// Garden actions reuse the Memory Mode review scheduler (ADR-0001).
/// Both failed-recall labels are genuine failures; neither is treated as a
/// correct Hard response. Good and Easy currently share the same schedule.
enum GardenRating {
  again('Lại', ReviewGrade.forgot),
  forgot('Quên', ReviewGrade.forgot),
  good('Ổn', ReviewGrade.good),
  easy('Giỏi', ReviewGrade.easy);

  const GardenRating(this.label, this.grade);
  final String label;
  final ReviewGrade grade;

  MemoryItem apply(MemoryItem item) => grade == ReviewGrade.forgot
      ? item.markIncorrect()
      : item.markCorrect();
}
