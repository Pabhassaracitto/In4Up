import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/knowledge/merge_split_service.dart';
import 'package:in4up/knowledge/models/evidence.dart';
import 'package:in4up/knowledge/models/knowledge_unit.dart';
import 'package:in4up/knowledge/models/learning_state.dart';
import 'package:in4up/knowledge/models/merge_record.dart';

KnowledgeUnit _unit(String id, String canonicalForm, List<String> forms,
        {String? senseNote}) =>
    KnowledgeUnit(
      unitId: id,
      kind: KnowledgeUnitKind.word,
      canonicalForm: canonicalForm,
      surfaceForms: forms,
      senseNote: senseNote,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

Evidence _ev(String id, String unitId) => Evidence.record(
      evidenceId: id,
      unitId: unitId,
      sourceType: EvidenceSourceType.audio,
      sourceId: 'track-1',
      locator: const EvidenceLocator(timestampStart: 12.5, timestampEnd: 15.0),
      excerpt: 'the bank of the river',
      producerVersion: const ProducerVersion(
        splitterVersion: 'split-1',
        extractorVersion: 'ext-1',
      ),
      createdAt: DateTime.utc(2026, 2, 1),
    );

LearningState _state(String unitId) =>
    LearningState.initial(unitId: unitId, now: DateTime.utc(2026, 1, 2));

void main() {
  group('Merge/Split HOÀN TÁC ĐƯỢC — DoD Task 1 (mục 2.1)', () {
    test(
        'merge: union surfaceForms + repoint evidence + archive state của absorbed',
        () {
      final a = _unit('u-a', 'bank', const ['bank'], senseNote: 'bờ sông');
      final b = _unit('u-b', 'Bank', const ['Bank', 'banks']);
      final e1 = _ev('ev-1', 'u-a');
      final e2 = _ev('ev-2', 'u-b');
      final e3 = _ev('ev-3', 'u-x'); // unit khác — không được đụng vào

      final out = MergeSplitService.mergeUnits(
        primary: a,
        absorbed: b,
        evidence: [e1, e2, e3],
        learningStates: [_state('u-a'), _state('u-b')],
        mergedAt: DateTime.utc(2026, 5, 1),
        recordId: 'rec-1',
      );

      // Primary giữ nguyên unitId:
      expect(out.mergedUnit.unitId, 'u-a');
      // Union surfaceForms (primary trước, absorbed sau, dedupe) + canonical
      // của absorbed trở thành surface form:
      expect(out.mergedUnit.surfaceForms, ['bank', 'Bank', 'banks']);

      // Evidence của absorbed được repoint; evidence khác giữ nguyên:
      expect(out.evidence[0], same(e1));
      expect(out.evidence[1].unitId, 'u-a');
      expect(out.evidence[1].evidenceId, 'ev-2');
      expect(out.evidence[2], same(e3));

      // State của absorbed rời danh sách hoạt động, được lưu vào record:
      expect(out.learningStates.length, 1);
      expect(out.learningStates.first.unitId, 'u-a');
      expect(out.record.absorbedLearningStateJson, isNotNull);
      expect(out.record.repointedEvidenceIds, ['ev-2']);
      expect(out.record.primaryUnitId, 'u-a');
      expect(out.record.absorbedUnitId, 'u-b');
      expect(out.record.undone, isFalse);
    });

    test('merge một unit với chính nó ⇒ ArgumentError (bảo vệ dữ liệu)', () {
      final a = _unit('u-a', 'bank', const []);
      expect(
        () => MergeSplitService.mergeUnits(primary: a, absorbed: a, evidence: const []),
        throwsArgumentError,
      );
    });

    test('UNDO: mọi thứ trở về NGUYÊN VẸN như trước merge (reversible)', () {
      final a = _unit('u-a', 'bank', const ['bank', 'Bank']);
      final b = _unit('u-b', 'riverbank', const ['riverbank', 'river bank']);
      final e1 = _ev('ev-1', 'u-a');
      final e2 = _ev('ev-2', 'u-b');
      final sbWithProgress = _state('u-b').withSkill(
        SkillDimension.listening,
        SM2Snapshot(
          easeFactor: 2.2,
          interval: 6,
          repetitions: 2,
          dueDate: DateTime.utc(2026, 3, 1),
          lastReviewedAt: DateTime.utc(2026, 2, 23),
        ),
        lastReviewEventId: 'ev-old-9',
      );

      final merged = MergeSplitService.mergeUnits(
        primary: a,
        absorbed: b,
        evidence: [e1, e2],
        learningStates: [_state('u-a'), sbWithProgress],
        mergedAt: DateTime.utc(2026, 5, 1),
        recordId: 'rec-undo-1',
      );
      // Giả lập người dùng học tiếp trên unit đã merge sau đó:
      final afterMoreLearning = merged.mergedUnit.withSurfaceForm('BANKS');

      final split = MergeSplitService.undoMerge(
        record: merged.record,
        currentPrimary: afterMoreLearning,
        evidence: merged.evidence,
        learningStates: merged.learningStates,
        undoneAt: DateTime.utc(2026, 6, 1),
      );

      // Primary trở về diện mạo trước merge:
      expect(split.restoredPrimary.unitId, 'u-a');
      expect(split.restoredPrimary.surfaceForms, a.surfaceForms);
      expect(split.restoredPrimary.canonicalForm, 'bank');

      // Absorbed hồi sinh nguyên vẹn (so sánh JSON từng byte):
      expect(split.revivedAbsorbed.toJson(), equals(b.toJson()));

      // Evidence trở về đúng unit cũ:
      expect(
        split.evidence.firstWhere((e) => e.evidenceId == 'ev-1').unitId,
        'u-a',
      );
      expect(
        split.evidence.firstWhere((e) => e.evidenceId == 'ev-2').unitId,
        'u-b',
      );

      // State của absorbed được trả lại NGUYÊN VẸN:
      final revivedState =
          split.learningStates.firstWhere((s) => s.unitId == 'u-b');
      expect(revivedState.toJson(), equals(sbWithProgress.toJson()));

      // Record lịch sử KHÔNG bị xóa — chỉ đánh dấu undone:
      expect(split.record.recordId, 'rec-undo-1');
      expect(split.record.undone, isTrue);
      expect(split.record.undoneAt, DateTime.utc(2026, 6, 1));
    });

    test(
        'evidence MỚI ghi nhận SAU merge (không thuộc repointed list) ở lại primary khi undo',
        () {
      final a = _unit('u-a', 'bank', const ['bank']);
      final b = _unit('u-b', 'Bank', const ['Bank']);

      final merged = MergeSplitService.mergeUnits(
        primary: a,
        absorbed: b,
        evidence: [_ev('ev-2', 'u-b')],
        mergedAt: DateTime.utc(2026, 5, 1),
        recordId: 'rec-keep-1',
      );

      // Sau merge, người dùng gặp từ này ở nguồn mới → evidence mới vào primary:
      final newCapture = _ev('ev-new-after-merge', 'u-a');

      final split = MergeSplitService.undoMerge(
        record: merged.record,
        currentPrimary: merged.mergedUnit,
        evidence: [...merged.evidence, newCapture],
        undoneAt: DateTime.utc(2026, 6, 1),
      );

      // Evidence cũ trả về absorbed; evidence mới ở lại primary — không mất gì:
      expect(
        split.evidence.firstWhere((e) => e.evidenceId == 'ev-2').unitId,
        'u-b',
      );
      expect(
        split.evidence
            .firstWhere((e) => e.evidenceId == 'ev-new-after-merge')
            .unitId,
        'u-a',
      );
    });

    test('undo 2 lần cùng một record ⇒ StateError (lịch sử nhất quán)', () {
      final a = _unit('u-a', 'bank', const []);
      final b = _unit('u-b', 'Bank', const []);

      final merged = MergeSplitService.mergeUnits(
        primary: a,
        absorbed: b,
        evidence: const [],
        mergedAt: DateTime.utc(2026, 5, 1),
        recordId: 'rec-twice',
      );
      final firstUndo = MergeSplitService.undoMerge(
        record: merged.record,
        currentPrimary: merged.mergedUnit,
        evidence: const [],
        undoneAt: DateTime.utc(2026, 6, 1),
      );

      expect(
        () => MergeSplitService.undoMerge(
          record: firstUndo.record,
          currentPrimary: firstUndo.restoredPrimary,
          evidence: const [],
        ),
        throwsStateError,
      );
    });

    test('undoMerge với currentPrimary sai unit ⇒ ArgumentError', () {
      final a = _unit('u-a', 'bank', const []);
      final b = _unit('u-b', 'Bank', const []);
      final merged = MergeSplitService.mergeUnits(
        primary: a,
        absorbed: b,
        evidence: const [],
        recordId: 'rec-mismatch',
      );

      expect(
        () => MergeSplitService.undoMerge(
          record: merged.record,
          currentPrimary: _unit('u-other', 'x', const []),
          evidence: const [],
        ),
        throwsArgumentError,
      );
    });

    test('UnitMergeRecord JSON round-trip — lịch sử merge sống sót qua lưu trữ', () {
      final a = _unit('u-a', 'bank', const ['bank']);
      final b = _unit('u-b', 'Bank', const ['Bank']);
      final merged = MergeSplitService.mergeUnits(
        primary: a,
        absorbed: b,
        evidence: [_ev('ev-2', 'u-b')],
        learningStates: [_state('u-b')],
        mergedAt: DateTime.utc(2026, 5, 1, 12),
        recordId: 'rec-json',
      );

      final clone = UnitMergeRecord.fromJson(merged.record.toJson());

      expect(clone.recordId, 'rec-json');
      expect(clone.repointedEvidenceIds, ['ev-2']);
      expect(clone.absorbedUnitJson, equals(merged.record.absorbedUnitJson));
      expect(clone.primaryUnitJson, equals(merged.record.primaryUnitJson));
      expect(clone.absorbedLearningStateJson,
          equals(merged.record.absorbedLearningStateJson));
      expect(clone.undone, isFalse);
      // Hồi sinh được absorbed từ bản clone:
      expect(KnowledgeUnit.fromJson(clone.absorbedUnitJson).toJson(),
          equals(b.toJson()));
    });
  });
}
