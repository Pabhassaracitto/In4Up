import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';

import '../../../models/color_mode.dart';
import '../pdf_reader_controller.dart';

class PdfToolbar extends StatelessWidget {
  final PdfReaderController controller;
  final String title;
  final VoidCallback? onUserInteraction;
  final VoidCallback? onShowAnnotations;
  final VoidCallback? onOpenGrammarSettings;

  const PdfToolbar({
    super.key,
    required this.controller,
    required this.title,
    this.onUserInteraction,
    this.onShowAnnotations,
    this.onOpenGrammarSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 4,
        left: 8,
        right: 8,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
        ),
      ),
      child: Row(
        children: [
          // ← Back
          IconButton(
            onPressed: () {
              onUserInteraction?.call();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back_ios_new,
                size: 18, color: Colors.white70),
          ),

          // Title
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Page counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${controller.currentPage + 1} / ${controller.totalPages}',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white60,
                fontFamily: 'monospace',
              ),
            ),
          ),

          const SizedBox(width: 6),

          // Color mode cycle button
          _ColorModeButton(
            controller: controller,
            onUserInteraction: onUserInteraction,
          ),

          const SizedBox(width: 4),

          // View mode toggle
          _ViewModeButton(
            controller: controller,
            onUserInteraction: onUserInteraction,
          ),

          const SizedBox(width: 4),

          // More options
          _MoreButton(
            controller: controller,
            onUserInteraction: onUserInteraction,
            onShowAnnotations: onShowAnnotations,
            onOpenGrammarSettings: onOpenGrammarSettings,
          ),
        ],
      ),
    );
  }
}

// ── Color Mode Button ─────────────────────────────────────

class _ColorModeButton extends StatelessWidget {
  final PdfReaderController controller;
  final VoidCallback? onUserInteraction;

  const _ColorModeButton({
    required this.controller,
    this.onUserInteraction,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = controller.colorMode != ColorMode.none;
    final showGrammarBadge =
        controller.colorMode == ColorMode.wordType && controller.grammarSettings.enabled;
    return GestureDetector(
      onTap: () {
        onUserInteraction?.call();
        HapticFeedback.selectionClick();
        controller.cycleColorMode();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? Color(0xFF2196F3).withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: isActive
              ? Border.all(color: Color(0xFF2196F3).withValues(alpha: 0.4))
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              controller.colorMode.icon,
              size: 13,
              color: isActive ? const Color(0xFF2196F3) : Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              context.uiText(controller.colorMode.label),
              style: TextStyle(
                fontSize: 10,
                color: isActive ? const Color(0xFF2196F3) : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (showGrammarBadge && MediaQuery.of(context).size.width >= 700) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  controller.activeGrammarPreset.name,
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

// ── View Mode Button ──────────────────────────────────────

class _ViewModeButton extends StatelessWidget {
  final PdfReaderController controller;
  final VoidCallback? onUserInteraction;

  const _ViewModeButton({
    required this.controller,
    this.onUserInteraction,
  });

  @override
  Widget build(BuildContext context) {
    final isPdf = controller.viewMode == PdfViewMode.pdfView;
    return GestureDetector(
      onTap: () {
        onUserInteraction?.call();
        HapticFeedback.selectionClick();
        if (isPdf) {
          controller.switchToTextMode();
        } else {
          controller.switchToPdfMode();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isPdf ? Icons.text_fields : Icons.picture_as_pdf,
          size: 16,
          color: Colors.white70,
        ),
      ),
    );
  }
}

// ── More Options ─────────────────────────────────────────

class _MoreButton extends StatelessWidget {
  final PdfReaderController controller;
  final VoidCallback? onUserInteraction;
  final VoidCallback? onShowAnnotations;
  final VoidCallback? onOpenGrammarSettings;

  const _MoreButton({
    required this.controller,
    this.onUserInteraction,
    this.onShowAnnotations,
    this.onOpenGrammarSettings,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onUserInteraction?.call();
        _showOptionsSheet(context);
      },
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.more_vert, size: 16, color: Colors.white70),
      ),
    );
  }

  void _showOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PdfOptionsSheet(
        controller: controller,
        onShowAnnotations: onShowAnnotations,
        onOpenGrammarSettings: onOpenGrammarSettings,
      ),
    );
  }
}

class _PdfOptionsSheet extends StatelessWidget {
  final PdfReaderController controller;
  final VoidCallback? onShowAnnotations;
  final VoidCallback? onOpenGrammarSettings;

  const _PdfOptionsSheet({
    required this.controller,
    this.onShowAnnotations,
    this.onOpenGrammarSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Text('Tùy chọn',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),

          const SizedBox(height: 16),

          // TTS Language
          const Text('Giọng đọc',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          _TtsLanguageSelector(controller: controller),

          const SizedBox(height: 16),

          // TTS Speed
          const Text('Tốc độ đọc',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          _TtsSpeedSlider(controller: controller),

          const SizedBox(height: 8),

          if (controller.colorMode == ColorMode.wordType) ...[
            ListTile(
              leading: const Icon(Icons.auto_awesome_motion, color: Color(0xFF6C63FF)),
              title: const Text(
                'Từ loại chuyên sâu',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                controller.activeGrammarPreset.name,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white54),
              onTap: () {
                Navigator.pop(context);
                onOpenGrammarSettings?.call();
              },
            ),
            const SizedBox(height: 8),
          ],

          // Annotations count
          ListTile(
            leading: const Icon(Icons.note_alt_outlined, color: Colors.amber),
            title: Text(
              context.uiText('${controller.annotations.length} ghi chú'),
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Mở danh sách để xem, sửa hoặc xoá ghi chú đã lưu',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
            trailing: controller.annotations.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.list, color: Colors.grey),
                    onPressed: () {
                      Navigator.pop(context);
                      onShowAnnotations?.call();
                    },
                  ),
            onTap: controller.annotations.isEmpty
                ? null
                : () {
                    Navigator.pop(context);
                    onShowAnnotations?.call();
                  },
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

class _TtsLanguageSelector extends StatelessWidget {
  final PdfReaderController controller;
  const _TtsLanguageSelector({required this.controller});

  @override
  Widget build(BuildContext context) {
    final options = [
      ('en-US', '🇺🇸 Tiếng Anh'),
      ('vi-VN', '🇻🇳 Tiếng Việt'),
      ('bilingual', '🔀 Song ngữ'),
    ];

    return Wrap(
      spacing: 8,
      children: options.map((opt) {
        final isSelected = controller.ttsLanguage == opt.$1;
        return GestureDetector(
          onTap: () => controller.setTtsLanguage(opt.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF2196F3)
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              opt.$2,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontSize: 12,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TtsSpeedSlider extends StatelessWidget {
  final PdfReaderController controller;
  const _TtsSpeedSlider({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('0.5x', style: TextStyle(color: Colors.grey, fontSize: 11)),
        Expanded(
          child: Slider(
            value: controller.ttsSpeed,
            min: 0.5,
            max: 1.5,
            divisions: 10,
            activeColor: const Color(0xFF2196F3),
            inactiveColor: Colors.white12,
            onChanged: controller.setTtsSpeed,
          ),
        ),
        Text(
          '${controller.ttsSpeed.toStringAsFixed(1)}x',
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
      ],
    );
  }
}
