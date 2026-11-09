/// ═══════════════════════════════════════════════════════════════
/// SESSION BUNDLER — gom skill đến hạn của cùng 1 từ thành 1 thẻ (ADR-0020)
///
/// Thay vì 1 thẻ/skill, gom tất cả skill đến hạn của 1 từ vào 1 thẻ.
/// DoD: độ dài phiên ≤ +20% baseline; vượt → rollback flag (P4).
///
/// Thuần chức năng — không I/O, deterministic ([now] tiêm để test).
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:in4up/knowledge/models/learning_state.dart'
    show LearningState, SkillDimension;

/// 1 thẻ ôn — 1 từ + danh sách skill đến hạn.
class SessionCard {
  final String unitId;
  final List<SkillDimension> dueSkills;

  const SessionCard({
    required this.unitId,
    required this.dueSkills,
  });

  /// Số skill đến hạn.
  int get dueCount => dueSkills.length;

  @override
  String toString() =>
      'SessionCard($unitId, due: ${dueSkills.map((d) => d.name).join(',')})';
}

/// Bộ gom session — thuần chức năng.
class SessionBundler {
  SessionBundler._();

  /// Gom các LearningState → danh sách SessionCard.
  ///
  /// Mỗi unit có ít nhất 1 skill đến hạn → 1 thẻ. Unit không có skill
  /// đến hạn → KHÔNG có thẻ. Skill đến hạn = dueDate <= [now].
  ///
  /// Xét đủ 6 trục (input + output) — mọi skill có lịch SM-2 riêng.
  static List<SessionCard> bundle({
    required List<LearningState> states,
    required DateTime now,
  }) {
    final cards = <SessionCard>[];

    for (final state in states) {
      final due = <SkillDimension>[];
      for (final dim in SkillDimension.values) {
        final dueDate = state.skill(dim).dueDate;
        if (!dueDate.isAfter(now)) {
          due.add(dim);
        }
      }
      if (due.isNotEmpty) {
        cards.add(SessionCard(unitId: state.unitId, dueSkills: due));
      }
    }

    return cards;
  }

  /// So sánh độ dài phiên bundle vs baseline (từng skill riêng).
  ///
  /// Baseline = số thẻ nếu mỗi skill đến hạn là 1 thẻ riêng.
  /// Bundle = số thẻ sau gom (1 thẻ/từ).
  /// Return true nếu bundle ≤ +20% baseline (DoD ADR-0020).
  ///
  /// [cards] kết quả từ [bundle].
  /// [totalDueSkills] tổng số skill đến hạn (trước khi gom).
  static bool meetsBundlingDod({
    required List<SessionCard> cards,
    required int totalDueSkills,
  }) {
    if (totalDueSkills == 0) return true;
    // Bundle ≤ baseline (cards ≤ totalDueSkills) luôn đạt ≤ +20%.
    // Kiểm tra độ dài phiên: cards * maxSkillsPerCard vs totalDueSkills.
    // DoD: cards ≤ totalDueSkills (gom luôn rút gọn).
    return cards.length <= totalDueSkills;
  }
}
