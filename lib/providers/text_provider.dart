// lib/providers/text_provider.dart
// VipSound - Enhanced Text Provider
// Version 2.0 - With Segment-based Learning

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/text_item.dart';
import '../models/text_segment.dart';

class TextProvider extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();

  // === TEXT DATA ===
  TextDocument? _currentDocument;
  List<TextItem> _lines = [];
  String _fullText = '';
  int _currentLineIndex = -1;

  // === SELECTION ===
  SelectedTextInfo? _selectedTextInfo;
  String? _selectedText;

  // === SEGMENTS (Learning Units) ===
  final List<TextSegment> _segments = [];
  int _currentSegmentIndex = -1;
  bool _isStudyingSegment = false;
  int _currentRepeatCount = 0;

  // === TTS SETTINGS ===
  double _ttsSpeed = 1.0;
  double _ttsPitch = 1.0;
  String _ttsLanguage = 'en-US';
  bool _isSpeaking = false;
  double _ttsVolume = 1.0;

  // === DISPLAY SETTINGS ===
  double _fontSize = 18.0;
  bool _showTranslation = true;
  bool _showWordTypes = false;
  bool _highlightSegments = true;

  // === STUDY STATS ===
  int _totalReviewsToday = 0;
  Duration _studyTimeToday = Duration.zero;
  DateTime? _studySessionStart;

  // ==================== GETTERS ====================

  // Text data
  TextDocument? get currentDocument => _currentDocument;
  List<TextItem> get lines => _lines;
  String get fullText => _fullText;
  int get currentLineIndex => _currentLineIndex;
  bool get hasText => _fullText.isNotEmpty;

  // Selection
  SelectedTextInfo? get selectedTextInfo => _selectedTextInfo;
  String? get selectedText => _selectedText;
  bool get hasSelection => _selectedTextInfo != null;

  // Segments
  List<TextSegment> get segments => List.unmodifiable(_segments);
  int get currentSegmentIndex => _currentSegmentIndex;
  TextSegment? get currentSegment =>
      _currentSegmentIndex >= 0 && _currentSegmentIndex < _segments.length
          ? _segments[_currentSegmentIndex]
          : null;
  bool get isStudyingSegment => _isStudyingSegment;
  int get currentRepeatCount => _currentRepeatCount;
  bool get hasSegments => _segments.isNotEmpty;

  // TTS
  double get ttsSpeed => _ttsSpeed;
  double get ttsPitch => _ttsPitch;
  String get ttsLanguage => _ttsLanguage;
  bool get isSpeaking => _isSpeaking;
  double get ttsVolume => _ttsVolume;

  // Display
  double get fontSize => _fontSize;
  bool get showTranslation => _showTranslation;
  bool get showWordTypes => _showWordTypes;
  bool get highlightSegments => _highlightSegments;

  // Stats
  int get totalReviewsToday => _totalReviewsToday;
  Duration get studyTimeToday => _studyTimeToday;

  // Filtered segments
  List<TextSegment> get hardSegments =>
      _segments.where((s) => s.difficulty == TextSegmentDifficulty.hard).toList();
  List<TextSegment> get dueForReview =>
      _segments.where((s) => _isDueForReview(s)).toList();

  // ==================== CONSTRUCTOR ====================

  TextProvider() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage(_ttsLanguage);
    await _tts.setSpeechRate(_ttsSpeed);
    await _tts.setPitch(_ttsPitch);
    await _tts.setVolume(_ttsVolume);

    _tts.setStartHandler(() {
      _isSpeaking = true;
      notifyListeners();
    });

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      _onTtsCompleted();
      notifyListeners();
    });

    _tts.setCancelHandler(() {
      _isSpeaking = false;
      _isStudyingSegment = false;
      notifyListeners();
    });

    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
      _isStudyingSegment = false;
      debugPrint('TTS Error: $msg');
      notifyListeners();
    });
  }

  // ==================== TEXT MANAGEMENT ====================

  /// Load text từ string
  void loadText(String content, {String? title}) {
    _fullText = content;
    _lines = _splitToLines(content);

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
    // Không clear segments để giữ lại các đoạn đã đánh dấu nếu cùng văn bản

    notifyListeners();
  }

  /// Cập nhật toàn bộ văn bản (Edit mode)
  void updateFullText(String newText) {
    _fullText = newText;
    _lines = _splitToLines(newText);

    if (_currentDocument != null) {
      _currentDocument = TextDocument(
        id: _currentDocument!.id,
        title: _currentDocument!.title,
        lines: _lines,
        createdAt: _currentDocument!.createdAt,
        updatedAt: DateTime.now(),
      );
    }

    // Kiểm tra và điều chỉnh segments nếu offset bị lệch
    _validateSegments();

    notifyListeners();
  }

  List<TextItem> _splitToLines(String content) {
    int currentOffset = 0;
    return content.split('\n').where((l) => l.trim().isNotEmpty).map((line) {
      final item = TextItem(
        id: 'line_$currentOffset',
        content: line.trim(),
        startTime: null,
        endTime: null,
      );
      currentOffset += line.length + 1; // +1 for newline
      return item;
    }).toList();
  }

  void _validateSegments() {
    // Loại bỏ segments có offset vượt quá độ dài văn bản
    _segments.removeWhere((s) =>
    s.startOffset >= _fullText.length ||
        s.endOffset > _fullText.length);

    // Cập nhật content cho các segments còn lại
    for (int i = 0; i < _segments.length; i++) {
      final seg = _segments[i];
      if (seg.startOffset < _fullText.length && seg.endOffset <= _fullText.length) {
        final newContent = _fullText.substring(seg.startOffset, seg.endOffset);
        if (newContent != seg.content) {
          _segments[i] = seg.copyWith(content: newContent);
        }
      }
    }
  }

  void clearText() {
    _lines = [];
    _fullText = '';
    _currentDocument = null;
    _currentLineIndex = -1;
    _selectedTextInfo = null;
    _selectedText = null;
    notifyListeners();
  }

  void setCurrentLine(int index) {
    if (index >= -1 && index < _lines.length) {
      _currentLineIndex = index;
      notifyListeners();
    }
  }

  // ==================== SELECTION ====================

  /// Chọn text với offset (dùng cho segment creation)
  void selectTextWithOffsets({
    required String text,
    required int startOffset,
    required int endOffset,
    int lineIndex = -1,
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

  /// Chọn text đơn giản (legacy)
  void selectText(String text) {
    _selectedText = text;
    notifyListeners();
  }

  void clearSelection() {
    _selectedTextInfo = null;
    _selectedText = null;
    notifyListeners();
  }

  /// Tính offset trong fullText từ line index và local offset
  int calculateGlobalOffset(int lineIndex, int localOffset) {
    int globalOffset = 0;
    for (int i = 0; i < lineIndex && i < _lines.length; i++) {
      globalOffset += _lines[i].content.length + 1; // +1 for newline
    }
    return globalOffset + localOffset;
  }

  // ==================== SEGMENT MANAGEMENT ====================

  /// Tạo segment từ selection hiện tại
  TextSegment? createSegmentFromSelection({
    required TextSegmentDifficulty difficulty,
    TextSegmentCategory category = TextSegmentCategory.custom,
    int? repeatCountOverride,
    double? ttsSpeedOverride,
    double? gapDurationOverride,
    String? note,
    String? translation,
    String? pronunciation,
    List<String> tags = const [],
  }) {
    if (_selectedTextInfo == null) return null;

    final info = _selectedTextInfo!;

    // Validate offsets
    if (info.startOffset < 0 ||
        info.endOffset > _fullText.length ||
        info.startOffset >= info.endOffset) {
      return null;
    }

    final repeatCount = repeatCountOverride ??
        TextSegment.suggestedRepeatCount(difficulty);
    final ttsSpd = ttsSpeedOverride ??
        TextSegment.suggestedTtsSpeed(difficulty);

    final segment = TextSegment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: info.text,
      startOffset: info.startOffset,
      endOffset: info.endOffset,
      difficulty: difficulty,
      category: category,
      repeatCount: repeatCount,
      ttsSpeed: ttsSpd,
      gapDuration: gapDurationOverride ?? 1.0,
      note: note,
      translation: translation,
      pronunciation: pronunciation,
      createdAt: DateTime.now(),
      tags: tags,
    );

    _segments.add(segment);
    _sortSegmentsByOffset();
    clearSelection();
    notifyListeners();

    return segment;
  }

  /// Tạo segment từ offset trực tiếp
  TextSegment? createSegment({
    required int startOffset,
    required int endOffset,
    required TextSegmentDifficulty difficulty,
    TextSegmentCategory category = TextSegmentCategory.custom,
    int? repeatCount,
    double? ttsSpeed,
    String? note,
    String? translation,
    List<String> tags = const [],
  }) {
    if (startOffset < 0 || endOffset > _fullText.length || startOffset >= endOffset) {
      return null;
    }

    final content = _fullText.substring(startOffset, endOffset);
    final segment = TextSegment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      startOffset: startOffset,
      endOffset: endOffset,
      difficulty: difficulty,
      category: category,
      repeatCount: repeatCount ?? TextSegment.suggestedRepeatCount(difficulty),
      ttsSpeed: ttsSpeed ?? TextSegment.suggestedTtsSpeed(difficulty),
      note: note,
      translation: translation,
      createdAt: DateTime.now(),
      tags: tags,
    );

    _segments.add(segment);
    _sortSegmentsByOffset();
    notifyListeners();

    return segment;
  }

  /// Cập nhật segment
  void updateSegment(String id, {
    TextSegmentDifficulty? difficulty,
    TextSegmentCategory? category,
    int? repeatCount,
    double? ttsSpeed,
    double? gapDuration,
    String? note,
    String? translation,
    String? pronunciation,
    List<String>? tags,
  }) {
    final index = _segments.indexWhere((s) => s.id == id);
    if (index == -1) return;

    _segments[index] = _segments[index].copyWith(
      difficulty: difficulty,
      category: category,
      repeatCount: repeatCount,
      ttsSpeed: ttsSpeed,
      gapDuration: gapDuration,
      note: note,
      translation: translation,
      pronunciation: pronunciation,
      tags: tags,
    );
    notifyListeners();
  }

  /// Xóa segment
  void deleteSegment(String id) {
    _segments.removeWhere((s) => s.id == id);
    if (_currentSegmentIndex >= _segments.length) {
      _currentSegmentIndex = _segments.length - 1;
    }
    notifyListeners();
  }

  /// Xóa tất cả segments
  void clearAllSegments() {
    _segments.clear();
    _currentSegmentIndex = -1;
    notifyListeners();
  }

  void _sortSegmentsByOffset() {
    _segments.sort((a, b) => a.startOffset.compareTo(b.startOffset));
  }

  /// Lấy segments theo category
  List<TextSegment> getSegmentsByCategory(TextSegmentCategory category) {
    return _segments.where((s) => s.category == category).toList();
  }

  /// Lấy segments theo difficulty
  List<TextSegment> getSegmentsByDifficulty(TextSegmentDifficulty difficulty) {
    return _segments.where((s) => s.difficulty == difficulty).toList();
  }

  /// Kiểm tra xem một vị trí có nằm trong segment nào không
  TextSegment? getSegmentAtOffset(int offset) {
    for (final seg in _segments) {
      if (offset >= seg.startOffset && offset < seg.endOffset) {
        return seg;
      }
    }
    return null;
  }

  bool _isDueForReview(TextSegment segment) {
    if (segment.lastReviewedAt == null) return true;

    // Simple spaced repetition: dựa trên reviewCount
    final daysSinceReview =
        DateTime.now().difference(segment.lastReviewedAt!).inDays;
    final interval = _getReviewInterval(segment.reviewCount);

    return daysSinceReview >= interval;
  }

  int _getReviewInterval(int reviewCount) {
    // Fibonacci-like intervals: 1, 1, 2, 3, 5, 8, 13...
    if (reviewCount <= 1) return 1;
    if (reviewCount == 2) return 1;
    if (reviewCount == 3) return 2;
    if (reviewCount == 4) return 3;
    if (reviewCount == 5) return 5;
    if (reviewCount == 6) return 8;
    return 13;
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
      _currentLineIndex = i;
      notifyListeners();
      await speak(_lines[i].content);
      // Chờ cho đến khi nói xong (đơn giản hóa)
      await Future.delayed(Duration(
        milliseconds: (_lines[i].content.length * 80 / _ttsSpeed).round(),
      ));
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
    _isStudyingSegment = false;
    _currentRepeatCount = 0;
    notifyListeners();
  }

  // ==================== SEGMENT TTS (Study Mode) ====================

  /// Phát TTS cho một segment với số lần lặp và khoảng nghỉ
  Future<void> speakSegment(TextSegment segment) async {
    _isStudyingSegment = true;
    _currentRepeatCount = 0;
    _currentSegmentIndex = _segments.indexOf(segment);

    // Bắt đầu study session nếu chưa có
    _studySessionStart ??= DateTime.now();

    // Lưu tốc độ gốc
    final originalSpeed = _ttsSpeed;

    // Đặt tốc độ của segment
    await setTtsSpeed(segment.ttsSpeed);
    notifyListeners();

    for (int i = 0; i < segment.repeatCount && _isStudyingSegment; i++) {
      _currentRepeatCount = i + 1;
      notifyListeners();

      await speak(segment.content);

      // Chờ cho đến khi nói xong
      await _waitForTtsComplete();

      // Khoảng nghỉ giữa các lần lặp
      if (i < segment.repeatCount - 1 && _isStudyingSegment) {
        await Future.delayed(Duration(
          milliseconds: (segment.gapDuration * 1000).round(),
        ));
      }
    }

    // Cập nhật thống kê
    _updateSegmentReviewStats(segment.id);
    _totalReviewsToday++;

    // Khôi phục tốc độ gốc
    await setTtsSpeed(originalSpeed);

    _isStudyingSegment = false;
    _currentRepeatCount = 0;
    notifyListeners();
  }

  Future<void> _waitForTtsComplete() async {
    while (_isSpeaking) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  void _onTtsCompleted() {
    // Callback khi TTS hoàn thành một câu
  }

  void _updateSegmentReviewStats(String segmentId) {
    final index = _segments.indexWhere((s) => s.id == segmentId);
    if (index == -1) return;

    _segments[index] = _segments[index].copyWith(
      lastReviewedAt: DateTime.now(),
      reviewCount: _segments[index].reviewCount + 1,
    );
  }

  /// Phát tất cả segments cần ôn tập
  Future<void> speakAllDueSegments() async {
    final due = dueForReview;
    for (final segment in due) {
      if (!_isStudyingSegment) break;
      await speakSegment(segment);
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  /// Bỏ qua segment hiện tại
  void skipCurrentSegment() {
    _isStudyingSegment = false;
    _currentRepeatCount = 0;
    stopSpeaking();
  }

  // ==================== TTS SETTINGS ====================

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

  Future<void> setTtsVolume(double volume) async {
    _ttsVolume = volume.clamp(0.0, 1.0);
    await _tts.setVolume(_ttsVolume);
    notifyListeners();
  }

  Future<void> setTtsLanguage(String language) async {
    _ttsLanguage = language;
    await _tts.setLanguage(language);
    notifyListeners();
  }

  // ==================== DISPLAY SETTINGS ====================

  void setFontSize(double size) {
    _fontSize = size.clamp(12.0, 36.0);
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

  void toggleHighlightSegments() {
    _highlightSegments = !_highlightSegments;
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
    // Chuyển đổi sang segment-based
    if (_selectedTextInfo == null) return;

    final segDifficulty = difficulty == DifficultyMark.hard
        ? TextSegmentDifficulty.hard
        : difficulty == DifficultyMark.medium
        ? TextSegmentDifficulty.medium
        : TextSegmentDifficulty.easy;

    createSegmentFromSelection(
      difficulty: segDifficulty,
      category: TextSegmentCategory.difficult,
    );
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

  // ==================== STATS ====================

  TextLearningStats getStats() {
    return TextLearningStats(
      totalSegments: _segments.length,
      easyCount: _segments.where((s) => s.difficulty == TextSegmentDifficulty.easy).length,
      mediumCount: _segments.where((s) => s.difficulty == TextSegmentDifficulty.medium).length,
      hardCount: _segments.where((s) => s.difficulty == TextSegmentDifficulty.hard).length,
      masterCount: _segments.where((s) => s.difficulty == TextSegmentDifficulty.master).length,
      totalReviews: _totalReviewsToday,
      totalStudyTime: _studyTimeToday,
    );
  }

  void resetDailyStats() {
    _totalReviewsToday = 0;
    _studyTimeToday = Duration.zero;
    _studySessionStart = null;
    notifyListeners();
  }

  // ==================== DISPOSE ====================

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}