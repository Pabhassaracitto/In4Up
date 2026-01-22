import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../providers/text_provider.dart';
import '../models/text_item.dart';

class SyncedLyricsView extends StatefulWidget {
  final bool autoScroll;
  final Function(int index, TextItem line)? onLineTap;
  final Function(int index, TextItem line)? onLineDoubleTap;
  final Function(int index, TextItem line)? onLineLongPress;

  const SyncedLyricsView({
    super.key,
    this.autoScroll = true,
    this.onLineTap,
    this.onLineDoubleTap,
    this.onLineLongPress,
  });

  @override
  State<SyncedLyricsView> createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends State<SyncedLyricsView> {
  final ScrollController _scrollController = ScrollController();
  int _lastScrolledIndex = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index) {
    if (!widget.autoScroll) return;
    if (index == _lastScrolledIndex) return;
    if (!_scrollController.hasClients) return;

    _lastScrolledIndex = index;

    final itemHeight = 100.0; // Approximate height per item
    final targetOffset = index * itemHeight;
    final maxOffset = _scrollController.position.maxScrollExtent;
    final viewportHeight = _scrollController.position.viewportDimension;

    // Center the item in viewport
    var offset = targetOffset - (viewportHeight / 2) + (itemHeight / 2);
    offset = offset.clamp(0.0, maxOffset);

    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<PlayerProvider, TextProvider>(
      builder: (context, player, textProvider, child) {
        final lines = textProvider.lines;
        final currentIndex = textProvider.currentLineIndex;

        // Auto scroll when current line changes
        if (widget.autoScroll && currentIndex >= 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToIndex(currentIndex);
          });
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.text_snippet, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      '${lines.length} dòng',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const Spacer(),
                    if (textProvider.isSpeaking)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.volume_up, size: 14, color: Colors.blue),
                            SizedBox(width: 4),
                            Text('TTS', style: TextStyle(color: Colors.blue, fontSize: 12)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Lyrics list
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: lines.length,
                  itemBuilder: (context, index) {
                    final line = lines[index];
                    final isCurrentLine = index == currentIndex;
                    final isPastLine = index < currentIndex;

                    return _LyricLine(
                      line: line,
                      index: index,
                      isCurrentLine: isCurrentLine,
                      isPastLine: isPastLine,
                      fontSize: textProvider.fontSize,
                      showTranslation: textProvider.showTranslation,
                      onTap: () => widget.onLineTap?.call(index, line),
                      onDoubleTap: () => widget.onLineDoubleTap?.call(index, line),
                      onLongPress: () => widget.onLineLongPress?.call(index, line),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LyricLine extends StatelessWidget {
  final TextItem line;
  final int index;
  final bool isCurrentLine;
  final bool isPastLine;
  final double fontSize;
  final bool showTranslation;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;

  const _LyricLine({
    required this.line,
    required this.index,
    required this.isCurrentLine,
    required this.isPastLine,
    required this.fontSize,
    required this.showTranslation,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCurrentLine
              ? const Color(0xFF6C63FF).withOpacity(0.15)
              : isPastLine
              ? Colors.white.withOpacity(0.02)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrentLine
                ? const Color(0xFF6C63FF)
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main text
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Line number
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCurrentLine
                        ? const Color(0xFF6C63FF)
                        : Colors.white.withOpacity(0.1),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: isCurrentLine ? Colors.white : Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.content,
                        style: TextStyle(
                          fontSize: isCurrentLine ? fontSize + 2 : fontSize,
                          fontWeight: isCurrentLine ? FontWeight.bold : FontWeight.normal,
                          color: isCurrentLine
                              ? Colors.white
                              : isPastLine
                              ? Colors.white54
                              : Colors.white70,
                          height: 1.5,
                        ),
                      ),

                      // Translation
                      if (showTranslation && line.translation != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          line.translation!,
                          style: TextStyle(
                            fontSize: fontSize - 2,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Current line indicator
                if (isCurrentLine)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF6C63FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),

            // Time info (if available)
            if (line.startTime != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 40),
                child: Text(
                  _formatDuration(line.startTime!),
                  style: TextStyle(
                    fontSize: 10,
                    color: isCurrentLine
                        ? const Color(0xFF6C63FF)
                        : Colors.grey,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    String minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    String seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}