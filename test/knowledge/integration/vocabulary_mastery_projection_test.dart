import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/knowledge/engine/ema_engine.dart';
import 'package:in4up/knowledge/integration/vocabulary_mastery_projection.dart';
import 'package:in4up/knowledge/models/learning_state.dart' show SkillDimension;
import 'package:in4up/knowledge/visual/mastery_geometry.dart';
import 'package:in4up/models/skill_review_data.dart';
import 'package:in4up/models/word_entry.dart';

void main() {
  WordEntry word({
    SkillReviewData? understand,
    SkillReviewData? listen,
    SkillReviewData? read,
  }) => WordEntry(
        id: 'word-1',
        word: 'hello',
        meaning: 'xin chào',
        understandData: understand,
        listenData: listen,
        readData: read,
      );

  test('untouched zeros and all output axes are unknown, not zero', () {
    final item = word();
    final before = jsonEncode(item.toJson());
    final projection = VocabularyMasteryProjection.fromWord(item);
    expect(projection.unitId, item.id);
    expect(projection.values.length, 6);
    for (final value in projection.values.values) {
      expect(value, isNull);
    }
    expect(projection.useIsPartial, isFalse);
    expect(inputMastery(projection.values), isNull);
    expect(outputMastery(projection.values), isNull);
    expect(jsonEncode(item.toJson()), before, reason: 'projection does not write data');
  });

  test('reviewed zero and existing manual non-zero scores are preserved', () {
    final item = word(
      understand: SkillReviewData(score: 0, totalReviews: 1),
      listen: SkillReviewData(score: 0.6),
      read: SkillReviewData(score: 0, nextReview: DateTime.utc(2027, 1, 1)),
    );
    final values = VocabularyMasteryProjection.fromWord(item).values;
    expect(values[SkillDimension.understanding], 0.0);
    expect(values[SkillDimension.listening], 0.6);
    expect(values[SkillDimension.reading], 0.0);
    expect(values[SkillDimension.use], isNull);
  });

  test('Venn edits are visible without changing any SM-2 history', () {
    final data = SkillReviewData(
      score: 0.1,
      easeFactor: 1.9,
      interval: 8,
      repetitions: 3,
      totalReviews: 5,
      correctReviews: 3,
      nextReview: DateTime.utc(2027, 1, 1),
    );
    final item = word(understand: data);
    final oldHistory = Map<String, dynamic>.from(data.toJson())..remove('score');
    item.setZone(MasteryZone.listenRead);
    final values = VocabularyMasteryProjection.fromWord(item).values;
    expect(values[SkillDimension.understanding], 0.2);
    expect(values[SkillDimension.listening], 0.8);
    expect(values[SkillDimension.reading], 0.8);
    expect(Map<String, dynamic>.from(data.toJson())..remove('score'), oldHistory);
    expect(values[SkillDimension.use], isNull);
    expect(values[SkillDimension.speak], isNull);
    expect(values[SkillDimension.write], isNull);
  });

  test('output requires flags; assessed zero stays zero and one use part is partial', () {
    final valuesWithoutFlags = VocabularyMasteryProjection.fromWord(
      word(),
      output: const MasteryVector(speak: 0.9, write: 0.8, useForm: 0.7),
    );
    expect(valuesWithoutFlags.values[SkillDimension.use], isNull);
    expect(valuesWithoutFlags.values[SkillDimension.speak], isNull);
    expect(valuesWithoutFlags.values[SkillDimension.write], isNull);

    final withFlags = VocabularyMasteryProjection.fromWord(
      word(),
      output: const MasteryVector(
        useForm: 0.7,
        hasUseForm: true,
        speak: 0,
        hasSpeak: true,
        write: 0.8,
        hasWrite: true,
      ),
    );
    expect(withFlags.values[SkillDimension.use], 0.7);
    expect(withFlags.useIsPartial, isTrue);
    expect(withFlags.values[SkillDimension.speak], 0.0);
    expect(withFlags.values[SkillDimension.write], 0.8);
    expect(outputMastery(withFlags.values), closeTo(0.5, 1e-10));
  });

  test('non-finite stored values are unknown instead of crashing display', () {
    final item = word(understand: SkillReviewData(score: double.nan, totalReviews: 1));
    expect(VocabularyMasteryProjection.fromWord(item)
        .values[SkillDimension.understanding], isNull);
  });
}
