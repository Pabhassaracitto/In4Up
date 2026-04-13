// lib/screens/read_mode/widgets/read_top_bar.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../providers/text_provider.dart';
import '../../../models/color_mode.dart';
import '../controllers/read_mode_controller.dart';
import '../sheets/read_settings_sheet.dart';
import 'quick_library_sheet.dart'; // ← THÊM

class ReadTopBar extends StatelessWidget {
  const ReadTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TextProvider>();
    final controller = context.watch<ReadModeController>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Row(
        children: [
          // ── Title bấm được → QuickLibrarySheet ──────────────
          _TitleButton(tp: tp, controller: controller),

          const Spacer(),

          // ── Color Mode ───────────────────────────────────────
          _ColorModeChip(textProvider: tp),
          const SizedBox(width: 8),

          // ── Auto Sync ────────────────────────────────────────
          _AutoSyncChip(controller: controller),
          const SizedBox(width: 8),

          // ── Settings ─────────────────────────────────────────
          GestureDetector(
            onTap: () => ReadSettingsSheet.show(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.tune,
                size: 18,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Title Button ──────────────────────────────────────────────
// Bấm → mở QuickLibrarySheet để đổi tài liệu nhanh
class _TitleButton extends StatelessWidget {
  final TextProvider tp;
  final ReadModeController controller;

  const _TitleButton({
    required this.tp,
    required this.controller,
  });

  /// Tên tài liệu hiện tại — cắt ngắn nếu quá dài
  String get _displayTitle {
    // 1. Từ document title
    final docTitle = tp.currentDocument?.title;
    if (docTitle != null && docTitle.isNotEmpty && docTitle != 'Untitled') {
      return docTitle.length > 20 ? '${docTitle.substring(0, 20)}…' : docTitle;
    }

    // 2. Từ file path
    final path = tp.currentTextPath;
    if (path != null) {
      final name = path.split('/').last.split('\\').last;
      final nameNoExt =
          name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name;
      return nameNoExt.length > 20
          ? '${nameNoExt.substring(0, 20)}…'
          : nameNoExt;
    }

    // 3. Fallback
    return 'Text Studio';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Nút title bấm được ─────────────────────────────────
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            QuickLibrarySheet.show(context);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF2196F3).withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon sách
                const Icon(
                  Icons.menu_book_rounded,
                  size: 13,
                  color: Color(0xFF2196F3),
                ),
                const SizedBox(width: 6),

                // Tên tài liệu
                Text(
                  _displayTitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 4),

                // Mũi tên dropdown
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 15,
                  color: Color(0xFF2196F3),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 8),

        // ── Progress chip: dòng hiện tại / tổng ───────────────
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 7,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            controller.readingProgressText,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}

// ── Color Mode Chip ───────────────────────────────────────────
// Giữ nguyên từ file cũ
class _ColorModeChip extends StatelessWidget {
  final TextProvider textProvider;
  const _ColorModeChip({required this.textProvider});

  @override
  Widget build(BuildContext context) {
    final isActive = textProvider.colorMode != ColorMode.none;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        textProvider.cycleColorMode();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF2196F3).withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: isActive
              ? Border.all(
                  color: const Color(0xFF2196F3).withValues(alpha: 0.3),
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              textProvider.colorMode.icon,
              size: 14,
              color: isActive ? const Color(0xFF2196F3) : Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              textProvider.colorMode.label,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? const Color(0xFF2196F3) : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Auto Sync Chip ────────────────────────────────────────────
// Giữ nguyên từ file cũ
class _AutoSyncChip extends StatelessWidget {
  final ReadModeController controller;
  const _AutoSyncChip({required this.controller});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => controller.toggleAutoSync(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: controller.autoSyncEnabled
              ? const Color(0xFF4CAF50).withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          controller.autoSyncEnabled ? Icons.sync : Icons.sync_disabled,
          size: 16,
          color: controller.autoSyncEnabled
              ? const Color(0xFF4CAF50)
              : Colors.grey,
        ),
      ),
    );
  }
}
