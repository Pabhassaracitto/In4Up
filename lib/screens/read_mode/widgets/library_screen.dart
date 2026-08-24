// lib/screens/read_mode/widgets/library_screen.dart

import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../features/pdf_reader/pdf_reader_screen.dart';
import '../../../providers/text_provider.dart';
import '../../../services/text_library_service.dart';
import '../models/recent_file.dart';
import '../services/recent_files_service.dart';
import 'cloud_picker_sheet.dart';
import 'library_add_sheet.dart';
import 'recent_file_card.dart';

// ═══════════════════════════════════════════════════════════
// MAIN SCREEN
// ═══════════════════════════════════════════════════════════

class ReadLibraryScreen extends StatefulWidget {
  const ReadLibraryScreen({super.key});

  @override
  State<ReadLibraryScreen> createState() => _ReadLibraryScreenState();
}

class _ReadLibraryScreenState extends State<ReadLibraryScreen>
    with TickerProviderStateMixin {
  // ── Services ───────────────────────────────────────────────
  final _service = RecentFilesService();

  // ── Tab controller (3 tabs) ────────────────────────────────
  late final TabController _tabCtrl;

  // ── Data ───────────────────────────────────────────────────
  List<RecentFile> _files = [];
  bool _isLoading = true;

  // ── Search ─────────────────────────────────────────────────
  bool _isSearching = false;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  // ── FAB animation ──────────────────────────────────────────
  late final AnimationController _fabAnim;
  late final Animation<double> _fabScale;

  @override
  void initState() {
    super.initState();

    // 3 tabs: Gần đây | Cloud | Thiết bị
    _tabCtrl = TabController(length: 3, vsync: this)
      ..addListener(_onTabChanged);

    _fabAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fabScale = CurvedAnimation(
      parent: _fabAnim,
      curve: Curves.elasticOut,
    );

    _load();
  }

  @override
  void dispose() {
    _tabCtrl
      ..removeListener(_onTabChanged)
      ..dispose();
    _fabAnim.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Tab change → reset search ──────────────────────────────
  void _onTabChanged() {
    if (!_tabCtrl.indexIsChanging) return;
    setState(() {
      _searchQuery = '';
      _searchCtrl.clear();
      _isSearching = false;
    });
  }

  // ── Load danh sách Recent ──────────────────────────────────
  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final files = await _service.getAll();

    if (!mounted) return;
    setState(() {
      _files = files;
      _isLoading = false;
    });

    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) _fabAnim.forward();
  }

  // ── Search filter ──────────────────────────────────────────
  List<RecentFile> get _filteredFiles {
    if (_searchQuery.isEmpty) return _files;
    final q = _searchQuery.toLowerCase();
    return _files
        .where((f) =>
            f.title.toLowerCase().contains(q) ||
            (f.subtitle?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  // ═══════════════════════════════════════════════════════════
  // FILE ACTIONS
  // ═══════════════════════════════════════════════════════════

  Future<void> _openFile(RecentFile file) async {
    // Lưu refs TRƯỚC khi await
    final tp = context.read<TextProvider>();
    final nav = Navigator.of(context);

    switch (file.type) {
      // ── Local text (.txt / .lrc / .srt) ───────────────────
      case RecentFileType.localText:
        if (file.localPath == null) return;
        await tp.loadTextFile(file.localPath!);
        if (!mounted) return;
        await _service.addOrUpdate(
          file.copyWith(
            lastOpened: DateTime.now(),
            totalLines: tp.lines.length,
          ),
        );
        break;

      // ── PDF ────────────────────────────────────────────────
      case RecentFileType.localPdf:
        if (file.localPath == null) return;
        await _service.addOrUpdate(
          file.copyWith(lastOpened: DateTime.now()),
        );
        if (!mounted) return;
        nav.push(MaterialPageRoute(
          builder: (_) => PdfReaderScreen(pdfPath: file.localPath!),
        ));
        break;

      // ── Cloud: load trực tiếp từ Firestore ────────────────
      case RecentFileType.cloud:
        if (file.cloudId == null) return;
        _showLoadingSnack('Đang tải từ Cloud...');

        final svc = TextLibraryService();
        final entry = await svc.getById(file.cloudId!);
        if (!mounted) return;

        if (entry != null) {
          tp.loadFromString(
            entry.content,
            title: entry.title,
            sourceType: TextSourceType.cloud,
            cloudId: entry.id,
            category: entry.category,
          );
          await _service.addOrUpdate(
            file.copyWith(
              lastOpened: DateTime.now(),
              totalLines: entry.lineCount,
            ),
          );
          _hideSnack();
        } else {
          _hideSnack();
          // Entry bị xoá khỏi cloud → mở CloudPickerSheet để chọn lại
          final loaded = await CloudPickerSheet.show(context);
          if (!mounted) return;
          if (loaded) await _load();
        }
        break;
    }
  }

  // ── Show add sheet ─────────────────────────────────────────
  void _showAddSheet() {
    LibraryAddSheet.show(
      context,
      onAddManualText: _handleManualText,
      onPickLocalText: _handlePickLocalText,
      onPickPdf: _handlePickPdf,
      onOpenCloud: _handleOpenCloud,
    );
  }

  // ── Manual text input ──────────────────────────────────────
  void _handleManualText() => _showManualInputDialog();

  // ── Pick TXT/LRC/SRT ──────────────────────────────────────
  Future<void> _handlePickLocalText() async {
    final tp = context.read<TextProvider>();

    FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const [
          'txt', 'lrc', 'srt', 'md', 'markdown', 'json', 'docx',
        ],
      );
    } catch (e) {
      debugPrint('[LibraryScreen] FilePicker error: $e');
      return;
    }

    if (result == null || result.files.single.path == null) return;
    if (!mounted) return;

    final path = result.files.single.path!;
    final loaded = await tp.loadTextFile(path);
    if (!mounted) return;
    if (!loaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không đọc được file — .doc cũ vui lòng lưu lại .docx hoặc .txt',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final file = RecentFile.fromLocalText(path).copyWith(
      totalLines: tp.lines.length,
    );
    await _service.addOrUpdate(file);
    if (!mounted) return;
    await _load();
  }

  // ── Pick PDF ───────────────────────────────────────────────
  Future<void> _handlePickPdf() async {
    final nav = Navigator.of(context);

    FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
    } catch (e) {
      debugPrint('[LibraryScreen] FilePicker PDF error: $e');
      return;
    }

    if (result == null || result.files.single.path == null) return;
    if (!mounted) return;

    final path = result.files.single.path!;
    final file = RecentFile.fromLocalPdf(path);
    await _service.addOrUpdate(file);
    if (!mounted) return;

    await _load();
    if (!mounted) return;

    nav.push(MaterialPageRoute(
      builder: (_) => PdfReaderScreen(pdfPath: path),
    ));
  }

  // ── Open Cloud picker ──────────────────────────────────────
  Future<void> _handleOpenCloud() async {
    final loaded = await CloudPickerSheet.show(context);
    if (!mounted) return;
    if (loaded) {
      await _load();
      // Switch sang tab "Gần đây" để thấy file vừa load
      _tabCtrl.animateTo(0);
    }
  }

  // ── Delete file from recent ────────────────────────────────
  Future<void> _removeFile(RecentFile file) async {
    HapticFeedback.heavyImpact();
    await _service.remove(file.id);
    if (mounted) await _load();
  }

  // ── File options (long press) ──────────────────────────────
  void _showFileOptions(RecentFile file) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141D2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    file.typeEmoji,
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      file.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(
              color: Colors.white12,
              height: 24,
              indent: 20,
              endIndent: 20,
            ),
            ListTile(
              leading: const Icon(
                Icons.open_in_new,
                color: Color(0xFF2196F3),
              ),
              title: const Text(
                'Mở tài liệu',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _openFile(file);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Colors.red,
              ),
              title: const Text(
                'Xóa khỏi danh sách',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                Navigator.pop(context);
                await _removeFile(file);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Manual input dialog ────────────────────────────────────
  void _showManualInputDialog() {
    final ctrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141D2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(
                  Icons.edit_note_rounded,
                  color: Color(0xFFFF9800),
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Nhập văn bản',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              maxLines: 10,
              autofocus: true,
              style: const TextStyle(
                color: Colors.white,
                height: 1.6,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText:
                    context.uiText('Paste hoặc nhập văn bản...\n\nMỗi dòng = 1 đơn vị đọc.'),
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.28),
                  fontSize: 13,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(sheetCtx),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Hủy',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final text = ctrl.text.trim();
                      if (text.isEmpty) return;

                      Navigator.pop(sheetCtx);

                      // Lưu tp ref TRƯỚC khi await
                      final tp = context.read<TextProvider>();
                      tp.loadFromString(text);

                      final lines = text
                          .split('\n')
                          .where((l) => l.trim().isNotEmpty)
                          .toList();
                      final preview = lines.isNotEmpty
                          ? (lines.first.length > 45
                              ? '${lines.first.substring(0, 45)}...'
                              : lines.first)
                          : 'Văn bản mới';

                      final file = RecentFile(
                        id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
                        title: preview,
                        type: RecentFileType.localText,
                        lastOpened: DateTime.now(),
                        totalLines: lines.length,
                        thumbnailEmoji: '✏️',
                      );
                      await _service.addOrUpdate(file);
                      if (!mounted) return;
                      await _load();
                    },
                    icon: const Icon(
                      Icons.check,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Xác nhận',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── Snack helpers ──────────────────────────────────────────
  ScaffoldFeatureController? _snackCtrl;

  void _showLoadingSnack(String msg) {
    if (!mounted) return;
    _snackCtrl = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Text(msg, style: const TextStyle(color: Colors.white)),
          ],
        ),
        backgroundColor: const Color(0xFF1565C0),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _hideSnack() {
    _snackCtrl?.close();
    _snackCtrl = null;
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1520),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildTabBar(),
          // Search bar — hiện khi _isSearching = true
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: _isSearching ? _buildSearchBar() : const SizedBox.shrink(),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildRecentTab(),
                _buildCloudTab(),
                _buildDeviceTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabScale,
        child: FloatingActionButton.extended(
          onPressed: _showAddSheet,
          backgroundColor: const Color(0xFF1565C0),
          elevation: 4,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text(
            'Thêm tài liệu',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1520),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.07),
          ),
        ),
      ),
      child: Row(
        children: [
          // ── Title ────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📚 Thư viện đọc',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context.uiText(_isLoading
                      ? 'Đang tải...'
                      : _files.isEmpty
                          ? 'Chưa có tài liệu nào'
                          : '${_files.length} tài liệu'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.42),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // ── Search button ─────────────────────────────────
          _HeaderIconButton(
            icon:
                _isSearching ? Icons.search_off_rounded : Icons.search_rounded,
            color: _isSearching
                ? const Color(0xFF2196F3)
                : Colors.white.withValues(alpha: 0.5),
            onTap: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = '';
                  _searchCtrl.clear();
                }
              });
            },
          ),
          const SizedBox(width: 6),

          // ── Refresh button ────────────────────────────────
          if (!_isLoading)
            _HeaderIconButton(
              icon: Icons.refresh_rounded,
              color: Colors.white.withValues(alpha: 0.5),
              onTap: _load,
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // TAB BAR
  // ═══════════════════════════════════════════════════════════

  Widget _buildTabBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
          ),
          child: TabBar(
            controller: _tabCtrl,
            isScrollable: compact,
            tabAlignment: compact ? TabAlignment.start : TabAlignment.fill,
            indicator: BoxDecoration(
              color: const Color(0xFF1565C0),
              borderRadius: BorderRadius.circular(10),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
            labelPadding: EdgeInsets.symmetric(horizontal: compact ? 8 : 0),
            tabs: [
              _libraryTab(
                icon: Icons.history_rounded,
                label: 'Gần đây',
                compact: compact,
                trailing: !compact && _files.isNotEmpty ? _TabBadge(count: _files.length) : null,
              ),
              _libraryTab(
                icon: Icons.cloud_rounded,
                label: 'Cloud',
                compact: compact,
              ),
              _libraryTab(
                icon: Icons.folder_rounded,
                label: 'Thiết bị',
                compact: compact,
              ),
            ],
          ),
        );
      },
    );
  }

  Tab _libraryTab({
    required IconData icon,
    required String label,
    required bool compact,
    Widget? trailing,
  }) {
    return Tab(
      height: compact ? 34 : 38,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 13 : 14),
            SizedBox(width: compact ? 4 : 5),
            Text(label, overflow: TextOverflow.ellipsis),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              trailing,
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SEARCH BAR
  // ═══════════════════════════════════════════════════════════

  Widget _buildSearchBar() {
    final hints = [
      'Tìm file gần đây...', // tab 0
      'Tìm trong Cloud...', // tab 1
      'Tìm file trên thiết bị...', // tab 2
    ];
    final hint = hints[_tabCtrl.index.clamp(0, 2)];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: Color(0xFF2196F3).withValues(alpha: 0.4),
          ),
        ),
        child: TextField(
          controller: _searchCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: context.uiText(hint),
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 12,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: Colors.white.withValues(alpha: 0.4),
              size: 18,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear_rounded,
                      color: Colors.white.withValues(alpha: 0.4),
                      size: 16,
                    ),
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                        _searchCtrl.clear();
                      });
                    },
                    padding: EdgeInsets.zero,
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onChanged: (v) => setState(() => _searchQuery = v),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // TAB 0: GẦN ĐÂY (Recent)
  // ═══════════════════════════════════════════════════════════

  Widget _buildRecentTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF2196F3),
          strokeWidth: 2,
        ),
      );
    }

    // Apply search filter
    final filtered = _filteredFiles;

    if (filtered.isEmpty && _searchQuery.isNotEmpty) {
      return _buildSearchEmpty(_searchQuery);
    }

    if (_files.isEmpty) {
      return _buildRecentEmptyState();
    }

    // Group theo status (áp dụng search filter)
    final inProgress = filtered.where((f) => f.isInProgress).toList();
    final newFiles = filtered.where((f) => f.isNew).toList();
    final completed = filtered.where((f) => f.isCompleted).toList();

    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFF2196F3),
      backgroundColor: const Color(0xFF1A2235),
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 120),
        children: [
          if (inProgress.isNotEmpty) ...[
            _SectionHeader(
              emoji: '📖',
              title: 'Đang đọc',
              count: inProgress.length,
            ),
            ...inProgress.map(
              (f) => _SwipeableCard(
                file: f,
                onTap: () => _openFile(f),
                onLongPress: () => _showFileOptions(f),
                onDismiss: () => _removeFile(f),
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (newFiles.isNotEmpty) ...[
            _SectionHeader(
              emoji: '🆕',
              title: 'Chưa đọc',
              count: newFiles.length,
            ),
            ...newFiles.map(
              (f) => _SwipeableCard(
                file: f,
                onTap: () => _openFile(f),
                onLongPress: () => _showFileOptions(f),
                onDismiss: () => _removeFile(f),
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (completed.isNotEmpty) ...[
            _SectionHeader(
              emoji: '✅',
              title: 'Đã hoàn thành',
              count: completed.length,
            ),
            ...completed.map(
              (f) => _SwipeableCard(
                file: f,
                onTap: () => _openFile(f),
                onLongPress: () => _showFileOptions(f),
                onDismiss: () => _removeFile(f),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // TAB 1: CLOUD
  // ═══════════════════════════════════════════════════════════

  Widget _buildCloudTab() {
    final svc = TextLibraryService();

    if (!svc.isAvailable) {
      return _buildInfoEmpty(
        icon: Icons.cloud_off_outlined,
        title: 'Chưa đăng nhập',
        subtitle: 'Đăng nhập Google để xem thư viện Cloud',
      );
    }

    return StreamBuilder<List<TextLibraryEntry>>(
      stream: svc.watchAll(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF2196F3),
              strokeWidth: 2,
            ),
          );
        }

        final all = snap.data ?? [];

        // Apply search
        final items = _searchQuery.isEmpty
            ? all
            : all.where((e) {
                final q = _searchQuery.toLowerCase();
                return e.title.toLowerCase().contains(q) ||
                    (e.category?.toLowerCase().contains(q) ?? false);
              }).toList();

        if (all.isEmpty) {
          return _buildInfoEmpty(
            icon: Icons.library_books_outlined,
            title: 'Cloud trống',
            subtitle: 'Vuốt trái để mở TextLibraryDrawer\nvà thêm văn bản',
          );
        }

        if (items.isEmpty) {
          return _buildSearchEmpty(_searchQuery);
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _CloudEntryTile(
            entry: items[i],
            onTap: () => _loadCloudEntry(items[i]),
          ),
        );
      },
    );
  }

  Future<void> _loadCloudEntry(TextLibraryEntry entry) async {
    try {
      final tp = context.read<TextProvider>();
      tp.loadFromString(
        entry.content,
        title: entry.title,
        sourceType: TextSourceType.cloud,
        cloudId: entry.id,
        category: entry.category,
      );

      // Issue2: apply saved translations
      try {
        final targetLang = tp.translationTargetLanguage.translationCode;
        final saved = entry.getTranslationsForLang(targetLang);
        if (saved != null) {
          tp.applySavedTranslations(saved, targetLang);
        }
      } catch (e) {
        debugPrint('⚠️ _loadCloudEntry apply translations error: $e');
      }

      final file = RecentFile.fromCloud(
        id: entry.id,
        title: entry.title,
        category: entry.category,
        totalLines: entry.lineCount,
      );
      await _service.addOrUpdate(file);
      if (!mounted) return;

      _tabCtrl.animateTo(0);
      await _load();
    } catch (e, st) {
      debugPrint('❌ _loadCloudEntry error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi mở Cloud: $e')),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  // TAB 2: THIẾT BỊ (Device)
  // ═══════════════════════════════════════════════════════════

  Widget _buildDeviceTab() {
    return _DeviceTab(
      searchQuery: _searchQuery,
      onFilePicked: (file) async {
        await _service.addOrUpdate(file);
        await _load();
        if (mounted) _tabCtrl.animateTo(0);
      },
      onOpenFile: _openFile,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // EMPTY STATES
  // ═══════════════════════════════════════════════════════════

  Widget _buildRecentEmptyState() {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isVerySmall = constraints.maxWidth < 360;
          final horizontalPad = isVerySmall ? 20.0 : 40.0;
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPad),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.elasticOut,
                    builder: (_, v, child) =>
                        Transform.scale(scale: v, child: child),
                    child: Text(
                      '📚',
                      style: TextStyle(fontSize: isVerySmall ? 56 : 72),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Thư viện đang trống',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isVerySmall ? 18 : 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nhấn "Thêm tài liệu" bên dưới\nhoặc chọn tab Cloud / Thiết bị',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.42),
                      fontSize: isVerySmall ? 12 : 14,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Responsive button – Wrap ensures no yellow-black overflow on small screens
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * 0.9,
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _showAddSheet,
                          icon:
                              const Icon(Icons.add_rounded, color: Colors.white),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              isVerySmall
                                  ? 'Thêm tài liệu'
                                  : 'Thêm tài liệu đầu tiên',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1565C0),
                            padding: EdgeInsets.symmetric(
                              horizontal: isVerySmall ? 20 : 28,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchEmpty(String query) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 48,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 12),
          Text(
            context.uiText('Không tìm thấy "$query"'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Thử từ khóa khác',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoEmpty({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// DEVICE TAB WIDGET
// ═══════════════════════════════════════════════════════════

class _DeviceTab extends StatefulWidget {
  final String searchQuery;
  final Future<void> Function(RecentFile) onFilePicked;
  final Future<void> Function(RecentFile) onOpenFile;

  const _DeviceTab({
    required this.searchQuery,
    required this.onFilePicked,
    required this.onOpenFile,
  });

  @override
  State<_DeviceTab> createState() => _DeviceTabState();
}

class _DeviceTabState extends State<_DeviceTab> {
  bool _picking = false;

  Future<void> _pickFile({required bool isPdf}) async {
    setState(() => _picking = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: isPdf
            ? ['pdf']
            : const ['txt', 'lrc', 'srt', 'md', 'markdown', 'json', 'docx'],
        allowMultiple: false,
      );

      if (result == null || result.files.single.path == null) return;
      if (!mounted) return;

      final path = result.files.single.path!;
      final file = isPdf
          ? RecentFile.fromLocalPdf(path)
          : RecentFile.fromLocalText(path);

      await widget.onFilePicked(file);
      if (!mounted) return;

      // Mở ngay sau khi pick
      await widget.onOpenFile(file);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        // ── Info text ────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Colors.white.withValues(alpha: 0.4),
                size: 16,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Chọn file từ thiết bị để thêm vào thư viện\nvà tự động mở',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Pick PDF ─────────────────────────────────────────
        _DevicePickButton(
          icon: Icons.picture_as_pdf_rounded,
          label: 'Mở file PDF',
          subtitle: 'Định dạng .pdf',
          color: const Color(0xFFEF5350),
          loading: _picking,
          onTap: () => _pickFile(isPdf: true),
        ),
        const SizedBox(height: 10),

        // ── Pick Text ─────────────────────────────────────────
        _DevicePickButton(
          icon: Icons.text_snippet_rounded,
          label: 'Mở file văn bản',
          subtitle: 'Định dạng .txt · .lrc · .srt',
          color: const Color(0xFF4CAF50),
          loading: _picking,
          onTap: () => _pickFile(isPdf: false),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// SUB-WIDGETS
// ═══════════════════════════════════════════════════════════

// ── Swipeable Card (Dismissible wrapper) ─────────────────
class _SwipeableCard extends StatelessWidget {
  final RecentFile file;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Future<void> Function() onDismiss;

  const _SwipeableCard({
    required this.file,
    required this.onTap,
    required this.onLongPress,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('${file.id}_${file.lastOpened.millisecondsSinceEpoch}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: Colors.red, size: 20),
            SizedBox(width: 6),
            Text(
              'Xóa',
              style: TextStyle(
                color: Colors.red,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        await onDismiss();
        return false; // Service xử lý UI update
      },
      child: RecentFileCard(
        file: file,
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}

// ── Cloud Entry Tile ─────────────────────────────────────
class _CloudEntryTile extends StatelessWidget {
  final TextLibraryEntry entry;
  final VoidCallback onTap;

  const _CloudEntryTile({
    required this.entry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: Color(0xFF2196F3).withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D3060), Color(0xFF1565C0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text('☁️', style: TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (entry.category != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xFF6C63FF).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            entry.category!,
                            style: const TextStyle(
                              color: Color(0xFF9C8FFF),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        context.uiText('${entry.wordCount} từ · ${entry.lineCount} dòng'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Device Pick Button ───────────────────────────────────
class _DevicePickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final bool loading;
  final VoidCallback onTap;

  const _DevicePickButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading
          ? null
          : () {
              HapticFeedback.mediumImpact();
              onTap();
            },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: loading
                  ? Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: color,
                        ),
                      ),
                    )
                  : Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: color.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab Badge ────────────────────────────────────────────
class _TabBadge extends StatelessWidget {
  final int count;
  const _TabBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ── Header Icon Button ───────────────────────────────────
class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

// ── Section Header ───────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String emoji;
  final String title;
  final int count;

  const _SectionHeader({
    required this.emoji,
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
