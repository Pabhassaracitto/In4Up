// lib/screens/read_mode/widgets/read_top_bar.dart

import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../models/color_mode.dart';
import '../../../providers/text_provider.dart';
import '../controllers/read_mode_controller.dart';
import '../sheets/read_settings_sheet.dart';
import 'quick_library_sheet.dart'; // ← THÊM

class ReadTopBar extends StatelessWidget {
  const ReadTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TextProvider>();
    final controller = context.watch<ReadModeController>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final actionRow = compact
            ? Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  _ColorModeChip(textProvider: tp, compact: true),
                  _AutoSyncChip(controller: controller),
                  _SettingsButton(onTap: () => ReadSettingsSheet.show(context)),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ColorModeChip(textProvider: tp),
                  const SizedBox(width: 8),
                  _AutoSyncChip(controller: controller),
                  const SizedBox(width: 8),
                  _SettingsButton(onTap: () => ReadSettingsSheet.show(context)),
                ],
              );

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
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TitleButton(tp: tp, controller: controller),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: actionRow,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _TitleButton(tp: tp, controller: controller),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: actionRow,
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
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
      final name = path.split('/').last.split("\\").last;
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 320;
        return Row(
          children: [
            Flexible(
              fit: FlexFit.loose,
              child: GestureDetector(
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
                      const Icon(
                        Icons.menu_book_rounded,
                        size: 13,
                        color: Color(0xFF2196F3),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 15,
                        color: Color(0xFF2196F3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: 8),
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
          ],
        );
      },
    );
  }
}

// ── Color Mode Chip ───────────────────────────────────────────
// Giữ nguyên từ file cũ
class _ColorModeChip extends StatelessWidget {
  final TextProvider textProvider;
  final bool compact;

  const _ColorModeChip({
    required this.textProvider,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = textProvider.colorMode != ColorMode.none;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final showGrammarBadge =
        !compact &&
        screenWidth >= 520 &&
        textProvider.colorMode == ColorMode.wordType &&
        textProvider.grammarSettings.enabled;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        textProvider.cycleColorMode();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 9 : 10,
          vertical: 6,
        ),
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
            if (showGrammarBadge) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  textProvider.activeGrammarPreset.name,
                  style: const TextStyle(
                    color: Color(0xFFB8B5FF),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SettingsButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
              ? Color(0xFF4CAF50).withValues(alpha: 0.2)
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
