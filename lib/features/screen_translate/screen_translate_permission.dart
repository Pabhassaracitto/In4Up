// lib/features/screen_translate/screen_translate_permission.dart
//
// XLAT-SCR-003 — MÁY TRẠNG THÁI QUYỀN của "dịch màn hình toàn hệ thống".
//
// Vì sao phải có file này: triệu chứng bản 0.10.3 là "bấm bong bóng ⇒ không có
// gì xảy ra". Ba nguyên nhân gốc đều nằm ở QUYỀN, và cả ba đều im lặng:
//   1. Android 10+ chặn `startActivity` từ nền (không có exemption) ⇒ màn hình
//      xin consent MediaProjection không bao giờ mở ra.
//   2. Android 14 (API 34): consent chỉ có hiệu lực cho MỘT phiên chụp ⇒ thiếu
//      consent là chuyện bình thường, không phải lỗi.
//   3. Quyền overlay (SYSTEM_ALERT_WINDOW) bị thu hồi ⇒ không vẽ được bong bóng
//      lẫn bản dịch.
//
// Phần Kotlin CHƯA có CI biên dịch (xem card XLAT-SCR-002) nên mọi quyết định
// "thiếu cái gì / bước tiếp theo là gì" phải nằm ở Dart để có máy bắt chạy
// trong CI. Máy trạng thái này THUẦN DART (không plugin, không BuildContext)
// ⇒ test được bằng `flutter test` trên host VM.
//
// Hợp đồng với native: `ScreenTranslatePlugin.status()` trả Map với ĐÚNG các
// khoá trong [ScreenTranslateNativeStatus.fromMap] — sai khoá là rớt im lặng
// về mặc định, nên có test khoá lại.

/// Trạng thái quyền của bong bóng dịch.
enum ScreenTranslatePermissionState {
  /// Không phải Android (iOS/desktop/web): không có overlay toàn hệ thống.
  unsupported,

  /// Thiếu SYSTEM_ALERT_WINDOW — không vẽ được bong bóng. Phải mở Cài đặt.
  needsOverlayPermission,

  /// Đang chạy nhưng chưa có consent MediaProjection cho phiên này.
  needsCaptureConsent,

  /// Lần xin consent gần nhất bị user từ chối (khác với "chưa xin": phải nói
  /// rõ là do từ chối, và vẫn cho thử lại).
  consentDenied,

  /// Đủ quyền: bấm bong bóng là chụp được.
  ready,
}

/// Hành động UI gợi ý cho từng trạng thái (nút bấm dưới thẻ Cài đặt).
enum ScreenTranslateRecoveryAction {
  /// Không có gì để sửa (nền tảng không hỗ trợ, hoặc mọi thứ đã ổn).
  none,

  /// Mở `Settings.ACTION_MANAGE_OVERLAY_PERMISSION`.
  openOverlaySettings,

  /// Xin lại consent MediaProjection (đang ở foreground ⇒ không bị chặn).
  requestCaptureConsent,

  /// Mở Cài đặt thông báo: Android 13+ chưa cấp POST_NOTIFICATIONS thì
  /// notification của service bị ẩn ⇒ user tưởng "không có gì xảy ra".
  openNotificationSettings,
}

/// Ảnh chụp trạng thái từ phía native (map thô của `status`).
class ScreenTranslateNativeStatus {
  const ScreenTranslateNativeStatus({
    this.supported = false,
    this.overlayGranted = false,
    this.running = false,
    this.captureConsented = false,
    this.consentDenied = false,
    this.notificationsEnabled = true,
    this.blockedBySystem = false,
    this.blockReason = '',
    this.sdkInt = 0,
  });

  final bool supported;
  final bool overlayGranted;
  final bool running;
  final bool captureConsented;
  final bool consentDenied;
  final bool notificationsEnabled;
  final bool blockedBySystem;

  /// Mã lý do từ native (`overlay`, `consent_blocked`, `consent_denied`,
  /// `capture_error`, `engine`…) — để UI/logs nói đúng chuyện.
  final String blockReason;

  /// `Build.VERSION.SDK_INT`.
  final int sdkInt;

  /// Giá trị an toàn dùng khi native chưa đăng ký method (build cũ / test).
  static const ScreenTranslateNativeStatus fallback = ScreenTranslateNativeStatus();

  /// Tên khoá do `ScreenTranslatePlugin.statusMap()` gửi sang. Đổi ở Kotlin mà
  /// quên đây ⇒ mọi quyền rớt về mặc định (`supported: false`) và UI khoá nút
  /// mà không ai hiểu vì sao — lỗi kiểu này chỉ lộ trên máy thật nên có test.
  static const Set<String> wireKeys = <String>{
    'supported',
    'overlayGranted',
    'running',
    'captureConsented',
    'consentDenied',
    'notificationsEnabled',
    'blockedBySystem',
    'blockReason',
    'sdkInt',
  };

  factory ScreenTranslateNativeStatus.fromMap(Map<Object?, Object?> map) {
    bool flag(Object? key) {
      final value = map[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) return value == 'true';
      return false;
    }

    final sdk = map['sdkInt'];
    return ScreenTranslateNativeStatus(
      supported: flag('supported'),
      overlayGranted: flag('overlayGranted'),
      running: flag('running'),
      captureConsented: flag('captureConsented'),
      consentDenied: flag('consentDenied'),
      notificationsEnabled: map['notificationsEnabled'] is bool
          ? map['notificationsEnabled']! as bool
          : true,
      blockedBySystem: flag('blockedBySystem'),
      blockReason: (map['blockReason'] as String?) ?? '',
      sdkInt: sdk is num ? sdk.toInt() : 0,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'supported': supported,
        'overlayGranted': overlayGranted,
        'running': running,
        'captureConsented': captureConsented,
        'consentDenied': consentDenied,
        'notificationsEnabled': notificationsEnabled,
        'blockedBySystem': blockedBySystem,
        'blockReason': blockReason,
        'sdkInt': sdkInt,
      };
}

/// Kết quả của máy trạng thái — UI chỉ việc đọc, không tự đoán nữa.
class ScreenTranslatePermissionSnapshot {
  const ScreenTranslatePermissionSnapshot({
    required this.state,
    required this.action,
    required this.status,
    this.notificationsBlocked = false,
    this.blockedBySystem = false,
    this.requiresConsentEachSession = false,
  });

  final ScreenTranslatePermissionState state;

  /// Nút bấm / thao tác gợi ý để thoát khỏi trạng thái hiện tại.
  final ScreenTranslateRecoveryAction action;

  /// Ảnh chụp native gốc (UI cần `running`, `blockReason`…).
  final ScreenTranslateNativeStatus status;

  /// Android 13+ chưa cấp POST_NOTIFICATIONS ⇒ notification bị ẩn.
  final bool notificationsBlocked;

  /// Android đã CHẶN việc mở màn hình xin quyền từ nền (xem logcat
  /// `ActivityTaskManager: Background activity start ...`).
  final bool blockedBySystem;

  /// API 34+: consent chỉ có hiệu lực cho một phiên chụp.
  final bool requiresConsentEachSession;

  /// Đủ quyền để bấm bong bóng là có kết quả.
  bool get isReady => state == ScreenTranslatePermissionState.ready;

  /// Bong bóng (nếu đang hiện) đang ở trạng thái "cần thiết lập": chạm vào sẽ
  /// mở đúng màn hình cài đặt thay vì cố chụp rồi thất bại im lặng.
  bool get bubbleNeedsSetup =>
      state == ScreenTranslatePermissionState.needsCaptureConsent ||
      state == ScreenTranslatePermissionState.consentDenied ||
      state == ScreenTranslatePermissionState.needsOverlayPermission;

  /// Có thể bật/tắt bong bóng không (nền tảng hỗ trợ + đã có quyền overlay).
  bool get canToggle =>
      state != ScreenTranslatePermissionState.unsupported &&
      state != ScreenTranslatePermissionState.needsOverlayPermission;
}

/// Máy trạng thái QUYỀN — một chỗ duy nhất quyết định, có test khoá lại.
///
/// Thứ tự các luật (đừng đảo, mỗi luật có một lý do):
///   1. Không phải Android             → `unsupported`   (không có overlay toàn hệ thống)
///   2. Thiếu quyền overlay            → `needsOverlayPermission` (vẽ không được gì cả)
///   3. Service CHƯA bật               → `ready`         (chưa bật thì chưa thiếu quyền nào)
///   4. Đang bật mà thiếu consent      → `consentDenied` nếu vừa bị từ chối,
///                                       ngược lại `needsCaptureConsent`
///   5. Còn lại                        → `ready`
///
/// Cảnh báo PHỤ (không đổi state): thiếu POST_NOTIFICATIONS trên Android 13+
/// ⇒ action chuyển sang `openNotificationSettings` vì user sẽ không thấy gì.
class ScreenTranslatePermissionResolver {
  const ScreenTranslatePermissionResolver();

  /// API 34 = Android 14: consent có hiệu lực cho MỘT phiên chụp.
  static const int kConsentPerSessionSdk = 34;

  ScreenTranslatePermissionSnapshot resolve(ScreenTranslateNativeStatus status) {
    final notificationsBlocked = !status.notificationsEnabled;
    final perSession = status.sdkInt >= kConsentPerSessionSdk;

    final ScreenTranslatePermissionState state;
    if (!status.supported) {
      state = ScreenTranslatePermissionState.unsupported;
    } else if (!status.overlayGranted) {
      state = ScreenTranslatePermissionState.needsOverlayPermission;
    } else if (!status.running) {
      // Chưa bật ⇒ chưa có gì để "thiếu". Khi bật, plugin sẽ xin consent ngay
      // lúc app còn foreground (không vướng chặn background activity start).
      state = ScreenTranslatePermissionState.ready;
    } else if (!status.captureConsented) {
      state = status.consentDenied
          ? ScreenTranslatePermissionState.consentDenied
          : ScreenTranslatePermissionState.needsCaptureConsent;
    } else {
      state = ScreenTranslatePermissionState.ready;
    }

    final ScreenTranslateRecoveryAction action;
    if (state == ScreenTranslatePermissionState.needsOverlayPermission) {
      action = ScreenTranslateRecoveryAction.openOverlaySettings;
    } else if (state == ScreenTranslatePermissionState.needsCaptureConsent ||
        state == ScreenTranslatePermissionState.consentDenied) {
      // Đang ở màn hình Cài đặt (foreground) ⇒ xin lại consent được HỢP PHÁP,
      // không vướng chặn "background activity start" của Android 10+.
      action = ScreenTranslateRecoveryAction.requestCaptureConsent;
    } else if (state == ScreenTranslatePermissionState.ready &&
        notificationsBlocked) {
      // Notification bị ẩn cũng là một dạng "im lặng" ⇒ phải sửa trước.
      action = ScreenTranslateRecoveryAction.openNotificationSettings;
    } else {
      action = ScreenTranslateRecoveryAction.none;
    }

    return ScreenTranslatePermissionSnapshot(
      state: state,
      action: action,
      status: status,
      notificationsBlocked: notificationsBlocked,
      blockedBySystem: status.blockedBySystem,
      requiresConsentEachSession: perSession,
    );
  }
}
