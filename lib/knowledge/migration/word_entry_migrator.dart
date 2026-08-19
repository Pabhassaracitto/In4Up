/// ═══════════════════════════════════════════════════════════════
/// WORD ENTRY MIGRATOR — BISECT B4 (bỏ khối states/snapshot + imports liên quan)
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:uuid/uuid.dart';

import 'package:in4up/knowledge/models/evidence.dart';
import 'package:in4up/knowledge/models/knowledge_unit.dart';
import 'package:in4up/knowledge/models/learning_state.dart';
import 'package:in4up/models/skill_review_data.dart';
import 'package:in4up/models/vocab_context.dart';
import 'package:in4up/models/vocabulary_type.dart';
import 'package:in4up/models/word_entry.dart';

class MigrationReport {
  final int inputCount;
  final int unitsCreated;
  final int evidenceCreated;
  final int statesCreated;
  final int unbornUnits;
  final List<String> duplicateIdsRemapped;
  final Set<String> fieldsNotRepresentedInV1;

  const MigrationReport({
    required this.inputCount,
    required this.unitsCreated,
    required this.evidenceCreated,
    required this.statesCreated,
    required this.unbornUnits,
    required this.duplicateIdsRemapped,
    required this.fieldsNotRepresentedInV1,
  });

  bool get isLossless => unitsCreated == inputCount;
}

class MigrationResult {
  final List<KnowledgeUnit> units;
  final List<Evidence> evidence;
  final List<LearningState> states;
  final MigrationReport report;

  const MigrationResult({
    required this.units,
    required this.evidence,
    required this.states,
    required this.report,
  });
}

class WordEntryMigrator {
  WordEntryMigrator._();

  static const ProducerVersion producer = ProducerVersion(
    splitterVersion: 'legacy-vocab-context',
    extractorVersion: 'migration-1',
  );

  static MigrationResult migrate(
    List<WordEntry> entries, {
    DateTime? now,
    String Function()? newUnitId,
  }) {
    final at = now ?? DateTime.now();
    final idGen = newUnitId ?? _defaultIdGen;

    final units = <KnowledgeUnit>[];
    final evidence = <Evidence>[];
    final states = <LearningState>[];
    final seenUnitIds = <String>{};
    final duplicateIds = <String>[];
    final unmappedFields = <String>{};
    var unborn = 0;

    for (final entry in entries) {
      var unitId = entry.id;
      if (!seenUnitIds.add(unitId)) {
        unitId = idGen();
        seenUnitIds.add(unitId);
        duplicateIds.add(entry.id);
      }
      if (entry.isUnborn) unborn++;
      _collectUnmappedFields(entry, unmappedFields);

      units.add(KnowledgeUnit(
        unitId: unitId,
        kind: _mapKind(entry.vocabType),
        canonicalForm: entry.word,
        surfaceForms: entry.word.trim().isEmpty
            ? const <String>[]
            : <String>[entry.word],
        language: entry.language,
        createdAt: entry.createdAt,
        updatedAt: entry.updatedAt,
      ));

      states.add(LearningState(
        unitId: unitId,
        understanding: _snapshot(entry.understandData, entry.lastReviewed, at),
        listening: _snapshot(entry.listenData, entry.lastReviewed, at),
        reading: _snapshot(entry.readData, entry.lastReviewed, at),
      ));

      var ctxIndex = 0;
      for (final ctx in entry.contexts) {
        evidence.add(_toEvidence(unitId, ctx, ctxIndex));
        ctxIndex++;
      }
    }

    return MigrationResult(
      units: units,
      evidence: evidence,
      states: states,
      report: MigrationReport(
        inputCount: entries.length,
        unitsCreated: units.length,
        evidenceCreated: evidence.length,
        statesCreated: states.length,
        unbornUnits: unborn,
        duplicateIdsRemapped: List.unmodifiable(duplicateIds),
        fieldsNotRepresentedInV1: Set.unmodifiable(unmappedFields),
      ),
    );
  }

  static String _defaultIdGen() => const Uuid().v4();

  static KnowledgeUnitKind _mapKind(VocabularyType type) {
    switch (type) {
      case VocabularyType.word:
        return KnowledgeUnitKind.word;
      case VocabularyType.phrase:
        return KnowledgeUnitKind.phrase;
      case VocabularyType.sentence:
        return KnowledgeUnitKind.sentence;
      case VocabularyType.paragraph:
        return KnowledgeUnitKind.paragraph;
    }
  }

  static SM2Snapshot _snapshot(
    SkillReviewData data,
    DateTime entryLastReviewed,
    DateTime at,
  ) {
    return SM2Snapshot(
      easeFactor: data.easeFactor,
      interval: data.interval,
      repetitions: data.repetitions,
      dueDate: data.nextReview ?? at,
      lastReviewedAt: data.totalReviews > 0 ? entryLastReviewed : null,
    );
  }

  static Evidence _toEvidence(String unitId, VocabContext ctx, int index) {
    return Evidence(
      evidenceId: 'mig-$unitId-ctx$index',
      unitId: unitId,
      sourceType: _mapSourceType(ctx),
      sourceId: ctx.sourceRef ?? ctx.sourceName ?? ctx.id,
      locator: _toLocator(ctx),
      excerpt: ctx.surroundingText,
      snapshotHash: SnapshotHash.compute(ctx.surroundingText),
      createdAt: ctx.encounteredAt,
      producerVersion: producer,
    );
  }

  static EvidenceSourceType _mapSourceType(VocabContext ctx) {
    switch (ctx.sourceType) {
      case 'pdf':
        return EvidenceSourceType.pdf;
      case 'web':
        return EvidenceSourceType.web;
      case 'youtube':
        return EvidenceSourceType.youtube;
      case 'clipboard':
        return EvidenceSourceType.clipboard;
      default:
        return EvidenceSourceType.text;
    }
  }

  static EvidenceLocator _toLocator(VocabContext ctx) {
    return EvidenceLocator(
      page: ctx.pageIndexHint,
      offset: ctx.textStartOffset,
    );
  }

  static void _collectUnmappedFields(WordEntry entry, Set<String> into) {
    if (entry.meaning.trim().isNotEmpty) into.add('meaning');
    if ((entry.phonetic ?? '').isNotEmpty) into.add('phonetic');
    if ((entry.example ?? '').isNotEmpty) into.add('example');
    if ((entry.imageUrl ?? '').isNotEmpty) into.add('imageUrl');
    if (entry.tags.isNotEmpty) into.add('tags');
    if ((entry.personalNotes ?? '').isNotEmpty) into.add('personalNotes');
    if (entry.userDifficulty != null) into.add('userDifficulty');
    if ((entry.topic ?? '').isNotEmpty) into.add('topic');
    if (entry.parentIds.isNotEmpty) into.add('parentIds');
    if (entry.childIds.isNotEmpty) into.add('childIds');
  }
}
