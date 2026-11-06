/// ═══════════════════════════════════════════════════════════════
/// EMA ENGINE — Mastery Vector (ADR-0016, patch A′)
///
/// Hai engine tách bạch:
///   * SM-2 (`sm2_algorithm.dart`) — chỉ quyết định LỊCH ÔN (interval/EF).
///   * EMA (bộ này) — chỉ cập nhật MASTERY VECTOR (score ∈ [0,1]).
///
/// Patch A′ (bất đối xứng theo chiều):
///   wasCorrect = q >= 3  →  scoreNor >= 0.6
///   gate       = wasCorrect ? (1.0 - assistance) : 1.0
///   alphaE     = alpha * confidence * gate
///   mastery    = mastery + alphaE * (scoreNor - mastery)
///
/// Dùng (ADR-0018): 2 EMA con useForm/useSentence.
///   Hiển thị Dùng = trung bình sub-test CÓ BẰNG CHỨNG, KHÔNG bù 0.
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:in4up/knowledge/models/evidence_metadata.dart';
import 'package:in4up/knowledge/models/learning_state.dart' show SkillDimension;
import 'package:in4up/knowledge/models/use_sub_test.dart' show UseSubTestType;

/// Alpha EMA mặc định — [P0 calibrate bằng dữ liệu thật].
/// Giá trị placeholder; không phải ngưỡng "đúng" — P4 calibrate.
const double kDefaultEmaAlpha = 0.2;

/// Hàm EMA thuần — patch A′ (ADR-0016 §2).
///
/// [current]  giá trị mastery hiện tại ∈ [0,1].
/// [scoreNor] q/5 ∈ [0,1] (q nguyên 0–5).
/// [assistance] mức độ gợi ý người học ∈ [0,1].
/// [confidence] độ tin cậy bằng chứng ∈ [0,1].
///
/// Bất đối xứng: đúng (scoreNor ≥ 0.6) → assistance làm giảm biên độ;
/// sai → gate = 1 (giữ nguyên cường độ, không bị assistance giảm).
double emaUpdate({
  required double current,
  required double scoreNor,
  required double assistance,
  required double confidence,
  double alpha = kDefaultEmaAlpha,
}) {
  assert(scoreNor >= 0.0 && scoreNor <= 1.0,
      'scoreNor phải nằm trong [0,1]: $scoreNor');
  assert(assistance >= 0.0 && assistance <= 1.0,
      'assistance phải nằm trong [0,1]: $assistance');
  assert(confidence >= 0.0 && confidence <= 1.0,
      'confidence phải nằm trong [0,1]: $confidence');

  final wasCorrect = scoreNor >= 0.6; // q >= 3
  final gate = wasCorrect ? (1.0 - assistance) : 1.0;
  final alphaE = alpha * confidence * gate;
  return current + alphaE * (scoreNor - current);
}

/// ═══════════════════════════════════════════════════════════════
/// MASTERY VECTOR — trạng thái EMA cho 6 trục / 2 nhóm (ADR-0015)
///
/// Input (receptive): understanding, listening, reading — mỗi trục 1 EMA.
/// Output (productive):
///   * speak, write — mỗi trục 1 EMA.
///   * use (Dùng) — 2 EMA con useForm + useSentence (ADR-0018 §4).
///     Hiển thị Dùng = trung bình sub-test có bằng chứng (hasUseForm/
///     hasUseSentence). KHÔNG bù 0 — chỉ có 1 sub-test → nhãn "một phần".
/// ═══════════════════════════════════════════════════════════════
class MasteryVector {
  // ── Input EMA (3 trục) ──
  final double understanding;
  final double listening;
  final double reading;

  // ── Output EMA ──
  /// Nói — phát âm từ đơn.
  final double speak;
  /// Nói đã có bằng chứng? (false = chưa đánh giá, KHÔNG bù 0).
  final bool hasSpeak;
  /// Viết — chính tả từ đơn.
  final double write;
  /// Viết đã có bằng chứng?
  final bool hasWrite;

  // ── Dùng: 2 EMA con (ADR-0018) ──
  /// EMA con form/inflection.
  final double useForm;
  /// Dùng form đã có bằng chứng? (false = chưa đánh giá, KHÔNG bù 0).
  final bool hasUseForm;

  /// EMA con sentence/cloze.
  final double useSentence;
  /// Dùng sentence đã có bằng chứng?
  final bool hasUseSentence;

  const MasteryVector({
    this.understanding = 0.0,
    this.listening = 0.0,
    this.reading = 0.0,
    this.speak = 0.0,
    this.hasSpeak = false,
    this.write = 0.0,
    this.hasWrite = false,
    this.useForm = 0.0,
    this.hasUseForm = false,
    this.useSentence = 0.0,
    this.hasUseSentence = false,
  });

  /// Trạng thái khởi điểm: mọi trục chưa có bằng chứng.
  static const MasteryVector initial = MasteryVector();

  /// Cập nhật EMA cho 1 trục (input hoặc speak/write).
  ///
  /// [dim] trục kỹ năng — use KHÔNG được gọi ở đây (dùng updateUse).
  MasteryVector update({
    required SkillDimension dim,
    required double scoreNor,
    required EvidenceMetadata evidence,
    double alpha = kDefaultEmaAlpha,
  }) {
    assert(dim != SkillDimension.use,
        'use phải dùng updateUse() với subTestType');
    final newValue = emaUpdate(
      current: _byDimension(dim),
      scoreNor: scoreNor,
      assistance: evidence.assistance,
      confidence: evidence.confidence,
      alpha: alpha,
    );
    return _copyDimension(dim, newValue);
  }

  /// Cập nhật EMA con cho trục Dùng (ADR-0018).
  ///
  /// [subTest] loại sub-test → map vào useForm/useSentence.
  MasteryVector updateUse({
    required UseSubTestType subTest,
    required double scoreNor,
    required EvidenceMetadata evidence,
    double alpha = kDefaultEmaAlpha,
  }) {
    if (subTest.isForm) {
      final newValue = emaUpdate(
        current: useForm,
        scoreNor: scoreNor,
        assistance: evidence.assistance,
        confidence: evidence.confidence,
        alpha: alpha,
      );
      return MasteryVector(
        understanding: understanding,
        listening: listening,
        reading: reading,
        speak: speak,
        hasSpeak: hasSpeak,
        write: write,
        hasWrite: hasWrite,
        useForm: newValue,
        hasUseForm: true,
        useSentence: useSentence,
        hasUseSentence: hasUseSentence,
      );
    } else {
      final newValue = emaUpdate(
        current: useSentence,
        scoreNor: scoreNor,
        assistance: evidence.assistance,
        confidence: evidence.confidence,
        alpha: alpha,
      );
      return MasteryVector(
        understanding: understanding,
        listening: listening,
        reading: reading,
        speak: speak,
        hasSpeak: hasSpeak,
        write: write,
        hasWrite: hasWrite,
        useForm: useForm,
        hasUseForm: hasUseForm,
        useSentence: newValue,
        hasUseSentence: true,
      );
    }
  }

  /// Hiển thị Dùng = trung bình sub-test CÓ BẰNG CHỨNG (ADR-0018 §4).
  /// Không bù 0: không sub-test nào → 0.0 + flag [useIsPartial].
  double get useDisplay {
    final parts = <double>[];
    if (hasUseForm) parts.add(useForm);
    if (hasUseSentence) parts.add(useSentence);
    if (parts.isEmpty) return 0.0;
    final sum = parts.fold<double>(0, (a, b) => a + b);
    return sum / parts.length;
  }

  /// Có đúng 1 sub-test → nhãn "một phần" (ADR-0018).
  bool get useIsPartial => (hasUseForm?1:0) + (hasUseSentence?1:0) == 1;

  /// Dùng đã có bằng chứng? (ít nhất 1 sub-test).
  bool get hasUse => hasUseForm || hasUseSentence;

  /// Có bằng chứng output (use/speak/write)? → gate archetype (ADR-0019).
  bool get hasOutputEvidence => hasUse || hasSpeak || hasWrite;

  /// Có bằng chứng input (understanding/listening/reading)?
  bool get hasInputEvidence =>
      understanding > 0 || listening > 0 || reading > 0;

  /// Lấy giá trị EMA theo trục. Với use → useDisplay (hiển thị).
  double valueOf(SkillDimension dim) {
    switch (dim) {
      case SkillDimension.understanding:
        return understanding;
      case SkillDimension.listening:
        return listening;
      case SkillDimension.reading:
        return reading;
      case SkillDimension.use:
        return useDisplay;
      case SkillDimension.speak:
        return speak;
      case SkillDimension.write:
        return write;
    }
  }

  // ── helpers ──
  double _byDimension(SkillDimension dim) => valueOf(dim);

  MasteryVector _copyDimension(SkillDimension dim, double newValue) {
    return MasteryVector(
      understanding: dim == SkillDimension.understanding ? newValue : understanding,
      listening: dim == SkillDimension.listening ? newValue : listening,
      reading: dim == SkillDimension.reading ? newValue : reading,
      speak: dim == SkillDimension.speak ? newValue : speak,
      hasSpeak: dim == SkillDimension.speak ? true : hasSpeak,
      write: dim == SkillDimension.write ? newValue : write,
      hasWrite: dim == SkillDimension.write ? true : hasWrite,
      useForm: useForm,
      hasUseForm: hasUseForm,
      useSentence: useSentence,
      hasUseSentence: hasUseSentence,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MasteryVector &&
      other.understanding == understanding &&
      other.listening == listening &&
      other.reading == reading &&
      other.speak == speak &&
      other.hasSpeak == hasSpeak &&
      other.write == write &&
      other.hasWrite == hasWrite &&
      other.useForm == useForm &&
      other.hasUseForm == hasUseForm &&
      other.useSentence == useSentence &&
      other.hasUseSentence == hasUseSentence;

  @override
  int get hashCode => Object.hash(
        understanding, listening, reading, speak, hasSpeak, write, hasWrite,
        useForm, hasUseForm, useSentence, hasUseSentence,
      );
}
