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
