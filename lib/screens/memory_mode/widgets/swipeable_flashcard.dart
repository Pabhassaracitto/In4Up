import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';

import '../models/memory_item.dart';
import '../models/review_session.dart';
import 'swipe_card_controller.dart';

/// Widget flashcard có thể vuốt 4 hướng
/// Đặt bên trong FlashcardPresenter thay thế GestureDetector cũ
class SwipeableFlashcard extends StatefulWidget {
  final MemoryItem item;
  final bool isFlipped;
  final VoidCallback onTap; // Lật thẻ
  final void Function(ReviewGrade grade) onGrade;
  final SwipeCardController swipeController;

  const SwipeableFlashcard({
    super.key,
    required this.item,
    required this.isFlipped,
    required this.onTap,
    required this.onGrade,
    required this.swipeController,
  });

  @override
  State<SwipeableFlashcard> createState() => _SwipeableFlashcardState();
}

class _SwipeableFlashcardState extends State<SwipeableFlashcard>
    with SingleTickerProviderStateMixin {
  // ── Drag state ──
  Offset _dragOffset = Offset.zero;
  double _dragAngle = 0.0;
  bool _isDragging = false;

  // ── Swipe threshold ──
  static const double _swipeThresholdH = 100.0; // px ngang
  static const double _swipeThresholdV = 80.0; // px dọc (dễ hơn)
  static const double _maxRotation = 0.25; // rad (~14°)

  // ── Overlay hint ──
  SwipeDirection? _hintDirection;

  @override
  void initState() {
    super.initState();
    widget.swipeController.onCardShown();
  }

  @override
  void didUpdateWidget(SwipeableFlashcard old) {
    super.didUpdateWidget(old);
    // Card mới → reset timer
    if (old.item.id != widget.item.id) {
      widget.swipeController.onCardShown();
      _dragOffset = Offset.zero;
      _dragAngle = 0.0;
      _hintDirection = null;
    }
  }

  // ── Xác định hướng từ offset ──
  SwipeDirection? _getDirection(Offset offset) {
    final dx = offset.dx.abs();
    final dy = offset.dy.abs();
    const minDrag = 20.0; // Dead zone

    if (dx < minDrag && dy < minDrag) return null;

    if (dy > dx) {
      // Ưu tiên dọc nếu dy > dx
      return offset.dy < 0 ? SwipeDirection.up : SwipeDirection.down;
    } else {
      return offset.dx > 0 ? SwipeDirection.right : SwipeDirection.left;
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _isDragging = true;
      _dragOffset += details.delta;

      // Góc xoay chỉ theo trục ngang
      _dragAngle = (_dragOffset.dx / 300.0).clamp(-_maxRotation, _maxRotation);

      // Xác định hint direction
      _hintDirection = _getDirection(_dragOffset);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final direction = _getDirection(_dragOffset);
    final dx = _dragOffset.dx.abs();
    final dy = _dragOffset.dy.abs();

    bool committed = false;

    if (direction == SwipeDirection.left || direction == SwipeDirection.right) {
      committed = dx >= _swipeThresholdH;
    } else if (direction != null) {
      committed = dy >= _swipeThresholdV;
    }

    if (committed && direction != null) {
      _commitSwipe(direction);
    } else {
      // Snap về giữa
      setState(() {
        _dragOffset = Offset.zero;
        _dragAngle = 0.0;
        _isDragging = false;
        _hintDirection = null;
      });
    }
  }

  void _commitSwipe(SwipeDirection direction) {
    // Chỉ cho grade khi đã lật thẻ (trừ down = snoozed không cần lật)
    if (!widget.isFlipped && direction != SwipeDirection.down) {
      // Chưa lật → không cho grade, snap về
      HapticFeedback.selectionClick();
      setState(() {
        _dragOffset = Offset.zero;
        _dragAngle = 0.0;
        _isDragging = false;
        _hintDirection = null;
      });
      // Gợi ý user lật thẻ trước
      _showFlipHint();
      return;
    }

    final grade = widget.swipeController.resolveGrade(direction);

    // Haptic tức thì
    switch (direction) {
      case SwipeDirection.left:
        HapticFeedback.heavyImpact();
        break;
      case SwipeDirection.right:
        HapticFeedback.lightImpact();
        break;
      case SwipeDirection.up:
        HapticFeedback.mediumImpact();
        Future.delayed(const Duration(milliseconds: 80), () {
          HapticFeedback.lightImpact();
        });
        break;
      case SwipeDirection.down:
        HapticFeedback.selectionClick();
        break;
    }

    widget.onGrade(grade);

    // Reset state
    setState(() {
      _dragOffset = Offset.zero;
      _dragAngle = 0.0;
      _isDragging = false;
      _hintDirection = null;
    });
  }

  void _showFlipHint() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('👆 Nhấn để lật thẻ trước khi đánh giá'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Card chính với transform ──
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..translate(_dragOffset.dx, _dragOffset.dy)
              ..rotateZ(_dragAngle),
            child: _buildCard(),
          ),

          // ── Overlay hint (xuất hiện khi kéo đủ xa) ──
          if (_hintDirection != null)
            _SwipeHintOverlay(
              direction: _hintDirection!,
              progress: _getHintProgress(),
            ),

          // ── Swipe direction hints tĩnh (luôn hiển thị mờ) ──
          if (!_isDragging) const _SwipeDirectionGuide(),
        ],
      ),
    );
  }

  double _getHintProgress() {
    final dx = _dragOffset.dx.abs();
    final dy = _dragOffset.dy.abs();
    final isHorizontal = _hintDirection == SwipeDirection.left ||
        _hintDirection == SwipeDirection.right;

    if (isHorizontal) {
      return (dx / _swipeThresholdH).clamp(0.0, 1.0);
    } else {
      return (dy / _swipeThresholdV).clamp(0.0, 1.0);
    }
  }

  Widget _buildCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 280),
      decoration: BoxDecoration(
        color: _cardColor(),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _shadowColor().withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: widget.isFlipped ? _buildBackFace() : _buildFrontFace(),
    );
  }

  Color _cardColor() {
    if (_hintDirection == null) return const Color(0xFF1E1E2E);

    // Tint màu theo hướng kéo
    final progress = _getHintProgress();
    switch (_hintDirection!) {
      case SwipeDirection.right:
        return Color.lerp(
          const Color(0xFF1E1E2E),
          const Color(0xFF1B5E20), // xanh đậm
          progress * 0.4,
        )!;
      case SwipeDirection.left:
        return Color.lerp(
          const Color(0xFF1E1E2E),
          const Color(0xFFB71C1C), // đỏ đậm
          progress * 0.4,
        )!;
      case SwipeDirection.up:
        return Color.lerp(
          const Color(0xFF1E1E2E),
          const Color(0xFF4A3800), // vàng đậm
          progress * 0.4,
        )!;
      case SwipeDirection.down:
        return Color.lerp(
          const Color(0xFF1E1E2E),
          const Color(0xFF212121), // xám
          progress * 0.4,
        )!;
    }
  }

  Color _shadowColor() {
    switch (_hintDirection) {
      case SwipeDirection.right:
        return const Color(0xFF4CAF50);
      case SwipeDirection.left:
        return const Color(0xFFF44336);
      case SwipeDirection.up:
        return const Color(0xFFFFD700);
      case SwipeDirection.down:
        return const Color(0xFF9E9E9E);
      case null:
        return Colors.black;
    }
  }

  Widget _buildFrontFace() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          widget.item.word,
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        if (widget.item.phonetic != null) ...[
          const SizedBox(height: 12),
          Text(
            widget.item.phonetic!,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[400],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 32),
        // Gợi ý lật
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Text(
              'Nhấn để xem nghĩa',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBackFace() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Word nhỏ lại
        Text(
          widget.item.word,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.grey[400],
          ),
        ),
        const Divider(height: 24, color: Colors.white12),

        // Nghĩa
        if (widget.item.meaning != null) ...[
          Text(
            widget.item.meaning!,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Ví dụ
        if (widget.item.example != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(
              widget.item.example!,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[300],
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Gợi ý swipe
        Center(
          child: Text(
            '← Quên  |  Nhớ →',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Overlay xuất hiện khi kéo đủ xa ──
class _SwipeHintOverlay extends StatelessWidget {
  final SwipeDirection direction;
  final double progress; // 0.0 → 1.0

  const _SwipeHintOverlay({
    required this.direction,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    if (progress < 0.3) return const SizedBox.shrink();

    final opacity = ((progress - 0.3) / 0.7).clamp(0.0, 1.0);

    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: opacity,
          duration: const Duration(milliseconds: 50),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _color().withValues(alpha: opacity),
                width: 3,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _emoji(),
                    style: const TextStyle(fontSize: 48),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _label(),
                    style: TextStyle(
                      color: _color(),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _color() {
    switch (direction) {
      case SwipeDirection.right:
        return const Color(0xFF4CAF50);
      case SwipeDirection.left:
        return const Color(0xFFF44336);
      case SwipeDirection.up:
        return const Color(0xFFFFD700);
      case SwipeDirection.down:
        return const Color(0xFF9E9E9E);
    }
  }

  String _emoji() {
    switch (direction) {
      case SwipeDirection.right:
        return '😊';
      case SwipeDirection.left:
        return '😵';
      case SwipeDirection.up:
        return '⭐';
      case SwipeDirection.down:
        return '💤';
    }
  }

  String _label() {
    switch (direction) {
      case SwipeDirection.right:
        return 'Nhớ được!';
      case SwipeDirection.left:
        return 'Quên rồi';
      case SwipeDirection.up:
        return 'Thuộc lòng!';
      case SwipeDirection.down:
        return 'Hoãn học';
    }
  }
}

// ── 4 mũi tên gợi ý mờ ở góc card ──
class _SwipeDirectionGuide extends StatelessWidget {
  const _SwipeDirectionGuide();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              // ← Trái: Quên
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _GuideArrow(
                    icon: Icons.arrow_back_ios,
                    color: const Color(0xFFF44336),
                    label: 'Quên',
                  ),
                ),
              ),
              // → Phải: Nhớ
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _GuideArrow(
                    icon: Icons.arrow_forward_ios,
                    color: const Color(0xFF4CAF50),
                    label: 'Nhớ',
                  ),
                ),
              ),
              // ↑ Lên: Thuộc
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: _GuideArrow(
                    icon: Icons.keyboard_arrow_up,
                    color: const Color(0xFFFFD700),
                    label: 'Thuộc',
                    isVertical: true,
                  ),
                ),
              ),
              // ↓ Xuống: Hoãn
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: _GuideArrow(
                    icon: Icons.keyboard_arrow_down,
                    color: const Color(0xFF9E9E9E),
                    label: 'Hoãn',
                    isVertical: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideArrow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool isVertical;

  const _GuideArrow({
    required this.icon,
    required this.color,
    required this.label,
    this.isVertical = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.15, // Rất mờ - chỉ gợi ý
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: isVertical
            ? [
                Icon(icon, color: color, size: 20),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ]
            : [
                Icon(icon, color: color, size: 20),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
      ),
    );
  }
}
