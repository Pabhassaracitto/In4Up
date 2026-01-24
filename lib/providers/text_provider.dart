import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/text_item.dart';
import '../models/text_segment.dart';

class TextProvider extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();

// Text data
  TextDocument? _currentDocument;
  List<TextItem> _lines = [];
  int _currentLineIndex = -1;
  String? _selectedText;

// TTS settings
  double _ttsSpeed = 1.0;
  double _ttsPitch = 1.0;
  String _ttsLanguage = 'en-US';
  bool _isSpeaking = false;

// Display settings
  double _fontSize = 18.0;
  bool _showTranslation = true;
  bool _showWordTypes = false;

// Getters
  TextDocument? get currentDocument => _currentDocument;
  List<TextItem> get lines => _lines;
  int get currentLineIndex => _currentLineIndex;
  String? get selectedText => _selectedText;
  double get ttsSpeed => _ttsSpeed;
  double get ttsPitch => _ttsPitch;
  String get ttsLanguage => _ttsLanguage;
  bool get isSpeaking => _isSpeaking;
  double get fontSize => _fontSize;
  bool get showTranslation => _showTranslation;
  bool get showWordTypes => _showWordTypes;

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
      notifyListeners();
    });
  }
// ==================== TEXT MANAGEMENT ====================
  void loadText(String content, {String? title}) {
    final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    _lines = lines.asMap().entries.map((entry) {
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
    notifyListeners();
  }

  void clearText() {
    _lines = [];
    _currentDocument = null;
    _currentLineIndex = -1;
    _selectedText = null;
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
    notifyListeners();
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

// ==================== DIFFICULTY MARKING ====================

  void markLineDifficulty(int lineIndex, DifficultyMark difficulty) {
    if (lineIndex >= 0 && lineIndex < _lines.length) {
// Tạo line mới với các words được đánh dấu
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
// Lưu vào danh sách điểm mù để ôn tập sau
    notifyListeners();
  }

// ==================== SYNC WITH AUDIO ====================

  void syncWithAudioPosition(Duration position) {
// Tìm line tương ứng với vị trí audio
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

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}
// ==================== TEXT SEGMENTS ====================

final List<TextSegment> _segments = [];
List<TextSegment> get segments => List.unmodifiable(_segments);

// Full text cho edit mode
String _fullText = '';
String get fullText => _fullText;

// Selected text with offsets
SelectedTextInfo? _selectedTextInfo;
SelectedTextInfo? get selectedTextInfo => _selectedTextInfo;

// ==================== FULL TEXT MANAGEMENT ====================

/// Load text và lưu fullText
void loadText(String content, {String? title}) {
  _fullText = content;
  final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();

  int currentOffset = 0;
  _lines = [];

  for (int i = 0; i < lines.length; i++) {
    final lineContent = lines[i].trim();
    _lines.add(TextItem(
      id: 'line_$i',
      content: lineContent,
      startTime: null,
      endTime: null,
    ));
    currentOffset += lineContent.length + 1; // +1 for newline
  }

  _currentDocument = TextDocument(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    title: title ?? 'Untitled',
    lines: _lines,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  _currentLineIndex = -1;
  _selectedTextInfo = null;
  notifyListeners();
}

/// Cập nhật toàn bộ văn bản (Edit mode)
void updateFullText(String newText) {
  _fullText = newText;

  // Tách thành lines
  final lines = newText.split('\n').where((l) => l.trim().isNotEmpty).toList();

  _lines = lines.asMap().entries.map((entry) {
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
  // Hoặc có thể implement logic điều chỉnh offset
  _segments.clear();
  _selectedTextInfo = null;

  notifyListeners();
}

// ==================== TEXT SELECTION ====================

/// Chọn text với offset (cho việc tạo segment)
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

/// Tính offset trong fullText từ line index và selection
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
      (difficulty == TextSegmentDifficulty.hard ? 5
          : difficulty == TextSegmentDifficulty.medium ? 3 : 1);

  // Tính ttsSpeed theo độ khó nếu không override
  final speed = ttsSpeedOverride ??
      (difficulty == TextSegmentDifficulty.hard ? 0.7
          : difficulty == TextSegmentDifficulty.medium ? 0.85 : 1.0);

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

/// Xóa segment
void deleteSegment(String id) {
  _segments.removeWhere((s) => s.id == id);
  notifyListeners();
}

/// Cập nhật segment
void updateSegment(TextSegment updated) {
  final index = _segments.indexWhere((s) => s.id == updated.id);
  if (index >= 0) {
    _segments[index] = updated;
    notifyListeners();
  }
}

/// Lấy segments theo độ khó
List<TextSegment> getSegmentsByDifficulty(TextSegmentDifficulty difficulty) {
  return _segments.where((s) => s.difficulty == difficulty).toList();
}

/// Lấy segments cần ôn tập (SRS)
List<TextSegment> getSegmentsForReview() {
  return _segments.where((s) => s.needsReview).toList();
}

/// Lấy segments theo type
List<TextSegment> getSegmentsByType(TextSegmentType type) {
  return _segments.where((s) => s.type == type).toList();
}

// ==================== TTS FOR SEGMENTS ====================

bool _isPlayingSegment = false;
bool get isPlayingSegment => _isPlayingSegment;

TextSegment? _currentPlayingSegment;
TextSegment? get currentPlayingSegment => _currentPlayingSegment;

int _currentRepeatIndex = 0;
int get currentRepeatIndex => _currentRepeatIndex;

/// Phát TTS cho một segment với số lần lặp
Future<void> speakSegment(TextSegment segment) async {
  _isPlayingSegment = true;
  _currentPlayingSegment = segment;
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

    // Khoảng nghỉ giữa các lần lặp
    if (i < segment.repeatCount - 1) {
      await Future.delayed(Duration(
        milliseconds: segment.difficulty == TextSegmentDifficulty.hard
            ? 1500 : 800,
      ));
    }
  }

  // Khôi phục tốc độ gốc
  await setTtsSpeed(originalSpeed);

  // Cập nhật thống kê
  final updated = segment.copyWith(
    lastPracticed: DateTime.now(),
    practiceCount: segment.practiceCount + 1,
    masteryLevel: _calculateNewMastery(segment),
  );
  updateSegment(updated);

  _isPlayingSegment = false;
  _currentPlayingSegment = null;
  _currentRepeatIndex = 0;
  notifyListeners();
}

/// Dừng phát segment
void stopSegmentPlayback() {
  _isPlayingSegment = false;
  _currentPlayingSegment = null;
  stopSpeaking();
  notifyListeners();
}

/// Tính mastery level mới sau khi luyện
double _calculateNewMastery(TextSegment segment) {
  // Tăng mastery mỗi lần luyện, tối đa 1.0
  final increment = 0.1 / (segment.difficulty.index + 1); // Khó hơn = tăng chậm hơn
  return (segment.masteryLevel + increment).clamp(0.0, 1.0);
}

/// Phát tất cả segments cần ôn tập (SRS session)
Future<void> startReviewSession() async {
  final toReview = getSegmentsForReview();
  for (final segment in toReview) {
    if (!_isPlayingSegment) break;
    await speakSegment(segment);
    await Future.delayed(const Duration(seconds: 1));
  }
}

// ==================== STATISTICS ====================

Map<String, dynamic> getSegmentStats() {
  return {
    'total': _segments.length,
    'easy': getSegmentsByDifficulty(TextSegmentDifficulty.easy).length,
    'medium': getSegmentsByDifficulty(TextSegmentDifficulty.medium).length,
    'hard': getSegmentsByDifficulty(TextSegmentDifficulty.hard).length,
    'needsReview': getSegmentsForReview().length,
    'averageMastery': _segments.isEmpty ? 0.0
        : _segments.map((s) => s.masteryLevel).reduce((a, b) => a + b) / _segments.length,
  };
}
}