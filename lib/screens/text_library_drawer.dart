//
// Mở rộng từ file cũ — thêm 2 tab:
//   📁 Máy     — file local (.txt/.lrc/.srt) như trước
//   ☁️ Thư viện — văn bản người dùng tự tạo, lưu Firebase
//
// Khi chọn bất kỳ văn bản nào → load vào TextProvider → đóng drawer

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../features/pdf_reader/pdf_reader_screen.dart';
import '../features/youtube/youtube_sheet.dart';
import '../providers/text_provider.dart';
import '../services/text_library_service.dart';
//news
import 'read_mode/models/recent_file.dart';
import 'read_mode/services/recent_files_service.dart';
import 'text_library/local_text_entry_dialog.dart';
import 'text_library/text_entry_dialog.dart';
import 'package:in4up/core/language/tr_extension.dart';

class TextLibraryDrawer extends StatefulWidget {
  const TextLibraryDrawer({super.key});

  @override
  State<TextLibraryDrawer> createState() => _TextLibraryDrawerState();
}

class _TextLibraryDrawerState extends State<TextLibraryDrawer>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF0D1520),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _LocalTab(onClose: () => Navigator.pop(context)),
                  _CloudTab(
                    searchQuery: _searchQuery,
                    onSearchChanged: (q) => setState(() => _searchQuery = q),
                    onClose: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF2196F3).withValues(alpha: 0.15),
            Colors.transparent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Color(0xFF2196F3).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.menu_book, color: Color(0xFF2196F3), size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TrText('Thư viện Đọc', style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TrText('Văn bản · Hội thoại · Transcript', style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab Bar ───────────────────────────────────────────────
  Widget _buildTabBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 320;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabCtrl,
            indicator: BoxDecoration(
              color: const Color(0xFF2196F3).withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: const Color(0xFF2196F3).withValues(alpha: 0.4),
              ),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: const Color(0xFF2196F3),
            unselectedLabelColor: Colors.grey,
            labelStyle:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
            labelPadding: EdgeInsets.symmetric(horizontal: compact ? 4 : 8),
            tabs: [
              _drawerTab(Icons.folder_outlined, 'Content', compact),
              _drawerTab(Icons.cloud_outlined, 'Library', compact),
            ],
          ),
        );
      },
    );
  }

  Tab _drawerTab(IconData icon, String label, bool compact) {
    return Tab(
      height: compact ? 34 : 38,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 14 : 16),
            SizedBox(width: compact ? 4 : 6),
            Text(label, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────
  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.swipe, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 6),
          TrText('Vuốt từ cạnh trái để mở', style: TextStyle(color: Colors.grey[700], fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Tab 1: FILE LOCAL
// ─────────────────────────────────────────────────────────────
class _LocalTab extends StatelessWidget {
  final VoidCallback onClose;
  const _LocalTab({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Consumer<TextProvider>(
      builder: (context, tp, _) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 430;
                      final tiles = [
                        _ActionButton(
                          icon: Icons.upload_file,
                          label: 'Import',
                          color: const Color(0xFF2196F3),
                          onTap: () => _importTextFile(context),
                        ),
                        _ActionButton(
                          icon: Icons.content_paste_rounded,
                          label: context.tr('Dán tay'),
                          color: const Color(0xFF26C6DA),
                          onTap: () => _openManualEntryDialog(context),
                        ),
                        _ActionButton(
                          icon: Icons.play_circle_fill,
                          label: 'YouTube',
                          color: const Color(0xFFFF0000),
                          onTap: () => YoutubeSheet.show(context, captionsFirst: true),
                        ),
                        _ActionButton(
                          icon: Icons.picture_as_pdf,
                          label: context.tr('Mở PDF'),
                          color: const Color(0xFFEF5350),
                          onTap: () => _importPdfFile(context),
                        ),
                        _ActionButton(
                          icon: Icons.cloud_upload_outlined,
                          label: context.tr('Lưu mới lên Cloud'),
                          color: const Color(0xFF6C63FF),
                          onTap: () => _uploadCurrentTextToCloud(context, tp),
                        ),
                        _ActionButton(
                          icon: Icons.cloud_sync_outlined,
                          label: tp.isCurrentTextFromCloud
                              ? 'Content'
                              : 'Content',
                          color: const Color(0xFF7E57C2),
                          onTap: () => tp.isCurrentTextFromCloud
                              ? _updateCurrentCloudDirectly(context, tp)
                              : _updateCurrentTextOnCloud(context, tp),
                        ),
                      ];

                      if (compact) {
                        return Column(
                          children: [
                            for (int i = 0; i < tiles.length; i++) ...[
                              tiles[i],
                              if (i != tiles.length - 1) const SizedBox(height: 8),
                            ],
                          ],
                        );
                      }

                      return Column(
                        children: [
                          for (int i = 0; i < tiles.length; i += 2) ...[
                            Row(
                              children: [
                                Expanded(child: tiles[i]),
                                const SizedBox(width: 8),
                                Expanded(child: tiles[i + 1]),
                              ],
                            ),
                            if (i < tiles.length - 2) const SizedBox(height: 8),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
            Expanded(
              child: !tp.hasLyrics
                  ? const _EmptyState(
                      icon: Icons.text_snippet_outlined,
                      title: context.tr('Chưa có văn bản'),
                      subtitle: context.tr('Import file TXT/LRC/SRT, dán tay hoặc tải nội dung lên cloud'),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        _TextCard(
                          title: tp.currentTextPath?.split('/').last ??
                              tp.currentDocument?.title ??
                              'Content',
                          subtitle: 'Content',
                          icon: Icons.description_outlined,
                          color: const Color(0xFF2196F3),
                          isActive: true,
                          onTap: onClose,
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _importPdfFile(BuildContext context) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.single.path == null) return;

    final path = result.files.single.path!;
    if (!context.mounted) return;

    // ★ THÊM: Lưu vào recent trước khi navigate
    final file = RecentFile.fromLocalPdf(path);
    await RecentFilesService().addOrUpdate(file);

    if (context.mounted) {
      onClose();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfReaderScreen(pdfPath: path),
        ),
      );
    }
  }

  Future<void> _importTextFile(BuildContext context) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'lrc', 'srt'],
    );
    if (result == null || result.files.single.path == null) return;

    final path = result.files.single.path!;
    if (!context.mounted) return;

    final tp = context.read<TextProvider>();
    await tp.loadTextFile(path);

    if (context.mounted) {
      final file = RecentFile.fromLocalText(path).copyWith(
        totalLines: tp.lines.length,
      );
      await RecentFilesService().addOrUpdate(file);
    }

    onClose();
  }

  Future<void> _openManualEntryDialog(BuildContext context) async {
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;
    final draft = await showDialog<LocalTextDraft>(
      context: context,
      builder: (_) => LocalTextEntryDialog(
        allowUploadToCloud: isLoggedIn,
        titleText: 'Enter',
        confirmText: isLoggedIn ? 'Content' : 'Content',
      ),
    );

    if (draft == null || !context.mounted) return;

    final tp = context.read<TextProvider>();
    tp.loadFromString(draft.content, title: draft.title);

    if (draft.uploadToCloud) {
      final entry = await TextLibraryService().add(
        title: draft.title,
        content: draft.content,
        category: draft.category,
      );
      if (entry != null) {
        await RecentFilesService().addOrUpdate(
          RecentFile.fromCloud(
            id: entry.id,
            title: entry.title,
            category: entry.category,
            totalLines: entry.lineCount,
          ),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: TrTrText('Đã nạp văn bản và lưu lên cloud')),
          );
        }
      }
    }

    if (context.mounted) onClose();
  }

  ({String title, String content})? _currentTextPayload(TextProvider tp) {
    final content = tp.fullText.trim().isNotEmpty
        ? tp.fullText.trim()
        : tp.lines.map((e) => e.content).join('\n').trim();
    if (content.isEmpty) return null;

    final title = tp.currentDocument?.title ??
        tp.currentTextPath?.split('/').last ??
        'Content';
    return (title: title, content: content);
  }

  Future<void> _uploadCurrentTextToCloud(
    BuildContext context,
    TextProvider tp,
  ) async {
    final payload = _currentTextPayload(tp);
    if (payload == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TrTrText('Chưa có văn bản hiện tại để đưa lên cloud')),
      );
      return;
    }

    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TrTrText('Cần đăng nhập Google để lưu thư viện cloud')),
      );
      return;
    }

    final entry = await showDialog<TextLibraryEntry>(
      context: context,
      builder: (_) => TextEntryDialog(
        initialTitle: payload.title,
        initialContent: payload.content,
        initialCategory: null,
      ),
    );

    if (entry != null && context.mounted) {
      await RecentFilesService().addOrUpdate(
        RecentFile.fromCloud(
          id: entry.id,
          title: entry.title,
          category: entry.category,
          totalLines: entry.lineCount,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã lưu "${entry.title}" lên cloud')),
      );
    }
  }

  Future<void> _updateCurrentCloudDirectly(
    BuildContext context,
    TextProvider tp,
  ) async {
    final payload = _currentTextPayload(tp);
    if (payload == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TrTrText('Chưa có văn bản hiện tại để cập nhật cloud')),
      );
      return;
    }
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TrTrText('Cần đăng nhập Google để cập nhật file cloud hiện tại')),
      );
      return;
    }
    if (tp.currentCloudId == null) {
      await _updateCurrentTextOnCloud(context, tp);
      return;
    }

    final entry = await TextLibraryService().getById(tp.currentCloudId!);
    if (!context.mounted) return;
    if (entry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TrTrText('Không tìm thấy file cloud hiện tại, hãy chọn file khác để cập nhật')),
      );
      await _updateCurrentTextOnCloud(context, tp);
      return;
    }

    final updated = await showDialog<TextLibraryEntry>(
      context: context,
      builder: (_) => TextEntryDialog(
        entry: entry,
        initialTitle: payload.title,
        initialContent: payload.content,
        initialCategory: tp.currentTextCategory ?? entry.category,
        preferInitialValues: true,
      ),
    );

    if (updated != null && context.mounted) {
      await RecentFilesService().addOrUpdate(
        RecentFile.fromCloud(
          id: updated.id,
          title: updated.title,
          category: updated.category,
          totalLines: updated.lineCount,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã cập nhật trực tiếp file cloud "${updated.title}"')),
      );
    }
  }

  Future<void> _updateCurrentTextOnCloud(
    BuildContext context,
    TextProvider tp,
  ) async {
    final payload = _currentTextPayload(tp);
    if (payload == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TrTrText('Chưa có văn bản hiện tại để cập nhật cloud')),
      );
      return;
    }

    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TrTrText('Cần đăng nhập Google để cập nhật thư viện cloud')),
      );
      return;
    }

    final entries = await TextLibraryService().fetchAll();
    if (!context.mounted) return;
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TrTrText('Cloud chưa có file nào để cập nhật')),
      );
      return;
    }

    final selected = await showModalBottomSheet<TextLibraryEntry>(
      context: context,
      backgroundColor: const Color(0xFF0D1520),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TrText('Chọn file cloud để cập nhật', style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const TrText('Nội dung hiện tại sẽ được nạp vào form sửa của file cloud bạn chọn.', style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 360,
                child: ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (_, i) {
                    final entry = entries[i];
                    return ListTile(
                      leading: const Icon(Icons.cloud_done_outlined,
                          color: Color(0xFF2196F3)),
                      title: Text(entry.title,
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text(
                        entry.category ?? 'Content',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      onTap: () => Navigator.pop(sheetCtx, entry),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected == null || !context.mounted) return;

    final updatedEntry = await showDialog<TextLibraryEntry>(
      context: context,
      builder: (_) => TextEntryDialog(
        entry: selected,
        initialTitle: payload.title,
        initialContent: payload.content,
        initialCategory: selected.category,
        preferInitialValues: true,
      ),
    );

    if (updatedEntry != null && context.mounted) {
      await RecentFilesService().addOrUpdate(
        RecentFile.fromCloud(
          id: updatedEntry.id,
          title: updatedEntry.title,
          category: updatedEntry.category,
          totalLines: updatedEntry.lineCount,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã cập nhật file cloud "${updatedEntry.title}"')),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Tab 2: CLOUD LIBRARY
// ─────────────────────────────────────────────────────────────
class _CloudTab extends StatefulWidget {
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClose;

  const _CloudTab({
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onClose,
  });

  @override
  State<_CloudTab> createState() => _CloudTabState();
}

class _CloudTabState extends State<_CloudTab> {
  final _svc = TextLibraryService();
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Load văn bản vào TextProvider ─────────────────────────
  void _loadEntry(BuildContext context, TextLibraryEntry entry) {
    HapticFeedback.mediumImpact();

    // Load text vào TextProvider
    context.read<TextProvider>().loadFromString(
          entry.content,
          title: entry.title,
          sourceType: TextSourceType.cloud,
          cloudId: entry.id,
          category: entry.category,
        );

    // ★ THÊM: Lưu vào RecentFiles để hiện trong thư viện đọc
    final file = RecentFile.fromCloud(
      id: entry.id,
      title: entry.title,
      category: entry.category,
      totalLines: entry.lineCount,
    );
    // Fire-and-forget
    RecentFilesService().addOrUpdate(file);

    widget.onClose();
  }

  // ── Mở dialog thêm mới ────────────────────────────────────
  Future<void> _openAddDialog(BuildContext context) async {
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;

    if (!isLoggedIn) {
      _showLoginRequired(context);
      return;
    }

    await showDialog<TextLibraryEntry>(
      context: context,
      builder: (_) => const TextEntryDialog(),
    );
  }

  // ── Mở dialog sửa ─────────────────────────────────────────
  Future<void> _openEditDialog(
      BuildContext context, TextLibraryEntry entry) async {
    final updated = await showDialog<TextLibraryEntry>(
      context: context,
      builder: (_) => TextEntryDialog(entry: entry),
    );
    if (updated != null) {
      await RecentFilesService().addOrUpdate(
        RecentFile.fromCloud(
          id: updated.id,
          title: updated.title,
          category: updated.category,
          totalLines: updated.lineCount,
        ),
      );
    }
  }

  Future<void> _updateEntryFromCurrentText(
    BuildContext context,
    TextLibraryEntry entry,
  ) async {
    final tp = context.read<TextProvider>();
    final content = tp.fullText.trim().isNotEmpty
        ? tp.fullText.trim()
        : tp.lines.map((e) => e.content).join('\n').trim();

    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TrTrText('Chưa có văn bản hiện tại để cập nhật vào cloud')),
      );
      return;
    }

    final title = tp.currentDocument?.title ?? entry.title;
    final updated = await showDialog<TextLibraryEntry>(
      context: context,
      builder: (_) => TextEntryDialog(
        entry: entry,
        initialTitle: title,
        initialContent: content,
        initialCategory: tp.currentTextCategory ?? entry.category,
        preferInitialValues: true,
      ),
    );

    if (updated != null && context.mounted) {
      await RecentFilesService().addOrUpdate(
        RecentFile.fromCloud(
          id: updated.id,
          title: updated.title,
          category: updated.category,
          totalLines: updated.lineCount,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã cập nhật "${updated.title}" từ văn bản hiện tại')),
      );
    }
  }

  // ── Xác nhận xoá ─────────────────────────────────────────
  Future<void> _confirmDelete(
      BuildContext context, TextLibraryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1520),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const TrText('Xoá văn bản?', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(
          '"${entry.title}" sẽ bị xoá khỏi thư viện cloud.',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const TrText(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const TrText('Xoá', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _svc.delete(entry.id);
      HapticFeedback.heavyImpact();
    }
  }

  void _showLoginRequired(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.cloud_off, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: TrTrText('Không có phiên đăng nhập hợp lệ để lưu cloud'),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A237E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: context.tr('Đăng nhập'),
          textColor: const Color(0xFF82B1FF),
          onPressed: () {
            // AuthService().signInWithGoogle(context) nếu muốn trigger thẳng
          },
        ),
      ),
    );
  }

  Widget _buildCloudHintBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF2196F3).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2196F3).withValues(alpha: 0.16),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.tips_and_updates_outlined,
              color: Color(0xFF82B1FF), size: 16),
          SizedBox(width: 8),
          Expanded(
            child: TrText('Chạm để mở vào Đọc · nút bút chì để sửa tên/chủ đề/nội dung · nút đồng bộ để cập nhật file cloud bằng văn bản hiện tại.', style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Search + Add button ──────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              Expanded(child: _buildSearchBar()),
              const SizedBox(width: 8),
              _AddButton(onTap: () => _openAddDialog(context)),
            ],
          ),
        ),

        Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
        _buildCloudHintBar(),

        // ── List từ Firestore ────────────────────────────────
        Expanded(
          child: StreamBuilder<List<TextLibraryEntry>>(
            stream: _svc.watchAll(),
            builder: (context, snap) {
              // Chưa đăng nhập
              if (!_svc.isAvailable) {
                return const _EmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: context.l10n.msgNotLoggedIn,
                  subtitle: context.tr('Đăng nhập Google để dùng thư viện cloud'),
                );
              }

              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF2196F3),
                    strokeWidth: 2,
                  ),
                );
              }

              final all = snap.data ?? [];

              // Filter search
              final items = widget.searchQuery.isEmpty
                  ? all
                  : all
                      .where((e) =>
                          e.title
                              .toLowerCase()
                              .contains(widget.searchQuery.toLowerCase()) ||
                          (e.category
                                  ?.toLowerCase()
                                  .contains(widget.searchQuery.toLowerCase()) ??
                              false))
                      .toList();

              if (items.isEmpty && all.isEmpty) {
                return _EmptyState(
                  // Removed const
                  icon: Icons.library_books_outlined,
                  title: context.tr('Thư viện trống'),
                  subtitle: context.tr('Nhấn + để thêm văn bản đầu tiên'),
                  action: TextButton.icon(
                    onPressed: () => _openAddDialog(context),
                    icon: const Icon(Icons.add, size: 16), // Already const
                    label: const TrTrText('Thêm ngay'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF2196F3),
                    ),
                  ),
                );
              }

              if (items.isEmpty) {
                return _EmptyState(
                  // Removed const
                  icon: Icons.search_off,
                  title: context.tr('Không tìm thấy'),
                  subtitle: '"${widget.searchQuery}"',
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                itemCount: items.length,
                itemBuilder: (_, i) => _CloudEntryCard(
                  entry: items[i],
                  onTap: () => _loadEntry(context, items[i]),
                  onEdit: () => _openEditDialog(context, items[i]),
                  onSyncFromCurrent: () => _updateEntryFromCurrentText(context, items[i]),
                  onDelete: () => _confirmDelete(context, items[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: context.tr('Tìm theo tiêu đề, chủ đề...'),
          hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
          prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 16),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey[600], size: 14),
                  onPressed: () {
                    _searchCtrl.clear();
                    widget.onSearchChanged('');
                  },
                  padding: EdgeInsets.zero,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        onChanged: widget.onSearchChanged,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Cloud Entry Card (có swipe-to-delete)
// ─────────────────────────────────────────────────────────────
class _CloudEntryCard extends StatelessWidget {
  final TextLibraryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onSyncFromCurrent;
  final VoidCallback onDelete;

  const _CloudEntryCard({
    required this.entry,
    required this.onTap,
    required this.onEdit,
    required this.onSyncFromCurrent,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // Để service xử lý, không tự dismiss
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color(0xFF2196F3).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.article_outlined,
                    color: Color(0xFF2196F3),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // Text info
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
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (entry.category != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C63FF)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                entry.category!,
                                style: const TextStyle(
                                  color: Color(0xFF9C8FFF),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          Text(
                            'Content',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: context.tr('Sửa thông tin file cloud'),
                      onPressed: onEdit,
                      icon: Icon(
                        Icons.edit_outlined,
                        color: Colors.grey[500],
                        size: 18,
                      ),
                    ),
                    IconButton(
                      tooltip: context.tr('Cập nhật file cloud bằng văn bản hiện tại'),
                      onPressed: onSyncFromCurrent,
                      icon: const Icon(
                        Icons.cloud_sync_outlined,
                        color: Color(0xFF82B1FF),
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Shared Widgets
// ─────────────────────────────────────────────────────────────

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF2196F3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF2196F3).withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 20),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 170;
          return Container(
            padding: EdgeInsets.symmetric(vertical: compact ? 10 : 11, horizontal: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: compact
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 18, color: color),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: color, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 16, color: color),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: color, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _TextCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _TextCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border:
              isActive ? Border.all(color: color.withValues(alpha: 0.4)) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: isActive ? color : Colors.grey, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.white70,
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
                ],
              ),
            ),
            if (isActive) Icon(Icons.check_circle, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: Colors.grey[700]),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}