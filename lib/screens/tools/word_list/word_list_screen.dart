// ═══════════════════════════════════════════════════════════════
// WORD LIST SCREEN — v4 Complete Merge
// Old: TTS, sort, selection, YouGlish, folders, import, settings
// New: Hierarchy, type filter, contexts, relationships, decompose
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../models/word_entry.dart';
import '../../../models/vocabulary_type.dart';
import '../../../providers/vocabulary_provider.dart';
import '../../../services/vocab_classifier.dart';
import '../../../features/tts/tts_service.dart';

import 'loop_count_picker.dart';
import 'word_list_models.dart' hide WordEntry;
import 'youglish_mini_sheet.dart';

// ══════════════════════════════════════════════════════════
// MAIN SCREEN
// ══════════════════════════════════════════════════════════
class WordListScreen extends StatefulWidget {
  const WordListScreen({super.key});
  @override
  State<WordListScreen> createState() => _WordListScreenState();
}

class _WordListScreenState extends State<WordListScreen> {
  // ── Services ──
  final _tts = TtsService();

  // ── UI state ──
  final _searchCtrl = TextEditingController();
  bool _showSearch = false;
  String? _expandedId;
  VocabularyType? _typeFilter;
  WordListSortMode _sortMode = WordListSortMode.addTime;
  WordListSettings _settings = const WordListSettings();

  // ── Playback state ──
  bool _isPlaying = false;
  int _playingIndex = -1;
  int _playingRepeatCurrent = 0;
  bool _stopRequested = false;
  int _listRepeatCount = 1;
  int _listRepeatCurrent = 0;
  final Map<String, int> _repeatOverrides = {};

  // ── Selection state ──
  bool _isSelecting = false;
  final Set<String> _selectedIds = {};

  @override
  void dispose() {
    _stopRequested = true;
    _tts.stop();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Sorted + filtered display list ──
  List<WordEntry> _getDisplayList(VocabularyProvider p) {
    final list = List<WordEntry>.from(p.displayedWords);
    _applySortMode(list);
    return list;
  }

  void _applySortMode(List<WordEntry> list) {
    switch (_sortMode) {
      case WordListSortMode.addTime:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case WordListSortMode.alphabetical:
        list.sort(
            (a, b) => a.word.toLowerCase().compareTo(b.word.toLowerCase()));
      case WordListSortMode.alphabeticalDesc:
        list.sort(
            (a, b) => b.word.toLowerCase().compareTo(a.word.toLowerCase()));
      case WordListSortMode.rankDescending:
      case WordListSortMode.easyFirst:
        list.sort((a, b) => b.mastery.compareTo(a.mastery));
      case WordListSortMode.familiarity:
      case WordListSortMode.hardFirst:
        list.sort((a, b) => a.mastery.compareTo(b.mastery));
      case WordListSortMode.random:
        list.shuffle();
      case WordListSortMode.sm2Due:
        list.sort((a, b) {
          if (a.isDue && !b.isDue) return -1;
          if (!a.isDue && b.isDue) return 1;
          return b.createdAt.compareTo(a.createdAt);
        });
    }
  }

  int _getRepeatCount(String id) => (_repeatOverrides[id] ?? 1).clamp(1, 999);

  @override
  Widget build(BuildContext context) {
    return Consumer<VocabularyProvider>(
      builder: (_, provider, __) {
        final items = _getDisplayList(provider);
        return Scaffold(
          backgroundColor: const Color(0xFF080B1A),
          body: SafeArea(
            child: Column(
              children: [
                _buildAppBar(provider),
                _buildTypeFilterBar(provider),
                _buildSubBar(provider, items),
                Expanded(child: _buildCompactList(provider, items)),
                _buildPlayBar(items),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: const Color(0xFF6C63FF),
            onPressed: () => _showAddSheet(provider),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  // APP BAR
  // ═══════════════════════════════════════════════════════
  Widget _buildAppBar(VocabularyProvider p) {
    final sm2Due = p.dueCount;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1520),
        border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 18),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 4),
          if (!_showSearch) ...[
            Expanded(
              child: Row(
                children: [
                  const Text('Wordlist',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  _CountBadge(count: p.total, color: const Color(0xFF6C63FF)),
                  if (sm2Due > 0) ...[
                    const SizedBox(width: 8),
                    _CountBadge(
                      count: sm2Due,
                      color: const Color(0xFFFF5722),
                      icon: Icons.alarm,
                      label: 'ôn',
                      onTap: () =>
                          setState(() => _sortMode = WordListSortMode.sm2Due),
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            Expanded(
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Tìm từ, cụm từ, câu...',
                    hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                    prefixIcon:
                        Icon(Icons.search, color: Colors.grey[600], size: 16),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                  onChanged: p.setSearch,
                ),
              ),
            ),
          ],
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search,
                color: Colors.grey[400], size: 20),
            onPressed: () {
              setState(() => _showSearch = !_showSearch);
              if (!_showSearch) {
                _searchCtrl.clear();
                p.clearSearch();
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.view_sidebar_outlined,
                color: Colors.grey[400], size: 20),
            onPressed: () => _showSmartGroupsSheet(p),
          ),
          _buildOverflowMenu(p),
        ],
      ),
    );
  }

  Widget _buildOverflowMenu(VocabularyProvider p) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: Colors.grey[400], size: 20),
      color: const Color(0xFF1A2235),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (val) {
        switch (val) {
          case 'select':
            setState(() {
              _isSelecting = !_isSelecting;
              if (!_isSelecting) _selectedIds.clear();
            });
          case 'expand':
            setState(() => _settings = _settings.copyWith(
                definitionsExpanded: !_settings.definitionsExpanded));
          case 'toggle_def':
            final any =
                _settings.showShortDefinition || _settings.showFullDefinition;
            setState(() => _settings = _settings.copyWith(
                showShortDefinition: !any, showFullDefinition: false));
          case 'settings':
            _showSettingsSheet();
        }
      },
      itemBuilder: (_) => [
        _menuItem('select', Icons.checklist, 'Chọn'),
        _menuItem('expand', Icons.unfold_more, 'Mở rộng tất cả'),
        const PopupMenuDivider(height: 1),
        _menuItem(
            'toggle_def',
            _settings.showShortDefinition
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            _settings.showShortDefinition ? 'Ẩn nghĩa' : 'Hiện nghĩa'),
        const PopupMenuDivider(height: 1),
        _menuItem('settings', Icons.tune, 'Options'),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(String v, IconData icon, String label) =>
      PopupMenuItem(
          value: v,
          child: Row(children: [
            Icon(icon, size: 16, color: Colors.grey[400]),
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ]));

  // ═══════════════════════════════════════════════════════
  // TYPE FILTER BAR
  // ═══════════════════════════════════════════════════════
  Widget _buildTypeFilterBar(VocabularyProvider p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1A),
        border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _TypeChip(
                label: 'Tất cả',
                count: p.total,
                color: const Color(0xFF9E9E9E),
                isSelected: _typeFilter == null,
                onTap: () => setState(() {
                      _typeFilter = null;
                      p.setFilterType(null);
                    })),
            const SizedBox(width: 6),
            ...VocabularyType.values.map((type) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _TypeChip(
                    label: type.label,
                    count: p.wordsByType[type]?.length ?? 0,
                    color: type.color,
                    isSelected: _typeFilter == type,
                    onTap: () => setState(() {
                      _typeFilter = _typeFilter == type ? null : type;
                      p.setFilterType(_typeFilter);
                    }),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // SUB BAR (Sort + Play All + Repeat)
  // ═══════════════════════════════════════════════════════
  Widget _buildSubBar(VocabularyProvider p, List<WordEntry> items) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1A),
        border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04))),
      ),
      child: Row(
        children: [
          // Sort
          _DropdownChip(
            icon: _sortMode.icon,
            label: _sortMode.label,
            color: _sortMode == WordListSortMode.sm2Due
                ? const Color(0xFFFF5722)
                : _sortMode == WordListSortMode.hardFirst
                    ? const Color(0xFFEF5350)
                    : const Color(0xFF6C63FF),
            onTap: () => _showSortSheet(),
          ),
          const Spacer(),
          // List repeat
          _ListRepeatButton(
            count: _listRepeatCount,
            current: _listRepeatCurrent,
            onTap: () => showModalBottomSheet(
              context: context,
              backgroundColor: const Color(0xFF0D1520),
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20))),
              builder: (_) => LoopCountPickerSheet(
                current: _listRepeatCount,
                allowInfinite: true,
                onChanged: (v) {
                  setState(() => _listRepeatCount = v);
                  Navigator.pop(context);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Play All
          _PlayAllButton(
            isPlaying: _isPlaying,
            onTap: () => _isPlaying ? _stopPlayback() : _playAll(items),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // COMPACT LIST
  // ═══════════════════════════════════════════════════════
  Widget _buildCompactList(VocabularyProvider p, List<WordEntry> items) {
    if (items.isEmpty) return _buildEmptyState(p);

    return Column(
      children: [
        // Selection action bar
        if (_isSelecting && _selectedIds.isNotEmpty) _buildSelectionBar(),
        // Stats strip
        _buildStatsStrip(p),
        // List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final entry = items[i];
              final isPlaying = _isPlaying && _playingIndex == i;
              final isSelected = _selectedIds.contains(entry.id);
              final isExpanded =
                  _expandedId == entry.id || _settings.definitionsExpanded;

              return _CompactListItem(
                entry: entry,
                index: i,
                isExpanded: isExpanded,
                isPlaying: isPlaying,
                isSelected: isSelected,
                isSelecting: _isSelecting,
                settings: _settings,
                provider: p,
                tts: _tts,
                repeatCount: _getRepeatCount(entry.id),
                playingRepeat: isPlaying ? _playingRepeatCurrent : 0,
                onTap: _isSelecting
                    ? () => setState(() {
                          _selectedIds.contains(entry.id)
                              ? _selectedIds.remove(entry.id)
                              : _selectedIds.add(entry.id);
                        })
                    : () => setState(() {
                          _expandedId =
                              _expandedId == entry.id ? null : entry.id;
                        }),
                onLongPress: () {
                  HapticFeedback.mediumImpact();
                  if (!_isSelecting) setState(() => _isSelecting = true);
                  setState(() => _selectedIds.add(entry.id));
                },
                onRepeatChanged: (v) =>
                    setState(() => _repeatOverrides[entry.id] = v),
                onEdit: () => _showEditSheet(entry, p),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatsStrip(VocabularyProvider p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: p.progress,
                minHeight: 3,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF6C63FF)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('${(p.progress * 100).toInt()}%',
              style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSelectionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF1A1A2E),
      child: Row(
        children: [
          Text('${_selectedIds.length} đã chọn',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
          const Spacer(),
          TextButton(
            onPressed: () => setState(() {
              _selectedIds.addAll(
                  _getDisplayList(context.read<VocabularyProvider>())
                      .map((e) => e.id));
            }),
            child: const Text('Tất cả',
                style: TextStyle(color: Color(0xFF6C63FF), fontSize: 12)),
          ),
          TextButton(
            onPressed: () => setState(() {
              _isSelecting = false;
              _selectedIds.clear();
            }),
            child: const Text('Xong',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(VocabularyProvider p) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.library_books_outlined, size: 52, color: Colors.grey[800]),
          const SizedBox(height: 16),
          Text('Chưa có từ vựng',
              style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Bôi đen từ khi đọc hoặc thêm thủ công',
              style: TextStyle(color: Colors.grey[700], fontSize: 12)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // PLAY BAR
  // ═══════════════════════════════════════════════════════
  Widget _buildPlayBar(List<WordEntry> items) {
    if (!_isPlaying && !(_isSelecting && _selectedIds.isNotEmpty))
      return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1520),
        border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child:
          _isPlaying ? _buildPlayingBar(items) : _buildSelectingPlayBar(items),
    );
  }

  Widget _buildPlayingBar(List<WordEntry> items) {
    final current = _playingIndex >= 0 && _playingIndex < items.length
        ? items[_playingIndex]
        : null;
    final listInfo = _listRepeatCount == 0
        ? 'Vòng $_listRepeatCurrent/∞'
        : _listRepeatCount > 1
            ? 'Vòng $_listRepeatCurrent/$_listRepeatCount'
            : '';
    return Row(
      children: [
        Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.volume_up,
                color: Color(0xFF9C8FFF), size: 18)),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
              Text(current?.word ?? '...',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              Text(
                  '${_playingIndex + 1}/${items.length}'
                  '${_playingRepeatCurrent > 1 ? ' · lần $_playingRepeatCurrent' : ''}'
                  '${listInfo.isNotEmpty ? '  $listInfo' : ''}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 11)),
            ])),
        GestureDetector(
          onTap: _stopPlayback,
          child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.stop, color: Colors.red, size: 18)),
        ),
      ],
    );
  }

  Widget _buildSelectingPlayBar(List<WordEntry> items) {
    return Row(
      children: [
        Text('${_selectedIds.length} đã chọn',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
        const Spacer(),
        GestureDetector(
          onTap: () {
            final selected =
                items.where((e) => _selectedIds.contains(e.id)).toList();
            if (selected.isNotEmpty) _playAll(selected);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF9C27B0)]),
                borderRadius: BorderRadius.circular(10)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.play_arrow, color: Colors.white, size: 16),
              SizedBox(width: 4),
              Text('Phát',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            ]),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // TTS PLAYBACK
  // ═══════════════════════════════════════════════════════
  Future<void> _playSingle(WordEntry entry) async {
    HapticFeedback.lightImpact();
    final repeat = _getRepeatCount(entry.id);
    for (int i = 0; i < repeat; i++) {
      if (_stopRequested || !mounted) break;
      await _tts.speak(entry.word);
      if (i < repeat - 1 && !_stopRequested && mounted) {
        await Future.delayed(const Duration(milliseconds: 600));
      }
    }
  }

  Future<void> _playAll(List<WordEntry> items) async {
    if (_isPlaying) {
      _stopPlayback();
      return;
    }
    if (items.isEmpty) return;
    HapticFeedback.mediumImpact();
    _stopRequested = false;
    setState(() {
      _isPlaying = true;
      _listRepeatCurrent = 0;
    });

    int listPass = 0;
    while (!_stopRequested && mounted) {
      listPass++;
      setState(() => _listRepeatCurrent = listPass);

      for (int i = 0; i < items.length; i++) {
        if (_stopRequested || !mounted) break;
        setState(() => _playingIndex = i);
        final entry = items[i];
        final repeat = _getRepeatCount(entry.id);
        for (int r = 0; r < repeat; r++) {
          if (_stopRequested || !mounted) break;
          setState(() => _playingRepeatCurrent = r + 1);
          await _tts.speak(entry.word);
          if (r < repeat - 1 && !_stopRequested && mounted) {
            await Future.delayed(const Duration(milliseconds: 700));
          }
        }
        if (!_stopRequested && mounted && i < items.length - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      if (_stopRequested || !mounted) break;
      if (_listRepeatCount != 0 && listPass >= _listRepeatCount) break;
      if (!_stopRequested && mounted)
        await Future.delayed(const Duration(milliseconds: 1200));
    }

    if (mounted)
      setState(() {
        _isPlaying = false;
        _playingIndex = -1;
        _playingRepeatCurrent = 0;
        _listRepeatCurrent = 0;
        _stopRequested = false;
      });
  }

  void _stopPlayback() {
    _stopRequested = true;
    _tts.stop();
    if (mounted)
      setState(() {
        _isPlaying = false;
        _playingIndex = -1;
        _playingRepeatCurrent = 0;
        _listRepeatCurrent = 0;
      });
  }

  // ═══════════════════════════════════════════════════════
  // SHEETS & DIALOGS
  // ═══════════════════════════════════════════════════════

  void _showSmartGroupsSheet(VocabularyProvider p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1520),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SmartGroupsSheet(provider: p),
    );
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1520),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _SortSheet(
        current: _sortMode,
        onSelected: (mode) {
          setState(() => _sortMode = mode);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1520),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SettingsSheet(
        settings: _settings,
        onChanged: (s) => setState(() => _settings = s),
      ),
    );
  }

  void _showAddSheet(VocabularyProvider p) {
    final textCtrl = TextEditingController();
    final meaningCtrl = TextEditingController();
    VocabularyType? detectedType;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A2235),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (_, setS) {
          final pad = MediaQuery.of(sheetCtx).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + pad),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.add_circle,
                        color: Color(0xFF42A5F5), size: 20),
                    const SizedBox(width: 10),
                    const Text('Thêm từ vựng',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    if (detectedType != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: detectedType!.bgColor,
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(detectedType!.label,
                            style: TextStyle(
                                color: detectedType!.color,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                  ]),
                  const SizedBox(height: 16),
                  TextField(
                    controller: textCtrl,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: _inputDeco('Từ / Cụm từ / Câu *',
                        'VD: breakthrough', const Color(0xFF42A5F5)),
                    onChanged: (t) => setS(() => detectedType =
                        t.trim().isEmpty ? null : VocabClassifier.classify(t)),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                      controller: meaningCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: _inputDeco('Nghĩa *', 'VD: bước đột phá',
                          const Color(0xFFFFB300))),
                  const SizedBox(height: 16),
                  SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final text = textCtrl.text.trim(),
                              meaning = meaningCtrl.text.trim();
                          if (text.isEmpty || meaning.isEmpty) return;
                          final entry = p.addWithAutoClassify(
                              text: text, meaning: meaning);
                          Navigator.pop(sheetCtx);
                          if (entry.vocabType != VocabularyType.word)
                            _showDecomposeDialog(entry, p);
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF42A5F5),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        child: const Text('Lưu',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      )),
                ]),
          );
        },
      ),
    );
  }

  InputDecoration _inputDeco(String label, String hint, Color color) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
        labelStyle: TextStyle(color: color, fontSize: 12),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: color, width: 1.5)),
      );

  void _showDecomposeDialog(WordEntry parent, VocabularyProvider p) {
    final result = p.autoDecompose(parent.word, parent.vocabType);
    if (result.isEmpty) return;
    final selWords = <String>{};
    final selPhrases = <String>{};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A2235),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (_, setS) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.auto_awesome, color: Color(0xFFFFB300), size: 20),
                  SizedBox(width: 10),
                  Text('Gợi ý tách thành phần',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 6),
                Text('Chọn từ/cụm muốn lưu riêng từ "${parent.word}"',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                const SizedBox(height: 16),
                if (result.words.isNotEmpty) ...[
                  Text('Từ đơn:',
                      style: TextStyle(
                          color: VocabularyType.word.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: result.words.map((w) {
                        final sel = selWords.contains(w);
                        final exists = p.hasWord(w);
                        return _DecomposeChip(
                            word: w,
                            selected: sel,
                            exists: exists,
                            color: VocabularyType.word.color,
                            onTap: exists
                                ? null
                                : () => setS(() {
                                      sel
                                          ? selWords.remove(w)
                                          : selWords.add(w);
                                    }));
                      }).toList()),
                  const SizedBox(height: 12),
                ],
                if (result.phrases.isNotEmpty) ...[
                  Text('Cụm từ:',
                      style: TextStyle(
                          color: VocabularyType.phrase.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: result.phrases.take(8).map((ph) {
                        final sel = selPhrases.contains(ph);
                        final exists = p.hasWord(ph);
                        return _DecomposeChip(
                            word: ph,
                            selected: sel,
                            exists: exists,
                            color: VocabularyType.phrase.color,
                            onTap: exists
                                ? null
                                : () => setS(() {
                                      sel
                                          ? selPhrases.remove(ph)
                                          : selPhrases.add(ph);
                                    }));
                      }).toList()),
                  const SizedBox(height: 16),
                ],
                Row(children: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Bỏ qua',
                          style: TextStyle(color: Colors.grey[500]))),
                  const Spacer(),
                  if (selWords.isNotEmpty || selPhrases.isNotEmpty)
                    ElevatedButton(
                      onPressed: () {
                        p.saveDecomposeResults(
                            parentId: parent.id,
                            selectedWords: selWords.toList(),
                            selectedPhrases: selPhrases.toList(),
                            meanings: {});
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                                '✅ Đã tạo ${selWords.length + selPhrases.length} entry con'),
                            backgroundColor: const Color(0xFF4CAF50),
                            behavior: SnackBarBehavior.floating));
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF)),
                      child: Text(
                          'Lưu ${selWords.length + selPhrases.length} mục'),
                    ),
                ]),
              ]),
        ),
      ),
    );
  }

  void _showEditSheet(WordEntry entry, VocabularyProvider p) {
    final wordC = TextEditingController(text: entry.word);
    final meanC = TextEditingController(text: entry.meaning);
    final noteC = TextEditingController(text: entry.personalNotes ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A2235),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final pad = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + pad),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              const Icon(Icons.edit, color: Color(0xFF42A5F5), size: 20),
              const SizedBox(width: 10),
              const Text('Sửa chi tiết',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Color(0xFFEF5350), size: 20),
                  onPressed: () {
                    p.removeWord(entry.id);
                    Navigator.pop(ctx);
                  }),
            ]),
            const SizedBox(height: 16),
            _editField(wordC, 'Từ', Icons.text_fields),
            const SizedBox(height: 10),
            _editField(meanC, 'Nghĩa', Icons.translate),
            const SizedBox(height: 10),
            _editField(noteC, 'Ghi chú', Icons.note_alt_outlined, maxLines: 3),
            const SizedBox(height: 16),
            SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    p.updateWord(entry.id,
                        word: wordC.text.trim(), meaning: meanC.text.trim());
                    if (noteC.text.trim().isNotEmpty)
                      p.updateNotes(entry.id, noteC.text.trim());
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF42A5F5),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: const Text('Lưu',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                )),
          ]),
        );
      },
    );
  }

  Widget _editField(TextEditingController c, String label, IconData icon,
          {int maxLines = 1}) =>
      TextField(
        controller: c,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
            prefixIcon: Icon(icon, color: Colors.grey[500], size: 16),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none)),
      );
}

// ══════════════════════════════════════════════════════════
// COMPACT LIST ITEM
// ══════════════════════════════════════════════════════════
class _CompactListItem extends StatelessWidget {
  final WordEntry entry;
  final int index;
  final bool isExpanded, isPlaying, isSelected, isSelecting;
  final WordListSettings settings;
  final VocabularyProvider provider;
  final TtsService tts;
  final int repeatCount, playingRepeat;
  final VoidCallback onTap, onLongPress, onEdit;
  final ValueChanged<int> onRepeatChanged;

  const _CompactListItem({
    required this.entry,
    required this.index,
    required this.isExpanded,
    required this.isPlaying,
    required this.isSelected,
    required this.isSelecting,
    required this.settings,
    required this.provider,
    required this.tts,
    required this.repeatCount,
    required this.playingRepeat,
    required this.onTap,
    required this.onLongPress,
    required this.onRepeatChanged,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final typeColor = entry.vocabType.color;
    final isDue = entry.isDue;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isPlaying
              ? const Color(0xFF6C63FF).withValues(alpha: 0.12)
              : isSelected
                  ? const Color(0xFF2196F3).withValues(alpha: 0.10)
                  : isExpanded
                      ? const Color(0xFF111827)
                      : isDue
                          ? const Color(0xFFFF5722).withValues(alpha: 0.04)
                          : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isPlaying
                ? const Color(0xFF6C63FF).withValues(alpha: 0.4)
                : isSelected
                    ? const Color(0xFF2196F3).withValues(alpha: 0.35)
                    : isExpanded
                        ? typeColor.withValues(alpha: 0.3)
                        : isDue
                            ? const Color(0xFFFF5722).withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.06),
            width: isPlaying ? 1.5 : 1,
          ),
        ),
        child: Column(children: [
          // ── Collapsed Row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
            child: Row(children: [
              // Selection checkbox or type badge
              if (isSelecting)
                Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF2196F3)
                                : Colors.transparent,
                            border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF2196F3)
                                    : Colors.grey),
                            borderRadius: BorderRadius.circular(6)),
                        child: isSelected
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 13)
                            : null))
              else ...[
                Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6)),
                    alignment: Alignment.center,
                    child: Text(entry.vocabType.badge,
                        style: TextStyle(
                            color: typeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800))),
                const SizedBox(width: 10),
              ],

              // Word + meaning
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      if (settings.showWord)
                        Flexible(
                            child: Text(entry.word,
                                style: TextStyle(
                                    color: isPlaying
                                        ? const Color(0xFF9C8FFF)
                                        : Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis)),
                      if (settings.showPhonetic && entry.phonetic != null) ...[
                        const SizedBox(width: 6),
                        Text(entry.phonetic!,
                            style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 10,
                                fontStyle: FontStyle.italic)),
                      ],
                    ]),
                    if (settings.showShortDefinition)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(children: [
                          Expanded(
                              child: Text(entry.meaning,
                                  style: TextStyle(
                                      color: Colors.grey[400], fontSize: 12),
                                  maxLines: isExpanded ? null : 1,
                                  overflow: isExpanded
                                      ? null
                                      : TextOverflow.ellipsis)),
                          const SizedBox(width: 8),
                          SizedBox(
                              width: 40,
                              child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                      value: entry.mastery,
                                      minHeight: 3,
                                      backgroundColor:
                                          Colors.white.withValues(alpha: 0.06),
                                      valueColor: AlwaysStoppedAnimation(entry
                                          .zone.color
                                          .withValues(alpha: 0.7))))),
                          const SizedBox(width: 3),
                          Text('${(entry.mastery * 100).toInt()}%',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 9)),
                        ]),
                      ),
                  ])),

              // Encounter badge
              if (entry.encounterCount > 1)
                Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4)),
                    child: Text('📌${entry.encounterCount}',
                        style: const TextStyle(fontSize: 9))),

              // Per-word repeat
              _PerWordRepeatBtn(
                  count: repeatCount,
                  isPlaying: isPlaying,
                  currentRepeat: playingRepeat,
                  onChanged: onRepeatChanged),
              const SizedBox(width: 2),

              // YouGlish
              GestureDetector(
                onTap: () => YouGlishMiniSheet.show(context, entry.word),
                child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                        color: const Color(0xFF00BCD4).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(7)),
                    child: const Icon(Icons.record_voice_over,
                        size: 13, color: Color(0xFF00BCD4))),
              ),
              const SizedBox(width: 2),

              // TTS
              GestureDetector(
                onTap: () => tts.speak(entry.word),
                child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                        color: isPlaying
                            ? const Color(0xFF6C63FF).withValues(alpha: 0.25)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(7)),
                    child: Icon(Icons.volume_up_outlined,
                        size: 13,
                        color: isPlaying
                            ? const Color(0xFF9C8FFF)
                            : Colors.grey[500])),
              ),

              // Expand indicator
              Icon(isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 16, color: Colors.grey[700]),
            ]),
          ),

          // ── Expanded Detail ──
          if (isExpanded) _buildExpanded(context),
        ]),
      ),
    );
  }

  Widget _buildExpanded(BuildContext ctx) {
    final children = provider.getChildren(entry.id);
    final parents = provider.getParents(entry.id);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Divider(color: Colors.white.withValues(alpha: 0.06), height: 4),
        const SizedBox(height: 8),

        // Contexts
        if (entry.contexts.isNotEmpty) ...[
          _SectionHeader(
              icon: Icons.menu_book,
              label: 'Ngữ cảnh (${entry.contexts.length})'),
          const SizedBox(height: 6),
          ...entry.contexts.take(3).map((c) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06))),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (c.surroundingText.isNotEmpty)
                        Text('"${c.surroundingText}"',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.grey[300],
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                height: 1.4)),
                      if (c.sourceName != null) ...[
                        const SizedBox(height: 4),
                        Text('${c.sourceIcon} ${c.displaySource}',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 10))
                      ],
                    ]),
              )),
          const SizedBox(height: 8),
        ],

        // Relationships
        if (parents.isNotEmpty || children.isNotEmpty) ...[
          _SectionHeader(icon: Icons.link, label: 'Liên kết'),
          const SizedBox(height: 6),
          if (parents.isNotEmpty) ...[
            Text('Xuất hiện trong:',
                style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            const SizedBox(height: 4),
            Wrap(
                spacing: 6,
                runSpacing: 4,
                children: parents
                    .map((p) => _RelatedChip(entry: p, prefix: '▲'))
                    .toList()),
          ],
          if (children.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Chứa:',
                style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            const SizedBox(height: 4),
            Wrap(
                spacing: 6,
                runSpacing: 4,
                children: children
                    .map((c) => _RelatedChip(entry: c, prefix: '▼'))
                    .toList()),
          ],
          const SizedBox(height: 8),
        ],

        // Notes
        if (entry.personalNotes != null && entry.personalNotes!.isNotEmpty) ...[
          _SectionHeader(icon: Icons.note_alt_outlined, label: 'Ghi chú'),
          const SizedBox(height: 4),
          Text(entry.personalNotes!,
              style: TextStyle(
                  color: Colors.grey[400], fontSize: 12, height: 1.5)),
          const SizedBox(height: 8),
        ],

        // SM-2 Skills
        _SectionHeader(icon: Icons.bar_chart, label: 'Ôn tập'),
        const SizedBox(height: 6),
        Row(children: [
          _SkillBar(
              label: 'Hiểu',
              value: entry.understand,
              color: const Color(0xFF42A5F5)),
          const SizedBox(width: 8),
          _SkillBar(
              label: 'Nghe',
              value: entry.listen,
              color: const Color(0xFF66BB6A)),
          const SizedBox(width: 8),
          _SkillBar(
              label: 'Đọc', value: entry.read, color: const Color(0xFFEF5350)),
        ]),
        if (entry.nextReview != null) ...[
          const SizedBox(height: 4),
          Text(
              entry.isDue
                  ? '⏰ Cần ôn tập!'
                  : '📅 Lần tới: ${entry.daysUntilDue} ngày nữa',
              style: TextStyle(
                  color:
                      entry.isDue ? const Color(0xFFFF5722) : Colors.grey[600],
                  fontSize: 11)),
        ],

        // Actions
        const SizedBox(height: 10),
        Row(children: [
          _ActionBtn(
              icon: Icons.edit_outlined,
              label: 'Sửa',
              color: const Color(0xFF42A5F5),
              onTap: onEdit),
          const SizedBox(width: 8),
          _ActionBtn(
              icon: Icons.play_arrow,
              label: 'Ôn',
              color: const Color(0xFF4CAF50),
              onTap: () {}),
          const Spacer(),
          _ActionBtn(
              icon: Icons.delete_outline,
              label: 'Xóa',
              color: const Color(0xFFEF5350),
              onTap: () => provider.removeWord(entry.id)),
        ]),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
// SMART GROUPS SHEET
// ══════════════════════════════════════════════════════════
class _SmartGroupsSheet extends StatelessWidget {
  final VocabularyProvider provider;
  const _SmartGroupsSheet({required this.provider});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (_, sc) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: ListView(controller: sc, children: [
          Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Smart Groups',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _gSection('📊 Trạng thái', [
            _gItem(Icons.alarm, 'Cần ôn', provider.dueCount,
                const Color(0xFFFF5722), () {}),
            _gItem(Icons.star, 'Thành thạo', provider.masteredCount,
                const Color(0xFFFFD54F), () {}),
            _gItem(
                Icons.repeat,
                'Gặp nhiều lần',
                provider.frequentlyEncountered.length,
                const Color(0xFFFFB300),
                () {}),
            _gItem(Icons.visibility_off, 'Điểm mù', provider.blindSpots,
                const Color(0xFF616161), () {}),
          ]),
          const SizedBox(height: 16),
          _gSection(
              '🏷️ Loại',
              VocabularyType.values
                  .map((t) => _gItem(t.icon, t.label,
                          provider.wordsByType[t]?.length ?? 0, t.color, () {
                        provider.setFilterType(t);
                        Navigator.pop(context);
                      }))
                  .toList()),
          if (provider.allSources.isNotEmpty) ...[
            const SizedBox(height: 16),
            _gSection(
                '📁 Nguồn',
                provider.allSources
                    .take(10)
                    .map((s) => _gItem(
                            _srcIcon(s),
                            s.length > 25 ? '${s.substring(0, 22)}...' : s,
                            provider.wordsBySource[s]?.length ?? 0,
                            const Color(0xFF2196F3), () {
                          provider.setFilterSource(s);
                          Navigator.pop(context);
                        }))
                    .toList()),
          ],
          if (provider.wordsByDate.isNotEmpty) ...[
            const SizedBox(height: 16),
            _gSection(
                '📅 Thời gian',
                provider.wordsByDate.entries
                    .take(7)
                    .map((e) => _gItem(
                        Icons.calendar_today,
                        e.key,
                        e.value.length,
                        const Color(0xFF9C27B0),
                        () => Navigator.pop(context)))
                    .toList()),
          ],
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  IconData _srcIcon(String s) => s.endsWith('.pdf')
      ? Icons.picture_as_pdf
      : s.startsWith('http')
          ? Icons.language
          : Icons.edit_note;

  Widget _gSection(String title, List<Widget> children) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...children
      ]);

  Widget _gItem(IconData icon, String label, int count, Color color,
          VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(label,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 13))),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('$count',
                      style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600))),
            ])),
      );
}

// ══════════════════════════════════════════════════════════
// SORT SHEET
// ══════════════════════════════════════════════════════════
class _SortSheet extends StatelessWidget {
  final WordListSortMode current;
  final ValueChanged<WordListSortMode> onSelected;
  const _SortSheet({required this.current, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('Sắp xếp',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...WordListSortMode.values.map((mode) {
              final sel = current == mode;
              return GestureDetector(
                onTap: () => onSelected(mode),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                      color: sel
                          ? const Color(0xFF6C63FF).withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: sel
                          ? Border.all(
                              color: const Color(0xFF6C63FF)
                                  .withValues(alpha: 0.4))
                          : null),
                  child: Row(children: [
                    Icon(mode.icon,
                        size: 16,
                        color:
                            sel ? const Color(0xFF9C8FFF) : Colors.grey[500]),
                    const SizedBox(width: 12),
                    Text(mode.label,
                        style: TextStyle(
                            color: sel ? Colors.white : Colors.grey[400],
                            fontWeight:
                                sel ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 13)),
                    if (sel) ...[
                      const Spacer(),
                      const Icon(Icons.check,
                          color: Color(0xFF9C8FFF), size: 16)
                    ],
                  ]),
                ),
              );
            }),
          ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
// SETTINGS SHEET
// ══════════════════════════════════════════════════════════
class _SettingsSheet extends StatefulWidget {
  final WordListSettings settings;
  final ValueChanged<WordListSettings> onChanged;
  const _SettingsSheet({required this.settings, required this.onChanged});
  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late WordListSettings _s;
  @override
  void initState() {
    super.initState();
    _s = widget.settings;
  }

  void _update(WordListSettings s) {
    setState(() => _s = s);
    widget.onChanged(s);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('Hiển thị',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _toggle('Từ', Icons.text_fields, _s.showWord,
                (v) => _update(_s.copyWith(showWord: v))),
            _toggle('Phiên âm', Icons.record_voice_over_outlined,
                _s.showPhonetic, (v) => _update(_s.copyWith(showPhonetic: v))),
            _toggle('Số thứ tự', Icons.format_list_numbered, _s.showNumber,
                (v) => _update(_s.copyWith(showNumber: v))),
            const Divider(color: Color(0xFF1E2A3A), height: 20),
            _toggle('Nghĩa ngắn', Icons.short_text, _s.showShortDefinition,
                (v) => _update(_s.copyWith(showShortDefinition: v))),
            _toggle(
                'Nghĩa đầy đủ',
                Icons.article_outlined,
                _s.showFullDefinition,
                (v) => _update(_s.copyWith(showFullDefinition: v))),
            _toggle('Ví dụ', Icons.format_quote_outlined, _s.showExample,
                (v) => _update(_s.copyWith(showExample: v))),
          ]),
    );
  }

  Widget _toggle(
          String label, IconData icon, bool value, ValueChanged<bool> cb) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: const TextStyle(color: Colors.white, fontSize: 13))),
          Switch(
              value: value,
              onChanged: cb,
              activeThumbColor: const Color(0xFF6C63FF),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
        ]),
      );
}

// ══════════════════════════════════════════════════════════
// HELPER WIDGETS
// ══════════════════════════════════════════════════════════

class _CountBadge extends StatelessWidget {
  final int count;
  final Color color;
  final IconData? icon;
  final String? label;
  final VoidCallback? onTap;
  const _CountBadge(
      {required this.count,
      required this.color,
      this.icon,
      this.label,
      this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.3))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[
                Icon(icon, size: 10, color: color),
                const SizedBox(width: 3)
              ],
              Text('$count${label != null ? ' $label' : ''}',
                  style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.w700)),
            ])),
      );
}

class _TypeChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  const _TypeChip(
      {required this.label,
      required this.count,
      required this.color,
      required this.isSelected,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: isSelected
                        ? color
                        : Colors.white.withValues(alpha: 0.1))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(label,
                  style: TextStyle(
                      color: isSelected ? color : Colors.grey[500],
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500)),
              const SizedBox(width: 4),
              Text('$count',
                  style: TextStyle(
                      color: isSelected
                          ? color.withValues(alpha: 0.7)
                          : Colors.grey[700],
                      fontSize: 10)),
            ])),
      );
}

class _DropdownChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _DropdownChip(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.25))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(width: 3),
              Icon(Icons.arrow_drop_down, size: 14, color: color),
            ])),
      );
}

class _PlayAllButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTap;
  const _PlayAllButton({required this.isPlaying, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
                gradient: isPlaying
                    ? const LinearGradient(
                        colors: [Color(0xFFB71C1C), Color(0xFFE53935)])
                    : const LinearGradient(
                        colors: [Color(0xFF4527A0), Color(0xFF6C63FF)]),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                      color: (isPlaying
                              ? const Color(0xFFE53935)
                              : const Color(0xFF6C63FF))
                          .withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ]),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(isPlaying ? Icons.stop : Icons.play_arrow,
                  color: Colors.white, size: 16),
              const SizedBox(width: 5),
              Text(isPlaying ? 'Dừng' : 'Phát tất cả',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ])),
      );
}

class _ListRepeatButton extends StatelessWidget {
  final int count, current;
  final VoidCallback onTap;
  const _ListRepeatButton(
      {required this.count, required this.current, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final label = count == 0 ? '∞' : '$count×';
    return GestureDetector(
      onTap: onTap,
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
              color: count != 1
                  ? const Color(0xFFFFB300).withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: count != 1
                      ? const Color(0xFFFFB300).withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.1))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.repeat,
                size: 13,
                color: count != 1 ? const Color(0xFFFFB300) : Colors.grey[600]),
            const SizedBox(width: 4),
            Text(current > 0 ? '$current/$label' : label,
                style: TextStyle(
                    color:
                        count != 1 ? const Color(0xFFFFB300) : Colors.grey[600],
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ])),
    );
  }
}

class _PerWordRepeatBtn extends StatelessWidget {
  final int count;
  final bool isPlaying;
  final int currentRepeat;
  final ValueChanged<int> onChanged;
  const _PerWordRepeatBtn(
      {required this.count,
      required this.isPlaying,
      required this.currentRepeat,
      required this.onChanged});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => showModalBottomSheet(
          context: context,
          backgroundColor: const Color(0xFF0D1520),
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (ctx) => LoopCountPickerSheet(
              current: count,
              onChanged: (v) {
                onChanged(v.clamp(1, 999));
                Navigator.pop(ctx);
              }),
        ),
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            decoration: BoxDecoration(
                color: count > 1
                    ? const Color(0xFFFFB300).withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                    color: count > 1
                        ? const Color(0xFFFFB300).withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.08))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.repeat,
                  size: 10,
                  color:
                      count > 1 ? const Color(0xFFFFB300) : Colors.grey[600]),
              const SizedBox(width: 2),
              Text(
                  isPlaying && currentRepeat > 0
                      ? '$currentRepeat/$count'
                      : '$count×',
                  style: TextStyle(
                      color: count > 1
                          ? const Color(0xFFFFB300)
                          : Colors.grey[600],
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ])),
      );
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 13, color: Colors.grey[500]),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: Colors.grey[400],
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ]);
}

class _RelatedChip extends StatelessWidget {
  final WordEntry entry;
  final String prefix;
  const _RelatedChip({required this.entry, required this.prefix});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 4, right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: entry.vocabType.bgColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: entry.vocabType.color.withValues(alpha: 0.3))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('$prefix ',
              style: TextStyle(
                  color: entry.vocabType.color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
          Text(entry.word,
              style: TextStyle(
                  color: entry.vocabType.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

class _SkillBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _SkillBar(
      {required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 9)),
          const Spacer(),
          Text('${(value * 100).toInt()}%',
              style: TextStyle(color: Colors.grey[600], fontSize: 9)),
        ]),
        const SizedBox(height: 2),
        ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
                value: value,
                minHeight: 4,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation(color))),
      ]));
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.25))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            ])),
      );
}

class _DecomposeChip extends StatelessWidget {
  final String word;
  final bool selected, exists;
  final Color color;
  final VoidCallback? onTap;
  const _DecomposeChip(
      {required this.word,
      required this.selected,
      required this.exists,
      required this.color,
      this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: exists
                    ? Colors.grey.withValues(alpha: 0.1)
                    : selected
                        ? color.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: exists
                        ? Colors.grey.withValues(alpha: 0.2)
                        : selected
                            ? color
                            : Colors.white.withValues(alpha: 0.1))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (exists)
                const Icon(Icons.check, size: 12, color: Colors.grey)
              else if (selected)
                Icon(Icons.check_circle, size: 12, color: color),
              if (exists || selected) const SizedBox(width: 4),
              Text(word,
                  style: TextStyle(
                      color: exists
                          ? Colors.grey
                          : selected
                              ? Colors.white
                              : Colors.grey[300],
                      fontSize: 13)),
            ])),
      );
}
