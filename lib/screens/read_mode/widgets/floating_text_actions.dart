// lib/screens/read_mode/widgets/floating_text_actions.dart

import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../models/vocab_context.dart';
import '../../../providers/text_provider.dart';
import '../../../providers/vocabulary_provider.dart';
import '../controllers/read_mode_controller.dart';
import '../sheets/create_segment_sheet.dart';

class FloatingTextActions {
  FloatingTextActions._();

  /// Hiện floating action bar cho text đã chọn
  static void show(BuildContext context, String selectedText, int lineIndex) {
    final controller = context.read<ReadModeController>();
    controller.removeFloatingMenu(); // Xóa menu cũ

    final entry = OverlayEntry(
      builder: (overlayContext) => Positioned(
        bottom: 100,
        left: 16,
        right: 16,
        child: _FloatingBar(
          selectedText: selectedText,
          lineIndex: lineIndex,
          onDismiss: () => controller.removeFloatingMenu(),
        ),
      ),
    );

    controller.showFloatingMenu(entry, context);
  }
}

class _FloatingBar extends StatelessWidget {
  final String selectedText;
  final int lineIndex;
  final VoidCallback onDismiss;

  const _FloatingBar({
    required this.selectedText,
    required this.lineIndex,
    required this.onDismiss,
  });
  void _saveSelectionToWordlist(BuildContext context) {
    final vocabProvider = context.read<VocabularyProvider>();
    final tp = context.read<TextProvider>();

    final selectedInfo = tp.selectedTextInfo;
    final resolvedLineIndex = selectedInfo?.lineIndex ?? lineIndex;
    final title = tp.currentDocument?.title ?? 'Text Studio';
    final lineContent = resolvedLineIndex < tp.lines.length
        ? tp.lines[resolvedLineIndex].content
        : selectedText;

    final ctx = VocabContext.fromStory(
      storyTitle: title,
      lineIndex: resolvedLineIndex,
      surroundingText: lineContent,
      sourceRef: tp.currentContextSourceRef,
      sourceRefType: tp.currentContextSourceRefType,
      anchorText: (selectedInfo?.text ?? selectedText).trim(),
      textStartOffset: selectedInfo?.startOffset,
      textEndOffset: selectedInfo?.endOffset,
    );

    vocabProvider.addWithAutoClassify(
      text: selectedText.trim(),
      meaning: '',
      context: ctx,
    );

    tp.clearSelection();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.library_add_check,
                color: Color(0xFF4CAF50), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '"${selectedText.length > 20 ? '${selectedText.substring(0, 20)}...' : selectedText}" → Wordlist',
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2A2A3E),
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A3E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Preview text
              Expanded(
                child: Text(
                  selectedText.length > 30
                      ? '"${selectedText.substring(0, 30)}..."'
                      : '"$selectedText"',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),

              // TTS
              _ActionBtn(
                icon: Icons.volume_up,
                color: const Color(0xFF2196F3),
                tooltip: context.uiText('Phát âm'),
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.read<TextProvider>().speakSelected();
                  onDismiss();
                },
              ),
              const SizedBox(width: 6),

              // Bookmark
              _ActionBtn(
                icon: Icons.bookmark_add,
                color: Colors.amber,
                tooltip: context.uiText('Lưu học'),
                onTap: () {
                  HapticFeedback.lightImpact();
                  onDismiss();
                  CreateSegmentSheet.show(context, lineIndex);
                },
              ),
              const SizedBox(width: 6),
              _ActionBtn(
                icon: Icons.library_add,
                color: const Color(0xFF4CAF50),
                tooltip: context.uiText('Lưu Wordlist'),
                onTap: () {
                  HapticFeedback.lightImpact();
                  _saveSelectionToWordlist(context);
                  onDismiss();
                },
              ),
              // Copy
              _ActionBtn(
                icon: Icons.copy,
                color: Colors.grey,
                tooltip: context.uiText('Sao chép'),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Clipboard.setData(ClipboardData(text: selectedText));
                  onDismiss();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('📋 Đã sao chép!'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
              const SizedBox(width: 6),

              // Close
              _ActionBtn(
                icon: Icons.close,
                color: Colors.grey[600]!,
                tooltip: context.uiText('Đóng'),
                onTap: () {
                  context.read<TextProvider>().clearSelection();
                  onDismiss();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.uiText(tooltip),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}
