// lib/screens/understand_mode/understand_provider.dart

import 'package:flutter/material.dart';
import 'models/understand_line.dart';
import 'services/understand_service.dart';

class UnderstandProvider extends ChangeNotifier {
  List<UnderstandLine> _understandLines = [];
  int _currentLineIndex = -1;
  bool _isUnderstanding = false;
  double _comprehensionScore = 0.0;
  final Map<int, DateTime> _lastReviewed = {};
  final Map<int, int> _reviewCounts = {};

  List<UnderstandLine> get understandLines => _understandLines;
  int get currentLineIndex => _currentLineIndex;
  bool get isUnderstanding => _isUnderstanding;
  double get comprehensionScore => _comprehensionScore;

  double get overallProgress => _understandLines.isEmpty
      ? 0
      : UnderstandService.calculateComprehension(_understandLines);

  void setUnderstandLines(List<UnderstandLine> lines) {
    _understandLines = lines;
    notifyListeners();
  }

  void setCurrentLine(int index) {
    if (index != _currentLineIndex &&
        index >= 0 &&
        index < _understandLines.length) {
      _currentLineIndex = index;
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
        _understandLines, _currentLineIndex);
  }
}
