// lib/providers/text_provider.dart
// VipSound - Text Provider với đầy đủ tính năng

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/color_mode.dart';
import '../models/text_item.dart';
import '../models/text_segment.dart';
import '../models/word_analysis.dart';
import '../services/syntax_highlighter_service.dart';

class TextProvider extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();

  // ==================== TEXT DATA ====================
  TextDocument? _currentDocument;
  List<TextItem> _lines = [];
  int _currentLineIndex = -1;
  String? _selectedText;
  String _fullText = '';
  String? _currentTextPath;

  // ==================== WORD ANALYSIS ====================
  List<List<AnalyzedWord>> _analyzedLines = [];
  ColorMode _colorMode = ColorMode.none;

  // ==================== TEXT SEGMENTS ====================
  final List<TextSegment> _segments = [];
  SelectedTextInfo? _selectedTextInfo;

  // ==================== TTS SETTINGS ====================
  double _ttsSpeed = 1.0;
  double _ttsPitch = 1.0;
  String _ttsLanguage = 'en-US';
  bool _isSpeaking = false;
  Completer<void>? _ttsCompleter;

  // ==================== SEGMENT PLAYBACK ====================
  bool _isPlayingSegment = false;
  TextSegment? _currentPlayingSegment;
  int _currentRepeatIndex = 0;

  // ==================== DISPLAY SETTINGS ====================
  double _fontSize = 18.0;
  bool _showTranslation = true;
  bool _showWordTypes = false;

  // ==================== GETTERS ====================

  TextDocument? get currentDocument => _currentDocument;
  List<TextItem> get lines => _lines;
  int get currentLineIndex => _currentLineIndex;
  String? get selectedText => _selectedText;
  String get fullText => _fullText;
  bool get hasLyrics => _lines.isNotEmpty;
  String? get currentTextPath => _currentTextPath;

  List<List<AnalyzedWord>> get analyzedLines => _analyzedLines;
  ColorMode get colorMode => _colorMode;

  List<TextSegment> get segments => List.unmodifiable(_segments);
  SelectedTextInfo? get selectedTextInfo => _selectedTextInfo;

  double get ttsSpeed => _ttsSpeed;
  double get ttsPitch => _ttsPitch;
  String get ttsLanguage => _ttsLanguage;
  bool get isSpeaking => _isSpeaking;

  bool get isPlayingSegment => _isPlayingSegment;
  TextSegment? get currentPlayingSegment => _currentPlayingSegment;
  int get currentRepeatIndex => _currentRepeatIndex;

  double get fontSize => _fontSize;
  bool get showTranslation => _showTranslation;
  bool get showWordTypes => _showWordTypes;

  // ==================== CONSTRUCTOR ====================

  TextProvider() {
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage(_ttsLanguage);
      await _tts.setSpeechRate(_convertSpeedToRate(_ttsSpeed));
      await _tts.setPitch(_ttsPitch);
      await _tts.setVolume(1.0);

      _tts.setStartHandler(() {
        _isSpeaking = true;
        notifyListeners();
      });

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        _ttsCompleter?.complete();
        _ttsCompleter = null;
        notifyListeners();
      });

      _tts.setCancelHandler(() {
        _isSpeaking = false;
        _ttsCompleter?.complete();
        _ttsCompleter = null;
        notifyListeners();
      });

      _tts.setErrorHandler((msg) {
        _isSpeaking = false;
        _ttsCompleter?.completeError(msg);
        _ttsCompleter = null;
        debugPrint('TTS Error: $msg');
        notifyListeners();
      });
    } catch (e) {
      debugPrint('TTS Init Error: $e');
    }
  }

  double _convertSpeedToRate(double speed) {
    return (speed / 2.0).clamp(0.0, 1.0);
  }

  // ==================== TEXT MANAGEMENT ====================

  void loadText(String content, {String? title}) {
    _parsePlainText(content, title: title);
    _currentTextPath = null;
  }

  void loadFromString(String content, {String? title}) {
    _parsePlainText(content, title: title);
    _currentTextPath = null;
  }

  Future<void> loadTextFile(String path, {String? title}) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        debugPrint('TextProvider.loadTextFile: File not found: $path');
        return;
      }

      _currentTextPath = path;

      final content = await file.readAsString();
      final lower = path.toLowerCase();
      final docTitle = title ?? _extractFileName(path);

      if (lower.endsWith('.lrc')) {
        _parseLrc(content, title: docTitle);
      } else if (lower.endsWith('.srt')) {
        _parseSrt(content, title: docTitle);
      } else {
        _parsePlainText(content, title: docTitle);
      }
    } catch (e) {
      debugPrint('TextProvider.loadTextFile error: $e');
    }
  }

  void updateFullText(String newText) {
    _parsePlainText(newText, title: _currentDocument?.title);
  }

  void clearText() {
    _lines = [];
    _analyzedLines = [];
    _currentDocument = null;
    _currentLineIndex = -1;
    _selectedText = null;
    _selectedTextInfo = null;
    _fullText = '';
    _segments.clear();
    _currentTextPath = null;
    notifyListeners();
  }

  void clearSelection() {
    _selectedText = null;
    _selectedTextInfo = null;
    notifyListeners();
  }

  void selectText(String text) {
    _selectedText = text;
    notifyListeners();
  }

  void setCurrentLine(int index) {
    if (index >= 0 && index < _lines.length) {
      _currentLineIndex = index;
      notifyListeners();
    }
  }

  String _extractFileName(String path) {
    return path.split(Platform.pathSeparator).last;
  }

  void _parsePlainText(String content, {String? title}) {
    _fullText = content;

    final lineStrings =
        content.split('\n').where((l) => l.trim().isNotEmpty).toList();

    _lines = lineStrings.asMap().entries.map((entry) {
      return TextItem(
        id: 'line_${entry.key}',
        content: entry.value.trim(),
      );
    }).toList();

    _analyzedLines = SyntaxHighlighterService.analyzeLines(
      _lines.map((l) => l.content).toList(),
    );

    _currentDocument = TextDocument(
      id: _currentDocument?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: title ?? _currentDocument?.title ?? 'Untitled',
      lines: _lines,
      createdAt: _currentDocument?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _currentLineIndex = -1;
    _selectedTextInfo = null;
    _selectedText = null;
    notifyListeners();
  }

  void _parseLrc(String content, {String? title}) {
    _fullText = content;
    _lines = [];

    final regex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');
    final rawLines = content.split('\n');

    for (final raw in rawLines) {
      final match = regex.firstMatch(raw);
      if (match == null) continue;

      final minutes = int.tryParse(match.group(1) ?? '') ?? 0;
      final seconds = int.tryParse(match.group(2) ?? '') ?? 0;
      final fraction = match.group(3) ?? '00';
      final text = (match.group(4) ?? '').trim();
      if (text.isEmpty) continue;

      final ms =
          fraction.length == 2 ? int.parse(fraction) * 10 : int.parse(fraction);

      final start = Duration(
        minutes: minutes,
        seconds: seconds,
        milliseconds: ms,
      );

      _lines.add(TextItem(
        id: 'line_${_lines.length}',
        content: text,
        startTime: start,
      ));
    }

    for (int i = 0; i < _lines.length - 1; i++) {
      final nextStart = _lines[i + 1].startTime;
      if (nextStart != null) {
        _lines[i] = _lines[i].copyWith(endTime: nextStart);
      }
    }

    _analyzedLines = SyntaxHighlighterService.analyzeLines(
      _lines.map((l) => l.content).toList(),
    );

    _currentDocument = TextDocument(
      id: _currentDocument?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: title ?? _currentDocument?.title ?? 'Untitled',
      lines: _lines,
      createdAt: _currentDocument?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _currentLineIndex = -1;
    _selectedTextInfo = null;
    _selectedText = null;
    notifyListeners();
  }

  void _parseSrt(String content, {String? title}) {
    _fullText = content;
    _lines = [];

    final blocks = content.split(RegExp(r'\r?\n\r?\n+'));

    final timeRegex = RegExp(
      r'(\d{2}):(\d{2}):(\d{2}),(\d{3})\s*-->\s*'
      r'(\d{2}):(\d{2}):(\d{2}),(\d{3})',
    );

    Duration parseTime(int h, int m, int s, int ms) => Duration(
          hours: h,
          minutes: m,
          seconds: s,
          milliseconds: ms,
        );

    for (int i = 0; i < blocks.length; i++) {
      final block = blocks[i].trim();
      if (block.isEmpty) continue;

      final linesBlock = block.split('\n');
      if (linesBlock.length < 2) continue;

      final timeMatch = timeRegex.firstMatch(linesBlock[1]);
      if (timeMatch == null) continue;

      final start = parseTime(
        int.parse(timeMatch.group(1)!),
        int.parse(timeMatch.group(2)!),
        int.parse(timeMatch.group(3)!),
        int.parse(timeMatch.group(4)!),
      );

      final end = parseTime(
        int.parse(timeMatch.group(5)!),
        int.parse(timeMatch.group(6)!),
        int.parse(timeMatch.group(7)!),
        int.parse(timeMatch.group(8)!),
      );

      final text = linesBlock.skip(2).join('\n').trim();
      if (text.isEmpty) continue;

      _lines.add(TextItem(
        id: 'line_${_lines.length}',
        content: text,
        startTime: start,
        endTime: end,
      ));
    }

    _analyzedLines = SyntaxHighlighterService.analyzeLines(
      _lines.map((l) => l.content).toList(),
    );

    _currentDocument = TextDocument(
      id: _currentDocument?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: title ?? _currentDocument?.title ?? 'Untitled',
      lines: _lines,
      createdAt: _currentDocument?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _currentLineIndex = -1;
    _selectedTextInfo = null;
    _selectedText = null;
    notifyListeners();
  }

  // ==================== COLOR MODE ====================

  void setColorMode(ColorMode mode) {
    _colorMode = mode;
    notifyListeners();
  }

  void cycleColorMode() {
    final modes = ColorMode.values;
    final currentIndex = modes.indexOf(_colorMode);
    _colorMode = modes[(currentIndex + 1) % modes.length];
    notifyListeners();
  }

  // ==================== TEXT SELECTION ====================

  void selectTextWithOffsets({
    required String text,
    required int startOffset,
    required int endOffset,
    required int lineIndex,
  }) {
    _selectedTextInfo = SelectedTextInfo(
      text: text,
      startOffset: startOffset,
      endOffset: endOffset,
      lineIndex: lineIndex,
    );
    _selectedText = text;
    notifyListeners();
  }

  int calculateGlobalOffset(int lineIndex, int localOffset) {
    int globalOffset = 0;
    for (int i = 0; i < lineIndex && i < _lines.length; i++) {
      globalOffset += _lines[i].content.length + 1;
    }
    return globalOffset + localOffset;
  }

  // ==================== SEGMENT MANAGEMENT ====================

  TextSegment? createSegmentFromSelection({
    TextSegmentDifficulty difficulty = TextSegmentDifficulty.medium,
    TextSegmentType type = TextSegmentType.phrase,
    int? repeatCountOverride,
    double? ttsSpeedOverride,
    String? note,
    String? translation,
    List<String> tags = const [],
  }) {
    if (_selectedTextInfo == null) return null;

    final info = _selectedTextInfo!;

    final repeatCount = repeatCountOverride ??
        (difficulty == TextSegmentDifficulty.hard
            ? 5
            : difficulty == TextSegmentDifficulty.medium
                ? 3
                : 1);

    final speed = ttsSpeedOverride ??
        (difficulty == TextSegmentDifficulty.hard
            ? 0.7
            : difficulty == TextSegmentDifficulty.medium
                ? 0.85
                : 1.0);

    final segment = TextSegment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: info.text,
      startOffset: info.startOffset,
      endOffset: info.endOffset,
      difficulty: difficulty,
      type: type,
      repeatCount: repeatCount,
      ttsSpeed: speed,
      note: note,
      translation: translation,
      tags: tags,
    );

    _segments.add(segment);
    _selectedTextInfo = null;
    _selectedText = null;

    notifyListeners();
    return segment;
  }

  void deleteSegment(String id) {
    _segments.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  void updateSegment(TextSegment updated) {
    final index = _segments.indexWhere((s) => s.id == updated.id);
    if (index >= 0) {
      _segments[index] = updated;
      notifyListeners();
    }
  }

  List<TextSegment> getSegmentsByDifficulty(TextSegmentDifficulty difficulty) {
    return _segments.where((s) => s.difficulty == difficulty).toList();
  }

  List<TextSegment> getSegmentsForReview() {
    return _segments.where((s) => s.needsReview).toList();
  }

  List<TextSegment> getSegmentsByType(TextSegmentType type) {
    return _segments.where((s) => s.type == type).toList();
  }

  // ==================== TTS FUNCTIONS ====================

  Future<void> speakSelected() async {
    if (_selectedText == null || _selectedText!.isEmpty) {
      debugPrint('No text selected to speak.');
      return;
    }

    _isSpeaking = true;
    notifyListeners();

    try {
      await speak(_selectedText!);
    } catch (e) {
      debugPrint('Error in speakSelected: $e');
    } finally {
      _isSpeaking = false;
      notifyListeners();
    }
  }

  Future<void> speakAllLines() async {
    if (_lines.isEmpty) return;

    _isSpeaking = true;
    notifyListeners();

    try {
      for (int i = 0; i < _lines.length; i++) {
        if (!_isSpeaking) break;

        _currentLineIndex = i;
        notifyListeners();

        await speak(_lines[i].content);

        if (_isSpeaking && i < _lines.length - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    } catch (e) {
      debugPrint('Error in speakAllLines: $e');
    } finally {
      _isSpeaking = false;
      notifyListeners();
    }
  }

  Future<void> speakCurrentLine() async {
    if (_currentLineIndex < 0 || _currentLineIndex >= _lines.length) {
      debugPrint('Invalid line index: $_currentLineIndex');
      return;
    }

    _isSpeaking = true;
    notifyListeners();

    try {
      await speak(_lines[_currentLineIndex].content);
    } catch (e) {
      debugPrint('Error in speakCurrentLine: $e');
    } finally {
      _isSpeaking = false;
      notifyListeners();
    }
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    try {
      await _tts.stop();
      _ttsCompleter = Completer<void>();
      final result = await _tts.speak(text);

      if (result == 1) {
        final wordCount = text.split(' ').length;
        final estimatedSeconds = (wordCount * 60 / 150 / _ttsSpeed).ceil();
        final timeout = Duration(seconds: estimatedSeconds.clamp(3, 60));

        await _ttsCompleter?.future.timeout(
          timeout,
          onTimeout: () {
            debugPrint('TTS timeout');
          },
        );
      }
    } catch (e) {
      debugPrint('Error in speak: $e');
    }
  }

  Future<void> stopSpeaking() async {
    _isSpeaking = false;
    _isPlayingSegment = false;
    _currentPlayingSegment = null;
    _currentRepeatIndex = 0;

    if (_ttsCompleter != null && !_ttsCompleter!.isCompleted) {
      _ttsCompleter!.complete();
    }
    _ttsCompleter = null;

    await _tts.stop();
    notifyListeners();
  }

  Future<void> setTtsSpeed(double speed) async {
    _ttsSpeed = speed.clamp(0.25, 2.0);
    await _tts.setSpeechRate(_convertSpeedToRate(_ttsSpeed));
    notifyListeners();
  }

  Future<void> setTtsPitch(double pitch) async {
    _ttsPitch = pitch.clamp(0.5, 2.0);
    await _tts.setPitch(_ttsPitch);
    notifyListeners();
  }

  Future<void> setTtsLanguage(String language) async {
    _ttsLanguage = language;
    await _tts.setLanguage(language);
    notifyListeners();
  }

  // ==================== SEGMENT TTS ====================

  Future<void> speakSegment(TextSegment segment) async {
    _isPlayingSegment = true;
    _currentPlayingSegment = segment;
    _currentRepeatIndex = 0;
    notifyListeners();

    final originalSpeed = _ttsSpeed;
    await setTtsSpeed(segment.ttsSpeed);

    for (int i = 0; i < segment.repeatCount; i++) {
      if (!_isPlayingSegment) break;

      _currentRepeatIndex = i + 1;
      notifyListeners();

      await speak(segment.content);

      if (i < segment.repeatCount - 1 && _isPlayingSegment) {
        await Future.delayed(Duration(
          milliseconds:
              segment.difficulty == TextSegmentDifficulty.hard ? 1500 : 800,
        ));
      }
    }

    await setTtsSpeed(originalSpeed);

    if (_isPlayingSegment) {
      final updated = segment.copyWith(
        lastPracticed: DateTime.now(),
        practiceCount: segment.practiceCount + 1,
        masteryLevel: _calculateNewMastery(segment),
      );
      updateSegment(updated);
    }

    _isPlayingSegment = false;
    _currentPlayingSegment = null;
    _currentRepeatIndex = 0;
    notifyListeners();
  }

  void stopSegmentPlayback() {
    _isPlayingSegment = false;
    _currentPlayingSegment = null;
    _currentRepeatIndex = 0;
    stopSpeaking();
    notifyListeners();
  }

  double _calculateNewMastery(TextSegment segment) {
    final increment = 0.1 / (segment.difficulty.index + 1);
    return (segment.masteryLevel + increment).clamp(0.0, 1.0);
  }

  Future<void> startReviewSession() async {
    final toReview = getSegmentsForReview();
    _isPlayingSegment = true;
    notifyListeners();

    for (final segment in toReview) {
      if (!_isPlayingSegment) break;
      await speakSegment(segment);
      if (_isPlayingSegment) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    _isPlayingSegment = false;
    notifyListeners();
  }

  // ==================== WORD DIFFICULTY MARKING ====================

  void markWordDifficulty(
      int lineIndex, int wordIndex, DifficultyLevel difficulty) {
    if (lineIndex >= 0 && lineIndex < _analyzedLines.length) {
      if (wordIndex >= 0 && wordIndex < _analyzedLines[lineIndex].length) {
        _analyzedLines[lineIndex][wordIndex] =
            _analyzedLines[lineIndex][wordIndex].copyWith(
          userDifficulty: difficulty,
        );
        notifyListeners();
      }
    }
  }

  Future<void> speakDifficultWordsFirst() async {
    final difficultWords = <AnalyzedWord>[];

    for (final line in _analyzedLines) {
      for (final word in line) {
        if (word.userDifficulty != null) {
          difficultWords.add(word);
        }
      }
    }

    difficultWords.sort((a, b) {
      final aLevel = a.userDifficulty?.index ?? 0;
      final bLevel = b.userDifficulty?.index ?? 0;
      return bLevel.compareTo(aLevel);
    });

    _isPlayingSegment = true;
    notifyListeners();

    for (final word in difficultWords) {
      if (!_isPlayingSegment) break;

      final repeatCount = word.userDifficulty?.repeatCount ?? 1;
      final speed = word.userDifficulty?.ttsSpeed ?? 1.0;

      await setTtsSpeed(speed);

      for (int i = 0; i < repeatCount; i++) {
        if (!_isPlayingSegment) break;
        await speak(word.word);
        if (i < repeatCount - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      await Future.delayed(const Duration(milliseconds: 800));
    }

    await setTtsSpeed(1.0);
    _isPlayingSegment = false;
    notifyListeners();
  }

  // ==================== STATISTICS ====================

  Map<String, dynamic> getSegmentStats() {
    final easy = getSegmentsByDifficulty(TextSegmentDifficulty.easy).length;
    final medium = getSegmentsByDifficulty(TextSegmentDifficulty.medium).length;
    final hard = getSegmentsByDifficulty(TextSegmentDifficulty.hard).length;
    final needsReview = getSegmentsForReview().length;

    double avgMastery = 0.0;
    if (_segments.isNotEmpty) {
      avgMastery =
          _segments.map((s) => s.masteryLevel).reduce((a, b) => a + b) /
              _segments.length;
    }

    return {
      'total': _segments.length,
      'easy': easy,
      'medium': medium,
      'hard': hard,
      'needsReview': needsReview,
      'averageMastery': avgMastery,
    };
  }

  Map<CEFRLevel, int> getCEFRStats() {
    final stats = <CEFRLevel, int>{};
    for (final level in CEFRLevel.values) {
      stats[level] = 0;
    }

    for (final line in _analyzedLines) {
      for (final word in line) {
        stats[word.cefrLevel] = (stats[word.cefrLevel] ?? 0) + 1;
      }
    }

    return stats;
  }

  Map<WordType, int> getWordTypeStats() {
    final stats = <WordType, int>{};
    for (final type in WordType.values) {
      stats[type] = 0;
    }

    for (final line in _analyzedLines) {
      for (final word in line) {
        stats[word.wordType] = (stats[word.wordType] ?? 0) + 1;
      }
    }

    return stats;
  }

  // ==================== DISPLAY SETTINGS ====================

  void setFontSize(double size) {
    _fontSize = size.clamp(12.0, 32.0);
    notifyListeners();
  }

  void toggleTranslation() {
    _showTranslation = !_showTranslation;
    notifyListeners();
  }

  void toggleWordTypes() {
    _showWordTypes = !_showWordTypes;
    notifyListeners();
  }

  // ==================== DIFFICULTY MARKING (Legacy) ====================

  void markLineDifficulty(int lineIndex, DifficultyMark difficulty) {
    if (lineIndex >= 0 && lineIndex < _lines.length) {
      final line = _lines[lineIndex];
      final words = line.content.split(' ').map((word) {
        return WordItem(word: word, difficulty: difficulty);
      }).toList();

      _lines[lineIndex] = line.copyWith(words: words);
      notifyListeners();
    }
  }

  void markSelectedDifficulty(DifficultyMark difficulty) {
    if (_selectedText == null) return;
    notifyListeners();
  }

  // ==================== SYNC WITH AUDIO ====================

  void syncWithAudioPosition(Duration position) {
    for (int i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      if (line.startTime != null && line.endTime != null) {
        if (position >= line.startTime! && position <= line.endTime!) {
          if (_currentLineIndex != i) {
            _currentLineIndex = i;
            notifyListeners();
          }
          break;
        }
      }
    }
  }

  // ==================== ANALYZED LINES METHODS ====================

  /// Dùng bởi read_mode_controller.dart
  void setAnalyzedLines(List<List<AnalyzedWord>> lines) {
    _analyzedLines = lines;
    notifyListeners();
  }

  /// Alias cho setAnalyzedLines - dùng bởi controller cũ
  void updateAnalyzedLines(List<List<AnalyzedWord>> analyzed) {
    setAnalyzedLines(analyzed);
  }

  // ==================== SEGMENT MANAGEMENT EXTENSIONS ====================

  void addSegment({
    required String name,
    required String content,
    required int startLine,
    required int endLine,
    Color color = const Color(0xFF2196F3),
    String? note,
  }) {
    final segment = TextSegment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      content: content,
      startLine: startLine,
      endLine: endLine,
      color: color,
      note: note,
    );
    _segments.add(segment);
    notifyListeners();
  }

  // ==================== VOCABULARY ====================

  final List<AnalyzedWord> _savedWords = [];
  List<AnalyzedWord> get savedWords => List.unmodifiable(_savedWords);

  void saveWord(AnalyzedWord word) {
    if (!_savedWords.any((w) => w.word == word.word)) {
      _savedWords.add(word);
      notifyListeners();
    }
  }

  // ==================== DISPOSE ====================

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}
