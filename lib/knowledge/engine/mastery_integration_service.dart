/// ═══════════════════════════════════════════════════════════════
/// MASTERY INTEGRATION SERVICE — event → SM-2 + EMA → Mastery (P4)
///
/// Thay vì SM-2 vừa quyết định lịch ôn vừa ảnh hưởng mastery trực tiếp,
/// service này TÁCH BIỆT:
///   1. SM-2 (via LearningState.withSkill) — chỉ quyết định lịch ôn.
///   2. EMA (via MasteryVector.update/updateUse) — chỉ cập nhật mastery.
///
/// Một event review vừa ghi ReviewEvent (cho SM-2) vừa cập nhật
/// MasteryVector (cho EMA) — ADR-0016 §1.
///
/// Thuần chức năng — không I/O, deterministic, test đơn giản.
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:in4up/knowledge/engine/ema_engine.dart'
    show MasteryVector, kDefaultEmaAlpha;
import 'package:in4up/knowledge/models/evidence_metadata.dart';
import 'package:in4up/knowledge/models/learning_state.dart'
    show LearningState, SM2Snapshot, SkillDimension, kSm2AlgorithmVersion;
import 'package:in4up/knowledge/models/use_sub_test.dart' show UseSubTestType;
import 'package:in4up/models/sm2_algorithm.dart' show SM2Algorithm;

/// Kết quả tích hợp: cả LearningState (SM-2) và MasteryVector (EMA) mới.
class MasteryIntegrationResult {
  final LearningState learningState;
  final MasteryVector masteryVector;

  const MasteryIntegrationResult({
    required this.learningState,
    required this.masteryVector,
  });

  @override
  String toString() =>
      'Integration(unit: ${learningState.unitId}, mv: ${masteryVector.useDisplay.toStringAsFixed(2)}/${masteryVector.speak.toStringAsFixed(2)})';
}

/// Service tích hợp — thuần chức năng.
class MasteryIntegrationService {
  MasteryIntegrationService._();

  /// Tích hợp 1 review event: SM-2 + EMA.
  ///
  /// [state] LearningState hiện tại (SM-2 snapshots).
  /// [mastery] MasteryVector hiện tại (EMA values).
  /// [dim] trục kỹ năng đã review.
  /// [quality] q nguyên 0–5.
  /// [evidence] metadata (assistance, confidence, gradedBy).
  /// [subTest] sub-test type cho trục Dùng (null = không phải Dùng).
  ///
  /// Trả Result với cả state và mastery đã cập nhật.
  static MasteryIntegrationResult integrate({
    required LearningState state,
    required MasteryVector mastery,
    required SkillDimension dim,
    required int quality,
    required EvidenceMetadata evidence,
    UseSubTestType? subTest,
    double alpha = kDefaultEmaAlpha,
    DateTime? now,
  }) {
    assert(quality >= 0 && quality <= 5, 'quality phải 0..5');
    final scoreNor = (quality / 5.0).clamp(0.0, 1.0);
    final at = now ?? DateTime.now();

    // ── 1. SM-2: tính lịch ôn mới ──
    // SM2Algorithm.calculate qua LearningState.withSkill.
    // Dùng SM2Snapshot.initial + apply SM-2 logic.
    // (SM-2 chỉ quyết định interval/EF — không ảnh hưởng mastery score.)
    final newSnapshot = _applySm2(
      state.skill(dim),
      quality,
      at,
    );
    final newState = state.withSkill(
      dim,
      newSnapshot,
      lastReviewEventId: '', // sẽ gán ở layer cao hơn
    );

    // ── 2. EMA: cập nhật mastery vector ──
    final newMastery = _applyEma(
      mastery,
      dim,
      scoreNor,
      evidence,
      subTest,
      alpha,
    );

    return MasteryIntegrationResult(
      learningState: newState,
      masteryVector: newMastery,
    );
  }

  /// Áp SM-2 cho 1 snapshot — dùng SM2Algorithm.calculate.
  static SM2Snapshot _applySm2(
    SM2Snapshot current,
    int quality,
    DateTime at,
  ) {
    // Import SM2Algorithm tại đây để tránh circular dependency.
    // SM2Algorithm.calculate returns SM2Result.
    // Đây là hàm SM-2 DUY NHẤT (ADR-0001).
    // (Implementation note: SM2Algorithm được import ở file này.)
    final result = SM2Algorithm.calculate(
      quality: quality,
      currentEF: current.easeFactor,
      currentInterval: current.interval,
      currentReps: current.repetitions,
      now: at,
    );
    return SM2Snapshot(
      easeFactor: result.easeFactor,
      interval: result.interval,
      repetitions: result.repetitions,
      dueDate: result.nextReview,
      lastReviewedAt: at,
      algorithmVersion: kSm2AlgorithmVersion,
    );
  }

  /// Áp EMA cho mastery vector.
  static MasteryVector _applyEma(
    MasteryVector mastery,
    SkillDimension dim,
    double scoreNor,
    EvidenceMetadata evidence,
    UseSubTestType? subTest,
    double alpha,
  ) {
    if (dim == SkillDimension.use) {
      // Trục Dùng — cần subTest type.
      final st = subTest ?? UseSubTestType.inflection;
      return mastery.updateUse(
        subTest: st,
        scoreNor: scoreNor,
        evidence: evidence,
        alpha: alpha,
      );
    }
    return mastery.update(
      dim: dim,
      scoreNor: scoreNor,
      evidence: evidence,
      alpha: alpha,
    );
  }

  /// Tích hợp batch: nhiều event → nhiều result.
  /// Dùng cho performance test (1000 từ ≤60ms).
  static List<MasteryIntegrationResult> integrateBatch({
    required List<LearningState> states,
    required List<MasteryVector> masteries,
    required List<SkillDimension> dims,
    required List<int> qualities,
    required List<EvidenceMetadata> evidences,
    double alpha = kDefaultEmaAlpha,
    DateTime? now,
  }) {
    final results = <MasteryIntegrationResult>[];
    final at = now ?? DateTime.now();
    for (var i = 0; i < states.length; i++) {
      results.add(integrate(
        state: states[i],
        mastery: masteries[i],
        dim: dims[i],
        quality: qualities[i],
        evidence: evidences[i],
        alpha: alpha,
        now: at,
      ));
    }
    return results;
  }
}
