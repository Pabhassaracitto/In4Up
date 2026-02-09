import 'package:flutter/material.dart';
import '../models/word_analysis.dart';

class SyntaxHighlighterService {
  SyntaxHighlighterService._();
  static final SyntaxHighlighterService instance = SyntaxHighlighterService._();

  bool _initialized = false;

  final Map<String, List<AnalyzedWord>> _cache = {};
  static const int _maxCacheSize = 500;

  Future<void> initialize() async {
    // để tương thích với code đang await initialize()
    _initialized = true;
  }

  static List<AnalyzedWord> analyzeLine(String text) {
    return instance._analyzeLine(text);
  }

  static List<List<AnalyzedWord>> analyzeLines(List<String> lines) {
    return lines.map(analyzeLine).toList();
  }

  List<List<AnalyzedWord>> analyzeAllLines(List<String> lines) {
    return lines.map(_analyzeLine).toList();
  }

  List<AnalyzedWord> _analyzeLine(String text) {
    final src = text.trim();
    if (src.isEmpty) return [];

    final cached = _cache[src];
    if (cached != null) return cached;

    final tokens = _tokenize(src);
    final result = <AnalyzedWord>[];

    for (final token in tokens) {
      final clean = token.replaceAll(RegExp(r"[^\w']"), '').toLowerCase();

      // punctuation
      if (RegExp(r'^[^\w]+$').hasMatch(token)) {
        result.add(AnalyzedWord(
          word: token,
          originalWord: token,
          wordType: WordType.punctuation,
          cefrLevel: CEFRLevel.unknown,
          isStopWord: true,
        ));
        continue;
      }

      // number
      if (RegExp(r'^\d+$').hasMatch(token)) {
        result.add(AnalyzedWord(
          word: token,
          originalWord: token,
          wordType: WordType.number,
          cefrLevel: CEFRLevel.unknown,
          isStopWord: true,
        ));
        continue;
      }

      if (clean.isEmpty) {
        result.add(AnalyzedWord(
          word: token,
          originalWord: token,
          wordType: WordType.unknown,
          cefrLevel: CEFRLevel.unknown,
        ));
        continue;
      }

      final isStop = _stopWords.contains(clean);
      final type =
          isStop ? _classifyStopWord(clean) : _classifyWordBasic(clean);
      final cefr = _estimateCEFR(clean);

      result.add(AnalyzedWord(
        word: token,
        originalWord: token,
        wordType: type,
        cefrLevel: cefr,
        meaning: _basicDict[clean],
        isStopWord: isStop,
      ));
    }

    _trimCacheIfNeeded();
    _cache[src] = result;
    return result;
  }

  List<String> _tokenize(String text) {
    // words + punctuation as tokens
    final regex = RegExp(r"[\w']+|[^\w\s]");
    return regex.allMatches(text).map((m) => m.group(0)!).toList();
  }

  void _trimCacheIfNeeded() {
    if (_cache.length < _maxCacheSize) return;
    final keysToRemove = _cache.keys.take(_maxCacheSize ~/ 5).toList();
    for (final k in keysToRemove) {
      _cache.remove(k);
    }
  }

  WordType _classifyWordBasic(String w) {
    if (_pronouns.contains(w)) return WordType.pronoun;
    if (_determiners.contains(w)) return WordType.determiner;
    if (_prepositions.contains(w)) return WordType.preposition;
    if (_conjunctions.contains(w)) return WordType.conjunction;
    if (_commonVerbs.contains(w)) return WordType.verb;

    if (w.endsWith('ing') ||
        w.endsWith('ed') ||
        w.endsWith('ify') ||
        w.endsWith('ate')) {
      return WordType.verb;
    }
    if (w.endsWith('ly') && w.length > 3) return WordType.adverb;

    if (w.endsWith('ful') ||
        w.endsWith('less') ||
        w.endsWith('ous') ||
        w.endsWith('able') ||
        w.endsWith('ible')) {
      return WordType.adjective;
    }

    if (w.endsWith('tion') ||
        w.endsWith('ment') ||
        w.endsWith('ness') ||
        w.endsWith('ity')) {
      return WordType.noun;
    }

    return WordType.unknown;
  }

  WordType _classifyStopWord(String w) {
    if (_pronouns.contains(w)) return WordType.pronoun;
    if (_determiners.contains(w)) return WordType.determiner;
    if (_prepositions.contains(w)) return WordType.preposition;
    if (_conjunctions.contains(w)) return WordType.conjunction;
    if (_commonVerbs.contains(w)) return WordType.verb;
    if (_adverbs.contains(w)) return WordType.adverb;
    return WordType.unknown;
  }

  CEFRLevel _estimateCEFR(String w) {
    // Có thể thay bằng database/wordlist sau. Hiện dùng heuristic.
    if (w.length <= 4) return CEFRLevel.a1;
    if (w.length <= 6) return CEFRLevel.a2;
    if (w.length <= 8) return CEFRLevel.b1;
    if (w.length <= 10) return CEFRLevel.b2;
    if (w.length <= 13) return CEFRLevel.c1;
    return CEFRLevel.c2;
  }

  void clearCache() => _cache.clear();

  // ===== word lists tối thiểu (đủ cho classify) =====
  static const _stopWords = {
    'the',
    'a',
    'an',
    'is',
    'are',
    'was',
    'were',
    'be',
    'been',
    'being',
    'have',
    'has',
    'had',
    'do',
    'does',
    'did',
    'will',
    'would',
    'could',
    'should',
    'can',
    'to',
    'of',
    'in',
    'for',
    'on',
    'with',
    'at',
    'by',
    'from',
    'as',
    'and',
    'but',
    'or',
    'not',
    'i',
    'you',
    'he',
    'she',
    'it',
    'we',
    'they',
    'me',
    'my',
    'your',
    'his',
    'her',
    'our',
    'their',
  };

  static const _pronouns = {
    'i',
    'you',
    'he',
    'she',
    'it',
    'we',
    'they',
    'me',
    'him',
    'her',
    'us',
    'them',
    'my',
    'your',
    'his',
    'our',
    'their'
  };
  static const _determiners = {
    'a',
    'an',
    'the',
    'some',
    'any',
    'every',
    'each',
    'no',
    'all',
    'both',
    'few',
    'many',
    'much',
    'several'
  };
  static const _prepositions = {
    'in',
    'on',
    'at',
    'to',
    'for',
    'of',
    'with',
    'by',
    'from',
    'about',
    'into',
    'through',
    'before',
    'after',
    'between',
    'under',
    'over'
  };
  static const _conjunctions = {
    'and',
    'but',
    'or',
    'nor',
    'for',
    'yet',
    'so',
    'because',
    'although',
    'while',
    'if',
    'when',
    'unless',
    'until',
    'since',
    'though'
  };
  static const _adverbs = {
    'not',
    'very',
    'just',
    'also',
    'here',
    'there',
    'often',
    'sometimes',
    'usually',
    'already',
    'probably'
  };

  static const _commonVerbs = {
    'be',
    'is',
    'am',
    'are',
    'was',
    'were',
    'have',
    'has',
    'had',
    'do',
    'does',
    'did',
    'go',
    'get',
    'make',
    'know',
    'think',
    'take',
    'see',
    'come',
    'want',
    'use',
    'find',
    'give',
    'tell',
    'work',
    'call',
    'try',
    'ask',
    'need',
  };

  static const _basicDict = <String, String>{
    'the': 'mạo từ xác định',
    'is': 'là/thì',
    'are': 'là/thì (số nhiều)',
    'have': 'có',
    'do': 'làm',
    'go': 'đi',
    'think': 'nghĩ',
  };
}
