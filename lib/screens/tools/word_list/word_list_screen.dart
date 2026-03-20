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
              bottom:
                  BorderSide(color: Colors.white.withValues(alpha: 0.06))),
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
                        color: const Color(0xFF6C63FF)
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFF6C63FF)
                                .withValues(alpha: 0.4)),
                      ),
                      child: Text('${ctrl.totalCount}',
                          style: const TextStyle(
                              color: Color(0xFF9C8FFF),
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
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
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Tìm từ...',
                      hintStyle:
                          TextStyle(color: Colors.grey[600], fontSize: 13),
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
            _OverflowMenu(ctrl: ctrl),
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
              bottom:
                  BorderSide(color: Colors.white.withValues(alpha: 0.05))),
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
              color: const Color(0xFF6C63FF),
              onTap: () => _showSortSheet(ctrl),
            ),
            const Spacer(),
            // ★ List repeat selector
            _ListRepeatButton(ctrl: ctrl),
            const SizedBox(width: 8),
            _PlayAllButton(ctrl: ctrl),
          ],
        ),
      ),
    );
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
        final hasExact = items.any(
            (e) => e.word.toLowerCase() == ctrl.searchQuery.toLowerCase());

        return Column(
          children: [
            // ★ Banner lưu từ khi search không có kết quả khớp
            if (isSearching && !hasExact && ctrl.searchQuery.length > 1)
              _buildSaveWordBanner(ctrl.searchQuery),

            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.list_alt,
                              size: 52, color: Colors.grey[800]),
                          const SizedBox(height: 16),
                          Text('Chưa có từ vựng',
                              style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text('Lưu từ hoặc nhập thủ công',
                              style: TextStyle(
                                  color: Colors.grey[700], fontSize: 12)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                      itemCount: items.length,
                      itemBuilder: (_, i) => _WordRow(
                        entry: items[i],
                        index: i,
                        ctrl: ctrl,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  // ★ Banner lưu từ từ search
  Widget _buildSaveWordBanner(String word) {
    return GestureDetector(
      onTap: () => _showAddWordDialog(prefill: word),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF2196F3).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFF2196F3).withValues(alpha: 0.3)),
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
                top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08))),
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
          child: const Icon(Icons.volume_up,
              color: Color(0xFF9C8FFF), size: 18),
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

  Widget _buildSelectionBar(WordListController ctrl) {
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
                style: TextStyle(
                    color: Color(0xFF2196F3), fontSize: 12))),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => ctrl.playAll(selectedOnly: true),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
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
            padding:
                EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomPad),
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
                    child: Icon(Icons.close,
                        color: Colors.grey[500], size: 20),
                  ),
                ]),
                const SizedBox(height: 16),
                _buildField(wordCtrl, 'Từ / Cụm từ *',
                    'VD: break a leg', Icons.translate,
                    const Color(0xFF42A5F5)),
                const SizedBox(height: 10),
                _buildField(meaningCtrl, 'Nghĩa *',
                    'VD: vui vẻ', Icons.lightbulb_outline,
                    const Color(0xFFFFB300)),
                const SizedBox(height: 10),
                _buildField(phoneticCtrl, 'Phiên âm (tuỳ chọn)',
                    '/ˈhæpi/', Icons.record_voice_over_outlined,
                    const Color(0xFF66BB6A)),
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
                        _folderMgr.findById(selectedFolder)?.name ??
                            'Default',
                        style: TextStyle(
                            color: Colors.grey[300], fontSize: 13),
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
                        id:
                            'manual_${DateTime.now().millisecondsSinceEpoch}',
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
                      padding:
                          const EdgeInsets.symmetric(vertical: 13),
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

  Widget _buildField(TextEditingController ctrl, String label,
      String hint, IconData icon, Color color) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
        labelStyle: TextStyle(color: color, fontSize: 12),
        prefixIcon:
            Icon(icon, color: color.withValues(alpha: 0.7), size: 16),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                BorderSide(color: Colors.white.withValues(alpha: 0.1))),
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
}

// ══════════════════════════════════════════════════════════
//  Word Row
// ══════════════════════════════════════════════════════════
class _WordRow extends StatefulWidget {
  final WordEntry entry;
  final int index;
  final WordListController ctrl;
  const _WordRow(
      {required this.entry, required this.index, required this.ctrl});

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
      onTap: ctrl.isSelecting
          ? () => ctrl.toggleSelect(entry.id)
          : null,
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
                      child: Text('${widget.index + 1}',
                          style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
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
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: _typeColor(entry.wordType!)
                                      .withValues(alpha: 0.15),
                                  borderRadius:
                                      BorderRadius.circular(4),
                                ),
                                child: Text(entry.wordType!,
                                    style: TextStyle(
                                        color:
                                            _typeColor(entry.wordType!),
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
                                    color: Colors.grey[400],
                                    fontSize: 12),
                                maxLines: shouldExpand ? null : 1,
                                overflow: shouldExpand
                                    ? null
                                    : TextOverflow.ellipsis),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Per-word repeat selector (1-N, no ∞)
                      _PerWordRepeatSelector(
                        count: repeatCount,
                        isPlaying: isPlaying,
                        currentRepeat:
                            isPlaying ? ctrl.playingRepeatCurrent : 0,
                        onChanged: (v) =>
                            ctrl.setRepeatCount(entry.id, v),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => ctrl.playSingle(entry),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isPlaying
                                ? const Color(0xFF6C63FF)
                                    .withValues(alpha: 0.25)
                                : Colors.white
                                    .withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.volume_up_outlined,
                              size: 16,
                              color: isPlaying
                                  ? const Color(0xFF9C8FFF)
                                  : Colors.grey[500]),
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
      ),
    );
  }

  Widget _buildExpandedContent(WordEntry entry, WordListSettings s) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          s.showNumber ? 50.0 : 12.0, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
              color: Colors.white.withValues(alpha: 0.06), height: 12),
          if (s.showFullDefinition && entry.fullDefinition != null) ...[
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.book_outlined, size: 13, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(entry.fullDefinition!,
                      style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                          height: 1.5))),
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
      case 'noun': return const Color(0xFF2196F3);
      case 'verb': return const Color(0xFFFF5722);
      case 'adj': case 'adjective': return const Color(0xFF4CAF50);
      case 'adv': case 'adverb': return const Color(0xFFFF9800);
      default: return const Color(0xFF9E9E9E);
    }
  }
}

// ══════════════════════════════════════════════════════════
//  Per-Word Repeat Selector (1-N, no ∞)
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
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
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
                size: 12,
                color: count > 1
                    ? const Color(0xFFFFB300)
                    : Colors.grey[600]),
            const SizedBox(width: 3),
            Text(
              isPlaying && currentRepeat > 0
                  ? '$currentRepeat/$count'
                  : '$count×',
              style: TextStyle(
                  color: count > 1
                      ? const Color(0xFFFFB300)
                      : Colors.grey[600],
                  fontSize: 11,
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
      // ★ FIX: dùng sheetCtx để pop đúng sheet, không pop màn hình
      builder: (sheetCtx) => LoopCountPickerSheet(
        current: count,
        allowInfinite: false, // Per-word không có ∞
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
//  List Repeat Button (∞ / 1 / custom)
// ══════════════════════════════════════════════════════════
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
              color: !isOnce
                  ? const Color(0xFF26C6DA)
                  : Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              ctrl.listRepeatLabel,
              style: TextStyle(
                  color: !isOnce
                      ? const Color(0xFF26C6DA)
                      : Colors.grey[600],
                  fontSize: 11,
                  fontWeight: FontWeight.w700),
            ),
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
      builder: (sheetCtx) => _ListRepeatSheet(
        current: ctrl.listRepeatCount,
        onChanged: (v) {
          ctrl.setListRepeatCount(v);
          Navigator.of(sheetCtx).pop();
        },
      ),
    );
  }
}

// ── Sheet lặp danh sách ───────────────────────────────────
class _ListRepeatSheet extends StatefulWidget {
  final int current;
  final ValueChanged<int> onChanged;
  const _ListRepeatSheet(
      {required this.current, required this.onChanged});

  @override
  State<_ListRepeatSheet> createState() => _ListRepeatSheetState();
}

class _ListRepeatSheetState extends State<_ListRepeatSheet> {
  final _ctrl = TextEditingController();
  bool _showCustom = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
              child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(2)))),
          const Text('Lặp danh sách',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Phát hết → lặp lại toàn bộ danh sách  •  ∞ = mãi mãi',
              style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const SizedBox(height: 20),
          Row(children: [
            _item(0, '∞', 'mãi', const Color(0xFFEF5350)),
            const SizedBox(width: 8),
            _item(1, '1', 'lần', const Color(0xFF26C6DA)),
            const SizedBox(width: 8),
            _item(2, '2', 'lần', const Color(0xFF26C6DA)),
            const SizedBox(width: 8),
            _item(3, '3', 'lần', const Color(0xFF26C6DA)),
            const SizedBox(width: 8),
            _item(5, '5', 'lần', const Color(0xFF26C6DA)),
          ]),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () =>
                setState(() => _showCustom = !_showCustom),
            child: Row(children: [
              Icon(
                  _showCustom
                      ? Icons.expand_less
                      : Icons.edit_outlined,
                  color: Colors.grey[500],
                  size: 15),
              const SizedBox(width: 6),
              Text(_showCustom ? 'Ẩn' : 'Nhập số khác...',
                  style:
                      TextStyle(color: Colors.grey[500], fontSize: 13)),
            ]),
          ),
          if (_showCustom) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style:
                      const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'VD: 10, 20...',
                    hintStyle:
                        TextStyle(color: Colors.grey[600], fontSize: 14),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF26C6DA), width: 1.5)),
                  ),
                  onSubmitted: (_) => _apply(),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _apply,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF26C6DA),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: const Text('OK',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ]),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _item(int value, String label, String sub, Color color) {
    final selected = widget.current == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          widget.onChanged(value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 56,
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    colors: [color.withValues(alpha: 0.8), color],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight)
                : null,
            color: selected
                ? null
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: selected
                ? null
                : Border.all(
                    color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 2))
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: TextStyle(
                      color: selected ? Colors.white : Colors.grey[400],
                      fontSize: label == '∞' ? 22 : 18,
                      fontWeight: FontWeight.w800)),
              Text(sub,
                  style: TextStyle(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.8)
                          : Colors.grey[600],
                      fontSize: 9)),
            ],
          ),
        ),
      ),
    );
  }

  void _apply() {
    final v = int.tryParse(_ctrl.text.trim());
    if (v == null || v < 0) return;
    widget.onChanged(v);
  }
}

// ══════════════════════════════════════════════════════════
//  Folder Tree Sheet
// ══════════════════════════════════════════════════════════
class _FolderTreeSheet extends StatefulWidget {
  final FolderTreeManager manager;
  final String? currentId;
  final bool showAllWords;
  final ValueChanged<String> onSelected;
  final Function(String? parentId, String name)? onAddFolder;
  final ValueChanged<String>? onDeleteFolder;

  const _FolderTreeSheet({
    required this.manager,
    required this.onSelected,
    this.currentId,
    this.showAllWords = false,
    this.onAddFolder,
    this.onDeleteFolder,
  });

  @override
  State<_FolderTreeSheet> createState() => _FolderTreeSheetState();
}

class _FolderTreeSheetState extends State<_FolderTreeSheet> {
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFF6C63FF)
                            .withValues(alpha: 0.3)),
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
          const SizedBox(height: 12),

          // All words
          if (widget.showAllWords)
            _FolderRow(
              id: WordFolder.allWords.id,
              name: 'Tất cả từ',
              icon: Icons.list_alt,
              color: const Color(0xFF2196F3),
              isSelected: widget.currentId == WordFolder.allWords.id,
              depth: 0,
              hasChildren: false,
              isExpanded: false,
              onTap: () => widget.onSelected(WordFolder.allWords.id),
              onToggle: null,
              onAdd: null,
              onDelete: null,
            ),

          // Folder tree
          ..._buildTree(widget.manager.roots, 0),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  List<Widget> _buildTree(List<FolderNode> nodes, int depth) {
    final widgets = <Widget>[];
    for (final node in nodes) {
      widgets.add(_FolderRow(
        id: node.id,
        name: node.name,
        icon: node.icon,
        color: node.color,
        isSelected: widget.currentId == node.id,
        depth: depth,
        hasChildren: node.children.isNotEmpty,
        isExpanded: node.isExpanded,
        onTap: () => widget.onSelected(node.id),
        onToggle: node.children.isNotEmpty
            ? () => setState(() => node.isExpanded = !node.isExpanded)
            : null,
        onAdd: widget.onAddFolder != null
            ? () => _showAddDialog(context, node.id)
            : null,
        onDelete: widget.onDeleteFolder != null && node.id != 'default'
            ? () {
                widget.onDeleteFolder!(node.id);
                setState(() {});
              }
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
          parentId == null
              ? 'Tạo thư mục mới'
              : 'Tạo thư mục con',
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
              child: Text('Huỷ',
                  style: TextStyle(color: Colors.grey[500]))),
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

class _FolderRow extends StatelessWidget {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final int depth;
  final bool hasChildren;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback? onToggle;
  final VoidCallback? onAdd;
  final VoidCallback? onDelete;

  const _FolderRow({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.depth,
    required this.hasChildren,
    required this.isExpanded,
    required this.onTap,
    this.onToggle,
    this.onAdd,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(
            left: depth * 16.0, bottom: 5),
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: color.withValues(alpha: 0.4))
              : null,
        ),
        child: Row(
          children: [
            // Toggle expand
            if (hasChildren)
              GestureDetector(
                onTap: onToggle,
                child: Icon(
                    isExpanded
                        ? Icons.expand_more
                        : Icons.chevron_right,
                    color: Colors.grey[600],
                    size: 18),
              )
            else
              const SizedBox(width: 18),
            const SizedBox(width: 6),
            Icon(icon, size: 16, color: isSelected ? color : Colors.grey[500]),
            const SizedBox(width: 10),
            Expanded(
              child: Text(name,
                  style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[400],
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal)),
            ),
            if (isSelected)
              Icon(Icons.check, color: color, size: 16),
            // Add subfolder
            if (onAdd != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onAdd,
                child: Icon(Icons.add,
                    color: Colors.grey[700], size: 16),
              ),
            ],
            // Delete
            if (onDelete != null) ...[
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
  }
}

// ══════════════════════════════════════════════════════════
//  Other widgets (Overflow, Settings, Sort, PlayAll, Dropdown)
// ══════════════════════════════════════════════════════════

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
      onSelected: (val) => _handle(context, val),
      itemBuilder: (_) => [
        _item('select', Icons.checklist, 'Chọn'),
        _item('expand', Icons.unfold_more, 'Mở rộng tất cả'),
        _item('add', Icons.add_circle_outline, 'Thêm từ mới'),
        const PopupMenuDivider(height: 1),
        _item('toggle_def',
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
              style:
                  const TextStyle(color: Colors.white, fontSize: 13)),
        ]),
      );

  void _handle(BuildContext ctx, String val) {
    final screen =
        ctx.findAncestorStateOfType<_WordListScreenState>();
    switch (val) {
      case 'select':
        ctrl.toggleSelecting();
        break;
      case 'expand':
        ctrl.toggleExpandAll();
        break;
      case 'add':
        screen?._showAddWordDialog();
        break;
      case 'toggle_def':
        ctrl.toggleShowDefinitions();
        break;
      case 'settings':
        showModalBottomSheet(
          context: ctx,
          backgroundColor: const Color(0xFF0D1520),
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20))),
          builder: (_) => _SettingsSheet(ctrl: ctrl),
        );
        break;
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
          _row('Phiên âm (Phonetic)',
              Icons.record_voice_over_outlined, _s.showPhonetic,
              (v) => _update(_s.copyWith(showPhonetic: v))),
          _row('Số thứ tự', Icons.format_list_numbered, _s.showNumber,
              (v) => _update(_s.copyWith(showNumber: v))),
          const Divider(color: Color(0xFF1E2A3A), height: 20),
          _row('Nghĩa ngắn', Icons.short_text, _s.showShortDefinition,
              (v) => _update(_s.copyWith(showShortDefinition: v))),
          _row('Nghĩa đầy đủ', Icons.article_outlined,
              _s.showFullDefinition,
              (v) => _update(_s.copyWith(showFullDefinition: v))),
          _row('Ví dụ', Icons.format_quote_outlined, _s.showExample,
              (v) => _update(_s.copyWith(showExample: v))),
        ],
      ),
    );
  }

  Widget _row(
      String label, IconData icon, bool value, ValueChanged<bool> cb) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13))),
          Switch(
              value: value,
              onChanged: cb,
              activeColor: const Color(0xFF6C63FF),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
        ],
      ),
    );
  }
}

class _SortSheet extends StatelessWidget {
  final WordListController ctrl;
  final BuildContext sheetCtx;
  const _SortSheet({required this.ctrl, required this.sheetCtx});

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
            final selected = ctrl.sortMode == mode;
            return GestureDetector(
              onTap: () {
                ctrl.setSortMode(mode);
                Navigator.pop(sheetCtx);
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
                child: Row(children: [
                  Icon(mode.icon,
                      size: 18,
                      color: selected
                          ? const Color(0xFF9C8FFF)
                          : Colors.grey[500]),
                  const SizedBox(width: 12),
                  Text(mode.label,
                      style: TextStyle(
                          color: selected
                              ? Colors.white
                              : Colors.grey[400],
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          fontSize: 13)),
                  if (selected) ...[
                    const Spacer(),
                    const Icon(Icons.check,
                        color: Color(0xFF9C8FFF), size: 16),
                  ],
                ]),
              ),
            );
          }),
        ],
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
