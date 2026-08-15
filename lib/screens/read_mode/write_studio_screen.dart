import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:in4up_ai/in4up_ai.dart';
import '../../core/responsive/app_responsive.dart';
import '../../models/text_item.dart';
import '../../providers/text_provider.dart';
import 'package:in4up/core/language/tr_extension.dart';

enum _WriteExerciseType {
  dictation,
  clozeInput,
  clozeChoice,
  rewrite,
  summary,
}

class WriteStudioScreen extends StatefulWidget {
  final VoidCallback onOpenWebReader;
  final VoidCallback onOpenPdfReader;
  final VoidCallback onOpenQuickActions;

  const WriteStudioScreen({
    super.key,
    required this.onOpenWebReader,
    required this.onOpenPdfReader,
    required this.onOpenQuickActions,
  });

  @override
  State<WriteStudioScreen> createState() => _WriteStudioScreenState();
}

class _WriteStudioScreenState extends State<WriteStudioScreen> {
  final math.Random _random = math.Random();
  final TextEditingController _dictationController = TextEditingController();
  final TextEditingController _rewriteController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();

  _WriteExerciseType _exerciseType = _WriteExerciseType.dictation;
  String _sourceKey = '';
  String _lastAiPromptKey = '';
  int _lineIndex = 0;
  bool _showAnswer = false;

  _DictationResult? _dictationResult;
  _ClozeResult? _clozeResult;
  _RewriteResult? _rewriteResult;
  _SummaryResult? _summaryResult;

  List<TextEditingController> _blankControllers = [];
  List<_BlankPrompt> _blankPrompts = [];
  List<List<String>> _choiceOptions = [];
  List<String?> _selectedChoices = [];

  @override
  void dispose() {
    _dictationController.dispose();
    _rewriteController.dispose();
    _summaryController.dispose();
    _disposeBlankControllers();
    super.dispose();
  }

  void _disposeBlankControllers() {
    for (final controller in _blankControllers) {
      controller.dispose();
    }
    _blankControllers = [];
  }

  void _ensureExerciseState(TextProvider textProvider) {
    final newKey = [
      textProvider.currentTextPath ?? '',
      textProvider.currentDocument?.title ?? '',
      textProvider.lines.length,
      textProvider.fullText.hashCode,
    ].join('|');

    if (_sourceKey == newKey && textProvider.lines.isNotEmpty) {
      if (_lineIndex >= textProvider.lines.length) {
        _lineIndex = textProvider.lines.length - 1;
        _resetExerciseForLine(textProvider, regenerateCloze: true);
      }
      return;
    }

    _sourceKey = newKey;
    _lineIndex = textProvider.currentLineIndex >= 0 &&
            textProvider.currentLineIndex < textProvider.lines.length
        ? textProvider.currentLineIndex
        : 0;
    _resetExerciseForLine(textProvider, regenerateCloze: true);
  }

  void _resetExerciseForLine(
    TextProvider textProvider, {
    required bool regenerateCloze,
  }) {
    _dictationController.clear();
    _rewriteController.clear();
    _summaryController.clear();
    _dictationResult = null;
    _clozeResult = null;
    _rewriteResult = null;
    _summaryResult = null;
    _showAnswer = false;
    _lastAiPromptKey = '';
    _selectedChoices = [];
    _disposeBlankControllers();

    if (regenerateCloze && textProvider.lines.isNotEmpty) {
      _generateCloze(textProvider);
    } else {
      _blankPrompts = [];
      _choiceOptions = [];
    }
  }

  void _changeLine(TextProvider textProvider, int newIndex) {
    if (textProvider.lines.isEmpty) return;
    final clamped = newIndex.clamp(0, textProvider.lines.length - 1).toInt();
    setState(() {
      _lineIndex = clamped;
      _resetExerciseForLine(textProvider, regenerateCloze: true);
    });
  }

  void _jumpToCurrentLine(TextProvider textProvider) {
    if (textProvider.currentLineIndex < 0 ||
        textProvider.currentLineIndex >= textProvider.lines.length) {
      return;
    }
    _changeLine(textProvider, textProvider.currentLineIndex);
  }

  void _cycleExercise(TextProvider textProvider, _WriteExerciseType type) {
    if (_exerciseType == type) return;
    setState(() {
      _exerciseType = type;
      _resetExerciseForLine(textProvider, regenerateCloze: true);
    });
  }

  void _generateCloze(TextProvider textProvider) {
    if (textProvider.lines.isEmpty) {
      _blankPrompts = [];
      _choiceOptions = [];
      return;
    }

    final line = textProvider.lines[_lineIndex].content;
    final tokens = line.split(RegExp(r'\s+'));
    final analyzedWords = _lineIndex < textProvider.analyzedLines.length
        ? textProvider.analyzedLines[_lineIndex]
        : const [];

    final candidateIndexes = <_RankedCandidate>[];
    for (int i = 0; i < tokens.length; i++) {
      final normalized = _normalizeWord(tokens[i]);
      if (normalized.length < 3) continue;
      if (!_containsLetters(normalized)) continue;

      double score = normalized.length.toDouble();
      final matchIndex = analyzedWords.indexWhere(
        (word) => _normalizeWord(word.originalWord) == normalized,
      );

      if (matchIndex >= 0) {
        final match = analyzedWords[matchIndex];
        if (!match.isStopWord) score += 4;
        switch (match.wordType.name) {
          case 'noun':
          case 'verb':
          case 'adjective':
          case 'adverb':
            score += 3;
            break;
          default:
            score += 0.5;
        }
        switch (match.cefrLevel.name) {
          case 'b2':
          case 'c1':
          case 'c2':
            score += 2.5;
            break;
          case 'b1':
            score += 1.5;
            break;
          case 'a2':
            score += 0.5;
            break;
          default:
            break;
        }
      }

      candidateIndexes.add(_RankedCandidate(index: i, score: score));
    }

    candidateIndexes.sort((a, b) => b.score.compareTo(a.score));

    final blankCount = tokens.length >= 14
        ? 3
        : tokens.length >= 8
            ? 2
            : 1;

    final selected = <int>[];
    for (final candidate in candidateIndexes) {
      if (selected.length >= blankCount) break;
      final tooClose =
          selected.any((value) => (value - candidate.index).abs() < 2);
      if (tooClose) continue;
      selected.add(candidate.index);
    }

    if (selected.isEmpty && tokens.isNotEmpty) {
      selected.add(0);
    }

    selected.sort();

    final prompts = <_BlankPrompt>[];
    for (int i = 0; i < selected.length; i++) {
      final tokenIndex = selected[i];
      prompts.add(
        _BlankPrompt(
          number: i + 1,
          tokenIndex: tokenIndex,
          answer: _normalizeWord(tokens[tokenIndex]),
          originalToken: tokens[tokenIndex],
        ),
      );
    }

    final pool =
        _buildChoicePool(textProvider, prompts.map((e) => e.answer).toSet());
    final options = prompts.map((prompt) {
      final distractors = pool.where((word) => word != prompt.answer).toList()
        ..shuffle(_random);
      final set = <String>{prompt.answer};
      for (final word in distractors) {
        if (set.length >= 4) break;
        set.add(word);
      }
      final list = set.toList()..shuffle(_random);
      return list;
    }).toList();

    _blankPrompts = prompts;
    _choiceOptions = options;
    _selectedChoices = List<String?>.filled(prompts.length, null);
    _blankControllers =
        List.generate(prompts.length, (_) => TextEditingController());
  }

  List<String> _buildChoicePool(
      TextProvider textProvider, Set<String> excluded) {
    final pool = <String>{};
    for (final line in textProvider.lines) {
      final words = line.content.split(RegExp(r'\s+'));
      for (final word in words) {
        final normalized = _normalizeWord(word);
        if (normalized.length >= 3 && _containsLetters(normalized)) {
          pool.add(normalized);
        }
      }
    }
    pool.removeWhere(excluded.contains);
    return pool.toList();
  }

  Future<void> _speakCurrentLine(TextProvider textProvider) async {
    if (textProvider.lines.isEmpty) return;
    await textProvider.speak(textProvider.lines[_lineIndex].content);
  }

  void _scoreDictation(TextProvider textProvider) {
    if (textProvider.lines.isEmpty) return;

    final expected = textProvider.lines[_lineIndex].content;
    final actual = _dictationController.text.trim();

    final expectedTokens = _tokenizeNormalized(expected);
    final actualTokens = _tokenizeNormalized(actual);
    final expectedText = expectedTokens.join(' ');
    final actualText = actualTokens.join(' ');

    final lcs = _longestCommonSubsequence(expectedTokens, actualTokens);
    final orderScore =
        expectedTokens.isEmpty ? 0.0 : lcs / expectedTokens.length;
    final charScore = _stringSimilarity(expectedText, actualText);
    final finalScore =
        ((orderScore * 0.7) + (charScore * 0.3)).clamp(0.0, 1.0).toDouble();

    final missing = _subtractMultiset(expectedTokens, actualTokens);
    final extra = _subtractMultiset(actualTokens, expectedTokens);

    setState(() {
      _dictationResult = _DictationResult(
        score: finalScore,
        orderScore: orderScore,
        spellingScore: charScore,
        missingWords: missing,
        extraWords: extra,
      );
      _showAnswer = true;
    });
  }

  void _checkCloze() {
    if (_blankPrompts.isEmpty) return;

    int correct = 0;
    final userAnswers = <String>[];

    for (int i = 0; i < _blankPrompts.length; i++) {
      final prompt = _blankPrompts[i];
      final answer = _exerciseType == _WriteExerciseType.clozeChoice
          ? (_selectedChoices[i] ?? '')
          : _blankControllers[i].text;
      final normalized = _normalizeWord(answer);
      userAnswers.add(normalized);
      if (normalized == prompt.answer) correct++;
    }

    setState(() {
      _clozeResult = _ClozeResult(
        correctCount: correct,
        totalCount: _blankPrompts.length,
        userAnswers: userAnswers,
      );
      _showAnswer = true;
    });
  }

  String _normalizeWord(String input) {
    return input.toLowerCase().replaceAll(RegExp(r"[^a-z0-9']"), '').trim();
  }

  bool _containsLetters(String input) {
    return RegExp(r'[a-z]').hasMatch(input);
  }

  List<String> _tokenizeNormalized(String input) {
    return input
        .split(RegExp(r'\s+'))
        .map(_normalizeWord)
        .where((word) => word.isNotEmpty)
        .toList();
  }

  int _longestCommonSubsequence(List<String> a, List<String> b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final dp = List.generate(a.length + 1, (_) => List.filled(b.length + 1, 0));
    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        if (a[i - 1] == b[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
        } else {
          dp[i][j] = math.max(dp[i - 1][j], dp[i][j - 1]);
        }
      }
    }
    return dp[a.length][b.length];
  }

  double _stringSimilarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    final distance = _levenshteinDistance(a, b);
    final maxLen = math.max(a.length, b.length);
    return (1 - (distance / maxLen)).clamp(0.0, 1.0).toDouble();
  }

  int _levenshteinDistance(String a, String b) {
    final rows = a.length + 1;
    final cols = b.length + 1;
    final matrix = List.generate(rows, (_) => List.filled(cols, 0));

    for (int i = 0; i < rows; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j < cols; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i < rows; i++) {
      for (int j = 1; j < cols; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce(math.min);
      }
    }

    return matrix[a.length][b.length];
  }

  List<String> _subtractMultiset(List<String> source, List<String> toRemove) {
    final counts = <String, int>{};
    for (final item in source) {
      counts[item] = (counts[item] ?? 0) + 1;
    }
    for (final item in toRemove) {
      final current = counts[item] ?? 0;
      if (current > 0) counts[item] = current - 1;
    }

    final result = <String>[];
    counts.forEach((key, value) {
      for (int i = 0; i < value; i++) {
        result.add(key);
      }
    });
    return result;
  }

  Set<String> _extractRewriteKeywords(TextProvider textProvider) {
    final analyzedWords = _lineIndex < textProvider.analyzedLines.length
        ? textProvider.analyzedLines[_lineIndex]
        : const [];

    final keywords = <String>{};
    for (final word in analyzedWords) {
      final normalized = _normalizeWord(word.originalWord);
      if (normalized.length < 3 || word.isStopWord) continue;
      switch (word.wordType.name) {
        case 'noun':
        case 'verb':
        case 'adjective':
        case 'adverb':
          keywords.add(normalized);
          break;
        default:
          if (normalized.length >= 5) keywords.add(normalized);
      }
    }

    if (keywords.isNotEmpty) return keywords.take(6).toSet();

    return _tokenizeNormalized(textProvider.lines[_lineIndex].content)
        .where((word) => word.length >= 4)
        .take(6)
        .toSet();
  }

  List<String> _extractExpectedVerbs(TextProvider textProvider) {
    final analyzedWords = _lineIndex < textProvider.analyzedLines.length
        ? textProvider.analyzedLines[_lineIndex]
        : const [];

    final verbs = analyzedWords
        .where((word) => word.wordType.name == 'verb')
        .map((word) => _normalizeWord(word.originalWord))
        .where((word) => word.isNotEmpty)
        .toSet()
        .toList();

    return verbs;
  }

  double _grammarProxyScore(
      String rawText, List<String> tokens, List<String> expectedVerbs) {
    if (tokens.isEmpty) return 0.0;

    final trimmed = rawText.trim();
    final firstChar = trimmed.isNotEmpty ? trimmed[0] : '';
    final startsUppercase =
        firstChar.isNotEmpty && firstChar.toUpperCase() == firstChar;
    final hasSentenceEnding =
        trimmed.endsWith('.') || trimmed.endsWith('!') || trimmed.endsWith('?');
    final enoughWords = tokens.length >= 4;
    const commonVerbs = {
      'is',
      'are',
      'was',
      'were',
      'be',
      'am',
      'do',
      'does',
      'did',
      'have',
      'has',
      'had',
      'go',
      'goes',
      'went',
      'make',
      'makes',
      'made',
      'say',
      'says',
      'said',
      'get',
      'gets',
      'got',
      'think',
      'thinks',
      'thought',
      'learn',
      'learns',
      'learned',
      'study',
      'studies'
    };
    final hasVerbLike = tokens.any((token) =>
        expectedVerbs.contains(token) || commonVerbs.contains(token));

    double score = 0.0;
    score += enoughWords ? 0.35 : 0.12;
    score += hasVerbLike ? 0.35 : 0.12;
    score += startsUppercase ? 0.15 : 0.05;
    score += hasSentenceEnding ? 0.15 : 0.05;
    return score.clamp(0.0, 1.0).toDouble();
  }

  void _scoreRewrite(TextProvider textProvider) {
    if (textProvider.lines.isEmpty) return;

    final expected = textProvider.lines[_lineIndex].content;
    final actual = _rewriteController.text.trim();
    final actualTokens = _tokenizeNormalized(actual);
    if (actualTokens.isEmpty) return;

    final keywords = _extractRewriteKeywords(textProvider);
    final usedKeywords = actualTokens.where(keywords.contains).toSet().toList()
      ..sort();
    final missingKeywords =
        keywords.where((word) => !usedKeywords.contains(word)).toList()..sort();
    final completenessScore = keywords.isEmpty
        ? _stringSimilarity(
            _tokenizeNormalized(expected).join(' '), actualTokens.join(' '))
        : (usedKeywords.length / keywords.length).clamp(0.0, 1.0).toDouble();

    final similarityToOriginal = _stringSimilarity(
      _tokenizeNormalized(expected).join(' '),
      actualTokens.join(' '),
    );

    double paraphraseScore;
    if (similarityToOriginal >= 0.94) {
      paraphraseScore = 0.18;
    } else if (similarityToOriginal >= 0.82) {
      paraphraseScore = 0.38;
    } else if (similarityToOriginal >= 0.58) {
      paraphraseScore = 0.82;
    } else if (similarityToOriginal >= 0.34) {
      paraphraseScore = completenessScore >= 0.45 ? 0.72 : 0.5;
    } else {
      paraphraseScore = completenessScore >= 0.45 ? 0.64 : 0.28;
    }

    final grammarScore = _grammarProxyScore(
      actual,
      actualTokens,
      _extractExpectedVerbs(textProvider),
    );

    final overall = ((completenessScore * 0.5) +
            (grammarScore * 0.22) +
            (paraphraseScore * 0.28))
        .clamp(0.0, 1.0)
        .toDouble();

    setState(() {
      _rewriteResult = _RewriteResult(
        overallScore: overall,
        completenessScore: completenessScore,
        grammarScore: grammarScore,
        paraphraseScore: paraphraseScore,
        similarityToOriginal: similarityToOriginal,
        usedKeywords: usedKeywords,
        missingKeywords: missingKeywords,
      );
      _showAnswer = true;
    });
  }

  void _scoreSummary(TextProvider textProvider) {
    if (textProvider.lines.isEmpty) return;

    final expected = textProvider.lines[_lineIndex].content;
    final actual = _summaryController.text.trim();
    final actualTokens = _tokenizeNormalized(actual);
    if (actualTokens.isEmpty) return;

    final expectedTokens = _tokenizeNormalized(expected);
    final keywords = _extractRewriteKeywords(textProvider);
    final keptKeywords = actualTokens.where(keywords.contains).toSet().toList()
      ..sort();
    final missedKeywords =
        keywords.where((word) => !keptKeywords.contains(word)).toList()..sort();

    final contentRetention = keywords.isEmpty
        ? _stringSimilarity(expectedTokens.join(' '), actualTokens.join(' '))
        : (keptKeywords.length / keywords.length).clamp(0.0, 1.0).toDouble();

    final compressionRatio = expectedTokens.isEmpty
        ? 1.0
        : (actualTokens.length / expectedTokens.length)
            .clamp(0.0, 2.0)
            .toDouble();

    double brevityScore;
    if (compressionRatio <= 0.45) {
      brevityScore = contentRetention >= 0.45 ? 0.92 : 0.5;
    } else if (compressionRatio <= 0.7) {
      brevityScore = 0.82;
    } else if (compressionRatio <= 1.0) {
      brevityScore = 0.64;
    } else {
      brevityScore = 0.32;
    }

    final grammarScore = _grammarProxyScore(
      actual,
      actualTokens,
      _extractExpectedVerbs(textProvider),
    );

    final overall = ((contentRetention * 0.5) +
            (brevityScore * 0.25) +
            (grammarScore * 0.25))
        .clamp(0.0, 1.0)
        .toDouble();

    setState(() {
      _summaryResult = _SummaryResult(
        overallScore: overall,
        contentRetentionScore: contentRetention,
        brevityScore: brevityScore,
        grammarScore: grammarScore,
        compressionRatio: compressionRatio,
        keptKeywords: keptKeywords,
        missedKeywords: missedKeywords,
      );
      _showAnswer = true;
    });
  }

  String _buildAiPrompt({
    required String expected,
    required String actual,
    required _DictationResult result,
  }) {
    return '''
in4up_WRITE_REVIEW
EXPECTED: $expected
ACTUAL: $actual
TOTAL_SCORE: ${(result.score * 100).round()}
ORDER_SCORE: ${(result.orderScore * 100).round()}
SPELLING_SCORE: ${(result.spellingScore * 100).round()}
MISSING: ${result.missingWords.isEmpty ? 'none' : result.missingWords.join(', ')}
EXTRA: ${result.extraWords.isEmpty ? 'none' : result.extraWords.join(', ')}

You are the offline writing feedback bot of in4up.
Return valid JSON with:
- summary: short feedback in English
- topics: 2-4 short labels
- action_items: 2-4 specific next practice suggestions
- grammar: if possible, short description of subject/verb/object/pattern/explanation
''';
  }

  String _buildRewriteAiPrompt({
    required String expected,
    required String actual,
    required _RewriteResult result,
  }) {
    return '''
in4up_REWRITE_REVIEW
EXPECTED: $expected
ACTUAL: $actual
TOTAL_SCORE: ${(result.overallScore * 100).round()}
CONTENT_SCORE: ${(result.completenessScore * 100).round()}
GRAMMAR_SCORE: ${(result.grammarScore * 100).round()}
PARAPHRASE_SCORE: ${(result.paraphraseScore * 100).round()}
MISSING: ${result.missingKeywords.isEmpty ? 'none' : result.missingKeywords.join(', ')}
KEPT: ${result.usedKeywords.isEmpty ? 'none' : result.usedKeywords.join(', ')}

You are the offline paraphrase feedback bot of in4up.
Return valid JSON with:
- summary: short feedback in English
- topics: 2-4 short labels
- action_items: 2-4 specific next practice suggestions
- grammar: quick description of sentence shape and what needs fixing
''';
  }

  String _buildSummaryAiPrompt({
    required String expected,
    required String actual,
    required _SummaryResult result,
  }) {
    return '''
in4up_SUMMARY_REVIEW
EXPECTED: $expected
ACTUAL: $actual
TOTAL_SCORE: ${(result.overallScore * 100).round()}
CONTENT_SCORE: ${(result.contentRetentionScore * 100).round()}
BREVITY_SCORE: ${(result.brevityScore * 100).round()}
GRAMMAR_SCORE: ${(result.grammarScore * 100).round()}
COMPRESSION: ${result.compressionLabel}
MISSED: ${result.missedKeywords.isEmpty ? 'none' : result.missedKeywords.join(', ')}
KEPT: ${result.keptKeywords.isEmpty ? 'none' : result.keptKeywords.join(', ')}

You are the offline summary feedback bot of in4up.
Return valid JSON with:
- summary: short feedback in English
- topics: 2-4 short labels
- action_items: 2-4 specific next practice suggestions
- grammar: quick description of conciseness, clarity and sentence shape
''';
  }

  Future<void> _runAiReview({
    required TextItem currentLine,
    required _DictationResult result,
  }) async {
    final actual = _dictationController.text.trim();
    if (actual.isEmpty) return;

    final facade = context.read<AiServiceFacade>();
    final prompt = _buildAiPrompt(
      expected: currentLine.content,
      actual: actual,
      result: result,
    );

    facade.clearAnalysis();
    setState(() {
      _lastAiPromptKey = prompt;
    });

    await facade.analyzeSentence(sentence: prompt);
    if (mounted) setState(() {});
  }

  Future<void> _runRewriteAiReview({
    required TextItem currentLine,
    required _RewriteResult result,
  }) async {
    final actual = _rewriteController.text.trim();
    if (actual.isEmpty) return;

    final facade = context.read<AiServiceFacade>();
    final prompt = _buildRewriteAiPrompt(
      expected: currentLine.content,
      actual: actual,
      result: result,
    );

    facade.clearAnalysis();
    setState(() {
      _lastAiPromptKey = prompt;
    });

    await facade.analyzeSentence(sentence: prompt);
    if (mounted) setState(() {});
  }

  Future<void> _runSummaryAiReview({
    required TextItem currentLine,
    required _SummaryResult result,
  }) async {
    final actual = _summaryController.text.trim();
    if (actual.isEmpty) return;

    final facade = context.read<AiServiceFacade>();
    final prompt = _buildSummaryAiPrompt(
      expected: currentLine.content,
      actual: actual,
      result: result,
    );

    facade.clearAnalysis();
    setState(() {
      _lastAiPromptKey = prompt;
    });

    await facade.analyzeSentence(sentence: prompt);
    if (mounted) setState(() {});
  }

  bool _hasMatchingAiAnalysis(AiServiceFacade facade) {
    final analysis = facade.currentAnalysis;
    if (analysis == null) return false;
    return analysis.inputText == _lastAiPromptKey;
  }

  Future<void> _showAiModelSetupDialog(AiServiceFacade facade) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const TrText('Cài đặt AI local'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TrText('Để dùng phản hồi AI cục bộ, hãy import model .gguf vào thiết bị.'),
            SizedBox(height: 8),
            TrText('Khuyến nghị: gemma-2b-it-q4_k_m.gguf (~1.5GB)'),
            SizedBox(height: 8),
            TrText('Khi chưa có model, phần Chấm nhanh vẫn hoạt động hoàn toàn offline.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const TrText('Để sau'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await facade.importModelFromUser();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? 'Content'
                        : 'Content',
                  ),
                ),
              );
              setState(() {});
            },
            child: const TrText('Chọn file .gguf'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF080B1A),
      child: Consumer<TextProvider>(
        builder: (context, textProvider, _) {
          final hasText = textProvider.hasLyrics;
          if (hasText) {
            _ensureExerciseState(textProvider);
          }

          final source = textProvider.currentTextPath;
          final currentTitle =
              textProvider.currentDocument?.title ?? 'Content';
          final currentLine = hasText ? textProvider.lines[_lineIndex] : null;
          final activeLineIndex = textProvider.currentLineIndex;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
            child: ResponsiveContentFrame(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeroCard(
                    hasText: hasText,
                    source: source,
                    lineCount: textProvider.lines.length,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _QuickActionChip(
                        icon: Icons.language,
                        label: 'Web Reader',
                        color: const Color(0xFF26A69A),
                        onTap: widget.onOpenWebReader,
                      ),
                      _QuickActionChip(
                        icon: Icons.picture_as_pdf,
                        label: 'PDF Reader',
                        color: const Color(0xFFEF5350),
                        onTap: widget.onOpenPdfReader,
                      ),
                      _QuickActionChip(
                        icon: Icons.auto_awesome,
                        label: context.tr('Công cụ nhanh'),
                        color: const Color(0xFF26C6DA),
                        onTap: widget.onOpenQuickActions,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (!hasText)
                    _EmptyTextCard(
                      onOpenWebReader: widget.onOpenWebReader,
                      onOpenPdfReader: widget.onOpenPdfReader,
                    )
                  else ...[
                    _buildContextCard(
                      title: currentTitle,
                      currentLine: currentLine!,
                      totalLines: textProvider.lines.length,
                      activeLineIndex: activeLineIndex,
                      onJumpToActive: activeLineIndex >= 0
                          ? () => _jumpToCurrentLine(textProvider)
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _buildExerciseSelector(textProvider),
                    const SizedBox(height: 16),
                    _buildLineNavigator(textProvider),
                    const SizedBox(height: 16),
                    if (_exerciseType == _WriteExerciseType.dictation)
                      _buildDictationCard(textProvider, currentLine!)
                    else if (_exerciseType == _WriteExerciseType.rewrite)
                      _buildRewriteCard(textProvider, currentLine!)
                    else if (_exerciseType == _WriteExerciseType.summary)
                      _buildSummaryCard(textProvider, currentLine!)
                    else
                      _buildClozeCard(currentLine!),
                    const SizedBox(height: 20),
                    const _TipCard(
                      title: context.tr('Vai trò của tab Viết'),
                      bullets: [
                        'Content',
                        'Content',
                        'Content',
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContextCard({
    required String title,
    required TextItem currentLine,
    required int totalLines,
    required int activeLineIndex,
    VoidCallback? onJumpToActive,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.article_outlined, color: Color(0xFF80DEEA)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF26C6DA).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Dòng ${_lineIndex + 1}/$totalLines',
                  style: const TextStyle(
                    color: Color(0xFF26C6DA),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            currentLine.content,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          if (onJumpToActive != null && activeLineIndex != _lineIndex) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onJumpToActive,
              icon: const Icon(Icons.sync_alt, size: 18),
              label: Text(
                  'Dùng dòng đang focus trong tab Đọc (#${activeLineIndex + 1})'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExerciseSelector(TextProvider textProvider) {
    final items = [
      (
        label: context.tr('Chép'),
        type: _WriteExerciseType.dictation,
        color: const Color(0xFF26C6DA),
      ),
      (
        label: context.tr('Điền từ'),
        type: _WriteExerciseType.clozeInput,
        color: const Color(0xFFFFB300),
      ),
      (
        label: context.tr('Chọn đáp án'),
        type: _WriteExerciseType.clozeChoice,
        color: const Color(0xFFAB47BC),
      ),
      (
        label: context.tr('Viết lại ý'),
        type: _WriteExerciseType.rewrite,
        color: const Color(0xFF4CAF50),
      ),
      (
        label: context.tr('Tóm tắt ngắn'),
        type: _WriteExerciseType.summary,
        color: const Color(0xFF81C784),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth - 8) / 2;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map(
                  (item) => SizedBox(
                    width: itemWidth,
                    child: _ExerciseSelectorChip(
                      label: item.label,
                      selected: _exerciseType == item.type,
                      color: item.color,
                      onTap: () => _cycleExercise(textProvider, item.type),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }

  Widget _buildLineNavigator(TextProvider textProvider) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF121827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bộ điều hướng bài tập',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _lineIndex > 0
                      ? () => _changeLine(textProvider, _lineIndex - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                  label: const TrText('Trước'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: textProvider.lines.length > 1
                      ? () => _changeLine(textProvider,
                          _random.nextInt(textProvider.lines.length))
                      : null,
                  icon: const Icon(Icons.shuffle),
                  label: const TrText('Ngẫu nhiên'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _lineIndex < textProvider.lines.length - 1
                      ? () => _changeLine(textProvider, _lineIndex + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('Sau'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDictationCard(TextProvider textProvider, TextItem currentLine) {
    final result = _dictationResult;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121827),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: const Color(0xFF26C6DA).withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note, color: Color(0xFF26C6DA)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Chép chính tả / Recall câu',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (result != null)
                _ScorePill(
                    score: result.score, accent: const Color(0xFF26C6DA)),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Nghe lại bằng TTS hoặc tự nhìn nhanh rồi gõ lại từ trí nhớ.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _speakCurrentLine(textProvider),
                icon: const Icon(Icons.volume_up_rounded),
                label: const TrText('Đọc câu'),
              ),
              const SizedBox(width: 10),
              TextButton.icon(
                onPressed: () => setState(() => _showAnswer = !_showAnswer),
                icon:
                    Icon(_showAnswer ? Icons.visibility_off : Icons.visibility),
                label: Text(_showAnswer ? 'Content' : 'Content'),
              ),
            ],
          ),
          if (_showAnswer) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                currentLine.content,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 13, height: 1.4),
              ),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _dictationController,
            onChanged: (_) {
              if (_dictationResult != null || _lastAiPromptKey.isNotEmpty) {
                setState(() {
                  _dictationResult = null;
                  _lastAiPromptKey = '';
                });
              }
            },
            minLines: 4,
            maxLines: 6,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: context.tr('Nhập lại câu bạn nghe hoặc nhớ được...'),
              hintStyle: TextStyle(color: Colors.grey[500]),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _scoreDictation(textProvider),
                  icon: const Icon(Icons.grading_rounded),
                  label: const TrText('Chấm nhanh'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _dictationController.clear();
                      _dictationResult = null;
                      _lastAiPromptKey = '';
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const TrText('Làm lại'),
                ),
              ),
            ],
          ),
          if (result != null) ...[
            const SizedBox(height: 16),
            _FeedbackCard(
              title: result.feedbackLabel,
              color: result.feedbackColor,
              children: [
                _MetricRow(
                    label: context.tr('Thứ tự câu'),
                    value: '${(result.orderScore * 100).round()}%'),
                _MetricRow(
                    label: context.tr('Độ sát chính tả'),
                    value: '${(result.spellingScore * 100).round()}%'),
                _MetricRow(
                    label: context.tr('Từ thiếu'),
                    value: result.missingWords.isEmpty
                        ? 'No'
                        : result.missingWords.join(', ')),
                _MetricRow(
                    label: context.tr('Từ dư'),
                    value: result.extraWords.isEmpty
                        ? 'No'
                        : result.extraWords.join(', ')),
              ],
            ),
            const SizedBox(height: 16),
            _buildAiReviewCard(currentLine: currentLine, result: result),
          ],
        ],
      ),
    );
  }

  Widget _buildAiReviewCard({
    required TextItem currentLine,
    required _DictationResult result,
  }) {
    final facade = context.watch<AiServiceFacade>();
    final hasTextInput = _dictationController.text.trim().isNotEmpty;
    final hasMatchingAnalysis = _hasMatchingAiAnalysis(facade);
    final analysis = hasMatchingAnalysis ? facade.currentAnalysis : null;
    final isLoadingCurrent = facade.isLoading && _lastAiPromptKey.isNotEmpty;
    final coach = _LocalCoachInsight.fromResult(result);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121827),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: const Color(0xFF7C4DFF).withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_alt_outlined,
                  color: Color(0xFFB388FF)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Phản hồi sâu 2 tầng',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: facade.hasModel
                      ? const Color(0xFF4CAF50).withValues(alpha: 0.12)
                      : Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  facade.hasModel ? 'Content' : 'Content',
                  style: TextStyle(
                    color: facade.hasModel
                        ? const Color(0xFF81C784)
                        : Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Tầng 1 luôn chạy offline bằng phân tích cục bộ. Tầng 2 dùng AI local để cho phản hồi sâu hơn khi model đã sẵn sàng.',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 14),
          _FeedbackCard(
            title: context.tr('Tầng 1 · Huấn luyện cục bộ'),
            color: coach.color,
            children: [
              _MetricRow(label: context.tr('Kết luận'), value: coach.summary),
              _MetricRow(label: context.tr('Thế mạnh'), value: coach.strength),
              _MetricRow(label: context.tr('Điểm cần sửa'), value: coach.primaryIssue),
              _MetricRow(label: context.tr('Lượt tiếp theo'), value: coach.nextStep),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: coach.tags
                .map(
                  (tag) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: coach.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        color: coach.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      !facade.hasModel || !hasTextInput || isLoadingCurrent
                          ? null
                          : () => _runAiReview(
                              currentLine: currentLine, result: result),
                  icon: const Icon(Icons.auto_awesome),
                  label: const TrText('Tầng 2 · AI local'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showAiModelSetupDialog(facade),
                  icon: const Icon(Icons.download_outlined),
                  label: Text(facade.hasModel ? 'Content' : 'Content'),
                ),
              ),
            ],
          ),
          if (isLoadingCurrent) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text(
              'Đang phân tích bằng AI local...',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
          if (analysis != null) ...[
            const SizedBox(height: 16),
            _FeedbackCard(
              title: 'Tầng 2 · ${facade.modelSourceLabel}',
              color: const Color(0xFFB388FF),
              children: [
                _MetricRow(
                  label: context.tr('Tóm tắt'),
                  value: analysis.summary.isNotEmpty
                      ? analysis.summary
                      : 'Content',
                ),
                _MetricRow(
                  label: context.tr('Chủ điểm'),
                  value: analysis.topics.isEmpty
                      ? 'No'
                      : analysis.topics.join(', '),
                ),
                _MetricRow(
                  label: context.tr('Hành động'),
                  value: analysis.actionItems.isEmpty
                      ? 'Content'
                      : analysis.actionItems.join(' • '),
                ),
                if (analysis.grammar != null) ...[
                  _MetricRow(
                      label: context.tr('Chủ ngữ'), value: analysis.grammar!.subject),
                  _MetricRow(label: context.tr('Động từ'), value: analysis.grammar!.verb),
                  _MetricRow(
                      label: context.tr('Mẫu câu'), value: analysis.grammar!.pattern),
                ],
              ],
            ),
          ],
          if (facade.lastError != null &&
              !isLoadingCurrent &&
              analysis == null) ...[
            const SizedBox(height: 12),
            Text(
              'Lỗi AI: ${facade.lastError}',
              style: const TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRewriteCard(TextProvider textProvider, TextItem currentLine) {
    final result = _rewriteResult;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121827),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_outlined, color: Color(0xFF4CAF50)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Viết lại ý bằng câu khác',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (result != null)
                _ScorePill(
                    score: result.overallScore,
                    accent: const Color(0xFF4CAF50)),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Giữ lại ý chính của câu gốc nhưng thử diễn đạt lại theo cách của riêng bạn.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              currentLine.content,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13, height: 1.4),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _rewriteController,
            onChanged: (_) {
              if (_rewriteResult != null || _lastAiPromptKey.isNotEmpty) {
                setState(() {
                  _rewriteResult = null;
                  _lastAiPromptKey = '';
                });
              }
            },
            minLines: 4,
            maxLines: 6,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: context.tr('Viết lại cùng ý, không cần chép y nguyên câu gốc...'),
              hintStyle: TextStyle(color: Colors.grey[500]),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _scoreRewrite(textProvider),
                  icon: const Icon(Icons.analytics_outlined),
                  label: const TrText('Phân tích bài viết'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _rewriteController.clear();
                      _rewriteResult = null;
                      _lastAiPromptKey = '';
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const TrText('Làm lại'),
                ),
              ),
            ],
          ),
          if (result != null) ...[
            const SizedBox(height: 16),
            _FeedbackCard(
              title: result.feedbackLabel,
              color: result.feedbackColor,
              children: [
                _MetricRow(
                    label: context.tr('Giữ ý'),
                    value: '${(result.completenessScore * 100).round()}%'),
                _MetricRow(
                    label: context.tr('Hình dáng câu'),
                    value: '${(result.grammarScore * 100).round()}%'),
                _MetricRow(
                    label: context.tr('Độ viết lại'),
                    value: '${(result.paraphraseScore * 100).round()}%'),
                _MetricRow(
                    label: context.tr('Từ khóa đã giữ'),
                    value: result.usedKeywords.isEmpty
                        ? 'Content'
                        : result.usedKeywords.join(', ')),
                _MetricRow(
                    label: context.tr('Từ khóa còn thiếu'),
                    value: result.missingKeywords.isEmpty
                        ? 'No'
                        : result.missingKeywords.join(', ')),
                _MetricRow(label: context.tr('Nhận xét'), value: result.summary),
                _MetricRow(label: context.tr('Điểm mạnh'), value: result.strength),
                _MetricRow(label: context.tr('Điểm cần sửa'), value: result.primaryIssue),
                _MetricRow(label: context.tr('Bước tiếp theo'), value: result.nextStep),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: result.tags
                  .map(
                    (tag) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: result.feedbackColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          color: result.feedbackColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            _buildRewriteAiReviewCard(currentLine: currentLine, result: result),
          ],
        ],
      ),
    );
  }

  Widget _buildRewriteAiReviewCard({
    required TextItem currentLine,
    required _RewriteResult result,
  }) {
    final facade = context.watch<AiServiceFacade>();
    final hasTextInput = _rewriteController.text.trim().isNotEmpty;
    final hasMatchingAnalysis = _hasMatchingAiAnalysis(facade);
    final analysis = hasMatchingAnalysis ? facade.currentAnalysis : null;
    final isLoadingCurrent = facade.isLoading && _lastAiPromptKey.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121827),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: const Color(0xFF81C784).withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_fix_high_outlined,
                  color: Color(0xFF81C784)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Tầng 2 · AI cho viết lại ý',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: facade.hasModel
                      ? const Color(0xFF4CAF50).withValues(alpha: 0.12)
                      : Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  facade.hasModel ? 'Content' : 'No model',
                  style: TextStyle(
                    color: facade.hasModel
                        ? const Color(0xFF81C784)
                        : Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Dùng AI local để xem bài viết lại đã đủ giữ ý, đủ khác câu gốc và đủ tự nhiên hay chưa.',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      !facade.hasModel || !hasTextInput || isLoadingCurrent
                          ? null
                          : () => _runRewriteAiReview(
                              currentLine: currentLine, result: result),
                  icon: const Icon(Icons.auto_awesome),
                  label: const TrText('Phân tích rewrite'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showAiModelSetupDialog(facade),
                  icon: const Icon(Icons.download_outlined),
                  label: Text(facade.hasModel ? 'Content' : 'Content'),
                ),
              ),
            ],
          ),
          if (isLoadingCurrent) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text(
              'AI local đang phân tích mức độ viết lại và độ tự nhiên của câu...',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
          if (analysis != null) ...[
            const SizedBox(height: 16),
            _FeedbackCard(
              title: 'AI rewrite · ${facade.modelSourceLabel}',
              color: const Color(0xFF81C784),
              children: [
                _MetricRow(
                  label: context.tr('Tóm tắt'),
                  value: analysis.summary.isNotEmpty
                      ? analysis.summary
                      : 'Content',
                ),
                _MetricRow(
                  label: context.tr('Chủ điểm'),
                  value: analysis.topics.isEmpty
                      ? 'No'
                      : analysis.topics.join(', '),
                ),
                _MetricRow(
                  label: context.tr('Gợi ý'),
                  value: analysis.actionItems.isEmpty
                      ? 'Content'
                      : analysis.actionItems.join(' • '),
                ),
                if (analysis.grammar != null) ...[
                  _MetricRow(
                      label: context.tr('Chủ ngữ'), value: analysis.grammar!.subject),
                  _MetricRow(label: context.tr('Động từ'), value: analysis.grammar!.verb),
                  _MetricRow(
                      label: context.tr('Mẫu câu'), value: analysis.grammar!.pattern),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(TextProvider textProvider, TextItem currentLine) {
    final result = _summaryResult;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121827),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: const Color(0xFF81C784).withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.short_text_rounded, color: Color(0xFF81C784)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Tóm tắt ý bằng câu ngắn',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (result != null)
                _ScorePill(
                    score: result.overallScore,
                    accent: const Color(0xFF81C784)),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Hãy rút gọn nội dung câu gốc thành một câu ngắn hơn nhưng vẫn giữ ý chính.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              currentLine.content,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13, height: 1.4),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _summaryController,
            onChanged: (_) {
              if (_summaryResult != null || _lastAiPromptKey.isNotEmpty) {
                setState(() {
                  _summaryResult = null;
                  _lastAiPromptKey = '';
                });
              }
            },
            minLines: 3,
            maxLines: 5,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: context.tr('Viết một phiên bản ngắn hơn, rõ hơn, giữ đúng ý chính...'),
              hintStyle: TextStyle(color: Colors.grey[500]),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _scoreSummary(textProvider),
                  icon: const Icon(Icons.compress_outlined),
                  label: const TrText('Chấm tóm tắt'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _summaryController.clear();
                      _summaryResult = null;
                      _lastAiPromptKey = '';
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const TrText('Làm lại'),
                ),
              ),
            ],
          ),
          if (result != null) ...[
            const SizedBox(height: 16),
            _FeedbackCard(
              title: result.feedbackLabel,
              color: result.feedbackColor,
              children: [
                _MetricRow(
                    label: context.tr('Giữ ý'),
                    value: '${(result.contentRetentionScore * 100).round()}%'),
                _MetricRow(
                    label: context.tr('Độ cô đọng'),
                    value: '${(result.brevityScore * 100).round()}%'),
                _MetricRow(
                    label: context.tr('Hình dáng câu'),
                    value: '${(result.grammarScore * 100).round()}%'),
                _MetricRow(
                    label: context.tr('Tỉ lệ độ dài'), value: result.compressionLabel),
                _MetricRow(
                    label: context.tr('Từ khóa đã giữ'),
                    value: result.keptKeywords.isEmpty
                        ? 'Content'
                        : result.keptKeywords.join(', ')),
                _MetricRow(
                    label: context.tr('Từ khóa còn thiếu'),
                    value: result.missedKeywords.isEmpty
                        ? 'No'
                        : result.missedKeywords.join(', ')),
                _MetricRow(label: context.tr('Nhận xét'), value: result.summary),
                _MetricRow(label: context.tr('Bước tiếp theo'), value: result.nextStep),
              ],
            ),
            const SizedBox(height: 16),
            _buildSummaryAiReviewCard(currentLine: currentLine, result: result),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryAiReviewCard({
    required TextItem currentLine,
    required _SummaryResult result,
  }) {
    final facade = context.watch<AiServiceFacade>();
    final hasTextInput = _summaryController.text.trim().isNotEmpty;
    final hasMatchingAnalysis = _hasMatchingAiAnalysis(facade);
    final analysis = hasMatchingAnalysis ? facade.currentAnalysis : null;
    final isLoadingCurrent = facade.isLoading && _lastAiPromptKey.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121827),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: const Color(0xFFA5D6A7).withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_graph_outlined, color: Color(0xFFA5D6A7)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Tầng 2 · AI cho tóm tắt',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: facade.hasModel
                      ? const Color(0xFF4CAF50).withValues(alpha: 0.12)
                      : Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  facade.hasModel ? 'Content' : 'No model',
                  style: TextStyle(
                    color: facade.hasModel
                        ? const Color(0xFF81C784)
                        : Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Dùng AI local để xem bản tóm tắt có đủ ý chính, đủ ngắn gọn và đủ rõ ràng hay chưa.',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      !facade.hasModel || !hasTextInput || isLoadingCurrent
                          ? null
                          : () => _runSummaryAiReview(
                              currentLine: currentLine, result: result),
                  icon: const Icon(Icons.auto_awesome),
                  label: const TrText('Phân tích tóm tắt'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showAiModelSetupDialog(facade),
                  icon: const Icon(Icons.download_outlined),
                  label: Text(facade.hasModel ? 'Content' : 'Content'),
                ),
              ),
            ],
          ),
          if (isLoadingCurrent) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text(
              'AI local đang kiểm tra độ cô đọng và mức giữ ý của bản tóm tắt...',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
          if (analysis != null) ...[
            const SizedBox(height: 16),
            _FeedbackCard(
              title: 'AI summary · ${facade.modelSourceLabel}',
              color: const Color(0xFFA5D6A7),
              children: [
                _MetricRow(
                  label: context.tr('Tóm tắt'),
                  value: analysis.summary.isNotEmpty
                      ? analysis.summary
                      : 'Content',
                ),
                _MetricRow(
                  label: context.tr('Chủ điểm'),
                  value: analysis.topics.isEmpty
                      ? 'No'
                      : analysis.topics.join(', '),
                ),
                _MetricRow(
                  label: context.tr('Gợi ý'),
                  value: analysis.actionItems.isEmpty
                      ? 'Content'
                      : analysis.actionItems.join(' • '),
                ),
                if (analysis.grammar != null) ...[
                  _MetricRow(
                      label: context.tr('Chủ ngữ'), value: analysis.grammar!.subject),
                  _MetricRow(label: context.tr('Động từ'), value: analysis.grammar!.verb),
                  _MetricRow(
                      label: context.tr('Mẫu câu'), value: analysis.grammar!.pattern),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildClozeCard(TextItem currentLine) {
    final result = _clozeResult;
    final isChoice = _exerciseType == _WriteExerciseType.clozeChoice;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (isChoice ? const Color(0xFFAB47BC) : const Color(0xFFFFB300))
              .withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isChoice ? Icons.quiz_outlined : Icons.rule_folder_outlined,
                color: isChoice
                    ? const Color(0xFFAB47BC)
                    : const Color(0xFFFFB300),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isChoice ? 'Content' : 'Content',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (result != null)
                _ScorePill(
                  score: result.score,
                  accent: isChoice
                      ? const Color(0xFFAB47BC)
                      : const Color(0xFFFFB300),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isChoice
                ? 'Content'
                : 'Content',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 14),
          _buildSentencePreview(currentLine.content),
          const SizedBox(height: 14),
          if (isChoice) _buildChoiceInputs() else _buildTypingInputs(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _blankPrompts.isEmpty ? null : _checkCloze,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const TrText('Kiểm tra'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    final provider = context.read<TextProvider>();
                    setState(() {
                      _resetExerciseForLine(provider, regenerateCloze: true);
                    });
                  },
                  icon: const Icon(Icons.shuffle),
                  label: const TrText('Đổi ô trống'),
                ),
              ),
            ],
          ),
          if (_showAnswer && _blankPrompts.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Answer: ${_blankPrompts.map((e) => '${e.number}. ${e.answer}').join('   •   ')}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
          if (result != null) ...[
            const SizedBox(height: 16),
            _FeedbackCard(
              title: result.feedbackLabel,
              color: result.feedbackColor,
              children: [
                _MetricRow(
                  label: context.tr('Đúng'),
                  value: '${result.correctCount}/${result.totalCount}',
                ),
                _MetricRow(
                  label: context.tr('Chi tiết'),
                  value: result.details(_blankPrompts),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSentencePreview(String line) {
    final tokens = line.split(RegExp(r'\s+'));
    final blankIndexMap = {
      for (final prompt in _blankPrompts) prompt.tokenIndex: prompt,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 10,
        children: [
          for (int i = 0; i < tokens.length; i++)
            if (blankIndexMap.containsKey(i))
              _BlankInlineBadge(
                number: blankIndexMap[i]!.number,
                answer: blankIndexMap[i]!.answer,
                reveal: _showAnswer,
              )
            else
              Text(
                tokens[i],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildTypingInputs() {
    return Column(
      children: List.generate(_blankPrompts.length, (index) {
        final prompt = _blankPrompts[index];
        final result = _clozeResult;
        final isCorrect =
            result != null && result.userAnswers[index] == prompt.answer;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: _blankControllers[index],
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Ô ${prompt.number}',
              hintText: context.tr('Nhập từ cần điền'),
              labelStyle: TextStyle(color: Colors.grey[400]),
              hintStyle: TextStyle(color: Colors.grey[600]),
              suffixIcon: result == null
                  ? null
                  : Icon(
                      isCorrect ? Icons.check_circle : Icons.cancel,
                      color: isCorrect ? Colors.green : Colors.redAccent,
                    ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildChoiceInputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(_blankPrompts.length, (index) {
        final prompt = _blankPrompts[index];
        final options = index < _choiceOptions.length
            ? _choiceOptions[index]
            : const <String>[];
        final result = _clozeResult;

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ô ${prompt.number}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: options.map((option) {
                  final selected = _selectedChoices[index] == option;
                  final isCorrect = result != null && option == prompt.answer;
                  final isWrongPicked =
                      result != null && selected && option != prompt.answer;

                  Color border = Colors.white.withValues(alpha: 0.08);
                  if (isCorrect && result != null) border = Colors.green;
                  if (isWrongPicked) border = Colors.redAccent;

                  return ChoiceChip(
                    selected: selected,
                    label: Text(option),
                    onSelected: (_) {
                      setState(() {
                        _selectedChoices[index] = option;
                        _clozeResult = null;
                      });
                    },
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: Colors.white.withValues(alpha: 0.04),
                    selectedColor: const Color(0xFFAB47BC),
                    side: BorderSide(color: border),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final bool hasText;
  final String? source;
  final int lineCount;

  const _HeroCard({
    required this.hasText,
    required this.source,
    required this.lineCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF26C6DA).withValues(alpha: 0.24),
            const Color(0xFF2196F3).withValues(alpha: 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF26C6DA).withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.edit_square,
                  color: Color(0xFF80DEEA),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Viết · Writing Studio',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Chép, điền từ và kiểm tra khả năng nhớ theo ngữ cảnh.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  hasText ? Icons.description_outlined : Icons.warning_amber,
                  size: 18,
                  color: hasText ? const Color(0xFF4CAF50) : Colors.orange,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasText
                        ? 'Current source: ${source ?? 'current document'} · $lineCount lines.'
                        : 'Please',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTextCard extends StatelessWidget {
  final VoidCallback onOpenWebReader;
  final VoidCallback onOpenPdfReader;

  const _EmptyTextCard({
    required this.onOpenWebReader,
    required this.onOpenPdfReader,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF121827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          const Icon(Icons.menu_book_outlined, size: 42, color: Colors.white54),
          const SizedBox(height: 12),
          const Text(
            'Content',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: onOpenWebReader,
                icon: const Icon(Icons.language),
                label: const TrText('Mở Web Reader'),
              ),
              ElevatedButton.icon(
                onPressed: onOpenPdfReader,
                icon: const Icon(Icons.picture_as_pdf),
                label: const TrText('Mở PDF Reader'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExerciseSelectorChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ExerciseSelectorChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? color : Colors.grey[400],
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.26)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlankInlineBadge extends StatelessWidget {
  final int number;
  final String answer;
  final bool reveal;

  const _BlankInlineBadge({
    required this.number,
    required this.answer,
    required this.reveal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: reveal
            ? const Color(0xFF4CAF50).withValues(alpha: 0.16)
            : const Color(0xFFFFB300).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: reveal
              ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
              : const Color(0xFFFFB300).withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        reveal ? answer : '[$number]',
        style: TextStyle(
          color: reveal ? const Color(0xFF81C784) : const Color(0xFFFFB300),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  final double score;
  final Color accent;

  const _ScorePill({required this.score, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${(score * 100).round()}%',
        style: TextStyle(
          color: accent,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final String title;
  final Color color;
  final List<Widget> children;

  const _FeedbackCard({
    required this.title,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetricRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final String title;
  final List<String> bullets;

  const _TipCard({required this.title, required this.bullets});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          ...bullets.map(
            (bullet) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(
                      Icons.check_circle_outline,
                      size: 14,
                      color: Color(0xFF26C6DA),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      bullet,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlankPrompt {
  final int number;
  final int tokenIndex;
  final String answer;
  final String originalToken;

  const _BlankPrompt({
    required this.number,
    required this.tokenIndex,
    required this.answer,
    required this.originalToken,
  });
}

class _RankedCandidate {
  final int index;
  final double score;

  const _RankedCandidate({required this.index, required this.score});
}

class _DictationResult {
  final double score;
  final double orderScore;
  final double spellingScore;
  final List<String> missingWords;
  final List<String> extraWords;

  const _DictationResult({
    required this.score,
    required this.orderScore,
    required this.spellingScore,
    required this.missingWords,
    required this.extraWords,
  });

  String get feedbackLabel {
    if (score >= 0.9) return 'Content';
    if (score >= 0.75) return 'Content';
    if (score >= 0.55) return 'Add';
    return 'Add';
  }

  Color get feedbackColor {
    if (score >= 0.9) return const Color(0xFF4CAF50);
    if (score >= 0.75) return const Color(0xFF81C784);
    if (score >= 0.55) return const Color(0xFFFFB300);
    return const Color(0xFFFF7043);
  }
}

class _LocalCoachInsight {
  final String summary;
  final String strength;
  final String primaryIssue;
  final String nextStep;
  final List<String> tags;
  final Color color;

  const _LocalCoachInsight({
    required this.summary,
    required this.strength,
    required this.primaryIssue,
    required this.nextStep,
    required this.tags,
    required this.color,
  });

  factory _LocalCoachInsight.fromResult(_DictationResult result) {
    final tags = <String>[];

    String strength;
    if (result.score >= 0.9) {
      strength = 'Content';
      tags.add('Content');
    } else if (result.orderScore >= 0.75) {
      strength = 'Content';
      tags.add('Content');
    } else if (result.spellingScore >= 0.75) {
      strength =
          'Content';
      tags.add('Content');
    } else {
      strength =
          'Content';
      tags.add('Content');
    }

    String issue;
    String nextStep;

    if (result.missingWords.isNotEmpty && result.orderScore < 0.65) {
      issue =
          'Content';
      nextStep =
          'Content';
      tags.add('Content');
      tags.add('Content');
    } else if (result.missingWords.isNotEmpty) {
      issue =
          'Content', ')}.';
      nextStep =
          'Add';
      tags.add('Content');
    } else if (result.extraWords.isNotEmpty) {
      issue =
          'Add';
      nextStep =
          'Add';
      tags.add('Add');
    } else if (result.spellingScore < 0.7) {
      issue = 'Content';
      nextStep =
          'Content';
      tags.add('Content');
    } else {
      issue =
          'Content';
      nextStep =
          'Content';
      tags.add('Content');
    }

    if (result.score >= 0.9) {
      tags.add('Content');
    } else if (result.score >= 0.7) {
      tags.add('Add');
    } else {
      tags.add('Content');
    }

    return _LocalCoachInsight(
      summary: result.feedbackLabel,
      strength: strength,
      primaryIssue: issue,
      nextStep: nextStep,
      tags: tags,
      color: result.feedbackColor,
    );
  }
}

class _RewriteResult {
  final double overallScore;
  final double completenessScore;
  final double grammarScore;
  final double paraphraseScore;
  final double similarityToOriginal;
  final List<String> usedKeywords;
  final List<String> missingKeywords;

  const _RewriteResult({
    required this.overallScore,
    required this.completenessScore,
    required this.grammarScore,
    required this.paraphraseScore,
    required this.similarityToOriginal,
    required this.usedKeywords,
    required this.missingKeywords,
  });

  String get feedbackLabel {
    if (overallScore >= 0.85)
      return 'Content';
    if (overallScore >= 0.68)
      return 'Content';
    if (overallScore >= 0.48)
      return 'Content';
    return 'Content';
  }

  Color get feedbackColor {
    if (overallScore >= 0.85) return const Color(0xFF4CAF50);
    if (overallScore >= 0.68) return const Color(0xFF81C784);
    if (overallScore >= 0.48) return const Color(0xFFFFB300);
    return const Color(0xFFFF7043);
  }

  String get summary {
    if (completenessScore < 0.45) {
      return 'Content';
    }
    if (paraphraseScore < 0.4) {
      return 'Content';
    }
    if (grammarScore < 0.45) {
      return 'Content';
    }
    return 'Content';
  }

  String get strength {
    if (paraphraseScore >= 0.7 && completenessScore >= 0.65) {
      return 'Content';
    }
    if (completenessScore >= 0.75) {
      return 'Content';
    }
    if (grammarScore >= 0.7) {
      return 'Content';
    }
    return 'Content';
  }

  String get primaryIssue {
    if (completenessScore < 0.45) {
      return 'Content';
    }
    if (paraphraseScore < 0.4) {
      return 'Content';
    }
    if (grammarScore < 0.45) {
      return 'Content';
    }
    return 'Content';
  }

  String get nextStep {
    if (completenessScore < 0.45) {
      return 'Content';
    }
    if (paraphraseScore < 0.4) {
      return 'Content';
    }
    if (grammarScore < 0.45) {
      return 'Content';
    }
    return 'Content';
  }

  List<String> get tags {
    final tags = <String>[];
    if (completenessScore >= 0.7) tags.add('Content');
    if (completenessScore < 0.45) tags.add('Content');
    if (paraphraseScore >= 0.7) tags.add('Content');
    if (paraphraseScore < 0.4) tags.add('Content');
    if (grammarScore >= 0.7) tags.add('Content');
    if (grammarScore < 0.45) tags.add('Content');
    if (similarityToOriginal > 0.9) tags.add('Content');
    return tags;
  }
}

class _SummaryResult {
  final double overallScore;
  final double contentRetentionScore;
  final double brevityScore;
  final double grammarScore;
  final double compressionRatio;
  final List<String> keptKeywords;
  final List<String> missedKeywords;

  const _SummaryResult({
    required this.overallScore,
    required this.contentRetentionScore,
    required this.brevityScore,
    required this.grammarScore,
    required this.compressionRatio,
    required this.keptKeywords,
    required this.missedKeywords,
  });

  String get feedbackLabel {
    if (overallScore >= 0.85) return 'Content';
    if (overallScore >= 0.68)
      return 'Content';
    if (overallScore >= 0.48)
      return 'Content';
    return 'Content';
  }

  Color get feedbackColor {
    if (overallScore >= 0.85) return const Color(0xFF4CAF50);
    if (overallScore >= 0.68) return const Color(0xFF81C784);
    if (overallScore >= 0.48) return const Color(0xFFFFB300);
    return const Color(0xFFFF7043);
  }

  String get compressionLabel {
    return '${(compressionRatio * 100).round()}% độ dài câu gốc';
  }

  String get summary {
    if (contentRetentionScore < 0.45) {
      return 'Content';
    }
    if (brevityScore < 0.45) {
      return 'Content';
    }
    if (grammarScore < 0.45) {
      return 'Content';
    }
    return 'Content';
  }

  String get nextStep {
    if (contentRetentionScore < 0.45) {
      return 'Content';
    }
    if (brevityScore < 0.45) {
      return 'Content';
    }
    if (grammarScore < 0.45) {
      return 'Content';
    }
    return 'Content';
  }
}

class _ClozeResult {
  final int correctCount;
  final int totalCount;
  final List<String> userAnswers;

  const _ClozeResult({
    required this.correctCount,
    required this.totalCount,
    required this.userAnswers,
  });

  double get score => totalCount == 0 ? 0.0 : correctCount / totalCount;

  String get feedbackLabel {
    if (score >= 1.0) return 'Content';
    if (score >= 0.67) return 'Content';
    if (score > 0.0) return 'Retry';
    return 'Content';
  }

  Color get feedbackColor {
    if (score >= 1.0) return const Color(0xFF4CAF50);
    if (score >= 0.67) return const Color(0xFF81C784);
    if (score > 0.0) return const Color(0xFFFFB300);
    return const Color(0xFFFF7043);
  }

  String details(List<_BlankPrompt> prompts) {
    final chunks = <String>[];
    for (int i = 0; i < prompts.length; i++) {
      final expected = prompts[i].answer;
      final actual = i < userAnswers.length ? userAnswers[i] : '';
      chunks.add(
          '${prompts[i].number}) ${actual.isEmpty ? '∅' : actual} → $expected');
    }
    return chunks.join('   •   ');
  }
}