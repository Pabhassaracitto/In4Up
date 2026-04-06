// lib/screens/memory_mode/widgets/flashcard_presenter.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/memory_controller.dart';
import '../models/memory_item.dart';
import '../models/memory_stage.dart';
import '../models/review_session.dart';

class FlashcardPresenter extends StatelessWidget {
  const FlashcardPresenter({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MemoryController>(
      builder: (context, controller, _) {
        final card = controller.currentCard;
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
              child: GestureDetector(
                onTap: () => controller.flipCard(),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _FlipCard(
                    item: card,
                    isFlipped: controller.isCardFlipped,
                  ),
                ),
              ),
            ),
            if (controller.isCardFlipped)
              _GradeButtons(
                onGrade: controller.gradeCurrentCard,
              )
            else
              _FlipHint(),
            const SizedBox(height: 24),
          ],
        );
      },
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
              builder: (context, value, child) {
                return Transform.scale(scale: value, child: child);
              },
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
              'Đã ôn ${stats.reviewedToday} từ\n'
              'Đúng ${stats.correctToday}/${stats.reviewedToday}',
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
          color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
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
                color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
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
                label: '${item.totalReviews}x ôn',
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

class _GradeButtons extends StatelessWidget {
  final ValueChanged<ReviewGrade> onGrade;
  const _GradeButtons({required this.onGrade});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: ReviewGrade.values.map((grade) {
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
                    Text(grade.emoji, style: const TextStyle(fontSize: 18)),
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
