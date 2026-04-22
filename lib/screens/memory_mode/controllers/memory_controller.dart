// lib/screens/memory_mode/controllers/memory_controller.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/memory_item.dart';
import '../models/memory_stage.dart';
import '../models/memory_stats.dart';
import '../models/review_session.dart';
import '../services/memory_storage_service.dart';

class MemoryController extends ChangeNotifier {
  // ==================== DATA ====================
  final List<MemoryItem> _allItems = [];
  List<MemoryItem> get allItems => List.unmodifiable(_allItems);

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  // ==================== SESSION STATE ====================
  ReviewSession? _currentSession;
  ReviewSession? get currentSession => _currentSession;

  List<MemoryItem> _reviewQueue = [];
  List<MemoryItem> get reviewQueue => List.unmodifiable(_reviewQueue);

  int _currentCardIndex = -1;
  int get currentCardIndex => _currentCardIndex;

  MemoryItem? get currentCard =>
      _currentCardIndex >= 0 && _currentCardIndex < _reviewQueue.length
          ? _reviewQueue[_currentCardIndex]
          : null;

  bool _isCardFlipped = false;
  bool get isCardFlipped => _isCardFlipped;

  bool _isReviewing = false;
  bool get isReviewing => _isReviewing;

  // ==================== VIEW STATE ====================
  MemoryViewMode _viewMode = MemoryViewMode.garden;
  MemoryViewMode get viewMode => _viewMode;

  MemoryStage? _filterStage;
  MemoryStage? get filterStage => _filterStage;

  MemorySortMode _sortMode = MemorySortMode.urgency;
  MemorySortMode get sortMode => _sortMode;

  // ==================== STATS ====================
  int _reviewedTodayCount = 0;
  int _correctTodayCount = 0;

  // ==================== STORAGE ====================
  final MemoryStorageService _storage = MemoryStorageService.instance;

  // ==================== COMPUTED ====================

  List<MemoryItem> get dueItems =>
      _allItems.where((item) => item.needsReview).toList()
        ..sort((a, b) => b.urgencyScore.compareTo(a.urgencyScore));

  List<MemoryItem> get filteredItems {
    var items = _filterStage != null
        ? _allItems.where((i) => i.stage == _filterStage).toList()
        : List<MemoryItem>.from(_allItems);

    switch (_sortMode) {
      case MemorySortMode.urgency:
        items.sort((a, b) => b.urgencyScore.compareTo(a.urgencyScore));
        break;
      case MemorySortMode.alphabetical:
        items.sort(
            (a, b) => a.word.toLowerCase().compareTo(b.word.toLowerCase()));
        break;
      case MemorySortMode.stage:
        items.sort((a, b) => a.stage.index.compareTo(b.stage.index));
        break;
      case MemorySortMode.newest:
        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case MemorySortMode.accuracy:
        items.sort((a, b) => a.accuracy.compareTo(b.accuracy));
        break;
    }
    return items;
  }

  MemoryStats get stats {
    final distribution = <MemoryStage, int>{};
    for (final stage in MemoryStage.values) {
      distribution[stage] = _allItems.where((i) => i.stage == stage).length;
    }

    return MemoryStats(
      totalItems: _allItems.length,
      stageDistribution: distribution,
      dueToday: dueItems.length,
      reviewedToday: _reviewedTodayCount,
      correctToday: _correctTodayCount,
      averageAccuracy: _allItems.isEmpty
          ? 0.0
          : _allItems.map((i) => i.accuracy).reduce((a, b) => a + b) /
              _allItems.length,
    );
  }

  // ==================== INIT ====================

  MemoryController() {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final items = await _storage.loadItems();
      _allItems.clear();
      _allItems.addAll(items);

      final todayStats = await _storage.loadTodayStats();
      _reviewedTodayCount = todayStats['reviewed'] ?? 0;
      _correctTodayCount = todayStats['correct'] ?? 0;

      _isLoaded = true;
      debugPrint('🧠 Controller loaded: ${_allItems.length} items');
      notifyListeners();
    } catch (e) {
      debugPrint('🧠 Load error: $e');
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    try {
      await _storage.saveItems(_allItems);
      await _storage.saveTodayStats(_reviewedTodayCount, _correctTodayCount);
    } catch (e) {
      debugPrint('🧠 Persist error: $e');
    }
  }

  // ==================== ⭐ THÊM TỪ - PHẦN QUAN TRỌNG NHẤT ⭐ ====================

  /// Thêm 1 từ vào vườn nhớ
  /// Trả về true nếu thêm thành công, false nếu đã tồn tại
  bool addWord({
    required String word,
    String? meaning,
    String? phonetic,
    String? example,
    String? context,
    String? audioPath,
    Duration? audioStart,
    Duration? audioEnd,
    String? wordType,
    String? cefrLevel,
    String? sourceFile,
    int? sourceLine,
    List<String> tags = const [],
  }) {
    // Kiểm tra trùng (case-insensitive)
    final wordLower = word.trim().toLowerCase();
    if (wordLower.isEmpty) return false;

    if (_allItems.any((i) => i.word.trim().toLowerCase() == wordLower)) {
      debugPrint('🧠 Word "$word" already exists, skipping');
      return false;
    }

    final item = MemoryItem(
      id: '${DateTime.now().millisecondsSinceEpoch}_${word.hashCode}',
      word: word.trim(),
      meaning: meaning?.trim(),
      phonetic: phonetic?.trim(),
      example: example?.trim(),
      context: context?.trim(),
      audioPath: audioPath,
      audioStart: audioStart,
      audioEnd: audioEnd,
      createdAt: DateTime.now(),
      nextReviewAt: DateTime.now(), // Cần ôn ngay
      wordType: wordType,
      cefrLevel: cefrLevel,
      sourceFile: sourceFile,
      sourceLine: sourceLine,
      tags: tags,
    );

    _allItems.add(item);
    _persist(); // Lưu xuống storage
    notifyListeners();

    debugPrint('🧠 ✅ Added word: "$word" → total: ${_allItems.length}');
    return true;
  }

  /// Import hàng loạt từ danh sách Map
  int importWords(List<Map<String, dynamic>> words) {
    int added = 0;
    for (final w in words) {
      final word = w['word'] as String? ?? '';
      if (word.isEmpty) continue;

      final success = addWord(
        word: word,
        meaning: w['meaning'] as String?,
        phonetic: w['phonetic'] as String?,
        example: w['example'] as String?,
        context: w['context'] as String?,
        wordType: w['wordType'] as String?,
        cefrLevel: w['cefrLevel'] as String?,
        sourceFile: w['sourceFile'] as String?,
      );
      if (success) added++;
    }
    debugPrint('🧠 Imported $added/${words.length} words');
    return added;
  }

  void removeItem(String id) {
    _allItems.removeWhere((i) => i.id == id);
    _persist();
    notifyListeners();
  }

  // ==================== REVIEW SESSION ====================

  void startReview({ReviewMode mode = ReviewMode.spaced, int? maxCards}) {
    List<MemoryItem> queue;

    switch (mode) {
      case ReviewMode.spaced:
        queue = dueItems;
        break;
      case ReviewMode.cram:
        queue = List.from(_allItems)..shuffle();
        break;
      case ReviewMode.difficult:
        queue = _allItems
            .where((i) =>
                i.stage == MemoryStage.seed ||
                i.stage == MemoryStage.sprout ||
                i.accuracy < 0.6)
            .toList()
          ..sort((a, b) => b.urgencyScore.compareTo(a.urgencyScore));
        break;
      case ReviewMode.stage:
        queue = filteredItems.where((i) => i.needsReview).toList();
        break;
      case ReviewMode.random:
        queue = List.from(_allItems)..shuffle();
        break;
    }

    if (maxCards != null && queue.length > maxCards) {
      queue = queue.sublist(0, maxCards);
    }

    if (queue.isEmpty) {
      debugPrint('🧠 No cards to review');
      return;
    }

    _reviewQueue = queue;
    _currentCardIndex = 0;
    _isCardFlipped = false;
    _isReviewing = true;

    _currentSession = ReviewSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startedAt: DateTime.now(),
      mode: mode,
    );

    HapticFeedback.mediumImpact();
    notifyListeners();
  }

  void flipCard() {
    _isCardFlipped = !_isCardFlipped;
    HapticFeedback.lightImpact();
    notifyListeners();
  }

  Future<void> gradeCurrentCard(ReviewGrade grade) async {
    final item = currentCard!;
    MemoryItem updated;

    switch (grade) {
      case ReviewGrade.forgot:
        updated = item.markIncorrect();
        break;
      case ReviewGrade.hard:
        updated = item.markHard();
        _correctTodayCount++;
        break;
      case ReviewGrade.good:
      case ReviewGrade.easy:
        updated = item.markCorrect();
        _correctTodayCount++;
        break;
      case ReviewGrade.retired: // ← THÊM
        updated = item.markRetired();
        _correctTodayCount++;
        break;
      case ReviewGrade.snoozed: // ← THÊM
        updated = item.markSnoozed();
        // Không tính vào correctToday
        break;
    }

    final idx = _allItems.indexWhere((i) => i.id == item.id);
    if (idx >= 0) _allItems[idx] = updated;
    _reviewedTodayCount++;

    // Haptic theo grade
    switch (grade) {
      case ReviewGrade.forgot:
        HapticFeedback.heavyImpact();
        break;
      case ReviewGrade.hard:
        HapticFeedback.mediumImpact();
        break;
      case ReviewGrade.good:
      case ReviewGrade.easy:
        HapticFeedback.lightImpact();
        break;
      case ReviewGrade.retired: // ← THÊM: double tap rung
        HapticFeedback.mediumImpact();
        await Future.delayed(const Duration(milliseconds: 100));
        HapticFeedback.lightImpact();
        break;
      case ReviewGrade.snoozed: // ← THÊM: rung nhẹ 1 lần
        HapticFeedback.selectionClick();
        break;
    }

    _moveToNextCard();
    _persist();
  }

  void _moveToNextCard() {
    _isCardFlipped = false;

    if (_currentCardIndex >= _reviewQueue.length - 1) {
      _completeSession();
    } else {
      _currentCardIndex++;
    }
    notifyListeners();
  }

  void _completeSession() {
    _isReviewing = false;
    _currentCardIndex = -1;
    _reviewQueue = [];
    _persist();
    notifyListeners();
  }

  void exitReview() {
    _isReviewing = false;
    _currentCardIndex = -1;
    _isCardFlipped = false;
    _reviewQueue = [];
    _persist();
    notifyListeners();
  }

  // ==================== VIEW CONTROL ====================

  void setViewMode(MemoryViewMode mode) {
    _viewMode = mode;
    notifyListeners();
  }

  void setFilterStage(MemoryStage? stage) {
    _filterStage = stage;
    notifyListeners();
  }

  void setSortMode(MemorySortMode mode) {
    _sortMode = mode;
    notifyListeners();
  }

  // ==================== DEBUG ====================

  /// Debug: thêm từ test
  void addTestWords() {
    final testWords = [
      {'word': 'hello', 'meaning': 'xin chào'},
      {'word': 'world', 'meaning': 'thế giới'},
      {'word': 'beautiful', 'meaning': 'đẹp'},
      {'word': 'knowledge', 'meaning': 'kiến thức'},
      {'word': 'remember', 'meaning': 'nhớ'},
      {'word': 'practice', 'meaning': 'thực hành'},
      {'word': 'language', 'meaning': 'ngôn ngữ'},
      {'word': 'science', 'meaning': 'khoa học'},
    ];
    importWords(testWords);
  }

  @override
  void dispose() {
    _persist();
    super.dispose();
  }
}

enum MemoryViewMode { garden, list, flashcard }

enum MemorySortMode { urgency, alphabetical, stage, newest, accuracy }
