// ignore_for_file: curly_braces_in_flow_control_structures, unnecessary_non_null_assertion, unnecessary_null_comparison
import 'dart:async';
import 'dart:math' as math;

import 'package:in4up/core/language/localized_material.dart';
import 'package:provider/provider.dart';
import 'package:in4up_ai/in4up_ai.dart';
import '../../core/responsive/app_responsive.dart';
import '../../features/writing/models/writing_assignment.dart';
import '../../features/writing/models/writing_source_request.dart';
import '../../features/writing/services/document_summary_signal_service.dart';
import '../../features/writing/services/writing_draft_store.dart';
import '../../models/text_item.dart';
import '../../providers/text_provider.dart';

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
  final WritingDraftStore _draftStore = WritingDraftStore();
  final TextEditingController _dictationController = TextEditingController();
  final TextEditingController _rewriteController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();
  Timer? _draftSaveTimer;

  _WriteExerciseType _exerciseType = _WriteExerciseType.dictation;
  WritingAssignment? _assignment;
  String _assignmentSourceKey = '';
  String _sourceKey = '';
  String _lastAiPromptKey = '';
  int _handledWritingSourceVersion = -1;
  int _lineIndex = 0;
  bool _showAnswer = false;

  _DictationResult? _dictationResult;
  _ClozeResult? _clozeResult;
  _RewriteResult? _rewriteResult;
  _SummaryResult? _summaryResult;
  DocumentSummarySignals? _documentSummarySignals;

  List<TextEditingController> _blankControllers = [];
  List<_BlankPrompt> _blankPrompts = [];
  List<List<String>> _choiceOptions = [];
  List<String?> _selectedChoices = [];

  @override
  void dispose() {
    _saveCurrentWorkspaceDraft();
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

  WritingTaskType get _activeTask => switch (_exerciseType) {
        _WriteExerciseType.dictation => WritingTaskType.dictation,
        _WriteExerciseType.clozeInput => WritingTaskType.cloze,
        _WriteExerciseType.clozeChoice => WritingTaskType.cloze,
        _WriteExerciseType.rewrite => WritingTaskType.rewrite,
        _WriteExerciseType.summary => WritingTaskType.summary,
      };

  void _ensureExerciseState(TextProvider textProvider) {
    final writingRequest = textProvider.writingSourceRequest;
    final receivedNewRequest = writingRequest != null &&
        _handledWritingSourceVersion != textProvider.writingSourceVersion;
    if (receivedNewRequest) {
      _exerciseType = switch (writingRequest.task) {
        WritingTaskType.dictation => _WriteExerciseType.dictation,
        WritingTaskType.cloze => _WriteExerciseType.clozeInput,
        WritingTaskType.rewrite => _WriteExerciseType.rewrite,
        WritingTaskType.summary => _WriteExerciseType.summary,
      };
      _handledWritingSourceVersion = textProvider.writingSourceVersion;
    }

    final newKey = [
      textProvider.currentContextSourceRef ?? '',
      textProvider.currentDocument?.title ?? '',
      textProvider.lines.length,
      writingRequest?.kind.name ?? 'no-handoff',
      writingRequest?.isExcerpt.toString() ?? 'false',
      writingRequest?.sourceLabel ?? '',
      textProvider.fullText,
    ].join('\u0000');

    if (_sourceKey == newKey &&
        textProvider.lines.isNotEmpty &&
        !receivedNewRequest) {
      if (_lineIndex >= textProvider.lines.length) {
        _lineIndex = textProvider.lines.length - 1;
        _resetExerciseForLine(textProvider, regenerateCloze: true);
      } else if (_assignment == null) {
        _assignment = _createAssignment(textProvider);
        _assignmentSourceKey = _sourceKey;
      }
      return;
    }

    _saveCurrentWorkspaceDraft();
    _sourceKey = newKey;
    _lineIndex = textProvider.currentLineIndex >= 0 &&
            textProvider.currentLineIndex < textProvider.lines.length
        ? textProvider.currentLineIndex
        : 0;
    _resetExerciseForLine(
      textProvider,
      regenerateCloze: true,
      saveCurrentDraft: false,
    );
  }

  WritingAssignment _createAssignment(TextProvider textProvider) {
    return WritingAssignment.fromContext(
      context: WritingAssignmentContext(
        sourceKey: _sourceKey,
        sourceTitle:
            textProvider.currentDocument?.title ?? 'Văn bản hiện tại',
        fullText: textProvider.fullText,
        lines: textProvider.lines.map((line) => line.content).toList(),
        lineIndex: _lineIndex,
        request: textProvider.writingSourceRequest,
      ),
      task: _activeTask,
    );
  }

  WritingDraftKey? _currentDraftKey() {
    final assignment = _assignment;
    if (assignment == null || !assignment.isWorkspaceTask) return null;
    return _draftStore.keyFor(
      sourceKey: _assignmentSourceKey,
      assignment: assignment,
    );
  }

  void _saveCurrentWorkspaceDraft() {
    _draftSaveTimer?.cancel();
    final assignment = _assignment;
    final key = _currentDraftKey();
    if (assignment == null || key == null) return;
    final text = switch (assignment.task) {
      WritingTaskType.rewrite => _rewriteController.text,
      WritingTaskType.summary => _summaryController.text,
      _ => '',
    };
    _draftStore.save(key, text);
  }

  void _saveWorkspaceDraftForInput(String text) {
    final key = _currentDraftKey();
    if (key == null) return;
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(
      const Duration(milliseconds: 350),
      () => _draftStore.save(key, text),
    );
  }

  void _restoreWorkspaceDraft() {
    final assignment = _assignment;
    final key = _currentDraftKey();
    if (assignment == null || key == null) return;
    final draft = _draftStore.read(key);
    if (assignment.task == WritingTaskType.rewrite) {
      _rewriteController.text = draft;
    } else if (assignment.task == WritingTaskType.summary) {
      _summaryController.text = draft;
    }
  }

  void _clearCurrentWorkspaceDraft() {
    _draftSaveTimer?.cancel();
    final key = _currentDraftKey();
    if (key != null) _draftStore.clear(key);
  }

  void _resetExerciseForLine(
    TextProvider textProvider, {
    required bool regenerateCloze,
    bool saveCurrentDraft = true,
  }) {
    if (saveCurrentDraft) _saveCurrentWorkspaceDraft();
    _dictationController.clear();
    _rewriteController.clear();
    _summaryController.clear();
    _dictationResult = null;
    _clozeResult = null;
    _rewriteResult = null;
    _summaryResult = null;
    _documentSummarySignals = null;
    _showAnswer = false;
    _lastAiPromptKey = '';
    _selectedChoices = [];
    _disposeBlankControllers();

    _assignment = _createAssignment(textProvider);
    _assignmentSourceKey = _sourceKey;
    _restoreWorkspaceDraft();

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
    _saveCurrentWorkspaceDraft();
    setState(() {
      _exerciseType = type;
      _resetExerciseForLine(
        textProvider,
        regenerateCloze: true,
        saveCurrentDraft: false,
      );
    });
  }

  void _generateCloze(TextProvider textProvider) {
    final assignment = _assignment;
    if (textProvider.lines.isEmpty ||
        assignment == null ||
        assignment.sourceText.trim().isEmpty) {
      _blankPrompts = [];
      _choiceOptions = [];
      return;
    }

    final line = assignment.sourceText;
    final tokens = line.split(RegExp(r'\s+'));
    final assignmentLineIndex = assignment.lineIndex;
    final analyzedWords = assignment.origin == AssignmentOrigin.perLine &&
            assignmentLineIndex != null &&
            assignmentLineIndex < textProvider.analyzedLines.length
        ? textProvider.analyzedLines[assignmentLineIndex]
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
    final assignment = _assignment;
    if (assignment == null || assignment.sourceText.trim().isEmpty) return;
    await textProvider.speak(assignment.sourceText);
  }

  void _scoreDictation() {
    final assignment = _assignment;
    if (assignment == null || assignment.sourceText.trim().isEmpty) return;

    final expected = assignment.sourceText;
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

  Set<String> _extractRewriteKeywords(
    TextProvider textProvider,
    WritingAssignment assignment,
  ) {
    final assignmentLineIndex = assignment.lineIndex;
    final analyzedWords = assignment.origin == AssignmentOrigin.perLine &&
            assignmentLineIndex != null &&
            assignmentLineIndex < textProvider.analyzedLines.length
        ? textProvider.analyzedLines[assignmentLineIndex]
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

    return _tokenizeNormalized(assignment.sourceText)
        .where((word) => word.length >= 4)
        .take(6)
        .toSet();
  }

  List<String> _extractExpectedVerbs(
    TextProvider textProvider,
    WritingAssignment assignment,
  ) {
    final assignmentLineIndex = assignment.lineIndex;
    final analyzedWords = assignment.origin == AssignmentOrigin.perLine &&
            assignmentLineIndex != null &&
            assignmentLineIndex < textProvider.analyzedLines.length
        ? textProvider.analyzedLines[assignmentLineIndex]
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
    final assignment = _assignment;
    if (assignment == null || assignment.sourceText.trim().isEmpty) return;

    final expected = assignment.sourceText;
    final actual = _rewriteController.text.trim();
    final actualTokens = _tokenizeNormalized(actual);
    if (actualTokens.isEmpty) return;

    final keywords = _extractRewriteKeywords(textProvider, assignment);
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
      _extractExpectedVerbs(textProvider, assignment),
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
    final assignment = _assignment;
    if (assignment == null || assignment.sourceText.trim().isEmpty) return;

    final expected = assignment.sourceText;
    final actual = _summaryController.text.trim();
    if (actual.isEmpty) return;

    if (assignment.scoringProfile == ScoringProfile.documentSignals) {
      setState(() {
        _summaryResult = null;
        _documentSummarySignals = DocumentSummarySignalService.analyze(
          sourceText: expected,
          draftText: actual,
        );
        _showAnswer = true;
      });
      return;
    }

    final actualTokens = _tokenizeNormalized(actual);
    if (actualTokens.isEmpty) return;
    final expectedTokens = _tokenizeNormalized(expected);
    final keywords = _extractRewriteKeywords(textProvider, assignment);
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
      _extractExpectedVerbs(textProvider, assignment),
    );

    final overall = ((contentRetention * 0.5) +
            (brevityScore * 0.25) +
            (grammarScore * 0.25))
        .clamp(0.0, 1.0)
        .toDouble();

    setState(() {
      _documentSummarySignals = null;
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

Bạn là bộ phản hồi viết offline của in4up.
Hãy trả về JSON hợp lệ với:
- summary: nhận xét ngắn bằng tiếng Việt
- topics: 2-4 nhãn ngắn
- action_items: 2-4 gợi ý luyện tiếp cụ thể
- grammar: nếu có thể, mô tả ngắn subject/verb/object/pattern/explanation_vi
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

Bạn là bộ phản hồi viết lại ý offline của in4up.
Hãy trả về JSON hợp lệ với:
- summary: nhận xét ngắn bằng tiếng Việt
- topics: 2-4 nhãn ngắn
- action_items: 2-4 gợi ý luyện tiếp cụ thể
- grammar: mô tả nhanh hình dáng câu và phần cần sửa
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

Bạn là bộ phản hồi tóm tắt offline của in4up.
Hãy trả về JSON hợp lệ với:
- summary: nhận xét ngắn bằng tiếng Việt
- topics: 2-4 nhãn ngắn
- action_items: 2-4 gợi ý luyện tiếp cụ thể
- grammar: mô tả nhanh độ gọn, độ rõ và hình dáng câu
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
        title: const Text('Cài đặt AI local'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Để dùng phản hồi AI cục bộ, hãy import model .gguf vào thiết bị.'),
            SizedBox(height: 8),
            Text('Khuyến nghị: gemma-2b-it-q4_k_m.gguf (~1.5GB)'),
            SizedBox(height: 8),
            Text(
                'Khi chưa có model, phần Chấm nhanh vẫn hoạt động hoàn toàn offline.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Để sau'),
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
                        ? '✅ AI local đã sẵn sàng'
                        : '❌ Import model thất bại',
                  ),
                ),
              );
              setState(() {});
            },
            child: const Text('Chọn file .gguf'),
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
          final writingRequest = textProvider.writingSourceRequest;
          final assignment = hasText ? _assignment : null;
          final currentLine = assignment == null
              ? null
              : TextItem(id: assignment.id, content: assignment.sourceText);
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
                  if (hasText && writingRequest != null) ...[
                    const SizedBox(height: 12),
                    _WritingSourceHandoffCard(request: writingRequest),
                  ],
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
                        label: 'Công cụ nhanh',
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
                    // hasText=true ⇒ _assignment đã auto-create
                    // (_ensureExerciseState) ⇒ an toàn dùng !
                    _buildContextCard(
                      assignment: assignment!,
                      totalLines: textProvider.lines.length,
                      activeLineIndex: activeLineIndex,
                      onJumpToActive:
                          assignment!.showLineNavigator && activeLineIndex >= 0
                              ? () => _jumpToCurrentLine(textProvider)
                              : null,
                    ),
                    const SizedBox(height: 16),
                    _buildExerciseSelector(textProvider),
                    if (assignment!.showLineNavigator) ...[
                      const SizedBox(height: 16),
                      _buildLineNavigator(textProvider),
                    ],
                    if (assignment!.needsContextPreview) ...[
                      const SizedBox(height: 16),
                      _buildReferenceContextCard(assignment!),
                    ],
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
                      title: 'Vai trò của tab Viết',
                      bullets: [
                        'Viết là nhánh output gắn trực tiếp với nguồn text hoặc lyric hiện tại.',
                        'Mặc định ưu tiên discoverability: người mới nhìn vào là biết có chép, điền từ, chọn đáp án, viết lại ý và tóm tắt ngắn.',
                        'Tab này đang đi theo 2 lớp: phản hồi local luôn chạy, AI local là lớp tăng cường khi model sẵn sàng.',
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
    required WritingAssignment assignment,
    required int totalLines,
    required int activeLineIndex,
    VoidCallback? onJumpToActive,
  }) {
    final scopeLabel = switch (assignment.origin) {
      AssignmentOrigin.perLine => 'Dòng ${_lineIndex + 1}/$totalLines',
      AssignmentOrigin.excerpt => 'Đoạn trích',
      AssignmentOrigin.fullDocument =>
        'Toàn bài · ${assignment.sourceWordCount} từ',
    };

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
                  context.uiText(assignment.sourceTitle),
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
                  context.uiText(scopeLabel),
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
            assignment.sourceText,
            maxLines:
                assignment.origin == AssignmentOrigin.fullDocument ? 10 : null,
            overflow: assignment.origin == AssignmentOrigin.fullDocument
                ? TextOverflow.ellipsis
                : null,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          if (assignment.scoringProfile == ScoringProfile.documentSignals) ...[
            const SizedBox(height: 10),
            const Text(
              'Bài dài: phản hồi offline chỉ hiển thị tín hiệu quan sát, không gán điểm hiểu nghĩa.',
              style: TextStyle(color: Color(0xFFFFD180), fontSize: 11),
            ),
          ],
          if (onJumpToActive != null && activeLineIndex != _lineIndex) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onJumpToActive,
              icon: const Icon(Icons.sync_alt, size: 18),
              label: Text(
                  context.uiText('Dùng dòng đang focus trong tab Đọc (#${activeLineIndex + 1})')),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReferenceContextCard(WritingAssignment assignment) {
    final taskInstruction = switch (assignment.task) {
      WritingTaskType.dictation => 'chép lại câu đầu tiên',
      WritingTaskType.cloze => 'làm bài cloze trên câu đầu tiên',
      WritingTaskType.rewrite => 'viết lại câu đầu tiên',
      WritingTaskType.summary => 'tóm tắt câu đầu tiên',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF26C6DA).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF26C6DA).withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.library_books_outlined,
                  color: Color(0xFF80DEEA), size: 19),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ngữ cảnh tham khảo',
                  style: TextStyle(
                    color: Color(0xFF80DEEA),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.uiText(
              'Đoạn chọn có nhiều câu. Bài hiện tại chỉ yêu cầu $taskInstruction để công thức chấm câu đơn không cho kết quả sai.',
            ),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            assignment.contextText,
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseSelector(TextProvider textProvider) {
    final items = [
      (
        label: 'Chép',
        type: _WriteExerciseType.dictation,
        color: const Color(0xFF26C6DA),
      ),
      (
        label: 'Điền từ',
        type: _WriteExerciseType.clozeInput,
        color: const Color(0xFFFFB300),
      ),
      (
        label: 'Chọn đáp án',
        type: _WriteExerciseType.clozeChoice,
        color: const Color(0xFFAB47BC),
      ),
      (
        label: 'Viết lại ý',
        type: _WriteExerciseType.rewrite,
        color: const Color(0xFF4CAF50),
      ),
      (
        label: 'Tóm tắt ngắn',
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
                  label: const Text('Trước'),
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
                  label: const Text('Ngẫu nhiên'),
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
                label: const Text('Đọc câu'),
              ),
              const SizedBox(width: 10),
              TextButton.icon(
                onPressed: () => setState(() => _showAnswer = !_showAnswer),
                icon:
                    Icon(_showAnswer ? Icons.visibility_off : Icons.visibility),
                label: Text(_showAnswer ? 'Ẩn đáp án' : 'Hiện đáp án'),
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
              hintText: context.uiText('Nhập lại câu bạn nghe hoặc nhớ được...'),
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
                  onPressed: _scoreDictation,
                  icon: const Icon(Icons.grading_rounded),
                  label: const Text('Chấm nhanh'),
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
                  label: const Text('Làm lại'),
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
                    label: 'Thứ tự câu',
                    value: '${(result.orderScore * 100).round()}%'),
                _MetricRow(
                    label: 'Độ sát chính tả',
                    value: '${(result.spellingScore * 100).round()}%'),
                _MetricRow(
                    label: 'Từ thiếu',
                    value: result.missingWords.isEmpty
                        ? 'Không có'
                        : result.missingWords.join(', ')),
                _MetricRow(
                    label: 'Từ dư',
                    value: result.extraWords.isEmpty
                        ? 'Không có'
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
                  facade.hasModel ? 'AI local sẵn sàng' : 'Chỉ tầng cục bộ',
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
            title: 'Tầng 1 · Huấn luyện cục bộ',
            color: coach.color,
            children: [
              _MetricRow(
                label: 'Kết luận',
                value: coach.summary,
                localizeValue: true,
              ),
              _MetricRow(
                label: 'Thế mạnh',
                value: coach.strength,
                localizeValue: true,
              ),
              _MetricRow(
                label: 'Điểm cần sửa',
                value: coach.primaryIssue,
                localizeValue: true,
              ),
              _MetricRow(
                label: 'Lượt tiếp theo',
                value: coach.nextStep,
                localizeValue: true,
              ),
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
                  label: const Text('Tầng 2 · AI local'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showAiModelSetupDialog(facade),
                  icon: const Icon(Icons.download_outlined),
                  label: Text(facade.hasModel ? 'Đổi model' : 'Cài AI local'),
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
                  label: 'Tóm tắt',
                  value: analysis.summary.isNotEmpty
                      ? analysis.summary
                      : 'AI chưa trả về phần tóm tắt rõ ràng.',
                ),
                _MetricRow(
                  label: 'Chủ điểm',
                  value: analysis.topics.isEmpty
                      ? 'Chưa có'
                      : analysis.topics.join(', '),
                ),
                _MetricRow(
                  label: 'Hành động',
                  value: analysis.actionItems.isEmpty
                      ? 'Chưa có gợi ý hành động cụ thể từ AI.'
                      : analysis.actionItems.join(' • '),
                ),
                if (analysis.grammar != null) ...[
                  _MetricRow(
                      label: 'Chủ ngữ', value: analysis.grammar!.subject),
                  _MetricRow(label: 'Động từ', value: analysis.grammar!.verb),
                  _MetricRow(
                      label: 'Mẫu câu', value: analysis.grammar!.pattern),
                ],
              ],
            ),
          ],
          if (facade.lastError != null &&
              !isLoadingCurrent &&
              analysis == null) ...[
            const SizedBox(height: 12),
            Text(
              context.uiText('Lỗi AI: ${facade.lastError}'),
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
            onChanged: (value) {
              _saveWorkspaceDraftForInput(value);
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
              hintText: context.uiText('Viết lại cùng ý, không cần chép y nguyên câu gốc...'),
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
                  label: const Text('Phân tích bài viết'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _clearCurrentWorkspaceDraft();
                    setState(() {
                      _rewriteController.clear();
                      _rewriteResult = null;
                      _lastAiPromptKey = '';
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Làm lại'),
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
                    label: 'Giữ ý',
                    value: '${(result.completenessScore * 100).round()}%'),
                _MetricRow(
                    label: 'Hình dáng câu',
                    value: '${(result.grammarScore * 100).round()}%'),
                _MetricRow(
                    label: 'Độ viết lại',
                    value: '${(result.paraphraseScore * 100).round()}%'),
                _MetricRow(
                    label: 'Từ khóa đã giữ',
                    value: result.usedKeywords.isEmpty
                        ? 'Chưa rõ'
                        : result.usedKeywords.join(', ')),
                _MetricRow(
                    label: 'Từ khóa còn thiếu',
                    value: result.missingKeywords.isEmpty
                        ? 'Không có'
                        : result.missingKeywords.join(', ')),
                _MetricRow(
                  label: 'Nhận xét',
                  value: result.summary,
                  localizeValue: true,
                ),
                _MetricRow(
                  label: 'Điểm mạnh',
                  value: result.strength,
                  localizeValue: true,
                ),
                _MetricRow(
                  label: 'Điểm cần sửa',
                  value: result.primaryIssue,
                  localizeValue: true,
                ),
                _MetricRow(
                  label: 'Bước tiếp theo',
                  value: result.nextStep,
                  localizeValue: true,
                ),
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
                  facade.hasModel ? 'AI local sẵn sàng' : 'Chưa có model',
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
                  label: const Text('Phân tích rewrite'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showAiModelSetupDialog(facade),
                  icon: const Icon(Icons.download_outlined),
                  label: Text(facade.hasModel ? 'Đổi model' : 'Cài AI local'),
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
                  label: 'Tóm tắt',
                  value: analysis.summary.isNotEmpty
                      ? analysis.summary
                      : 'AI chưa trả về nhận xét đủ rõ.',
                ),
                _MetricRow(
                  label: 'Chủ điểm',
                  value: analysis.topics.isEmpty
                      ? 'Chưa có'
                      : analysis.topics.join(', '),
                ),
                _MetricRow(
                  label: 'Gợi ý',
                  value: analysis.actionItems.isEmpty
                      ? 'Chưa có gợi ý cụ thể từ AI.'
                      : analysis.actionItems.join(' • '),
                ),
                if (analysis.grammar != null) ...[
                  _MetricRow(
                      label: 'Chủ ngữ', value: analysis.grammar!.subject),
                  _MetricRow(label: 'Động từ', value: analysis.grammar!.verb),
                  _MetricRow(
                      label: 'Mẫu câu', value: analysis.grammar!.pattern),
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
    final signals = _documentSummarySignals;
    final assignment = _assignment!;
    final usesDocumentSignals =
        assignment.scoringProfile == ScoringProfile.documentSignals;

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
              Expanded(
                child: Text(
                  usesDocumentSignals
                      ? 'Tóm tắt nội dung dài'
                      : 'Tóm tắt ý bằng câu ngắn',
                  style: const TextStyle(
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
          Text(
            usesDocumentSignals
                ? 'Viết bản tóm tắt cho toàn bộ nguồn. Phản hồi offline chỉ mô tả độ dài, mức trùng cụm và sự hiện diện từ khóa — không tự nhận là điểm hiểu nghĩa.'
                : 'Hãy rút gọn nội dung câu gốc thành một câu ngắn hơn nhưng vẫn giữ ý chính.',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
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
              maxLines: usesDocumentSignals ? 8 : null,
              overflow: usesDocumentSignals ? TextOverflow.ellipsis : null,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13, height: 1.4),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _summaryController,
            onChanged: (value) {
              _saveWorkspaceDraftForInput(value);
              if (_summaryResult != null ||
                  _documentSummarySignals != null ||
                  _lastAiPromptKey.isNotEmpty) {
                setState(() {
                  _summaryResult = null;
                  _documentSummarySignals = null;
                  _lastAiPromptKey = '';
                });
              }
            },
            minLines: usesDocumentSignals ? 7 : 3,
            maxLines: usesDocumentSignals ? 14 : 5,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: context.uiText(
                usesDocumentSignals
                    ? 'Viết bản tóm tắt toàn bài theo cách hiểu của bạn...'
                    : 'Viết một phiên bản ngắn hơn, rõ hơn, giữ đúng ý chính...',
              ),
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
                  label: Text(
                    usesDocumentSignals ? 'Xem tín hiệu offline' : 'Chấm tóm tắt',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _clearCurrentWorkspaceDraft();
                    setState(() {
                      _summaryController.clear();
                      _summaryResult = null;
                      _documentSummarySignals = null;
                      _lastAiPromptKey = '';
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Làm lại'),
                ),
              ),
            ],
          ),
          if (signals != null) ...[
            const SizedBox(height: 16),
            _FeedbackCard(
              title: 'Tín hiệu quan sát · không phải điểm semantic',
              color: const Color(0xFFFFB74D),
              children: [
                _MetricRow(
                  label: 'Độ dài',
                  value:
                      '${signals.draftWordCount}/${signals.sourceWordCount} từ · ${signals.compressionLabel}',
                ),
                _MetricRow(
                  label: 'Cụm trùng',
                  value: signals.copiedPhraseLabel,
                ),
                _MetricRow(
                  label: 'Từ khóa',
                  value: signals.keywordPresenceLabel,
                ),
                _MetricRow(
                  label: 'Đã xuất hiện',
                  value: signals.presentKeywords.isEmpty
                      ? 'Chưa quan sát thấy'
                      : signals.presentKeywords.join(', '),
                ),
                _MetricRow(
                  label: 'Chưa xuất hiện',
                  value: signals.absentKeywords.isEmpty
                      ? 'Không có trong danh sách quan sát'
                      : signals.absentKeywords.join(', '),
                ),
                const _MetricRow(
                  label: 'Giới hạn',
                  value:
                      'Các tín hiệu trên không kết luận bản tóm tắt đúng nghĩa, đủ ý hay viết hay. Cần người học hoặc AI semantic kiểm tra riêng.',
                ),
              ],
            ),
          ],
          if (result != null) ...[
            const SizedBox(height: 16),
            _FeedbackCard(
              title: result.feedbackLabel,
              color: result.feedbackColor,
              children: [
                _MetricRow(
                    label: 'Giữ ý',
                    value: '${(result.contentRetentionScore * 100).round()}%'),
                _MetricRow(
                    label: 'Độ cô đọng',
                    value: '${(result.brevityScore * 100).round()}%'),
                _MetricRow(
                    label: 'Hình dáng câu',
                    value: '${(result.grammarScore * 100).round()}%'),
                _MetricRow(
                  label: 'Tỉ lệ độ dài',
                  value: context.uiText(result.compressionLabel),
                ),
                _MetricRow(
                    label: 'Từ khóa đã giữ',
                    value: result.keptKeywords.isEmpty
                        ? 'Chưa rõ'
                        : result.keptKeywords.join(', ')),
                _MetricRow(
                    label: 'Từ khóa còn thiếu',
                    value: result.missedKeywords.isEmpty
                        ? 'Không có'
                        : result.missedKeywords.join(', ')),
                _MetricRow(
                  label: 'Nhận xét',
                  value: result.summary,
                  localizeValue: true,
                ),
                _MetricRow(
                  label: 'Bước tiếp theo',
                  value: result.nextStep,
                  localizeValue: true,
                ),
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
                  facade.hasModel ? 'AI local sẵn sàng' : 'Chưa có model',
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
                  label: const Text('Phân tích tóm tắt'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showAiModelSetupDialog(facade),
                  icon: const Icon(Icons.download_outlined),
                  label: Text(facade.hasModel ? 'Đổi model' : 'Cài AI local'),
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
                  label: 'Tóm tắt',
                  value: analysis.summary.isNotEmpty
                      ? analysis.summary
                      : 'AI chưa trả về nhận xét đủ rõ.',
                ),
                _MetricRow(
                  label: 'Chủ điểm',
                  value: analysis.topics.isEmpty
                      ? 'Chưa có'
                      : analysis.topics.join(', '),
                ),
                _MetricRow(
                  label: 'Gợi ý',
                  value: analysis.actionItems.isEmpty
                      ? 'Chưa có gợi ý cụ thể từ AI.'
                      : analysis.actionItems.join(' • '),
                ),
                if (analysis.grammar != null) ...[
                  _MetricRow(
                      label: 'Chủ ngữ', value: analysis.grammar!.subject),
                  _MetricRow(label: 'Động từ', value: analysis.grammar!.verb),
                  _MetricRow(
                      label: 'Mẫu câu', value: analysis.grammar!.pattern),
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
                  isChoice ? 'Cloze · Chọn đáp án' : 'Cloze · Điền từ',
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
                ? 'Chọn từ đúng cho từng ô trống để kiểm tra khả năng nhớ theo ngữ cảnh.'
                : 'Điền lại các từ khóa đã được ẩn khỏi câu hiện tại.',
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
                  label: const Text('Kiểm tra'),
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
                  label: const Text('Đổi ô trống'),
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
                context.uiText('Đáp án: ${_blankPrompts.map((e) => '${e.number}. ${e.answer}').join('   •   ')}'),
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
                  label: 'Đúng',
                  value: '${result.correctCount}/${result.totalCount}',
                ),
                _MetricRow(
                  label: 'Chi tiết',
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
              labelText: context.uiText('Ô ${prompt.number}'),
              hintText: context.uiText('Nhập từ cần điền'),
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
                context.uiText('Ô ${prompt.number}'),
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
    final currentSource = source ?? context.uiText('văn bản đang mở');
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
                    context.uiText(hasText
                        ? 'Nguồn hiện tại: $currentSource · $lineCount dòng.'
                        : 'Chưa có văn bản hoạt động. Hãy mở PDF hoặc Web Reader để chuẩn bị bài viết.'),
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

class _WritingSourceHandoffCard extends StatelessWidget {
  final WritingSourceRequest request;

  const _WritingSourceHandoffCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final sourceIcon = switch (request.kind) {
      WritingSourceKind.web => Icons.language_rounded,
      WritingSourceKind.pdf => Icons.picture_as_pdf_rounded,
      WritingSourceKind.text => Icons.description_outlined,
    };
    final taskLabel = switch (request.task) {
      WritingTaskType.dictation => 'Chép chính tả',
      WritingTaskType.cloze => 'Điền từ',
      WritingTaskType.rewrite => 'Viết lại ý',
      WritingTaskType.summary => 'Tóm tắt ngắn',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(sourceIcon, color: const Color(0xFF81C784), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.isExcerpt
                      ? context.uiText('Đã nhận đoạn chọn để luyện Viết')
                      : context.uiText('Đã nhận nội dung để luyện Viết'),
                  style: const TextStyle(
                    color: Color(0xFFB9F6CA),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  request.sourceLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 7),
                Text(
                  context.uiText(
                    'Đã mở sẵn bài “$taskLabel”. Bạn vẫn có thể đổi dạng bài bên dưới.',
                  ),
                  style: const TextStyle(
                    color: Color(0xFF81C784),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_downward_rounded,
              color: Color(0xFF81C784), size: 18),
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
            'Cần nguồn văn bản để bắt đầu luyện viết',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bạn có thể nhập một bài web hoặc file PDF trước, sau đó các dạng bài viết sẽ dùng chính nội dung đó.',
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
                label: const Text('Mở Web Reader'),
              ),
              ElevatedButton.icon(
                onPressed: onOpenPdfReader,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Mở PDF Reader'),
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
            context.uiText(title),
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
  final bool localizeValue;

  const _MetricRow({
    required this.label,
    required this.value,
    this.localizeValue = false,
  });

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
              context.uiText(label),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              localizeValue ? context.uiText(value) : value,
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
    if (score >= 0.9) return 'Rất tốt · bám câu gần như hoàn chỉnh';
    if (score >= 0.75) return 'Tốt · đã nắm được phần lớn nội dung';
    if (score >= 0.55) return 'Khá · cần luyện thêm thứ tự hoặc chính tả';
    return 'Cần lặp lại · nên nghe/chép thêm vài vòng';
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
      strength = 'Bạn đã giữ được gần như toàn bộ cấu trúc và nội dung câu.';
      tags.add('Giữ câu tốt');
    } else if (result.orderScore >= 0.75) {
      strength = 'Thứ tự ý trong câu khá ổn, nền recall đang tốt.';
      tags.add('Bám trật tự');
    } else if (result.spellingScore >= 0.75) {
      strength =
          'Bạn nghe/nhớ được âm tương đối tốt nhưng cần chắc hơn về cấu trúc.';
      tags.add('Nghe âm ổn');
    } else {
      strength =
          'Bạn đã bắt đầu bám được một phần câu, cần chia nhỏ bài luyện hơn.';
      tags.add('Đang xây nền');
    }

    String issue;
    String nextStep;

    if (result.missingWords.isNotEmpty && result.orderScore < 0.65) {
      issue =
          'Đang rơi cả từ khóa lẫn thứ tự cụm, nên luyện theo chunk ngắn 3–5 từ.';
      nextStep =
          'Nghe lại 2 vòng, dừng sau từng cụm nhỏ rồi chép từng phần trước khi ghép cả câu.';
      tags.add('Thiếu từ khóa');
      tags.add('Vỡ cấu trúc');
    } else if (result.missingWords.isNotEmpty) {
      issue =
          'Bạn bỏ sót một số từ khóa quan trọng: ${result.missingWords.join(', ')}.';
      nextStep =
          'Giữ nguyên tốc độ nhưng nhìn đáp án 1 lần, sau đó che lại và chép thêm 1 vòng tập trung vào từ khóa thiếu.';
      tags.add('Thiếu từ');
    } else if (result.extraWords.isNotEmpty) {
      issue =
          'Bạn thêm từ ngoài câu gốc, dấu hiệu đoán theo ý hơn là bám âm thanh.';
      nextStep =
          'Giảm tốc độ nghe hoặc đọc TTS, tập trung chép đúng những gì thực sự nghe được thay vì suy diễn thêm.';
      tags.add('Thêm từ');
    } else if (result.spellingScore < 0.7) {
      issue = 'Nội dung gần đúng nhưng chính tả/độ sát từng từ còn yếu.';
      nextStep =
          'Mở đáp án, chép lại đúng chính tả 1 vòng rồi làm lại ngay cùng câu để khóa chính xác mặt chữ.';
      tags.add('Chính tả');
    } else {
      issue =
          'Sai số còn nhỏ, chủ yếu ở độ mượt và độ ổn định giữa các lần chép.';
      nextStep =
          'Tăng độ khó bằng cách chuyển sang câu kế tiếp hoặc thử chế độ điền từ để ép recall chủ động hơn.';
      tags.add('Sẵn sàng tăng độ khó');
    }

    if (result.score >= 0.9) {
      tags.add('Qua câu mới');
    } else if (result.score >= 0.7) {
      tags.add('Lặp thêm 1 vòng');
    } else {
      tags.add('Giảm tải');
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
      return 'Viết lại tốt · giữ ý mà vẫn có dấu ấn riêng';
    if (overallScore >= 0.68)
      return 'Khá ổn · bắt đầu có paraphrase và giữ được ý chính';
    if (overallScore >= 0.48)
      return 'Đang lên · giữ được một phần ý nhưng cần viết tự nhiên hơn';
    return 'Cần làm lại · ý hoặc cấu trúc câu chưa đủ rõ';
  }

  Color get feedbackColor {
    if (overallScore >= 0.85) return const Color(0xFF4CAF50);
    if (overallScore >= 0.68) return const Color(0xFF81C784);
    if (overallScore >= 0.48) return const Color(0xFFFFB300);
    return const Color(0xFFFF7043);
  }

  String get summary {
    if (completenessScore < 0.45) {
      return 'Bài viết lại đang thiếu nhiều ý chính so với câu gốc.';
    }
    if (paraphraseScore < 0.4) {
      return 'Bạn giữ ý được nhưng đang bám quá sát câu gốc, chưa thật sự viết lại.';
    }
    if (grammarScore < 0.45) {
      return 'Ý có mặt nhưng câu trả lời chưa thành một phát biểu đủ tự nhiên.';
    }
    return 'Bài viết lại khá cân bằng giữa giữ ý, đổi cách diễn đạt và độ trọn câu.';
  }

  String get strength {
    if (paraphraseScore >= 0.7 && completenessScore >= 0.65) {
      return 'Bạn đã diễn đạt lại mà vẫn giữ được hầu hết từ khóa trọng tâm.';
    }
    if (completenessScore >= 0.75) {
      return 'Khả năng giữ ý chính tốt, nền hiểu bài tương đối chắc.';
    }
    if (grammarScore >= 0.7) {
      return 'Câu trả lời có hình dáng câu khá ổn và dễ đọc.';
    }
    return 'Bạn đã bắt đầu chuyển từ chép sang tự tạo đầu ra, đây là bước rất quan trọng.';
  }

  String get primaryIssue {
    if (completenessScore < 0.45) {
      return 'Thiếu ý chính hoặc bỏ rơi quá nhiều từ khóa trọng tâm.';
    }
    if (paraphraseScore < 0.4) {
      return 'Quá giống câu gốc, nên thay đổi cấu trúc hoặc chọn cách nói khác.';
    }
    if (grammarScore < 0.45) {
      return 'Câu chưa đủ trọn vẹn về hình thức: có thể thiếu động từ, quá ngắn hoặc chưa kết thúc tự nhiên.';
    }
    return 'Sai số còn lại chủ yếu là tinh chỉnh để câu tự nhiên và gọn hơn.';
  }

  String get nextStep {
    if (completenessScore < 0.45) {
      return 'Đọc lại câu gốc, gạch 3–5 từ khóa chính rồi viết lại chỉ với các từ khóa đó trong đầu.';
    }
    if (paraphraseScore < 0.4) {
      return 'Thử đổi trật tự cụm từ hoặc thay ít nhất 1 phần mở đầu/kết thúc trước khi nộp lại.';
    }
    if (grammarScore < 0.45) {
      return 'Viết thành câu dài hơn 4 từ, ưu tiên có một động từ rõ và kết thúc bằng dấu câu.';
    }
    return 'Tăng độ khó bằng cách viết ngắn gọn hơn hoặc diễn đạt cùng ý theo văn phong khác.';
  }

  List<String> get tags {
    final tags = <String>[];
    if (completenessScore >= 0.7) tags.add('Giữ ý tốt');
    if (completenessScore < 0.45) tags.add('Thiếu ý');
    if (paraphraseScore >= 0.7) tags.add('Paraphrase ổn');
    if (paraphraseScore < 0.4) tags.add('Quá sát câu gốc');
    if (grammarScore >= 0.7) tags.add('Câu tự nhiên');
    if (grammarScore < 0.45) tags.add('Câu chưa trọn');
    if (similarityToOriginal > 0.9) tags.add('Cần đổi cấu trúc');
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
    if (overallScore >= 0.85) return 'Tóm tắt tốt · ngắn mà vẫn giữ được ý';
    if (overallScore >= 0.68)
      return 'Khá ổn · đã cô đọng nhưng còn có thể gọn hơn';
    if (overallScore >= 0.48)
      return 'Tạm được · giữ ý một phần nhưng chưa thật sự gói gọn';
    return 'Cần làm lại · đang thiếu ý hoặc chưa đủ cô đọng';
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
      return 'Bản tóm tắt đang rơi mất khá nhiều ý chính.';
    }
    if (brevityScore < 0.45) {
      return 'Bạn giữ ý được nhưng chưa rút gọn đủ so với câu gốc.';
    }
    if (grammarScore < 0.45) {
      return 'Bản tóm tắt còn thiếu hình dáng một câu ngắn, gọn và tự nhiên.';
    }
    return 'Bản tóm tắt khá cân bằng giữa ngắn gọn, giữ ý và dễ đọc.';
  }

  String get nextStep {
    if (contentRetentionScore < 0.45) {
      return 'Giữ lại 2–3 từ khóa trọng tâm nhất rồi viết lại đúng 1 câu ngắn xoay quanh các từ đó.';
    }
    if (brevityScore < 0.45) {
      return 'Lược bớt cụm phụ, trạng từ hoặc giải thích phụ để câu ngắn và bén hơn.';
    }
    if (grammarScore < 0.45) {
      return 'Đảm bảo câu có ít nhất một động từ chính và kết thúc rõ ràng bằng dấu câu.';
    }
    return 'Thử tóm tắt lại ngắn hơn nữa nhưng vẫn giữ nguyên 2 từ khóa cốt lõi.';
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
    if (score >= 1.0) return 'Chính xác hoàn toàn';
    if (score >= 0.67) return 'Ổn · đã nhớ được phần lớn từ khóa';
    if (score > 0.0) return 'Đang lên · thử lại thêm một vòng';
    return 'Chưa khớp · nên xem lại ngữ cảnh';
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
