import '../models/vocabulary_type.dart';

class VocabClassifier {
  static VocabularyType classify(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return VocabularyType.word;

    if (RegExp(r'[.!?]\s*$').hasMatch(trimmed)) {
      return VocabularyType.sentence;
    }

    final tokens = trimmed
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    if (tokens.length == 1) return VocabularyType.word;

    if (tokens.length <= 5) {
      if (_looksLikeSentence(trimmed, tokens)) {
        return VocabularyType.sentence;
      }
      return VocabularyType.phrase;
    }

    return VocabularyType.sentence;
  }

  static bool _looksLikeSentence(String text, List<String> tokens) {
    final startsWithCapital = RegExp(r'^[A-Z]').hasMatch(text);
    final containsVerb = _commonVerbs.any(
        (v) => tokens.any((t) => t.toLowerCase() == v));
    return startsWithCapital && containsVerb;
  }

  static DecomposeResult decompose(String text, VocabularyType type) {
    if (type == VocabularyType.word) {
      return DecomposeResult.empty();
    }

    // ★ FIX: Thay regex string để tránh lỗi escape
    final clean = text.replaceAll(RegExp(r"""[.!?,;:"'()\[\]{}]"""), ' ').trim();
    final tokens = clean
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    final words = <String>[];
    final phrases = <String>[];

    for (final token in tokens) {
      final lower = token.toLowerCase();
      if (lower.length > 2 && !_stopWords.contains(lower)) {
        words.add(lower);
      }
    }

    if (type == VocabularyType.sentence && tokens.length >= 3) {
      for (int i = 0; i < tokens.length - 1; i++) {
        final a = tokens[i].toLowerCase();
        final b = tokens[i + 1].toLowerCase();
        if (!_stopWords.contains(a) || !_stopWords.contains(b)) {
          final bigram = '$a $b';
          if (!_isAllStopWords(bigram)) phrases.add(bigram);
        }
      }
      for (int i = 0; i < tokens.length - 2; i++) {
        final trigram =
            '${tokens[i]} ${tokens[i + 1]} ${tokens[i + 2]}'.toLowerCase();
        if (!_isAllStopWords(trigram)) phrases.add(trigram);
      }
    }

    return DecomposeResult(
      words: words.toSet().toList(),
      phrases: phrases.toSet().toList(),
      originalText: text,
      originalType: type,
    );
  }

  static bool _isAllStopWords(String phrase) {
    return phrase.split(' ').every((w) => _stopWords.contains(w.toLowerCase()));
  }

  static const _commonVerbs = {
    'is', 'are', 'was', 'were', 'be', 'been', 'being',
    'have', 'has', 'had', 'do', 'does', 'did',
    'will', 'would', 'shall', 'should',
    'may', 'might', 'must', 'can', 'could',
    'get', 'got', 'make', 'made', 'take', 'took',
    'go', 'went', 'come', 'came', 'see', 'saw',
    'know', 'knew', 'think', 'thought',
    'give', 'gave', 'tell', 'told', 'say', 'said',
    'find', 'found', 'want', 'need', 'use', 'used',
    'try', 'tried', 'leave', 'left', 'call', 'called',
    'achieve', 'achieved', 'transform', 'transformed',
  };

  static const _stopWords = {
    'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
    'have', 'has', 'had', 'do', 'does', 'did',
    'will', 'would', 'shall', 'should', 'may', 'might', 'must', 'can', 'could',
    'i', 'you', 'he', 'she', 'it', 'we', 'they',
    'me', 'him', 'her', 'us', 'them',
    'my', 'your', 'his', 'its', 'our', 'their',
    'this', 'that', 'these', 'those',
    'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by', 'from',
    'up', 'about', 'into', 'through', 'during', 'before', 'after',
    'and', 'but', 'or', 'nor', 'not', 'so', 'yet',
    'if', 'then', 'than', 'when', 'where', 'how', 'what', 'which', 'who',
    'no', 'very', 'just', 'also', 'too', 'as',
  };
}

class DecomposeResult {
  final List<String> words;
  final List<String> phrases;
  final String? originalText;
  final VocabularyType? originalType;

  const DecomposeResult({
    required this.words,
    required this.phrases,
    this.originalText,
    this.originalType,
  });

  factory DecomposeResult.empty() =>
      const DecomposeResult(words: [], phrases: []);

  bool get isEmpty => words.isEmpty && phrases.isEmpty;
  int get totalSuggestions => words.length + phrases.length;
}
