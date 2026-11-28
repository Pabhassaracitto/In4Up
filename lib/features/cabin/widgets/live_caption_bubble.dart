import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:in4up/core/language/localized_material.dart' hide Text;
import 'package:flutter/material.dart';
import 'package:in4up/core/theme/app_colors.dart';
import 'package:in4up/core/theme/app_spacing.dart';
import 'package:in4up/core/theme/app_typography.dart';

import '../screens/live_cabin_screen.dart';
import '../services/stts_cabin_service.dart';

const Key liveCaptionBubbleCloseKey = Key('live_caption_bubble_close');

/// Bong bóng nổi phụ đề Live Cabin (theo WP1 / PLAN-008).
/// Hiển thị trực tiếp bản dịch cabin trên toàn bộ các màn hình của In4Up.
class LiveCaptionBubble extends StatefulWidget {
  const LiveCaptionBubble({super.key});

  @override
  State<LiveCaptionBubble> createState() => _LiveCaptionBubbleState();
}

class _LiveCaptionBubbleState extends State<LiveCaptionBubble>
    with SingleTickerProviderStateMixin {
  final SttsCabinService _service = SttsCabinService();

  Offset _position = const Offset(20, 190);
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
      duration: const Duration(milliseconds: 1000),
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
    if (_service.isListening) {
      _scheduleAutoHide();
      if (!_isExpanded) {
        setState(() => _isExpanded = true);
      }
    }
  }

  void _scheduleAutoHide() {
    _autoHideTimer?.cancel();
    if (!_service.isListening) return;
    _autoHideTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      if (_isDragging) {
        _scheduleAutoHide();
        return;
      }
      setState(() => _isExpanded = false);
    });
  }

  void _handleTap() {
    HapticFeedback.selectionClick();
    if (!_isExpanded) {
      setState(() => _isExpanded = true);
      _scheduleAutoHide();
      return;
    }
    _service.togglePause();
  }

  void _handleLongPress() {
    HapticFeedback.heavyImpact();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LiveCabinScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_service.shouldShowBubble) {
      return const SizedBox.shrink();
    }

    final active = _service.activeCaption;
    final textToShow = active?.translatedText.isNotEmpty == true
        ? active!.translatedText
        : (active?.sourceText ?? context.uiText('Đang nghe cabin...'));

    final screenSize = MediaQuery.of(context).size;
    final bubbleWidth = _isExpanded ? 240.0 : 56.0;
    final maxX = math.max(10.0, screenSize.width - bubbleWidth - 10);
    final maxY = math.max(80.0, screenSize.height - 180);
    final pos = Offset(
      _position.dx.clamp(10.0, maxX),
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
        onTap: _handleTap,
        onLongPress: _handleLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          width: bubbleWidth,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.surfaceModal.withValues(
              alpha: _isExpanded ? 0.96 : 0.9,
            ),
            borderRadius: BorderRadius.circular(_isExpanded ? 16 : 28),
            border: Border.all(
              color: const Color(0xFF00E676).withValues(alpha: 0.5),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E676).withValues(alpha: 0.28),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _isExpanded ? _buildExpanded(textToShow) : _buildCollapsed(),
        ),
      ),
    );
  }

  Widget _buildCollapsed() {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (_service.isListening)
          FadeTransition(
            opacity: Tween(begin: 0.4, end: 1.0).animate(_pulseController),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00E676).withValues(alpha: 0.2),
              ),
            ),
          ),
        Icon(
          _service.isPaused
              ? Icons.pause_rounded
              : Icons.interpreter_mode_rounded,
          color: const Color(0xFF00E676),
          size: 24,
        ),
      ],
    );
  }

  Widget _buildExpanded(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF00E676).withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _service.isPaused
                  ? Icons.pause_rounded
                  : Icons.interpreter_mode_rounded,
              color: const Color(0xFF00E676),
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${_service.sourceLanguage.toUpperCase()} → ${_service.targetLanguage.toUpperCase()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF00E676),
                          fontSize: AppTypography.captionSize,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (_service.isDubbingEnabled) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.volume_up_rounded,
                        color: Color(0xFF00E676),
                        size: 12,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppTypography.footnoteSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Tooltip(
            message: context.uiText('Đóng cabin'),
            child: GestureDetector(
              key: liveCaptionBubbleCloseKey,
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.lightImpact();
                _service.stopCabin();
              },
              child: SizedBox(
                width: AppSpacing.minTouchTarget,
                height: AppSpacing.minTouchTarget,
                child: Center(
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.32),
                      ),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.redAccent,
                      size: 15,
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
