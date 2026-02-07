// lib/screens/read_mode/widgets/read_top_bar.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../providers/text_provider.dart';
import '../controllers/read_mode_controller.dart';
import '../sheets/read_settings_sheet.dart';

class ReadTopBar extends StatelessWidget {
  const ReadTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final textProvider = context.watch<TextProvider>();
    final controller = context.watch<ReadModeController>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: Row(
        children: [
          // Title + Reading progress
          Expanded(
            child: Row(
              children: [
                const Text(
                  'Text Studio',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                // Dòng hiện tại / tổng
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
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
            ),
          ),

          // Color Mode Chip
          _ColorModeChip(textProvider: textProvider),

          const SizedBox(width: 8),

          // Auto-sync indicator
          _AutoSyncChip(controller: controller),

          const SizedBox(width: 8),

          // Settings
          GestureDetector(
            onTap: () => ReadSettingsSheet.show(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.tune, size: 18, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

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
              ? const Color(0xFF2196F3).withOpacity(0.2)
              : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: isActive
              ? Border.all(color: const Color(0xFF2196F3).withOpacity(0.3))
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
              ? const Color(0xFF4CAF50).withOpacity(0.2)
              : Colors.white.withOpacity(0.08),
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
