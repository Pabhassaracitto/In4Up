/// BISECT D2 — skeleton: enums + consts + LifecycleSuggestion.
library;

/// 5 trạng thái mục 6 (thứ tự enum = chiều phát triển bình thường).
enum MemoryStage { observed, captured, promoted, practicing, maintained }

/// Lý do người dùng chủ động promote (mục 6).
enum PromoteReason { userSave, userWriting, userShadowing }

/// Nguồn của một lần chuyển trạng thái.
enum TransitionSource { implicit, user, derived }

const int kReplayCaptureThreshold = 3;
const int kContextReopenThreshold = 2;
const int kMaintainedIntervalDays = 21;

/// Đề xuất KHÔNG CHẶN LUỒNG — dữ liệu cho badge nhỏ hoặc tổng kết cuối phiên.
class LifecycleSuggestion {
  final String unitId;
  final String reason;
  final DateTime at;

  const LifecycleSuggestion({
    required this.unitId,
    required this.reason,
    required this.at,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'unitId': unitId,
        'reason': reason,
        'at': at.toIso8601String(),
      };
}

/// Một lần chuyển trạng thái — append-only (không xóa, theo GOVERNANCE).
class StageTransition {
  final MemoryStage from;
  final MemoryStage to;
  final DateTime at;
  final String reason;
  final TransitionSource source;

  const StageTransition({
    required this.from,
    required this.to,
    required this.at,
    required this.reason,
    required this.source,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'from': from.name,
        'to': to.name,
        'at': at.toIso8601String(),
        'reason': reason,
        'source': source.name,
      };

  factory StageTransition.fromJson(Map<String, dynamic> json) =>
      StageTransition(
        from: MemoryStage.values.firstWhere((s) => s.name == json['from']),
        to: MemoryStage.values.firstWhere((s) => s.name == json['to']),
        at: DateTime.parse(json['at'] as String),
        reason: json['reason'] as String,
        source:
            TransitionSource.values.firstWhere((s) => s.name == json['source']),
      );
}

/// Trạng thái lifecycle của một KnowledgeUnit.
class MemoryLifecycleUnit {
  final String unitId;
  MemoryStage stage;
  DateTime stageEnteredAt;

  /// Số evidence đã ghi nhận ở tầng Observed.
  int evidenceCount;

  /// Cờ tín hiệu implicit (mục 6): bôi đen / tra nghĩa.
  bool highlighted;
  bool translated;

  /// Số lần mở lại theo context (khóa = evidenceId).
  final Map<String, int> contextReopens;

  /// Số lần nghe lại theo câu (khóa = evidenceId).
  final Map<String, int> sentenceReplays;

  /// Mốc SM-2 bắt đầu (sau promote → practicing).
  DateTime? sm2StartedAt;

  /// Lịch sử chuyển trạng thái — append-only.
  final List<StageTransition> history;

  MemoryLifecycleUnit({
    required this.unitId,
    required this.stage,
    required this.stageEnteredAt,
    this.evidenceCount = 0,
    this.highlighted = false,
    this.translated = false,
    Map<String, int>? contextReopens,
    Map<String, int>? sentenceReplays,
    this.sm2StartedAt,
    List<StageTransition>? history,
  })  : contextReopens = contextReopens ?? <String, int>{},
        sentenceReplays = sentenceReplays ?? <String, int>{},
        history = history ?? <StageTransition>[];

  Map<String, dynamic> toJson() => <String, dynamic>{
        'unitId': unitId,
        'stage': stage.name,
        'stageEnteredAt': stageEnteredAt.toIso8601String(),
        'evidenceCount': evidenceCount,
        'highlighted': highlighted,
        'translated': translated,
        'contextReopens': contextReopens,
        'sentenceReplays': sentenceReplays,
        'sm2StartedAt': sm2StartedAt?.toIso8601String(),
        'history': [for (final t in history) t.toJson()],
      };

  factory MemoryLifecycleUnit.fromJson(Map<String, dynamic> json) {
    return MemoryLifecycleUnit(
      unitId: json['unitId'] as String,
      stage: MemoryStage.values.firstWhere((s) => s.name == json['stage']),
      stageEnteredAt: DateTime.parse(json['stageEnteredAt'] as String),
      evidenceCount: json['evidenceCount'] as int? ?? 0,
      highlighted: json['highlighted'] as bool? ?? false,
      translated: json['translated'] as bool? ?? false,
      contextReopens:
          (json['contextReopens'] as Map<String, dynamic>?)?.cast<int>(),
      sentenceReplays:
          (json['sentenceReplays'] as Map<String, dynamic>?)?.cast<int>(),
      sm2StartedAt: json['sm2StartedAt'] == null
          ? null
          : DateTime.parse(json['sm2StartedAt'] as String),
      history: [
        for (final t in (json['history'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>())
          StageTransition.fromJson(t)
      ],
    );
  }
}

/// Đề xuất KHÔNG CHẶN LUỒNG — dữ liệu cho badge nhỏ hoặc tổng kết cuối phiên.
class LifecycleSuggestion {
  final String unitId;

  /// Lý do dạng người đọc được — bắt buộc cụ thể (mục 5 style), không "AI đề xuất" mơ hồ.
  final String reason;

  final DateTime at;

  const LifecycleSuggestion({
    required this.unitId,
    required this.reason,
    required this.at,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'unitId': unitId,
        'reason': reason,
        'at': at.toIso8601String(),
      };
}
