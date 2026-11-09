/// ═══════════════════════════════════════════════════════════════
/// USE FORM ENGINE — dạng từ / inflection (ADR-0018 §1, P3)
///
/// Sub-test form: rule-based inflection. Chỉ bật rule có sẵn:
/// plural/3sg, past/pp, comparative/superlative, gerund.
///
/// Item không có rule → KHÔNG hiện sub-test, KHÔNG tính là 0 (ADR-0018).
/// Deterministic, local-first (ADR-0021 §3).
/// ═══════════════════════════════════════════════════════════════
library;

/// Loại dạng từ cần kiểm tra.
enum InflectionForm {
  plural,     // số nhiều (cats, boxes, cities)
  thirdPerson, // 3sg (runs, goes, does)
  past,       // quá khứ (walked, used, studied)
  pastParticiple, // participle (walked, used, studied)
  comparative, // so sánh hơn (bigger, fancier)
  superlative, // so sánh nhất (biggest, most)
  gerund,     // danh động từ (running, using, studying)
}

extension InflectionFormLabel on InflectionForm {
  String get label {
    switch (this) {
      case InflectionForm.plural: return 'số nhiều';
      case InflectionForm.thirdPerson: return '3sg';
      case InflectionForm.past: return 'quá khứ';
      case InflectionForm.pastParticiple: return 'participle';
      case InflectionForm.comparative: return 'hơn';
      case InflectionForm.superlative: return 'nhiều nhất';
      case InflectionForm.gerund: return 'gerund';
    }
  }
}

/// Kết quả kiểm tra dạng từ.
class UseFormResult {
  final String baseWord;
  final InflectionForm form;
  final String correctForm; // dạng đúng
  final String userAnswer;
  final bool isCorrect;
  final bool hasRule; // false = không có rule → không hiện sub-test

  const UseFormResult({
    required this.baseWord,
    required this.form,
    required this.correctForm,
    required this.userAnswer,
    required this.isCorrect,
    this.hasRule = true,
  });

  @override
  String toString() =>
      'UseForm($baseWord → $form: $correctForm, user: $userAnswer, correct: $isCorrect)';
}

/// Engine dạng từ — rule-based, deterministic.
class UseFormEngine {
  UseFormEngine._();

  /// Sinh dạng đúng của [baseWord] theo [form].
  /// Trả null nếu không có rule (item không hỗ trợ).
  static String? generateForm(String baseWord, InflectionForm form) {
    final word = baseWord.toLowerCase().trim();
    if (word.isEmpty) return null;

    switch (form) {
      case InflectionForm.plural:
        return _plural(word);
      case InflectionForm.thirdPerson:
        return _thirdPerson(word);
      case InflectionForm.past:
      case InflectionForm.pastParticiple:
        return _past(word);
      case InflectionForm.comparative:
        return _comparative(word);
      case InflectionForm.superlative:
        return _superlative(word);
      case InflectionForm.gerund:
        return _gerund(word);
    }
  }

  /// Kiểm tra user answer có đúng dạng [form] của [baseWord]?
  /// Normalize (lowercase, bỏ dấu) trước khi so sánh.
  static UseFormResult check({
    required String baseWord,
    required InflectionForm form,
    required String userAnswer,
  }) {
    final correct = generateForm(baseWord, form);
    if (correct == null) {
      return UseFormResult(
        baseWord: baseWord,
        form: form,
        correctForm: '',
        userAnswer: userAnswer,
        isCorrect: false,
        hasRule: false,
      );
    }
    final normalized = _normalize(userAnswer);
    final isCorrect = normalized == _normalize(correct);
    return UseFormResult(
      baseWord: baseWord,
      form: form,
      correctForm: correct,
      userAnswer: userAnswer,
      isCorrect: isCorrect,
      hasRule: true,
    );
  }

  // ── Rules ──

  static String? _plural(String word) {
    if (word.endsWith('s') || word.endsWith('x') ||
        word.endsWith('ch') || word.endsWith('sh')) {
      return '${word}es';
    }
    if (word.endsWith('y') && word.length > 1 &&
        !_isVowel(word[word.length - 2])) {
      return '${word.substring(0, word.length - 1)}ies';
    }
    if (word.endsWith('o') && word.length > 1 &&
        !_isVowel(word[word.length - 2])) {
      return '${word}es';
    }
    return '${word}s';
  }

  static String? _thirdPerson(String word) {
    return _plural(word); // same rules as plural for 3sg
  }

  static String? _past(String word) {
    if (word.endsWith('e')) {
      return '${word}d';
    }
    if (word.endsWith('y') && word.length > 1 &&
        !_isVowel(word[word.length - 2])) {
      return '${word.substring(0, word.length - 1)}ied';
    }
    if (_shouldDouble(word)) {
      return '${word}${word[word.length - 1]}ed';
    }
    return '${word}ed';
  }

  static String? _comparative(String word) {
    if (word.length <= 1) return null;
    if (word.endsWith('e')) {
      return '${word}r';
    }
    if (word.endsWith('y') && word.length > 1 &&
        !_isVowel(word[word.length - 2])) {
      return '${word.substring(0, word.length - 1)}ier';
    }
    if (_shouldDouble(word)) {
      return '${word}${word[word.length - 1]}er';
    }
    return '${word}er';
  }

  static String? _superlative(String word) {
    final comp = _comparative(word);
    if (comp == null) return null;
    // big → biggest, nice → nicest
    if (comp.endsWith('er')) {
      return '${comp.substring(0, comp.length - 2)}est';
    }
    return null; // fallback: "most ___" not handled in Phase 1
  }

  static String? _gerund(String word) {
    if (word.endsWith('e')) {
      return '${word.substring(0, word.length - 1)}ing';
    }
    if (_shouldDouble(word)) {
      return '${word}${word[word.length - 1]}ing';
    }
    return '${word}ing';
  }

  // ── helpers ──

  /// Có nên double final consonant? CVC pattern (consonant-vowel-consonant)
  /// với vowel ngắn. 'run' → 'running', 'big' → 'bigger'.
  /// 'walk' (CVCC) → không double, 'tall' (CVCC) → không double.
  /// 'play' (ends y) → không double (→ played).
  static bool _shouldDouble(String word) {
    if (word.length < 3) return false;
    final last = word[word.length - 1];
    if (last == 'y' || last == 'w' || last == 'x') return false; // 'y' special case → +ed/+ing
    final second = word[word.length - 2];
    if (!_isConsonant(last)) return false;
    if (!_isVowel(second)) return false;
    return _isConsonant(word[word.length - 3]);
  }

  static bool _isVowel(String c) =>
      c == 'a' || c == 'e' || c == 'i' || c == 'o' || c == 'u';

  static bool _isConsonant(String c) =>
      RegExp(r'^[a-z]$').hasMatch(c.toLowerCase()) &&
      !_isVowel(c.toLowerCase());

  static String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r"[^a-z0-9']"), '').trim();
}
