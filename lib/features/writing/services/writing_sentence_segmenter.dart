/// Bộ tách câu nhỏ, deterministic, dùng cho fallback P0 của Writing Studio.
///
/// Mục tiêu không phải thay một NLP sentence boundary detector hoàn chỉnh, mà
/// là tránh những lỗi phổ biến của `split(. ! ?)` như Mr., U.S. và e.g.
class WritingSentenceSegmenter {
  WritingSentenceSegmenter._();

  static const Set<String> _abbreviations = {
    'mr',
    'mrs',
    'ms',
    'dr',
    'prof',
    'sr',
    'jr',
    'st',
    'vs',
    'etc',
    'e.g',
    'i.e',
    'no',
    'fig',
    // Một số viết tắt học thuật thường gặp trong nội dung tiếng Việt.
    'ts',
    'ths',
    'pgs',
    'gs',
  };

  static List<String> split(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) return const [];

    final sentences = <String>[];
    var sentenceStart = 0;
    var index = 0;

    while (index < normalized.length) {
      final char = normalized[index];
      if (char != '.' && char != '!' && char != '?') {
        index++;
        continue;
      }

      var punctuationEnd = index;
      while (punctuationEnd + 1 < normalized.length &&
          '.!?'.contains(normalized[punctuationEnd + 1])) {
        punctuationEnd++;
      }

      if (char == '.' && _isNonTerminalPeriod(normalized, index)) {
        index = punctuationEnd + 1;
        continue;
      }

      var boundaryEnd = punctuationEnd + 1;
      while (boundaryEnd < normalized.length &&
          _isClosingQuoteOrBracket(normalized[boundaryEnd])) {
        boundaryEnd++;
      }

      if (boundaryEnd < normalized.length &&
          !_isWhitespace(normalized[boundaryEnd])) {
        index = punctuationEnd + 1;
        continue;
      }

      final sentence = normalized.substring(sentenceStart, boundaryEnd).trim();
      if (sentence.isNotEmpty) sentences.add(sentence);

      while (boundaryEnd < normalized.length &&
          _isWhitespace(normalized[boundaryEnd])) {
        boundaryEnd++;
      }
      sentenceStart = boundaryEnd;
      index = boundaryEnd;
    }

    if (sentenceStart < normalized.length) {
      final remainder = normalized.substring(sentenceStart).trim();
      if (remainder.isNotEmpty) sentences.add(remainder);
    }

    return sentences.isEmpty ? [normalized] : sentences;
  }

  static int count(String text) => split(text).length;

  static String firstSentence(String text) {
    final sentences = split(text);
    return sentences.isEmpty ? text.trim() : sentences.first;
  }

  static bool _isNonTerminalPeriod(String text, int periodIndex) {
    if (periodIndex > 0 &&
        periodIndex + 1 < text.length &&
        _isDigit(text[periodIndex - 1]) &&
        _isDigit(text[periodIndex + 1])) {
      return true;
    }

    final token = _tokenBeforePeriod(text, periodIndex).toLowerCase();
    if (_abbreviations.contains(token)) return true;

    // Initial hoặc acronym: "A. Smith", "U.S. policy".
    if (RegExp(r'^[a-z]$').hasMatch(token)) return true;
    if (RegExp(r'^(?:[a-z]\.)+[a-z]$').hasMatch(token)) return true;

    return false;
  }

  static String _tokenBeforePeriod(String text, int periodIndex) {
    var start = periodIndex - 1;
    while (start >= 0) {
      final char = text[start];
      if (!_isLetter(char) && char != '.') break;
      start--;
    }
    return text.substring(start + 1, periodIndex);
  }

  static bool _isWhitespace(String value) => RegExp(r'\s').hasMatch(value);

  static bool _isDigit(String value) => RegExp(r'[0-9]').hasMatch(value);

  static bool _isLetter(String value) {
    return value.toUpperCase() != value.toLowerCase();
  }

  static bool _isClosingQuoteOrBracket(String value) {
    return const {'"', "'", '”', '’', ')', ']', '}'}.contains(value);
  }
}
