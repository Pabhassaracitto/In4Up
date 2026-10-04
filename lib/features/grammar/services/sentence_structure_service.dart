import 'dart:collection';
import 'dart:math' as math;

import '../../../knowledge/text/segmenter.dart';
import '../../../services/syntax_highlighter_service.dart';
import '../models/grammar_category.dart';
import '../models/grammar_token.dart';
import '../models/structure_analysis.dart';
import 'grammar_analysis_service.dart';
import 'grammar_lexicon_service.dart';
import 'phrase_builder.dart';
import 'sentence_typer.dart';
import 'verb_group_reader.dart';

class SentenceStructureService {
  SentenceStructureService._({
    GrammarAnalysisService? grammarAnalysis,
    GrammarLexiconService? lexicon,
    PhraseBuilder? phraseBuilder,
    SentenceTyper? sentenceTyper,
  })  : _grammarAnalysis = grammarAnalysis ?? GrammarAnalysisService.instance,
        _lexicon = lexicon ?? GrammarLexiconService.instance,
        _phraseBuilder = phraseBuilder ?? PhraseBuilder(),
        _sentenceTyper = sentenceTyper ?? SentenceTyper();

  static final SentenceStructureService instance = SentenceStructureService._();

  final GrammarAnalysisService _grammarAnalysis;
  final GrammarLexiconService _lexicon;
  final PhraseBuilder _phraseBuilder;
  final SentenceTyper _sentenceTyper;

  final LinkedHashMap<String, StructureAnalysis> _cache =
      LinkedHashMap<String, StructureAnalysis>();

  static const int _maxCacheEntries = 500;

  StructureAnalysis analyzeLine(
    String lineText, {
    required int anchorStart,
    required int anchorEnd,
  }) {
    final key = '$anchorStart:$anchorEnd:$lineText';
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached;
      return cached;
    }

    final result = _analyzeLineUncached(
      lineText,
      anchorStart: anchorStart,
      anchorEnd: anchorEnd,
    );
    if (_cache.length >= _maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = result;
    return result;
  }

  List<StructureAnalysis> analyzeLineAll(String lineText) {
    final normalized = _normalizeTypography(lineText);
    final rawTokens = _tokensFor(normalized);
    final tokens = _expandTokens(rawTokens);
    final analyses = <StructureAnalysis>[];
    for (final sentence in TextSegmenter.sentences(normalized)) {
      final anchor = tokens.where((token) =>
          token.isWord &&
          token.startOffset >= sentence.start &&
          token.endOffset <= sentence.end).toList(growable: false);
      if (anchor.isEmpty) continue;
      final first = anchor.first;
      analyses.add(analyzeLine(
        lineText,
        anchorStart: first.startOffset,
        anchorEnd: first.endOffset,
      ));
    }
    return analyses;
  }

  void clearCache() => _cache.clear();

  StructureAnalysis _analyzeLineUncached(
    String lineText, {
    required int anchorStart,
    required int anchorEnd,
  }) {
    if (lineText.trim().isEmpty) {
      return StructureAnalysis(
        sourceText: lineText,
        supported: false,
        notes: const ['empty'],
      );
    }

    final normalized = _normalizeTypography(lineText);
    final rawTokens = _tokensFor(normalized);
    final tokens = _expandTokens(rawTokens);
    final sentenceSpan = _sentenceContaining(normalized, anchorStart, anchorEnd);
    final sentenceTokens = tokens
        .where((token) =>
            token.startOffset >= sentenceSpan.start &&
            token.endOffset <= sentenceSpan.end)
        .toList(growable: false);

    final gateTokens = sentenceTokens.isEmpty ? tokens : sentenceTokens;
    if (!_looksLikeEnglish(normalized, gateTokens)) {
      return StructureAnalysis(
        sourceText: lineText,
        supported: false,
        sentenceStart: sentenceSpan.start,
        sentenceEnd: sentenceSpan.end,
        confidence: 0,
        notes: const ['language_gate'],
      );
    }

    final anchorIndex = _anchorTokenIndex(sentenceTokens, anchorStart, anchorEnd);
    if (anchorIndex == null) {
      return StructureAnalysis(
        sourceText: lineText,
        supported: true,
        sentenceStart: sentenceSpan.start,
        sentenceEnd: sentenceSpan.end,
        confidence: 0.2,
        notes: const ['anchor_not_found'],
      );
    }

    final notes = <String>[];
    final lineComplete = _lineLooksComplete(normalized);
    if (!lineComplete) notes.add('line_continues');

    final phraseResult = _phraseBuilder.build(
      sentenceTokens,
      anchorIndex: anchorIndex,
    );
    final typing = lineComplete
        ? _sentenceTyper.analyze(
            sentenceTokens,
            anchorIndex: anchorIndex,
            spanStart: sentenceSpan.start,
            spanEnd: sentenceSpan.end,
          )
        : const SentenceTypingResult();

    final confidence = _confidence(
      phraseResult.phrase,
      typing.sentence,
      lineComplete: lineComplete,
      tokenCount: sentenceTokens.length,
    );

    return StructureAnalysis(
      sourceText: lineText,
      supported: true,
      phrase: phraseResult.phrase,
      outer: phraseResult.outer,
      sentence: typing.sentence,
      clauseRole: typing.clauseRole,
      conditionalType: typing.conditionalType,
      sentenceStart: sentenceSpan.start,
      sentenceEnd: sentenceSpan.end,
      confidence: confidence,
      notes: notes,
    );
  }

  List<GrammarToken> _tokensFor(String normalizedText) {
    // Explicitly reuse the Read-tab tokenizer. GrammarAnalysisService uses the
    // same path and adds cached POS/lemma/confidence on top.
    SyntaxHighlighterService.tokenizeText(normalizedText);
    return _grammarAnalysis.analyzeLine(normalizedText).tokens;
  }

  List<StructureToken> _expandTokens(List<GrammarToken> tokens) {
    final out = <StructureToken>[];
    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      final normalized = _normalizeToken(token.normalized);
      final contraction = _splitContraction(normalized);
      if (contraction == null) {
        out.add(_fromGrammarToken(token, i, normalized: normalized));
        continue;
      }
      for (final part in contraction) {
        out.add(_syntheticToken(token, i, part));
      }
    }
    return out;
  }

  StructureToken _fromGrammarToken(
    GrammarToken token,
    int sourceIndex, {
    String? normalized,
  }) {
    final norm = normalized ?? _normalizeToken(token.normalized);
    final entry = norm.isEmpty ? null : _lexicon.lookup(norm);
    return StructureToken(
      surface: token.surface,
      normalized: norm,
      lemma: entry?.lemma ?? token.lemma,
      category: entry?.category ?? token.category,
      subCategory: entry?.subCategory ?? token.subCategory,
      confidence: entry?.confidence ?? token.confidence,
      startOffset: token.startOffset,
      endOffset: token.endOffset,
      sourceIndex: sourceIndex,
    );
  }

  StructureToken _syntheticToken(
    GrammarToken original,
    int sourceIndex,
    _ContractionPart part,
  ) {
    return StructureToken(
      surface: original.surface,
      normalized: part.normalized,
      lemma: part.lemma,
      category: part.category,
      subCategory: part.subCategory,
      confidence: math.max(original.confidence, 0.78),
      startOffset: original.startOffset,
      endOffset: original.endOffset,
      sourceIndex: sourceIndex,
    );
  }

  List<_ContractionPart>? _splitContraction(String normalized) {
    if (normalized.isEmpty) return null;
    final lower = normalized.replaceAll('’', "'");
    final negative = <String, String>{
      "don't": 'do',
      "doesn't": 'does',
      "didn't": 'did',
      "isn't": 'is',
      "aren't": 'are',
      "wasn't": 'was',
      "weren't": 'were',
      "haven't": 'have',
      "hasn't": 'has',
      "hadn't": 'had',
      "can't": 'can',
      "cannot": 'can',
      "won't": 'will',
      "wouldn't": 'would',
      "shouldn't": 'should',
      "couldn't": 'could',
      "mustn't": 'must',
    };
    final aux = negative[lower];
    if (aux != null) {
      return [
        _part(aux, _auxCategory(aux), lemma: _lemmaForAux(aux)),
        _part('not', GrammarCategory.particle, lemma: 'not', subCategory: 'negation'),
      ];
    }
    if (lower.endsWith("'s") && lower.length > 2) {
      final base = lower.substring(0, lower.length - 2);
      if (_contractablePronouns.contains(base) || base == 'there' || base == 'that') {
        return [
          _part(base, GrammarCategory.pronoun, lemma: base),
          _part("'s", GrammarCategory.auxiliary, lemma: 'be_or_have'),
        ];
      }
    }
    if (lower.endsWith("'re") && lower.length > 3) {
      final base = lower.substring(0, lower.length - 3);
      return [
        _part(base, GrammarCategory.pronoun, lemma: base),
        _part('are', GrammarCategory.auxiliary, lemma: 'be'),
      ];
    }
    if (lower.endsWith("'ve") && lower.length > 3) {
      final base = lower.substring(0, lower.length - 3);
      return [
        _part(base, GrammarCategory.pronoun, lemma: base),
        _part('have', GrammarCategory.auxiliary, lemma: 'have'),
      ];
    }
    if (lower.endsWith("'ll") && lower.length > 3) {
      final base = lower.substring(0, lower.length - 3);
      return [
        _part(base, GrammarCategory.pronoun, lemma: base),
        _part('will', GrammarCategory.modal, lemma: 'will'),
      ];
    }
    return null;
  }

  _ContractionPart _part(
    String normalized,
    GrammarCategory category, {
    String? lemma,
    String? subCategory,
  }) {
    return _ContractionPart(
      normalized: normalized,
      lemma: lemma ?? normalized,
      category: category,
      subCategory: subCategory,
    );
  }

  GrammarCategory _auxCategory(String aux) {
    if (const {'can', 'could', 'may', 'might', 'must', 'shall', 'should', 'will', 'would'}
        .contains(aux)) {
      return GrammarCategory.modal;
    }
    return GrammarCategory.auxiliary;
  }

  String _lemmaForAux(String aux) {
    if (const {'am', 'is', 'are', 'was', 'were', 'be', 'been', 'being'}.contains(aux)) {
      return 'be';
    }
    if (const {'have', 'has', 'had', 'having'}.contains(aux)) return 'have';
    if (const {'do', 'does', 'did'}.contains(aux)) return 'do';
    return aux;
  }

  Segment _sentenceContaining(String text, int anchorStart, int anchorEnd) {
    final sentences = TextSegmenter.sentences(text);
    if (sentences.isEmpty) return Segment(text: text.trim(), start: 0, end: text.length);
    for (final sentence in sentences) {
      if (anchorStart >= sentence.start && anchorEnd <= sentence.end) return sentence;
    }
    return sentences.first;
  }

  int? _anchorTokenIndex(
    List<StructureToken> tokens,
    int anchorStart,
    int anchorEnd,
  ) {
    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      if (!token.isWord) continue;
      final overlaps = token.startOffset < anchorEnd && token.endOffset > anchorStart;
      final contains = token.startOffset <= anchorStart && token.endOffset >= anchorEnd;
      if (overlaps || contains) return i;
    }
    return null;
  }

  bool _lineLooksComplete(String text) {
    final trimmed = text.trimRight();
    if (trimmed.isEmpty) return false;
    return RegExp(r'''[.!?]["')\]]*$''').hasMatch(trimmed);
  }

  bool _looksLikeEnglish(String text, List<StructureToken> tokens) {
    if (_vietnameseMarks.hasMatch(text)) return false;
    var asciiWords = 0;
    var nonAsciiLetters = 0;
    var asciiLetters = 0;
    for (final codePoint in text.runes) {
      final isAsciiLetter = (codePoint >= 0x41 && codePoint <= 0x5A) ||
          (codePoint >= 0x61 && codePoint <= 0x7A);
      if (isAsciiLetter) asciiLetters++;
      if (codePoint > 0x7F && RegExp(r'\p{L}', unicode: true).hasMatch(String.fromCharCode(codePoint))) {
        nonAsciiLetters++;
      }
    }
    for (final token in tokens) {
      if (!token.isWord) continue;
      if (RegExp(r'^[A-Za-z]').hasMatch(token.normalized)) asciiWords++;
    }
    if (asciiWords == 0) return false;
    if (nonAsciiLetters > 0 && nonAsciiLetters > asciiLetters / 4) return false;
    return true;
  }

  double _confidence(
    Object? phrase,
    Object? sentence, {
    required bool lineComplete,
    required int tokenCount,
  }) {
    var confidence = 0.86;
    if (phrase == null) confidence -= 0.12;
    if (sentence == null) confidence -= 0.18;
    if (!lineComplete) confidence = math.min(confidence, 0.55);
    if (tokenCount > 40) confidence -= 0.1;
    return confidence.clamp(0.0, 1.0).toDouble();
  }

  String _normalizeTypography(String text) => text
      .replaceAll('’', "'")
      .replaceAll('‘', "'")
      .replaceAll('“', '"')
      .replaceAll('”', '"')
      .replaceAll('–', '-')
      .replaceAll('—', '-')
      .replaceAll('\u00A0', ' ')
      .replaceAll('\u2009', ' ')
      .replaceAll('\u200B', ' ')
      .replaceAll('…', '.');

  String _normalizeToken(String token) => token
      .toLowerCase()
      .replaceAll('’', "'")
      .replaceAll(RegExp(r"^[^\w']+|[^\w']+$"), '')
      .trim();

  static final RegExp _vietnameseMarks = RegExp(
    r'[àảãáạăằắẳẵặâầấẩẫậèẻẽéẹêềếểễệìỉĩíịòọỏõóôồốổỗộơờớởỡợùủũúụừứửữựỳỷỹỵđ]',
    caseSensitive: false,
  );

  static const Set<String> _contractablePronouns = {
    'i', 'you', 'he', 'she', 'it', 'we', 'they',
  };

}

class _ContractionPart {
  final String normalized;
  final String lemma;
  final GrammarCategory category;
  final String? subCategory;

  const _ContractionPart({
    required this.normalized,
    required this.lemma,
    required this.category,
    this.subCategory,
  });
}
