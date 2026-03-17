/// ═══════════════════════════════════════════════════════════════
///  TEXT PARSER
///  
///  Phân tích văn bản để tìm từ vựng
///  Hỗ trợ nhận diện từ đã biết / chưa biết
/// ═══════════════════════════════════════════════════════════════

class ParsedWord {
  final String original;
  final String normalized;
  final int startIndex;
  final int endIndex;
  final bool isWord;

  const ParsedWord({
    required this.original,
    required this.normalized,
    required this.startIndex,
    required this.endIndex,
    required this.isWord,
  });
}

class TextParser {
  // Regex để tách từ (chữ cái và dấu ')
  static final RegExp _wordPattern = RegExp(r"[a-zA-Z']+");
  
  // Các từ phổ biến nên bỏ qua
  static const Set<String> _stopWords = {
    'a', 'an', 'the', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
    'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could',
    'should', 'may', 'might', 'must', 'shall', 'can', 'need', 'dare',
    'ought', 'used', 'to', 'of', 'in', 'for', 'on', 'with', 'at', 'by',
    'from', 'up', 'about', 'into', 'over', 'after', 'and', 'but', 'or',
    'as', 'if', 'when', 'than', 'because', 'while', 'although', 'so',
    'that', 'this', 'these', 'those', 'it', 'its', 'i', 'you', 'he',
    'she', 'we', 'they', 'me', 'him', 'her', 'us', 'them', 'my', 'your',
    'his', 'our', 'their', 'mine', 'yours', 'hers', 'ours', 'theirs',
    'what', 'which', 'who', 'whom', 'whose', 'where', 'why', 'how',
    'all', 'each', 'every', 'both', 'few', 'more', 'most', 'other',
    'some', 'such', 'no', 'nor', 'not', 'only', 'own', 'same', 'then',
    'too', 'very', 'just', 'also', 'now', 'here', 'there', 'out',
    'even', 'new', 'want', 'way', 'look', 'first', 'well', 'back',
    'any', 'good', 'much', 'before', 'get', 'like', 'one', 'two',
    'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten',
  };

  /// Parse văn bản thành danh sách parsed words
  static List<ParsedWord> parse(String text) {
    final result = <ParsedWord>[];
    int currentIndex = 0;

    for (final match in _wordPattern.allMatches(text)) {
      // Thêm phần không phải từ (dấu câu, khoảng trắng)
      if (match.start > currentIndex) {
        result.add(ParsedWord(
          original: text.substring(currentIndex, match.start),
          normalized: '',
          startIndex: currentIndex,
          endIndex: match.start,
          isWord: false,
        ));
      }

      // Thêm từ
      final word = match.group(0)!;
      result.add(ParsedWord(
        original: word,
        normalized: word.toLowerCase(),
        startIndex: match.start,
        endIndex: match.end,
        isWord: true,
      ));

      currentIndex = match.end;
    }

    // Phần còn lại
    if (currentIndex < text.length) {
      result.add(ParsedWord(
        original: text.substring(currentIndex),
        normalized: '',
        startIndex: currentIndex,
        endIndex: text.length,
        isWord: false,
      ));
    }

    return result;
  }

  /// Lấy danh sách từ unique (không trùng lặp)
  static List<String> extractUniqueWords(String text, {bool excludeStopWords = true}) {
    final parsed = parse(text);
    final words = <String>{};

    for (final p in parsed) {
      if (p.isWord && p.normalized.length > 1) {
        if (!excludeStopWords || !_stopWords.contains(p.normalized)) {
          words.add(p.normalized);
        }
      }
    }

    return words.toList()..sort();
  }

  /// Đếm tần suất từ
  static Map<String, int> wordFrequency(String text, {bool excludeStopWords = true}) {
    final parsed = parse(text);
    final freq = <String, int>{};

    for (final p in parsed) {
      if (p.isWord && p.normalized.length > 1) {
        if (!excludeStopWords || !_stopWords.contains(p.normalized)) {
          freq[p.normalized] = (freq[p.normalized] ?? 0) + 1;
        }
      }
    }

    return freq;
  }

  /// Kiểm tra từ có phải stop word không
  static bool isStopWord(String word) => _stopWords.contains(word.toLowerCase());
}
