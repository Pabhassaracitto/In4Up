// lib/screens/read_mode/widgets/text_line_widget.dart
// ★ FIX: Thêm guard index trong Selector2 để tránh RangeError khi lines thay đổi

import 'package:flutter/foundation.dart';
import 'package:in4up/core/language/localized_material.dart';
import 'package:provider/provider.dart';
import 'package:in4up/core/platform/safe_haptics.dart';

import '../../../features/grammar/models/grammar_category.dart';
import '../../../features/grammar/models/grammar_highlight_settings.dart';
import '../../../features/grammar/models/grammar_palette.dart';
import '../../../features/grammar/services/grammar_style_mapper.dart';
import '../../../features/translation/translation_display_mode.dart';
import '../../../features/translation/translation_toolbar.dart';
import '../../../models/color_mode.dart';
import '../../../models/ipa_color_visibility.dart';
import '../../../models/ipa_display_mode.dart';
import '../../../models/word_analysis.dart';
import '../../../models/word_color_style.dart';
import '../../../models/word_entry.dart';
import '../../../providers/player_provider.dart';
import '../../../providers/text_provider.dart';
import '../../../providers/vocabulary_bridge.dart';
import '../../../screens/read_mode/models/playback_recipe.dart';
import '../../../screens/read_mode/services/playback_controller.dart';
import '../../../services/ipa_stress_annotator.dart';
import '../../../services/ipa_styling.dart';
import '../../../services/line_ipa_service.dart';
import '../../../services/syntax_highlighter_service.dart';
import '../controllers/read_mode_controller.dart';
import '../services/line_word_hit.dart';
import '../services/word_range_selection.dart';
import '../sheets/line_actions_sheet.dart';
import 'colored_text_widget.dart';
import 'floating_text_actions.dart';
import 'word_tap_plain_text.dart';

class TextLineWidget extends StatelessWidget {
  final int index;
  final ScrollController scrollController;

  const TextLineWidget({
    super.key,
    required this.index,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    // ★ THÊM: Lấy controller để dùng ValueNotifier
    // Dùng listen: false vì rebuild được quản lý bởi ValueListenableBuilder
    final playbackController = context.read<PlaybackController>();

    return ValueListenableBuilder<int>(
      valueListenable: playbackController.activeLineNotifier,
      builder: (_, activeLine, __) {
        return ValueListenableBuilder<bool>(
          valueListenable: playbackController.isSourceNotifier,
          builder: (_, isSource, ___) {
            // Ghost: dòng bản dịch mờ khi đang phát ngôn ngữ nguồn
            final isPlaybackActive = activeLine == index;
            final ghostTranslation = isPlaybackActive &&
                isSource &&
                playbackController.recipe.mode != PlaybackMode.enOnly;

            return Selector2<TextProvider, PlayerProvider, _LineData>(
              selector: (_, tp, pp) {
                if (index < 0 || index >= tp.lines.length) {
                  return const _LineData.empty();
                }
                final line = tp.lines[index];
                // IPA interlinear (READ-IPA-001): hidden → không tính;
                // activeLine → chỉ dòng phát / dòng hiện tại; all → mọi dòng.
                final isCurrent =
                    index == tp.currentLineIndex || isPlaybackActive;
                List<IpaSegment>? lineIpaSegments;
                if (tp.ipaDisplayMode == IpaDisplayMode.all ||
                    (tp.ipaDisplayMode == IpaDisplayMode.activeLine &&
                        isCurrent)) {
                  lineIpaSegments = tp.lineIpaSegmentsFor(index);
                }
                final ipaVisibility = tp.ipaColorVisibility;
                final analyzed = index < tp.analyzedLines.length
                    ? tp.analyzedLines[index]
                    : const <AnalyzedWord>[];
                return _LineData(
                  content: line.content,
                  translation: line.translation,
                  startTime: line.startTime,
                  endTime: line.endTime,
                  isCurrentLine: isCurrent,
                  isPlaying: _checkIsPlaying(tp, pp, index),
                  isFocusCue: index == tp.focusCueLineIndex,
                  colorMode: tp.colorMode,
                  // READ-WORDSTYLE-001: kiểu hiển thị từ (nền / chỉ màu chữ /
                  // gạch chân) — đổi ở Cài đặt là dòng vẽ lại ngay.
                  wordColorStyle: tp.wordColorStyle,
                  wordTapBoxes: tp.wordTapBoxes && analyzed.isNotEmpty,
                  showLineNumbers: tp.showLineNumbers,
                  textAlign: tp.textAlign,
                  fontSize: tp.fontSize,
                  // AUDIT v1.30.1 (mục 4): giãn dòng chỉnh real-time.
                  lineHeight: tp.readerLineHeight,
                  displayMode: tp.translationDisplayMode,
                  // AUDIT-2026-10-20 (mục 6): dùng isLineBeingSpoken ⇒
                  // dòng đang đọc được highlight kể cả khi đọc THỬ 1 dòng
                  // (trước chỉ đọc CẢ BÀI mới highlight ⇒ "có phát mà không
                  // thấy chỗ để cho dùng").
                  isSpeaking: tp.isLineBeingSpoken(index),
                  // IPA can resolve before analysis is available. Use the same
                  // source tokenizer so IPA still has tappable word positions.
                  analyzedWords: analyzed.isEmpty && lineIpaSegments != null
                      ? SyntaxHighlighterService.tokenizeText(line.content)
                          .map((word) => AnalyzedWord(word: word))
                          .toList(growable: false)
                      : analyzed,
                  ghostTranslation: ghostTranslation, // ★ Đảm bảo có dòng này
                  lineIpaSegments: lineIpaSegments,
                  ipaColorByType: tp.ipaColorByType,
                  ipaFadeKnown: tp.ipaFadeKnown,
                  ipaColorVisibility: ipaVisibility,
                  lineStress: tp.lineStressFor(lineIpaSegments),
                  linkMarks: tp.linkMarksFor(lineIpaSegments),
                );
              },
              shouldRebuild: (prev, next) => prev != next,
              builder: (context, data, _) {
                if (data.isEmpty) return const SizedBox.shrink();
                return _buildSwipeableLine(context, data);
              },
            );
          },
        );
      },
    );
  }

  static bool _checkIsPlaying(TextProvider tp, PlayerProvider pp, int index) {
    if (index >= tp.lines.length) return false;
    final line = tp.lines[index];
    if (line.startTime == null || !pp.isPlaying) return false;
    return pp.state.position >= line.startTime! &&
        (line.endTime == null || pp.state.position <= line.endTime!);
  }

  Widget _buildSwipeableLine(BuildContext context, _LineData data) {
    return Dismissible(
      key: ValueKey('line_swipe_$index'),
      confirmDismiss: (direction) async {
        final tp = context.read<TextProvider>();
        final controller = context.read<ReadModeController>();

        // ★ FIX: Guard khi lines có thể đã thay đổi trước khi gesture hoàn thành
        if (index < 0 || index >= tp.lines.length) return false;

        if (direction == DismissDirection.endToStart) {
          SafeHaptics.mediumImpact();
          controller.bookmarkLine(index);
          _showQuickBookmarkFeedback(context);
          return false;
        } else if (direction == DismissDirection.startToEnd) {
          SafeHaptics.lightImpact();
          tp.setCurrentLine(index);
          tp.speakAllLines(startIndex: index);
          return false;
        }
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Color(0xFF2196F3).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.volume_up, color: Color(0xFF2196F3), size: 20),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.bookmark_add, color: Colors.amber, size: 20),
      ),
      child: _buildLineContainer(context, data),
    );
  }

  Widget _buildLineContainer(BuildContext context, _LineData data) {
    // PSRC-234: dòng ĐÃ phân tích từ được vẽ bằng `WordTapPlainText`, widget
    // đó tự lo chạm một lần (đọc từ + pop) và chạm đúp (đọc + dịch cả dòng).
    // Tầng dòng KHÔNG được gắn `onDoubleTap` cho những dòng này:
    // `DoubleTapGestureRecognizer` GIỮ gesture arena ~300 ms, mà chạm một lần
    // vào từ phải phát âm NGAY (mất phản xạ "chạm là nghe"). Chạm giữ vẫn mở
    // `LineActionsSheet` như cũ nên không mất đường nào.
    final wordTapPlain = _usesWordTapPlainText(data);
    return GestureDetector(
      onTap: () {
        final controller = context.read<ReadModeController>();
        final tp = context.read<TextProvider>();
        if (index < 0 || index >= tp.lines.length) return; // ★ FIX
        // READ-SELECT-002: đang chọn nhiều từ ở ô chữ ⇒ "chạm ra ngoài" là
        // BỎ CHỌN (không đọc dòng/seek như thường lệ). Widget ô chữ tự thoát
        // khi thấy selection của provider đã bị xoá.
        if (WordSelectionState.isActive) {
          tp.clearSelection();
          SafeHaptics.selectionClick();
          return;
        }
        controller.removeFloatingMenu();
        tp.setCurrentLine(index);
        SafeHaptics.selectionClick();

        if (data.startTime != null) {
          context.read<PlayerProvider>().seek(data.startTime!);
        }
      },
      onDoubleTap: wordTapPlain
          ? null
          : () {
              SafeHaptics.lightImpact();
              LineActionsSheet.show(context, index);
            },
      // IN4-36: chạm giữ KHÔNG còn mở thẳng bảng sửa dòng (chức năng ít
      // dùng — "lãng phí" cử chỉ theo audit 1.10.4). Giờ chạm giữ mở
      // LineActionsSheet (đọc TTS/luân lưu/lưu/sao chép) — hữu ích;
      // "Sửa dòng…" vẫn vào được TỪ TRONG sheet đó (chủ động hơn).
      onLongPress: () {
        SafeHaptics.mediumImpact();
        LineActionsSheet.show(context, index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          // AUDIT-2026-10-20 (mục 6): thêm trạng thái "ĐANG ĐỌC" (TTS) —
          // tím ứng dụng, khác với dòng hiện tại (xanh dương) và dòng đang
          // phát audio (xanh lá) ⇒ user NHÌN THẤY ngay dòng nào đang đọc
          // (kể cả khi chỉ đọc 1 dòng).
          color: data.isFocusCue
              ? const Color(0xFFFFD54F).withValues(alpha: 0.12)
              : data.isSpeaking
                  ? const Color(0xFF6C63FF).withValues(alpha: 0.12)
                  : data.isCurrentLine
                      ? const Color(0xFF2196F3).withValues(alpha: 0.08)
                      : data.isPlaying
                          ? const Color(0xFF4CAF50).withValues(alpha: 0.08)
                          : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: data.isFocusCue
                ? const Color(0xFFFFD54F).withValues(alpha: 0.7)
                : data.isSpeaking
                    ? const Color(0xFF6C63FF).withValues(alpha: 0.45)
                    : data.isCurrentLine
                        ? const Color(0xFF2196F3).withValues(alpha: 0.25)
                        : data.isPlaying
                            ? const Color(0xFF4CAF50).withValues(alpha: 0.25)
                            : Colors.transparent,
            width: data.isFocusCue || data.isSpeaking || data.isCurrentLine
                ? 1.5
                : 1.0,
          ),
          boxShadow: data.isFocusCue
              ? [
                  BoxShadow(
                    color: const Color(0xFFFFD54F).withValues(alpha: 0.22),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: data.textAlign == TextAlign.center
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            _LineHeader(index: index, data: data),
            const SizedBox(height: 6),
            TranslationLineDisplay(
              key: ValueKey(
                  context.watch<TextProvider>().translationDocumentRevision),
              originalText: data.content,
              translatedText: data.translation,
              displayMode: data.displayMode,
              blurTranslation: context.watch<TextProvider>().blurTranslations,
              originalWidget: _buildTextContent(context, data, index),
              textAlign: data.textAlign,
              // Ghost VI: khi đang phát ngôn ngữ nguồn, dòng bản dịch mờ đi nhưng vẫn đọc được
              // Trước đây alpha 0.15 quá mờ khiến user tưởng bản dịch biến mất
              translationStyle: TextStyle(
                fontSize: data.fontSize - 2,
                color: data.ghostTranslation
                    ? Colors.grey[400]!.withValues(alpha: 0.55)
                    : Colors.grey[400],
                fontStyle: FontStyle.italic,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onLineSelectionChanged(
    BuildContext context,
    _LineData data,
    TextSelection selection,
  ) {
    if (selection.baseOffset == selection.extentOffset) return;
    final start = selection.start.clamp(0, data.content.length);
    final end = selection.end.clamp(0, data.content.length);
    if (start >= end) return;

    final tp = context.read<TextProvider>();
    if (tp.currentLineIndex != index) tp.setCurrentLine(index);
    final controller = context.read<ReadModeController>();
    final lineStartOffset = controller.getLineStartOffset(index);
    controller.handleTextSelection(
      selection: selection,
      content: data.content,
      lineStartOffset: lineStartOffset,
      lineIndex: index,
    );
    FloatingTextActions.show(
      context,
      data.content.substring(start, end),
      index,
    );
  }

  /// Match by source position, not spelling: IPA segments can include
  /// punctuation and repeated words can have different linking/stress marks.
  Map<int, InlineSpan> _wordIpaSpans(_LineData data) {
    final segments = data.lineIpaSegments;
    if (segments == null) return const {};
    final words = buildLineWordSpans(
      content: data.content,
      words:
          data.analyzedWords.map((word) => word.word).toList(growable: false),
    );
    final annotations = <int, List<InlineSpan>>{};
    var cursor = 0;
    var word = 0;
    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final surfaceStart = data.content.indexOf(segment.surface, cursor);
      if (surfaceStart < 0) continue;
      cursor = surfaceStart + segment.surface.length;
      if (!segment.hasIpa) continue;
      final coreInSurface = segment.surface.indexOf(segment.wordCore);
      if (coreInSurface < 0) continue;
      final start = surfaceStart + coreInSurface;
      final end = start + segment.wordCore.length;
      while (word < words.length && words[word].end <= start) {
        word++;
      }
      if (word == words.length || words[word].start >= end) continue;
      final spans = annotations.putIfAbsent(words[word].wordIndex, () => []);
      if (spans.isNotEmpty) spans.add(const TextSpan(text: ' '));
      spans.add(_buildSegmentSpanWithMarks(data, segments, i));
    }
    return {
      for (final entry in annotations.entries)
        entry.key: TextSpan(
          style: TextStyle(
            fontSize: data.fontSize * 0.75,
            fontWeight: data.isSpeaking || data.isPlaying
                ? FontWeight.w600
                : FontWeight.w400,
            height: 1.25,
            letterSpacing: 0.3,
          ),
          children: entry.value,
        ),
    };
  }

  /// Dựng span IPA của 1 từ trong interlinear — kèm mark nhấn/nối âm
  /// (P2/P3) + ẩn riêng từng loại (P1).
  InlineSpan _buildSegmentSpanWithMarks(
    _LineData data,
    List<IpaSegment> segments,
    int segmentIndex,
  ) {
    final seg = segments[segmentIndex];
    final emphasized = data.isSpeaking || data.isPlaying;
    final alpha = isFadedOf(data, seg.wordCore)
        ? IpaStyling.fadedAlpha
        : (emphasized ? 1.0 : 0.8);
    final base = IpaStyling.segmentSpan(
      seg,
      colorByType: data.ipaColorByType,
      alpha: alpha,
      visibility: data.ipaColorVisibility,
    );
    final primary = data.lineStress?.primaryPerWord[segmentIndex];
    final link = data.linkMarks?.length == segments.length
        ? data.linkMarks![segmentIndex]
        : IpaLinkMark.none;
    if (!data.ipaColorByType) return base;
    if (!data.ipaColorVisibility.stressWords &&
        !data.ipaColorVisibility.linking) {
      return base;
    }
    return IpaStyling.stressOrLinkFromIpa(
      base,
      seg.ipa ?? '',
      primary: data.ipaColorVisibility.stressWords ? primary : null,
      link: (data.ipaColorVisibility.linking && !link.isEmpty) ? link : null,
      showStress: data.ipaColorVisibility.stressWords,
      showLink: data.ipaColorVisibility.linking,
    );
  }

  static bool isFadedOf(_LineData data, String word) {
    if (!data.ipaFadeKnown) return false;
    final entry = VocabularyBridge.findByWord(word);
    return entry != null && entry.zone == MasteryZone.mastered;
  }

  static bool _usesWordBoxes(_LineData data) =>
      data.wordTapBoxes &&
      data.colorMode != ColorMode.none &&
      data.analyzedWords.isNotEmpty;

  /// Reuse PSRC-234 gestures whether or not the plain line has IPA.
  static bool _usesWordTapPlainText(_LineData data) =>
      !_usesWordBoxes(data) &&
      data.analyzedWords.isNotEmpty &&
      data.content.trim().isNotEmpty;

  /// POS/CEFR/difficulty: cùng đoạn chọn + lưu đầy đủ như chế độ không màu.
  /// Màu nằm trên TextSpan (không Wrap từng chip — chữ Việt không bị bể hàng).
  /// [index] = index dòng trong document (ColoredTextWidget tra trạng thái phát).
  Widget _buildTextContent(BuildContext context, _LineData data, int index) {
    final baseStyle = TextStyle(
      fontSize: data.fontSize,
      color: Colors.white,
      height: data.lineHeight,
    );

    final wordIpa = _wordIpaSpans(data);
    if (_usesWordBoxes(data)) {
      return Align(
        alignment: data.textAlign == TextAlign.center
            ? Alignment.center
            : Alignment.centerLeft,
        child: ColoredTextWidget(
          words: data.analyzedWords,
          wordIpa: wordIpa,
          fontSize: data.fontSize,
          lineHeight: data.lineHeight,
          colorMode: data.colorMode,
          lineIndex: index,
          // IN4: truyền căn lề để Wrap canh TỪNG hàng (hàng rớt khi dòng
          // dài) — trước đó hàng rớt bị canh trái, hàng đầu canh giữa.
          textAlign: data.textAlign,
          // READ-SELECT-002: offset đầu dòng để vùng chọn nhiều từ ghi vào
          // TextProvider như một selection thật (cùng công thức với
          // SelectableText ở các chế độ khác).
          lineStartOffset:
              context.read<ReadModeController>().getLineStartOffset(index),
        ),
      );
    }

    // PSRC-234: dòng CHƯA phân tích được từ (vừa import / đang phân tích /
    // dòng trống) ⇒ không có từ nào để chạm; giữ `SelectableText` để người
    // dùng vẫn bôi chọn + sao chép được như trước.
    if (!_usesWordTapPlainText(data)) {
      return SelectableText(
        data.content,
        textAlign: data.textAlign,
        style: baseStyle,
        onSelectionChanged: (selection, _) =>
            _onLineSelectionChanged(context, data, selection),
      );
    }

    final useGrammar = data.colorMode == ColorMode.wordType;
    final grammarSettings = useGrammar
        ? context.select<TextProvider, GrammarHighlightSettings>(
            (tp) => tp.grammarSettings,
          )
        : null;
    final palette = grammarSettings?.enabled == true
        ? context.select<TextProvider, GrammarPalette>(
            (tp) => tp.activeGrammarPalette,
          )
        : null;

    // PSRC-234: dòng không bật box từng từ trước đây là `SelectableText` /
    // `SelectableText.rich` ⇒ chạm một từ KHÔNG có phản ứng gì (chỉ đặt con
    // trỏ), chạm đúp không ra dòng. Nay vẽ bằng `WordTapPlainText`: chạm một
    // lần = đọc từ + pop tra nhanh, chạm đúp = đọc + dịch cả dòng, giữ + kéo
    // = chọn nhiều từ (READ-SELECT-002). Màu chữ/POS/CEFR vẫn do
    // `_wordStyle` quyết định nên nhìn không đổi.
    return WordTapPlainText(
      key: ValueKey<String>('read-wordtap-line-$index'),
      content: data.content,
      words: data.analyzedWords,
      wordIpa: wordIpa,
      lineIndex: index,
      fontSize: data.fontSize,
      textAlign: data.textAlign,
      wordStyle: (wordIndex, selected) => _wordStyle(
        data,
        grammarSettings,
        palette,
        wordIndex,
        selected,
      ),
    );
  }

  /// Nền của từ đang nằm trong vùng chọn nhiều từ (READ-SELECT-002) — cùng
  /// tông xanh với viền mỏ neo ở chế độ ô chữ.
  static const Color _wordSelectionHighlight = Color(0x5964B5F6);

  TextStyle _wordStyle(
    _LineData data,
    GrammarHighlightSettings? grammarSettings,
    GrammarPalette? palette,
    int wordIndex,
    bool selected,
  ) {
    final word = data.analyzedWords[wordIndex];
    final grammarCategory = grammarCategoryFromLegacyWordType(word.wordType);
    final grammarResolved =
        grammarSettings != null && palette != null && grammarCategory != null
            ? GrammarStyleMapper.resolve(
                category: grammarCategory,
                palette: palette,
                settings: grammarSettings,
                defaultTextColor: Colors.white,
              )
            : null;

    // READ-WORDSTYLE-001 — cùng một luật với ColoredTextWidget:
    //   fill      → nền màu + chữ màu
    //   textOnly  → chỉ chữ màu (không nền)
    //   underline → chữ màu + gạch chân màu
    final fillBackground = data.wordColorStyle == WordColorStyle.fill;
    final underlineColor = grammarResolved?.underline ??
        (data.wordColorStyle == WordColorStyle.underline
            ? (grammarResolved?.foreground ?? word.getColor(data.colorMode))
            : null);
    return TextStyle(
      color: grammarResolved?.foreground ?? word.getColor(data.colorMode),
      backgroundColor: selected
          ? _wordSelectionHighlight
          : fillBackground
              ? (grammarResolved?.background ??
                  word.getBackgroundColor(data.colorMode))
              : null,
      fontWeight: grammarResolved?.fontWeight,
      decoration: underlineColor != null ? TextDecoration.underline : null,
      decorationColor: underlineColor,
      decorationThickness: underlineColor != null ? 1.6 : null,
    );
  }

  void _showQuickBookmarkFeedback(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.bookmark_added, color: Colors.amber, size: 18),
            SizedBox(width: 8),
            Text('Đã đánh dấu dòng!'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2A2A3E),
        duration: const Duration(seconds: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      ),
    );
  }
}

class _LineHeader extends StatelessWidget {
  final int index;
  final _LineData data;

  const _LineHeader({required this.index, required this.data});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: data.textAlign == TextAlign.center
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        if (data.showLineNumbers) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: data.isCurrentLine
                  ? Color(0xFF2196F3).withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              context.uiText('${index + 1}'),
              style: TextStyle(
                color: data.isCurrentLine
                    ? const Color(0xFF2196F3)
                    : Colors.grey[600],
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
        if (data.startTime != null) ...[
          Icon(
            Icons.access_time,
            size: 10,
            color: data.isPlaying ? const Color(0xFF4CAF50) : Colors.grey[600],
          ),
          const SizedBox(width: 2),
          Text(
            _formatDuration(data.startTime!),
            style: TextStyle(
              fontSize: 11,
              color:
                  data.isPlaying ? const Color(0xFF4CAF50) : Colors.grey[600],
              fontFamily: 'monospace',
            ),
          ),
        ],
        const Spacer(),
        if (data.isSpeaking)
          const Icon(Icons.graphic_eq, color: Color(0xFF6C63FF), size: 14),
        if (data.isPlaying)
          const Icon(Icons.volume_up, color: Color(0xFF4CAF50), size: 14),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}

class _LineData {
  final String content;
  final String? translation;
  final Duration? startTime;
  final Duration? endTime;
  final bool isCurrentLine;
  final bool isPlaying;
  final bool isFocusCue;
  final ColorMode colorMode;

  /// READ-WORDSTYLE-001 — nền màu / chỉ màu chữ / gạch chân.
  final WordColorStyle wordColorStyle;
  final bool wordTapBoxes;
  final bool showLineNumbers;
  final TextAlign textAlign;
  final double fontSize;

  /// AUDIT v1.30.1 (mục 4) — giãn dòng (TextStyle.height) của vùng đọc.
  final double lineHeight;
  final TranslationDisplayMode displayMode;
  final bool isSpeaking;
  final List<AnalyzedWord> analyzedWords;
  final bool isEmpty;
  final bool ghostTranslation; // ★ ĐÃ THÊM
  /// Segments IPA theo từ (null = ẩn hoặc không đủ điều kiện).
  final List<IpaSegment>? lineIpaSegments;

  /// READ-IPA-004: tô màu phoneme + mờ IPA từ đã thuộc (default OFF).
  final bool ipaColorByType;
  final bool ipaFadeKnown;

  /// READ-IPA-006: ẩn riêng từng loại màu + đánh dấu nhấn/nối âm.
  final IpaColorVisibility ipaColorVisibility;
  final IpaLineStress? lineStress;
  final List<IpaLinkMark>? linkMarks;

  const _LineData({
    required this.content,
    this.translation,
    this.startTime,
    this.endTime,
    required this.isCurrentLine,
    required this.isPlaying,
    required this.isFocusCue,
    required this.colorMode,
    this.wordColorStyle = WordColorStyle.textOnly,
    this.wordTapBoxes = false,
    required this.showLineNumbers,
    required this.textAlign,
    required this.fontSize,
    this.lineHeight = 1.6,
    required this.displayMode,
    required this.isSpeaking,
    required this.analyzedWords,
    this.isEmpty = false,
    this.ghostTranslation = false, // ★ ĐÃ THÊM
    this.lineIpaSegments,
    this.ipaColorByType = false,
    this.ipaFadeKnown = false,
    this.ipaColorVisibility = IpaColorVisibility.all,
    this.lineStress,
    this.linkMarks,
  });

  const _LineData.empty()
      : content = '',
        translation = null,
        startTime = null,
        endTime = null,
        isCurrentLine = false,
        isPlaying = false,
        isFocusCue = false,
        colorMode = ColorMode.none,
        wordColorStyle = WordColorStyle.textOnly,
        wordTapBoxes = false,
        showLineNumbers = true,
        // READ-ALIGN-001: mặc định căn GIỮA (trước đây trái).
        textAlign = TextAlign.center,
        fontSize = 18,
        lineHeight = 1.6,
        displayMode = TranslationDisplayMode.hidden,
        isSpeaking = false,
        analyzedWords = const [],
        isEmpty = true,
        ghostTranslation = false, // ★ ĐÃ THÊM
        lineIpaSegments = null,
        ipaColorByType = false,
        ipaFadeKnown = false,
        ipaColorVisibility = IpaColorVisibility.all,
        lineStress = null,
        linkMarks = null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _LineData) return false;
    if (isEmpty != other.isEmpty) return false;
    if (isEmpty) return true; // 2 empty đều bằng nhau

    if (analyzedWords.length != other.analyzedWords.length) return false;

    return content == other.content &&
        translation == other.translation &&
        isCurrentLine == other.isCurrentLine &&
        isPlaying == other.isPlaying &&
        isFocusCue == other.isFocusCue &&
        colorMode == other.colorMode &&
        wordColorStyle == other.wordColorStyle &&
        wordTapBoxes == other.wordTapBoxes &&
        showLineNumbers == other.showLineNumbers &&
        textAlign == other.textAlign &&
        fontSize == other.fontSize &&
        lineHeight == other.lineHeight &&
        displayMode == other.displayMode &&
        isSpeaking == other.isSpeaking &&
        lineIpaSegments == other.lineIpaSegments &&
        ipaColorByType == other.ipaColorByType &&
        ipaFadeKnown == other.ipaFadeKnown &&
        ipaColorVisibility == other.ipaColorVisibility &&
        _mapEqualsNullable(
            lineStressToMap(lineStress), lineStressToMap(other.lineStress)) &&
        _listEqualsNullable(linkMarks, other.linkMarks) &&
        ghostTranslation == other.ghostTranslation; // ★ ĐÃ THÊM
  }

  static bool _mapEqualsNullable(
          Map<int, IpaStressSyllable>? a, Map<int, IpaStressSyllable>? b) =>
      a == null || b == null ? a == b : mapEquals(a, b);

  static bool _listEqualsNullable(List<IpaLinkMark>? a, List<IpaLinkMark>? b) =>
      a == null || b == null ? a == b : listEquals(a, b);

  static Map<int, IpaStressSyllable>? lineStressToMap(IpaLineStress? s) =>
      s?.primaryPerWord;

  @override
  int get hashCode => isEmpty
      ? 0
      : Object.hash(
          content,
          translation,
          isCurrentLine,
          isPlaying,
          isFocusCue,
          colorMode,
          wordColorStyle,
          showLineNumbers,
          textAlign,
          fontSize,
          lineHeight,
          displayMode,
          isSpeaking,
          lineIpaSegments == null ? null : Object.hashAll(lineIpaSegments!),
          ipaColorByType,
          ipaFadeKnown,
          ipaColorVisibility,
          ghostTranslation, // ★ ĐÃ THÊM
        );
}
