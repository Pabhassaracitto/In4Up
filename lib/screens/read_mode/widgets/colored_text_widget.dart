// lib/screens/read_mode/widgets/colored_text_widget.dart

import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:in4up_core/vocab_level_difficulty.dart';

import '../../../features/grammar/models/grammar_category.dart';
import '../../../features/grammar/models/grammar_highlight_settings.dart';
import '../../../features/grammar/models/grammar_palette.dart';
import '../../../features/grammar/services/grammar_style_mapper.dart';
import '../../../models/color_mode.dart';
import '../../../models/word_analysis.dart';
import '../../../providers/text_provider.dart';
import '../services/read_text_action_runner.dart';
import '../services/word_range_selection.dart';
import '../sheets/word_actions_sheet.dart';
import 'read_text_action_hooks.dart';

/// Chế độ ô chữ (tô màu / IPA) của tab Đọc — mỗi từ một ô chạm được.
///
/// READ-SELECT-002 (audit 1.e — "chọn nhiều từ thường thất bại"): trước đây
/// KHÔNG có cách nào chọn nhiều từ vì mỗi từ là một `GestureDetector` và cả
/// dòng không có `SelectableText`. Giờ:
///
///  • chạm một từ  → phát âm (giữ nguyên phản xạ cũ);
///  • chạm hai lần → nghĩa nhanh (như cũ);
///  • GIỮ một từ   → vào chế độ chọn, từ đó là mỏ neo (nền đổi rõ ràng);
///  • kéo ngang khi đang giữ, hoặc chạm từ thứ hai → mở rộng vùng chọn;
///  • thanh hành động dưới vùng chọn chạy đúng [ReadTextActionRunner.run]
///    (một đường xử lý duy nhất, không nhánh thứ hai) và ghi vùng chọn vào
///    `TextProvider.selectTextWithOffsets` để phần còn lại của app thấy như
///    một selection thật;
///  • thoát: nút ✕ hoặc chạm ra ngoài (tầng dòng hỏi [WordSelectionState]).
class ColoredTextWidget extends StatefulWidget {
  final List<AnalyzedWord> words;
  final double fontSize;
  final ColorMode colorMode;
  final int lineIndex;

  /// Offset ký tự đầu của dòng trong toàn tài liệu. Truyền từ tầng dòng
  /// (`ReadModeController.getLineStartOffset`) — để widget này không phải tự
  /// đi tìm controller; `null` thì tự tính đúng công thức đó.
  final int? lineStartOffset;

  const ColoredTextWidget({
    super.key,
    required this.words,
    required this.fontSize,
    required this.colorMode,
    required this.lineIndex,
    this.lineStartOffset,
  });

  @override
  State<ColoredTextWidget> createState() => _ColoredTextWidgetState();
}

class _ColoredTextWidgetState extends State<ColoredTextWidget> {
  WordRange? _range;

  /// Một GlobalKey cho mỗi ô từ — dùng để biết con trỏ đang ở từ nào khi kéo
  /// (hình chữ nhật của ô là thứ duy nhất trả lời được câu đó).
  List<GlobalKey> _wordKeys = const [];

  bool get _selecting => _range != null;

  @override
  void dispose() {
    if (WordSelectionState.activeLineIndex == widget.lineIndex) {
      WordSelectionState.deactivate();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(ColoredTextWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Dòng đổi nội dung (sửa dòng, đổi tài liệu) ⇒ vùng chọn cũ vô nghĩa.
    // KHÔNG gọi clearSelection() ngay tại đây: didUpdateWidget chạy trong pha
    // build, notifyListeners() lúc này sẽ làm widget khác markNeedsBuild
    // trong lúc build; dọn local trước rồi mới dọn provider ở frame sau.
    final hadSelection = _range != null;
    if (oldWidget.lineIndex != widget.lineIndex ||
        oldWidget.words.length != widget.words.length) {
      _range = null;
      _wordKeys = const [];
      if (WordSelectionState.activeLineIndex == oldWidget.lineIndex) {
        WordSelectionState.deactivate();
      }
      if (hadSelection) {
        final staleLine = oldWidget.lineIndex;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final tp = context.read<TextProvider>();
          if (tp.selectedTextInfo?.lineIndex == staleLine) {
            tp.clearSelection();
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.words.isEmpty) {
      return const SizedBox.shrink();
    }
    if (_wordKeys.length != widget.words.length) {
      _wordKeys = List<GlobalKey>.generate(
        widget.words.length,
        (_) => GlobalKey(),
      );
    }

    // Vùng chọn bị xoá ở nơi khác (nút ✕ của dòng khác, clearSelection từ
    // luồng khác) ⇒ thoát chế độ chọn cho khớp trạng thái thật của app.
    final selectionLine = context.select<TextProvider, int?>(
      (tp) => tp.selectedTextInfo?.lineIndex,
    );
    final range = _range;
    if (range != null && selectionLine != widget.lineIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _range != null) {
          setState(() => _range = null);
        }
      });
    }

    final wrap = Wrap(
      spacing: 3,
      runSpacing: 4,
      children: [
        for (var i = 0; i < widget.words.length; i++)
          _buildWord(context, i, range),
      ],
    );

    if (range == null) {
      // Chưa ở chế độ chọn ⇒ giữ NGUYÊN cây widget như trước (không bọc
      // thêm detector nào để không đổi phản xạ chạm/giữ của người dùng cũ).
      return wrap;
    }

    return GestureDetector(
      // Chạm vào khoảng trống giữa các ô trong vùng này = bỏ chọn; chạm vào
      // ô từ vẫn do detector của ô xử lý (con thắng cha trong gesture arena).
      behavior: HitTestBehavior.opaque,
      onTap: () => _exitSelection(clearProvider: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          wrap,
          const SizedBox(height: 6),
          _buildSelectionBar(context, range),
        ],
      ),
    );
  }

  Widget _buildWord(BuildContext context, int index, WordRange? range) {
    final selected = range != null && range.contains(index);
    final isAnchor = range != null && range.anchorIndex == index;

    return _ColoredWord(
      key: _wordKeys[index],
      word: widget.words[index],
      fontSize: widget.fontSize,
      colorMode: widget.colorMode,
      selected: selected,
      isAnchor: isAnchor,
      selectionActive: range != null,
      onTap: () => _selecting ? _extendTo(index) : _speak(index),
      onDoubleTap: _selecting ? null : () => _showQuickMeaning(index),
      onLongPressStart: () => _startSelection(index),
      onLongPressMoveUpdate: (position) => _dragTo(position),
    );
  }

  Widget _buildSelectionBar(BuildContext context, WordRange range) {
    final selection = _selectionFor(range);
    if (selection == null) return const SizedBox.shrink();

    final anchorWord = widget.words[range.anchorIndex];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: ReadTextActionBar(
            selectedText: selection.text,
            callbacks: ReadTextActionCallbacks(
              onTranslate: (text) => ReadTextActionRunner.run(
                context,
                ReadTextAction.translate,
                selectedText: text,
              ),
              onGrammar: (text) => ReadTextActionRunner.run(
                context,
                ReadTextAction.grammar,
                selectedText: text,
              ),
              onPronounce: (text) => ReadTextActionRunner.run(
                context,
                ReadTextAction.pronounce,
                selectedText: text,
              ),
              onDictionary: (text) => ReadTextActionRunner.run(
                context,
                ReadTextAction.dictionary,
                selectedText: text,
              ),
            ),
          ),
        ),
        IconButton(
          key: const Key('read-word-selection-details'),
          tooltip: context.uiText('Từ chi tiết'),
          visualDensity: VisualDensity.compact,
          iconSize: 18,
          color: const Color(0xFF64B5F6),
          icon: const Icon(Icons.menu_book_outlined),
          onPressed: () {
            WordActionsSheet.show(
              context,
              anchorWord,
              widget.lineIndex,
              range.anchorIndex,
            );
          },
        ),
        IconButton(
          key: const Key('read-word-selection-exit'),
          tooltip: context.uiText('Thoát chọn'),
          visualDensity: VisualDensity.compact,
          iconSize: 18,
          color: Colors.white70,
          icon: const Icon(Icons.close),
          onPressed: () => _exitSelection(clearProvider: true),
        ),
      ],
    );
  }

  // ── Thao tác ────────────────────────────────────────────────────────────

  void _speak(int index) {
    HapticFeedback.selectionClick();
    final tp = context.read<TextProvider>();
    if (tp.currentLineIndex != widget.lineIndex) {
      tp.setCurrentLine(widget.lineIndex);
    }
    tp.speak(widget.words[index].word);
  }

  void _showQuickMeaning(int index) {
    _QuickMeaning.show(context, widget.words[index]);
  }

  void _startSelection(int index) {
    final range = resolveWordRange(
      anchorIndex: index,
      focusIndex: index,
      wordCount: widget.words.length,
    );
    if (range == null) return;
    HapticFeedback.selectionClick();
    final tp = context.read<TextProvider>();
    if (tp.currentLineIndex != widget.lineIndex) {
      tp.setCurrentLine(widget.lineIndex);
    }
    WordSelectionState.activate(widget.lineIndex);
    setState(() => _range = range);
    _publishSelection(range);
  }

  void _extendTo(int index) {
    final range = _range;
    if (range == null) return;
    final next = resolveWordRange(
      anchorIndex: range.anchorIndex,
      focusIndex: index,
      wordCount: widget.words.length,
    );
    if (next == null || next.focusIndex == range.focusIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _range = next);
    _publishSelection(next);
  }

  /// Kéo khi vẫn đang giữ: từ dưới con trỏ (hoặc từ gần nhất) là đầu kéo mới.
  void _dragTo(Offset globalPosition) {
    final range = _range;
    if (range == null) return;
    final boxes = <Rect?>[];
    for (final key in _wordKeys) {
      final renderObject = key.currentContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) {
        boxes.add(null);
        continue;
      }
      boxes.add(renderObject.localToGlobal(Offset.zero) & renderObject.size);
    }
    final index = wordIndexAtPoint(boxes: boxes, point: globalPosition);
    if (index == null) return;
    _extendTo(index);
  }

  /// Thoát chế độ chọn; `clearProvider` = xoá luôn selection của app.
  void _exitSelection({required bool clearProvider}) {
    if (WordSelectionState.activeLineIndex == widget.lineIndex) {
      WordSelectionState.deactivate();
    }
    if (_range == null) return;
    if (mounted) {
      setState(() => _range = null);
    } else {
      _range = null;
    }
    if (clearProvider && mounted) {
      context.read<TextProvider>().clearSelection();
    }
  }

  /// Nội dung dòng hiện tại (để tính offset) — rỗng nếu dòng không còn.
  String _lineContent() {
    final tp = context.read<TextProvider>();
    if (widget.lineIndex < 0 || widget.lineIndex >= tp.lines.length) return '';
    return tp.lines[widget.lineIndex].content;
  }

  WordSelectionText? _selectionFor(WordRange range) {
    final selection = buildWordSelectionText(
      words: widget.words,
      start: range.start,
      end: range.end,
      lineContent: _lineContent(),
    );
    return selection;
  }

  /// Ghi vùng chọn vào [TextProvider] — phần còn lại của app (nút Dịch/Ngữ
  /// pháp ở header, lưu từ, hành động của dòng) nhìn thấy như một selection
  /// thật do người dùng bôi chọn.
  void _publishSelection(WordRange range) {
    final selection = _selectionFor(range);
    if (selection == null) return;
    final tp = context.read<TextProvider>();
    final lineStart = _lineStartOffset(tp);
    tp.selectTextWithOffsets(
      text: selection.text,
      startOffset: lineStart + selection.startOffset,
      endOffset: lineStart + selection.endOffset,
      lineIndex: widget.lineIndex,
    );
  }

  /// Offset đầu dòng — tầng dòng truyền sẵn (nguồn duy nhất:
  /// `ReadModeController.getLineStartOffset`); thiếu thì tính đúng công thức
  /// đó tại chỗ để vùng chọn vẫn có offset đúng.
  int _lineStartOffset(TextProvider tp) {
    final provided = widget.lineStartOffset;
    if (provided != null && provided >= 0) return provided;
    var offset = 0;
    for (var i = 0; i < widget.lineIndex && i < tp.lines.length; i++) {
      offset += tp.lines[i].content.length + 1;
    }
    return offset;
  }
}

class _MiniMark extends StatelessWidget {
  final Color color;
  final double width;

  const _MiniMark({required this.color, this.width = 16});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 2,
      margin: const EdgeInsets.only(top: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}

class _ColoredWord extends StatelessWidget {
  final AnalyzedWord word;
  final double fontSize;
  final ColorMode colorMode;

  /// READ-SELECT-002 — trạng thái vùng chọn nhiều từ.
  final bool selected;
  final bool isAnchor;
  final bool selectionActive;

  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback onLongPressStart;
  final void Function(Offset globalPosition) onLongPressMoveUpdate;

  const _ColoredWord({
    super.key,
    required this.word,
    required this.fontSize,
    required this.colorMode,
    required this.selected,
    required this.isAnchor,
    required this.selectionActive,
    required this.onTap,
    required this.onDoubleTap,
    required this.onLongPressStart,
    required this.onLongPressMoveUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final grammarSettings =
        context.select<TextProvider, GrammarHighlightSettings>(
      (tp) => tp.grammarSettings,
    );
    final activePalette = context.select<TextProvider, GrammarPalette>(
      (tp) => tp.activeGrammarPalette,
    );
    final hasDifficulty = word.userDifficulty != null;
    final hasRecall = word.isSaved || word.hasSavedNotes || word.hasDueReview;

    final grammarCategory = grammarCategoryFromLegacyWordType(word.wordType);
    final useGrammarStyle =
        colorMode == ColorMode.wordType && grammarSettings.enabled;
    final grammarResolved = useGrammarStyle
        ? GrammarStyleMapper.resolve(
            category: grammarCategory,
            palette: activePalette,
            settings: grammarSettings,
            defaultTextColor: Colors.white,
          )
        : null;

    final baseBackground =
        grammarResolved?.background ?? word.getBackgroundColor(colorMode);
    final baseForeground = grammarResolved?.foreground ?? word.getColor(colorMode);

    // Nền vùng chọn phải rõ hơn hẳn nền tô màu từ loại (người dùng đang
    // "giữ" để chọn, không phải đang đọc màu ngữ pháp).
    final bgColor = selected
        ? const Color(0xFF2196F3).withValues(alpha: isAnchor ? 0.45 : 0.30)
        : baseBackground;
    final textColor = selected ? Colors.white : baseForeground;

    final borderColor = hasDifficulty
        ? word.userDifficulty!.color.withValues(alpha: 0.5)
        : word.hasDueReview
            ? Colors.redAccent.withValues(alpha: 0.45)
            : word.hasSavedNotes
                ? Colors.amber.withValues(alpha: 0.38)
                : word.isSaved
                    ? const Color(0xFF4CAF50).withValues(alpha: 0.28)
                    : grammarResolved?.outline ?? Colors.transparent;

    final Border? border = isAnchor
        ? Border.all(color: const Color(0xFF64B5F6), width: 2)
        : hasDifficulty || hasRecall || grammarResolved?.outline != null
            ? Border.all(
                color: borderColor,
                width: hasDifficulty ? 1.5 : 1,
              )
            : null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPressStart: (_) => onLongPressStart(),
      onLongPressMoveUpdate: (details) =>
          onLongPressMoveUpdate(details.globalPosition),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(4),
          border: border,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              word.word,
              style: TextStyle(
                fontSize: fontSize,
                color: textColor,
                fontWeight: grammarResolved?.fontWeight ??
                    (hasDifficulty || word.isSaved
                        ? FontWeight.bold
                        : FontWeight.normal),
                decoration: grammarResolved?.underline != null
                    ? TextDecoration.underline
                    : null,
                decorationColor: grammarResolved?.underline,
                decorationThickness: grammarResolved?.underline != null ? 2 : null,
                height: 1.6,
              ),
            ),
            if (hasDifficulty || hasRecall)
              Wrap(
                spacing: 3,
                runSpacing: 2,
                children: [
                  if (hasDifficulty)
                    _MiniMark(color: word.userDifficulty!.color),
                  if (word.isSaved)
                    const _MiniMark(color: Color(0xFF4CAF50), width: 6),
                  if (word.hasSavedNotes)
                    const _MiniMark(color: Colors.amber, width: 6),
                  if (word.hasDueReview)
                    const _MiniMark(color: Colors.redAccent, width: 6),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Nghĩa nhanh (chạm hai lần) — tách khỏi `_ColoredWord` để widget từ chỉ còn
/// lo hiển thị + thao tác (READ-SELECT-002 cần `_ColoredWord` nhận callback
/// thay vì tự quyết định hành vi).
class _QuickMeaning {
  _QuickMeaning._();

  static void show(BuildContext context, AnalyzedWord word) {
    if (word.meaning == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: word.wordType.color.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                word.word,
                style: TextStyle(
                  color: word.wordType.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    word.meaning!,
                    style: const TextStyle(color: Colors.white),
                  ),
                  Text(
                    '${context.uiText(grammarCategoryFromLegacyWordType(word.wordType).labelVi)} · ${word.cefrLevel.shortLabel}',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2A2A3E),
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      ),
    );
  }
}
