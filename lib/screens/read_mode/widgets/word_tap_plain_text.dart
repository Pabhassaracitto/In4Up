// lib/screens/read_mode/widgets/word_tap_plain_text.dart
//
// PSRC-234 — tab Đọc, dòng KHÔNG bật "box từng từ" vẫn phải có đủ ba thao tác
// như khi bật box (owner: "khi chưa bật box từng từ, nhấp một lần vào từ phải
// đọc từ + mở từ điển dịch giống như khi có box từng từ; nhấp đúp phải đọc
// nguyên dòng, dịch nguyên câu và hiện popup dịch"):
//
//   • chạm MỘT lần vào từ → phát âm từ + `WordMiniPop` (pop tra nhanh, cùng
//     đúng một đường với chế độ ô chữ — không có nhánh thứ hai);
//   • chạm ĐÚP            → đọc nguyên dòng + dịch nguyên câu + mở
//     `ReadSelectionTranslateSheet` (đúng popup của nút biểu tượng Dịch);
//   • GIỮ rồi KÉO         → chọn nhiều từ liền kề (READ-SELECT-002), thanh
//     hành động dưới đáy như khi bôi chọn bằng tay trước đây.
//
// Vì sao phải là widget riêng thay cho `SelectableText`: `SelectableText` chỉ
// cho biết KHOẢNG ĐÃ CHỌN, không cho biết người dùng chạm vào ĐÂU, và chạm
// một lần thì nó chỉ đặt con trỏ ⇒ dòng không box là "câm" (đúng triệu chứng
// PSRC-234). Ở đây dòng được vẽ bằng MỘT `RichText`; `RenderParagraph` đổi
// toạ độ chạm → chỉ số ký tự → từ (`services/line_word_hit.dart`), kể cả
// khi một số từ được vẽ thành WidgetSpan chứa cả chữ và IPA.
//
// Đánh đổi đã cân nhắc: mất bôi chọn bằng tay cầm (handles) của
// `SelectableText`, nhưng giữ đúng trải nghiệm "giữ rồi kéo" của chế độ ô chữ
// (cùng `WordRange`, cùng `FloatingTextActions`, cùng ghi selection vào
// `TextProvider` để các nút Dịch/Ngữ pháp/Từ điển ở header vẫn thấy).
import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:in4up/core/language/localized_material.dart';
import 'package:in4up/core/platform/safe_haptics.dart';
import 'package:provider/provider.dart';

import '../../../models/word_analysis.dart';
import '../../../providers/text_provider.dart';
import '../controllers/read_mode_controller.dart';
import '../services/line_word_hit.dart';
import '../services/read_text_action_runner.dart';
import '../services/word_range_selection.dart';
import 'floating_text_actions.dart';
import 'read_text_action_hooks.dart';
import 'read_word_ipa.dart';
import 'word_mini_pop.dart';

/// Một dòng chữ "liền" (không ô từng từ) nhưng vẫn chạm/giữ được từng từ.
class WordTapPlainText extends StatefulWidget {
  const WordTapPlainText({
    super.key,
    required this.content,
    required this.words,
    required this.lineIndex,
    required this.fontSize,
    required this.wordStyle,
    this.wordIpa = const {},
    this.textAlign = TextAlign.left,
    this.lineStartOffset,
  });

  /// Nội dung dòng (nguồn duy nhất để đổi toạ độ chạm → chỉ số ký tự).
  final String content;

  /// Từ đã phân tích của dòng, đúng thứ tự trong [content].
  final List<AnalyzedWord> words;

  /// Chỉ số dòng trong tài liệu — ghi vào `TextProvider` khi chọn nhiều từ.
  final int lineIndex;

  final double fontSize;

  final TextStyle Function(int wordIndex, bool selected) wordStyle;
  final Map<int, InlineSpan> wordIpa;

  final TextAlign textAlign;

  /// Offset ký tự đầu dòng trong toàn tài liệu
  /// (`ReadModeController.getLineStartOffset`). `null` thì tự tính đúng công
  /// thức đó — để vùng chọn vẫn có offset đúng khi widget dựng độc lập.
  final int? lineStartOffset;

  @override
  State<WordTapPlainText> createState() => _WordTapPlainTextState();
}

class _WordTapPlainTextState extends State<WordTapPlainText> {
  /// Key của `RichText` để lấy được `RenderParagraph` — nguồn duy nhất đổi
  /// toạ độ chạm sang chỉ số ký tự.
  final GlobalKey _textKey = GlobalKey();
  final _ipaWordKeys = <int, GlobalKey>{};

  final LineTapClassifier _tap = LineTapClassifier();
  int? _lastTappedWord;
  bool _lastTapHadIpa = false;

  List<LineWordSpan> _spans = const <LineWordSpan>[];

  // Offsets in the rendered paragraph, which counts each WidgetSpan as one
  // character. Selection/copy must still use _spans and the source text.
  List<LineWordSpan> _displaySpans = const <LineWordSpan>[];

  WordRange? _range;

  @override
  void initState() {
    super.initState();
    _rebuildWordSpans();
  }

  @override
  void didUpdateWidget(WordTapPlainText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lineIndex != widget.lineIndex ||
        oldWidget.content != widget.content ||
        oldWidget.words.length != widget.words.length ||
        !Iterable<int>.generate(widget.words.length).every(
          (i) => oldWidget.words[i].word == widget.words[i].word,
        )) {
      _rebuildWordSpans();
      _ipaWordKeys.clear();
      _tap.reset();
      // Dòng đổi nội dung (sửa dòng, đổi tài liệu) ⇒ vùng chọn cũ vô nghĩa.
      // Không gọi clearSelection() ngay tại đây: didUpdateWidget chạy trong
      // pha build nên notifyListeners() sẽ làm widget khác markNeedsBuild
      // giữa lúc build — dọn local trước, dọn provider ở frame sau.
      final hadSelection = _range != null;
      if (oldWidget.lineIndex != widget.lineIndex) {
        if (WordSelectionState.activeLineIndex == oldWidget.lineIndex) {
          WordSelectionState.deactivate();
        }
      }
      _range = null;
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
  void dispose() {
    if (WordSelectionState.activeLineIndex == widget.lineIndex) {
      WordSelectionState.deactivate();
    }
    _tap.reset();
    super.dispose();
  }

  void _rebuildWordSpans() {
    _spans = buildLineWordSpans(
      content: widget.content,
      words: widget.words.map((word) => word.word).toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Vùng chọn bị xoá ở nơi khác (nút ✕ của thanh hành động, chạm ra ngoài
    // dòng, clearSelection từ luồng khác) ⇒ thoát chế độ chọn cho khớp trạng
    // thái thật của app — cùng luật với `ColoredTextWidget`.
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

    final style = TextStyle(
      fontSize: widget.fontSize,
      color: Colors.white,
      height: 1.6,
    );

    return GestureDetector(
      // opaque: chạm vào khoảng trắng trong dòng cũng là chạm dòng (không rơi
      // xuống tầng dưới), nhưng KHÔNG có `onDoubleTap` ở đây — xem
      // `LineTapClassifier` (double tap của GestureDetector giữ arena 300 ms).
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => _handleTapUp(context, details),
      onLongPressStart: (details) =>
          _startSelection(context, details.localPosition),
      onLongPressMoveUpdate: (details) =>
          _dragTo(context, details.localPosition),
      child: RichText(
        key: _textKey,
        text: TextSpan(
          style: style,
          children: _buildSpans(style, range),
        ),
        textAlign: widget.textAlign,
        textDirection: Directionality.of(context),
        // `SelectableText` tự nhân cỡ chữ theo cài đặt hệ thống; `RichText`
        // thì không (mặc định `TextScaler.noScaling`) ⇒ phải truyền tay, nếu
        // không người dùng bật "cỡ chữ lớn" sẽ thấy dòng co lại.
        textScaler: MediaQuery.textScalerOf(context),
      ),
    );
  }

  List<InlineSpan> _buildSpans(TextStyle baseStyle, WordRange? range) {
    final children = <InlineSpan>[];
    final displaySpans = <LineWordSpan>[];
    var cursor = 0;
    var removed = 0;
    for (final span in _spans) {
      if (span.start > cursor) {
        children
            .add(TextSpan(text: widget.content.substring(cursor, span.start)));
      }
      final index = span.wordIndex;
      final text = widget.content.substring(span.start, span.end);
      final style = widget.wordStyle(index, range?.contains(index) ?? false);
      final ipa = widget.wordIpa[index];
      final displayStart = span.start - removed;
      if (ipa == null) {
        children.add(TextSpan(text: text, style: style));
      } else {
        // A single placeholder keeps the source word and IPA on the same
        // run. Punctuation and whitespace remain ordinary paragraph text.
        children.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Column(
            key: _ipaWordKeys.putIfAbsent(index, () => GlobalKey()),
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                text: TextSpan(text: text, style: baseStyle.merge(style)),
                textAlign: TextAlign.center,
              ),
              ReadWordIpa(span: ipa, inline: true),
            ],
          ),
        ));
        removed += span.length - 1;
      }
      displaySpans.add(LineWordSpan(
        wordIndex: index,
        start: displayStart,
        end: span.end - removed,
      ));
      cursor = span.end;
    }
    if (cursor < widget.content.length) {
      children.add(TextSpan(text: widget.content.substring(cursor)));
    }
    _displaySpans = displaySpans;
    return children;
  }

  // ── Đổi toạ độ → từ ─────────────────────────────────────────────────────

  /// Từ nằm dưới điểm chạm [local] (toạ độ của `RichText`). `null` = dòng
  /// chưa đo được / không ghép được từ nào.
  int? _wordAt(Offset local) {
    if (_displaySpans.isEmpty) return null;
    final renderObject = _textKey.currentContext?.findRenderObject();
    if (renderObject is! RenderParagraph) return null;
    // The IPA tier may be far below the glyph baseline. Hit-test the actual
    // pair before asking the paragraph for a caret in the nearest text run.
    for (final wordIndex in widget.wordIpa.keys) {
      if (_ipaWordRect(wordIndex, ancestor: renderObject)?.contains(local) ??
          false) {
        return wordIndex;
      }
    }
    final position = renderObject.getPositionForOffset(local);
    return wordIndexAtCharOffset(
      spans: _displaySpans,
      charOffset: position.offset,
    );
  }

  Rect? _ipaWordRect(int wordIndex, {RenderBox? ancestor}) {
    final box = _ipaWordKeys[wordIndex]?.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return MatrixUtils.transformRect(
      box.getTransformTo(ancestor),
      Offset.zero & box.size,
    );
  }

  /// Hình chữ nhật (toạ độ toàn cục) của từ [#wordIndex] — để pop tra nhanh
  /// trồi lên đúng cạnh từ vừa chạm. `null` = chưa đo được, pop tự chọn chỗ.
  Rect? _wordRect(int wordIndex) {
    final pair = _ipaWordRect(wordIndex);
    if (pair != null) return pair;
    final span = lineWordSpanFor(spans: _displaySpans, wordIndex: wordIndex);
    if (span == null) return null;
    final renderObject = _textKey.currentContext?.findRenderObject();
    if (renderObject is! RenderParagraph) return null;

    final boxes = renderObject.getBoxesForSelection(
      TextSelection(baseOffset: span.start, extentOffset: span.end),
    );
    if (boxes.isEmpty) return null;

    var rect = boxes.first.toRect();
    for (final box in boxes.skip(1)) {
      rect = rect.expandToInclude(box.toRect());
    }
    return renderObject.localToGlobal(rect.topLeft) & rect.size;
  }

  // ── Thao tác ────────────────────────────────────────────────────────────

  void _handleTapUp(BuildContext context, TapUpDetails details) {
    final wordIndex = _wordAt(details.localPosition);
    // Two short neighboring words can be within the double-tap distance.
    // If the first tap activated IPA on this line, allow a second tap at the
    // same screen position even though the original paragraph rewrapped.
    final hasIpa = widget.wordIpa.isNotEmpty;
    if (_lastTapHadIpa == hasIpa && _lastTappedWord != wordIndex) _tap.reset();
    _lastTappedWord = wordIndex;
    _lastTapHadIpa = hasIpa;

    // Chạm đúp là thao tác của CẢ DÒNG nên vẫn phải chạy kể cả khi cú chạm
    // không ghép được từ nào (dòng chỉ có dấu câu, phân tích lệch nội dung).
    if (_tap.registerTap(
        position: details.globalPosition, at: DateTime.now())) {
      _handleLineDoubleTap(context);
      return;
    }
    if (wordIndex == null) return;

    SafeHaptics.selectionClick();

    // Chạm nhanh luôn là đọc/tra từ, kể cả khi đang chọn nhiều từ (chỉ GIỮ +
    // kéo mới duy trì vùng chọn) — cùng phản xạ với chế độ ô chữ.
    if (_range != null) _exitSelection(clearProvider: true);
    context.read<ReadModeController>().removeFloatingMenu();

    final tp = context.read<TextProvider>();
    // Vùng chọn còn sót của DÒNG KHÁC (thanh hành động đang mở) phải được
    // đóng lại, nếu không thanh đó vẫn treo trên màn hình với đoạn cũ.
    if (tp.selectedText != null) tp.clearSelection();
    if (tp.currentLineIndex != widget.lineIndex) {
      tp.setCurrentLine(widget.lineIndex);
    }
    unawaited(tp.speak(widget.words[wordIndex].word));

    WordMiniPop.show(
      context,
      word: widget.words[wordIndex],
      lineIndex: widget.lineIndex,
      wordIndex: wordIndex,
      anchorRect: _wordRect(wordIndex),
      onSelectMore: () => _startSelectionAt(context, wordIndex),
    );
  }

  /// Chạm đúp: đọc NGUYÊN DÒNG + dịch NGUYÊN CÂU + mở popup dịch (đúng popup
  /// của nút biểu tượng Dịch — `ReadSelectionTranslateSheet`).
  void _handleLineDoubleTap(BuildContext context) {
    // Pop của cú chạm thứ nhất (nếu vừa mở) không được nằm đè lên popup dịch.
    WordMiniPop.dismiss();
    if (_range != null) _exitSelection(clearProvider: true);
    context.read<ReadModeController>().removeFloatingMenu();
    SafeHaptics.mediumImpact();

    final lineText = widget.content.trim();
    if (lineText.isEmpty) return;

    final tp = context.read<TextProvider>();
    if (tp.currentLineIndex != widget.lineIndex) {
      tp.setCurrentLine(widget.lineIndex);
    }
    tp.clearSelection();
    unawaited(tp.speak(widget.content, lineIndex: widget.lineIndex));
    unawaited(
      ReadTextActionRunner.run(
        context,
        ReadTextAction.translate,
        selectedText: widget.content,
      ),
    );
  }

  /// GIỮ một từ ⇒ vào chế độ chọn nhiều từ, từ đó là mỏ neo (READ-SELECT-002).
  void _startSelection(BuildContext context, Offset local) {
    _tap.reset();
    final wordIndex = _wordAt(local);
    if (wordIndex == null) return;
    _startSelectionAt(context, wordIndex);
  }

  void _startSelectionAt(BuildContext context, int wordIndex) {
    // Có thể được gọi từ nút "Bôi nhiều chữ" của pop (sau khi pop đã đóng) ⇒
    // dòng có thể không còn trên màn hình.
    if (!mounted) return;
    final range = resolveWordRange(
      anchorIndex: wordIndex,
      focusIndex: wordIndex,
      wordCount: widget.words.length,
    );
    if (range == null) return;

    // Pop tra nhanh và chế độ chọn không sống cùng lúc (pop che chữ đang bôi).
    WordMiniPop.dismiss();
    SafeHaptics.selectionClick();
    final tp = context.read<TextProvider>();
    if (tp.currentLineIndex != widget.lineIndex) {
      tp.setCurrentLine(widget.lineIndex);
    }
    WordSelectionState.activate(widget.lineIndex);
    setState(() => _range = range);
    _publishSelection(range);
    _showSelectionBar(range);
  }

  /// Kéo khi vẫn đang giữ: từ dưới con trỏ là đầu kéo mới, mỏ neo không đổi.
  void _dragTo(BuildContext context, Offset local) {
    final range = _range;
    if (range == null) return;
    final wordIndex = _wordAt(local);
    if (wordIndex == null) return;

    final next = resolveWordRange(
      anchorIndex: range.anchorIndex,
      focusIndex: wordIndex,
      wordCount: widget.words.length,
    );
    if (next == null || next.focusIndex == range.focusIndex) return;

    SafeHaptics.selectionClick();
    setState(() => _range = next);
    _publishSelection(next);
    _showSelectionBar(next);
  }

  /// Thanh hành động dưới đáy — ĐÚNG widget mà trước đây việc bôi chọn bằng
  /// tay của `SelectableText` mở ra, nên thao tác quen thuộc không đổi.
  void _showSelectionBar(WordRange range) {
    final selection = _selectionFor(range);
    if (selection == null || !mounted) return;
    FloatingTextActions.show(context, selection.text, widget.lineIndex);
  }

  void _exitSelection({required bool clearProvider}) {
    if (WordSelectionState.activeLineIndex == widget.lineIndex) {
      WordSelectionState.deactivate();
    }
    if (_range == null) return;
    WordMiniPop.dismiss();
    if (mounted) {
      setState(() => _range = null);
    } else {
      _range = null;
    }
    if (clearProvider && mounted) {
      context.read<TextProvider>().clearSelection();
    }
  }

  // ── Vùng chọn → chuỗi + offset ──────────────────────────────────────────

  String _lineContent() {
    final tp = context.read<TextProvider>();
    if (widget.lineIndex < 0 || widget.lineIndex >= tp.lines.length) {
      return widget.content;
    }
    return tp.lines[widget.lineIndex].content;
  }

  WordSelectionText? _selectionFor(WordRange range) {
    return buildWordSelectionText(
      words: widget.words,
      start: range.start,
      end: range.end,
      lineContent: _lineContent(),
    );
  }

  /// Ghi vùng chọn vào `TextProvider` — phần còn lại của app (nút Dịch/Ngữ
  /// pháp/Từ điển ở header, lưu từ, hành động của dòng) nhìn thấy như một
  /// selection thật do người dùng bôi chọn (cùng công thức với
  /// `ColoredTextWidget` và với `SelectableText` trước đây).
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
