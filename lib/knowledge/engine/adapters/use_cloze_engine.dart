/// ═══════════════════════════════════════════════════════════════
/// USE CLOZE ENGINE — câu thiếu từ, điền dạng (ADR-0018 §2, P3)
///
/// Sub-test sentence: cloze điền dạng. Câu thiếu từ, user điền đúng dạng.
/// Deterministic, local-first (ADR-0021 §3).
///
/// Collocation KHÔNG có dữ liệu repo → Phase 2 (ADR-0018 §3).
/// ═══════════════════════════════════════════════════════════════
library;

/// 1 item cloze: câu có chỗ trống + đáp án đúng + dạng cần điền.
class ClozeItem {
  final String sentence; // câu có chỗ trống (___)
  final String answer; // từ cần điền
  final String? formType; // dạng cần (plural/past/gerund/...) — null = gốc

  const ClozeItem({
    required this.sentence,
    required this.answer,
    this.formType,
  });

  /// Câu hoàn chỉnh (điền đáp án).
  String get filled => sentence.replaceAll('___', answer);
}

/// Kết quả chấm cloze.
class UseClozeResult {
  final ClozeItem item;
  final String userAnswer;
  final bool isCorrect;

  const UseClozeResult({
    required this.item,
    required this.userAnswer,
    required this.isCorrect,
  });

  @override
  String toString() =>
      'UseCloze(user: $userAnswer, correct: $isCorrect, expected: ${item.answer})';
}

/// Engine cloze — deterministic.
class UseClozeEngine {
  UseClozeEngine._();

  /// Kiểm tra user answer có đúng đáp án?
  /// Normalize (lowercase, bỏ dấu) trước khi so sánh.
  static UseClozeResult check({
    required ClozeItem item,
    required String userAnswer,
  }) {
    final normalized = _normalize(userAnswer);
    final expected = _normalize(item.answer);
    final isCorrect = normalized == expected;
    return UseClozeResult(
      item: item,
      userAnswer: userAnswer,
      isCorrect: isCorrect,
    );
  }

  /// Sinh câu cloze từ 1 từ + ngữ cảnh mẫu.
  ///
  /// [word] từ cần điền.
  /// [formType] dạng cần (plural/past/gerund/...) — null = gốc.
  /// [template] mẫu câu (có ___).
  static ClozeItem createItem({
    required String word,
    required String template,
    String? formType,
  }) {
    return ClozeItem(
      sentence: template,
      answer: word,
      formType: formType,
    );
  }

  static String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r"[^a-z0-9']"), '').trim();
}
