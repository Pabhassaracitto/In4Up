// lib/screens/read_mode/widgets/word_mini_pop.dart
//
// AUDIT-2026-10-20 (mục 4) — "1 pop nhú lên ít thôi" cho ô chữ trong tab Đọc.
//
// YÊU CẦU CỦA OWNER:
//   • Chạm từ → đọc (giữ nguyên).
//   • Nhấn giữ / chạm đúp → ra MENU, nhưng menu phải GỌN: chỉ chứa thông
//     tin quan trọng cơ bản — từ gốc + IPA + loại từ + CEFR (A1/A2/B1…) +
//     độ khó (dễ / trung bình / khó / rất khó) + lưu nhớ + nghĩa.
//   • "Trên đầu pop như cái rèm": chạm giữ và KÉO LÊN ⇒ pop ra thông tin đầy
//     đủ (bảng chi tiết của `WordActionsSheet`).
//   • Thêm ảnh cho từ (đã có sẵn cơ chế tìm/chọn ảnh ở Worklist + Sửa từ
//     vựng) ⇒ pop cũng phải làm được.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in4up/core/language/localized_material.dart' hide Text;
import 'package:provider/provider.dart';

import '../../../features/dictionary/models/dict_entry.dart';
import '../../../features/dictionary/services/dictionary_service.dart';
import '../../../features/vocab_image/vocab_image_picker.dart';
import '../../../models/vocab_context.dart';
import '../../../models/word_analysis.dart';
import '../../../providers/text_provider.dart';
import '../../../providers/vocabulary_provider.dart';
import '../../../services/ipa_resolver.dart';
import '../sheets/word_actions_sheet.dart';

/// Key của "rèm" (kéo lên để bung thông tin đầy đủ).
const Key wordMiniPopCurtainKey = Key('word_mini_pop_curtain');

/// Key của nút mở bảng chi tiết đầy đủ.
const Key wordMiniPopExpandKey = Key('word_mini_pop_expand');

/// Key của nút lưu nhớ trong pop.
const Key wordMiniPopSaveKey = Key('word_mini_pop_save');

/// Key của nút thêm ảnh trong pop.
const Key wordMiniPopImageKey = Key('word_mini_pop_image');

/// Key của nút phát âm trong pop.
const Key wordMiniPopSpeakKey = Key('word_mini_pop_speak');

/// Key của nút "Bôi nhiều chữ" trong pop.
const Key wordMiniPopSelectMoreKey = Key('word_mini_pop_select_more');

/// Pop nhỏ cho 1 từ trong vùng đọc.
class WordMiniPop extends StatefulWidget {
  const WordMiniPop({
    super.key,
    required this.word,
    required this.lineIndex,
    required this.wordIndex,
    this.onSelectMore,
  });

  final AnalyzedWord word;
  final int lineIndex;
  final int wordIndex;

  /// Nếu khác null ⇒ hiện nút "Bôi nhiều chữ" (bật chế độ chọn nhiều từ
  /// của READ-SELECT-002). Bấm ⇒ đóng pop và bắt đầu bôi từ.
  final VoidCallback? onSelectMore;

  /// Mở pop nhỏ (thay cho bảng chi tiết ngay).
  static Future<void> show(
    BuildContext context, {
    required AnalyzedWord word,
    required int lineIndex,
    required int wordIndex,
    VoidCallback? onSelectMore,
  }) {
    HapticFeedback.lightImpact();
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: context.uiText('Đóng'),
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (ctx, _, __) => WordMiniPop(
        word: word,
        lineIndex: lineIndex,
        wordIndex: wordIndex,
        onSelectMore: onSelectMore,
      ),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOut);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<WordMiniPop> createState() => _WordMiniPopState();
}

class _WordMiniPopState extends State<WordMiniPop> {
  List<DictEntry> _dictEntries = const [];
  bool _loading = true;
  double _dragDistance = 0;

  @override
  void initState() {
    super.initState();
    _lookupDict();
  }

  Future<void> _lookupDict() async {
    try {
      final entries = await DictionaryService.instance.lookup(widget.word.word);
      if (!mounted) return;
      setState(() {
        _dictEntries = entries;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// IPA ưu tiên từ dữ liệu từ đã phân tích, sau đó từ từ điển (MDX).
  String? get _ipa {
    final own = widget.word.phonetic?.trim();
    if (own != null && own.isNotEmpty) return own;
    for (final e in _dictEntries.take(5)) {
      final p = e.phonetic;
      if (p != null && IpaValidator.looksLikeIpa(p)) {
        final n = IpaValidator.normalize(p);
        if (n != null) return n;
      }
      final x = IpaDefinitionExtractor.extract(e.plainDefinition);
      if (x != null) return x;
    }
    return null;
  }

  String? get _meaning {
    if (_dictEntries.isNotEmpty) return _dictEntries.first.plainDefinition;
    final m = widget.word.meaning;
    return (m == null || m.isEmpty) ? null : m;
  }

  /// Kéo lên quá ngưỡng ⇒ mở bảng chi tiết đầy đủ.
  void _onCurtainDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_dragDistance < 36 && velocity > -260) {
      setState(() => _dragDistance = 0);
      return;
    }
    _openFullSheet();
  }

  void _openFullSheet() {
    // Lưu N navigator TRƯỚC khi pop: context của dialog sẽ unmount ngay khi
    // pop ⇒ không dùng nó để mở sheet (sẽ bị bỏ qua do !mounted).
    final navigator = Navigator.of(context);
    final sheetCtx = navigator.context;
    navigator.pop();
    // Mở sau khi pop đóng để không chồng 2 lớp modal.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!sheetCtx.mounted) return;
      WordActionsSheet.show(
        sheetCtx,
        widget.word,
        widget.lineIndex,
        widget.wordIndex,
      );
    });
  }

  void _save() {
    final tp = context.read<TextProvider>();
    final vocab = context.read<VocabularyProvider>();
    if (vocab.hasWord(widget.word.word)) {
      _toast(context.uiText('Từ đã có trong thư viện'));
      return;
    }
    final ipa = _ipa;
    vocab.addWithAutoClassify(
      text: widget.word.word,
      meaning: widget.word.meaning ?? _meaning ?? '',
      phonetic: ipa,
      phoneticSource: ipa == null ? null : 'mdx',
      context: _buildContext(tp),
    );
    tp.saveWord(widget.word);
    _toast(context.uiText('Đã lưu từ'));
  }

  VocabContext _buildContext(TextProvider tp) {
    final title = tp.currentDocument?.title ?? 'Text Studio';
    final lineContent = widget.lineIndex < tp.lines.length
        ? tp.lines[widget.lineIndex].content
        : widget.word.word;
    return VocabContext.fromStory(
      storyTitle: title,
      lineIndex: widget.lineIndex,
      surroundingText: lineContent,
      sourceRef: tp.currentContextSourceRef,
      sourceRefType: tp.currentContextSourceRefType,
      anchorText: widget.word.word,
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  /// Mở hộp chọn ảnh (tìm/chọn ảnh — cùng cơ chế với Worklist + Sửa từ).
  void _openImagePicker() {
    final vocab = context.read<VocabularyProvider>();
    final existing = vocab.findByWord(widget.word.word);
    if (existing == null) {
      _toast(context.uiText('Hãy lưu từ trước khi thêm ảnh'));
      return;
    }
    final ctx = context;
    showDialog<void>(
      context: ctx,
      builder: (dialogCtx) => Dialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              VocabImagePicker(
                wordId: existing.id,
                word: existing.word,
                meaning: existing.meaning,
                currentImageUrl: existing.imageUrl,
                onImageChanged: (_) {},
                size: 120,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: Text(context.uiText('Đóng')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tp = context.read<TextProvider>();
    final vocab = context.watch<VocabularyProvider>();
    final saved = vocab.hasWord(widget.word.word);
    final type = widget.word.wordType;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Material(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(18),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── "RÈM": kéo lên để bung thông tin đầy đủ ────────────
                  GestureDetector(
                    key: wordMiniPopCurtainKey,
                    onVerticalDragUpdate: (d) =>
                        setState(() => _dragDistance += d.delta.dy),
                    onVerticalDragEnd: _onCurtainDragEnd,
                    onTap: _openFullSheet,
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.keyboard_arrow_up_rounded,
                              size: 15,
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              context.uiText('Kéo lên để xem đầy đủ'),
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Colors.white.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Từ + IPA + nút phát âm ───────────────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                widget.word.word,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: type.color,
                                ),
                              ),
                            ),
                            if (_ipa != null) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _ipa!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.white60,
                                  ),
                                ),
                              ),
                            ],
                            const Spacer(),
                            _MiniIconButton(
                              buttonKey: wordMiniPopSpeakKey,
                              icon: Icons.volume_up_rounded,
                              tooltip: context.uiText('Phát âm'),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                tp.speak(widget.word.word);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // ── Loại từ + CEFR + độ khó ───────────────────
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _MiniBadge(
                              label: type.labelVi,
                              color: type.color,
                            ),
                            _MiniBadge(
                              label: widget.word.cefrLevel.shortLabel,
                              color: widget.word.cefrLevel.color,
                            ),
                            if (widget.word.userDifficulty != null)
                              _MiniBadge(
                                label: widget.word.userDifficulty!.label,
                                color: widget.word.userDifficulty!.color,
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // ── Nghĩa ─────────────────────────────────────
                        if (_loading)
                          const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else if (_meaning != null)
                          Text(
                            _meaning!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        const SizedBox(height: 12),
                        // ── Hành động ─────────────────────────────────
                        Row(
                          children: [
                            _MiniActionButton(
                              buttonKey: wordMiniPopSaveKey,
                              icon: saved
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_border_rounded,
                              label: context.uiText('Lưu'),
                              active: saved,
                              onTap: _save,
                            ),
                            if (widget.onSelectMore != null) ...[
                              const SizedBox(width: 8),
                              _MiniActionButton(
                                buttonKey: wordMiniPopSelectMoreKey,
                                icon: Icons.format_list_bulleted,
                                label: context.uiText('Bôi nhiều chữ'),
                                onTap: () {
                                  final cb = widget.onSelectMore;
                                  Navigator.of(context).pop();
                                  cb?.call();
                                },
                              ),
                            ],
                            const SizedBox(width: 8),
                            _MiniActionButton(
                              buttonKey: wordMiniPopImageKey,
                              icon: Icons.image_outlined,
                              label: context.uiText('Thêm ảnh'),
                              onTap: _openImagePicker,
                            ),
                            const Spacer(),
                            _MiniActionButton(
                              buttonKey: wordMiniPopExpandKey,
                              icon: Icons.open_in_full_rounded,
                              label: context.uiText('Xem đầy đủ'),
                              onTap: _openFullSheet,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Badge nhỏ (loại từ / CEFR / độ khó).
class _MiniBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Nút tròn chỉ có icon.
class _MiniIconButton extends StatelessWidget {
  final Key buttonKey;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _MiniIconButton({
    required this.buttonKey,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        key: buttonKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFF2196F3).withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF2196F3)),
        ),
      ),
    );
  }
}

/// Nút hành động nhỏ (icon + nhãn).
class _MiniActionButton extends StatelessWidget {
  final Key buttonKey;
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _MiniActionButton({
    required this.buttonKey,
    required this.icon,
    required this.label,
    this.active = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        key: buttonKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF4CAF50).withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: active
                  ? const Color(0xFF4CAF50).withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: active ? const Color(0xFF81C784) : Colors.white70,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: active ? const Color(0xFF81C784) : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
