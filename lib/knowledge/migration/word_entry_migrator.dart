/// ═══════════════════════════════════════════════════════════════
/// WORD ENTRY MIGRATOR — chuyển dữ liệu cũ sang Knowledge schema
///
/// Handoff MVA v2.0 — Task 3 (mục 8):
///   đọc `WordEntry` cũ (Hive box 'vocabulary_v2')
///   → sinh `KnowledgeUnit` + `Evidence` + `LearningState`
///   → KHÔNG XÓA data cũ.
///
/// Nguyên tắc (DoD Task 3):
///  * KHÔNG mất từ nào: 1 WordEntry ⇒ đúng 1 KnowledgeUnit (kể cả
///    isUnborn); id trùng (dữ liệu lỗi) ⇒ remap UUID mới + ghi report,
///    không rò rỉ FK.
///  * unitId GIỮ NGUYÊN id cũ ('v_...'/'w_...' — không sinh từ text)
///    ⇒ lịch sử review vẫn truy được sau migration.
///  * Due date KHÔNG ĐỔI BẤT NGỜ: SM2Snapshot.dueDate = nextReview cũ
///    (byte-đồng nhất); nextReview null = "due ngay" ⇒ dueDate = mốc
///    migration (ngữ nghĩa giữ nguyên). algorithmVersion = sm2-srd-v1 —
///    ngữ nghĩa Bản 2 đã được chứng minh tương đương ở Task 2.
///  * VocabContext ⇒ Evidence (nơi gặp từ): excerpt + snapshotHash +
///    locator reopen (pdf: page/rect/offset; web: url/scroll %;
///    youtube: timestamp mm:ss).
///  * THUẦN (pure): không đột biến input; IDEMPOTENT: chạy lại cho
///    kết quả giống hệt (evidenceId deterministic).
///  * Trường cũ không có trong schema v1 (meaning, phonetic, example,
///    tags, topic, personalNotes, hierarchy…) KHÔNG bị mất — dữ liệu cũ
///    nằm nguyên trong box cũ; migrator chỉ LIỆT KÊ vào report để
///    phased sau này (nghĩa là "không mất âm thầm").
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart' show Rect;

import 'package:uuid/uuid.dart';

import 'package:in4up/knowledge/models/evidence.dart';
import 'package:in4up/knowledge/models/knowledge_unit.dart';
import 'package:in4up/knowledge/models/learning_state.dart';
import 'package:in4up/models/skill_review_data.dart';
import 'package:in4up/models/vocab_context.dart';
import 'package:in4up/models/vocabulary_type.dart';
import 'package:in4up/models/word_entry.dart';

/// Báo cáo migration — để audit "chạy trên 100% dữ liệu, không mất từ nào".
class MigrationReport {
  final int inputCount;

  /// Số unit sinh ra — DoD: phải bằng inputCount.
  final int unitsCreated;
  final int evidenceCreated;
  final int statesCreated;

  /// Số từ isUnborn vẫn được tạo unit (không mất từ nào — kể cả unborn).
  final int unbornUnits;

  /// Id cũ bị trùng ⇒ đã remap UUID mới (dữ liệu lỗi, cần xem lại).
  final List<String> duplicateIdsRemapped;

  /// Trường dữ liệu cũ CHƯA có chỗ chứa trong schema v1 — vẫn nằm nguyên
  /// trong store cũ, không mất; liệt kê để phased.
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

  /// DoD khớp: mỗi từ đầu vào có đúng 1 unit.
  bool get isLossless => unitsCreated == inputCount;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'inputCount': inputCount,
        'unitsCreated': unitsCreated,
        'evidenceCreated': evidenceCreated,
        'statesCreated': statesCreated,
        'unbornUnits': unbornUnits,
        'duplicateIdsRemapped': duplicateIdsRemapped,
        'fieldsNotRepresentedInV1': fieldsNotRepresentedInV1.toList()
          ..sort(),
      };
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

  /// Mọi evidence sinh bởi migration đều gắn producer version này —
  /// truy vết được nguồn gốc dữ liệu (schema mục 2.2).
  static const ProducerVersion producer = ProducerVersion(
    splitterVersion: 'legacy-vocab-context',
    extractorVersion: 'migration-1',
  );

  static final RegExp _mmss =
      RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$');

  /// Chạy migration. [now] tiêm được để test/idempotency;
  /// [newUnitId] tiêm được cho test case remap id trùng.
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
      // 1:1 — KHÔNG mất từ nào. Id trùng (dữ liệu lỗi) ⇒ remap, không vỡ.
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

      var ctxIndex = 0;
      for (final ctx in entry.contexts) {
        evidence.add(_toEvidence(unitId, ctx, ctxIndex));
        ctxIndex++;
      }

      // Baseline snapshot — event log (ReviewEvent) chỉ bắt đầu SAU migration.
      states.add(LearningState(
        unitId: unitId,
        understanding: _snapshot(entry.understandData, entry.lastReviewed, at),
        listening: _snapshot(entry.listenData, entry.lastReviewed, at),
        reading: _snapshot(entry.readData, entry.lastReviewed, at),
      ));
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

  /// Ngữ nghĩa skill cũ → snapshot mới. Due date byte-đồng nhất.
  static SM2Snapshot _snapshot(
    SkillReviewData data,
    DateTime entryLastReviewed,
    DateTime at,
  ) {
    return SM2Snapshot(
      easeFactor: data.easeFactor,
      interval: data.interval,
      repetitions: data.repetitions,
      // nextReview null = "due ngay lập tức" — giữ nguyên ngữ nghĩa.
      dueDate: data.nextReview ?? at,
      lastReviewedAt: data.totalReviews > 0 ? entryLastReviewed : null,
    );
  }

  static Evidence _toEvidence(String unitId, VocabContext ctx, int index) {
    return Evidence(
      // Deterministic ⇒ migration idempotent (chạy lại không sinh trùng).
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
      // 'manual', 'story', và mọi giá trị lạ ⇒ text (nguồn văn bản thuần).
      default:
        return EvidenceSourceType.text;
    }
  }

  static EvidenceLocator _toLocator(VocabContext ctx) {
    final refType = ctx.sourceRefType;
    final isPdf = ctx.sourceType == 'pdf' || refType == 'pdfPath';
    final isWebLike =
        ctx.sourceType == 'web' || refType == 'webUrl' || ctx.sourceType == 'youtube';

    // Web lưu tiến trình cuộn 0..1 (đã clamp ở controller) → schema 0..100.
    final scroll = ctx.scrollProgressHint;
    final double? scrollPercent =
        (isWebLike && scroll != null) ? scroll * 100.0 : null;

    return EvidenceLocator(
      page: isPdf ? (ctx.pageIndexHint ?? ctx.numericPositionHint) : null,
      rect: _toLocatorRect(ctx.rectHint),
      offset: ctx.textStartOffset,
      url: (isWebLike && ctx.sourceRef != null) ? ctx.sourceRef : null,
      scrollPercent: scrollPercent,
      timestampStart: ctx.sourceType == 'youtube'
          ? _parseTimestamp(ctx.pageOrPosition)
          : null,
    );
  }

  static LocatorRect? _toLocatorRect(Rect? rect) {
    if (rect == null) return null;
    return LocatorRect(
      x: rect.left,
      y: rect.top,
      width: rect.width,
      height: rect.height,
    );
  }

  /// "02:15" → 135s; "1:02:15" → 3735s. Không parse được ⇒ null.
  static double? _parseTimestamp(String? position) {
    if (position == null) return null;
    final match = _mmss.firstMatch(position.trim());
    if (match == null) return null;
    final a = int.parse(match.group(1)!);
    final b = int.parse(match.group(2)!);
    final c = match.group(3);
    if (c != null) {
      return (a * 3600 + b * 60 + int.parse(c)).toDouble();
    }
    return (a * 60 + b).toDouble();
  }

  /// Trường cũ không có chỗ chứa trong schema v1 — liệt kê (không mất
  /// âm thầm): dữ liệu vẫn nằm nguyên trong store cũ.
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
