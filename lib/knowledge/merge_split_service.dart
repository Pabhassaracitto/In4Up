/// ═══════════════════════════════════════════════════════════════
/// MERGE / SPLIT SERVICE — hợp nhất & tách KnowledgeUnit
///
/// Handoff MATRIX KNOWLEDGE MVA v2.0 — quy tắc cứng mục 2.1:
/// merge/split là hành vi CÓ THỂ HOÀN TÁC (giữ lịch sử merge).
///
/// Nguyên tắc BẤT MẤT DỮ LIỆU (ưu tiên 2 — mục 10):
///  * Merge KHÔNG xóa gì: absorbed được snapshot đầy đủ trong record.
///  * Evidence của absorbed được repoint sang primary; danh sách ID
///    được ghi lại để split trả về đúng chỗ.
///  * LearningState của absorbed được lưu vào record — KHÔNG tự gộp
///    mastery của 2 unit (gộp tiến độ là quyết định policy thuộc về
///    người dùng, không tự quyết).
///  * Split (undoMerge): absorbed hồi sinh nguyên vẹn, evidence trở về,
///    primary quay về surfaceForms lúc trước merge — NHƯNG mọi review
///    đã tích lũy trên primary SAU khi merge được GIỮ LẠI
///    (hủy tiến độ review thật của người dùng = mất dữ liệu).
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:uuid/uuid.dart';

import 'package:in4up/knowledge/models/evidence.dart';
import 'package:in4up/knowledge/models/knowledge_unit.dart';
import 'package:in4up/knowledge/models/learning_state.dart';
import 'package:in4up/knowledge/models/merge_record.dart';

/// Kết quả một lần merge.
class MergeOutcome {
  /// Primary sau khi hấp thụ (union surfaceForms, updatedAt = mergedAt).
  final KnowledgeUnit mergedUnit;

  /// Lịch sử merge — input bắt buộc cho `undoMerge`.
  final UnitMergeRecord record;

  /// Toàn bộ evidence sau repoint (danh sách MỚI, cùng độ dài & thứ tự input).
  final List<Evidence> evidence;

  /// LearningState còn hoạt động sau merge (của primary;
  /// state của absorbed đã được lưu vào record).
  final List<LearningState> learningStates;

  const MergeOutcome({
    required this.mergedUnit,
    required this.record,
    required this.evidence,
    required this.learningStates,
  });
}

/// Kết quả một lần split (hoàn tác merge).
class SplitOutcome {
  final KnowledgeUnit restoredPrimary;
  final KnowledgeUnit revivedAbsorbed;

  /// Record gốc đã đánh dấu `undone` — vẫn giữ trong lịch sử, không xóa.
  final UnitMergeRecord record;

  final List<Evidence> evidence;
  final List<LearningState> learningStates;

  const SplitOutcome({
    required this.restoredPrimary,
    required this.revivedAbsorbed,
    required this.record,
    required this.evidence,
    required this.learningStates,
  });
}

class MergeSplitService {
  MergeSplitService._();

  /// Gộp [absorbed] vào [primary].
  ///
  /// CHỈ được gọi từ hành động người dùng chủ động xác nhận
  /// (mục 2.1: trùng canonicalForm KHÔNG TỰ ĐỘNG merge —
  /// `KnowledgeUnit.isMergeCandidateWith` chỉ là gợi ý).
  static MergeOutcome mergeUnits({
    required KnowledgeUnit primary,
    required KnowledgeUnit absorbed,
    required List<Evidence> evidence,
    List<LearningState> learningStates = const <LearningState>[],
    String reason = 'manual',
    DateTime? mergedAt,
    String? recordId,
  }) {
    if (primary.unitId == absorbed.unitId) {
      throw ArgumentError(
          'Không thể merge một KnowledgeUnit với chính nó: ${primary.unitId}');
    }

    final at = mergedAt ?? DateTime.now();

    // Union surfaceForms: thứ tự primary trước, absorbed sau, dedupe chính xác.
    final mergedForms = <String>[...primary.surfaceForms];
    for (final form in absorbed.surfaceForms) {
      if (!mergedForms.contains(form)) mergedForms.add(form);
    }
    // canonicalForm của absorbed trở thành surface form của primary
    // (vốn là biến thể chữ viết của cùng một tri thức sau khi gộp).
    if (absorbed.canonicalForm != primary.canonicalForm &&
        !mergedForms.contains(absorbed.canonicalForm)) {
      mergedForms.add(absorbed.canonicalForm);
    }

    final mergedUnit = KnowledgeUnit(
      unitId: primary.unitId,
      kind: primary.kind,
      canonicalForm: primary.canonicalForm,
      surfaceForms: mergedForms,
      language: primary.language,
      senseNote: primary.senseNote,
      createdAt: primary.createdAt,
      updatedAt: at,
    );

    // Repoint evidence của absorbed sang primary; ghi lại ID đã đổi.
    final repointedIds = <String>[];
    final updatedEvidence = <Evidence>[];
    for (final item in evidence) {
      if (item.unitId == absorbed.unitId) {
        repointedIds.add(item.evidenceId);
        updatedEvidence.add(item.copyWith(unitId: primary.unitId));
      } else {
        updatedEvidence.add(item);
      }
    }

    // State của absorbed được lưu vào record (không gộp mastery);
    // state của các unit khác (kể cả primary) giữ nguyên.
    Map<String, dynamic>? absorbedStateJson;
    final activeStates = <LearningState>[];
    for (final state in learningStates) {
      if (state.unitId == absorbed.unitId) {
        absorbedStateJson ??= state.toJson();
      } else {
        activeStates.add(state);
      }
    }

    final record = UnitMergeRecord(
      recordId: recordId ?? const Uuid().v4(),
      primaryUnitId: primary.unitId,
      absorbedUnitId: absorbed.unitId,
      reason: reason,
      mergedAt: at,
      primaryUnitJson: primary.toJson(),
      absorbedUnitJson: absorbed.toJson(),
      absorbedLearningStateJson: absorbedStateJson,
      repointedEvidenceIds: List.unmodifiable(repointedIds),
    );

    return MergeOutcome(
      mergedUnit: mergedUnit,
      record: record,
      evidence: updatedEvidence,
      learningStates: activeStates,
    );
  }

  /// Hoàn tác merge ("split"): hồi sinh absorbed, trả evidence về đúng unit,
  /// primary trở về surfaceForms lúc trước merge.
  ///
  /// Giữ lại: (1) tiến độ review đã tích lũy trên primary sau khi merge,
  /// (2) evidence MỚI được ghi nhận thẳng vào primary sau khi merge.
  static SplitOutcome undoMerge({
    required UnitMergeRecord record,
    required KnowledgeUnit currentPrimary,
    required List<Evidence> evidence,
    List<LearningState> learningStates = const <LearningState>[],
    DateTime? undoneAt,
  }) {
    if (record.undone) {
      throw StateError(
          'Merge ${record.recordId} đã được hoàn tác trước đó.');
    }
    if (currentPrimary.unitId != record.primaryUnitId) {
      throw ArgumentError(
          'currentPrimary.unitId (${currentPrimary.unitId}) không khớp '
          'primaryUnitId của record (${record.primaryUnitId}).');
    }

    final at = undoneAt ?? DateTime.now();

    // Hồi sinh absorbed nguyên vẹn từ snapshot.
    final revived = KnowledgeUnit.fromJson(record.absorbedUnitJson);

    // Primary quay về diện mạo trước merge (surfaceForms/kind/canonical/
    // senseNote/language), nhưng giữ unitId/createdAt hiện hữu.
    final preMerge = KnowledgeUnit.fromJson(record.primaryUnitJson);
    final restoredPrimary = KnowledgeUnit(
      unitId: currentPrimary.unitId,
      kind: preMerge.kind,
      canonicalForm: preMerge.canonicalForm,
      surfaceForms: preMerge.surfaceForms,
      language: preMerge.language,
      senseNote: preMerge.senseNote,
      createdAt: currentPrimary.createdAt,
      updatedAt: at,
    );

    // Chỉ trả về đúng những evidence ĐÃ ĐƯỢC ghi nhận là repoint lúc merge;
    // evidence mới ghi sau merge (không nằm trong list) ở lại primary.
    final repointedSet = record.repointedEvidenceIds.toSet();
    final updatedEvidence = <Evidence>[];
    for (final item in evidence) {
      if (item.unitId == record.primaryUnitId &&
          repointedSet.contains(item.evidenceId)) {
        updatedEvidence.add(item.copyWith(unitId: record.absorbedUnitId));
      } else {
        updatedEvidence.add(item);
      }
    }

    // Trả lại state của absorbed (nếu có); state các unit khác giữ nguyên
    // (kể cả state của primary với mọi review sau merge).
    final updatedStates = <LearningState>[
      for (final state in learningStates)
        if (state.unitId != record.absorbedUnitId) state,
    ];
    final absorbedStateJson = record.absorbedLearningStateJson;
    if (absorbedStateJson != null) {
      updatedStates.add(LearningState.fromJson(absorbedStateJson));
    }

    return SplitOutcome(
      restoredPrimary: restoredPrimary,
      revivedAbsorbed: revived,
      record: record.asUndone(at),
      evidence: updatedEvidence,
      learningStates: updatedStates,
    );
  }
}
