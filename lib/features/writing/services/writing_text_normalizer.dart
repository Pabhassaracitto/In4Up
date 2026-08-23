/// Chuẩn hóa token dùng chung cho các bài Chép/Cloze/Rewrite/Summary.
///
/// Không giới hạn vào `[a-z]`: giữ chữ cái và chữ số của các hệ chữ được
/// In4Up hỗ trợ, đồng thời loại punctuation/symbol ở mọi vị trí.
class WritingTextNormalizer {
  WritingTextNormalizer._();

  static const Set<int> _apostrophes = {
    0x0027, // '
    0x2019, // ’
  };

  static String normalizeWord(String input) {
    final buffer = StringBuffer();
    for (final rune in input.toLowerCase().runes) {
      if (_isLetterOrDigit(rune) || _apostrophes.contains(rune)) {
        buffer.writeCharCode(_apostrophes.contains(rune) ? 0x0027 : rune);
      }
    }
    return buffer.toString().trim();
  }

  static List<String> tokenize(String input) {
    return input
        .split(RegExp(r'\s+'))
        .map(normalizeWord)
        .where((word) => word.isNotEmpty)
        .toList();
  }

  static bool containsLetters(String input) {
    return input.runes.any(_isLetter);
  }

  static bool _isLetterOrDigit(int rune) {
    return _isLetter(rune) || _isDigit(rune) || _isCombiningMark(rune);
  }

  static bool _isLetter(int rune) {
    if ((rune >= 0x41 && rune <= 0x5A) ||
        (rune >= 0x61 && rune <= 0x7A)) {
      return true;
    }
    if (rune < 0x00C0) return false;

    // Symbols, general punctuation, arrows, emoji và full-width punctuation.
    if ((rune >= 0x2000 && rune <= 0x2FFF) ||
        (rune >= 0x3000 && rune <= 0x303F) ||
        (rune >= 0x1F000 && rune <= 0x1FAFF) ||
        (rune >= 0xFF00 && rune <= 0xFF65)) {
      return false;
    }

    // Punctuation đặc thù thường gặp trong Arabic/Indic/CJK text.
    const punctuation = {
      0x060C,
      0x061B,
      0x061F,
      0x0964,
      0x0965,
      0x0E2F,
      0x0E46,
      0x104A,
      0x104B,
    };
    return !punctuation.contains(rune);
  }

  static bool _isDigit(int rune) {
    return (rune >= 0x30 && rune <= 0x39) ||
        (rune >= 0x0660 && rune <= 0x0669) ||
        (rune >= 0x06F0 && rune <= 0x06F9) ||
        (rune >= 0x0966 && rune <= 0x096F) ||
        (rune >= 0x0E50 && rune <= 0x0E59);
  }

  static bool _isCombiningMark(int rune) {
    return (rune >= 0x0300 && rune <= 0x036F) ||
        (rune >= 0x1AB0 && rune <= 0x1AFF) ||
        (rune >= 0x1DC0 && rune <= 0x1DFF) ||
        (rune >= 0x20D0 && rune <= 0x20FF) ||
        (rune >= 0xFE20 && rune <= 0xFE2F);
  }
}
