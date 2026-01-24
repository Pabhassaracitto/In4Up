// lib/providers/text_provider.dart
// PHẦN CẬP NHẬT - Sửa lỗi TTS và thêm Word Analysis

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/text_item.dart';
import '../models/text_segment.dart';
import '../models/word_analysis.dart';

class TextProvider extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();
  final WordDatabase _wordDatabase = WordDatabase();

  // ==================== TEXT DATA ====================
  TextDocument? _currentDocument;
  List<TextItem> _lines = [];
  int _currentLineIndex = -1;
  String? _selectedText;
  String _fullText = '';

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

  // Text data
  TextDocument? get currentDocument => _currentDocument;
  List<TextItem> get lines => _lines;
  int get currentLineIndex => _currentLineIndex;
  String? get selectedText => _selectedText;
  String get fullText => _fullText;

  // Word analysis
  List<List<AnalyzedWord>> get analyzedLines => _analyzedLines;
  ColorMode get colorMode => _colorMode;

  // Segments
  List<TextSegment> get segments => List.unmodifiable(_segments);
  SelectedTextInfo? get selectedTextInfo => _selectedTextInfo;

  // TTS
  double get ttsSpeed => _ttsSpeed;
  double get ttsPitch => _ttsPitch;
  String get ttsLanguage => _ttsLanguage;
  bool get isSpeaking => _isSpeaking;

  // Segment playback
  bool get isPlayingSegment => _isPlayingSegment;
  TextSegment? get currentPlayingSegment => _currentPlayingSegment;
  int get currentRepeatIndex => _currentRepeatIndex;

  // Display
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
      // Flutter TTS sử dụng rate từ 0.0 đến 1.0, không phải 0.25-2.0
      // 0.5 = tốc độ bình thường, 0.0 = chậm nhất, 1.0 = nhanh nhất
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

  /// Chuyển đổi từ tốc độ người dùng (0.25-2.0) sang rate của Flutter TTS (0.0-1.0)
  double _convertSpeedToRate(double speed) {
    // speed 1.0 = rate 0.5 (tốc độ bình thường)
    // speed 0.25 = rate 0.125
    // speed 2.0 = rate 1.0
    return (speed / 2.0).clamp(0.0, 1.0);
  }

  // ==================== TEXT MANAGEMENT ====================

  void loadText(String content, {String? title}) {
    _fullText = content;
    final lineStrings = content.split('\n').where((l) => l.trim().isNotEmpty).toList();

    _lines = lineStrings.asMap().entries.map((entry) {
      return TextItem(
        id: 'line_${entry.key}',
        content: entry.value.trim(),
      );
    }).toList();

    // Phân tích từ vựng cho mỗi dòng
    _analyzedLines = _lines.map((line) {
      return _wordDatabase.analyzeSentence(line.content);
    }).toList();

    _currentDocument = TextDocument(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title ?? 'Untitled',
      lines: _lines,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _currentLineIndex = -1;
    _selectedTextInfo = null;
    _selectedText = null;
    notifyListeners();
  }

  void updateFullText(String newText) {
    _fullText = newText;
    final lineStrings = newText.split('\n').where((l) => l.trim().isNotEmpty).toList();

    _lines = lineStrings.asMap().entries.map((entry) {
      return TextItem(
        id: 'line_${entry.key}',
        content: entry.value.trim(),
      );
    }).toList();

    // Phân tích lại từ vựng
    _analyzedLines = _lines.map((line) {
      return _wordDatabase.analyzeSentence(line.content);
    }).toList();

    if (_currentDocument != null) {
      _currentDocument = TextDocument(
        id: _currentDocument!.id,
        title: _currentDocument!.title,
        lines: _lines,
        createdAt: _currentDocument!.createdAt,
        updatedAt: DateTime.now(),
      );
    }

    _segments.clear();
    _selectedTextInfo = null;
    _selectedText = null;
    _currentLineIndex = -1;

    notifyListeners();
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
    notifyListeners();
  }

  void setCurrentLine(int index) {
    if (index >= 0 && index < _lines.length) {
      _currentLineIndex = index;
      notifyListeners();
    }
  }

  void selectText(String text) {
    _selectedText = text;
    notifyListeners();
  }

  void clearSelection() {
    _selectedText = null;
    _selectedTextInfo = null;
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

  // ==================== TEXT SELECTION WITH OFFSETS ====================

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

  // ==================== TTS FUNCTIONS (SỬA LỖI) ====================

  /// Phát TTS và đợi cho đến khi hoàn thành
  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    await _tts.stop();

    _ttsCompleter = Completer<void>();

    await _tts.speak(text);

    // Đợi cho đến khi TTS hoàn thành
    try {
      await _ttsCompleter?.future.timeout(
        Duration(seconds: text.length ~/ 2 + 10), // Timeout dựa trên độ dài text
        onTimeout: () {
          debugPrint('TTS timeout');
        },
      );
    } catch (e) {
      debugPrint('TTS speak error: $e');
    }
  }

  Future<void> speakCurrentLine() async {
    if (_currentLineIndex >= 0 && _currentLineIndex < _lines.length) {
      await speak(_lines[_currentLineIndex].content);
    }
  }

  /// Đọc tất cả các dòng - ĐÃ SỬA
  Future<void> speakAllLines() async {
    _isSpeaking = true;
    notifyListeners();

    for (int i = 0; i < _lines.length; i++) {
      if (!_isSpeaking) break; // Cho phép dừng giữa chừng

      _currentLineIndex = i;
      notifyListeners();

      // Đợi TTS hoàn thành trước khi chuyển dòng
      await speak(_lines[i].content);

      // Khoảng nghỉ giữa các dòng
      if (_isSpeaking && i < _lines.length - 1) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }

    _isSpeaking = false;
    notifyListeners();
  }

  Future<void> speakSelected() async {
    if (_selectedText != null && _selectedText!.isNotEmpty) {
      await speak(_selectedText!);
    }
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    _isSpeaking = false;
    _isPlayingSegment = false;
    _currentPlayingSegment = null;
    _currentRepeatIndex = 0;
    _ttsCompleter?.complete();
    _ttsCompleter = null;
    notifyListeners();
  }

  /// Set tốc độ TTS - ĐÃ SỬA
  Future<void> setTtsSpeed(double speed) async {
    _ttsSpeed = speed.clamp(0.25, 2.0);
    // Chuyển đổi sang rate của Flutter TTS
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
          milliseconds: segment.difficulty == TextSegmentDifficulty.hard
              ? 1500
              : 800,
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

  /// Đánh dấu độ khó cho một từ trong analyzed words
  void markWordDifficulty(int lineIndex, int wordIndex, DifficultyLevel difficulty) {
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

  /// Đọc TTS các từ khó trước theo thứ tự độ khó
  Future<void> speakDifficultWordsFirst() async {
    final difficultWords = <AnalyzedWord>[];

    // Thu thập tất cả từ khó
    for (final line in _analyzedLines) {
      for (final word in line) {
        if (word.userDifficulty != null &&
            word.userDifficulty != DifficultyLevel.known) {
          difficultWords.add(word);
        }
      }
    }

    // Sắp xếp theo độ khó (khó nhất trước)
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
      avgMastery = _segments.map((s) => s.masteryLevel).reduce((a, b) => a + b) /
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

  /// Thống kê từ vựng theo CEFR
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

  /// Thống kê từ vựng theo loại từ
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

  // ==================== DIFFICULTY MARKING (Legacy support) ====================

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

  // ==================== DISPOSE ====================

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}