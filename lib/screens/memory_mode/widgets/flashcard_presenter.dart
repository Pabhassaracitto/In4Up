// lib/screens/memory_mode/widgets/flashcard_presenter.dart

import 'dart:math';
import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../controllers/memory_controller.dart';
import '../models/memory_item.dart';
import '../models/memory_stage.dart';
import '../models/review_session.dart'; // ← SwipeDirection lấy từ đây

// ══════════════════════════════════════════════════════
//  SWIPE CONTROLLER - Logic timer ngầm
// ══════════════════════════════════════════════════════
class _SwipeTimerController {
  DateTime? _cardShownAt;

  void onCardShown() => _cardShownAt = DateTime.now();

  int get _elapsedSeconds {
    if (_cardShownAt == null) return 99;
    return DateTime.now().difference(_cardShownAt!).inSeconds;
  }

  /// Vuốt → Grade (có timer ngầm)
  ReviewGrade resolveGrade(SwipeDirection dir) {
    switch (dir) {
      case SwipeDirection.right:
        // ≤3s → Easy, >3s → Good
        return _elapsedSeconds <= 3 ? ReviewGrade.easy : ReviewGrade.good;
      case SwipeDirection.left:
        // ≤2s → Hard (nhớ mang máng), >2s → Forgot
        return _elapsedSeconds <= 2 ? ReviewGrade.hard : ReviewGrade.forgot;
      case SwipeDirection.up:
        return ReviewGrade.retired;
      case SwipeDirection.down:
        return ReviewGrade.snoozed;
    }
  }
}

// ══════════════════════════════════════════════════════
//  FLASHCARD PRESENTER - Entry point
// ══════════════════════════════════════════════════════
class FlashcardPresenter extends StatefulWidget {
  const FlashcardPresenter({super.key});

  @override
  State<FlashcardPresenter> createState() => _FlashcardPresenterState();
}

class _FlashcardPresenterState extends State<FlashcardPresenter> {
  final _swipeTimer = _SwipeTimerController();
  String? _lastCardId; // Theo dõi card thay đổi để reset timer

  @override
  Widget build(BuildContext context) {
    return Consumer<MemoryController>(
      builder: (context, controller, _) {
        final card = controller.currentCard;

        // Reset timer khi chuyển card mới
        if (card != null && card.id != _lastCardId) {
          _lastCardId = card.id;
          _swipeTimer.onCardShown();
        }

        if (card == null) {
          return _buildComplete(context, controller);
        }

        return Column(
          children: [
            _PresenterHeader(
              current: controller.currentCardIndex + 1,
              total: controller.reviewQueue.length,
              stage: card.stage,
              onExit: controller.exitReview,
            ),
            Expanded(
              child: _SwipeCardArea(
                item: card,
                isFlipped: controller.isCardFlipped,
                swipeTimer: _swipeTimer,
                onTap: controller.flipCard,
                onGrade: (grade) => _handleGrade(context, controller, grade),
              ),
            ),
            // ── Grade buttons: ẩn retired/snoozed (hiếm dùng) ──
            if (controller.isCardFlipped)
              _GradeButtons(
                onGrade: (grade) => _handleGrade(context, controller, grade),
              )
            else
              _FlipHint(),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Future<void> _handleGrade(
    BuildContext context,
    MemoryController controller,
    ReviewGrade grade,
  ) async {
    // Hiển thị toast feedback
    if (context.mounted) _showGradeFeedback(context, grade);

    await controller.gradeCurrentCard(grade);
  }

  void _showGradeFeedback(BuildContext context, ReviewGrade grade) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(grade.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              grade.label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 700),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(grade.buttonColor).withValues(alpha: 0.95),
        margin: const EdgeInsets.fromLTRB(60, 0, 60, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _buildComplete(BuildContext context, MemoryController controller) {
    final stats = controller.stats;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, value, child) =>
                  Transform.scale(scale: value, child: child),
              child: const Text('🌺', style: TextStyle(fontSize: 72)),
            ),
            const SizedBox(height: 24),
            const Text(
              'Hoàn thành!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.uiText('Đã ôn ${stats.reviewedToday} từ\nĐúng ${stats.correctToday}/${stats.reviewedToday}'),
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: stats.reviewedToday > 0
                        ? stats.correctToday / stats.reviewedToday
                        : 0.0,
                    strokeWidth: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF4CAF50)),
                  ),
                  Text(
                    stats.reviewedToday > 0
                        ? '${(stats.correctToday / stats.reviewedToday * 100).round()}%'
                        : '0%',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: controller.exitReview,
              icon: const Icon(Icons.park),
              label: const Text('Về vườn'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
//  SWIPE CARD AREA - Bao ngoài _FlipCard
// ══════════════════════════════════════════════════════
class _SwipeCardArea extends StatefulWidget {
  final MemoryItem item;
  final bool isFlipped;
  final _SwipeTimerController swipeTimer;
  final VoidCallback onTap;
  final void Function(ReviewGrade) onGrade;

  const _SwipeCardArea({
    required this.item,
    required this.isFlipped,
    required this.swipeTimer,
    required this.onTap,
    required this.onGrade,
  });

  @override
  State<_SwipeCardArea> createState() => _SwipeCardAreaState();
}

class _SwipeCardAreaState extends State<_SwipeCardArea>
    with SingleTickerProviderStateMixin {
  // ── Drag state ──
  Offset _drag = Offset.zero;
  double _angle = 0.0;
  SwipeDirection? _activeDir;

  // ── Ngưỡng swipe ──
  static const double _hThreshold = 100.0; // ngang
  static const double _vThreshold = 80.0; // dọc (dễ hơn ngang)
  static const double _maxAngle = 0.20; // ~11.5 độ

  // ── Xác định hướng từ offset ──
  SwipeDirection? _directionOf(Offset offset) {
    final dx = offset.dx.abs();
    final dy = offset.dy.abs();
    const deadZone = 18.0;

    if (dx < deadZone && dy < deadZone) return null;

    // Ưu tiên dọc khi dy > dx * 1.2 (tránh nhầm lên/xuống với trái/phải)
    if (dy > dx * 1.2) {
      return offset.dy < 0 ? SwipeDirection.up : SwipeDirection.down;
    }
    return offset.dx > 0 ? SwipeDirection.right : SwipeDirection.left;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() {
      _drag += d.delta;
      _angle = (_drag.dx / 320.0).clamp(-_maxAngle, _maxAngle);
      _activeDir = _directionOf(_drag);
    });
  }

  void _onPanEnd(DragEndDetails _) {
    final dir = _activeDir;
    if (dir == null) {
      _snapBack();
      return;
    }

    final dist = dir == SwipeDirection.left || dir == SwipeDirection.right
        ? _drag.dx.abs()
        : _drag.dy.abs();
    final threshold = dir == SwipeDirection.up || dir == SwipeDirection.down
        ? _vThreshold
        : _hThreshold;

    if (dist >= threshold) {
      _commitSwipe(dir);
    } else {
      _snapBack();
    }
  }

  void _snapBack() {
    setState(() {
      _drag = Offset.zero;
      _angle = 0.0;
      _activeDir = null;
    });
  }

  void _commitSwipe(SwipeDirection dir) {
    // Chưa lật thẻ và không phải snoozed → không cho grade
    if (!widget.isFlipped && dir != SwipeDirection.down) {
      _snapBack();
      HapticFeedback.selectionClick();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('👆 Nhấn lật thẻ trước khi đánh giá'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final grade = widget.swipeTimer.resolveGrade(dir);
    _snapBack();
    widget.onGrade(grade);
  }

  // ── Tính progress hint (0.0 → 1.0) ──
  double get _hintProgress {
    if (_activeDir == null) return 0.0;
    final isH =
        _activeDir == SwipeDirection.left || _activeDir == SwipeDirection.right;
    final dist = isH ? _drag.dx.abs() : _drag.dy.abs();
    final threshold = isH ? _hThreshold : _vThreshold;
    return (dist / threshold).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: GestureDetector(
        onTap: widget.onTap, // lật thẻ
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── Card chính (giữ nguyên _FlipCard 3D) ──
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..translate(_drag.dx, _drag.dy * 0.4) // dọc di ít hơn ngang
                ..rotateZ(_angle),
              child: _FlipCard(
                item: widget.item,
                isFlipped: widget.isFlipped,
              ),
            ),

            // ── Overlay khi kéo đủ xa ──
            if (_activeDir != null && _hintProgress > 0.25)
              _SwipeOverlay(
                direction: _activeDir!,
                progress: _hintProgress,
              ),

            // ── Gợi ý 4 hướng (mờ, luôn hiển thị khi không kéo) ──
            if (_activeDir == null && widget.isFlipped) const _DirectionHints(),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
//  SWIPE OVERLAY - Hiển thị khi kéo
// ══════════════════════════════════════════════════════
class _SwipeOverlay extends StatelessWidget {
  final SwipeDirection direction;
  final double progress; // 0.0 → 1.0

  const _SwipeOverlay({required this.direction, required this.progress});

  Color get _color {
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

  String get _emoji {
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

  String get _label {
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

  @override
  Widget build(BuildContext context) {
    // Fade in sau 25%, full opacity khi đạt 100%
    final opacity = ((progress - 0.25) / 0.75).clamp(0.0, 1.0);

    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: opacity,
          duration: const Duration(milliseconds: 30),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _color.withValues(alpha: 0.8),
                width: 3,
              ),
              color: _color.withValues(alpha: 0.08),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_emoji, style: const TextStyle(fontSize: 52)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _color.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
}

// ══════════════════════════════════════════════════════
//  DIRECTION HINTS - 4 mũi tên mờ gợi ý
// ══════════════════════════════════════════════════════
class _DirectionHints extends StatelessWidget {
  const _DirectionHints();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            // ← Trái
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: _HintArrow(
                  icon: Icons.arrow_back_ios,
                  color: const Color(0xFFF44336),
                  label: 'Quên',
                ),
              ),
            ),
            // → Phải
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: _HintArrow(
                  icon: Icons.arrow_forward_ios,
                  color: const Color(0xFF4CAF50),
                  label: 'Nhớ',
                ),
              ),
            ),
            // ↑ Lên
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(
                child: _HintArrow(
                  icon: Icons.keyboard_arrow_up,
                  color: const Color(0xFFFFD700),
                  label: '⭐',
                  iconSize: 28,
                ),
              ),
            ),
            // ↓ Xuống
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(
                child: _HintArrow(
                  icon: Icons.keyboard_arrow_down,
                  color: const Color(0xFF9E9E9E),
                  label: '💤',
                  iconSize: 28,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HintArrow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final double iconSize;

  const _HintArrow({
    required this.icon,
    required this.color,
    required this.label,
    this.iconSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.18,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: iconSize),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
//  FLIP CARD - GIỮ NGUYÊN HOÀN TOÀN từ code gốc
// ══════════════════════════════════════════════════════
class _FlipCard extends StatelessWidget {
  final MemoryItem item;
  final bool isFlipped;

  const _FlipCard({required this.item, required this.isFlipped});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: isFlipped ? pi : 0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      builder: (context, angle, _) {
        final showBack = angle > pi / 2;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: showBack
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(pi),
                  child: _BackFace(item: item),
                )
              : _FrontFace(item: item),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════
//  FRONT / BACK FACE - GIỮ NGUYÊN từ code gốc
// ══════════════════════════════════════════════════════
class _FrontFace extends StatelessWidget {
  final MemoryItem item;
  const _FrontFace({required this.item});

  @override
  Widget build(BuildContext context) {
    final stage = item.stage;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            stage.primaryColor.withValues(alpha: 0.15),
            stage.primaryColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: stage.primaryColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(stage.emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              item.word,
              style: TextStyle(
                fontSize: 32 * stage.fontScale,
                fontWeight: FontWeight.bold,
                color: stage.primaryColor,
                letterSpacing: 1,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (item.phonetic != null) ...[
            const SizedBox(height: 12),
            Text(
              item.phonetic!,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 32),
          Text(
            'Tap để lật',
            style: TextStyle(color: Colors.grey[700], fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _BackFace extends StatelessWidget {
  final MemoryItem item;
  const _BackFace({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Color(0xFF4CAF50).withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            item.word,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          if (item.meaning != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFF4CAF50).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                item.meaning!,
                style: const TextStyle(
                  fontSize: 18,
                  color: Color(0xFF4CAF50),
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          if (item.example != null) ...[
            const SizedBox(height: 16),
            Text(
              '"${item.example!}"',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (item.context != null) ...[
            const SizedBox(height: 12),
            Text(
              '📖 ${item.context!}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (item.wordType != null)
                _MetaBadge(
                  label: item.wordType!,
                  color: const Color(0xFF2196F3),
                ),
              if (item.cefrLevel != null) ...[
                const SizedBox(width: 8),
                _MetaBadge(
                  label: item.cefrLevel!,
                  color: const Color(0xFFFF9800),
                ),
              ],
              const SizedBox(width: 8),
              _MetaBadge(
                label: context.uiText('${item.totalReviews}x ôn'),
                color: Colors.grey,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _MetaBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
//  GRADE BUTTONS - Ẩn retired/snoozed (dùng swipe)
// ══════════════════════════════════════════════════════
class _GradeButtons extends StatelessWidget {
  final ValueChanged<ReviewGrade> onGrade;
  const _GradeButtons({required this.onGrade});

  @override
  Widget build(BuildContext context) {
    // Chỉ hiển thị 4 grade chính, retired/snoozed dùng swipe
    final grades = [
      ReviewGrade.forgot,
      ReviewGrade.hard,
      ReviewGrade.good,
      ReviewGrade.easy,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: grades.map((grade) {
          final color = Color(grade.buttonColor);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ElevatedButton(
                onPressed: () => onGrade(grade),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      grade.emoji,
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      grade.label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
//  FLIP HINT + HEADER - GIỮ NGUYÊN từ code gốc
// ══════════════════════════════════════════════════════
class _FlipHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        '🤔 Cố nhớ nghĩa rồi tap để lật',
        style: TextStyle(color: Colors.grey[600], fontSize: 13),
      ),
    );
  }
}

class _PresenterHeader extends StatelessWidget {
  final int current;
  final int total;
  final MemoryStage stage;
  final VoidCallback onExit;

  const _PresenterHeader({
    required this.current,
    required this.total,
    required this.stage,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        border: Border(
          bottom: BorderSide(
            color: stage.primaryColor.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onExit,
            child: const Icon(Icons.close, color: Colors.grey, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                Text(
                  '$current / $total',
                  style: TextStyle(
                    color: stage.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: current / total,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation(stage.primaryColor),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(stage.emoji, style: const TextStyle(fontSize: 20)),
        ],
      ),
    );
  }
}
