// lib/features/learn_by_heart/services/fsrs_engine.dart

import 'dart:math' as math;
import '../models/fsrs_models.dart';
import '../models/learn_by_heart_item.dart';
import '../models/review_state.dart';

/// Thuật toán Spaced Repetition thích ứng FSRS kết hợp Cold-Start 5 bước
/// Thiết kế chuẩn theo Product Spec v4.1 FINAL SEALED
class FSRSEngine {
  // Cold start fixed intervals (tính bằng ngày) cho 5 lần review đầu
  static const List<int> _coldStartIntervals = [0, 1, 3, 7, 14];

  /// Xử lý một phiên ôn tập Active Recall với 4 mức đánh giá FSRS
  static LearnByHeartItem processReview({
    required LearnByHeartItem item,
    required FSRSRating rating,
  }) {
    final now = DateTime.now();
    final currentParams = item.fsrsParams;
    final totalReps = item.totalReviews + 1;
    final isColdStart = totalReps <= 5;

    int newIntervalDays;
    double newStability = currentParams.stability;
    double newDifficulty = currentParams.difficulty;
    int newReps = currentParams.reps;
    int newLapses = currentParams.lapses;
    int newConsecutiveSuccesses = item.consecutiveSuccesses;
    ReviewState newReviewState = item.reviewState;

    if (rating == FSRSRating.again) {
      // ══ QUÊN (AGAIN): Reset chu kỳ ══
      newLapses += 1;
      newReps = 0;
      newConsecutiveSuccesses = 0;
      newReviewState = ReviewState.lapse;
      newStability = math.max(0.5, currentParams.stability * 0.4);
      newDifficulty = math.min(10.0, currentParams.difficulty + 1.2);
      newIntervalDays = 1; // Ôn lại vào ngày mai
    } else {
      // ══ NHỚ (HARD, GOOD, EASY) ══
      newReps += 1;
      newConsecutiveSuccesses += 1;
      newReviewState = ReviewState.review;

      if (isColdStart) {
        // Cold start 5 lần đầu
        final coldIndex = math.min(totalReps - 1, _coldStartIntervals.length - 1);
        int baseColdInterval = _coldStartIntervals[coldIndex];

        if (rating == FSRSRating.hard) {
          newDifficulty = math.min(10.0, currentParams.difficulty + 0.6);
          newIntervalDays = math.max(1, (baseColdInterval * 0.8).round());
        } else if (rating == FSRSRating.good) {
          newIntervalDays = math.max(1, baseColdInterval);
        } else {
          // Easy
          newDifficulty = math.max(1.0, currentParams.difficulty - 0.5);
          newIntervalDays = (baseColdInterval * 1.3).round().clamp(1, 30);
        }
        newStability = newIntervalDays.toDouble();
      } else {
        // Thuật toán FSRS thích ứng từ lần 6
        switch (rating) {
          case FSRSRating.hard:
            newDifficulty = math.min(10.0, currentParams.difficulty + 0.8);
            newStability = currentParams.stability * (1.0 + (11.0 - newDifficulty) * 0.08);
            newIntervalDays = math.max(1, (newStability * 0.9).round());
            break;
          case FSRSRating.good:
            newDifficulty = (currentParams.difficulty - 0.1).clamp(1.0, 10.0);
            newStability = currentParams.stability * (1.0 + (11.0 - newDifficulty) * 0.18);
            newIntervalDays = math.max(1, newStability.round());
            break;
          case FSRSRating.easy:
            newDifficulty = math.max(1.0, currentParams.difficulty - 0.8);
            newStability = currentParams.stability * (1.0 + (11.0 - newDifficulty) * 0.32);
            newIntervalDays = math.max(1, (newStability * 1.35).round());
            break;
          default:
            newIntervalDays = 1;
        }
      }
    }

    final nextReview = now.add(Duration(days: newIntervalDays));

    final log = ReviewLog(
      timestamp: now,
      rating: rating.name,
      intervalDays: newIntervalDays,
      stability: newStability,
      difficulty: newDifficulty,
      isAssessment: false,
    );

    return item.copyWith(
      reviewState: newReviewState,
      fsrsParams: currentParams.copyWith(
        stability: newStability,
        difficulty: newDifficulty,
        reps: newReps,
        lapses: newLapses,
        lastIntervalDays: newIntervalDays,
      ),
      nextReviewDate: nextReview,
      consecutiveSuccesses: newConsecutiveSuccesses,
      totalReviews: totalReps,
      lastReviewedAt: now,
      reviewHistory: [...item.reviewHistory, log],
    );
  }

  /// Xử lý bài kiểm tra thực chất (Assessment Layer) với trọng số gấp 2 lần
  static LearnByHeartItem processAssessment({
    required LearnByHeartItem item,
    required AssessmentRating rating,
  }) {
    final now = DateTime.now();
    final currentParams = item.fsrsParams;

    int newIntervalDays;
    double newStability = currentParams.stability;
    double newDifficulty = currentParams.difficulty;
    int newConsecutiveSuccesses = item.consecutiveSuccesses;
    int newLapses = currentParams.lapses;
    ReviewState newReviewState = item.reviewState;

    switch (rating) {
      case AssessmentRating.heavyMistake:
        // Sai nhiều trong Assessment → Lapse nghiêm trọng
        newLapses += 1;
        newConsecutiveSuccesses = 0; // Reset streak
        newReviewState = ReviewState.lapse;
        newStability = math.max(1.0, currentParams.stability * 0.3);
        newDifficulty = math.min(10.0, currentParams.difficulty + 2.0);
        newIntervalDays = 1;
        break;

      case AssessmentRating.nearCorrect:
        // Gần đúng → Duy trì khoảng cách hiện tại, nhắc ôn sau 3 ngày
        newConsecutiveSuccesses += 1;
        newReviewState = ReviewState.review;
        newDifficulty = math.min(10.0, currentParams.difficulty + 0.5);
        newStability = currentParams.stability * 1.2;
        newIntervalDays = math.max(3, (newStability * 0.8).round());
        break;

      case AssessmentRating.perfect:
        // Đúng hoàn toàn không gợi ý → Trọng số x2: tăng vọt độ bền vững!
        newConsecutiveSuccesses += 2;
        newReviewState = ReviewState.review;
        newDifficulty = math.max(1.0, currentParams.difficulty - 1.2);
        // Nhân hệ số bền vững gấp 2 lần review thường
        newStability = currentParams.stability * 2.2;
        newIntervalDays = math.max(14, newStability.round());
        break;
    }

    final nextReview = now.add(Duration(days: newIntervalDays));

    final log = ReviewLog(
      timestamp: now,
      rating: rating.name,
      intervalDays: newIntervalDays,
      stability: newStability,
      difficulty: newDifficulty,
      isAssessment: true,
    );

    return item.copyWith(
      reviewState: newReviewState,
      fsrsParams: currentParams.copyWith(
        stability: newStability,
        difficulty: newDifficulty,
        lapses: newLapses,
        lastIntervalDays: newIntervalDays,
      ),
      nextReviewDate: nextReview,
      consecutiveSuccesses: newConsecutiveSuccesses,
      totalAssessments: item.totalAssessments + 1,
      lastAssessmentDate: now,
      lastReviewedAt: now,
      reviewHistory: [...item.reviewHistory, log],
    );
  }

  /// Dự đoán khoảng cách ngày tiếp theo cho từng nút để preview trên UI
  static String estimateIntervalLabel(LearnByHeartItem item, FSRSRating rating) {
    final totalReps = item.totalReviews + 1;
    if (totalReps <= 5) {
      if (rating == FSRSRating.again) return '1 ngày';
      final coldIndex = math.min(totalReps - 1, _coldStartIntervals.length - 1);
      final base = _coldStartIntervals[coldIndex];
      if (rating == FSRSRating.hard) return '${math.max(1, (base * 0.8).round())} ngày';
      if (rating == FSRSRating.good) return '${math.max(1, base)} ngày';
      return '${math.max(2, (base * 1.3).round())} ngày';
    }

    // FSRS estimated
    final s = item.fsrsParams.stability;
    switch (rating) {
      case FSRSRating.again:
        return '1 ngày';
      case FSRSRating.hard:
        return '${math.max(1, (s * 1.1).round())} ngày';
      case FSRSRating.good:
        return '${math.max(2, (s * 1.25).round())} ngày';
      case FSRSRating.easy:
        return '${math.max(4, (s * 1.5).round())} ngày';
    }
  }
}
