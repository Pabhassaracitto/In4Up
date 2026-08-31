import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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
    } on MissingPluginException {
      debugPrint('[TtsNotification] plugin chưa gắn — cần build lại APK (không đủ hot reload)');
    } on PlatformException catch (e) {
      debugPrint('[TtsNotification] activate failed: ${e.message}');
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
    } on MissingPluginException {
      debugPrint('[TtsNotification] plugin chưa gắn — cần build lại APK');
    } on PlatformException catch (e) {
      debugPrint('[TtsNotification] update failed: ${e.message}');
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
    } on MissingPluginException {
      debugPrint('[TtsNotification] plugin chưa gắn — cần build lại APK');
    } on PlatformException catch (e) {
      debugPrint('[TtsNotification] deactivate failed: ${e.message}');
    }
  }
}
