// lib/screens/read_mode/widgets/library_screen.dart

import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../features/pdf_reader/pdf_reader_screen.dart';
import '../../../providers/text_provider.dart';
import '../models/recent_file.dart';
import '../services/recent_files_service.dart';
import 'library_add_sheet.dart';
import 'recent_file_card.dart';
import 'cloud_picker_sheet.dart';

class ReadLibraryScreen extends StatefulWidget {
  const ReadLibraryScreen({super.key});

  @override
  State<ReadLibraryScreen> createState() => _ReadLibraryScreenState();
}

class _ReadLibraryScreenState extends State<ReadLibraryScreen>
    with SingleTickerProviderStateMixin {
  final _service = RecentFilesService();

  List<RecentFile> _files = [];
  bool _isLoading = true;

  late final AnimationController _fabAnim;
  late final Animation<double> _fabScale;

  @override
  void initState() {
    super.initState();
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
    _fabAnim.dispose();
    super.dispose();
  }

  // ── Load danh sách ───────────────────────────────────────────
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

  // ── Grouped ──────────────────────────────────────────────────
  List<RecentFile> get _inProgress =>
      _files.where((f) => f.isInProgress).toList();
  List<RecentFile> get _newFiles => _files.where((f) => f.isNew).toList();
  List<RecentFile> get _completed =>
      _files.where((f) => f.isCompleted).toList();

  // ── Mở file ─────────────────────────────────────────────────
  Future<void> _openFile(RecentFile file) async {
    // Lưu reference context-dependent objects TRƯỚC khi await
    final tp = context.read<TextProvider>();
    final nav = Navigator.of(context);

    switch (file.type) {
      case RecentFileType.localText:
        if (file.localPath == null) return;
        // Load file — sau await không dùng context nữa
        await tp.loadTextFile(file.localPath!);
        if (!mounted) return;
        await _service.addOrUpdate(
          file.copyWith(
            lastOpened: DateTime.now(),
            totalLines: tp.lines.length,
          ),
        );
        break;

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

      case RecentFileType.cloud:
        // Hướng dẫn mở TextLibraryDrawer
        if (!mounted) return;
        _showSnack(
          icon: Icons.swipe_right_alt,
          message: 'Vuốt từ trái → để mở Thư viện Cloud',
          color: const Color(0xFF1565C0),
        );
        break;
    }
  }

  // ── Show add sheet ───────────────────────────────────────────
  void _showAddSheet() {
    LibraryAddSheet.show(
      context,
      onAddManualText: _handleManualText,
      onPickLocalText: _handlePickLocalText,
      onPickPdf: _handlePickPdf,
      onOpenCloud: _handleOpenCloud,
    );
  }

  // ── Handler: nhập tay ────────────────────────────────────────
  void _handleManualText() {
    // Không có async ở đây — show dialog đồng bộ
    _showManualInputDialog();
  }

  // ── Handler: pick TXT/LRC/SRT ────────────────────────────────
  Future<void> _handlePickLocalText() async {
    // 1. Lưu ref TRƯỚC khi await
    final tp = context.read<TextProvider>();

    // 2. Mở file picker (async — không dùng context)
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'lrc', 'srt'],
      );
    } catch (e) {
      debugPrint('[LibraryScreen] FilePicker error: $e');
      return;
    }

    if (result == null || result.files.single.path == null) return;
    if (!mounted) return;

    final path = result.files.single.path!;

    // 3. Load file
    await tp.loadTextFile(path);
    if (!mounted) return;

    // 4. Lưu vào recent
    final file = RecentFile.fromLocalText(path).copyWith(
      totalLines: tp.lines.length,
    );
    await _service.addOrUpdate(file);
    if (!mounted) return;

    // 5. Reload list
    await _load();
  }

  // ── Handler: pick PDF ────────────────────────────────────────
  Future<void> _handlePickPdf() async {
    // 1. Lưu Navigator ref TRƯỚC khi await
    final nav = Navigator.of(context);

    // 2. File picker
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
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

    // 3. Lưu vào recent
    final file = RecentFile.fromLocalPdf(path);
    await _service.addOrUpdate(file);
    if (!mounted) return;

    // 4. Reload list
    await _load();
    if (!mounted) return;

    // 5. Mở PDF reader — dùng nav ref đã lưu
    nav.push(MaterialPageRoute(
      builder: (_) => PdfReaderScreen(pdfPath: path),
    ));
  }

  // ── Handler: cloud ───────────────────────────────────────────
  Future<void> _handleOpenCloud() async {
    // Mở CloudPickerSheet
    final loaded = await CloudPickerSheet.show(context);
    if (!mounted) return;

    // Nếu đã load thành công → reload list
    if (loaded) {
      await _load();
    }
  }

  // ── Manual input dialog ──────────────────────────────────────
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
            // Handle
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

            // Header
            const Row(
              children: [
                Icon(Icons.edit_note_rounded,
                    color: Color(0xFFFF9800), size: 20),
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

            // Text field
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
                    'Paste hoặc nhập văn bản...\n\nMỗi dòng = 1 đơn vị đọc.',
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

            // Buttons
            Row(
              children: [
                // Hủy
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

                // Xác nhận
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final text = ctrl.text.trim();
                      if (text.isEmpty) return;

                      // Đóng sheet TRƯỚC
                      Navigator.pop(sheetCtx);

                      // Lưu ref TRƯỚC khi await
                      final tp = context.read<TextProvider>();

                      // Load text
                      tp.loadFromString(text);

                      // Tạo preview title
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
                    icon:
                        const Icon(Icons.check, size: 18, color: Colors.white),
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

  // ── File options (long press) ────────────────────────────────
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
                  Text(file.typeEmoji, style: const TextStyle(fontSize: 18)),
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
                color: Colors.white12, height: 24, indent: 20, endIndent: 20),

            // Mở
            ListTile(
              leading: const Icon(Icons.open_in_new, color: Color(0xFF2196F3)),
              title: const Text(
                'Mở tài liệu',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _openFile(file);
              },
            ),

            // Xóa
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Xóa khỏi danh sách',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                Navigator.pop(context);
                HapticFeedback.heavyImpact();
                await _service.remove(file.id);
                if (mounted) await _load();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Snackbar helper ──────────────────────────────────────────
  void _showSnack({
    required IconData icon,
    required String message,
    required Color color,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1520),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
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

  // ── Header ───────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
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
                  _isLoading
                      ? 'Đang tải...'
                      : _files.isEmpty
                          ? 'Chưa có tài liệu nào'
                          : '${_files.length} tài liệu',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.42),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Refresh button
          if (!_isLoading)
            GestureDetector(
              onTap: _load,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  Icons.refresh_rounded,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Body ─────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF2196F3),
          strokeWidth: 2,
        ),
      );
    }

    if (_files.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFF2196F3),
      backgroundColor: const Color(0xFF1A2235),
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 120),
        children: [
          // ── Đang đọc dang dở
          if (_inProgress.isNotEmpty) ...[
            _SectionHeader(
              emoji: '📖',
              title: 'Đang đọc',
              count: _inProgress.length,
            ),
            ..._inProgress.map((f) => RecentFileCard(
                  file: f,
                  onTap: () => _openFile(f),
                  onLongPress: () => _showFileOptions(f),
                )),
            const SizedBox(height: 4),
          ],

          // ── Chưa đọc
          if (_newFiles.isNotEmpty) ...[
            _SectionHeader(
              emoji: '🆕',
              title: 'Chưa đọc',
              count: _newFiles.length,
            ),
            ..._newFiles.map((f) => RecentFileCard(
                  file: f,
                  onTap: () => _openFile(f),
                  onLongPress: () => _showFileOptions(f),
                )),
            const SizedBox(height: 4),
          ],

          // ── Đã xong
          if (_completed.isNotEmpty) ...[
            _SectionHeader(
              emoji: '✅',
              title: 'Đã hoàn thành',
              count: _completed.length,
            ),
            ..._completed.map((f) => RecentFileCard(
                  file: f,
                  onTap: () => _openFile(f),
                  onLongPress: () => _showFileOptions(f),
                )),
          ],
        ],
      ),
    );
  }

  // ── Empty state ──────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 700),
              curve: Curves.elasticOut,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: const Text(
                '📚',
                style: TextStyle(fontSize: 72),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Thư viện đang trống',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nhấn "Thêm tài liệu" bên dưới\nđể bắt đầu hành trình đọc của bạn',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.42),
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _showAddSheet,
              icon: const Icon(
                Icons.add_rounded,
                color: Colors.white,
              ),
              label: const Text(
                'Thêm tài liệu đầu tiên',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
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
    );
  }
}

// ── Section Header ───────────────────────────────────────────
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
