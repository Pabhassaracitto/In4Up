// BISECT T4 — probe + 2 helpers + test 1.

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

  test('probe', () {
    final e = Evidence.record(
      unitId: 'u',
      sourceType: EvidenceSourceType.text,
      sourceId: 's',
      locator: const EvidenceLocator(),
      excerpt: 'x',
      producerVersion: WordEntryMigrator.producer,
    );
    expect(e.verifyAgainst('x'), isTrue);
    final u2 =
        KnowledgeUnit.create(kind: KnowledgeUnitKind.word, canonicalForm: 'w');
    expect(u2.unitId, isNotEmpty);
    const probeRect = Rect.fromLTWH(0, 0, 1, 1);
    expect(probeRect.width, 1);
    expect(VocabularyType.values.length, 4);
  });

  test('test1: 1:1 không mất từ nào', () {
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
        result.units.map((u) => u.unitId).toSet(), {'v_100_0', 'v_200_1', 'w_300_2'});
  });
}
