// lib/providers/text_provider.dart
// Chỉ thêm các phần thay đổi - giữ nguyên toàn bộ code cũ

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../features/translation/text_provider_translation.dart';
import '../features/translation/translation_display_mode.dart';
import '../features/tts/tts_service.dart';
import '../models/color_mode.dart';
import '../models/text_item.dart';
import '../models/text_segment.dart';
import '../models/word_analysis.dart';
import '../screens/memory_mode/memory_provider.dart';
import '../services/storage_service.dart'; // ★ THÊM
import '../services/syntax_highlighter_service.dart';
import '../services/text_splitter_service.dart';

class TextProvider extends ChangeNotifier with TranslationMixin {
  final TtsService _ttsService = TtsService();
  final StorageService _storage = StorageService();

  // ====================  TEXT DATA ====================
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

  // ==================== SEGMENT PLAYBACK ====================
  bool _isPlayingSegment = false;
  TextSegment? _currentPlayingSegment;
  int _currentRepeatIndex = 0;

  // ==================== DISPLAY SETTINGS ====================
  double _fontSize = 18.0;
  // bool _showTranslation = true; // REMOVED
  bool _showWordTypes = false;

  // ==================== GETTERS ====================
  TextDocument? get currentDocument => _currentDocument;
  @override
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
  bool get showTranslation =>
      translationDisplayMode != TranslationDisplayMode.hidden; // CHANGED
  bool get showWordTypes => _showWordTypes;

  // ==================== CONSTRUCTOR ====================

  TextProvider() {
    _restoreFromStorage();
  }

  // ★ THÊM: Restore settings
  void _restoreFromStorage() {
    if (!_storage.isInitialized) return;

    try {
      _fontSize = _storage.getFontSize();
      _ttsSpeed = _storage.getTtsSpeed();

      if (_storage.getShowTranslation()) {
        setTranslationDisplayMode(TranslationDisplayMode.stackedBelow);
      } else {
        setTranslationDisplayMode(TranslationDisplayMode.hidden);
      }

      // Restore color mode
      final savedColorMode = _storage.getColorMode();
      _colorMode = ColorMode.values.firstWhere(
        (m) => m.name == savedColorMode,
        orElse: () => ColorMode.none,
      );

      // Restore text segments
      final savedSegments = _storage.getAllTextSegments();
      _segments.addAll(savedSegments);

      // Restore saved words
      // (savedWords sẽ được load lazy khi cần)

      debugPrint('✅ TextProvider restored: '
          'fontSize=$_fontSize, '
          'colorMode=${_colorMode.name}, '
          'segments=${_segments.length}');
    } catch (e) {
      debugPrint('⚠️ Error restoring TextProvider: $e');
    }
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

      // ★ THÊM: Save last text path
      _storage.saveLastTextPath(path);
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

    // ★ THÊM: Persist
    _storage.saveColorMode(mode.name);

    notifyListeners();
  }

  void cycleColorMode() {
    final modes = ColorMode.values;
    final currentIndex = modes.indexOf(_colorMode);
    _colorMode = modes[(currentIndex + 1) % modes.length];

    // ★ THÊM: Persist
    _storage.saveColorMode(_colorMode.name);

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

  // ==================== TEXT LINE EDITING ====================

  /// Sửa nội dung + bản dịch của 1 dòng
  void editLine({
    required int index,
    required String content,
    String? translation,
  }) {
    if (index < 0 || index >= _lines.length) return;

    _lines[index] = _lines[index].copyWith(
      content: content.trim(),
      translation: (translation == null || translation.trim().isEmpty)
          ? null
          : translation.trim(),
    );

    // Re-analyze từ loại
    final analyzed = SyntaxHighlighterService.analyzeLine(content);
    if (index < _analyzedLines.length) {
      _analyzedLines[index] = analyzed;
    } else {
      while (_analyzedLines.length <= index) {
        _analyzedLines.add([]);
      }
      _analyzedLines[index] = analyzed;
    }

    notifyListeners();
    debugPrint('✏️ editLine($index): "$content"');
  }

  /// Xoá 1 dòng
  void deleteLine(int index) {
    if (index < 0 || index >= _lines.length) return;

    _lines.removeAt(index);
    if (index < _analyzedLines.length) _analyzedLines.removeAt(index);

    if (_currentLineIndex >= _lines.length) {
      _currentLineIndex = _lines.length - 1;
    }
    if (_currentLineIndex == index) _currentLineIndex = -1;

    notifyListeners();
    debugPrint('🗑️ deleteLine($index)');
  }

  /// Tách 1 dòng thành nhiều dòng (khi user nhấn Enter trong LineEditSheet)
  void splitLine({
    required int index,
    required List<String> contentLines,
    List<String> translationLines = const [],
  }) {
    if (index < 0 || index >= _lines.length) return;
    if (contentLines.isEmpty) {
      deleteLine(index);
      return;
    }

    final original = _lines[index];

    final newItems = contentLines.asMap().entries.map((e) {
      final i = e.key;
      final text = e.value.trim();
      final trans = i < translationLines.length
          ? (translationLines[i].trim().isEmpty
              ? null
              : translationLines[i].trim())
          : null;
      return TextItem(
        id: '${original.id}_s$i',
        content: text,
        translation: trans,
        startTime: i == 0 ? original.startTime : null,
        endTime: i == 0 ? original.endTime : null,
      );
    }).toList();

    final newAnalyzed = contentLines
        .map((c) => SyntaxHighlighterService.analyzeLine(c))
        .toList();

    _lines
      ..removeAt(index)
      ..insertAll(index, newItems);

    if (index < _analyzedLines.length) {
      _analyzedLines.removeAt(index);
    } else {
      while (_analyzedLines.length <= index) {
        _analyzedLines.add([]);
      }
    }
    _analyzedLines.insertAll(index, newAnalyzed);

    if (_currentLineIndex >= index) _currentLineIndex = index;

    notifyListeners();
    debugPrint('✂️ splitLine($index) → ${contentLines.length} lines');
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

    // ★ THÊM: Persist
    _storage.saveTextSegment(segment);

    notifyListeners();
    return segment;
  }

  void deleteSegment(String id) {
    _segments.removeWhere((s) => s.id == id);

    // ★ THÊM: Persist
    _storage.deleteTextSegment(id);

    notifyListeners();
  }

  void updateSegment(TextSegment updated) {
    final index = _segments.indexWhere((s) => s.id == updated.id);
    if (index >= 0) {
      _segments[index] = updated;

      // ★ THÊM: Persist
      _storage.saveTextSegment(updated);

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

  void addTextSegment(TextSegment segment) {
    _segments.add(segment);
    notifyListeners();
  }

  // ==================== TTS FUNCTIONS ====================

  Future<void> speakSelected() async {
    if (_selectedText == null || _selectedText!.isEmpty) return;
    await _ttsService.speak(_selectedText!);
  }

  Future<void> speakAllLines() async {
    if (_lines.isEmpty) return;
    _isSpeaking = true;
    notifyListeners();

    final lineTexts = _lines.map((l) => l.content).toList();
    await _ttsService.speakLines(
      lineTexts,
      onLineChanged: (index) {
        // Guard: widget có thể đã unmount
        if (!hasListeners) return;
        _currentLineIndex = index;
        notifyListeners();
      },
    );

    _isSpeaking = false;
    notifyListeners();
  }

  Future<void> speakCurrentLine() async {
    // ★ FIX: Guard khi chưa chọn dòng
    if (_currentLineIndex < 0 || _currentLineIndex >= _lines.length) {
      // Nếu chưa có dòng nào được chọn, phát dòng đầu tiên
      if (_lines.isNotEmpty) {
        _currentLineIndex = 0;
        notifyListeners();
        await _ttsService.speak(_lines[0].content);
      }
      return;
    }
    await _ttsService.speak(_lines[_currentLineIndex].content);
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    await _ttsService.speak(text);
  }

  Future<void> stopSpeaking() async {
    _isSpeaking = false;
    _isPlayingSegment = false;
    _currentPlayingSegment = null;
    _currentRepeatIndex = 0;
    await _ttsService.stop();
    notifyListeners();
  }

  Future<void> setTtsSpeed(double speed) async {
    _ttsSpeed = speed.clamp(0.25, 2.0);
    _ttsService.configure(speed: _ttsSpeed);
    _storage.saveTtsSpeed(_ttsSpeed);
    notifyListeners();
  }

  Future<void> setTtsPitch(double pitch) async {
    _ttsPitch = pitch.clamp(0.5, 2.0);
    _ttsService.configure(pitch: _ttsPitch);
    notifyListeners();
  }

  Future<void> setTtsLanguage(String language) async {
    _ttsLanguage = language;
    _ttsService.configure(language: language);
    notifyListeners();
  }

  // ==================== SEGMENT TTS ====================

  Future<void> speakSegment(TextSegment segment) async {
    _isPlayingSegment = true;
    _currentPlayingSegment = segment;
    _currentRepeatIndex = 0;
    notifyListeners();

    final originalSpeed = _ttsSpeed;
    _ttsService.configure(speed: segment.ttsSpeed);

    for (int i = 0; i < segment.repeatCount; i++) {
      if (!_isPlayingSegment) break;
      _currentRepeatIndex = i + 1;
      notifyListeners();

      await _ttsService.speak(segment.content);
      await Future.delayed(Duration(
        milliseconds:
            segment.difficulty == TextSegmentDifficulty.hard ? 1500 : 800,
      ));
    }

    _ttsService.configure(speed: originalSpeed);

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
    _ttsService.stop();
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

  // ==================== WORD DIFFICULTY ====================

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

    // ★ THÊM: Persist
    _storage.saveFontSize(_fontSize);

    notifyListeners();
  }

  void toggleTranslation() {
    // Bridge to mixin: toggle between hidden and stacked
    if (translationDisplayMode == TranslationDisplayMode.hidden) {
      setTranslationDisplayMode(TranslationDisplayMode.stackedBelow);
    } else {
      setTranslationDisplayMode(TranslationDisplayMode.hidden);
    }
    _storage.saveShowTranslation(showTranslation);
    notifyListeners();
  }

  void toggleWordTypes() {
    _showWordTypes = !_showWordTypes;
    notifyListeners();
  }

  // ==================== LEGACY ====================

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

  // ==================== ANALYZED LINES ====================

  void setAnalyzedLines(List<List<AnalyzedWord>> lines) {
    _analyzedLines = lines;
    notifyListeners();
  }

  void updateAnalyzedLines(List<List<AnalyzedWord>> analyzed) {
    setAnalyzedLines(analyzed);
  }

  // ==================== SEGMENT EXTENSIONS ====================

  void addSegment({
    required String name,
    required String content,
    required int startLine,
    required int endLine,
    Color color = const Color(0xFF2196F3),
    String? note,
    String? ipa,
    String? translation,
  }) {
    final segment = TextSegment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      content: content,
      startLine: startLine,
      endLine: endLine,
      color: color,
      note: note,
      ipa: ipa,
      translation: translation,
    );
    _segments.add(segment);

    // ★ THÊM: Persist
    _storage.saveTextSegment(segment);

    notifyListeners();
  }

  // ==================== VOCABULARY ====================

  final List<AnalyzedWord> _savedWords = [];
  List<AnalyzedWord> get savedWords => List.unmodifiable(_savedWords);

  void saveWord(AnalyzedWord word) {
    if (!_savedWords.any((w) => w.word == word.word)) {
      _savedWords.add(word);

      // Phần này lưu cho list "Saved Words" của tab Đọc (giữ nguyên của bạn)
      _storage.saveWord(word.word, {
        'word': word.word,
        'originalWord': word.originalWord,
        'wordType': word.wordType.name,
        'cefrLevel': word.cefrLevel.name,
        'meaning': word.meaning,
        'phonetic': word.phonetic,
        'example': word.example,
        'savedAt': DateTime.now().toIso8601String(),
      });

      // ★ SỬA LẠI ĐOẠN NÀY:
      // Bọc trong Future.microtask để tránh xung đột luồng (Race Condition) và Stack Overflow
      Future.microtask(() {
        try {
          debugPrint('🔄 Đang gửi từ "${word.word}" sang Vườn Nhớ...');
          MemoryProvider.addWord(
            word: word.word,
            meaning: word.meaning,
            phonetic: word.phonetic,
            example: word.example,
            wordType: word.wordType.name,
            cefrLevel: word.cefrLevel.name,
            sourceFile: _currentTextPath?.split('/').last ?? 'Unknown',
          );
          debugPrint('✅ Đã gửi xong!');
        } catch (e) {
          debugPrint('⚠️ Lỗi gửi sang Memory (không ảnh hưởng app): $e');
        }
      });

      notifyListeners();
    }
  }

  // ==================== DISPOSE ====================

  @override
  void dispose() {
    _ttsService.stop();
    super.dispose();
  }

  /// Tách dòng tự động và load lại
  void autoSplitText({
    SplitMode mode = SplitMode.smart,
    int minWords = 4,
    int maxWords = 15,
  }) {
    if (_fullText.isEmpty) return;

    final lines = TextSplitterService.split(
      _fullText,
      mode: mode,
      minWordsBeforeSplit: minWords,
      maxWordsPerLine: maxWords,
    );

    _applyLines(lines);
  }

  /// Load từ danh sách dòng đã tách
  void loadFromLines(List<String> lines, {String? title}) {
    _applyLines(lines, title: title);
  }

  void _applyLines(List<String> lineStrings, {String? title}) {
    _lines = lineStrings.asMap().entries.map((entry) {
      return TextItem(
        id: 'line_${entry.key}',
        content: entry.value.trim(),
      );
    }).toList();

    _fullText = lineStrings.join('\n');

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

    debugPrint('✂️ Auto-split: ${_lines.length} lines');
  }
}
