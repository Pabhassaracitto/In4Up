/// ═══════════════════════════════════════════════════════════════
/// NETWORK POLICY — pure function (ADR-0021, SIMPLIFIED)
///
/// Không phân loại model rẻ/đặng — chỉ phân loại op:
///   * cheap  — tra từ, dịch, IPA, cloze, inflection, lookup → online.
///   * expensive — DSP, TTS neural, shadowing scoring, OCR, xử lý hình
///     ảnh → user-gate (offline/cache).
///
/// 3 chế độ (Settings):
///   * alwaysOnline — online mọi lúc (bỏ qua kết nối/op).
///   * alwaysOffline — không online, chỉ cache/offline.
///   * auto — cheap → online khi có mạng; expensive → user-gate
///     (offline/cache); offline khi mất mạng.
///
/// Thuần chức năng — không I/O, deterministic, test đơn giản.
/// ═══════════════════════════════════════════════════════════════
library;

/// Chi phí op — cheap/expensive (ADR-0021 §1).
enum OpCost {
  /// Tra từ, dịch, IPA, cloze, inflection, lookup — online.
  cheap,

  /// DSP, TTS neural, shadowing scoring, OCR, xử lý hình ảnh —
  /// user-gate (offline/cache).
  expensive,
}

/// Chế độ mạng — do user chọn ở Settings (ADR-0021 §2).
enum NetworkMode {
  /// Luôn online — bỏ qua kết nối thực tế.
  alwaysOnline,

  /// Luôn offline — chỉ cache/offline, không online.
  alwaysOffline,

  /// Tự động — cheap online khi có mạng; expensive user-gate;
  /// offline khi mất mạng.
  auto,
}

/// Kết quả quyết định — thuần dữ liệu.
class NetworkDecision {
  /// Có được phép gọi online?
  final bool allowOnline;

  /// Có dùng cache/offline (mà không online)?
  final bool useCache;

  /// Lý do (cho debug/UI).
  final String reason;

  const NetworkDecision({
    required this.allowOnline,
    required this.useCache,
    required this.reason,
  });

  @override
  String toString() =>
      'NetworkDecision(online: $allowOnline, cache: $useCache, $reason)';
}

/// Bộ quyết định network — thuần chức năng.
class NetworkPolicy {
  NetworkPolicy._();

  /// Quyết định cho 1 op + chế độ + trạng thái kết nối.
  ///
  /// [op] chi phí op (cheap/expensive).
  /// [mode] chế độ mạng (user choice).
  /// [hasConnection] trạng thái kết nối thực tế (WiFi/4G có dữ liệu).
  ///
  /// Thuần: không I/O, không side-effect. Deterministic.
  static NetworkDecision decide({
    required OpCost op,
    required NetworkMode mode,
    required bool hasConnection,
  }) {
    switch (mode) {
      case NetworkMode.alwaysOnline:
        // User chọn luôn online — bỏ qua kết nối thực tế.
        return const NetworkDecision(
          allowOnline: true,
          useCache: false,
          reason: 'alwaysOnline: online mọi lúc',
        );

      case NetworkMode.alwaysOffline:
        // User chọn luôn offline — chỉ cache/offline.
        return const NetworkDecision(
          allowOnline: false,
          useCache: true,
          reason: 'alwaysOffline: chỉ cache/offline',
        );

      case NetworkMode.auto:
        if (!hasConnection) {
          return const NetworkDecision(
            allowOnline: false,
            useCache: true,
            reason: 'auto + mất mạng: offline/cache',
          );
        }
        if (op == OpCost.cheap) {
          return const NetworkDecision(
            allowOnline: true,
            useCache: false,
            reason: 'auto + cheap + có mạng: online',
          );
        }
        // expensive + có mạng → user-gate: ưu tiên cache/offline.
        return const NetworkDecision(
          allowOnline: false,
          useCache: true,
          reason: 'auto + expensive + có mạng: user-gate (cache)',
        );
    }
  }

  /// Lệnh mặc định cho op (dùng khi không có user choice):
  /// cheap → online; expensive → cache. (Auto khi có mạng.)
  static NetworkDecision defaultForOp(
    OpCost op, {
    required bool hasConnection,
  }) {
    return decide(
      op: op,
      mode: NetworkMode.auto,
      hasConnection: hasConnection,
    );
  }
}
