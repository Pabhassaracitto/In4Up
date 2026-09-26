// packages/in4up_ai/lib/src/engine/ai_route_planner.dart
//
// WP1 (API-002) — Hoạch định route LLM (chat/analysis) THUẦN LOGIC.
//
// Tách khỏi facade để test được yêu cầu AT của WP1 mà không cần network:
// "Routing = offline-only → KHÔNG có request /chat/completions nào đi ra".
// Facade gọi `planLlmRoute` rồi mới quyết định có tạo AiEngineRemote hay
// không — plan không chứa remote ⇒ engine remote không được khởi tạo ⇒
// không request nào đi ra (không chỉ "không gọi").

import '../provider/ai_provider_config.dart';

/// Một điểm dừng trong route: engine remote (API) hoặc engine local
/// (Gemma .gguf, hoặc mock khi không có model).
enum AiLlmRouteStop { remote, local }

/// Route đã hoạch định cho 1 request LLM.
class AiLlmRoutePlan {
  /// Thứ tự engine sẽ thử — engine đầu lỗi ⇒ thử engine kế (fallback 2 chiều
  /// theo ADR-0007). `local` luôn có mặt (cuối cùng là mock trung thực).
  final List<AiLlmRouteStop> stops;

  const AiLlmRoutePlan(this.stops);

  /// Route có dùng engine remote không (false ⇒ tuyệt đối không gọi API).
  bool get usesRemote => stops.contains(AiLlmRouteStop.remote);

  bool get remoteFirst => stops.isNotEmpty && stops.first == AiLlmRouteStop.remote;
}

/// Hoạch định route cho năng lực LLM (AiRouteCapability.chat) theo
/// AiRoutingPrefs (WP0):
///
/// * offlineOnly  → [local] — KHÔNG bao giờ gọi API.
/// * onlineFirst  → [remote, local] — API trước (nếu có provider + model),
///   lỗi ⇒ fallback local.
/// * offlineFirst → [local, remote] khi đã có model Gemma thật (ưu tiên
///   offline); [remote, local] khi CHƯA có model offline (API là lựa chọn
///   thật duy nhất — mock chỉ là lớp cuối trung thực).
/// * Không provider hợp lệ (chưa cấu hình / provider tắt / thiếu model) →
///   [local] — app hành xử y hệt trước khi có tầng API (mặc định WP0).
AiLlmRoutePlan planLlmRoute({
  required AiRouteMode mode,
  required bool remoteAvailable,
  required bool localModelReady,
}) {
  if (!remoteAvailable || mode == AiRouteMode.offlineOnly) {
    return const AiLlmRoutePlan([AiLlmRouteStop.local]);
  }
  switch (mode) {
    case AiRouteMode.offlineOnly:
      return const AiLlmRoutePlan([AiLlmRouteStop.local]);
    case AiRouteMode.onlineFirst:
      return const AiLlmRoutePlan(
          [AiLlmRouteStop.remote, AiLlmRouteStop.local]);
    case AiRouteMode.offlineFirst:
      return localModelReady
          ? const AiLlmRoutePlan(
              [AiLlmRouteStop.local, AiLlmRouteStop.remote])
          : const AiLlmRoutePlan(
              [AiLlmRouteStop.remote, AiLlmRouteStop.local]);
  }
}
