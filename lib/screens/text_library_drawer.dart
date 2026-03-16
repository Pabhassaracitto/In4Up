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

import '../providers/text_provider.dart';
import '../services/text_library_service.dart';
import '../widgets/youtube_caption_download_dialog.dart';
import 'text_library/text_entry_dialog.dart';

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
            const Color(0xFF2196F3).withValues(alpha: 0.15),
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
              color: const Color(0xFF2196F3).withValues(alpha: 0.2),
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
                Text(
                  'Thư viện Text',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Văn bản · Hội thoại · Transcript',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
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
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        tabs: const [
          Tab(icon: Icon(Icons.folder_outlined, size: 16), text: 'Máy'),
          Tab(icon: Icon(Icons.cloud_outlined, size: 16), text: 'Thư viện'),
        ],
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
          Text(
            'Vuốt từ cạnh trái để mở',
            style: TextStyle(color: Colors.grey[700], fontSize: 11),
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
    return Column(
      children: [
        // Actions
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.upload_file,
                  label: 'Import',
                  color: const Color(0xFF2196F3),
                  onTap: () => _importTextFile(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.play_circle_fill,
                  label: 'YouTube Lyrics',
                  color: const Color(0xFFFF0000),
                  onTap: () => YoutubeCaptionDownloadDialog.show(context),
                ),
              ),
            ],
          ),
        ),

        Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),

        // List
        Expanded(
          child: Consumer<TextProvider>(
            builder: (context, tp, _) {
              if (!tp.hasLyrics)
                return _EmptyState(
                  icon: Icons.text_snippet_outlined,
                  title: 'Chưa có văn bản',
                  subtitle: 'Import file TXT, LRC, hoặc SRT',
                );
              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _TextCard(
                    title: tp.currentTextPath?.split('/').last ??
                        tp.currentDocument?.title ??
                        'Văn bản hiện tại',
                    subtitle: '${tp.lines.length} dòng',
                    icon: Icons.description_outlined,
                    color: const Color(0xFF2196F3),
                    isActive: true,
                    onTap: onClose,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _importTextFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'lrc', 'srt'],
    );
    if (result != null && result.files.single.path != null) {
      if (context.mounted) {
        await context
            .read<TextProvider>()
            .loadTextFile(result.files.single.path!);
        HapticFeedback.mediumImpact();
        if (context.mounted) Navigator.pop(context);
      }
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
    context.read<TextProvider>().loadFromString(
          entry.content,
          title: entry.title,
        );
    widget.onClose();
  }

  // ── Mở dialog thêm mới ────────────────────────────────────
  Future<void> _openAddDialog(BuildContext context) async {
    final isLoggedIn = FirebaseAuth.instance.currentUser != null &&
        !(FirebaseAuth.instance.currentUser!.isAnonymous);

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
    await showDialog<TextLibraryEntry>(
      context: context,
      builder: (_) => TextEntryDialog(entry: entry),
    );
  }

  // ── Xác nhận xoá ─────────────────────────────────────────
  Future<void> _confirmDelete(
      BuildContext context, TextLibraryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1520),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xoá văn bản?',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(
          '"${entry.title}" sẽ bị xoá khỏi thư viện cloud.',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá', style: TextStyle(color: Colors.red)),
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
              child: Text('Đăng nhập Google để lưu văn bản lên cloud'),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A237E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'Đăng nhập',
          textColor: const Color(0xFF82B1FF),
          onPressed: () {
            // AuthService().signInWithGoogle(context) nếu muốn trigger thẳng
          },
        ),
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

        // ── List từ Firestore ────────────────────────────────
        Expanded(
          child: StreamBuilder<List<TextLibraryEntry>>(
            stream: _svc.watchAll(),
            builder: (context, snap) {
              // Chưa đăng nhập
              if (!_svc.isAvailable) {
                return _EmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Chưa đăng nhập',
                  subtitle: 'Đăng nhập Google để dùng thư viện cloud',
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
                  icon: Icons.library_books_outlined,
                  title: 'Thư viện trống',
                  subtitle: 'Nhấn + để thêm văn bản đầu tiên',
                  action: TextButton.icon(
                    onPressed: () => _openAddDialog(context),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Thêm ngay'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF2196F3),
                    ),
                  ),
                );
              }

              if (items.isEmpty) {
                return _EmptyState(
                  icon: Icons.search_off,
                  title: 'Không tìm thấy',
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
          hintText: 'Tìm theo tiêu đề, chủ đề...',
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
  final VoidCallback onDelete;

  const _CloudEntryCard({
    required this.entry,
    required this.onTap,
    required this.onEdit,
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
                    color: const Color(0xFF2196F3).withValues(alpha: 0.12),
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
                      Row(
                        children: [
                          if (entry.category != null) ...[
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
                            const SizedBox(width: 6),
                          ],
                          Text(
                            '${entry.wordCount} từ · ${entry.lineCount} dòng',
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

                // Edit button
                GestureDetector(
                  onTap: onEdit,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.edit_outlined,
                      color: Colors.grey[600],
                      size: 16,
                    ),
                  ),
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
              color: const Color(0xFF2196F3).withValues(alpha: 0.3),
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
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
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
