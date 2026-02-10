// lib/screens/read_mode/widgets/text_line_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../providers/text_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../models/word_analysis.dart';
import '../controllers/read_mode_controller.dart';
import 'colored_text_widget.dart';
import 'floating_text_actions.dart';
import '../sheets/line_actions_sheet.dart';
import '../../../models/color_mode.dart';

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
    // Selector: chỉ rebuild khi dữ liệu DÒNG NÀY thay đổi
    return Selector2<TextProvider, PlayerProvider, _LineData>(
      selector: (_, tp, pp) => _LineData(
        content: tp.lines[index].content,
        translation: tp.lines[index].translation,
        startTime: tp.lines[index].startTime,
        endTime: tp.lines[index].endTime,
        isCurrentLine: index == tp.currentLineIndex,
        isPlaying: _checkIsPlaying(tp, pp, index),
        colorMode: tp.colorMode,
        fontSize: tp.fontSize,
        showTranslation: tp.showTranslation,
        isSpeaking: tp.isSpeaking && index == tp.currentLineIndex,
        analyzedWords: index < tp.analyzedLines.length
            ? tp.analyzedLines[index]
            : const <AnalyzedWord>[],
      ),
      shouldRebuild: (prev, next) => prev != next,
      builder: (context, data, _) {
        return _buildSwipeableLine(context, data);
      },
    );
  }

  static bool _checkIsPlaying(TextProvider tp, PlayerProvider pp, int index) {
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

        if (direction == DismissDirection.endToStart) {
          // ← Swipe trái: Bookmark dòng
          HapticFeedback.mediumImpact();
          controller.bookmarkLine(index);
          _showQuickBookmarkFeedback(context);
          return false;
        } else if (direction == DismissDirection.startToEnd) {
          // → Swipe phải: TTS đọc dòng
          HapticFeedback.lightImpact();
          tp.setCurrentLine(index);
          tp.speakCurrentLine();
          return false;
        }
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF2196F3).withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.volume_up, color: Color(0xFF2196F3), size: 20),
            const SizedBox(width: 8),
            Text(
              'TTS',
              style: TextStyle(
                color: const Color(0xFF2196F3).withOpacity(0.8),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Lưu',
              style: TextStyle(
                color: Colors.amber.withOpacity(0.8),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.bookmark_add, color: Colors.amber, size: 20),
          ],
        ),
      ),
      child: _buildLineContainer(context, data),
    );
  }

  Widget _buildLineContainer(BuildContext context, _LineData data) {
    return GestureDetector(
      onTap: () {
        final controller = context.read<ReadModeController>();
        final tp = context.read<TextProvider>();
        controller.removeFloatingMenu();
        tp.setCurrentLine(index);
        HapticFeedback.selectionClick();
      },
      onDoubleTap: () {
        final tp = context.read<TextProvider>();
        tp.setCurrentLine(index);
        tp.speakCurrentLine();
      },
      onLongPress: () {
        LineActionsSheet.show(context, index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: data.isCurrentLine
              ? const Color(0xFF2196F3).withOpacity(0.08)
              : data.isPlaying
                  ? const Color(0xFF4CAF50).withOpacity(0.08)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: data.isCurrentLine
                ? const Color(0xFF2196F3).withOpacity(0.25)
                : data.isPlaying
                    ? const Color(0xFF4CAF50).withOpacity(0.25)
                    : Colors.transparent,
            width: data.isCurrentLine ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Line header
            _LineHeader(
              index: index,
              data: data,
            ),
            const SizedBox(height: 6),

            // Text content
            _buildTextContent(context, data),

            // Translation
            if (data.showTranslation && data.translation != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  data.translation!,
                  style: TextStyle(
                    fontSize: data.fontSize - 2,
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTextContent(BuildContext context, _LineData data) {
    if (data.colorMode == ColorMode.none) {
      return SelectableText(
        data.content,
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

            final start = selection.start;
            final end = selection.end;
            final selectedText = data.content.substring(start, end);

            FloatingTextActions.show(context, selectedText, index);
          }
        },
      );
    }

    return ColoredTextWidget(
      words: data.analyzedWords,
      fontSize: data.fontSize,
      colorMode: data.colorMode,
      lineIndex: index,
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

// ==================== LINE HEADER ====================

class _LineHeader extends StatelessWidget {
  final int index;
  final _LineData data;

  const _LineHeader({required this.index, required this.data});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Line number
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: data.isCurrentLine
                ? const Color(0xFF2196F3).withOpacity(0.2)
                : Colors.white.withOpacity(0.05),
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

        // Timestamp (if synced)
        if (data.startTime != null) ...[
          const SizedBox(width: 6),
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

        // Status indicators
        if (data.isSpeaking)
          const _PulsingIcon(
            icon: Icons.graphic_eq,
            color: Color(0xFF2196F3),
            size: 14,
          ),
        if (data.isPlaying)
          const _PulsingIcon(
            icon: Icons.volume_up,
            color: Color(0xFF4CAF50),
            size: 14,
          ),

        // Swipe hint (cho dòng hiện tại)
        if (data.isCurrentLine) ...[
          const SizedBox(width: 8),
          Text(
            '← TTS | Lưu →',
            style: TextStyle(
              fontSize: 8,
              color: Colors.grey[700],
            ),
          ),
        ],
      ],
    );
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}

// ==================== PULSING ICON ====================

class _PulsingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _PulsingIcon({
    required this.icon,
    required this.color,
    this.size = 14,
  });

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Icon(widget.icon, size: widget.size, color: widget.color),
    );
  }
}

// ==================== DATA CLASS ====================

class _LineData {
  final String content;
  final String? translation;
  final Duration? startTime;
  final Duration? endTime;
  final bool isCurrentLine;
  final bool isPlaying;
  final ColorMode colorMode;
  final double fontSize;
  final bool showTranslation;
  final bool isSpeaking;
  final List<AnalyzedWord> analyzedWords;

  const _LineData({
    required this.content,
    this.translation,
    this.startTime,
    this.endTime,
    required this.isCurrentLine,
    required this.isPlaying,
    required this.colorMode,
    required this.fontSize,
    required this.showTranslation,
    required this.isSpeaking,
    required this.analyzedWords,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _LineData) return false;

    // FIX VẤN ĐỀ 8: So sánh sâu (Deep comparison) danh sách từ
    bool listEquals(List<AnalyzedWord> a, List<AnalyzedWord> b) {
      if (a.length != b.length) return false;
      for (int i = 0; i < a.length; i++) {
        // AnalyzedWord cũng cần override == (đã làm ở model)
        if (a[i] != b[i]) return false;
      }
      return true;
    }

    return content == other.content &&
        translation == other.translation &&
        isCurrentLine == other.isCurrentLine &&
        isPlaying == other.isPlaying &&
        colorMode == other.colorMode &&
        fontSize == other.fontSize &&
        showTranslation == other.showTranslation &&
        isSpeaking == other.isSpeaking &&
        // Sử dụng hàm so sánh list thay vì chỉ so sánh length
        listEquals(analyzedWords, other.analyzedWords);
  }

  @override
  int get hashCode => Object.hash(
        content,
        isCurrentLine,
        isPlaying,
        colorMode,
        fontSize,
        showTranslation,
        isSpeaking,
        // Hash code của list
        Object.hashAll(analyzedWords),
      );
}
