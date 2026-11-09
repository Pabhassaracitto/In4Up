// BATTERY-OPT-001 — Xin quyền "Dừng tối ưu mức sử dụng pin".
//
// Startup and Settings both go through this service and open only Android's
// official permission UI. Do not show a second explanatory dialog first.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:in4up/core/language/localized_material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'battery_prompt_gate.dart';

class BatteryOptimizationService {
  BatteryOptimizationService._();

  static const String _prefsDeclinedKey = 'battery_opt_declined_v1';
  static final BatteryPromptGate _promptGate = BatteryPromptGate();

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  /// Đã được miễn tối ưu pin chưa.
  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (!isSupported) return true;
    try {
      return await Permission.ignoreBatteryOptimizations.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Người dùng đã bỏ qua/từ chối yêu cầu trước đó → startup không làm phiền.
  static Future<bool> hasDeclined() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsDeclinedKey) ?? false;
  }

  static Future<void> _setDeclined(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsDeclinedKey, value);
  }

  /// Gọi một lần lúc khởi động app (sau frame đầu tiên).
  /// Không hỏi lại nếu đã được cấp hoặc người dùng đã từ chối/bỏ qua.
  static Future<void> maybeRequestOnStartup(BuildContext context) async {
    if (!isSupported) return;
    if (await isIgnoringBatteryOptimizations()) return;
    if (await hasDeclined()) return;
    if (!context.mounted) return;
    await requestPermission(context);
  }

  /// Dùng chung bởi startup và Settings; chỉ mở Android's official permission
  /// UI (không thêm một app dialog phía trước). Trả true nếu đã được cấp.
  /// Settings có thể gọi lại sau khi người dùng chủ động bấm nút.
  static Future<bool> requestPermission(BuildContext context) async {
    if (!isSupported) return true;
    if (await isIgnoringBatteryOptimizations()) return true;
    if (!context.mounted || !_promptGate.tryEnter()) return false;

    try {
      final status = await Permission.ignoreBatteryOptimizations.request();
      // Nếu user đóng/từ chối system UI, không tự hiện lại mỗi lần mở app;
      // họ vẫn có thể chủ động thử lại từ Settings.
      await _setDeclined(!status.isGranted);
      return status.isGranted;
    } catch (_) {
      await _setDeclined(true);
      return false;
    } finally {
      _promptGate.leave();
    }
  }
}
