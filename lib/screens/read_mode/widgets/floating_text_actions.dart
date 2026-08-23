// lib/screens/read_mode/widgets/floating_text_actions.dart

import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../models/vocab_context.dart';
import '../../../models/word_entry.dart';
import '../../../providers/text_provider.dart';
import '../../../providers/vocabulary_provider.dart';
import '../../../widgets/vocab_entry_meta.dart';
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
  final _newTopicCtrl = TextEditingController();
  List<WordEntry> _related = [];

  // READ-630 parity (txt source): chủ đề + ngôn ngữ như SelectionSaveSheet
  String? _selectedTopic;
  String _selectedLanguage = 'en';
  WordEntry? _existing;

  @override
  void dispose() {
    _meaningCtrl.dispose();
    _noteCtrl.dispose();
    _newTopicCtrl.dispose();
    super.dispose();
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

      // Entry đã tồn tại → pre-fill nghĩa + note + tag (để update dễ)
      final existing = vocab.findByWord(selLower);

      setState(() {
        _related = candidates.take(8).toList();
        _existing = existing;
        if (existing != null) {
          if (existing.meaning.trim().isNotEmpty) {
            _meaningCtrl.text = existing.meaning;
          }
          if ((existing.personalNotes ?? '').trim().isNotEmpty) {
            _noteCtrl.text = existing.personalNotes!.trim();
          }
          if (existing.topics.isNotEmpty) {
            _selectedTopic = existing.topics.first;
          }
          if (existing.languages.isNotEmpty) {
            _selectedLanguage = existing.languages.first;
          } else if (existing.language.isNotEmpty) {
            _selectedLanguage = existing.language;
          }
        }
      });
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
    final text = widget.selectedText.trim();
    final existed = _existing != null;

    // Topic + language áp giống SelectionSaveSheet (READ-630 parity):
    // entry mới → ghi tag; entry cũ → BỔ SUNG tag, không ghi đè nghĩa cũ
    // (smart-fill của addWithAutoClassify).
    vocabProvider.addWithAutoClassify(
      text: text,
      meaning: meaning,
      context: ctx,
      language: _selectedLanguage,
      topic: _selectedTopic,
    );

    if (note.isNotEmpty) {
      final entry = vocabProvider.findByWord(text);
      if (entry != null) {
        vocabProvider.updateNotes(entry.id, note);
      }
    }

    tp.clearSelection();
    Navigator.pop(context);

    final shortText = text.length > 30 ? '${text.substring(0, 30)}…' : text;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.library_add_check, color: Color(0xFF9C27B0), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                existed
                    ? '"$shortText" đã có — bổ sung ngữ cảnh + tag'
                    : '"$shortText" đã lưu đầy đủ',
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
    final isPhrase = widget.selectedText.trim().split(RegExp(r'\s+')).length > 1;

    // READ-630 parity (txt source): chủ đề + ngôn ngữ như SelectionSaveSheet
    final vocabProvider = context.read<VocabularyProvider>();
    final topicOptions = vocabProvider.allTopics.toList()..sort();
    final languageOptions =
        (vocabProvider.allLanguages.toList()..sort()).toSet()
      ..addAll(['en', 'vi', 'pali', 'my']);
    final sortedLangs = languageOptions.toList()..sort();

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

            // ── Entry đã có sẵn → người dùng biết (đủ thông tin để update) ──
            if (_existing != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFFF9800).withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 16, color: Color(0xFFFF9800)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Đã có trong WordList — nghĩa/ghi chú đã điền sẵn. '
                        'Lưu sẽ bổ sung ngữ cảnh + tag (không ghi đè nghĩa '
                        'đang có).',
                        style: const TextStyle(
                            color: Color(0xFFFFB74D), fontSize: 11.5, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Chủ đề (chọn có sẵn / tạo mới) — parity với web/PDF ──
            const Text(
              'Chủ đề',
              style: TextStyle(
                  color: Colors.white54, fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in topicOptions)
                  ChoiceChip(
                    label: Text(
                      t,
                      style: TextStyle(
                          color: _selectedTopic == t ? Colors.white : Colors.white54,
                          fontSize: 11),
                    ),
                    selected: _selectedTopic == t,
                    selectedColor: const Color(0xFFFF9800),
                    backgroundColor: Colors.white.withValues(alpha: 0.04),
                    side: BorderSide(
                        color: _selectedTopic == t
                            ? const Color(0xFFFF9800)
                            : Colors.white.withValues(alpha: 0.1)),
                    onSelected: (value) => setState(() {
                      _selectedTopic =
                          value ? t : (_selectedTopic == t ? null : _selectedTopic);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _newTopicCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Tạo chủ đề mới… (Enter để chọn)',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: const BorderSide(color: Color(0xFFFF9800)),
                ),
              ),
              onSubmitted: (value) {
                final v = value.trim();
                if (v.isEmpty) return;
                setState(() => _selectedTopic = v);
                _newTopicCtrl.clear();
              },
            ),
            const SizedBox(height: 10),

            // ── Ngôn ngữ — parity với web/PDF ─────────────────────────
            const Text(
              'Ngôn ngữ',
              style: TextStyle(
                  color: Colors.white54, fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final lang in sortedLangs)
                  ChoiceChip(
                    label: Text(
                      labelForLanguage(lang),
                      style: TextStyle(
                          color: _selectedLanguage == lang ? Colors.white : Colors.white54,
                          fontSize: 11),
                    ),
                    selected: _selectedLanguage == lang,
                    selectedColor: const Color(0xFF42A5F5),
                    backgroundColor: Colors.white.withValues(alpha: 0.04),
                    side: BorderSide(
                        color: _selectedLanguage == lang
                            ? const Color(0xFF42A5F5)
                            : Colors.white.withValues(alpha: 0.1)),
                    onSelected: (value) {
                      if (value) setState(() => _selectedLanguage = lang);
                    },
                  ),
              ],
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
                          // ★ FIX overflow sọc vàng-đen (48px): từ/cụm dài
                          // không bị chặn width → RenderFlex overflow. Chặn
                          // 140px + ellipsis (meaning chặn 100px bên cạnh).
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 140),
                            child: Text(
                              e.word,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: e.vocabType.color,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (e.meaning.trim().isNotEmpty) ...[
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 100),
                              child: Text(
                                e.meaning,
                                maxLines: 1,
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
