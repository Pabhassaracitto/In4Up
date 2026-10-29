// lib/features/ocr/ocr_source_sheet.dart
//
// Sheet chọn nguồn ảnh cho OCR (ADR-0009 · KANBAN OCR-001).
//
// Chỉ hiện nguồn KHẢ DỤNG theo nền tảng:
// - Document Scanner: CHỈ Android (Google Beta, phát qua Play services,
//   không cần quyền camera).
// - Chọn ảnh có sẵn: Android + iOS (file_picker — iOS dùng PHPicker nên
//   không cần NSPhotoLibraryUsageDescription).
//
// i18n (rule vàng #5): mọi literal tiếng Việt trong file này đều là giá trị
// `vi` của ARB (đã dịch đủ 26 locale) — shim `Text`/`uiText` tự dịch.
// KHÔNG thêm literal mới chưa phân loại: generator
// tool/generate_legacy_ui_fallbacks.py sẽ fail.

import 'package:in4up/core/language/localized_material.dart';

import 'ocr_service.dart';

class OcrSourceSheet extends StatelessWidget {
  const OcrSourceSheet({super.key});

  /// Mở sheet chọn nguồn. Trả về null nếu user đóng mà không chọn.
  static Future<OcrImageSource?> show(BuildContext context) {
    return showModalBottomSheet<OcrImageSource>(
      context: context,
      backgroundColor: const Color(0xFF0D1520),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const OcrSourceSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sources = OcrService.instance.availableSources;
    return SafeArea(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF26C6DA).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.document_scanner_outlined,
                      color: Color(0xFF26C6DA),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Quét ảnh thành văn bản',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey[500], size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            for (final source in sources)
              _SourceTile(
                source: source,
                onTap: () => Navigator.of(context).pop(source),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final OcrImageSource source;
  final VoidCallback onTap;

  const _SourceTile({required this.source, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isScanner = source == OcrImageSource.documentScanner;
    final color = isScanner ? const Color(0xFF26C6DA) : const Color(0xFF6C63FF);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Material(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(
                  isScanner
                      ? Icons.photo_camera_outlined
                      : Icons.image_outlined,
                  color: color,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isScanner ? 'Chụp & quét tài liệu' : 'Chọn ảnh có sẵn',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isScanner
                            ? 'Tự dò mép, crop, lọc ảnh · chỉ Android'
                            : 'Ảnh chụp trang sách hoặc ảnh scan',
                        style: TextStyle(color: Colors.grey[500], fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[600], size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
