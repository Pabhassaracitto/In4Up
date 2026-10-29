import 'dart:async';

import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:in4up/core/language/localized_material.dart';
import 'package:in4up/providers/karaoke_settings_provider.dart';
import 'package:in4up_stt/stt_lrc_converter.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'karaoke_lyrics_line.dart';

/// Virtualized lyrics shared by Listen and Understand. Scroll by item index
/// and measured visibility, not a guessed fixed height: lines can wrap, have
/// translations, and change height with text scale or panel resizing.
class KaraokeTranscriptView extends StatefulWidget {
  const KaraokeTranscriptView({
    super.key,
    required this.lines,
    required this.currentLineIndex,
    required this.currentWordIndex,
    required this.wordsForLine,
    required this.style,
    required this.autoFollow,
    required this.onLineTap,
    this.onLineLongPress,
    this.translationForLine,
    this.compact = false,
  });

  final List<LrcLine> lines;
  final int currentLineIndex;
  final int currentWordIndex;
  final List<LrcWord> Function(int index) wordsForLine;
  final KaraokeStyle style;
  final bool autoFollow;
  final ValueChanged<LrcLine> onLineTap;
  final ValueChanged<LrcLine>? onLineLongPress;
  final String? Function(LrcLine line)? translationForLine;
  final bool compact;

  @override
  State<KaraokeTranscriptView> createState() => _KaraokeTranscriptViewState();
}

class _KaraokeTranscriptViewState extends State<KaraokeTranscriptView> {
  final ItemScrollController _items = ItemScrollController();
  final ItemPositionsListener _positions = ItemPositionsListener.create();
  Timer? _resumeTimer;
  bool _userScrolling = false;
  bool _followScheduled = false;
  int _followGeneration = 0;
  Size? _lastViewport;

  bool get _singleLine =>
      widget.style.displayMode == KaraokeDisplayMode.currentLineOnly;

  bool get _hasCurrent => widget.currentLineIndex >= 0 &&
      widget.currentLineIndex < widget.lines.length;

  @override
  void initState() {
    super.initState();
    _scheduleFollow();
  }

  @override
  void didUpdateWidget(covariant KaraokeTranscriptView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentLineIndex != widget.currentLineIndex ||
        oldWidget.lines != widget.lines ||
        oldWidget.style != widget.style ||
        oldWidget.autoFollow != widget.autoFollow) {
      _scheduleFollow();
    }
  }

  @override
  void dispose() {
    _followGeneration++;
    _resumeTimer?.cancel();
    super.dispose();
  }

  void _scheduleFollow() {
    if (_followScheduled) return;
    _followScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _followScheduled = false;
      if (mounted) _followCurrent();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _followCurrent() {
    if (!widget.autoFollow || _userScrolling || _singleLine ||
        !_hasCurrent || !_items.isAttached ||
        _lastViewport == null || _lastViewport!.height <= 0) {
      return;
    }

    final index = widget.currentLineIndex;
    ItemPosition? current;
    for (final position in _positions.itemPositions.value) {
      if (position.index == index) {
        current = position;
        break;
      }
    }
    if (current == null) {
      // Large seeks should not depend on any approximation of preceding
      // heights. Jump directly to the indexed item, then check its true size.
      _followGeneration++;
      _items.jumpTo(index: index, alignment: .08);
      _scheduleFollow();
      return;
    }

    final leading = current.itemLeadingEdge;
    final trailing = current.itemTrailingEdge;
    final extent = trailing - leading;
    const epsilon = .02;
    final fullyVisible = leading >= -epsilon && trailing <= 1 + epsilon;
    // An exceptionally tall line cannot fit all at once. Keep its beginning
    // visible and allow the user to scroll through it rather than oscillating.
    final tallLineAtTop = extent >= 1 && leading >= -epsilon && leading <= .08;
    if (fullyVisible || tallLineAtTop) return;

    final alignment = extent >= 1 ? 0.0 : ((1 - extent) / 2).clamp(.02, .35);
    final generation = ++_followGeneration;
    _items.scrollTo(
      index: index,
      alignment: alignment,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    ).then((_) {
      if (mounted && generation == _followGeneration) _scheduleFollow();
    });
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    final userStarted = notification is ScrollStartNotification &&
            notification.dragDetails != null ||
        notification is UserScrollNotification &&
            notification.direction != ScrollDirection.idle;
    if (userStarted) {
      _resumeTimer?.cancel();
      _followGeneration++;
      _userScrolling = true;
    } else if (notification is ScrollEndNotification && _userScrolling) {
      // Do not fight a finger, mouse wheel, keyboard scroll, or fling. Once the
      // interaction settles, restore follow even if playback is paused.
      _resumeTimer?.cancel();
      _resumeTimer = Timer(const Duration(milliseconds: 2500), () {
        if (!mounted) return;
        _userScrolling = false;
        _scheduleFollow();
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      if (_lastViewport != size) {
        _lastViewport = size;
        _scheduleFollow();
      }
      if (_singleLine && !_hasCurrent) {
        return Center(
          child: Text(
            context.uiText('Chưa đến dòng đầu tiên'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54),
          ),
        );
      }

      final count = _singleLine ? 1 : widget.lines.length;
      final initialIndex = !_singleLine && _hasCurrent ? widget.currentLineIndex : 0;
      return NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: ScrollablePositionedList.builder(
          key: ValueKey(widget.style.displayMode),
          itemScrollController: _items,
          itemPositionsListener: _positions,
          initialScrollIndex: initialIndex,
          initialAlignment: .08,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: count,
          itemBuilder: (context, displayIndex) {
            final index = _singleLine ? widget.currentLineIndex : displayIndex;
            final line = widget.lines[index];
            final active = index == widget.currentLineIndex;
            return Semantics(
              key: ValueKey('karaoke-line-$index'),
              button: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onLineTap(line),
                onLongPress: widget.onLineLongPress == null
                    ? null
                    : () => widget.onLineLongPress!(line),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: widget.compact
                      ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2)
                      : EdgeInsets.zero,
                  padding: EdgeInsets.symmetric(
                    vertical: widget.compact && size.height < 80 ? 2 : 10,
                    horizontal: widget.compact ? 12 : 16,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFF6C63FF).withValues(alpha: .15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(widget.compact ? 10 : 8),
                    border: widget.compact && active
                        ? Border.all(
                            color: const Color(0xFF6C63FF).withValues(alpha: .25),
                          )
                        : null,
                  ),
                  child: KaraokeLyricsLine(
                    line: line,
                    isActive: active,
                    words: active ? widget.wordsForLine(index) : const [],
                    activeWordIndex: active ? widget.currentWordIndex : -1,
                    style: widget.style,
                    translation: widget.translationForLine?.call(line),
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }
}
