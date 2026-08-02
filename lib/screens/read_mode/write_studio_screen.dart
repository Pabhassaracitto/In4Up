import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vipsound_ai/vipsound_ai.dart';

import '../../models/text_item.dart';
import '../../providers/text_provider.dart';

enum _WriteExerciseType {
  dictation,
  clozeInput,
  clozeChoice,
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

  _WriteExerciseType _exerciseType = _WriteExerciseType.dictation;
  String _sourceKey = '';
  String _lastAiPromptKey = '';
  int _lineIndex = 0;
  bool _showAnswer = false;

  _DictationResult? _dictationResult;
  _ClozeResult? _clozeResult;

  List<TextEditingController> _blankControllers = [];
  List<_BlankPrompt> _blankPrompts = [];
  List<List<String>> _choiceOptions = [];
  List<String?> _selectedChoices = [];

  @override
  void dispose() {
    _dictationController.dispose();
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
    _dictationResult = null;
    _clozeResult = null;
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
      final tooClose = selected.any((value) => (value - candidate.index).abs() < 2);
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

    final pool = _buildChoicePool(textProvider, prompts.map((e) => e.answer).toSet());
    final options = prompts.map((prompt) {
      final distractors = pool.where((word) => word != prompt.answer).toList()..shuffle(_random);
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
    _blankControllers = List.generate(prompts.length, (_) => TextEditingController());
  }

  List<String> _buildChoicePool(TextProvider textProvider, Set<String> excluded) {
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
    final orderScore = expectedTokens.isEmpty ? 0.0 : lcs / expectedTokens.length;
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
    return input
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9']"), '')
        .trim();
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

  String _buildAiPrompt({
    required String expected,
    required String actual,
    required _DictationResult result,
  }) {
    return '''
VIPSOUND_WRITE_REVIEW
EXPECTED: $expected
ACTUAL: $actual
TOTAL_SCORE: ${(result.score * 100).round()}
ORDER_SCORE: ${(result.orderScore * 100).round()}
SPELLING_SCORE: ${(result.spellingScore * 100).round()}
MISSING: ${result.missingWords.isEmpty ? 'none' : result.missingWords.join(', ')}
EXTRA: ${result.extraWords.isEmpty ? 'none' : result.extraWords.join(', ')}

Bạn là bộ phản hồi viết offline của VipSound.
Hãy trả về JSON hợp lệ với:
- summary: nhận xét ngắn bằng tiếng Việt
- topics: 2-4 nhãn ngắn
- action_items: 2-4 gợi ý luyện tiếp cụ thể
- grammar: nếu có thể, mô tả ngắn subject/verb/object/pattern/explanation_vi
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
            Text('Để dùng phản hồi AI cục bộ, hãy import model .gguf vào thiết bị.'),
            SizedBox(height: 8),
            Text('Khuyến nghị: gemma-2b-it-q4_k_m.gguf (~1.5GB)'),
            SizedBox(height: 8),
            Text('Khi chưa có model, phần Chấm nhanh vẫn hoạt động hoàn toàn offline.'),
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
          final currentTitle = textProvider.currentDocument?.title ?? 'Văn bản hiện tại';
          final currentLine = hasText ? textProvider.lines[_lineIndex] : null;
          final activeLineIndex = textProvider.currentLineIndex;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
                  else
                    _buildClozeCard(currentLine!),
                  const SizedBox(height: 20),
                  const _TipCard(
                    title: 'Vai trò của tab Viết',
                    bullets: [
                      'Viết là nhánh output gắn trực tiếp với nguồn text hoặc lyric hiện tại.',
                      'Mặc định ưu tiên discoverability: người mới nhìn vào là biết có chép, điền từ và chọn đáp án.',
                      'Các bài viết nâng cao và AI scoring sâu hơn sẽ tiếp tục nối vào đây trên cùng kiến trúc.',
                    ],
                  ),
                ],
              ],
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
              label: Text('Dùng dòng đang focus trong tab Đọc (#${activeLineIndex + 1})'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExerciseSelector(TextProvider textProvider) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ExerciseSelectorChip(
              label: 'Chép',
              selected: _exerciseType == _WriteExerciseType.dictation,
              color: const Color(0xFF26C6DA),
              onTap: () => _cycleExercise(textProvider, _WriteExerciseType.dictation),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ExerciseSelectorChip(
              label: 'Điền từ',
              selected: _exerciseType == _WriteExerciseType.clozeInput,
              color: const Color(0xFFFFB300),
              onTap: () => _cycleExercise(textProvider, _WriteExerciseType.clozeInput),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ExerciseSelectorChip(
              label: 'Chọn đáp án',
              selected: _exerciseType == _WriteExerciseType.clozeChoice,
              color: const Color(0xFFAB47BC),
              onTap: () => _cycleExercise(textProvider, _WriteExerciseType.clozeChoice),
            ),
          ),
        ],
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
                  onPressed: _lineIndex > 0 ? () => _changeLine(textProvider, _lineIndex - 1) : null,
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Trước'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: textProvider.lines.length > 1
                      ? () => _changeLine(textProvider, _random.nextInt(textProvider.lines.length))
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
        border: Border.all(color: const Color(0xFF26C6DA).withValues(alpha: 0.18)),
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
                _ScorePill(score: result.score, accent: const Color(0xFF26C6DA)),
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
                icon: Icon(_showAnswer ? Icons.visibility_off : Icons.visibility),
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
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
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
              hintText: 'Nhập lại câu bạn nghe hoặc nhớ được...',
              hintStyle: TextStyle(color: Colors.grey[500]),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
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
                _MetricRow(label: 'Thứ tự câu', value: '${(result.orderScore * 100).round()}%'),
                _MetricRow(label: 'Độ sát chính tả', value: '${(result.spellingScore * 100).round()}%'),
                _MetricRow(label: 'Từ thiếu', value: result.missingWords.isEmpty ? 'Không có' : result.missingWords.join(', ')),
                _MetricRow(label: 'Từ dư', value: result.extraWords.isEmpty ? 'Không có' : result.extraWords.join(', ')),
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
        border: Border.all(color: const Color(0xFF7C4DFF).withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_alt_outlined, color: Color(0xFFB388FF)),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: facade.hasModel
                      ? const Color(0xFF4CAF50).withValues(alpha: 0.12)
                      : Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  facade.hasModel ? 'AI local sẵn sàng' : 'Chỉ tầng cục bộ',
                  style: TextStyle(
                    color: facade.hasModel ? const Color(0xFF81C784) : Colors.orange,
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
              _MetricRow(label: 'Kết luận', value: coach.summary),
              _MetricRow(label: 'Thế mạnh', value: coach.strength),
              _MetricRow(label: 'Điểm cần sửa', value: coach.primaryIssue),
              _MetricRow(label: 'Lượt tiếp theo', value: coach.nextStep),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: coach.tags
                .map(
                  (tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                  onPressed: !facade.hasModel || !hasTextInput || isLoadingCurrent
                      ? null
                      : () => _runAiReview(currentLine: currentLine, result: result),
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
                  value: analysis.topics.isEmpty ? 'Chưa có' : analysis.topics.join(', '),
                ),
                _MetricRow(
                  label: 'Hành động',
                  value: analysis.actionItems.isEmpty
                      ? 'Chưa có gợi ý hành động cụ thể từ AI.'
                      : analysis.actionItems.join(' • '),
                ),
                if (analysis.grammar != null) ...[
                  _MetricRow(label: 'Chủ ngữ', value: analysis.grammar!.subject),
                  _MetricRow(label: 'Động từ', value: analysis.grammar!.verb),
                  _MetricRow(label: 'Mẫu câu', value: analysis.grammar!.pattern),
                ],
              ],
            ),
          ],
          if (facade.lastError != null && !isLoadingCurrent && analysis == null) ...[
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
                color: isChoice ? const Color(0xFFAB47BC) : const Color(0xFFFFB300),
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
                  accent: isChoice ? const Color(0xFFAB47BC) : const Color(0xFFFFB300),
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
          if (isChoice)
            _buildChoiceInputs()
          else
            _buildTypingInputs(),
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
                'Đáp án: ${_blankPrompts.map((e) => '${e.number}. ${e.answer}').join('   •   ')}',
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
        final isCorrect = result != null && result.userAnswers[index] == prompt.answer;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: _blankControllers[index],
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Ô ${prompt.number}',
              hintText: 'Nhập từ cần điền',
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
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
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
        final options = index < _choiceOptions.length ? _choiceOptions[index] : const <String>[];
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
                        ? 'Nguồn hiện tại: ${source ?? 'văn bản đang mở'} · $lineCount dòng.'
                        : 'Chưa có văn bản hoạt động. Hãy mở PDF hoặc Web Reader để chuẩn bị bài viết.',
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
          color: selected ? color.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.06),
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
        color: reveal ? const Color(0xFF4CAF50).withValues(alpha: 0.16) : const Color(0xFFFFB300).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: reveal ? const Color(0xFF4CAF50).withValues(alpha: 0.3) : const Color(0xFFFFB300).withValues(alpha: 0.3),
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
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
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
      strength = 'Bạn nghe/nhớ được âm tương đối tốt nhưng cần chắc hơn về cấu trúc.';
      tags.add('Nghe âm ổn');
    } else {
      strength = 'Bạn đã bắt đầu bám được một phần câu, cần chia nhỏ bài luyện hơn.';
      tags.add('Đang xây nền');
    }

    String issue;
    String nextStep;

    if (result.missingWords.isNotEmpty && result.orderScore < 0.65) {
      issue = 'Đang rơi cả từ khóa lẫn thứ tự cụm, nên luyện theo chunk ngắn 3–5 từ.';
      nextStep = 'Nghe lại 2 vòng, dừng sau từng cụm nhỏ rồi chép từng phần trước khi ghép cả câu.';
      tags.add('Thiếu từ khóa');
      tags.add('Vỡ cấu trúc');
    } else if (result.missingWords.isNotEmpty) {
      issue = 'Bạn bỏ sót một số từ khóa quan trọng: ${result.missingWords.join(', ')}.';
      nextStep = 'Giữ nguyên tốc độ nhưng nhìn đáp án 1 lần, sau đó che lại và chép thêm 1 vòng tập trung vào từ khóa thiếu.';
      tags.add('Thiếu từ');
    } else if (result.extraWords.isNotEmpty) {
      issue = 'Bạn thêm từ ngoài câu gốc, dấu hiệu đoán theo ý hơn là bám âm thanh.';
      nextStep = 'Giảm tốc độ nghe hoặc đọc TTS, tập trung chép đúng những gì thực sự nghe được thay vì suy diễn thêm.';
      tags.add('Thêm từ');
    } else if (result.spellingScore < 0.7) {
      issue = 'Nội dung gần đúng nhưng chính tả/độ sát từng từ còn yếu.';
      nextStep = 'Mở đáp án, chép lại đúng chính tả 1 vòng rồi làm lại ngay cùng câu để khóa chính xác mặt chữ.';
      tags.add('Chính tả');
    } else {
      issue = 'Sai số còn nhỏ, chủ yếu ở độ mượt và độ ổn định giữa các lần chép.';
      nextStep = 'Tăng độ khó bằng cách chuyển sang câu kế tiếp hoặc thử chế độ điền từ để ép recall chủ động hơn.';
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
      chunks.add('${prompts[i].number}) ${actual.isEmpty ? '∅' : actual} → $expected');
    }
    return chunks.join('   •   ');
  }
}
