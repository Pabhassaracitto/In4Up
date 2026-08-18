// lib/screens/read_mode/widgets/floating_text_actions.dart

import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../models/vocab_context.dart';
import '../../../models/word_entry.dart';
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

  void _saveQuick(BuildContext context) {
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
            const Icon(Icons.bolt, color: Color(0xFF4CAF50), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '\"${selectedText.length > 20 ? '${selectedText.substring(0, 20)}...' : selectedText}\" → Đã lưu nhanh',
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

  void _saveFull(BuildContext context) {
    onDismiss();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _FullSaveSheet(
        selectedText: selectedText,
        lineIndex: lineIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPhrase = selectedText.trim().split(RegExp(r'\s+')).length > 1;

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
              // Preview text - flexible, not expanded to allow actions to scroll
              Flexible(
                child: Text(
                  selectedText.length > 30
                      ? '\"${selectedText.substring(0, 30)}...\"'
                      : '\"$selectedText\"',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),

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

              // Quick save (bolt) - luu nhanh
              _ActionBtn(
                icon: Icons.bolt,
                color: const Color(0xFF4CAF50),
                tooltip: context.uiText('Lưu nhanh'),
                onTap: () {
                  HapticFeedback.lightImpact();
                  _saveQuick(context);
                  onDismiss();
                },
              ),
              const SizedBox(width: 6),

                      // Full save (+ nghĩa + gợi ý) - luu day du
                      _ActionBtn(
                        icon: Icons.edit_note,
                        color: const Color(0xFF9C27B0),
                        tooltip: isPhrase ? 'Lưu đủ (cụm/câu + gợi ý)' : 'Lưu đủ + nghĩa',
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          _saveFull(context);
                        },
                      ),
                      const SizedBox(width: 6),

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

class _FullSaveSheet extends StatefulWidget {
  final String selectedText;
  final int lineIndex;

  const _FullSaveSheet({required this.selectedText, required this.lineIndex});

  @override
  State<_FullSaveSheet> createState() => _FullSaveSheetState();
}

class _FullSaveSheetState extends State<_FullSaveSheet> {
  final _meaningCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  List<WordEntry> _related = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRelated());
  }

  void _loadRelated() {
    try {
      final vocab = context.read<VocabularyProvider>();
      final selLower = widget.selectedText.toLowerCase().trim();
      final selWords = selLower.split(RegExp(r'\s+')).where((w) => w.length > 2).toSet();

      final candidates = vocab.allWords.where((entry) {
        final wLower = entry.word.toLowerCase();
        if (wLower == selLower) return false;
        if (selLower.contains(wLower) || wLower.contains(selLower)) return true;
        final entryWords = wLower.split(RegExp(r'\s+')).where((w) => w.length > 2).toSet();
        return selWords.intersection(entryWords).isNotEmpty;
      }).toList();

      candidates.sort((a, b) => b.encounterCount.compareTo(a.encounterCount));
      setState(() => _related = candidates.take(8).toList());
    } catch (_) {}
  }

  void _doSave() {
    final vocabProvider = context.read<VocabularyProvider>();
    final tp = context.read<TextProvider>();
    final selectedInfo = tp.selectedTextInfo;
    final resolvedLineIndex = selectedInfo?.lineIndex ?? widget.lineIndex;
    final title = tp.currentDocument?.title ?? 'Text Studio';
    final lineContent = resolvedLineIndex < tp.lines.length
        ? tp.lines[resolvedLineIndex].content
        : widget.selectedText;

    final ctx = VocabContext.fromStory(
      storyTitle: title,
      lineIndex: resolvedLineIndex,
      surroundingText: lineContent,
      sourceRef: tp.currentContextSourceRef,
      sourceRefType: tp.currentContextSourceRefType,
      anchorText: (selectedInfo?.text ?? widget.selectedText).trim(),
      textStartOffset: selectedInfo?.startOffset,
      textEndOffset: selectedInfo?.endOffset,
    );

    final meaning = _meaningCtrl.text.trim();
    final note = _noteCtrl.text.trim();

    vocabProvider.addWithAutoClassify(
      text: widget.selectedText.trim(),
      meaning: meaning,
      context: ctx,
    );

    if (note.isNotEmpty) {
      final created = vocabProvider.findByWord(widget.selectedText.trim());
      if (created != null) {
        vocabProvider.updateNotes(created.id, note);
      }
    }

    tp.clearSelection();
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.library_add_check, color: Color(0xFF9C27B0), size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('\"${widget.selectedText}\" đã lưu đầy đủ')),
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
  void dispose() {
    _meaningCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPhrase = widget.selectedText.trim().split(RegExp(r'\s+')).length > 1;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C27B0).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.edit_note, color: Color(0xFF9C27B0)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPhrase ? 'Lưu cụm/câu đầy đủ' : 'Lưu từ đầy đủ',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '\"${widget.selectedText}\"',
                        style: TextStyle(color: Colors.grey[400], fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _meaningCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Nghĩa / dịch (tuỳ chọn)',
                hintText: isPhrase ? 'Nhập nghĩa cụm/câu...' : 'Nhập nghĩa từ...',
                labelStyle: TextStyle(color: Colors.grey[400]),
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF9C27B0)),
                ),
              ),
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Ghi chú cá nhân',
                hintText: 'Ví dụ, ngữ cảnh, mẹo nhớ...',
                labelStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.03),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              minLines: 1,
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            if (_related.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.hub_outlined, size: 16, color: Color(0xFF4CAF50)),
                  const SizedBox(width: 6),
                  Text(
                    'Cụm/từ liên đới (${_related.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _related.map((e) {
                  return GestureDetector(
                    onTap: () {
                      if (e.meaning.trim().isNotEmpty) {
                        _meaningCtrl.text = e.meaning;
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: e.vocabType.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: e.vocabType.color.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            e.word,
                            style: TextStyle(
                              color: e.vocabType.color,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (e.meaning.trim().isNotEmpty) ...[
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 100),
                              child: Text(
                                e.meaning,
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 10,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Hủy'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[400],
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _doSave,
                    icon: const Icon(Icons.save_alt, size: 18),
                    label: const Text('Lưu đầy đủ'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF9C27B0),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
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
