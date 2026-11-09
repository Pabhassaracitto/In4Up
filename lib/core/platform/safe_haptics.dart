import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' as services;

/// Best-effort haptics for controls that also run on desktop.
///
/// Flutter's haptic platform channel is implemented on mobile, but Windows,
/// macOS, Linux and web have no tactile feedback backend. Read-mode gestures
/// must remain usable there, so unsupported platforms skip the call and mobile
/// platform-channel failures are swallowed as non-fatal UI feedback.
class SafeHaptics {
  SafeHaptics._();

  static Future<void> selectionClick() =>
      _run(services.HapticFeedback.selectionClick);
  static Future<void> lightImpact() =>
      _run(services.HapticFeedback.lightImpact);
  static Future<void> mediumImpact() =>
      _run(services.HapticFeedback.mediumImpact);
  static Future<void> heavyImpact() =>
      _run(services.HapticFeedback.heavyImpact);
  static Future<void> vibrate() => _run(services.HapticFeedback.vibrate);

  static Future<void> _run(Future<void> Function() feedback) =>
      runForPlatform(
        feedback,
        platform: defaultTargetPlatform,
        isWeb: kIsWeb,
      );

  /// Executes [feedback] only where Flutter provides native haptic feedback.
  /// Exposed for deterministic tests without invoking a platform channel.
  @visibleForTesting
  static Future<void> runForPlatform(
    Future<void> Function() feedback, {
    required TargetPlatform platform,
    bool isWeb = false,
  }) async {
    if (isWeb ||
        (platform != TargetPlatform.android &&
            platform != TargetPlatform.iOS)) {
      return;
    }
    try {
      await feedback();
    } catch (_) {
      // Haptics are optional; they must never break the underlying action.
    }
  }
}
