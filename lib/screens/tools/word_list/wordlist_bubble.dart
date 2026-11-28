// lib/screens/tools/word_list/wordlist_bubble.dart
// Floating round bubble that shows wordlist TTS status across tabs.
// Non-destructive tap: expands/collapses readout; explicit 44pt stop button stops TTS.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in4up/core/language/localized_material.dart' hide Text;
import 'package:in4up/core/theme/app_colors.dart';
import 'package:in4up/core/theme/app_spacing.dart';
import 'package:in4up/core/theme/app_typography.dart';

import 'word_list_screen.dart';
import 'wordlist_playback_service.dart';

const Key wordlistBubbleStopButtonKey = Key('wordlist_bubble_stop_button');

class WordlistBubble extends StatefulWidget {
  const WordlistBubble({super.key});

  @override
  State<WordlistBubble> createState() => _WordlistBubbleState();
}

class _WordlistBubbleState extends State<WordlistBubble>
    with SingleTickerProviderStateMixin {
  final _service = WordlistPlaybackService();

  Offset _position = const Offset(20, 120);
  bool _isDragging = false;
  bool _isExpanded = true;
  Timer? _autoHideTimer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceChanged);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scheduleAutoHide();
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    _service.removeListener(_onServiceChanged);
    _pulseController.dispose();
    super.dispose();
  }

  void _onServiceChanged() {
    if (!mounted) return;
    setState(() {});
    if (_service.isPlaying) {
      _scheduleAutoHide();
      if (!_isExpanded) {
        setState(() => _isExpanded = true);
      }
    }
  }

  void _scheduleAutoHide() {
    _autoHideTimer?.cancel();
    if (!_service.isPlaying) return;
    _autoHideTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      if (_isDragging) {
        _scheduleAutoHide();
        return;
      }
      setState(() => _isExpanded = false);
    });
  }

  void _handleBodyTap() {
    HapticFeedback.selectionClick();
    setState(() => _isExpanded = !_isExpanded);
    if (_isExpanded) {
      _scheduleAutoHide();
    } else {
      _autoHideTimer?.cancel();
    }
  }

  void _handleStopTap() {
    HapticFeedback.mediumImpact();
    _service.stopPlayback();
  }

  void _handleOpenWordlist() {
    HapticFeedback.heavyImpact();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WordListScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_service.shouldShowBubble) {
      return const SizedBox.shrink();
    }

    final current = _service.currentWord;
    final progressText =
        '${_service.playingIndex + 1}/${_service.queue.length}';
    final repeatText = _service.playingRepeatCurrent > 1
        ? ' · ×${_service.playingRepeatCurrent}'
        : '';
    final listRepeat = _service.listRepeatCount > 1
        ? ' · ${_service.listRepeatCurrent}/${_service.listRepeatCount == 0 ? '∞' : _service.listRepeatCount}'
        : '';

    final screenSize = MediaQuery.of(context).size;
    final bubbleWidth = _isExpanded ? 228.0 : 58.0;
    final maxX = (screenSize.width - bubbleWidth - 12).clamp(12.0, double.infinity);
    final maxY = (screenSize.height - 160).clamp(80.0, double.infinity);
    final pos = Offset(
      _position.dx.clamp(12.0, maxX),
      _position.dy.clamp(80.0, maxY),
    );

    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: GestureDetector(
        onPanStart: (_) {
          setState(() => _isDragging = true);
          _autoHideTimer?.cancel();
        },
        onPanUpdate: (details) {
          setState(() {
            _position += details.delta;
          });
        },
        onPanEnd: (_) {
          setState(() => _isDragging = false);
          _scheduleAutoHide();
        },
        onTap: _handleBodyTap,
        onLongPress: _handleOpenWordlist,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          width: bubbleWidth,
          height: 58,
          decoration: BoxDecoration(
            color: AppColors.surfaceModal.withValues(
              alpha: _isExpanded ? 0.96 : 0.9,
            ),
            borderRadius: BorderRadius.circular(_isExpanded ? 16 : 29),
            border: Border.all(
              color: AppColors.accentPrimary.withValues(alpha: 0.45),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentPrimary.withValues(alpha: 0.32),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _isExpanded
              ? _buildExpanded(current, progressText, repeatText, listRepeat)
              : _buildCollapsed(),
        ),
      ),
    );
  }

  Widget _buildCollapsed() {
    return Stack(
      alignment: Alignment.center,
      children: [
        FadeTransition(
          opacity: Tween(begin: 0.6, end: 1.0).animate(_pulseController),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accentPrimary.withValues(alpha: 0.18),
            ),
          ),
        ),
        const Icon(
          Icons.volume_up_rounded,
          color: Color(0xFF9C8FFF),
          size: 22,
        ),
        Positioned(
          bottom: 6,
          right: 8,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.accentRemember,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surfaceModal, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpanded(
    dynamic current,
    String progressText,
    String repeatText,
    String listRepeat,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.accentPrimary.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.volume_up_rounded,
              color: Color(0xFF9C8FFF),
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _service.currentStepText ?? current?.word ?? '...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppTypography.subheadSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '$progressText$repeatText$listRepeat',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: AppTypography.captionSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Tooltip(
            message: context.uiText('Dừng đọc từ vựng'),
            child: GestureDetector(
              key: wordlistBubbleStopButtonKey,
              behavior: HitTestBehavior.opaque,
              onTap: _handleStopTap,
              child: SizedBox(
                width: AppSpacing.minTouchTarget,
                height: AppSpacing.minTouchTarget,
                child: Center(
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.32),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.stop_rounded,
                      color: Colors.redAccent,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
