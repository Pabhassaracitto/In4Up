/// ═══════════════════════════════════════════════════════════════
/// UNIT MERGE RECORD — lịch sử merge để merge/split HOÀN TÁC ĐƯỢC
///
/// Handoff MATRIX KNOWLEDGE MVA v2.0 — quy tắc cứng mục 2.1:
/// merge/split là hành vi có thể hoàn tác, GIỮ LỊCH SỬ merge.
///
/// Record là append-only: sau khi undo vẫn GIỮ LẠI record,
/// chỉ đánh dấu `undone` — không xóa.
/// ═══════════════════════════════════════════════════════════════
library;

class UnitMergeRecord {
  final String recordId;

  /// Unit còn sống sau merge (hấp thụ surfaceForms + evidence của absorbed).
  final String primaryUnitId;

  /// Unit bị hấp thụ — bị ẩn khỏi danh sách hoạt động, KHÔNG xóa dữ liệu.
  final String absorbedUnitId;

  /// Vì sao merge: 'manual' | 'suggestion-accepted' | …
  final String reason;
  final DateTime mergedAt;

  /// Snapshot TRƯỚC merge của primary — split khôi phục đúng surfaceForms cũ.
  final Map<String, dynamic> primaryUnitJson;

  /// Snapshot đầy đủ của absorbed — split hồi sinh unit này nguyên vẹn.
  final Map<String, dynamic> absorbedUnitJson;

  /// LearningState của absorbed lúc merge (null nếu chưa có state)
  /// — hoàn tác trả lại đúng chỗ, không hủy tiến độ.
  final Map<String, dynamic>? absorbedLearningStateJson;

  /// Các evidenceId đã bị repoint sang primary — split trả về đúng unit cũ.
  final List<String> repointedEvidenceIds;

  /// Đã hoàn tác chưa (record vẫn giữ lại sau khi undo).
  final bool undone;
  final DateTime? undoneAt;

  const UnitMergeRecord({
    required this.recordId,
    required this.primaryUnitId,
    required this.absorbedUnitId,
    required this.reason,
    required this.mergedAt,
    required this.primaryUnitJson,
    required this.absorbedUnitJson,
    this.absorbedLearningStateJson,
    required this.repointedEvidenceIds,
    this.undone = false,
    this.undoneAt,
  });

  /// Trả về bản copy đã đánh dấu hoàn tác — không đột biến `this`.
  UnitMergeRecord asUndone(DateTime at) => UnitMergeRecord(
        recordId: recordId,
        primaryUnitId: primaryUnitId,
        absorbedUnitId: absorbedUnitId,
        reason: reason,
        mergedAt: mergedAt,
        primaryUnitJson: primaryUnitJson,
        absorbedUnitJson: absorbedUnitJson,
        absorbedLearningStateJson: absorbedLearningStateJson,
        repointedEvidenceIds: repointedEvidenceIds,
        undone: true,
        undoneAt: at,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'recordId': recordId,
        'primaryUnitId': primaryUnitId,
        'absorbedUnitId': absorbedUnitId,
        'reason': reason,
        'mergedAt': mergedAt.toIso8601String(),
        'primaryUnitJson': primaryUnitJson,
        'absorbedUnitJson': absorbedUnitJson,
        'absorbedLearningStateJson': absorbedLearningStateJson,
        'repointedEvidenceIds': repointedEvidenceIds,
        'undone': undone,
        'undoneAt': undoneAt?.toIso8601String(),
      };

  factory UnitMergeRecord.fromJson(Map<String, dynamic> json) {
    return UnitMergeRecord(
      recordId: json['recordId'] as String,
      primaryUnitId: json['primaryUnitId'] as String,
      absorbedUnitId: json['absorbedUnitId'] as String,
      reason: json['reason'] as String? ?? 'manual',
      mergedAt: DateTime.parse(json['mergedAt'] as String),
      primaryUnitJson:
          json['primaryUnitJson'] as Map<String, dynamic>? ?? const {},
      absorbedUnitJson:
          json['absorbedUnitJson'] as Map<String, dynamic>? ?? const {},
      absorbedLearningStateJson:
          json['absorbedLearningStateJson'] as Map<String, dynamic>?,
      repointedEvidenceIds:
          (json['repointedEvidenceIds'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(),
      undone: json['undone'] as bool? ?? false,
      undoneAt: json['undoneAt'] == null
          ? null
          : DateTime.parse(json['undoneAt'] as String),
    );
  }
}
