// lib/screens/tools/word_list/word_list_controller.dart
//
// ★ FIX: stopPlayback() kiểm tra _disposed trước khi notifyListeners()
//        để tránh "used after disposed" error khi Navigator.pop() trong
//        khi đang phát hoặc vừa chọn số lần lặp.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../features/tts/tts_service.dart';
import '../../memory_mode/memory_provider.dart';
import 'word_list_models.dart';

class WordListController extends ChangeNotifier {
  // ── Dependencies ──────────────────────────────────────────
  final _tts = TtsService();

  // ── Disposed guard ────────────────────────────────────────
  bool _disposed = false;

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

  // ── Repeat overrides ─────────────────────────────────────
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

  // ── Safe notify — không gọi nếu đã dispose ───────────────
  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

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

    return items;
  }

  // ── Repeat count ─────────────────────────────────────────
  int getRepeatCount(String id) => _repeatOverrides[id] ?? 1;

  void setRepeatCount(String id, int count) {
    _repeatOverrides[id] = count.clamp(0, 999); // 0 = infinite
    _safeNotify();
  }

  // ── Settings ─────────────────────────────────────────────
  void updateSettings(WordListSettings s) {
    _settings = s;
    _safeNotify();
  }

  void toggleShowDefinitions() {
    _settings = _settings.copyWith(
      showShortDefinition: !_settings.showShortDefinition,
    );
    _safeNotify();
  }

  void toggleExpandAll() {
    _settings = _settings.copyWith(
      definitionsExpanded: !_settings.definitionsExpanded,
    );
    _safeNotify();
  }

  // ── Sort & Folder ─────────────────────────────────────────
  void setSortMode(WordListSortMode mode) {
    _sortMode = mode;
    _safeNotify();
  }

  void setFolder(String folderId) {
    _currentFolderId = folderId;
    _safeNotify();
  }

  void setSearch(String query) {
    _searchQuery = query;
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

  // ── Manual add/remove ─────────────────────────────────────
  void addManualEntry(WordEntry entry) {
    _manualEntries.insert(0, entry);
    _safeNotify();
  }

  void removeManualEntry(String id) {
    _manualEntries.removeWhere((e) => e.id == id);
    _safeNotify();
  }

  // ── TTS Playback ─────────────────────────────────────────

  Future<void> playSingle(WordEntry entry) async {
    if (_disposed) return;
    HapticFeedback.lightImpact();
    final repeat = getRepeatCount(entry.id);

    // repeat == 0 → chơi 3 lần cho single (tránh vô hạn với nút đơn lẻ)
    final times = repeat == 0 ? 3 : repeat;

    for (int i = 0; i < times; i++) {
      if (_stopRequested || _disposed) break;
      await _tts.speak(entry.word);
      if (i < times - 1) {
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
    _safeNotify();

    final items = selectedOnly && _selectedIds.isNotEmpty
        ? displayEntries.where((e) => _selectedIds.contains(e.id)).toList()
        : displayEntries;

    for (int i = 0; i < items.length; i++) {
      if (_stopRequested || _disposed) break;

      _playingIndex = i;
      _safeNotify();

      final entry = items[i];
      final repeat = getRepeatCount(entry.id);

      if (repeat == 0) {
        // Vô hạn — tiếp tục cho đến khi stopRequested
        int r = 0;
        while (!_stopRequested && !_disposed) {
          _playingRepeatCurrent = r + 1;
          _safeNotify();
          await _tts.speak(entry.word);
          if (!_stopRequested && !_disposed) {
            await Future.delayed(const Duration(milliseconds: 700));
          }
          r++;
        }
      } else {
        for (int r = 0; r < repeat; r++) {
          if (_stopRequested || _disposed) break;
          _playingRepeatCurrent = r + 1;
          _safeNotify();
          await _tts.speak(entry.word);
          if (r < repeat - 1 && !_stopRequested && !_disposed) {
            await Future.delayed(const Duration(milliseconds: 700));
          }
        }
      }

      if (!_stopRequested && !_disposed && i < items.length - 1) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    if (!_disposed) {
      _isPlaying = false;
      _playingIndex = -1;
      _playingRepeatCurrent = 0;
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
    // ★ KEY FIX: chỉ notify nếu chưa disposed
    _safeNotify();
  }

  @override
  void dispose() {
    _disposed = true;
    // stop TTS nhưng KHÔNG gọi notifyListeners nữa
    _stopRequested = true;
    _tts.stop();
    super.dispose();
  }
}
