import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../features/translation/translation_service.dart';
import '../../../services/vocab_classifier.dart';
import '../../../models/vocabulary_type.dart';
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

    final title = tp.currentDocument?.title ?? 'Text Studio';
    final lineContent = lineIndex < tp.lines.length
        ? tp.lines[lineIndex].content
        : selectedText;

    final ctx = VocabContext.fromStory(
      storyTitle: title,
      lineIndex: lineIndex,
      surroundingText: lineContent,
    );

    final type = VocabClassifier.classify(selectedText);
    vocabProvider.addWithAutoClassify(
      text: selectedText.trim(),
      meaning: '',
      context: ctx,
    );

    tp.clearSelection();

    final canDecompose = type != VocabularyType.word;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.library_add_check,
                color: Color(0xFF4ADE80), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '"${selectedText.length > 20 ? '${selectedText.substring(0, 20)}...' : selectedText}" → Wordlist',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E1E2E).withValues(alpha: 0.95),
        duration: const Duration(seconds: 4),
        action: canDecompose
            ? SnackBarAction(
                label: 'PHÂN RÃ 🧩',
                textColor: const Color(0xFF818CF8),
                onPressed: () => _showDecomposeSheet(context, selectedText, ctx),
              )
            : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
    );
  }

  void _showDecomposeSheet(
      BuildContext context, String text, VocabContext vctx) {
    final type = VocabClassifier.classify(text);
    final result = VocabClassifier.decompose(text, type);

    if (result.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161625),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _DecomposeSheet(
        result: result,
        vocabContext: vctx,
      ),
    );
  }

  void _translateSelection(BuildContext context) async {
    final tp = context.read<TextProvider>();
    final result = await TranslationService().translateText(selectedText);

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🌐 ${result.translatedText}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF6C63FF),
          action: SnackBarAction(
            label: 'COPY',
            textColor: Colors.white,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: result.translatedText));
            },
          ),
        ),
      );
    }
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // TTS
              _ActionBtn(
                icon: Icons.volume_up_rounded,
                color: const Color(0xFF64B5F6),
                tooltip: 'Phát âm (TTS)',
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.read<TextProvider>().speakSelected();
                  onDismiss();
                },
              ),
              const _Divider(),

              // Translation
              _ActionBtn(
                icon: Icons.translate_rounded,
                color: const Color(0xFF818CF8),
                tooltip: 'Dịch nghĩa',
                onTap: () {
                  HapticFeedback.lightImpact();
                  _translateSelection(context);
                  onDismiss();
                },
              ),
              const _Divider(),

              // Save to Wordlist (1-Click)
              _ActionBtn(
                icon: Icons.add_task_rounded,
                color: const Color(0xFF4ADE80),
                tooltip: 'Lưu Wordlist',
                onTap: () {
                  HapticFeedback.lightImpact();
                  _saveSelectionToWordlist(context);
                  onDismiss();
                },
              ),
              const _Divider(),

              // Bookmark / Segment
              _ActionBtn(
                icon: Icons.bookmark_add_rounded,
                color: const Color(0xFFFBBF24),
                tooltip: 'Lưu vào Phân đoạn',
                onTap: () {
                  HapticFeedback.lightImpact();
                  onDismiss();
                  CreateSegmentSheet.show(context, lineIndex);
                },
              ),
              const _Divider(),

              // Copy
              _ActionBtn(
                icon: Icons.content_copy_rounded,
                color: Colors.grey[400]!,
                tooltip: 'Sao chép',
                onTap: () {
                  HapticFeedback.lightImpact();
                  Clipboard.setData(ClipboardData(text: selectedText));
                  onDismiss();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('📋 Đã sao chép văn bản!'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),

              const SizedBox(width: 4),
              // Close
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                color: Colors.grey[600],
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
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

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.white.withValues(alpha: 0.1),
    );
  }
}

class _DecomposeSheet extends StatefulWidget {
  final DecomposeResult result;
  final VocabContext vocabContext;

  const _DecomposeSheet({
    required this.result,
    required this.vocabContext,
  });

  @override
  State<_DecomposeSheet> createState() => _DecomposeSheetState();
}

class _DecomposeSheetState extends State<_DecomposeSheet> {
  final Set<String> _addedTokens = {};

  void _addToken(String token) {
    if (_addedTokens.contains(token)) return;

    final provider = context.read<VocabularyProvider>();
    provider.addWithAutoClassify(
      text: token,
      meaning: '',
      context: widget.vocabContext,
    );

    setState(() {
      _addedTokens.add(token);
    });

    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                '🧩 Phân rã tri thức',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Chọn các cụm từ hoặc từ vựng nổi bật để lưu vào Vườn:',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
          const SizedBox(height: 20),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.result.phrases.isNotEmpty) ...[
                    _buildSectionHeader('Cụm từ (Phrases)'),
                    _buildTokenChips(widget.result.phrases),
                    const SizedBox(height: 16),
                  ],
                  if (widget.result.words.isNotEmpty) ...[
                    _buildSectionHeader('Từ vựng (Words)'),
                    _buildTokenChips(widget.result.words),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Xong',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildTokenChips(List<String> tokens) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tokens.map((t) {
        final isAdded = _addedTokens.contains(t);
        return InkWell(
          onTap: () => _addToken(t),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isAdded
                  ? const Color(0xFF4ADE80).withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isAdded
                    ? const Color(0xFF4ADE80).withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t,
                  style: TextStyle(
                    color: isAdded ? const Color(0xFF4ADE80) : Colors.white,
                    fontSize: 13,
                    fontWeight: isAdded ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (isAdded) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.check, size: 14, color: Color(0xFF4ADE80)),
                ],
              ],
            ),
          ),
        );
      }).toList(),
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
      message: tooltip,
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
