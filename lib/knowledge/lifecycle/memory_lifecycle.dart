/// ═══════════════════════════════════════════════════════════════
/// MEMORY LIFECYCLE — Dual-Memory theo mục 6 bàn giao
///
///   Observed   ← tự động, chỉ ghi Evidence, KHÔNG hiện UI gì
///   Captured   ← tự động khi: bôi đen + tra nghĩa, HOẶC nghe lại 1 câu
///                >3 lần, HOẶC mở lại cùng context ≥2 lần
///   Promoted   ← CHỈ khi người dùng chủ động: bấm "Lưu", kéo sang
///                Writing, hoặc hoàn thành 1 lần shadowing
///   Practicing ← tự động sau Promoted, bắt đầu SM-2
///   Maintained ← SM-2 interval > 21 ngày trên cả 3 skill
///
/// RÀO CHẶN "CẤM POPUP CHẶN LUỒNG" (mục 6, điều kiện DoD Task 6):
///  * Engine KHÔNG có bất kỳ API nào phát dialog/yêu cầu xác nhận.
///  * Đầu ra duy nhất khi capture là LifecycleSuggestion — DỮ LIỆU cho
///    badge không chặn luồng, hoặc gộp vào cuối phiên (endSessionSummary).
///  * Promote là API tường minh do UI gọi sau hành động người dùng —
///    LearningAction (mục 2.5) KHÔNG BAO GIỜ tự động promote.
///  * recordImplicit từ chối các action mang ý chí người dùng
///    (savedToWordlist/sentToWriting) — chúng phải đi qua promote().
///
/// Thuần chức năng, JSON-able, clock tiêm được — dễ test & chạy trong
/// worker isolate; UI wiring nằm ở tầng app (INTEGRATE-1).
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:in4up/knowledge/models/learning_action.dart';
import 'package:in4up/knowledge/models/learning_state.dart'
    show LearningState, SkillDimension;

/// 5 trạng thái mục 6 (thứ tự enum = chiều phát triển bình thường).
enum MemoryStage { observed, captured, promoted, practicing, maintained }

/// Lý do người dùng chủ động promote (mục 6).
enum PromoteReason { userSave, userWriting, userShadowing }

/// Nguồn của một lần chuyển trạng thái.
enum TransitionSource { implicit, user, derived }

const int kReplayCaptureThreshold = 3; // capture khi replay > 3 lần
const int kContextReopenThreshold = 2; // capture khi mở lại cùng context >= 2
const int kMaintainedIntervalDays = 21; // maintained khi interval > 21 ngày

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
}
