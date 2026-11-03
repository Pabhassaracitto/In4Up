import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Kênh MethodChannel cho notification TTS (foreground service Android).
///
/// M4U-IMPORT-002 — app CHẾT sau khi phát TTS: `MissingPluginException` KHÔNG
/// phải `PlatformException` ⇒ try/catch cũ KHÔNG bắt được ⇒ exception nổi lên
/// ("Unhandled Exception") và tiến trình chết (logcat: "Service protocol
/// connection closed. Lost connection to device.").
///
/// Native (`in4up/tts_notification`) chưa có trong bản build này ⇒ bắt
/// `MissingPluginException` + mọi lỗi khác: notification là thứ KHÔNG
/// critical, thiếu nó không được làm app sập.
class TtsNotificationService {
  static const _channel = MethodChannel('in4up/tts_notification');

  Future<void> activate({
    required String title,
    required String subtitle,
  }) async {
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('startForeground', {
          'title': title,
          'subtitle': subtitle,
          'icon': 'ic_headphones',
        });
      } else if (Platform.isIOS) {
        await _channel.invokeMethod('activateAudioSession');
      }
    } on MissingPluginException catch (e) {
      // Native chưa đăng ký channel (bản build cũ / nền tảng khác).
      debugPrint('[TtsNotification] native chưa có: ${e.message}');
    } on PlatformException catch (e) {
      // Notification không critical — log và tiếp tục
      debugPrint('[TtsNotification] activate failed: ${e.message}');
    } catch (e) {
      debugPrint('[TtsNotification] activate error: $e');
    }
  }

  /// Update notification content khi chuyển câu
  Future<void> updateNotification({
    required String title,
    required String subtitle,
  }) async {
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('updateNotification', {
          'title': title,
          'subtitle': subtitle,
        });
      }
    } on MissingPluginException catch (e) {
      debugPrint('[TtsNotification] native chưa có: ${e.message}');
    } on PlatformException catch (e) {
      debugPrint('[TtsNotification] update failed: ${e.message}');
    } catch (e) {
      debugPrint('[TtsNotification] update error: $e');
    }
  }

  /// Deactivate khi stop
  Future<void> deactivate() async {
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('stopForeground');
      } else if (Platform.isIOS) {
        await _channel.invokeMethod('deactivateAudioSession');
      }
    } on MissingPluginException catch (e) {
      debugPrint('[TtsNotification] native chưa có: ${e.message}');
    } on PlatformException catch (e) {
      debugPrint('[TtsNotification] deactivate failed: ${e.message}');
    } catch (e) {
      debugPrint('[TtsNotification] deactivate error: $e');
    }
  }
}
