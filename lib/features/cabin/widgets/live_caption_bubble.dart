import 'dart:async';
import 'dart:math' as math;
import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';

import '../screens/live_cabin_screen.dart';
import '../services/stts_cabin_service.dart';

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
        : (active?.sourceText ?? 'Đang nghe cabin...');

    final screenSize = MediaQuery.of(context).size;
    final maxX = math.max(10.0, screenSize.width - 90);
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
          width: _isExpanded ? 220 : 54,
          height: 54,
          decoration: BoxDecoration(
            color: const Color(0xFF101B2B).withValues(alpha: _isExpanded ? 0.95 : 0.88),
            borderRadius: BorderRadius.circular(_isExpanded ? 16 : 27),
            border: Border.all(
              color: const Color(0xFF00E676).withValues(alpha: 0.5),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E676).withValues(alpha: 0.3),
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
          child: _isExpanded
              ? _buildExpanded(textToShow)
              : _buildCollapsed(),
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
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00E676).withValues(alpha: 0.2),
              ),
            ),
          ),
        Icon(
          _service.isPaused ? Icons.pause_rounded : Icons.interpreter_mode_rounded,
          color: const Color(0xFF00E676),
          size: 24,
        ),
      ],
    );
  }

  Widget _buildExpanded(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
              _service.isPaused ? Icons.pause_rounded : Icons.interpreter_mode_rounded,
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
                    Text(
                      '${_service.sourceLanguage.toUpperCase()} ➔ ${_service.targetLanguage.toUpperCase()}',
                      style: const TextStyle(
                        color: Color(0xFF00E676),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_service.isDubbingEnabled) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.volume_up_rounded, color: Color(0xFF00E676), size: 10),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // Stop icon
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _service.stopCabin();
            },
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 14),
            ),
          ),
        ],
      ),
    );
  }
}
