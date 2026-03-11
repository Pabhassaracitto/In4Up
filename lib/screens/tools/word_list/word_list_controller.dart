//
// ★ FIX: Dùng MemoryProvider.controller (singleton) thay vì
//   inject MemoryController qua constructor → không cần Provider lookup

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../features/tts/tts_service.dart';
import '../../memory_mode/memory_provider.dart'; // ★ dùng singleton
import 'word_list_models.dart';

class WordListController extends ChangeNotifier {
  // ── Dependencies ──────────────────────────────────────────
  // Dùng MemoryProvider.controller (singleton tĩnh) → không cần context
  final _tts = TtsService();

  // ── Data ──────────────────────────────────────────────────
  final List<WordEntry> _manualEntries = [];
  String _currentFolderId = WordFolder.allWords.id;
  WordListSortMode _sortMode = WordListSortMode.addTime;
  WordListSettings _settings = const WordListSettings();

  // ── Playback state ────────────────────────────────────────
  bool _isPlaying = false;
  int _playingIndex = -1;
  int _playingRepeatCurrent = 0;
  bool _stopRequested = false;

  // ── Selection ─────────────────────────────────────────────
  bool _isSelecting = false;
  final Set<String> _selectedIds = {};

  // ── Search ────────────────────────────────────────────────
  String _searchQuery = '';

  // ── Repeat overrides (cho memory items) ───────────────────
  final Map<String, int> _repeatOverrides = {};

  // ─── Getters ─────────────────────────────────────────────
  WordListSettings get settings => _settings;
  WordListSortMode get sortMode => _sortMode;
  String get currentFolderId => _currentFolderId;
  bool get isPlaying => _isPlaying;
  int get playingIndex => _playingIndex;
  int get playingRepeatCurrent => _playingRepeatCurrent;
  bool get isSelecting => _isSelecting;
  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);
  String get searchQuery => _searchQuery;

  // ── Lấy từ MemoryProvider singleton ──────────────────────
  List<WordEntry> get _allEntries {
    final fromMemory = MemoryProvider.controller.allItems
        .map(WordEntry.fromMemoryItem)
        .toList();
    return [...fromMemory, ..._manualEntries];
  }

  int get totalCount => _allEntries.length;

  // ── displayEntries — filter + sort ───────────────────────
  List<WordEntry> get displayEntries {
    var items = _currentFolderId == WordFolder.allWords.id
        ? _allEntries
        : _manualEntries;

    // Search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items
          .where((e) =>
              e.word.toLowerCase().contains(q) ||
              (e.shortDefinition?.toLowerCase().contains(q) ?? false) ||
              (e.phonetic?.toLowerCase().contains(q) ?? false))
          .toList();
    }

    // Sort
    final result = List<WordEntry>.from(items);
    switch (_sortMode) {
      case WordListSortMode.addTime:
        result.sort((a, b) => b.addedAt.compareTo(a.addedAt));
        break;
      case WordListSortMode.alphabetical:
        result.sort(
            (a, b) => a.word.toLowerCase().compareTo(b.word.toLowerCase()));
        break;
      case WordListSortMode.alphabeticalDesc:
        result.sort(
            (a, b) => b.word.toLowerCase().compareTo(a.word.toLowerCase()));
        break;
      case WordListSortMode.rankDescending:
        result.sort((a, b) => b.strength.compareTo(a.strength));
        break;
      case WordListSortMode.familiarity:
        result.sort((a, b) => a.strength.compareTo(b.strength));
        break;
      case WordListSortMode.random:
        result.shuffle();
        break;
    }
    return result;
  }

  // ── Settings ─────────────────────────────────────────────
  void updateSettings(WordListSettings s) {
    _settings = s;
    notifyListeners();
  }

  void toggleExpandAll() {
    _settings =
        _settings.copyWith(definitionsExpanded: !_settings.definitionsExpanded);
    notifyListeners();
  }

  void toggleShowDefinitions() {
    final anyVisible =
        _settings.showShortDefinition || _settings.showFullDefinition;
    _settings = _settings.copyWith(
      showShortDefinition: !anyVisible,
      showFullDefinition: false,
    );
    notifyListeners();
  }

  // ── Sort ──────────────────────────────────────────────────
  void setSortMode(WordListSortMode mode) {
    _sortMode = mode;
    notifyListeners();
  }

  // ── Folder ────────────────────────────────────────────────
  void setFolder(String folderId) {
    _currentFolderId = folderId;
    notifyListeners();
  }

  // ── Search ────────────────────────────────────────────────
  void setSearch(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  // ── Repeat ────────────────────────────────────────────────
  void setRepeatCount(String entryId, int count) {
    _repeatOverrides[entryId] = count;
    notifyListeners();
  }

  int getRepeatCount(String entryId) => _repeatOverrides[entryId] ?? 1;

  // ── Selection ─────────────────────────────────────────────
  void toggleSelecting() {
    _isSelecting = !_isSelecting;
    if (!_isSelecting) _selectedIds.clear();
    notifyListeners();
  }

  void toggleSelect(String id) {
    _selectedIds.contains(id)
        ? _selectedIds.remove(id)
        : _selectedIds.add(id);
    notifyListeners();
  }

  void selectAll() {
    _selectedIds.addAll(displayEntries.map((e) => e.id));
    notifyListeners();
  }

  void clearSelection() {
    _selectedIds.clear();
    notifyListeners();
  }

  // ── Manual add/remove ─────────────────────────────────────
  void addManualEntry(WordEntry entry) {
    _manualEntries.insert(0, entry);
    notifyListeners();
  }

  void removeManualEntry(String id) {
    _manualEntries.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  // ── TTS Playback ─────────────────────────────────────────

  Future<void> playSingle(WordEntry entry) async {
    HapticFeedback.lightImpact();
    final repeat = getRepeatCount(entry.id);
    for (int i = 0; i < repeat; i++) {
      if (_stopRequested) break;
      await _tts.speak(entry.word);
      if (i < repeat - 1) {
        await Future.delayed(const Duration(milliseconds: 600));
      }
    }
  }

  Future<void> playAll({bool selectedOnly = false}) async {
    if (_isPlaying) {
      await stopPlayback();
      return;
    }

    HapticFeedback.mediumImpact();
    _stopRequested = false;
    _isPlaying = true;
    notifyListeners();

    final items = selectedOnly && _selectedIds.isNotEmpty
        ? displayEntries.where((e) => _selectedIds.contains(e.id)).toList()
        : displayEntries;

    for (int i = 0; i < items.length; i++) {
      if (_stopRequested) break;

      _playingIndex = i;
      notifyListeners();

      final entry = items[i];
      final repeat = getRepeatCount(entry.id);

      for (int r = 0; r < repeat; r++) {
        if (_stopRequested) break;
        _playingRepeatCurrent = r + 1;
        notifyListeners();
        await _tts.speak(entry.word);
        if (r < repeat - 1) {
          await Future.delayed(const Duration(milliseconds: 700));
        }
      }

      if (!_stopRequested && i < items.length - 1) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    _isPlaying = false;
    _playingIndex = -1;
    _playingRepeatCurrent = 0;
    _stopRequested = false;
    notifyListeners();
  }

  Future<void> stopPlayback() async {
    _stopRequested = true;
    await _tts.stop();
    _isPlaying = false;
    _playingIndex = -1;
    _playingRepeatCurrent = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    stopPlayback();
    super.dispose();
  }
}
