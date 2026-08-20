/// ═══════════════════════════════════════════════════════════════
/// ATTENTION SCORE v1 — ranking deterministic theo mục 5 bàn giao
///
///   score(unit, context) =
///       w1 * isWeakInCurrentGoalSkill(unit)      // 0 hoặc 1
///     + w2 * isDueOrOverdue(unit)                // 0 hoặc 1, overdue
///     + w3 * appearsInCurrentSource(unit)        //     cộng hệ số ngày trễ
///     + w4 * recentInteractionCount(unit, 7 ngày)
///
///   w1=0.4, w2=0.3, w3=0.2, w4=0.1  — khởi điểm, cho phép tune sau.
///
/// GHI CHÚ NGHĨA (quy ước v1, có const để tune):
///  * isWeakInCurrentGoalSkill: chưa có LearningState (chưa promote)
///    ⇒ 1; có state ⇒ 1 khi interval của skill-mục-tiêu còn mỏng
///    (< kWeakSkillIntervalDays) hoặc chưa đủ l repetitions.
///  * isDueOrOverdue: dueDate ≤ now ⇒ 1; trễ bao nhiêu ngày thì cộng
///    thêm hệ số tăng dần, chặn ở kOverdueBoostMax (×1.5 của w2) để
///    ranking không bị một từ trễ lâu nuốt mất hết trật tự.
///  * recentInteractionCount: đếm LearningAction 7 ngày gần nhất,
///    CHUẨN HÓA về [0,1] theo ngưỡng bão hòa kRecentInteractionCap
///    (w4 * count thô sẽ cho >1.0 và phá trật tự — quy ước bền hơn).
///  * Đây là CÔNG THỨC deterministic — không phải neural attention
///    (glossary mục 1: gọi đúng tên "Attention Score").
///
/// Lý do (reason) buộc cụ thể theo tiêu chí — kiểu:
///   "Gợi ý vì bạn nghe từ này chưa vững, đã đến hạn ôn tập (trễ 5 ngày),
///    và nó vừa xuất hiện trong bài đang nghe."
/// KHÔNG BAO GIỜ xuất "AI đề xuất" mơ hồ.
///
/// Thuần, immutable, JSON-able — chạy được trong worker isolate (mục 4).
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:in4up/knowledge/models/learning_state.dart'
    show LearningState, SkillDimension;

/// Trọng số khởi điểm (mục 5).
const double kAttentionW1 = 0.4;
const double kAttentionW2 = 0.3;
const double kAttentionW3 = 0.2;
const double kAttentionW4 = 0.1;

/// Interval còn mỏng hơn ngưỡng này ⇒ "yếu" ở skill mục tiêu.
const int kWeakSkillIntervalDays = 7;

/// Trễ nhiều ngày ⇒ hệ số tăng dần, chặn ở ×kOverdueBoostMax của w2.
const double kOverdueBoostPerDay = 0.1;
const double kOverdueBoostMax = 1.5;

/// Bão hòa đếm tương tác gần đây (chuẩn hóa về [0,1]).
const int kRecentInteractionCap = 5;

/// Đầu vào cho một unit cần chấm điểm.
class AttentionInput {
  final String unitId;

  /// Null khi unit chưa promote (chưa có SRS) — coi là yếu ở goal skill.
  final LearningState? state;

  /// Skill mục tiêu của phiên hiện tại (null ⇒ không chấm w1).
  final SkillDimension? goalSkill;

  /// Unit có xuất hiện trong nguồn đang mở không (0/1 của w3).
  final bool appearsInCurrentSource;

  /// Số LearningAction trong 7 ngày gần nhất.
  final int recentInteractionCount;

  const AttentionInput({
    required this.unitId,
    this.state,
    this.goalSkill,
    this.appearsInCurrentSource = false,
    this.recentInteractionCount = 0,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'unitId': unitId,
        'state': state?.toJson(),
        'goalSkill': goalSkill?.name,
        'appearsInCurrentSource': appearsInCurrentSource,
        'recentInteractionCount': recentInteractionCount,
      };

  factory AttentionInput.fromJson(Map<String, dynamic> json) {
    final stateRaw = json['state'];
    final goalRaw = json['goalSkill'];
    return AttentionInput(
      unitId: json['unitId'] as String,
      state: stateRaw == null
          ? null
          : LearningState.fromJson(stateRaw as Map<String, dynamic>),
      goalSkill: goalRaw == null
          ? null
          : SkillDimension.values
              .firstWhere((s) => s.name == goalRaw),
      appearsInCurrentSource:
          json['appearsInCurrentSource'] as bool? ?? false,
      recentInteractionCount: json['recentInteractionCount'] as int? ?? 0,
    );
  }
}

/// Kết quả chấm điểm một unit.
class AttentionResult {
  final String unitId;
  final double score;

  /// Lý do cụ thể (tiêu chí nào bắn) — cho UI hiển thị.
  final String reason;

  /// Chi tiết từng thành phần (debug/tune) — deterministic.
  final Map<String, double> breakdown;

  const AttentionResult({
    required this.unitId,
    required this.score,
    required this.reason,
    required this.breakdown,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'unitId': unitId,
        'score': score,
        'reason': reason,
        'breakdown': breakdown,
      };

  factory AttentionResult.fromJson(Map<String, dynamic> json) =>
      AttentionResult(
        unitId: json['unitId'] as String,
        score: (json['score'] as num).toDouble(),
        reason: json['reason'] as String,
        breakdown: Map<String, double>.from(
            json['breakdown'] as Map<String, dynamic>),
      );
}

String _skillLabel(SkillDimension skill) {
  switch (skill) {
    case SkillDimension.understanding:
      return 'hiểu';
    case SkillDimension.listening:
      return 'nghe';
    case SkillDimension.reading:
      return 'đọc';
  }
}

/// Bộ chấm điểm + xếp hạng — thuần chức năng.
class AttentionRanker {
  AttentionRanker._();

  /// Chấm 1 unit (mục 5). [now] tiêm để deterministic.
  static AttentionResult score(AttentionInput input, {DateTime? now}) {
    final at = now ?? DateTime.now();
    final parts = <String, double>{};
    final reasons = <String>[];

    // ── w1: yếu ở skill mục tiêu ──
    final goal = input.goalSkill;
    var weak = 0.0;
    if (goal != null) {
      final state = input.state;
      if (state == null) {
        weak = 1.0;
        reasons.add('từ này chưa được luyện ($goal chưa có tiến độ)');
      } else {
        final skill = state.skill(goal);
        final isWeak =
            skill.interval < kWeakSkillIntervalDays || skill.repetitions < 2;
        if (isWeak) {
          weak = 1.0;
          reasons.add('bạn ${_skillLabel(goal)} từ này chưa vững');
        }
      }
    }
    parts['w1_weak'] = kAttentionW1 * weak;

    // ── w2: đến hạn / trễ hạn ──
    var due = 0.0;
    final state = input.state;
    if (state != null) {
      DateTime? nearest;
      for (final dim in SkillDimension.values) {
        final d = state.skill(dim).dueDate;
        if (nearest == null || d.isBefore(nearest)) {
          nearest = d;
        }
      }
      if (nearest != null && !nearest.isAfter(at)) {
        final overdueDays = at.difference(nearest).inDays;
        var boost = 1.0 + overdueDays * kOverdueBoostPerDay;
        if (boost > kOverdueBoostMax) boost = kOverdueBoostMax;
        due = boost;
        if (overdueDays > 0) {
          reasons.add('đã đến hạn ôn tập (trễ $overdueDays ngày)');
        } else {
          reasons.add('đã đến hạn ôn tập');
        }
      }
    }
    parts['w2_due'] = kAttentionW2 * due;

    // ── w3: xuất hiện trong nguồn đang mở ──
    final appears = input.appearsInCurrentSource ? 1.0 : 0.0;
    if (appears > 0) {
      reasons.add('vừa xuất hiện trong bài đang mở');
    }
    parts['w3_appears'] = kAttentionW3 * appears;

    // ── w4: tương tác gần đây (chuẩn hóa, bão hòa) ──
    final count = input.recentInteractionCount < 0
        ? 0
        : input.recentInteractionCount;
    final normalized =
        count >= kRecentInteractionCap ? 1.0 : count / kRecentInteractionCap;
    if (count > 0) {
      reasons.add('bạn đã tương tác $count lần trong 7 ngày qua');
    }
    parts['w4_recent'] = kAttentionW4 * normalized;

    final score = parts['w1_weak']! +
        parts['w2_due']! +
        parts['w3_appears']! +
        parts['w4_recent']!;

    // Ghép lý do: "Gợi ý vì A, B, và C." — cụ thể, không mơ hồ (mục 5+1).
    var reason = 'Không có tiêu chí nào bắn.';
    if (reasons.isNotEmpty) {
      final joined = reasons.length == 1
          ? reasons.single
          : '${reasons.sublist(0, reasons.length - 1).join(', ')}'
              ' và ${reasons.last}';
      reason = 'Gợi ý vì $joined.';
    }

    return AttentionResult(
      unitId: input.unitId,
      score: score,
      reason: reason,
      breakdown: parts,
    );
  }

  /// Xếp hạng giảm dần; bằng điểm ⇒ ổn định theo unitId (deterministic).
  static List<AttentionResult> rank(
    List<AttentionInput> inputs, {
    DateTime? now,
  }) {
    final results = [
      for (final input in inputs) score(input, now: now),
    ]..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        return a.unitId.compareTo(b.unitId);
      });
    return List<AttentionResult>.unmodifiable(results);
  }
}
