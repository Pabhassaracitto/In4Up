//
// ★ MỚI: YouGlish icon trên mỗi row
// ★ MỚI: Import button (Clipboard / TextProvider / File)
// ★ MỚI: Drag từ sang folder khác
// ★ MỚI: Sort modes SM-2, khó→dễ, dễ→khó
// ★ MỚI: Export folder → CSV
// ★ MỚI: Move selected words sang folder khác

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'loop_count_picker.dart';
import 'word_import_sheet.dart';
import 'word_list_controller.dart';
import 'word_list_models.dart';

import 'youglish_mini_sheet.dart';

class WordListScreen extends StatefulWidget {
  const WordListScreen({super.key});

  @override
  State<WordListScreen> createState() => _WordListScreenState();
}

class _WordListScreenState extends State<WordListScreen> {
  late WordListController _ctrl;
  final _searchCtrl = TextEditingController();
  bool _showSearch = false;
  final _folderMgr = FolderTreeManager();

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

  // ─── AppBar ──────────────────────────────────────────────
  Widget _buildAppBar() {
    return Consumer<WordListController>(
      builder: (_, ctrl, __) => Container(
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
                    const Text('Word List',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color:
                                const Color(0xFF6C63FF).withValues(alpha: 0.4)),
                      ),
                      child: Text('${ctrl.totalCount}',
                          style: const TextStyle(
                              color: Color(0xFF9C8FFF),
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                    // SM-2 due badge
                    if (ctrl.sm2DueCount > 0) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => ctrl.setSortMode(WordListSortMode.sm2Due),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFFF5722).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFFFF5722)
                                    .withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.alarm,
                                  size: 10, color: Color(0xFFFF5722)),
                              const SizedBox(width: 3),
                              Text('${ctrl.sm2DueCount} ôn',
                                  style: const TextStyle(
                                      color: Color(0xFFFF5722),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
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
                      hintText: 'Tìm từ...',
                      hintStyle:
                          TextStyle(color: Colors.grey[600], fontSize: 13),
                      prefixIcon:
                          Icon(Icons.search, color: Colors.grey[600], size: 16),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                    onChanged: ctrl.setSearch,
                  ),
                ),
              ),
            ],
            // ★ MỚI: Import button
            GestureDetector(
              onTap: () => WordImportSheet.show(context, ctrl),
              child: Container(
                padding: const EdgeInsets.all(7),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.download_outlined,
                    color: Color(0xFF4CAF50), size: 18),
              ),
            ),
            IconButton(
              icon: Icon(_showSearch ? Icons.close : Icons.search,
                  color: Colors.grey[400], size: 20),
              onPressed: () {
                setState(() => _showSearch = !_showSearch);
                if (!_showSearch) {
                  _searchCtrl.clear();
                  ctrl.setSearch('');
                }
              },
            ),
            _OverflowMenu(ctrl: ctrl, folderMgr: _folderMgr),
          ],
        ),
      ),
    );
  }

  // ─── SubBar ──────────────────────────────────────────────
  Widget _buildSubBar() {
    return Consumer<WordListController>(
      builder: (_, ctrl, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0F1A),
          border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
        ),
        child: Row(
          children: [
            _DropdownChip(
              icon: Icons.folder_outlined,
              label: _folderLabel(ctrl.currentFolderId),
              color: const Color(0xFF2196F3),
              onTap: () => _showFolderSheet(ctrl),
            ),
            const SizedBox(width: 8),
            _DropdownChip(
              icon: ctrl.sortMode.icon,
              label: ctrl.sortMode.label,
              color: _sortModeColor(ctrl.sortMode),
              onTap: () => _showSortSheet(ctrl),
            ),
            const Spacer(),
            _ListRepeatButton(ctrl: ctrl),
            const SizedBox(width: 8),
            _PlayAllButton(ctrl: ctrl),
          ],
        ),
      ),
    );
  }

  Color _sortModeColor(WordListSortMode mode) {
    switch (mode) {
      case WordListSortMode.sm2Due:
        return const Color(0xFFFF5722);
      case WordListSortMode.hardFirst:
        return const Color(0xFFEF5350);
      case WordListSortMode.easyFirst:
        return const Color(0xFF4CAF50);
      default:
        return const Color(0xFF6C63FF);
    }
  }

  String _folderLabel(String id) {
    if (id == WordFolder.allWords.id) return 'All words';
    return _folderMgr.findById(id)?.name ?? 'Default';
  }

  // ─── List ─────────────────────────────────────────────────
  Widget _buildList() {
    return Consumer<WordListController>(
      builder: (_, ctrl, __) {
        final items = ctrl.displayEntries;
        final isSearching = ctrl.searchQuery.isNotEmpty;
        final hasExact = items
            .any((e) => e.word.toLowerCase() == ctrl.searchQuery.toLowerCase());

        return Column(
          children: [
            // Selection action bar (khi đang chọn)
            if (ctrl.isSelecting && ctrl.selectedIds.isNotEmpty)
              _buildSelectionActionBar(ctrl),

            if (isSearching && !hasExact && ctrl.searchQuery.length > 1)
              _buildSaveWordBanner(ctrl.searchQuery),

            Expanded(
              child: items.isEmpty
                  ? _buildEmptyState(ctrl)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                      itemCount: items.length,
                      itemBuilder: (_, i) => _WordRow(
                        entry: items[i],
                        index: i,
                        ctrl: ctrl,
                        folderMgr: _folderMgr,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(WordListController ctrl) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.list_alt, size: 52, color: Colors.grey[800]),
          const SizedBox(height: 16),
          Text('Chưa có từ vựng',
              style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Lưu từ hoặc import hàng loạt',
              style: TextStyle(color: Colors.grey[700], fontSize: 12)),
          const SizedBox(height: 20),
          // Quick import button
          GestureDetector(
            onTap: () => WordImportSheet.show(context, ctrl),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.35)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.download_outlined,
                      color: Color(0xFF4CAF50), size: 18),
                  SizedBox(width: 8),
                  Text('Import từ vựng',
                      style: TextStyle(
                          color: Color(0xFF4CAF50),
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ★ MỚI: Selection action bar
  Widget _buildSelectionActionBar(WordListController ctrl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF1A1A2E),
      child: Row(
        children: [
          Text('${ctrl.selectedIds.length} đã chọn',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
          const SizedBox(width: 12),
          // Move to folder
          GestureDetector(
            onTap: () => _showMoveToFolderSheet(ctrl),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.35)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.drive_file_move_outlined,
                      color: Color(0xFF2196F3), size: 14),
                  SizedBox(width: 4),
                  Text('Chuyển folder',
                      style: TextStyle(color: Color(0xFF2196F3), fontSize: 12)),
                ],
              ),
            ),
          ),
          const Spacer(),
          TextButton(
              onPressed: ctrl.selectAll,
              child: const Text('Tất cả',
                  style: TextStyle(color: Color(0xFF6C63FF), fontSize: 12))),
          TextButton(
              onPressed: ctrl.toggleSelecting,
              child: const Text('Xong',
                  style: TextStyle(color: Colors.grey, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildSaveWordBanner(String word) {
    return GestureDetector(
      onTap: () => _showAddWordDialog(prefill: word),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF2196F3).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: const Color(0xFF2196F3).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.add_circle_outline,
                color: Color(0xFF2196F3), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Lưu "$word" vào danh sách',
                style: const TextStyle(
                    color: Color(0xFF2196F3),
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[600], size: 18),
          ],
        ),
      ),
    );
  }

  // ─── Play Bar ─────────────────────────────────────────────
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
                top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
          ),
          child: ctrl.isPlaying
              ? _buildPlayingBar(ctrl)
              : _buildSelectingBar(ctrl),
        );
      },
    );
  }

  Widget _buildPlayingBar(WordListController ctrl) {
    final items = ctrl.displayEntries;
    final current = ctrl.playingIndex >= 0 && ctrl.playingIndex < items.length
        ? items[ctrl.playingIndex]
        : null;

    final listInfo = ctrl.listRepeatCount == 0
        ? 'Vòng ${ctrl.listRepeatCurrent} / ∞'
        : ctrl.listRepeatCount > 1
            ? 'Vòng ${ctrl.listRepeatCurrent}/${ctrl.listRepeatCount}'
            : '';

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child:
              const Icon(Icons.volume_up, color: Color(0xFF9C8FFF), size: 18),
        ),
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
                '${ctrl.playingIndex + 1}/${items.length}'
                '${ctrl.playingRepeatCurrent > 1 ? ' · lần ${ctrl.playingRepeatCurrent}' : ''}'
                '${listInfo.isNotEmpty ? '  $listInfo' : ''}',
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
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
            child: const Icon(Icons.stop, color: Colors.red, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectingBar(WordListController ctrl) {
    return Row(
      children: [
        Text('${ctrl.selectedIds.length} đã chọn',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
        const Spacer(),
        TextButton(
            onPressed: ctrl.selectAll,
            child: const Text('Chọn tất cả',
                style: TextStyle(color: Color(0xFF2196F3), fontSize: 12))),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => ctrl.playAll(selectedOnly: true),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF9C27B0)]),
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

  // ─── Dialogs & Sheets ─────────────────────────────────────
  void _showAddWordDialog({String prefill = ''}) {
    final wordCtrl = TextEditingController(text: prefill);
    final meaningCtrl = TextEditingController();
    final phoneticCtrl = TextEditingController();
    String selectedFolder = _ctrl.currentFolderId == WordFolder.allWords.id
        ? WordFolder.defaultFolder.id
        : _ctrl.currentFolderId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A2235),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (_, setSheetState) {
          final bottomPad = MediaQuery.of(sheetCtx).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomPad),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.add_circle,
                      color: Color(0xFF42A5F5), size: 20),
                  const SizedBox(width: 10),
                  const Text('Thêm từ mới',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(sheetCtx),
                    child: Icon(Icons.close, color: Colors.grey[500], size: 20),
                  ),
                ]),
                const SizedBox(height: 16),
                _buildField(wordCtrl, 'Từ / Cụm từ *', 'VD: break a leg',
                    Icons.translate, const Color(0xFF42A5F5)),
                const SizedBox(height: 10),
                _buildField(meaningCtrl, 'Nghĩa *', 'VD: vui vẻ',
                    Icons.lightbulb_outline, const Color(0xFFFFB300)),
                const SizedBox(height: 10),
                _buildField(phoneticCtrl, 'Phiên âm (tuỳ chọn)', '/ˈhæpi/',
                    Icons.record_voice_over_outlined, const Color(0xFF66BB6A)),
                const SizedBox(height: 10),
                // Folder selector
                GestureDetector(
                  onTap: () async {
                    final chosen = await _showFolderPicker(sheetCtx);
                    if (chosen != null) {
                      setSheetState(() => selectedFolder = chosen);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Row(children: [
                      Icon(Icons.folder_outlined,
                          color: Colors.grey[500], size: 16),
                      const SizedBox(width: 8),
                      Text(
                        _folderMgr.findById(selectedFolder)?.name ?? 'Default',
                        style: TextStyle(color: Colors.grey[300], fontSize: 13),
                      ),
                      const Spacer(),
                      Icon(Icons.arrow_drop_down,
                          color: Colors.grey[600], size: 18),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final word = wordCtrl.text.trim();
                      final meaning = meaningCtrl.text.trim();
                      if (word.isEmpty || meaning.isEmpty) return;
                      _ctrl.addManualEntry(WordEntry.manual(
                        id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
                        word: word.toLowerCase(),
                        shortDefinition: meaning,
                        phonetic: phoneticCtrl.text.trim().isEmpty
                            ? null
                            : phoneticCtrl.text.trim(),
                        folderId: selectedFolder,
                      ));
                      Navigator.pop(sheetCtx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF42A5F5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Lưu từ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, String hint,
      IconData icon, Color color) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
        labelStyle: TextStyle(color: color, fontSize: 12),
        prefixIcon: Icon(icon, color: color.withValues(alpha: 0.7), size: 16),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: color, width: 1.5)),
      ),
    );
  }

  Future<String?> _showFolderPicker(BuildContext ctx) async {
    return showModalBottomSheet<String>(
      context: ctx,
      backgroundColor: const Color(0xFF0D1520),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _FolderTreeSheet(
        manager: _folderMgr,
        onSelected: (id) => Navigator.pop(ctx, id),
      ),
    );
  }

  void _showFolderSheet(WordListController ctrl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1520),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => _FolderTreeSheet(
        manager: _folderMgr,
        showAllWords: true,
        currentId: ctrl.currentFolderId,
        onSelected: (id) {
          ctrl.setFolder(id);
          Navigator.pop(sheetCtx);
        },
        onAddFolder: (parentId, name) {
          setState(() => _folderMgr.addFolder(
                name: name,
                parentId: parentId,
              ));
        },
        onDeleteFolder: (id) {
          setState(() => _folderMgr.removeFolder(id));
          if (ctrl.currentFolderId == id) {
            ctrl.setFolder(WordFolder.allWords.id);
          }
        },
        // ★ MỚI: export
        onExportFolder: (id) async {
          _exportFolder(id);
          Navigator.pop(sheetCtx);
        },
      ),
    );
  }

  void _showSortSheet(WordListController ctrl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1520),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => _SortSheet(ctrl: ctrl, sheetCtx: sheetCtx),
    );
  }

  // ★ MỚI: Move to folder sheet
  void _showMoveToFolderSheet(WordListController ctrl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1520),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.drive_file_move_outlined,
                  color: Color(0xFF2196F3), size: 20),
              const SizedBox(width: 10),
              Text(
                'Chuyển ${ctrl.selectedIds.length} từ sang...',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold),
              ),
            ]),
            const SizedBox(height: 16),
            ...(_folderMgr.flattenAll().map((item) {
              return GestureDetector(
                onTap: () {
                  ctrl.moveSelectedToFolder(item.node.id);
                  Navigator.pop(sheetCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Đã chuyển sang "${item.node.name}"'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: const Color(0xFF2196F3),
                    ),
                  );
                },
                child: Container(
                  margin: EdgeInsets.only(left: item.depth * 16.0, bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    Icon(item.node.icon, size: 16, color: item.node.color),
                    const SizedBox(width: 10),
                    Text(item.node.name,
                        style: const TextStyle(color: Colors.white)),
                  ]),
                ),
              );
            })),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ★ MỚI: Export folder
  Future<void> _exportFolder(String folderId) async {
    final csv = _ctrl.exportFolderAsCsv(folderId);
    if (csv.isEmpty) return;

    try {
      final dir = await getTemporaryDirectory();
      final name = folderId == WordFolder.allWords.id
          ? 'all_words'
          : (_folderMgr.findById(folderId)?.name ?? 'folder');
      final file = File(
          '${dir.path}/${name}_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csv);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Word List: $name',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi export: $e')),
        );
      }
    }
  }
}

// ══════════════════════════════════════════════════════════
//  Word Row — với YouGlish icon và drag-to-folder
// ══════════════════════════════════════════════════════════
class _WordRow extends StatefulWidget {
  final WordEntry entry;
  final int index;
  final WordListController ctrl;
  final FolderTreeManager folderMgr;

  const _WordRow({
    required this.entry,
    required this.index,
    required this.ctrl,
    required this.folderMgr,
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
    final isDue = entry.isSm2Due;

    // ★ LongPressDraggable cho drag-to-folder
    return LongPressDraggable<String>(
      data: entry.id,
      delay: const Duration(milliseconds: 400),
      hapticFeedbackOnStart: true,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
                blurRadius: 12,
              ),
            ],
          ),
          child: Text(
            entry.word,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildRowContent(
            ctx: context,
            ctrl: ctrl,
            entry: entry,
            settings: settings,
            isPlaying: isPlaying,
            isSelected: isSelected,
            repeatCount: repeatCount,
            shouldExpand: shouldExpand,
            isDue: isDue),
      ),
      onDragStarted: () {
        if (!ctrl.isSelecting) {
          HapticFeedback.mediumImpact();
        }
      },
      child: GestureDetector(
        onLongPress: () {
          HapticFeedback.mediumImpact();
          if (!ctrl.isSelecting) ctrl.toggleSelecting();
          ctrl.toggleSelect(entry.id);
        },
        onTap: ctrl.isSelecting ? () => ctrl.toggleSelect(entry.id) : null,
        child: _buildRowContent(
            ctx: context,
            ctrl: ctrl,
            entry: entry,
            settings: settings,
            isPlaying: isPlaying,
            isSelected: isSelected,
            repeatCount: repeatCount,
            shouldExpand: shouldExpand,
            isDue: isDue),
      ),
    );
  }

  Widget _buildRowContent({
    required BuildContext ctx,
    required WordListController ctrl,
    required WordEntry entry,
    required WordListSettings settings,
    required bool isPlaying,
    required bool isSelected,
    required int repeatCount,
    required bool shouldExpand,
    required bool isDue,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isPlaying
            ? const Color(0xFF6C63FF).withValues(alpha: 0.12)
            : isSelected
                ? const Color(0xFF2196F3).withValues(alpha: 0.10)
                : isDue
                    ? const Color(0xFFFF5722).withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPlaying
              ? const Color(0xFF6C63FF).withValues(alpha: 0.4)
              : isSelected
                  ? const Color(0xFF2196F3).withValues(alpha: 0.35)
                  : isDue
                      ? const Color(0xFFFF5722).withValues(alpha: 0.25)
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
                                : Colors.grey),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${widget.index + 1}',
                            style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                        if (isDue)
                          const Icon(Icons.alarm,
                              size: 10, color: Color(0xFFFF5722)),
                      ],
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          if (settings.showWord)
                            Text(entry.word,
                                style: TextStyle(
                                  color: isPlaying
                                      ? const Color(0xFF9C8FFF)
                                      : Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                )),
                          if (settings.showPhonetic &&
                              entry.phonetic != null) ...[
                            const SizedBox(width: 8),
                            Text(entry.phonetic!,
                                style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic)),
                          ],
                          if (entry.wordType != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: _typeColor(entry.wordType!)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(entry.wordType!,
                                  style: TextStyle(
                                      color: _typeColor(entry.wordType!),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ],
                      ),
                      if (settings.showShortDefinition &&
                          entry.shortDefinition != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(entry.shortDefinition!,
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 12),
                              maxLines: shouldExpand ? null : 1,
                              overflow:
                                  shouldExpand ? null : TextOverflow.ellipsis),
                        ),
                    ],
                  ),
                ),
                // Action buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Per-word repeat
                    _PerWordRepeatSelector(
                      count: repeatCount,
                      isPlaying: isPlaying,
                      currentRepeat: isPlaying ? ctrl.playingRepeatCurrent : 0,
                      onChanged: (v) => ctrl.setRepeatCount(entry.id, v),
                    ),
                    const SizedBox(width: 4),

                    // ★ MỚI: YouGlish icon
                    GestureDetector(
                      onTap: () => YouGlishMiniSheet.show(ctx, entry.word),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF00BCD4).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Icon(Icons.record_voice_over,
                            size: 14, color: Color(0xFF00BCD4)),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // TTS play
                    GestureDetector(
                      onTap: () => ctrl.playSingle(entry),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: isPlaying
                              ? const Color(0xFF6C63FF).withValues(alpha: 0.25)
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Icon(Icons.volume_up_outlined,
                            size: 14,
                            color: isPlaying
                                ? const Color(0xFF9C8FFF)
                                : Colors.grey[500]),
                      ),
                    ),

                    if (settings.showFullDefinition || settings.showExample)
                      GestureDetector(
                        onTap: () => setState(() => _expanded = !_expanded),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: Icon(
                              shouldExpand
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: Colors.grey[700],
                              size: 18),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (shouldExpand &&
              (settings.showFullDefinition || settings.showExample))
            _buildExpandedContent(entry, settings),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(WordEntry entry, WordListSettings s) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(s.showNumber ? 50.0 : 12.0, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 12),
          if (s.showFullDefinition && entry.fullDefinition != null) ...[
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.book_outlined, size: 13, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(entry.fullDefinition!,
                      style: TextStyle(
                          color: Colors.grey[400], fontSize: 12, height: 1.5))),
            ]),
            const SizedBox(height: 6),
          ],
          if (s.showExample && entry.example != null)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.format_quote, size: 13, color: Colors.grey[700]),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(entry.example!,
                      style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          height: 1.5))),
            ]),
        ],
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'noun':
        return const Color(0xFF2196F3);
      case 'verb':
        return const Color(0xFFFF5722);
      case 'adj':
      case 'adjective':
        return const Color(0xFF4CAF50);
      case 'adv':
      case 'adverb':
        return const Color(0xFFFF9800);
      default:
        return const Color(0xFF9E9E9E);
    }
  }
}

// ══════════════════════════════════════════════════════════
//  Per-Word Repeat Selector
// ══════════════════════════════════════════════════════════
class _PerWordRepeatSelector extends StatelessWidget {
  final int count;
  final bool isPlaying;
  final int currentRepeat;
  final ValueChanged<int> onChanged;

  const _PerWordRepeatSelector({
    required this.count,
    required this.isPlaying,
    required this.currentRepeat,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: count > 1
              ? const Color(0xFFFFB300).withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: count > 1
                ? const Color(0xFFFFB300).withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.repeat,
                size: 11,
                color: count > 1 ? const Color(0xFFFFB300) : Colors.grey[600]),
            const SizedBox(width: 2),
            Text(
              isPlaying && currentRepeat > 0
                  ? '$currentRepeat/$count'
                  : '$count×',
              style: TextStyle(
                  color: count > 1 ? const Color(0xFFFFB300) : Colors.grey[600],
                  fontSize: 10,
                  fontWeight: FontWeight.w700),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => LoopCountPickerSheet(
        current: count,
        allowInfinite: false,
        onChanged: (v) {
          onChanged(v.clamp(1, 999));
          Navigator.of(sheetCtx).pop();
          HapticFeedback.selectionClick();
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  Sort Sheet — thêm sort modes mới
// ══════════════════════════════════════════════════════════
class _SortSheet extends StatelessWidget {
  final WordListController ctrl;
  final BuildContext sheetCtx;
  const _SortSheet({required this.ctrl, required this.sheetCtx});

  @override
  Widget build(BuildContext context) {
    // Group by category
    final groups = [
      (
        'Theo thời gian & tên',
        [
          WordListSortMode.addTime,
          WordListSortMode.alphabetical,
          WordListSortMode.alphabeticalDesc,
          WordListSortMode.random,
        ]
      ),
      (
        'Theo độ thành thạo',
        [
          WordListSortMode.hardFirst,
          WordListSortMode.easyFirst,
          WordListSortMode.rankDescending,
          WordListSortMode.familiarity,
        ]
      ),
      (
        'SM-2 Spaced Repetition',
        [
          WordListSortMode.sm2Due,
        ]
      ),
    ];

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
          ...groups.map((group) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.$1,
                    style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5)),
                const SizedBox(height: 6),
                ...group.$2.map((mode) {
                  final selected = ctrl.sortMode == mode;
                  final isNew = mode == WordListSortMode.sm2Due ||
                      mode == WordListSortMode.hardFirst ||
                      mode == WordListSortMode.easyFirst;
                  return GestureDetector(
                    onTap: () {
                      ctrl.setSortMode(mode);
                      Navigator.pop(sheetCtx);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF6C63FF).withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: selected
                            ? Border.all(
                                color: const Color(0xFF6C63FF)
                                    .withValues(alpha: 0.4))
                            : null,
                      ),
                      child: Row(children: [
                        Icon(mode.icon,
                            size: 16,
                            color: selected
                                ? const Color(0xFF9C8FFF)
                                : Colors.grey[500]),
                        const SizedBox(width: 12),
                        Text(mode.label,
                            style: TextStyle(
                                color:
                                    selected ? Colors.white : Colors.grey[400],
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                fontSize: 13)),
                        if (isNew) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5722)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('MỚI',
                                style: TextStyle(
                                    color: Color(0xFFFF5722),
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                        if (selected) ...[
                          const Spacer(),
                          const Icon(Icons.check,
                              color: Color(0xFF9C8FFF), size: 16),
                        ],
                      ]),
                    ),
                  );
                }),
                const SizedBox(height: 8),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  Folder Tree Sheet — với DragTarget và Export
// ══════════════════════════════════════════════════════════
class _FolderTreeSheet extends StatefulWidget {
  final FolderTreeManager manager;
  final String? currentId;
  final bool showAllWords;
  final ValueChanged<String> onSelected;
  final Function(String? parentId, String name)? onAddFolder;
  final ValueChanged<String>? onDeleteFolder;
  final ValueChanged<String>? onExportFolder; // ★ MỚI

  const _FolderTreeSheet({
    required this.manager,
    required this.onSelected,
    this.currentId,
    this.showAllWords = false,
    this.onAddFolder,
    this.onDeleteFolder,
    this.onExportFolder,
  });

  @override
  State<_FolderTreeSheet> createState() => _FolderTreeSheetState();
}

class _FolderTreeSheetState extends State<_FolderTreeSheet> {
  String? _hoveringFolderId;

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
          Row(children: [
            const Text('Nhóm từ',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const Spacer(),
            if (widget.onAddFolder != null)
              GestureDetector(
                onTap: () => _showAddDialog(context, null),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.create_new_folder_outlined,
                          color: Color(0xFF9C8FFF), size: 14),
                      SizedBox(width: 5),
                      Text('Thư mục mới',
                          style: TextStyle(
                              color: Color(0xFF9C8FFF), fontSize: 12)),
                    ],
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 4),
          // ★ MỚI: Drag hint
          Text('Kéo thả từ vào đây để chuyển folder',
              style: TextStyle(color: Colors.grey[700], fontSize: 11)),
          const SizedBox(height: 12),

          // All words — drag target
          if (widget.showAllWords)
            _FolderDragTarget(
              id: WordFolder.allWords.id,
              name: 'Tất cả từ',
              icon: Icons.list_alt,
              color: const Color(0xFF2196F3),
              isSelected: widget.currentId == WordFolder.allWords.id,
              depth: 0,
              isHovering: _hoveringFolderId == WordFolder.allWords.id,
              onTap: () => widget.onSelected(WordFolder.allWords.id),
              onWillAccept: (_) {
                setState(() => _hoveringFolderId = WordFolder.allWords.id);
                return false; // All words không nhận drag
              },
              onLeave: (_) => setState(() => _hoveringFolderId = null),
              onAccept: (_) {},
              onAdd: null,
              onDelete: null,
              onExport: null,
            ),

          ..._buildTree(widget.manager.roots, 0),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  List<Widget> _buildTree(List<FolderNode> nodes, int depth) {
    final widgets = <Widget>[];
    for (final node in nodes) {
      widgets.add(_FolderDragTarget(
        id: node.id,
        name: node.name,
        icon: node.icon,
        color: node.color,
        isSelected: widget.currentId == node.id,
        depth: depth,
        isHovering: _hoveringFolderId == node.id,
        hasChildren: node.children.isNotEmpty,
        isExpanded: node.isExpanded,
        onTap: () => widget.onSelected(node.id),
        onToggle: node.children.isNotEmpty
            ? () => setState(() => node.isExpanded = !node.isExpanded)
            : null,
        onWillAccept: (data) {
          setState(() => _hoveringFolderId = node.id);
          return true;
        },
        onLeave: (_) => setState(() => _hoveringFolderId = null),
        onAccept: (wordId) {
          setState(() => _hoveringFolderId = null);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã chuyển từ vào "${node.name}"'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: node.color,
            ),
          );
        },
        onAdd: widget.onAddFolder != null
            ? () => _showAddDialog(context, node.id)
            : null,
        onDelete: widget.onDeleteFolder != null && node.id != 'default'
            ? () {
                widget.onDeleteFolder!(node.id);
                setState(() {});
              }
            : null,
        onExport: widget.onExportFolder != null
            ? () => widget.onExportFolder!(node.id)
            : null,
      ));
      if (node.isExpanded) {
        widgets.addAll(_buildTree(node.children, depth + 1));
      }
    }
    return widgets;
  }

  void _showAddDialog(BuildContext ctx, String? parentId) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2235),
        title: Text(
          parentId == null ? 'Tạo thư mục mới' : 'Tạo thư mục con',
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Tên thư mục...',
            hintStyle: TextStyle(color: Colors.grey[600]),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Huỷ', style: TextStyle(color: Colors.grey[500]))),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isNotEmpty) {
                widget.onAddFolder!(parentId, name);
                setState(() {});
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF)),
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
  }
}

// ★ MỚI: DragTarget wrapper cho folder row
class _FolderDragTarget extends StatelessWidget {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final int depth;
  final bool isHovering;
  final bool hasChildren;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback? onToggle;
  final bool Function(String?) onWillAccept;
  final void Function(String?) onLeave;
  final void Function(String?) onAccept;
  final VoidCallback? onAdd;
  final VoidCallback? onDelete;
  final VoidCallback? onExport; // ★ MỚI

  const _FolderDragTarget({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.depth,
    required this.isHovering,
    this.hasChildren = false,
    this.isExpanded = false,
    required this.onTap,
    this.onToggle,
    required this.onWillAccept,
    required this.onLeave,
    required this.onAccept,
    this.onAdd,
    this.onDelete,
    this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => onWillAccept(details.data),
      onLeave: onLeave,
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (ctx, candidateData, rejectedData) {
        final isDraggingOver = candidateData.isNotEmpty || isHovering;

        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: EdgeInsets.only(left: depth * 16.0, bottom: 5),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDraggingOver
                  ? color.withValues(alpha: 0.25)
                  : isSelected
                      ? color.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: isDraggingOver
                  ? Border.all(color: color, width: 2)
                  : isSelected
                      ? Border.all(color: color.withValues(alpha: 0.4))
                      : null,
            ),
            child: Row(
              children: [
                if (hasChildren)
                  GestureDetector(
                    onTap: onToggle,
                    child: Icon(
                        isExpanded ? Icons.expand_more : Icons.chevron_right,
                        color: Colors.grey[600],
                        size: 18),
                  )
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 6),
                Icon(isDraggingOver ? Icons.folder_open : icon,
                    size: 16,
                    color: isSelected || isDraggingOver
                        ? color
                        : Colors.grey[500]),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(name,
                      style: TextStyle(
                          color: isSelected || isDraggingOver
                              ? Colors.white
                              : Colors.grey[400],
                          fontSize: 13,
                          fontWeight: isSelected || isDraggingOver
                              ? FontWeight.w600
                              : FontWeight.normal)),
                ),
                if (isDraggingOver)
                  Icon(Icons.add_circle, color: color, size: 16),
                if (isSelected && !isDraggingOver)
                  Icon(Icons.check, color: color, size: 16),
                // Export button
                if (onExport != null && !isDraggingOver) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onExport,
                    child: Icon(Icons.ios_share,
                        color: Colors.grey[700], size: 15),
                  ),
                ],
                // Add subfolder
                if (onAdd != null && !isDraggingOver) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onAdd,
                    child: Icon(Icons.add, color: Colors.grey[700], size: 16),
                  ),
                ],
                // Delete
                if (onDelete != null && !isDraggingOver) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onDelete,
                    child: Icon(Icons.delete_outline,
                        color: Colors.grey[700], size: 16),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════
//  Remaining helper widgets (unchanged)
// ══════════════════════════════════════════════════════════

class _OverflowMenu extends StatelessWidget {
  final WordListController ctrl;
  final FolderTreeManager folderMgr;
  const _OverflowMenu({required this.ctrl, required this.folderMgr});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: Colors.grey[400], size: 20),
      color: const Color(0xFF1A2235),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (val) => _handle(context, val),
      itemBuilder: (_) => [
        _item('select', Icons.checklist, 'Chọn'),
        _item('expand', Icons.unfold_more, 'Mở rộng tất cả'),
        _item('add', Icons.add_circle_outline, 'Thêm từ mới'),
        const PopupMenuDivider(height: 1),
        _item('import', Icons.download_outlined, 'Import từ vựng'),
        const PopupMenuDivider(height: 1),
        _item(
            'toggle_def',
            ctrl.settings.showShortDefinition
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            ctrl.settings.showShortDefinition
                ? 'Ẩn Definition'
                : 'Hiện Definition'),
        const PopupMenuDivider(height: 1),
        _item('settings', Icons.tune, 'Options'),
      ],
    );
  }

  PopupMenuItem<String> _item(String v, IconData icon, String label) =>
      PopupMenuItem(
        value: v,
        child: Row(children: [
          Icon(icon, size: 16, color: Colors.grey[400]),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 13)),
        ]),
      );

  void _handle(BuildContext ctx, String val) {
    final screen = ctx.findAncestorStateOfType<_WordListScreenState>();
    switch (val) {
      case 'select':
        ctrl.toggleSelecting();
      case 'expand':
        ctrl.toggleExpandAll();
      case 'add':
        screen?._showAddWordDialog();
      case 'import':
        WordImportSheet.show(ctx, ctrl);
      case 'toggle_def':
        ctrl.toggleShowDefinitions();
      case 'settings':
        showModalBottomSheet(
          context: ctx,
          backgroundColor: const Color(0xFF0D1520),
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (_) => _SettingsSheet(ctrl: ctrl),
        );
    }
  }
}

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
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Options Settings',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _row('Từ (Word)', Icons.text_fields, _s.showWord,
              (v) => _update(_s.copyWith(showWord: v))),
          _row('Phiên âm (Phonetic)', Icons.record_voice_over_outlined,
              _s.showPhonetic, (v) => _update(_s.copyWith(showPhonetic: v))),
          _row('Số thứ tự', Icons.format_list_numbered, _s.showNumber,
              (v) => _update(_s.copyWith(showNumber: v))),
          const Divider(color: Color(0xFF1E2A3A), height: 20),
          _row('Nghĩa ngắn', Icons.short_text, _s.showShortDefinition,
              (v) => _update(_s.copyWith(showShortDefinition: v))),
          _row('Nghĩa đầy đủ', Icons.article_outlined, _s.showFullDefinition,
              (v) => _update(_s.copyWith(showFullDefinition: v))),
          _row('Ví dụ', Icons.format_quote_outlined, _s.showExample,
              (v) => _update(_s.copyWith(showExample: v))),
        ],
      ),
    );
  }

  Widget _row(String label, IconData icon, bool value, ValueChanged<bool> cb) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
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
        ],
      ),
    );
  }
}

class _ListRepeatButton extends StatelessWidget {
  final WordListController ctrl;
  const _ListRepeatButton({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final isInfinite = ctrl.listRepeatCount == 0;
    final isOnce = ctrl.listRepeatCount == 1;

    return GestureDetector(
      onTap: () => _showListRepeatPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: !isOnce
              ? const Color(0xFF26C6DA).withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: !isOnce
                ? const Color(0xFF26C6DA).withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isInfinite ? Icons.all_inclusive : Icons.loop,
              size: 13,
              color: !isOnce ? const Color(0xFF26C6DA) : Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(ctrl.listRepeatLabel,
                style: TextStyle(
                    color: !isOnce ? const Color(0xFF26C6DA) : Colors.grey[600],
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  void _showListRepeatPicker(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1520),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => LoopCountPickerSheet(
        current: ctrl.listRepeatCount,
        allowInfinite: true,
        onChanged: (v) {
          ctrl.setListRepeatCount(v);
          Navigator.of(sheetCtx).pop();
        },
      ),
    );
  }
}

class _PlayAllButton extends StatelessWidget {
  final WordListController ctrl;
  const _PlayAllButton({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: ctrl.playAll,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
            Text(ctrl.isPlaying ? 'Dừng' : 'Phát tất cả',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                    color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(width: 3),
            Icon(Icons.arrow_drop_down, size: 14, color: color),
          ],
        ),
      ),
    );
  }
}
