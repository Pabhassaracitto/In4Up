//
// Sheet hiện danh sách văn bản Cloud để chọn nhanh
// Dùng cho:
//   1. LibraryAddSheet → "Thư viện Cloud"
//   2. QuickLibrarySheet → cloud item

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../providers/text_provider.dart';
import '../../../services/text_library_service.dart';
import '../models/recent_file.dart';
import '../services/recent_files_service.dart';

class CloudPickerSheet extends StatefulWidget {
  const CloudPickerSheet({super.key});

  /// Hiện sheet — trả về true nếu đã load thành công
  static Future<bool> show(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const CloudPickerSheet(),
    );
    return result == true;
  }

  @override
  State<CloudPickerSheet> createState() => _CloudPickerSheetState();
}

class _CloudPickerSheetState extends State<CloudPickerSheet> {
  final _svc = TextLibraryService();
  final _recentSvc = RecentFilesService();
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Load entry vào TextProvider + lưu recent ─────────────
  Future<void> _selectEntry(TextLibraryEntry entry) async {
    final tp = context.read<TextProvider>();

    // Load content
    tp.loadFromString(entry.content, title: entry.title);

    // Lưu vào recent
    final file = RecentFile.fromCloud(
      id: entry.id,
      title: entry.title,
      category: entry.category,
      totalLines: entry.lineCount,
    );
    await _recentSvc.addOrUpdate(file);

    if (!mounted) return;
    // Trả về true → caller biết đã load xong
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      height: screenH * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF141D2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          _buildHeader(),
          _buildSearchBar(),
          const Divider(color: Colors.white12, height: 1),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  // ── Handle ───────────────────────────────────────────────
  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(0xFF2196F3).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.cloud_rounded,
              color: Color(0xFF2196F3),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thư viện Cloud',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Chọn văn bản để đọc',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context, false),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white54,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Search bar ───────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Tìm theo tiêu đề, chủ đề...',
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 12,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: Colors.white.withValues(alpha: 0.4),
              size: 16,
            ),
            suffixIcon: _search.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: Colors.white.withValues(alpha: 0.4),
                      size: 14,
                    ),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _search = '');
                    },
                    padding: EdgeInsets.zero,
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
          onChanged: (v) => setState(() => _search = v),
        ),
      ),
    );
  }

  // ── List ─────────────────────────────────────────────────
  Widget _buildList() {
    if (!_svc.isAvailable) {
      return _buildEmpty(
        icon: Icons.cloud_off_outlined,
        title: 'Chưa đăng nhập',
        subtitle: 'Đăng nhập Google để dùng thư viện Cloud',
      );
    }

    return StreamBuilder<List<TextLibraryEntry>>(
      stream: _svc.watchAll(),
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
        final items = _search.isEmpty
            ? all
            : all.where((e) {
                final q = _search.toLowerCase();
                return e.title.toLowerCase().contains(q) ||
                    (e.category?.toLowerCase().contains(q) ?? false);
              }).toList();

        if (all.isEmpty) {
          return _buildEmpty(
            icon: Icons.library_books_outlined,
            title: 'Thư viện Cloud trống',
            subtitle: 'Thêm văn bản từ tab Đọc → Thư viện',
          );
        }

        if (items.isEmpty) {
          return _buildEmpty(
            icon: Icons.search_off,
            title: 'Không tìm thấy',
            subtitle: '"$_search"',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _CloudEntryTile(
            entry: items[i],
            onTap: () => _selectEntry(items[i]),
          ),
        );
      },
    );
  }

  // ── Empty state ──────────────────────────────────────────
  Widget _buildEmpty({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
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
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
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
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Cloud icon box
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
                      // Category badge
                      if (entry.category != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF6C63FF).withValues(alpha: 0.15),
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
                      // Stats
                      Text(
                        '${entry.wordCount} từ · ${entry.lineCount} dòng',
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

            // Arrow
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
