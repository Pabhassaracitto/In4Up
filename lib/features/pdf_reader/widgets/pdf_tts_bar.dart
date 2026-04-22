import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../pdf_reader_controller.dart';

class PdfTtsBar extends StatelessWidget {
  final PdfReaderController controller;

  const PdfTtsBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final isPlaying = controller.ttsState == PdfTtsState.playing;
    final isLoading = controller.ttsState == PdfTtsState.loading;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
        ),
      ),
      child: Row(
        children: [
          // Progress text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _langLabel(controller.ttsLanguage),
                  style: TextStyle(color: Colors.grey[600], fontSize: 10),
                ),
                const SizedBox(height: 2),
                LinearProgressIndicator(
                  value: controller.totalPages > 0
                      ? (controller.currentPage + 1) / controller.totalPages
                      : 0,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF2196F3)),
                  minHeight: 2,
                  borderRadius: BorderRadius.circular(1),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Prev page
          _BarBtn(
            icon: Icons.skip_previous_rounded,
            onTap: controller.currentPage > 0
                ? () {
                    HapticFeedback.selectionClick();
                    // Controlled via PdfViewer's controller externally
                    // Signal via a callback if needed
                  }
                : null,
          ),

          const SizedBox(width: 8),

          // Play/Stop main button
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              controller.speakCurrentPage();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isPlaying
                    ? const Color(0xFFEF5350)
                    : const Color(0xFF2196F3),
                boxShadow: [
                  BoxShadow(
                    color: (isPlaying
                            ? const Color(0xFFEF5350)
                            : const Color(0xFF2196F3))
                        .withValues(alpha: 0.35),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Icon(
                      isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
            ),
          ),

          const SizedBox(width: 8),

          // Next page
          _BarBtn(
            icon: Icons.skip_next_rounded,
            onTap: controller.currentPage < controller.totalPages - 1
                ? () => HapticFeedback.selectionClick()
                : null,
          ),

          const SizedBox(width: 12),

          // Speed indicator
          GestureDetector(
            onTap: () => _showSpeedPicker(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${controller.ttsSpeed.toStringAsFixed(1)}x',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _langLabel(String lang) {
    switch (lang) {
      case 'en-US':
        return '🇺🇸 English';
      case 'vi-VN':
        return '🇻🇳 Tiếng Việt';
      case 'bilingual':
        return '🔀 Song ngữ EN → VN';
      default:
        return lang;
    }
  }

  void _showSpeedPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Tốc độ đọc',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [0.5, 0.7, 0.9, 1.0, 1.2, 1.5].map((speed) {
                final isSelected = (controller.ttsSpeed - speed).abs() < 0.05;
                return GestureDetector(
                  onTap: () {
                    controller.setTtsSpeed(speed);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF2196F3)
                          : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${speed}x',
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }
}

class _BarBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _BarBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: onTap != null ? 0.07 : 0.03),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: onTap != null ? Colors.white70 : Colors.grey[700],
        ),
      ),
    );
  }
}
