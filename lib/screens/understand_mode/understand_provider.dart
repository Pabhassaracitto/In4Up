// lib/screens/understand_mode/understand_provider.dart

import 'package:flutter/material.dart';
import 'package:in2up_stt/stt_lrc_converter.dart';
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
      // Clamp để tránh duration quá ngắn/dài
      if (lineDuration.inMilliseconds < 800) {
        lineDuration = const Duration(milliseconds: 800);
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
    _lrcLines = lines.where((l) => l.text.isNotEmpty).toList();
    _currentLineIndex = -1;
    notifyListeners();
  }

  void updatePosition(Duration position) {
    if (_lrcLines.isEmpty) return;

    int newIndex = -1;
    for (int i = 0; i < _lrcLines.length; i++) {
      if (_lrcLines[i].timestamp <= position) {
        newIndex = i;
      } else {
        break;
      }
    }

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
