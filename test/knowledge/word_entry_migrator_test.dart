// BISECT T5a — probe + chỉ helper _skill.

import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/knowledge/migration/word_entry_migrator.dart';
import 'package:in4up/knowledge/models/evidence.dart';
import 'package:in4up/knowledge/models/knowledge_unit.dart';
import 'package:in4up/models/vocab_context.dart';
import 'package:in4up/models/vocabulary_type.dart';
import 'package:in4up/models/word_entry.dart';

SkillReviewData _skill({
  double easeFactor = 2.2,
  int interval = 6,
  int repetitions = 2,
  DateTime? nextReview,
  int totalReviews = 4,
}) {
  return SkillReviewData(
    easeFactor: easeFactor,
    interval: interval,
    repetitions: repetitions,
    nextReview: nextReview,
    totalReviews: totalReviews,
    correctReviews: 3,
  );
}

void main() {
  test('probe', () {
    const probeRect = Rect.fromLTWH(0, 0, 1, 1);
    expect(probeRect.width, 1);
    expect(VocabularyType.values.length, 4);
  });

  test('skill fixture qua export cua word_entry', () {
    final s = _skill();
    expect(s.easeFactor, 2.2);
    expect(s.totalReviews, 4);
    final s2 = _skill(totalReviews: 0);
    expect(s2.totalReviews, 0);
    expect(s2.nextReview, isNull);
  });
}
