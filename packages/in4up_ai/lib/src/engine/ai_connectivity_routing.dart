// YT-AUDIT-06 (IN4-104) — Định tuyến AI theo **loại mạng**.
//
// Yêu cầu owner (2026-10-20):
//   "Luôn ưu tiên mạng nếu dùng wifi; còn nếu phát hiện dùng mạng di động thì
//    ưu tiên cục bộ, nhưng nếu không thành công thì qua mạng."
//
// Trước đây `AiRoutePlanner.planLlmRoute()` chỉ có 3 mode TĨNH
// (offlineOnly / onlineFirst / offlineFirst) và **không hề biết** thiết bị
// đang wifi hay 4G (`connectivity_plus` lúc đó chỉ dùng ở `ai_model_loader`
// để quyết định có tải model hay không).
//
// Thiết kế: tách làm 2 lớp để test được mà không cần thiết bị.
//   • `resolveRouteMode()` + `classifyConnectivity()` — **thuần**, không đụng
//     plugin ⇒ `AiRoutePlanner` giữ nguyên contract cũ.
//   • `AiConnectivityRouter` — singleton bọc `connectivity_plus`, giữ giá trị
//     đã resolve để các chỗ gọi ĐỒNG BỘ (vd `AiServiceFacade._chatRoutePlan`)
//     vẫn dùng được.
//
// Bất biến được giữ nguyên: `offlineOnly` tuyệt đối không sinh request remote.

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../provider/ai_provider_config.dart';

/// Loại mạng hiện tại — rút gọn từ `ConnectivityResult` để phần thuần không
/// phụ thuộc plugin.
enum AiNetworkKind {
  /// Wifi / ethernet / VPN — rẻ, nhanh ⇒ ưu tiên online.
  wifi,

  /// Mạng di động (3G/4G/5G) — đắt, chậm ⇒ ưu tiên cục bộ.
  mobile,

  /// Không có mạng ⇒ cấm remote.
  none,
}

/// YT-AUDIT-06 (IN4-104) — resolve mode cấu hình + loại mạng ⇒ mode THẬT.
///
/// Chỉ `AiRouteMode.auto` bị thay đổi; 3 mode còn lại đi qua nguyên vẹn
/// (người dùng đã chọn rõ ràng thì tôn trọng lựa chọn đó).
AiRouteMode resolveRouteMode(AiRouteMode configured, AiNetworkKind kind) {
  if (configured != AiRouteMode.auto) return configured;
  return switch (kind) {
    // Wifi: API trước (nhanh, không tốn data), lỗi ⇒ fallback local.
    AiNetworkKind.wifi => AiRouteMode.onlineFirst,
    // 4G: máy trước (không tốn data), hỏng/thiếu model ⇒ qua API.
    AiNetworkKind.mobile => AiRouteMode.offlineFirst,
    // Không mạng: tuyệt đối không tạo request remote.
    AiNetworkKind.none => AiRouteMode.offlineOnly,
  };
}

/// Rút gọn danh sách `ConnectivityResult` (có thể có nhiều phần tử) thành 1
/// [AiNetworkKind].
///
/// Ưu tiên wifi khi có mặt cùng lúc với mobile (Android hay trả cả hai khi
/// wifi yếu nhưng vẫn kết nối).
AiNetworkKind classifyConnectivity(List<ConnectivityResult> results) {
  if (results.isEmpty) return AiNetworkKind.none;

  var hasWiredOrWifi = false;
  var hasMobile = false;
  var hasOther = false;

  for (final r in results) {
    switch (r) {
      case ConnectivityResult.wifi:
      case ConnectivityResult.ethernet:
        hasWiredOrWifi = true;
        break;
      case ConnectivityResult.mobile:
        hasMobile = true;
        break;
      case ConnectivityResult.none:
        break;
      default:
        // bluetooth / vpn / other — có đường ra mạng nhưng không rõ loại.
        hasOther = true;
        break;
    }
  }

  if (hasWiredOrWifi) return AiNetworkKind.wifi;
  if (hasMobile) return AiNetworkKind.mobile;
  // VPN/other: có mạng, không phải di động ⇒ coi như wifi.
  if (hasOther) return AiNetworkKind.wifi;
  return AiNetworkKind.none;
}

/// Giữ loại mạng hiện tại để các chỗ gọi đồng bộ dùng được.
///
/// * Mặc định **lạc quan là wifi** trước khi có kết quả thật — để hành vi
///   không đổi so với trước khi có module này trong trường hợp plugin chưa
///   sẵn sàng (vd desktop chưa đăng ký plugin).
/// * Lắng nghe `onConnectivityChanged` ⇒ đổi mạng giữa phiên được cập nhật.
/// * Mọi lỗi đều bị nuốt: định tuyến sai nhiều nhất là chậm hơn, không được
///   làm sập luồng AI.
class AiConnectivityRouter {
  AiConnectivityRouter._();

  static final AiConnectivityRouter instance = AiConnectivityRouter._();

  AiNetworkKind _kind = AiNetworkKind.wifi;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _started = false;
  DateTime? _lastMeasured;

  /// Đo lại sau khoảng thời gian này. Tra từ (`lookupWord`) là luồng gọi
  /// NHIỀU NHẤT (mỗi từ một lần) — đo lại từng lần sẽ biến thành hàng trăm
  /// platform-channel call. `onConnectivityChanged` vẫn cập nhật ngay khi có
  /// sự kiện đổi mạng, nên 10 s chỉ là lưới an toàn.
  static const Duration measurementTtl = Duration(seconds: 10);

  /// Loại mạng đang được dùng để định tuyến.
  AiNetworkKind get kind => _kind;

  /// Bắt đầu lắng nghe thay đổi mạng + đo ngay một lần. Gọi nhiều lần an toàn.
  Future<void> ensureStarted() async {
    if (_started) return;
    _started = true;
    try {
      _sub = Connectivity()
          .onConnectivityChanged
          .listen((results) => _kind = classifyConnectivity(results));
    } catch (_) {
      // Desktop/web có thể không có plugin — giữ giá trị lạc quan.
      _kind = AiNetworkKind.wifi;
    }
    await refresh(maxAge: Duration.zero);
  }

  /// Đo lại (trừ khi kết quả đo gần đây vẫn còn "tươi"). Trả về loại mạng.
  ///
  /// [maxAge] = `Duration.zero` ⇒ đo lại ngay (dùng cho `ensureStarted()`).
  Future<AiNetworkKind> refresh({Duration maxAge = measurementTtl}) async {
    final last = _lastMeasured;
    final now = DateTime.now();
    if (last != null && maxAge > Duration.zero && now.difference(last) < maxAge) {
      return _kind;
    }
    try {
      final results = await Connectivity()
          .checkConnectivity()
          .timeout(const Duration(seconds: 5));
      _kind = classifyConnectivity(results);
    } catch (_) {
      // Giữ nguyên giá trị cũ — không được làm hỏng định tuyến vì lỗi đo.
    }
    _lastMeasured = now;
    return _kind;
  }

  /// Mode THẬT để hoạch định route (dùng cho chỗ gọi đồng bộ).
  AiRouteMode resolve(AiRouteMode configured) =>
      resolveRouteMode(configured, _kind);

  /// Dùng cho test — đặt cứng loại mạng, bỏ qua plugin.
  void debugOverrideKind(AiNetworkKind kind) {
    _kind = kind;
    _lastMeasured = DateTime.now();
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _started = false;
  }
}
