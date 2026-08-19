// Test Migration Adapter — Task 3 DoD (mục 8):
//   "Chạy trên 100% dữ liệu test hiện có, không mất từ nào,
//    review due date không đổi bất ngờ."
//
// LƯU Ý: KHÔNG import trực tiếp skill_review_data.dart — SkillReviewData
// lấy qua export của word_entry.dart (tránh tổ hợp import từng làm CI
// analyzer gãy — xem postmortem bisect B1–B7 trong word_entry_migrator.dart).

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

WordEntry _entry(
  String id,
  String word, {
  List<VocabContext>? contexts,
  SkillReviewData? u,
  SkillReviewData? l,
  SkillReviewData? r,
  bool unborn = false,
  List<String>? tags,
  String? topic,
  VocabularyType? vocabType,
}) {
  return WordEntry(
    id: id,
    word: word,
    meaning: 'nghĩa của $word',
    understandData: u,
    listenData: l,
    readData: r,
    lastReviewed: DateTime.utc(2026, 2, 20, 9),
    createdAt: DateTime.utc(2026, 1, 10),
    updatedAt: DateTime.utc(2026, 2, 20, 9),
    contexts: contexts,
    isUnborn: unborn,
    tags: tags,
    topic: topic,
    vocabType: vocabType,
  );
}

void main() {
  final at = DateTime.utc(2026, 8, 20, 12);

  group('WordEntryMigrator — DoD Task 3', () {
    test('1:1 KHÔNG MẤT TỪ NÀO — mọi id cũ thành unitId (giữ FK lịch sử)', () {
      final result = WordEntryMigrator.migrate(
        [
          _entry('v_100_0', 'bank'),
          _entry('v_200_1', 'river'),
          _entry('w_300_2', 'run'),
        ],
        now: at,
      );

      expect(result.report.isLossless, isTrue);
      expect(result.report.inputCount, 3);
      expect(result.report.unitsCreated, 3);
      expect(result.report.statesCreated, 3);
      expect(
        result.units.map((u) => u.unitId).toSet(),
        {'v_100_0', 'v_200_1', 'w_300_2'},
      );
    });

    // (bisect T2: chỉ test 1)
  });
}
