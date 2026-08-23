/// ═══════════════════════════════════════════════════════════════
/// SKILL REVIEW DATA — SM-2 cho từng chiều kỹ năng
///
/// Tách từ word_entry.dart (Task 2 / ADR-0001) thành file thuần, chỉ
/// phụ thuộc hàm SM-2 DUY NHẤT — test/knowledge module import nhẹ,
/// không kéo theo cả WordEntry. word_entry.dart re-export class này
/// nên mọi import cũ vẫn hoạt động.
/// ═══════════════════════════════════════════════════════════════
library;

import 'sm2_algorithm.dart';

class SkillReviewData {
  double score; // 0.0 → 1.0
  double easeFactor;
  int interval; // ngày
  int repetitions;
  DateTime? nextReview;
  int totalReviews;
  int correctReviews;

  SkillReviewData({
    this.score = 0.0,
    this.easeFactor = 2.5,
    this.interval = 0,
    this.repetitions = 0,
    this.nextReview,
    this.totalReviews = 0,
    this.correctReviews = 0,
  });

  bool get isDue {
    if (nextReview == null) return true;
    return DateTime.now().isAfter(nextReview!);
  }

  int get daysUntilDue {
    if (nextReview == null) return 0;
    final diff = nextReview!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  double get accuracy => totalReviews > 0 ? correctReviews / totalReviews : 0;

  void review(int quality) {
    // ADR-0001 / Task 2: gọi HÀM SM-2 DUY NHẤT — không tự giữ công thức
    // inline ở đây nữa. Ngữ nghĩa giữ nguyên hệ nghĩa cũ của chính
    // đường ghi dữ liệu thật này ⇒ due date hiện tại không đổi.
    final result = SM2Algorithm.calculate(
      quality: quality,
      currentEF: easeFactor,
      currentInterval: interval,
      currentReps: repetitions,
    );
    easeFactor = result.easeFactor;
    interval = result.interval;
    repetitions = result.repetitions;
    nextReview = result.nextReview;

    // Bookkeeping mastery-score (0..1) — không phải SM-2, giữ nguyên hệ cũ.
    totalReviews++;
    if (quality >= 3) {
      correctReviews++;
      final delta = (quality - 2) * 0.1;
      score = (score + delta).clamp(0.0, 1.0);
    } else {
      final delta = (quality - 2) * 0.05;
      score = (score + delta).clamp(0.0, 1.0);
    }
  }

  Map<String, dynamic> toJson() => {
        'score': score,
        'easeFactor': easeFactor,
        'interval': interval,
        'repetitions': repetitions,
        'nextReview': nextReview?.toIso8601String(),
        'totalReviews': totalReviews,
        'correctReviews': correctReviews,
      };

  factory SkillReviewData.fromJson(Map<String, dynamic> json) =>
      SkillReviewData(
        score: (json['score'] as num?)?.toDouble() ?? 0.0,
        easeFactor: (json['easeFactor'] as num?)?.toDouble() ?? 2.5,
        interval: json['interval'] as int? ?? 0,
        repetitions: json['repetitions'] as int? ?? 0,
        nextReview: json['nextReview'] != null
            ? DateTime.parse(json['nextReview'] as String)
            : null,
        totalReviews: json['totalReviews'] as int? ?? 0,
        correctReviews: json['correctReviews'] as int? ?? 0,
      );
}
