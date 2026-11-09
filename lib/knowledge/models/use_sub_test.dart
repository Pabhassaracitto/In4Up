/// ═══════════════════════════════════════════════════════════════
/// USE SUB-TEST TYPE — phân loại task trục Dùng (ADR-0018)
///
/// Trục Dùng = tổng hợp 2 sub-test:
///   * form/morphology (inflection) — rule-based, deterministic, local-first.
///   * sentence (cloze) — điền dạng, deterministic, local-first.
///
/// Phase 1 chỉ bật 2 sub-test đầu. Collocation + AI sentence = Phase 2.
/// Sub-test KHÔNG có rule/bằng chứng → KHÔNG hiện, KHÔNG tính là 0 (ADR-0018 §4).
/// ═══════════════════════════════════════════════════════════════
library;

/// Loại sub-test của trục Dùng. Mỗi event Dùng mang đúng 1 subTestType.
enum UseSubTestType {
  /// Dạng từ (inflection) — plural/3sg, past/pp, comparative/superlative,
  /// gerund. Rule có sẵn trong `grammar_lexicon_service`.
  inflection,

  /// Câu thiếu từ, điền dạng đúng (cloze). Deterministic, local-first.
  clozeSentence,

  /// Kết hợp từ (collocation) — Phase 2 (không có dữ liệu repo Phase 1).
  collocation,

  /// Đánh giá câu bằng AI — Phase 2, premium, cần consent.
  aiSentence,
}

extension UseSubTestTypeInfo on UseSubTestType {
  /// Sub-test thuộc nhóm form (dạng từ) hay sentence (câu).
  /// → map vào EMA con useForm / useSentence (ADR-0018 §4).
  bool get isForm => this == UseSubTestType.inflection;
  bool get isSentence => this == UseSubTestType.clozeSentence ||
      this == UseSubTestType.collocation ||
      this == UseSubTestType.aiSentence;

  /// Phase 1 chỉ nhận 2 sub-test đầu; collocation/aiSentence = Phase 2.
  bool get isPhase1 => this == UseSubTestType.inflection ||
      this == UseSubTestType.clozeSentence;
}
