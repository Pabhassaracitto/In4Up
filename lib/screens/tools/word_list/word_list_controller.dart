//
// ★ MỚI: sort modes SM-2, khó→dễ, dễ→khó
// ★ MỚI: moveWordToFolder (drag & drop giữa folders)
// ★ MỚI: hasWord() helper cho import
// ★ MỚI: exportFolder() → CSV string
// ★ FIX dispose crash

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../features/tts/tts_service.dart';
import '../../memory_mode/memory_provider.dart';
import 'word_list_models.dart';

class WordListController extends ChangeNotifier {
  final _tts = TtsService();
  bool _disposed = false;

  // ── Data ──────────────────────────────────────────────────
  final List<WordEntry> _manualEntries = [];
  String _currentFolderId = WordFolder.allWords.id;
  WordListSortMode _sortMode = WordListSortMode.addTime;
  WordListSettings _settings = const WordListSettings();
  final Map<String, int> _repeatOverrides = {};

  // ── List-level repeat ─────────────────────────────────────
  int _listRepeatCount = 1;
  int _listRepeatCurrent = 0;

  // ── Playback state ────────────────────────────────────────
  bool _isPlaying = false;
  int _playingIndex = -1;
  int _playingRepeatCurrent = 0;
  bool _stopRequested = false;

  // ── Selection ─────────────────────────────────────────────
  bool _isSelecting = false;
  final Set<String> _selectedIds = {};
  String _searchQuery = '';

  // ─── Getters ─────────────────────────────────────────────
  WordListSettings get settings => _settings;
  WordListSortMode get sortMode => _sortMode;
  String get currentFolderId => _currentFolderId;
  bool get isPlaying => _isPlaying;
  int get playingIndex => _playingIndex;
  int get playingRepeatCurrent => _playingRepeatCurrent;
  int get listRepeatCount => _listRepeatCount;
  int get listRepeatCurrent => _listRepeatCurrent;
  bool get isSelecting => _isSelecting;
  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);
  String get searchQuery => _searchQuery;

  String get listRepeatLabel {
    if (_listRepeatCount == 0) return '∞';
    return '$_listRepeatCount×';
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  // ── Data ──────────────────────────────────────────────────
  List<WordEntry> get _allEntries {
    final fromMemory = MemoryProvider.controller.allItems
        .map(WordEntry.fromMemoryItem)
        .toList();
    return [...fromMemory, ..._manualEntries];
  }

  int get totalCount => _allEntries.length;

  // ★ MỚI: Kiểm tra từ đã tồn tại (cho import)
  bool hasWord(String word) {
    final normalized = word.toLowerCase().trim();
    return _allEntries.any((e) => e.word.toLowerCase() == normalized);
  }

  List<WordEntry> get displayEntries {
    var items = _currentFolderId == WordFolder.allWords.id
        ? _allEntries
        : _manualEntries.where((e) => e.folderId == _currentFolderId).toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items
          .where((e) =>
              e.word.toLowerCase().contains(q) ||
              (e.shortDefinition?.toLowerCase().contains(q) ?? false) ||
              (e.phonetic?.toLowerCase().contains(q) ?? false))
          .toList();
    }

    final result = List<WordEntry>.from(items);
    _applySortMode(result);
    return result;
  }

  void _applySortMode(List<WordEntry> list) {
    switch (_sortMode) {
      case WordListSortMode.addTime:
        list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      case WordListSortMode.alphabetical:
        list.sort(
            (a, b) => a.word.toLowerCase().compareTo(b.word.toLowerCase()));
      case WordListSortMode.alphabeticalDesc:
        list.sort(
            (a, b) => b.word.toLowerCase().compareTo(a.word.toLowerCase()));
      case WordListSortMode.rankDescending:
        list.sort((a, b) => b.strength.compareTo(a.strength));
      case WordListSortMode.familiarity:
        list.sort((a, b) => a.strength.compareTo(b.strength));
      case WordListSortMode.random:
        list.shuffle();
      case WordListSortMode.sm2Due:
        list.sort((a, b) {
          if (a.isSm2Due && !b.isSm2Due) return -1;
          if (!a.isSm2Due && b.isSm2Due) return 1;
          return b.addedAt.compareTo(a.addedAt);
        });
      case WordListSortMode.hardFirst:
        list.sort((a, b) => a.strength.compareTo(b.strength));
      case WordListSortMode.easyFirst:
        list.sort((a, b) => b.strength.compareTo(a.strength));
    }
  }

  // ── Per-word repeat ───────────────────────────────────────
  int getRepeatCount(String id) => (_repeatOverrides[id] ?? 1).clamp(1, 999);

  void setRepeatCount(String id, int count) {
    _repeatOverrides[id] = count.clamp(1, 999);
    _safeNotify();
  }

  // ── List repeat ───────────────────────────────────────────
  void setListRepeatCount(int count) {
    _listRepeatCount = count < 0 ? 0 : count;
    _safeNotify();
  }

  // ── Settings ─────────────────────────────────────────────
  void updateSettings(WordListSettings s) {
    _settings = s;
    _safeNotify();
  }

  void toggleShowDefinitions() {
    final any = _settings.showShortDefinition || _settings.showFullDefinition;
    _settings = _settings.copyWith(
        showShortDefinition: !any, showFullDefinition: false);
    _safeNotify();
  }

  void toggleExpandAll() {
    _settings =
        _settings.copyWith(definitionsExpanded: !_settings.definitionsExpanded);
    _safeNotify();
  }

  void setSortMode(WordListSortMode mode) {
    _sortMode = mode;
    _safeNotify();
  }

  void setFolder(String folderId) {
    _currentFolderId = folderId;
    _safeNotify();
  }

  void setSearch(String q) {
    _searchQuery = q;
    _safeNotify();
  }

  // ── Selection ─────────────────────────────────────────────
  void toggleSelecting() {
    _isSelecting = !_isSelecting;
    if (!_isSelecting) _selectedIds.clear();
    _safeNotify();
  }

  void toggleSelect(String id) {
    _selectedIds.contains(id) ? _selectedIds.remove(id) : _selectedIds.add(id);
    _safeNotify();
  }

  void selectAll() {
    _selectedIds.addAll(displayEntries.map((e) => e.id));
    _safeNotify();
  }

  void clearSelection() {
    _selectedIds.clear();
    _safeNotify();
  }

  // ── Manual entries ────────────────────────────────────────
  void addManualEntry(WordEntry entry) {
    _manualEntries.insert(0, entry);
    _safeNotify();
  }

  void removeManualEntry(String id) {
    _manualEntries.removeWhere((e) => e.id == id);
    _safeNotify();
  }

  // ★ MỚI: Move word sang folder khác (dùng cho drag & drop)
  void moveWordToFolder(String wordId, String targetFolderId) {
    final idx = _manualEntries.indexWhere((e) => e.id == wordId);
    if (idx == -1) return; // Memory words không thể move

    _manualEntries[idx] = _manualEntries[idx].copyWith(
      folderId: targetFolderId == WordFolder.allWords.id
          ? WordFolder.defaultFolder.id
          : targetFolderId,
    );
    _safeNotify();
  }

  // ★ MỚI: Move nhiều words cùng lúc (từ selection)
  void moveSelectedToFolder(String targetFolderId) {
    if (_selectedIds.isEmpty) return;
    final fid = targetFolderId == WordFolder.allWords.id
        ? WordFolder.defaultFolder.id
        : targetFolderId;

    for (final id in _selectedIds) {
      final idx = _manualEntries.indexWhere((e) => e.id == id);
      if (idx >= 0) {
        _manualEntries[idx] = _manualEntries[idx].copyWith(folderId: fid);
      }
    }
    clearSelection();
    _safeNotify();
  }

  // ★ MỚI: Export folder → CSV string
  String exportFolderAsCsv(String folderId) {
    final words = folderId == WordFolder.allWords.id
        ? _manualEntries
        : _manualEntries.where((e) => e.folderId == folderId).toList();

    final buffer = StringBuffer();
    buffer.writeln('word,meaning,phonetic,example');
    for (final w in words) {
      final meaning = (w.shortDefinition ?? '').replaceAll(',', ';');
      final phonetic = (w.phonetic ?? '').replaceAll(',', ';');
      final example = (w.example ?? '').replaceAll(',', ';');
      buffer.writeln('${w.word},$meaning,$phonetic,$example');
    }
    return buffer.toString();
  }

  // ★ MỚI: Count SM-2 due words
  int get sm2DueCount => _allEntries.where((e) => e.isSm2Due).length;

  // ── TTS ───────────────────────────────────────────────────
  Future<void> playSingle(WordEntry entry) async {
    if (_disposed) return;
    HapticFeedback.lightImpact();
    final repeat = getRepeatCount(entry.id);
    for (int i = 0; i < repeat; i++) {
      if (_stopRequested || _disposed) break;
      await _tts.speak(entry.word);
      if (i < repeat - 1 && !_stopRequested && !_disposed) {
        await Future.delayed(const Duration(milliseconds: 600));
      }
    }
  }

  Future<void> playAll({bool selectedOnly = false}) async {
    if (_disposed) return;
    if (_isPlaying) {
      await stopPlayback();
      return;
    }

    HapticFeedback.mediumImpact();
    _stopRequested = false;
    _isPlaying = true;
    _listRepeatCurrent = 0;
    _safeNotify();

    final items = selectedOnly && _selectedIds.isNotEmpty
        ? displayEntries.where((e) => _selectedIds.contains(e.id)).toList()
        : displayEntries;

    if (items.isEmpty) {
      _isPlaying = false;
      _safeNotify();
      return;
    }

    int listPass = 0;
    while (!_stopRequested && !_disposed) {
      listPass++;
      _listRepeatCurrent = listPass;
      _safeNotify();

      for (int i = 0; i < items.length; i++) {
        if (_stopRequested || _disposed) break;

        _playingIndex = i;
        _safeNotify();

        final entry = items[i];
        final repeat = getRepeatCount(entry.id);

        for (int r = 0; r < repeat; r++) {
          if (_stopRequested || _disposed) break;
          _playingRepeatCurrent = r + 1;
          _safeNotify();
          await _tts.speak(entry.word);
          if (r < repeat - 1 && !_stopRequested && !_disposed) {
            await Future.delayed(const Duration(milliseconds: 700));
          }
        }

        if (!_stopRequested && !_disposed && i < items.length - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      if (_stopRequested || _disposed) break;
      if (_listRepeatCount != 0 && listPass >= _listRepeatCount) break;
      if (!_stopRequested && !_disposed) {
        await Future.delayed(const Duration(milliseconds: 1200));
      }
    }

    if (!_disposed) {
      _isPlaying = false;
      _playingIndex = -1;
      _playingRepeatCurrent = 0;
      _listRepeatCurrent = 0;
      _stopRequested = false;
      _safeNotify();
    }
  }

  Future<void> stopPlayback() async {
    _stopRequested = true;
    await _tts.stop();
    _isPlaying = false;
    _playingIndex = -1;
    _playingRepeatCurrent = 0;
    _listRepeatCurrent = 0;
    _safeNotify();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopRequested = true;
    _tts.stop();
    super.dispose();
  }
}
