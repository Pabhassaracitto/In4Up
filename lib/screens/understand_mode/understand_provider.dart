// lib/screens/understand_mode/understand_provider.dart

import 'package:flutter/material.dart';
import 'package:in4up_stt/stt_lrc_converter.dart';

import '../../features/understand_ai/understand_ai_context.dart';
import 'models/understand_line.dart';
import 'services/understand_service.dart';

class UnderstandProvider extends ChangeNotifier {
  List<UnderstandLine> _understandLines = [];
  int _currentUnderstandLineIndex = -1;
  bool _isUnderstanding = false;
  double _comprehensionScore = 0.0;
  final Map<int, DateTime> _lastReviewed = {};
  final Map<int, int> _reviewCounts = {};

  List<LrcLine> _lrcLines = [];
  List<LrcLine> get lrcLines => _lrcLines;
  int _currentLineIndex = -1;
  int get currentLineIndex => _currentLineIndex;

  // Keep the latest player clock even before LRC exists. Transcription can
  // finish while paused, without a later playback tick to select the line.
  Duration _lastPosition = Duration.zero;

  // Mode luyện tập hiện tại (Đồng bộ / Shadowing) — UnderstandModeScreen đồng
  // bộ theo TabController. AI Coach chỉ ĐỌC giá trị này để gắn vào context;
  // đóng sheet/chat không bao giờ reset nó.
  UnderstandLearningMode _learningMode = UnderstandLearningMode.sync;
  UnderstandLearningMode get learningMode => _learningMode;

  void setLearningMode(UnderstandLearningMode mode) {
    if (mode == _learningMode) return;
    _learningMode = mode;
    notifyListeners();
  }

  // Karaoke word-level tracking
  int _currentWordIndex = -1;
  int get currentWordIndex => _currentWordIndex;

  /// Trả về danh sách từ (có timestamp) của dòng đang phát.
  /// Nếu LRC không có inline timestamp → ước lượng đều theo số từ
  /// và dựa trên khoảng thời gian tới dòng tiếp theo để karaoke nhảy chính xác hơn.
  List<LrcWord> wordsForLine(int index) {
    if (index < 0 || index >= _lrcLines.length) return const [];
    final line = _lrcLines[index];
    if (line.words.isNotEmpty) return line.words;

    // Tính duration của dòng = timestamp dòng sau - timestamp dòng hiện tại
    // Nếu là dòng cuối, giả định 4 giây
    Duration lineDuration = const Duration(seconds: 4);
    if (index + 1 < _lrcLines.length) {
      lineDuration = _lrcLines[index + 1].timestamp - line.timestamp;
      // Never estimate words beyond the next line's real start. Equal
      // timestamps can occur in imported LRC; keep their duration at zero.
      if (lineDuration.isNegative) {
        lineDuration = Duration.zero;
      } else if (lineDuration.inMilliseconds > 8000) {
        lineDuration = const Duration(seconds: 8);
      }
    }

    // Chia đều duration cho số từ để karaoke nhảy đều hơn (thay vì cố định 350ms)
    return LrcWord.estimateFromWithDuration(line.text, line.timestamp, lineDuration);
  }

  List<UnderstandLine> get understandLines => _understandLines;
  int get currentUnderstandLineIndex => _currentUnderstandLineIndex;
  bool get isUnderstanding => _isUnderstanding;
  double get comprehensionScore => _comprehensionScore;

  double get overallProgress => _understandLines.isEmpty
      ? 0
      : UnderstandService.calculateComprehension(_understandLines);

  // ★ TASK 5: Clear toàn bộ state khi đổi bài — tránh hiển thị lyrics bài cũ
  void clear() {
    _lrcLines = [];
    _currentLineIndex = -1;
    _currentWordIndex = -1;
    _understandLines = [];
    _currentUnderstandLineIndex = -1;
    _isUnderstanding = false;
    _comprehensionScore = 0.0;
    _lastReviewed.clear();
    _reviewCounts.clear();
    notifyListeners();
  }

  void setUnderstandLines(List<UnderstandLine> lines) {
    _understandLines = lines;
    notifyListeners();
  }

  void loadLrcLines(List<LrcLine> lines) {
    // Imported LRC and partial AI results are not guaranteed to be sorted.
    // Preserve the input order for equal timestamps, without changing the file.
    final indexed = lines.asMap().entries
        .where((entry) => entry.value.text.trim().isNotEmpty)
        .toList();
    indexed.sort((a, b) {
      final time = a.value.timestamp.compareTo(b.value.timestamp);
      return time == 0 ? a.key.compareTo(b.key) : time;
    });
    _lrcLines = indexed.map((entry) => entry.value).toList();
    _currentLineIndex = _lineIndexAt(_lastPosition);
    _currentWordIndex = _computeWordIndex(_lastPosition);
    notifyListeners();
  }

  // Last line whose start is at or before the player clock. This also handles
  // seeks backwards and long transcripts without scanning every line per tick.
  int _lineIndexAt(Duration position) {
    var low = 0;
    var high = _lrcLines.length;
    while (low < high) {
      final mid = low + (high - low) ~/ 2;
      if (_lrcLines[mid].timestamp <= position) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low - 1;
  }

  void updatePosition(Duration position) {
    _lastPosition = position;
    if (_lrcLines.isEmpty) return;

    final newIndex = _lineIndexAt(position);
    final lineChanged = newIndex != _currentLineIndex;
    if (lineChanged) {
      _currentLineIndex = newIndex;
    }

    // Cập nhật word-level karaoke cho dòng đang phát
    final newWordIndex = _computeWordIndex(position);
    final wordChanged = newWordIndex != _currentWordIndex;

    if (lineChanged || wordChanged) {
      _currentWordIndex = newWordIndex;
      notifyListeners();
    }
  }

  int _computeWordIndex(Duration position) {
    if (_currentLineIndex < 0 || _currentLineIndex >= _lrcLines.length) {
      return -1;
    }
    final words = wordsForLine(_currentLineIndex);
    if (words.isEmpty) return -1;

    var active = -1;
    for (int i = 0; i < words.length; i++) {
      if (words[i].start <= position) {
        active = i;
      } else {
        break;
      }
    }
    return active;
  }

  void setCurrentLine(int index) {
    if (index != _currentUnderstandLineIndex &&
        index >= 0 &&
        index < _understandLines.length) {
      _currentUnderstandLineIndex = index;
      notifyListeners();
    }
  }

  void markAsDifficult(int index) {
    if (index < 0 || index >= _understandLines.length) return;

    _understandLines[index] = _understandLines[index].copyWith(
      isDifficult: true,
    );

    notifyListeners();
  }

  void updateComprehensionScore(int index, double score) {
    if (index < 0 || index >= _understandLines.length) return;

    _understandLines[index] = _understandLines[index].copyWith(
      comprehensionScore: score,
    );

    _lastReviewed[index] = DateTime.now();
    _reviewCounts[index] = (_reviewCounts[index] ?? 0) + 1;

    // Update overall comprehension score
    _comprehensionScore =
        UnderstandService.calculateComprehension(_understandLines);

    notifyListeners();
  }

  void addNote(int index, String note) {
    if (index < 0 || index >= _understandLines.length) return;

    final currentNotes = List<String>.from(_understandLines[index].notes);
    currentNotes.add(note);

    _understandLines[index] = _understandLines[index].copyWith(
      notes: currentNotes,
    );

    notifyListeners();
  }

  void startUnderstanding() {
    _isUnderstanding = true;
    notifyListeners();
  }

  void stopUnderstanding() {
    _isUnderstanding = false;
    notifyListeners();
  }

  List<int> getLinesForReview() {
    final reviewIndices = <int>[];

    for (int i = 0; i < _understandLines.length; i++) {
      if (UnderstandService.needsReview(_understandLines[i])) {
        reviewIndices.add(i);
      }
    }

    return reviewIndices;
  }

  List<int> getSuggestedLines() {
    return UnderstandService.suggestNextLines(
        _understandLines, _currentUnderstandLineIndex);
  }
}
