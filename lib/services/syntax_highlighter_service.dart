import 'package:in4up/features/grammar/models/grammar_category.dart';

import '../features/grammar/services/grammar_lexicon_service.dart';
import '../models/word_analysis.dart';
import '../providers/vocabulary_bridge.dart';

class SyntaxHighlighterService {
  SyntaxHighlighterService._();
  static final SyntaxHighlighterService instance = SyntaxHighlighterService._();

  final GrammarLexiconService _grammarLexicon = GrammarLexiconService.instance;
  final Map<String, List<AnalyzedWord>> _cache = {};
  static const int _maxCacheSize = 500;

  Future<void> initialize() async {
    // để tương thích với code đang await initialize()
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

  /// Public method cho Web Reader và PDF Reader
  AnalyzedWord analyzeWord(String word) {
    final clean = word.toLowerCase().replaceAll(RegExp(r"[^\w']"), '');
    if (clean.isEmpty) {
      return AnalyzedWord(word: word, wordType: WordType.unknown);
    }
    final lexiconEntry = _grammarLexicon.lookup(clean);
    final isStop = _stopWords.contains(clean) || (lexiconEntry?.category.isFunctionWord ?? false);
    final type = lexiconEntry?.category.legacyWordType ??
        (isStop ? _classifyStopWord(clean) : _classifyWordBasic(clean));
    final cefr = _estimateCEFR(clean);
    final base = AnalyzedWord(
      word: word,
      originalWord: word,
      wordType: type,
      cefrLevel: cefr,
      meaning: _basicDict[clean],
      isStopWord: isStop,
    );
    return _applyGlobalVocabularyData(base, clean);
  }

  /// Expose CEFR dictionary cho JavaScript serialization
  static Map<String, CEFRLevel> get cefrDictionary => _cefrDictionary;

  List<AnalyzedWord> _analyzeLine(String text) {
    final src = text.trim();
    if (src.isEmpty) return [];

    final cached = _cache[src];
    if (cached != null) {
      return cached
          .map((word) => _applyGlobalVocabularyData(
                word,
                word.word.toLowerCase().replaceAll(RegExp(r"[^\w']"), ''),
              ))
          .toList();
    }

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

      final lexiconEntry = _grammarLexicon.lookup(clean);
      final isStop =
          _stopWords.contains(clean) || (lexiconEntry?.category.isFunctionWord ?? false);
      final type = lexiconEntry?.category.legacyWordType ??
          (isStop ? _classifyStopWord(clean) : _classifyWordBasic(clean));
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
    return result
        .map((word) => _applyGlobalVocabularyData(
              word,
              word.word.toLowerCase().replaceAll(RegExp(r"[^\w']"), ''),
            ))
        .toList();
  }

  AnalyzedWord _applyGlobalVocabularyData(AnalyzedWord word, String clean) {
    if (clean.isEmpty) return word;
    final entry = VocabularyBridge.findByWord(clean);
    if (entry == null) return word;
    return word.copyWith(
      meaning: entry.meaning.trim().isNotEmpty ? entry.meaning.trim() : word.meaning,
      phonetic: (entry.phonetic?.trim().isNotEmpty ?? false)
          ? entry.phonetic!.trim()
          : word.phonetic,
      example: (entry.example?.trim().isNotEmpty ?? false)
          ? entry.example!.trim()
          : word.example,
      userDifficulty: entry.userDifficulty,
      isSaved: true,
      hasSavedNotes: (entry.personalNotes?.trim().isNotEmpty ?? false),
      hasDueReview: entry.hasAnyDue,
      encounterCount: entry.encounterCount,
    );
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
    // 1. Tra từ điển Hardcoded (Độ chính xác cao)
    if (_cefrDictionary.containsKey(w)) {
      return _cefrDictionary[w]!;
    }

    // 2. Heuristic cải tiến (nếu không có trong từ điển)
    // Các hậu tố phức tạp thường đi kèm từ vựng cấp cao
    if (w.endsWith('ibility') ||
        w.endsWith('omorphism') ||
        w.endsWith('ential')) {
      return CEFRLevel.c1;
    }
    if (w.endsWith('ment') || w.endsWith('tion') || w.endsWith('ance')) {
      return CEFRLevel.b2;
    }

    // Fallback dựa trên độ dài (nhưng nới lỏng hơn)
    if (w.length <= 3) return CEFRLevel.a1;
    if (w.length <= 5) return CEFRLevel.a2;
    if (w.length <= 8) return CEFRLevel.b1;

    return CEFRLevel.b2;
  }

  // Mini CEFR Dictionary (Ví dụ)
  static const Map<String, CEFRLevel> _cefrDictionary = {
    // A1
    'the': CEFRLevel.a1, 'and': CEFRLevel.a1, 'you': CEFRLevel.a1,
    'that': CEFRLevel.a1,
    'was': CEFRLevel.a1, 'for': CEFRLevel.a1, 'are': CEFRLevel.a1,
    'with': CEFRLevel.a1,
    'they': CEFRLevel.a1, 'be': CEFRLevel.a1, 'one': CEFRLevel.a1,
    'have': CEFRLevel.a1,
    // A2
    'ability': CEFRLevel.a2, 'able': CEFRLevel.a2, 'about': CEFRLevel.a2,
    'above': CEFRLevel.a2,
    'accept': CEFRLevel.a2, 'according': CEFRLevel.a2, 'account': CEFRLevel.a2,
    // B1
    'absolutely': CEFRLevel.b1, 'academic': CEFRLevel.b1,
    'access': CEFRLevel.b1,
    'accommodation': CEFRLevel.b1, 'achievement': CEFRLevel.b1,
    // B2
    'abandon': CEFRLevel.b2, 'absolute': CEFRLevel.b2, 'absorb': CEFRLevel.b2,
    'abstract': CEFRLevel.b2, 'abuse': CEFRLevel.b2,
    // C1
    'abolish': CEFRLevel.c1, 'abortion': CEFRLevel.c1, 'absence': CEFRLevel.c1,
    'absurd': CEFRLevel.c1, 'abundance': CEFRLevel.c1,
    // C2
    'abhor': CEFRLevel.c2, 'abide': CEFRLevel.c2, 'abject': CEFRLevel.c2,
  };

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
