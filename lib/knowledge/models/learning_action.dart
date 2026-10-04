/// ═══════════════════════════════════════════════════════════════
/// LEARNING ACTION — tín hiệu hành vi (KHÔNG PHẢI mastery)
///
/// Handoff MATRIX KNOWLEDGE MVA v2.0 — schema mục 2.5.
///
/// Quy tắc cứng:
///  * Bảng này KHÔNG BAO GIỜ được dùng để tự động thay đổi `LearningState`.
///  * Chỉ dùng cho: Attention Score (mục 5) và phát hiện candidate
///    "nên promote" trong Dual-Memory Lifecycle (mục 6).
/// ═══════════════════════════════════════════════════════════════
library;

enum LearningActionType {
  opened,
  replayed,
  highlighted,
  translated,
  savedToWordlist,
  sentToWriting,
  chatAsked,
  skipped,
}

class LearningAction {
  final LearningActionType actionType;

  /// Nullable: một số hành vi (vd `skipped`) có thể không gắn unit cụ thể.
  final String? unitId;
  final String? evidenceId;

  final DateTime timestamp;

  /// ID phiên học — gom hành vi theo phiên cho Attention Score.
  final String sessionId;

  const LearningAction({
    required this.actionType,
    this.unitId,
    this.evidenceId,
    required this.timestamp,
    required this.sessionId,
  });

  @override
  bool operator ==(Object other) {
    return other is LearningAction &&
        other.actionType == actionType &&
        other.unitId == unitId &&
        other.evidenceId == evidenceId &&
        other.timestamp == timestamp &&
        other.sessionId == sessionId;
  }

  @override
  int get hashCode =>
      Object.hash(actionType, unitId, evidenceId, timestamp, sessionId);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'actionType': actionType.name,
        'unitId': unitId,
        'evidenceId': evidenceId,
        'timestamp': timestamp.toIso8601String(),
        'sessionId': sessionId,
      };

  factory LearningAction.fromJson(Map<String, dynamic> json) {
    return LearningAction(
      actionType: LearningActionType.values.firstWhere(
        (a) => a.name == json['actionType'],
        orElse: () => throw FormatException(
            'LearningActionType không hợp lệ: ${json['actionType']}'),
      ),
      unitId: json['unitId'] as String?,
      evidenceId: json['evidenceId'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      sessionId: json['sessionId'] as String,
    );
  }
}
