// packages/in4up_ai/lib/src/provider/ai_provider_fallback.dart
//
// PSRC-254 — fallback có giới hạn giữa các provider theo thứ tự ưu tiên.
//
// Mục tiêu: provider đầu lỗi ⇒ thử provider kế trong cùng MỘT lượt chat,
// nhưng KHÔNG thử lại vô hạn (mỗi provider bị "lạnh" một nhịp) và KHÔNG
// sinh thêm câu trả lời trùng: nếu provider đã trả về một phần token thì
// lượt đó coi như CÓ KẾT CỤC, facade không gọi provider khác nữa.

/// Thời gian tạm loại provider vừa lỗi (ms). Tránh vòng lặp thử lại liên tục
/// khi server chết, nhưng vẫn cho user thử lại sau một phút mà không cần đổi
/// cấu hình.
const int kAiProviderCooldownMs = 60 * 1000;

/// Số provider TỐI ĐA được thử trong một lượt chat (kể cả provider đầu).
const int kAiProviderMaxAttemptsPerRequest = 3;

class AiProviderFallbackTracker {
  final Map<String, int> _failedAt = {};
  final int maxAttempts;
  final int cooldownMs;

  AiProviderFallbackTracker({
    this.maxAttempts = kAiProviderMaxAttemptsPerRequest,
    this.cooldownMs = kAiProviderCooldownMs,
  });

  /// Các id đang bị làm lạnh tại thời điểm [nowMs].
  Set<String> coolingIds({required int nowMs}) => {
        for (final entry in _failedAt.entries)
          if (nowMs - entry.value < cooldownMs) entry.key,
      };

  bool isCooling(String id, {required int nowMs}) {
    final at = _failedAt[id];
    return at != null && nowMs - at < cooldownMs;
  }

  /// Đánh dấu provider vừa lỗi TRƯỚC khi sinh được token nào.
  void markFailed(String id, {required int nowMs}) {
    _failedAt[id] = nowMs;
  }

  /// Xóa lạnh khi user thử lại thủ công hoặc cấu hình provider thay đổi.
  void clear(String id) => _failedAt.remove(id);

  void clearAll() => _failedAt.clear();

  /// Dùng cho test: số lượt thử còn lại tối đa.
  int get attemptsPerRequest => maxAttempts;
}
