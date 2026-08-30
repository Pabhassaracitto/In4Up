// lib/features/learn_by_heart/widgets/fsrs_rating_bar.dart

import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';
import '../models/fsrs_models.dart';
import '../models/learn_by_heart_item.dart';
import '../services/fsrs_engine.dart';

class FSRSRatingBar extends StatelessWidget {
  final LearnByHeartItem item;
  final void Function(FSRSRating rating) onRated;

  const FSRSRatingBar({
    super.key,
    required this.item,
    required this.onRated,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1322),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Đánh giá độ nhớ để FSRS tối ưu lịch ôn tập:',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[400],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _RatingButton(
                    rating: FSRSRating.again,
                    intervalText: FSRSEngine.estimateIntervalLabel(item, FSRSRating.again),
                    onTap: () => _handleRating(FSRSRating.again),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RatingButton(
                    rating: FSRSRating.hard,
                    intervalText: FSRSEngine.estimateIntervalLabel(item, FSRSRating.hard),
                    onTap: () => _handleRating(FSRSRating.hard),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RatingButton(
                    rating: FSRSRating.good,
                    intervalText: FSRSEngine.estimateIntervalLabel(item, FSRSRating.good),
                    onTap: () => _handleRating(FSRSRating.good),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RatingButton(
                    rating: FSRSRating.easy,
                    intervalText: FSRSEngine.estimateIntervalLabel(item, FSRSRating.easy),
                    onTap: () => _handleRating(FSRSRating.easy),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleRating(FSRSRating rating) {
    HapticFeedback.mediumImpact();
    onRated(rating);
  }
}

class _RatingButton extends StatelessWidget {
  final FSRSRating rating;
  final String intervalText;
  final VoidCallback onTap;

  const _RatingButton({
    required this.rating,
    required this.intervalText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = rating.color;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              rating.label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              intervalText,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
