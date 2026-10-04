// lib/features/learn_by_heart/widgets/assessment_rating_bar.dart

import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';
import '../i18n/learn_by_heart_l10n.dart';
import '../models/fsrs_models.dart';

class AssessmentRatingBar extends StatelessWidget {
  final void Function(AssessmentRating rating) onRated;

  const AssessmentRatingBar({
    super.key,
    required this.onRated,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = LearnByHeartL10n.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
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
              'So sánh với bản đọc nhẩm trong đầu và tự đánh giá thực chất (Trọng số x2):',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[400],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _AssessmentButton(
                    label: l10n.heavyMistakes,
                    rating: AssessmentRating.heavyMistake,
                    subtitle: 'Quên / vấp nhiều',
                    onTap: () => _handleRating(AssessmentRating.heavyMistake),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _AssessmentButton(
                    label: l10n.almostCorrect,
                    rating: AssessmentRating.nearCorrect,
                    subtitle: 'Nhớ ý, sót vài từ',
                    onTap: () => _handleRating(AssessmentRating.nearCorrect),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _AssessmentButton(
                    label: l10n.perfectRecite,
                    rating: AssessmentRating.perfect,
                    subtitle: 'Chuẩn xác 100%',
                    onTap: () => _handleRating(AssessmentRating.perfect),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleRating(AssessmentRating rating) {
    HapticFeedback.mediumImpact();
    onRated(rating);
  }
}

class _AssessmentButton extends StatelessWidget {
  final String label;
  final AssessmentRating rating;
  final String subtitle;
  final VoidCallback onTap;

  const _AssessmentButton({
    required this.label,
    required this.rating,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = rating.color;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.45), width: 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
