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

/// Engine lifecycle — thuần, clock tiêm được.
class MemoryLifecycleEngine {
  final Map<String, MemoryLifecycleUnit> _units = <String, MemoryLifecycleUnit>{};
  final List<LifecycleSuggestion> _pendingSuggestions =
      <LifecycleSuggestion>[];
  final DateTime Function() _clock;

  MemoryLifecycleEngine({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  /// Ghi nhận unit ở tầng Observed (mục 6: tự động, chỉ ghi Evidence).
  MemoryLifecycleUnit observe(String unitId, {int evidenceBump = 1}) {
    final now = _clock();
    final existing = _units[unitId];
    if (existing != null) {
      existing.evidenceCount += evidenceBump;
      return existing;
    }
    final unit = MemoryLifecycleUnit(
      unitId: unitId,
      stage: MemoryStage.observed,
      stageEnteredAt: now,
      evidenceCount: evidenceBump,
    );
    _units[unitId] = unit;
    return unit;
  }

  MemoryLifecycleUnit? unit(String unitId) => _units[unitId];

  /// Ghi nhận hành vi IMPLICIT (mục 2.5 — không bao giờ tự promote).
  /// Từ chối action mang ý chí người dùng — chúng đi qua promote().
  void recordImplicit(LearningAction action) {
    final type = action.actionType;
    if (type == LearningActionType.savedToWordlist ||
        type == LearningActionType.sentToWriting) {
      throw ArgumentError(
          'Action người dùng (${type.name}) phải đi qua promote() — '
          'không được recordImplicit (mục 2.5 + mục 6).');
    } else if (type == LearningActionType.opened) {
      _bumpReopen(action);
    } else if (type == LearningActionType.replayed) {
      _bumpReplay(action);
    } else if (type == LearningActionType.highlighted) {
      _flagHighlight(action);
    } else if (type == LearningActionType.translated) {
      _flagTranslate(action);
    } else {
      // chatAsked/skipped: chỉ phục vụ Attention Score (mục 5) —
      // không tác động lifecycle.
      return;
    }
    _evaluateCapture(action.unitId);
  }

  void _bumpReopen(LearningAction action) {
    final unitId = action.unitId;
    if (unitId == null) return;
    final unit = _units[unitId] ?? observe(unitId, evidenceBump: 0);
    final key = action.evidenceId;
    if (key == null) return;
    unit.contextReopens[key] = (unit.contextReopens[key] ?? 0) + 1;
  }

  void _bumpReplay(LearningAction action) {
    final unitId = action.unitId;
    if (unitId == null) return;
    final unit = _units[unitId] ?? observe(unitId, evidenceBump: 0);
    final key = action.evidenceId;
    if (key == null) return;
    unit.sentenceReplays[key] = (unit.sentenceReplays[key] ?? 0) + 1;
  }

  void _flagHighlight(LearningAction action) {
    final unitId = action.unitId;
    if (unitId == null) return;
    final unit = _units[unitId] ?? observe(unitId, evidenceBump: 0);
    unit.highlighted = true;
  }

  void _flagTranslate(LearningAction action) {
    final unitId = action.unitId;
    if (unitId == null) return;
    final unit = _units[unitId] ?? observe(unitId, evidenceBump: 0);
    unit.translated = true;
  }

  /// Quy tắc capture mục 6 — chỉ khởi作用 từ observed.
  void _evaluateCapture(String? unitId) {
    if (unitId == null) return;
    final unit = _units[unitId];
    if (unit == null || unit.stage != MemoryStage.observed) return;

    String? reason;
    if (unit.highlighted && unit.translated) {
      reason = 'bôi đen và tra nghĩa';
    } else if (unit.sentenceReplays.values
        .any((count) => count > kReplayCaptureThreshold)) {
      reason = 'nghe lại một câu hơn $kReplayCaptureThreshold lần';
    } else if (unit.contextReopens.values
        .any((count) => count >= kContextReopenThreshold)) {
      reason = 'mở lại cùng context lần thứ $kContextReopenThreshold';
    }
    if (reason == null) return;

    _transition(unit, MemoryStage.captured,
        reason: reason, source: TransitionSource.implicit);
    // Đầu ra duy nhất — DỮ LIỆU badge không chặn luồng (mục 6).
    _pendingSuggestions.add(LifecycleSuggestion(
      unitId: unitId,
      reason: 'Gợi ý lưu vì bạn đã $reason.',
      at: _clock(),
    ));
  }

  /// Promote — CHỈ người dùng (mục 6). Tự động bước tiếp sang practicing
  /// và khởi động SM-2 (mốc sm2StartedAt cho tầng app dựng LearningState).
  bool promote(String unitId, PromoteReason reason) {
    final unit = _units[unitId];
    if (unit == null) return false;
    if (unit.stage != MemoryStage.observed &&
        unit.stage != MemoryStage.captured) {
      return false; // đã promote rồi — no-op idempotent
    }
    final now = _clock();
    _transition(unit, MemoryStage.promoted,
        reason: 'người dùng: ${reason.name}',
        source: TransitionSource.user);
    _transition(unit, MemoryStage.practicing,
        reason: 'tự động sau promote — bắt đầu SM-2',
        source: TransitionSource.derived,
        at: now);
    unit.sm2StartedAt = now;
    return true;
  }

  /// Maintained là trạng thái DẪN XUẤT từ LearningState (mục 6):
  /// interval > ngưỡng trên CẢ 3 skill ⇒ maintained; rơi xuống ⇒ trở lại
  /// practicing (đường lùi duy nhất được phép).
  void evaluateMaintained(String unitId, LearningState state) {
    final unit = _units[unitId];
    if (unit == null) return;
    if (unit.stage != MemoryStage.practicing &&
        unit.stage != MemoryStage.maintained) {
      return;
    }
    final allLong = SkillDimension.values
        .every((d) => state.skill(d).interval > kMaintainedIntervalDays);
    if (allLong && unit.stage == MemoryStage.practicing) {
      _transition(unit, MemoryStage.maintained,
          reason:
              'interval > $kMaintainedIntervalDays ngày trên cả 3 skill',
          source: TransitionSource.derived);
    } else if (!allLong && unit.stage == MemoryStage.maintained) {
      _transition(unit, MemoryStage.practicing,
          reason: 'interval rơi dưới ngưỡng maintained',
          source: TransitionSource.derived);
    }
  }

  void _transition(
    MemoryLifecycleUnit unit,
    MemoryStage to, {
    required String reason,
    required TransitionSource source,
    DateTime? at,
  }) {
    final now = at ?? _clock();
    unit.history.add(StageTransition(
      from: unit.stage,
      to: to,
      at: now,
      reason: reason,
      source: source,
    ));
    unit.stage = to;
    unit.stageEnteredAt = now;
  }

  /// Tổng kết cuối phiên (mục 6: "gộp vào cuối phiên học") — lấy và xóa hàng đợi.
  List<LifecycleSuggestion> endSessionSummary() {
    final drained = List<LifecycleSuggestion>.unmodifiable(_pendingSuggestions);
    _pendingSuggestions.clear();
    return drained;
  }

  /// Chỉ đọc — suggestion đang chờ (cho badge real-time, không chặn luồng).
  List<LifecycleSuggestion> get pendingSuggestions =>
      List.unmodifiable(_pendingSuggestions);
}
