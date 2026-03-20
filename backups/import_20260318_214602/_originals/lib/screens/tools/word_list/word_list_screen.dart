import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'loop_count_picker.dart';
import 'word_list_controller.dart';
import 'word_list_models.dart';

class WordListScreen extends StatefulWidget {
  const WordListScreen({super.key});

  @override
  State<WordListScreen> createState() => _WordListScreenState();
}

class _WordListScreenState extends State<WordListScreen> {
  late WordListController _ctrl;
  final _searchCtrl = TextEditingController();
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _ctrl = WordListController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _ctrl,
      child: Scaffold(
        backgroundColor: const Color(0xFF080B1A),
        body: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              _buildSubBar(),
              Expanded(child: _buildList()),
              _buildPlayBar(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── App Bar ─────────────────────────────────────────────
  Widget _buildAppBar() {
    return Consumer<WordListController>(
      builder: (_, ctrl, __) {
        return Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1520),
            border: Border(
              bottom:
                  BorderSide(color: Colors.white.withValues(alpha: 0.06)),
            ),
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
                      const Text(
                        'Word List',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF)
                              .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF6C63FF)
                                .withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          '${ctrl.totalCount}',
                          style: const TextStyle(
                            color: Color(0xFF9C8FFF),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
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
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Tìm từ...',
                        hintStyle: TextStyle(
                            color: Colors.grey[600], fontSize: 13),
                        prefixIcon: Icon(Icons.search,
                            color: Colors.grey[600], size: 16),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 9),
                      ),
                      onChanged: ctrl.setSearch,
                    ),
                  ),
                ),
              ],
              IconButton(
                icon: Icon(
                  _showSearch ? Icons.close : Icons.search,
                  color: Colors.grey[400],
                  size: 20,
                ),
                onPressed: () {
                  setState(() => _showSearch = !_showSearch);
                  if (!_showSearch) {
                    _searchCtrl.clear();
                    ctrl.setSearch('');
                  }
                },
              ),
              _OverflowMenu(ctrl: ctrl),
            ],
          ),
        );
      },
    );
  }

  // ─── Sub Bar ─────────────────────────────────────────────
  Widget _buildSubBar() {
    return Consumer<WordListController>(
      builder: (_, ctrl, __) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0F1A),
          border: Border(
            bottom:
                BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
        ),
        child: Row(
          children: [
            _DropdownChip(
              icon: Icons.folder_outlined,
              label: ctrl.currentFolderId == WordFolder.allWords.id
                  ? 'All words'
                  : 'Default',
              color: const Color(0xFF2196F3),
              onTap: () => _showFolderSheet(ctrl),
            ),
            const SizedBox(width: 8),
            _DropdownChip(
              icon: ctrl.sortMode.icon,
              label: ctrl.sortMode.label,
              color: const Color(0xFF6C63FF),
              onTap: () => _showSortSheet(ctrl),
            ),
            const Spacer(),
            _PlayAllButton(ctrl: ctrl),
          ],
        ),
      ),
    );
  }

  // ─── List ────────────────────────────────────────────────
  Widget _buildList() {
    return Consumer<WordListController>(
      builder: (_, ctrl, __) {
        final items = ctrl.displayEntries;
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.list_alt, size: 52, color: Colors.grey[800]),
                const SizedBox(height: 16),
                Text(
                  'Chưa có từ vựng',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Thêm từ từ Vườn Trí Nhớ hoặc nhấn + để tự thêm',
                  style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
          itemCount: items.length,
          itemBuilder: (_, i) => _WordRow(
            entry: items[i],
            index: i,
            ctrl: ctrl,
          ),
        );
      },
    );
  }

  // ─── Play Bar ────────────────────────────────────────────
  Widget _buildPlayBar() {
    return Consumer<WordListController>(
      builder: (_, ctrl, __) {
        if (!ctrl.isPlaying && !ctrl.isSelecting) {
          return const SizedBox.shrink();
        }
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1520),
            border: Border(
              top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          child: ctrl.isPlaying
              ? _buildPlayingBar(ctrl)
              : _buildSelectionBar(ctrl),
        );
      },
    );
  }

  Widget _buildPlayingBar(WordListController ctrl) {
    final items = ctrl.displayEntries;
    final current =
        ctrl.playingIndex >= 0 && ctrl.playingIndex < items.length
            ? items[ctrl.playingIndex]
            : null;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.volume_up,
              color: Color(0xFF9C8FFF), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                current?.word ?? '...',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${ctrl.playingIndex + 1} / ${items.length}'
                '${ctrl.playingRepeatCurrent > 1 ? ' · lần ${ctrl.playingRepeatCurrent}' : ''}',
                style:
                    TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: ctrl.stopPlayback,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(Icons.stop, color: Colors.red, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionBar(WordListController ctrl) {
    return Row(
      children: [
        Text(
          '${ctrl.selectedIds.length} đã chọn',
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13),
        ),
        const Spacer(),
        TextButton(
          onPressed: ctrl.selectAll,
          child: const Text('Chọn tất cả',
              style:
                  TextStyle(color: Color(0xFF2196F3), fontSize: 12)),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => ctrl.playAll(selectedOnly: true),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF9C27B0)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_arrow, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text('Phát',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Sheets ───────────────────────────────────────────────
  void _showFolderSheet(WordListController ctrl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1520),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FolderSheet(ctrl: ctrl),
    );
  }

  void _showSortSheet(WordListController ctrl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1520),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SortSheet(ctrl: ctrl),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Word Row
// ─────────────────────────────────────────────────────────────
class _WordRow extends StatefulWidget {
  final WordEntry entry;
  final int index;
  final WordListController ctrl;

  const _WordRow({
    required this.entry,
    required this.index,
    required this.ctrl,
  });

  @override
  State<_WordRow> createState() => _WordRowState();
}

class _WordRowState extends State<_WordRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;
    final entry = widget.entry;
    final settings = ctrl.settings;
    final isPlaying = ctrl.isPlaying && ctrl.playingIndex == widget.index;
    final isSelected = ctrl.selectedIds.contains(entry.id);
    final repeatCount = ctrl.getRepeatCount(entry.id);
    final shouldExpand = _expanded || settings.definitionsExpanded;

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        if (!ctrl.isSelecting) ctrl.toggleSelecting();
        ctrl.toggleSelect(entry.id);
      },
      onTap: ctrl.isSelecting ? () => ctrl.toggleSelect(entry.id) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: isPlaying
              ? const Color(0xFF6C63FF).withValues(alpha: 0.12)
              : isSelected
                  ? const Color(0xFF2196F3).withValues(alpha: 0.10)
                  : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPlaying
                ? const Color(0xFF6C63FF).withValues(alpha: 0.4)
                : isSelected
                    ? const Color(0xFF2196F3).withValues(alpha: 0.35)
                    : Colors.white.withValues(alpha: 0.07),
            width: isPlaying ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Number / checkbox
                  if (ctrl.isSelecting)
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
                                : Colors.grey,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 13)
                            : null,
                      ),
                    )
                  else if (settings.showNumber)
                    SizedBox(
                      width: 26,
                      child: Text(
                        '${widget.index + 1}',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  // Word info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            if (settings.showWord)
                              Text(
                                entry.word,
                                style: TextStyle(
                                  color: isPlaying
                                      ? const Color(0xFF9C8FFF)
                                      : Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            if (settings.showPhonetic &&
                                entry.phonetic != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                entry.phonetic!,
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                            if (entry.wordType != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: _wordTypeColor(entry.wordType!)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  entry.wordType!,
                                  style: TextStyle(
                                    color:
                                        _wordTypeColor(entry.wordType!),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (settings.showShortDefinition &&
                            entry.shortDefinition != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              entry.shortDefinition!,
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 12),
                              maxLines: shouldExpand ? null : 1,
                              overflow: shouldExpand
                                  ? null
                                  : TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Right controls
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ★ Repeat selector — dùng LoopCountPickerSheet mới
                      _RepeatSelector(
                        count: repeatCount,
                        isPlaying: isPlaying,
                        currentRepeat:
                            isPlaying ? ctrl.playingRepeatCurrent : 0,
                        onChanged: (v) =>
                            ctrl.setRepeatCount(entry.id, v),
                      ),
                      const SizedBox(width: 4),
                      // Play single
                      GestureDetector(
                        onTap: () => ctrl.playSingle(entry),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isPlaying
                                ? const Color(0xFF6C63FF)
                                    .withValues(alpha: 0.25)
                                : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.volume_up_outlined,
                            size: 16,
                            color: isPlaying
                                ? const Color(0xFF9C8FFF)
                                : Colors.grey[500],
                          ),
                        ),
                      ),
                      if (settings.showFullDefinition ||
                          settings.showExample)
                        GestureDetector(
                          onTap: () =>
                              setState(() => _expanded = !_expanded),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 2),
                            child: Icon(
                              shouldExpand
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: Colors.grey[700],
                              size: 18,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Expanded content
            if (shouldExpand &&
                (settings.showFullDefinition || settings.showExample))
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                    settings.showNumber ? 50.0 : 12.0, 0, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Divider(
                        color: Colors.white.withValues(alpha: 0.06),
                        height: 12),
                    if (settings.showFullDefinition &&
                        entry.fullDefinition != null) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.book_outlined,
                              size: 13, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              entry.fullDefinition!,
                              style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                  height: 1.5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (settings.showExample && entry.example != null)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.format_quote,
                              size: 13, color: Colors.grey[700]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              entry.example!,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _wordTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'noun': return const Color(0xFF2196F3);
      case 'verb': return const Color(0xFFFF5722);
      case 'adj':
      case 'adjective': return const Color(0xFF4CAF50);
      case 'adv':
      case 'adverb': return const Color(0xFFFF9800);
      default: return const Color(0xFF9E9E9E);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Repeat Selector — dùng LoopCountPickerSheet mới
// ─────────────────────────────────────────────────────────────
class _RepeatSelector extends StatelessWidget {
  final int count; // 0 = vô hạn
  final bool isPlaying;
  final int currentRepeat;
  final ValueChanged<int> onChanged;

  const _RepeatSelector({
    required this.count,
    required this.isPlaying,
    required this.currentRepeat,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isInfinite = count == 0;
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: (count != 1)
              ? const Color(0xFFFFB300).withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: (count != 1)
                ? const Color(0xFFFFB300).withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isInfinite ? Icons.all_inclusive : Icons.repeat,
              size: 12,
              color: (count != 1)
                  ? const Color(0xFFFFB300)
                  : Colors.grey[600],
            ),
            const SizedBox(width: 3),
            Text(
              isInfinite
                  ? '∞'
                  : (isPlaying && currentRepeat > 0
                      ? '$currentRepeat/$count'
                      : '$count×'),
              style: TextStyle(
                color: (count != 1)
                    ? const Color(0xFFFFB300)
                    : Colors.grey[600],
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1520),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      // ★ FIX: dùng builder context (sheetCtx) để pop đúng sheet,
      //   KHÔNG dùng parent context → tránh pop cả WordListScreen
      builder: (sheetCtx) => LoopCountPickerSheet(
        current: count,
        onChanged: (v) {
          onChanged(v);
          // Pop sheet bằng sheetCtx — chỉ đóng bottom sheet
          Navigator.of(sheetCtx).pop();
          HapticFeedback.selectionClick();
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Overflow Menu
// ─────────────────────────────────────────────────────────────
class _OverflowMenu extends StatelessWidget {
  final WordListController ctrl;
  const _OverflowMenu({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: Colors.grey[400], size: 20),
      color: const Color(0xFF1A2235),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (val) => _handleMenu(context, val),
      itemBuilder: (_) => [
        _menuItem('select', Icons.checklist, 'Chọn'),
        _menuItem('expand', Icons.unfold_more, 'Mở rộng tất cả'),
        const PopupMenuDivider(height: 1),
        _menuItem(
          'toggle_def',
          ctrl.settings.showShortDefinition
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          ctrl.settings.showShortDefinition
              ? 'Ẩn Definition'
              : 'Hiện Definition',
        ),
        const PopupMenuDivider(height: 1),
        _menuItem('settings', Icons.tune, 'Options Settings'),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(
      String val, IconData icon, String label) {
    return PopupMenuItem(
      value: val,
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[400]),
          const SizedBox(width: 10),
          Text(label,
              style:
                  const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }

  void _handleMenu(BuildContext context, String val) {
    switch (val) {
      case 'select':
        ctrl.toggleSelecting();
        break;
      case 'expand':
        ctrl.toggleExpandAll();
        break;
      case 'toggle_def':
        ctrl.toggleShowDefinitions();
        break;
      case 'settings':
        _showSettingsSheet(context);
        break;
    }
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1520),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SettingsSheet(ctrl: ctrl),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Settings Sheet
// ─────────────────────────────────────────────────────────────
class _SettingsSheet extends StatefulWidget {
  final WordListController ctrl;
  const _SettingsSheet({required this.ctrl});

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late WordListSettings _s;

  @override
  void initState() {
    super.initState();
    _s = widget.ctrl.settings;
  }

  void _update(WordListSettings s) {
    setState(() => _s = s);
    widget.ctrl.updateSettings(s);
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
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Options Settings',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Tùy chỉnh thông tin hiển thị cho mỗi từ',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 20),
          _ToggleRow(
            label: 'Hiển thị từ (Word)',
            icon: Icons.text_fields,
            value: _s.showWord,
            onChanged: (v) => _update(_s.copyWith(showWord: v)),
          ),
          _ToggleRow(
            label: 'Phiên âm (Phonetic)',
            icon: Icons.record_voice_over_outlined,
            value: _s.showPhonetic,
            onChanged: (v) => _update(_s.copyWith(showPhonetic: v)),
          ),
          _ToggleRow(
            label: 'Số thứ tự (Number)',
            icon: Icons.format_list_numbered,
            value: _s.showNumber,
            onChanged: (v) => _update(_s.copyWith(showNumber: v)),
          ),
          const Divider(color: Color(0xFF1E2A3A), height: 20),
          _ToggleRow(
            label: 'Nghĩa ngắn (Short Definition)',
            icon: Icons.short_text,
            value: _s.showShortDefinition,
            onChanged: (v) =>
                _update(_s.copyWith(showShortDefinition: v)),
          ),
          _ToggleRow(
            label: 'Nghĩa đầy đủ (Full Definition)',
            icon: Icons.article_outlined,
            value: _s.showFullDefinition,
            onChanged: (v) =>
                _update(_s.copyWith(showFullDefinition: v)),
          ),
          _ToggleRow(
            label: 'Ví dụ câu (Example)',
            icon: Icons.format_quote_outlined,
            value: _s.showExample,
            onChanged: (v) => _update(_s.copyWith(showExample: v)),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF6C63FF),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sort Sheet
// ─────────────────────────────────────────────────────────────
class _SortSheet extends StatelessWidget {
  final WordListController ctrl;
  const _SortSheet({required this.ctrl});

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
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Sắp xếp',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...WordListSortMode.values.map((mode) {
            final selected = ctrl.sortMode == mode;
            return GestureDetector(
              onTap: () {
                ctrl.setSortMode(mode);
                Navigator.pop(context);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF6C63FF).withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: selected
                      ? Border.all(
                          color: const Color(0xFF6C63FF)
                              .withValues(alpha: 0.4))
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(mode.icon,
                        size: 18,
                        color: selected
                            ? const Color(0xFF9C8FFF)
                            : Colors.grey[500]),
                    const SizedBox(width: 12),
                    Text(
                      mode.label,
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : Colors.grey[400],
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                    if (selected) ...[
                      const Spacer(),
                      const Icon(Icons.check,
                          color: Color(0xFF9C8FFF), size: 16),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Folder Sheet
// ─────────────────────────────────────────────────────────────
class _FolderSheet extends StatelessWidget {
  final WordListController ctrl;
  const _FolderSheet({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final folders = [WordFolder.allWords, WordFolder.defaultFolder];
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
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Chọn nhóm từ',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...folders.map((f) {
            final selected = ctrl.currentFolderId == f.id;
            return GestureDetector(
              onTap: () {
                ctrl.setFolder(f.id);
                Navigator.pop(context);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? f.color.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: selected
                      ? Border.all(
                          color: f.color.withValues(alpha: 0.4))
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(f.icon,
                        size: 18,
                        color: selected ? f.color : Colors.grey[500]),
                    const SizedBox(width: 12),
                    Text(
                      f.name,
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : Colors.grey[400],
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                    if (selected) ...[
                      const Spacer(),
                      Icon(Icons.check, color: f.color, size: 16),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Play All Button
// ─────────────────────────────────────────────────────────────
class _PlayAllButton extends StatelessWidget {
  final WordListController ctrl;
  const _PlayAllButton({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: ctrl.playAll,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: ctrl.isPlaying
              ? const LinearGradient(
                  colors: [Color(0xFFB71C1C), Color(0xFFE53935)])
              : const LinearGradient(
                  colors: [Color(0xFF4527A0), Color(0xFF6C63FF)]),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: (ctrl.isPlaying
                      ? const Color(0xFFE53935)
                      : const Color(0xFF6C63FF))
                  .withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ctrl.isPlaying ? Icons.stop : Icons.play_arrow,
                color: Colors.white, size: 16),
            const SizedBox(width: 5),
            Text(
              ctrl.isPlaying ? 'Dừng' : 'Phát tất cả',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Dropdown Chip
// ─────────────────────────────────────────────────────────────
class _DropdownChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _DropdownChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 3),
            Icon(Icons.arrow_drop_down, size: 14, color: color),
          ],
        ),
      ),
    );
  }
}
