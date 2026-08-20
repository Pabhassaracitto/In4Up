// lib/screens/tools/word_list/wordlist_bubble.dart
// Floating round bubble that shows wordlist TTS status across tabs
// Features: draggable, auto-hide after seconds, tap to mute, hide when back to wordlist

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'wordlist_playback_service.dart';

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
    // Reset auto-hide on word change
    if (_service.isPlaying) {
      _scheduleAutoHide();
      if (!_isExpanded) {
        // Briefly expand on new word
        setState(() => _isExpanded = true);
      }
    }
  }

  void _scheduleAutoHide() {
    _autoHideTimer?.cancel();
    if (!_service.isPlaying) return;
    _autoHideTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      if (_isDragging) {
        _scheduleAutoHide();
        return;
      }
      setState(() => _isExpanded = false);
    });
  }

  void _handleTap() {
    HapticFeedback.mediumImpact();
    // Tap to mute
    _service.stopPlayback();
  }

  void _handleLongPress() {
    HapticFeedback.heavyImpact();
    setState(() => _isExpanded = !_isExpanded);
    if (_isExpanded) {
      _scheduleAutoHide();
    } else {
      _autoHideTimer?.cancel();
    }
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

    // Keep within screen bounds
    final screenSize = MediaQuery.of(context).size;
    final maxX = screenSize.width - 72;
    final maxY = screenSize.height - 160;
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
        onTap: _handleTap,
        onLongPress: _handleLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          width: _isExpanded ? 196 : 58,
          height: 58,
          decoration: BoxDecoration(
            color: const Color(0xFF1A2235).withValues(alpha: _isExpanded ? 0.96 : 0.88),
            borderRadius: BorderRadius.circular(_isExpanded ? 16 : 29),
            border: Border.all(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.45),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
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
              color: const Color(0xFF6C63FF).withValues(alpha: 0.18),
            ),
          ),
        ),
        const Icon(Icons.volume_up_rounded,
            color: Color(0xFF9C8FFF), size: 22),
        Positioned(
          bottom: 6,
          right: 8,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF1A2235), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpanded(
    current,
    String progressText,
    String repeatText,
    String listRepeat,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          // Icon circle
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.volume_up_rounded,
                color: Color(0xFF9C8FFF), size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  current?.word ?? '...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '$progressText$repeatText$listRepeat',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Mute button
          GestureDetector(
            onTap: _handleTap,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.red.withValues(alpha: 0.25), width: 1),
              ),
              child: const Icon(Icons.stop_rounded,
                  color: Colors.redAccent, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}
