// lib/screens/read_mode/widgets/quick_library_sheet.dart
//
// Bottom sheet thu gọn — hiện 5 file gần nhất
// Bấm vào file → load ngay, đóng sheet
// Bấm "Xem tất cả" → TextProvider.clearText() → về ReadLibraryScreen

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../features/pdf_reader/pdf_reader_screen.dart';
import '../../../providers/text_provider.dart';
import '../../../services/text_library_service.dart';
import '../models/recent_file.dart';
import '../services/recent_files_service.dart';
import 'cloud_picker_sheet.dart';
import 'package:in4up/core/language/tr_extension.dart';

class QuickLibrarySheet extends StatefulWidget {
  const QuickLibrarySheet({super.key});

  /// Hiện sheet — dùng static helper
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const QuickLibrarySheet(),
    );
  }

  @override
  State<QuickLibrarySheet> createState() => _QuickLibrarySheetState();
}

class _QuickLibrarySheetState extends State<QuickLibrarySheet> {
  final _service = RecentFilesService();
  List<RecentFile> _files = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await _service.getAll();
    if (!mounted) return;
    setState(() {
      // Chỉ lấy 5 file gần nhất
      _files = all.take(5).toList();
      _isLoading = false;
    });
  }

  // ── Mở file ─────────────────────────────────────────────────
  Future<void> _openFile(RecentFile file) async {
    // Lưu refs TRƯỚC khi await
    final tp = context.read<TextProvider>();
    final nav = Navigator.of(context);

    // Đóng sheet trước
    nav.pop();

    switch (file.type) {
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
        if (!mounted) return;

        // Đóng QuickLibrarySheet trước
        Navigator.pop(context);

        // Mở CloudPickerSheet với cloudId được lọc sẵn
        if (file.cloudId != null) {
          // Load trực tiếp từ Firestore theo id
          final svc = TextLibraryService();
          final entry = await svc.getById(file.cloudId!);
          if (!mounted) return;

          if (entry != null) {
            final tp = context.read<TextProvider>();
            tp.loadFromString(
              entry.content,
              title: entry.title,
              sourceType: TextSourceType.cloud,
              cloudId: entry.id,
              category: entry.category,
            );

            // Cập nhật recent
            await _service.addOrUpdate(
              file.copyWith(lastOpened: DateTime.now()),
            );
          } else {
            // Entry bị xóa khỏi cloud → mở CloudPickerSheet để chọn lại
            if (mounted) {
              CloudPickerSheet.show(context);
            }
          }
        }
        break;
    }
  }

  // ── Về thư viện đầy đủ ──────────────────────────────────────
  void _openFullLibrary() {
    final tp = context.read<TextProvider>();
    Navigator.pop(context); // đóng sheet
    // Clear text → ReadModeScreen sẽ tự hiện ReadLibraryScreen
    tp.clearText();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141D2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          _buildHeader(),
          const Divider(color: Colors.white12, height: 1),
          _buildBody(),
          _buildFooter(),
        ],
      ),
    );
  }

  // ── Handle bar ───────────────────────────────────────────────
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

  // ── Header ───────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 12),
      child: Row(
        children: [
          const Text(
            '📚',
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TrText('Đổi tài liệu', style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TrText('Gần đây nhất', style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Nút đóng
          GestureDetector(
            onTap: () => Navigator.pop(context),
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

  // ── Body ─────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF2196F3),
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_files.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(
              Icons.library_books_outlined,
              color: Colors.white.withValues(alpha: 0.2),
              size: 40,
            ),
            const SizedBox(height: 10),
            TrText('Chưa có tài liệu nào', style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _files.length,
      separatorBuilder: (_, __) => const Divider(
        color: Colors.white10,
        height: 1,
        indent: 72,
      ),
      itemBuilder: (_, i) => _QuickFileRow(
        file: _files[i],
        onTap: () => _openFile(_files[i]),
      ),
    );
  }

  // ── Footer ───────────────────────────────────────────────────
  Widget _buildFooter() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            // ── Xem tất cả ───────────────────────
            Expanded(
              child: GestureDetector(
                onTap: _openFullLibrary,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: Color(0xFF1565C0).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Color(0xFF1565C0).withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.grid_view_rounded,
                        color: Color(0xFF2196F3),
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      TrText('Xem tất cả', style: TextStyle(
                          color: Color(0xFF2196F3),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quick File Row ────────────────────────────────────────────
class _QuickFileRow extends StatelessWidget {
  final RecentFile file;
  final VoidCallback onTap;

  const _QuickFileRow({
    required this.file,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // ── Emoji thumbnail ───────────────────
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  file.thumbnailEmoji ?? file.typeEmoji,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // ── Info ──────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.title,
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
                      // Type badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: _typeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          file.typeLabel,
                          style: TextStyle(
                            color: _typeColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Progress text
                      Text(
                        file.progressText,
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

            // ── Progress indicator ────────────────
            if (file.totalLines > 0) ...[
              const SizedBox(width: 10),
              _CircularProgress(value: file.readProgress),
            ],

            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right,
              size: 16,
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ],
        ),
      ),
    );
  }

  List<Color> get _gradientColors {
    switch (file.type) {
      case RecentFileType.localPdf:
        return [const Color(0xFF7B1818), const Color(0xFFBF3030)];
      case RecentFileType.cloud:
        return [const Color(0xFF0D3060), const Color(0xFF1565C0)];
      case RecentFileType.localText:
        return [const Color(0xFF13472E), const Color(0xFF27AE60)];
    }
  }

  Color get _typeColor {
    switch (file.type) {
      case RecentFileType.localPdf:
        return const Color(0xFFEF5350);
      case RecentFileType.cloud:
        return const Color(0xFF2196F3);
      case RecentFileType.localText:
        return const Color(0xFF4CAF50);
    }
  }
}

// ── Circular Progress ─────────────────────────────────────────
class _CircularProgress extends StatelessWidget {
  final double value;
  const _CircularProgress({required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: value.clamp(0.0, 1.0),
            strokeWidth: 2.5,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(_progressColor),
          ),
          Text(
            '${(value * 100).round()}%',
            style: TextStyle(
              color: _progressColor,
              fontSize: 7,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color get _progressColor {
    if (value >= 1.0) return Colors.green;
    if (value > 0.5) return const Color(0xFF2196F3);
    if (value > 0) return const Color(0xFFFF9800);
    return Colors.white38;
  }
}