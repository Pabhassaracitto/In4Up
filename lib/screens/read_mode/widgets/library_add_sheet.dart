// lib/screens/read_mode/widgets/library_add_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LibraryAddSheet extends StatelessWidget {
  final VoidCallback onAddManualText;
  final VoidCallback onPickLocalText;
  final VoidCallback onPickPdf;
  final VoidCallback onOpenCloud;

  const LibraryAddSheet({
    super.key,
    required this.onAddManualText,
    required this.onPickLocalText,
    required this.onPickPdf,
    required this.onOpenCloud,
  });

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onAddManualText,
    required VoidCallback onPickLocalText,
    required VoidCallback onPickPdf,
    required VoidCallback onOpenCloud,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => LibraryAddSheet(
        onAddManualText: onAddManualText,
        onPickLocalText: onPickLocalText,
        onPickPdf: onPickPdf,
        onOpenCloud: onOpenCloud,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141D2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
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
          const SizedBox(height: 20),

          // Title
          const Row(
            children: [
              Icon(Icons.add_circle_outline,
                  color: Color(0xFF2196F3), size: 20),
              SizedBox(width: 8),
              Text(
                'Thêm tài liệu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ── Option 1: Nhập tay ──────────────────────────────
          _OptionTile(
            icon: Icons.cloud_download_rounded,
            label: 'Thư viện Cloud',
            description: 'Chọn từ văn bản đã lưu', // ← sửa text
            color: const Color(0xFF2196F3),
            onTap: () {
              Navigator.pop(context);
              onOpenCloud();
            },
          ),
          const SizedBox(height: 10),

          // ── Option 2: File TXT/LRC/SRT ──────────────────────
          _OptionTile(
            icon: Icons.upload_file_rounded,
            label: 'File từ thiết bị',
            description: 'TXT · LRC · SRT',
            color: const Color(0xFF4CAF50),
            onTap: () {
              Navigator.pop(context);
              onPickLocalText();
            },
          ),
          const SizedBox(height: 10),

          // ── Option 3: PDF ────────────────────────────────────
          _OptionTile(
            icon: Icons.picture_as_pdf_rounded,
            label: 'File PDF',
            description: 'Sách · Bài giảng · Tài liệu',
            color: const Color(0xFFEF5350),
            onTap: () {
              Navigator.pop(context);
              onPickPdf();
            },
          ),
          const SizedBox(height: 10),

          // ── Option 4: Cloud ──────────────────────────────────
          _OptionTile(
            icon: Icons.cloud_download_rounded,
            label: 'Thư viện Cloud',
            description: 'Văn bản đã lưu trên Firebase',
            color: const Color(0xFF2196F3),
            onTap: () {
              Navigator.pop(context);
              onOpenCloud();
            },
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: color.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Icon box
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),

            // Text
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
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Arrow
            Icon(
              Icons.chevron_right,
              size: 18,
              color: color.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
