// lib/providers/text_provider.dart
// VipSound - Text Provider
// Version 3.0 - Enhanced with Text Segments & SRS

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/text_item.dart';
import '../models/text_segment.dart';

class TextProvider extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();

  // ==================== TEXT DATA ====================
  TextDocument? _currentDocument;
  List<TextItem> _lines = [];
  int _currentLineIndex = -1;
  String? _selectedText;
  String _fullText = '';

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
  bool _showTranslation = true;
  bool _showWordTypes = false;

  // ==================== GETTERS ====================

  // Text data
  TextDocument? get currentDocument => _currentDocument;
  List<TextItem> get lines => _lines;
  int get currentLineIndex => _currentLineIndex;
  String? get selectedText => _selectedText;
  String get fullText => _fullText;

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
    await _tts.setLanguage(_ttsLanguage);
    await _tts.setSpeechRate(_ttsSpeed);
    await _tts.setPitch(_ttsPitch);
    await _tts.setVolume(1.0);

    _tts.setStartHandler(() {
      _isSpeaking = true;
      notifyListeners();
    });

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      notifyListeners();
    });

    _tts.setCancelHandler(() {
      _isSpeaking = false;
      notifyListeners();
    });

    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
      debugPrint('TTS Error: $msg');
      notifyListeners();
    });
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

    if (_currentDocument != null) {
      _currentDocument = TextDocument(
        id: _currentDocument!.id,
        title: _currentDocument!.title,
        lines: _lines,
        createdAt: _currentDocument!.createdAt,
        updatedAt: DateTime.now(),
      );
    }

    // Clear segments vì offset có thể bị lệch
    _segments.clear();
    _selectedTextInfo = null;
    _selectedText = null;
    _currentLineIndex = -1;

    notifyListeners();
  }

  void clearText() {
    _lines = [];
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
      globalOffset += _lines[i].content.length + 1; // +1 for newline
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

    // Tính repeatCount theo độ khó nếu không override
    final repeatCount = repeatCountOverride ??
        (difficulty == TextSegmentDifficulty.hard
            ? 5
            : difficulty == TextSegmentDifficulty.medium
            ? 3
            : 1);

    // Tính ttsSpeed theo độ khó nếu không override
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

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> speakCurrentLine() async {
    if (_currentLineIndex >= 0 && _currentLineIndex < _lines.length) {
      await speak(_lines[_currentLineIndex].content);
    }
  }

  Future<void> speakAllLines() async {
    for (int i = 0; i < _lines.length; i++) {
      if (!_isSpeaking && i > 0) break; // Cho phép dừng giữa chừng
      _currentLineIndex = i;
      notifyListeners();
      await speak(_lines[i].content);
      // Đợi TTS hoàn thành
      await Future.delayed(const Duration(milliseconds: 500));
    }
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
    notifyListeners();
  }

  Future<void> setTtsSpeed(double speed) async {
    _ttsSpeed = speed.clamp(0.1, 2.0);
    await _tts.setSpeechRate(_ttsSpeed);
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

    // Lưu tốc độ gốc
    final originalSpeed = _ttsSpeed;

    // Set tốc độ của segment
    await setTtsSpeed(segment.ttsSpeed);

    for (int i = 0; i < segment.repeatCount; i++) {
      if (!_isPlayingSegment) break; // Cho phép dừng giữa chừng

      _currentRepeatIndex = i + 1;
      notifyListeners();

      await speak(segment.content);

      // Đợi TTS hoàn thành + khoảng nghỉ
      await _waitForTtsComplete();

      // Khoảng nghỉ giữa các lần lặp
      if (i < segment.repeatCount - 1 && _isPlayingSegment) {
        await Future.delayed(Duration(
          milliseconds: segment.difficulty == TextSegmentDifficulty.hard
              ? 1500
              : 800,
        ));
      }
    }

    // Khôi phục tốc độ gốc
    await setTtsSpeed(originalSpeed);

    // Cập nhật thống kê
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

  Future<void> _waitForTtsComplete() async {
    // Đợi tối đa 30 giây cho TTS hoàn thành
    int waited = 0;
    while (_isSpeaking && waited < 30000) {
      await Future.delayed(const Duration(milliseconds: 100));
      waited += 100;
    }
  }

  void stopSegmentPlayback() {
    _isPlayingSegment = false;
    _currentPlayingSegment = null;
    _currentRepeatIndex = 0;
    stopSpeaking();
    notifyListeners();
  }

  double _calculateNewMastery(TextSegment segment) {
    // Tăng mastery mỗi lần luyện, tối đa 1.0
    // Khó hơn = tăng chậm hơn
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
    // Có thể mở rộng để lưu vào danh sách điểm mù
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