// lib/screens/read_mode/widgets/text_line_widget.dart
// ★ FIX: Thêm guard index trong Selector2 để tránh RangeError khi lines thay đổi

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../features/translation/translation_display_mode.dart';
import '../../../features/translation/translation_toolbar.dart';
import '../../../models/color_mode.dart';
import '../../../models/word_analysis.dart';
import '../../../providers/player_provider.dart';
import '../../../providers/text_provider.dart';
import '../../../screens/read_mode/models/playback_recipe.dart';
import '../../../screens/read_mode/services/playback_controller.dart';
import '../controllers/read_mode_controller.dart';
import '../sheets/line_actions_sheet.dart';
import '../sheets/line_edit_sheet.dart';
import 'colored_text_widget.dart';
import 'floating_text_actions.dart';

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
          valueListenable: playbackController.isENNotifier,
          builder: (_, isEN, ___) {
            // Ghost: dòng VI mờ khi đang phát EN
            final isPlaybackActive = activeLine == index;
            final ghostVI = isPlaybackActive &&
                isEN &&
                playbackController.recipe.mode != PlaybackMode.enOnly;

            return Selector2<TextProvider, PlayerProvider, _LineData>(
              selector: (_, tp, pp) {
                if (index < 0 || index >= tp.lines.length) {
                  return const _LineData.empty();
                }
                final line = tp.lines[index];
                return _LineData(
                  content: line.content,
                  translation: line.translation,
                  startTime: line.startTime,
                  endTime: line.endTime,
                  isCurrentLine:
                      index == tp.currentLineIndex || isPlaybackActive,
                  isPlaying: _checkIsPlaying(tp, pp, index),
                  isFocusCue: index == tp.focusCueLineIndex,
                  colorMode: tp.colorMode,
                  showLineNumbers: tp.showLineNumbers,
                  textAlign: tp.textAlign,
                  fontSize: tp.fontSize,
                  displayMode: tp.translationDisplayMode,
                  isSpeaking: tp.isSpeaking && index == tp.currentLineIndex,
                  analyzedWords: index < tp.analyzedLines.length
                      ? tp.analyzedLines[index]
                      : const <AnalyzedWord>[],
                  ghostVI: ghostVI, // ★ Đảm bảo có dòng này
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
          HapticFeedback.mediumImpact();
          controller.bookmarkLine(index);
          _showQuickBookmarkFeedback(context);
          return false;
        } else if (direction == DismissDirection.startToEnd) {
          HapticFeedback.lightImpact();
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
    return GestureDetector(
      onTap: () {
        final controller = context.read<ReadModeController>();
        final tp = context.read<TextProvider>();
        if (index < 0 || index >= tp.lines.length) return; // ★ FIX
        controller.removeFloatingMenu();
        tp.setCurrentLine(index);
        HapticFeedback.selectionClick();

        if (data.startTime != null) {
          context.read<PlayerProvider>().seek(data.startTime!);
        }
      },
      onDoubleTap: () {
        HapticFeedback.lightImpact();
        LineActionsSheet.show(context, index);
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        LineEditSheet.show(context, index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: data.isFocusCue
              ? const Color(0xFFFFD54F).withValues(alpha: 0.12)
              : data.isCurrentLine
                  ? const Color(0xFF2196F3).withValues(alpha: 0.08)
                  : data.isPlaying
                      ? const Color(0xFF4CAF50).withValues(alpha: 0.08)
                      : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: data.isFocusCue
                ? const Color(0xFFFFD54F).withValues(alpha: 0.7)
                : data.isCurrentLine
                    ? const Color(0xFF2196F3).withValues(alpha: 0.25)
                    : data.isPlaying
                        ? const Color(0xFF4CAF50).withValues(alpha: 0.25)
                        : Colors.transparent,
            width: data.isFocusCue || data.isCurrentLine ? 1.5 : 1.0,
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
              originalText: data.content,
              translatedText: data.translation,
              displayMode: data.displayMode,
              originalWidget: _buildTextContent(context, data),
              textAlign: data.textAlign,
              // ★ Ghost Sentence: Mờ đi khi đang đọc Tiếng Anh (ghostVI = true)
              translationStyle: TextStyle(
                fontSize: data.fontSize - 2,
                color: data.ghostVI
                    ? Colors.grey[500]!.withValues(alpha: 0.15)
                    : Colors.grey[500],
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextContent(BuildContext context, _LineData data) {
    if (data.colorMode == ColorMode.none) {
      return SelectableText(
        data.content,
        textAlign: data.textAlign,
        style: TextStyle(
          fontSize: data.fontSize,
          color: Colors.white,
          height: 1.6,
        ),
        onSelectionChanged: (selection, cause) {
          if (selection.baseOffset != selection.extentOffset) {
            final controller = context.read<ReadModeController>();
            final lineStartOffset = controller.getLineStartOffset(index);

            controller.handleTextSelection(
              selection: selection,
              content: data.content,
              lineStartOffset: lineStartOffset,
              lineIndex: index,
            );

            final selectedText =
                data.content.substring(selection.start, selection.end);
            FloatingTextActions.show(context, selectedText, index);
          }
        },
      );
    }

    return Align(
      alignment: data.textAlign == TextAlign.center
          ? Alignment.center
          : Alignment.centerLeft,
      child: ColoredTextWidget(
        words: data.analyzedWords,
        fontSize: data.fontSize,
        colorMode: data.colorMode,
        lineIndex: index,
      ),
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
              '${index + 1}',
              style: TextStyle(
                color: data.isCurrentLine
                    ? const Color(0xFF2196F3)
                    : Colors.grey[600],
                fontSize: 10,
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
              fontSize: 9,
              color:
                  data.isPlaying ? const Color(0xFF4CAF50) : Colors.grey[600],
              fontFamily: 'monospace',
            ),
          ),
        ],
        const Spacer(),
        if (data.isSpeaking)
          const Icon(Icons.graphic_eq, color: Color(0xFF2196F3), size: 14),
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
  final bool showLineNumbers;
  final TextAlign textAlign;
  final double fontSize;
  final TranslationDisplayMode displayMode;
  final bool isSpeaking;
  final List<AnalyzedWord> analyzedWords;
  final bool isEmpty;
  final bool ghostVI; // ★ ĐÃ THÊM

  const _LineData({
    required this.content,
    this.translation,
    this.startTime,
    this.endTime,
    required this.isCurrentLine,
    required this.isPlaying,
    required this.isFocusCue,
    required this.colorMode,
    required this.showLineNumbers,
    required this.textAlign,
    required this.fontSize,
    required this.displayMode,
    required this.isSpeaking,
    required this.analyzedWords,
    this.isEmpty = false,
    this.ghostVI = false, // ★ ĐÃ THÊM
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
        showLineNumbers = true,
        textAlign = TextAlign.left,
        fontSize = 18,
        displayMode = TranslationDisplayMode.hidden,
        isSpeaking = false,
        analyzedWords = const [],
        isEmpty = true,
        ghostVI = false; // ★ ĐÃ THÊM

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
        showLineNumbers == other.showLineNumbers &&
        textAlign == other.textAlign &&
        fontSize == other.fontSize &&
        displayMode == other.displayMode &&
        isSpeaking == other.isSpeaking &&
        ghostVI == other.ghostVI; // ★ ĐÃ THÊM
  }

  @override
  int get hashCode => isEmpty
      ? 0
      : Object.hash(
          content,
          isCurrentLine,
          isPlaying,
          isFocusCue,
          colorMode,
          showLineNumbers,
          textAlign,
          fontSize,
          displayMode,
          isSpeaking,
          ghostVI, // ★ ĐÃ THÊM
        );
}
