// lib/screens/read_mode/widgets/read_bottom_bar.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../providers/text_provider.dart';
import '../../../providers/player_provider.dart';
import '../controllers/read_mode_controller.dart';
import '../sheets/segments_list_sheet.dart';

class ReadBottomBar extends StatelessWidget {
  final VoidCallback? onToggleWordlist; // ← MỚI
  final bool showWordlistPanel; // ← MỚI

  const ReadBottomBar({
    super.key,
    this.onToggleWordlist,
    this.showWordlistPanel = false,
  });

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TextProvider>();
    context.watch<PlayerProvider>();
    final controller = context.watch<ReadModeController>();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Reading Progress Bar
            _ReadingProgressBar(progress: controller.readingProgress),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Font Size
                  _BarAction(
                    icon: Icons.text_decrease,
                    onTap: () => tp.setFontSize(tp.fontSize - 2),
                  ),
                  _BarAction(
                    icon: Icons.text_increase,
                    onTap: () => tp.setFontSize(tp.fontSize + 2),
                  ),

                  // Translation toggle
                  _BarAction(
                    icon: Icons.translate,
                    isActive: tp.showTranslation,
                    activeThumbColor: const Color(0xFF4CAF50),
                    onTap: () => tp.toggleTranslation(),
                  ),

                  // TTS current line
                  _BarAction(
                    icon: tp.isSpeaking
                        ? Icons.stop_circle_outlined
                        : Icons.record_voice_over,
                    isActive: tp.isSpeaking,
                    activeThumbColor: Colors.orange,
                    onTap: () {
                      if (tp.isSpeaking) {
                        tp.stopSpeaking();
                      } else {
                        tp.speakCurrentLine();
                      }
                    },
                  ),

                  // Segments (Bookmarks)
                  _BarAction(
                    icon: Icons.bookmark,
                    isActive: tp.segments.isNotEmpty,
                    activeThumbColor: Colors.amber,
                    badge:
                        tp.segments.isNotEmpty ? '${tp.segments.length}' : null,
                    onTap: () => SegmentsListSheet.show(context),
                  ),
                  _BarAction(
                    icon: showWordlistPanel
                        ? Icons.view_sidebar
                        : Icons.view_sidebar_outlined,
                    isActive: showWordlistPanel,
                    activeThumbColor: const Color(0xFF6C63FF),
                    onTap: () => onToggleWordlist?.call(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadingProgressBar extends StatelessWidget {
  final double progress;
  const _ReadingProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: LinearProgressIndicator(
        value: progress,
        backgroundColor: Colors.white.withValues(alpha: 0.05),
        valueColor: AlwaysStoppedAnimation(
          Color.lerp(
            const Color(0xFF2196F3),
            const Color(0xFF4CAF50),
            progress,
          )!,
        ),
        minHeight: 3,
      ),
    );
  }
}

class _BarAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;
  final Color? activeThumbColor;
  final String? badge;

  const _BarAction({
    required this.icon,
    required this.onTap,
    this.isActive = false,
    this.activeThumbColor,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isActive ? (activeThumbColor ?? const Color(0xFF2196F3)) : Colors.grey;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(10),
            decoration: isActive
                ? BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  )
                : null,
            child: Icon(icon, color: color, size: 22),
          ),
          if (badge != null)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: activeThumbColor ?? Colors.amber,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
