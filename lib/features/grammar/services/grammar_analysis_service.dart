import '../../../models/word_analysis.dart';
import '../../../services/syntax_highlighter_service.dart';
import '../models/grammar_analysis_result.dart';
import '../models/grammar_category.dart';
import '../models/grammar_token.dart';
import 'grammar_lexicon_service.dart';

class GrammarAnalysisService {
  GrammarAnalysisService._();
  static final GrammarAnalysisService instance = GrammarAnalysisService._();

  final GrammarLexiconService _lexicon = GrammarLexiconService.instance;

  GrammarAnalysisResult analyzeLine(
    String text, {
    String? sourceLabel,
  }) {
    final analyzedWords = SyntaxHighlighterService.analyzeLine(text);
    return fromAnalyzedWords(
      text,
      analyzedWords,
      sourceLabel: sourceLabel,
    );
  }

  List<GrammarAnalysisResult> analyzeLines(
    List<String> lines, {
    String? sourceLabel,
  }) {
    return lines
        .map((line) => analyzeLine(line, sourceLabel: sourceLabel))
        .toList();
  }

  GrammarAnalysisResult fromAnalyzedWords(
    String sourceText,
    List<AnalyzedWord> analyzedWords, {
    String? sourceLabel,
  }) {
    final tokens = <GrammarToken>[];
    var searchStart = 0;

    for (final analyzed in analyzedWords) {
      final surface = analyzed.originalWord;
      final startOffset = _findTokenOffset(sourceText, surface, searchStart);
      final safeStart = startOffset < 0 ? searchStart : startOffset;
      final safeEnd = safeStart + surface.length;
      searchStart = safeEnd;

      final normalized = surface.toLowerCase().replaceAll(RegExp(r"[^\w']"), '').trim();
      final lexiconEntry = normalized.isEmpty ? null : _lexicon.lookup(normalized);
      final category = lexiconEntry?.category ??
          _upgradeLegacyCategory(analyzed.wordType, normalized, analyzed.isStopWord);
      final token = GrammarToken.fromAnalyzedWord(
        analyzed,
        startOffset: safeStart,
        endOffset: safeEnd,
        overrideCategory: category,
        overrideLemma: lexiconEntry?.lemma,
        overrideSubCategory: lexiconEntry?.subCategory,
        overrideConfidence: lexiconEntry?.confidence ??
            _legacyConfidence(analyzed.wordType, analyzed.isStopWord),
      );
      tokens.add(token);
    }

    return GrammarAnalysisResult(
      sourceText: sourceText,
      sourceLabel: sourceLabel,
      tokens: tokens,
    );
  }

  int _findTokenOffset(String sourceText, String token, int fromIndex) {
    if (token.isEmpty || fromIndex >= sourceText.length) return -1;
    final index = sourceText.indexOf(token, fromIndex);
    if (index >= 0) return index;
    return sourceText.toLowerCase().indexOf(token.toLowerCase(), fromIndex);
  }

  GrammarCategory _upgradeLegacyCategory(
    WordType legacy,
    String normalized,
    bool isStopWord,
  ) {
    if (normalized.isEmpty) {
      return grammarCategoryFromLegacyWordType(legacy);
    }

    if (_modalWords.contains(normalized)) {
      return GrammarCategory.modal;
    }
    if (_auxiliaryWords.contains(normalized)) {
      return GrammarCategory.auxiliary;
    }
    if (_particleWords.contains(normalized)) {
      return GrammarCategory.particle;
    }
    if (_interjections.contains(normalized)) {
      return GrammarCategory.interjection;
    }

    if (legacy == WordType.unknown && isStopWord) {
      return GrammarCategory.determiner;
    }
    return grammarCategoryFromLegacyWordType(legacy);
  }

  double _legacyConfidence(WordType type, bool isStopWord) {
    switch (type) {
      case WordType.noun:
      case WordType.verb:
      case WordType.adjective:
      case WordType.adverb:
        return 0.72;
      case WordType.pronoun:
      case WordType.determiner:
      case WordType.preposition:
      case WordType.conjunction:
      case WordType.number:
      case WordType.punctuation:
        return 0.78;
      case WordType.interjection:
        return 0.66;
      case WordType.unknown:
        return isStopWord ? 0.42 : 0.25;
    }
  }

  static const Set<String> _modalWords = {
    'can', 'could', 'may', 'might', 'must', 'shall', 'should', 'will', 'would',
  };

  static const Set<String> _auxiliaryWords = {
    'am', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
    'have', 'has', 'had',
    'do', 'does', 'did',
  };

  static const Set<String> _particleWords = {
    'not', 'to', 'up', 'off', 'out', 'down', 'away', 'back',
  };

  static const Set<String> _interjections = {
    'oh', 'wow', 'hey', 'ah', 'oops', 'alas', 'bravo',
  };
}
