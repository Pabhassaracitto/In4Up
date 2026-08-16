// lib/screens/read_mode/widgets/empty_state_widget.dart
// Thay toàn bộ nội dung cũ bằng redirect sang ReadLibraryScreen

import 'package:in4up/core/language/localized_material.dart';

import 'library_screen.dart';

/// ReadEmptyState giờ chỉ là alias trỏ tới ReadLibraryScreen
/// Giữ nguyên tên class để không cần sửa read_mode_screen.dart
class ReadEmptyState extends StatelessWidget {
  const ReadEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const ReadLibraryScreen();
  }
}

// lib/screens/read_mode/widgets/empty_state_widget.dart
/*
import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../../../features/pdf_reader/pdf_reader_screen.dart';
import '../../../providers/text_provider.dart';
import 'library_screen.dart';

class ReadEmptyState extends StatelessWidget {
  const ReadEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(scale: value, child: child);
              },
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Color(0xFF2196F3).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Color(0xFF2196F3).withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.menu_book,
                  size: 64,
                  color: Color(0xFF2196F3),
                ),
              ),
            ),
            const SizedBox(height: 32),

            const Text(
              'Text Studio',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Thêm văn bản để bắt đầu đọc\nHỗ trợ TXT, LRC, SRT',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // Import buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ImportCard(
                  icon: Icons.upload_file,
                  label: 'File TXT',
                  subtitle: 'Plain text',
                  color: const Color(0xFF2196F3),
                  onTap: () => _importFile(context, ['txt']),
                ),
                const SizedBox(width: 12),
                _ImportCard(
                  icon: Icons.music_note,
                  label: 'File LRC',
                  subtitle: 'Có sync thời gian',
                  color: const Color(0xFF4CAF50),
                  onTap: () => _importFile(context, ['lrc', 'srt']),
                ),
                const SizedBox(width: 12),
                _ImportCard(
                  icon: Icons.picture_as_pdf,
                  label: 'File PDF',
                  subtitle: 'Sách, bài giảng',
                  color: const Color(0xFFEF5350),
                  onTap: () => _importFile(context, ['pdf']),
                ),
                const SizedBox(width: 12),
                _ImportCard(
                  icon: Icons.edit_note,
                  label: 'Nhập tay',
                  subtitle: 'Paste văn bản',
                  color: const Color(0xFFFF9800),
                  onTap: () => _showManualInput(context),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Swipe hint
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'Hoặc vuốt từ trái → để mở Thư viện Text',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.swipe_right,
                          color: Colors.grey[700], size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Swipe → mở Text Library',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 11,
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

  Future<void> _importFile(
      BuildContext context, List<String> extensions) async {
    try {
      final result = await FilePicker.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions,
      );

      if (result == null || result.files.single.path == null) return;

      final path = result.files.single.path!;

      if (path.toLowerCase().endsWith('.pdf') && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfReaderScreen(pdfPath: path),
          ),
        );
        return;
      }

      if (context.mounted) {
        await context.read<TextProvider>().loadTextFile(path);
      }
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error importing file: $e');
    }
  }

  void _showManualInput(BuildContext context) {
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.edit_note, color: Color(0xFFFF9800)),
                const SizedBox(width: 8),
                const Text(
                  'Nhập văn bản',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 10,
              autofocus: true,
              style: const TextStyle(color: Colors.white, height: 1.6),
              decoration: InputDecoration(
                hintText: context.uiText(
                  'Paste hoặc nhập văn bản...\n\nMỗi dòng sẽ là 1 đơn vị đọc.\nHỗ trợ tiếng Anh, tiếng Việt, Pali...',
                ),
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Hủy'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (controller.text.trim().isNotEmpty) {
                        context
                            .read<TextProvider>()
                            .loadFromString(controller.text);
                        Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Xác nhận'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
}

class _ImportCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ImportCard({
    required this.icon,
    required this.label,
    required this.subtitle,
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
        width: 95,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey[600], fontSize: 9),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
*/
