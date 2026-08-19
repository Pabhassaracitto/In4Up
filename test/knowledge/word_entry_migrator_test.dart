// BISECT T3 — probe: load từng import, không logic phức tạp.

import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/knowledge/migration/word_entry_migrator.dart';
import 'package:in4up/knowledge/models/evidence.dart';
import 'package:in4up/knowledge/models/knowledge_unit.dart';
import 'package:in4up/models/vocab_context.dart';
import 'package:in4up/models/vocabulary_type.dart';
import 'package:in4up/models/word_entry.dart';

void main() {
  test('probe: mọi import load được và dùng được', () {
    final e = Evidence.record(
      unitId: 'u',
      sourceType: EvidenceSourceType.text,
      sourceId: 's',
      locator: const EvidenceLocator(),
      excerpt: 'x',
      producerVersion: WordEntryMigrator.producer,
    );
    expect(e.verifyAgainst('x'), isTrue);

    final u =
        KnowledgeUnit.create(kind: KnowledgeUnitKind.word, canonicalForm: 'w');
    expect(u.unitId, isNotEmpty);

    final vc = VocabContext(
      id: 'c',
      sourceType: 'manual',
      surroundingText: 't',
      encounteredAt: DateTime.utc(2026, 1, 1),
    );
    expect(vc.surroundingText, 't');

    final we = WordEntry(id: 'we', word: 'w', meaning: 'm');
    expect(we.word, 'w');

    const probeRect = Rect.fromLTWH(0, 0, 1, 1);
    expect(probeRect.width, 1);

    expect(VocabularyType.values.length, 4);
  });
}
