// BATTERY-OPT-001 — Xin quyền "Dừng tối ưu mức sử dụng pin".
//
// ════════════════════════════════════════════════════════════════════════════
// Yêu cầu chủ dự án (2026-11-09):
//   "bình thường người dùng mở lên phải gặp 2 thông báo về pin, tôi muốn chỉ có
//    1 thông báo và bấm vô là vào chỗ mở pin."
//
// Hai việc phải bảo đảm — và đây là NGUỒN SỰ THẬT DUY NHẤT cho cả hai:
//
//  1. CHỈ MỘT thông báo pin cho mỗi phiên app.
//     * `_shownThisSession` chặn ở cấp process: dù có 2 nơi gọi (startup +
//       Settings) trong cùng phiên thì màn hệ thống cũng chỉ hiện 1 lần.
//     * Chỉ MỘT điểm gọi lúc khởi động: `main_shell.dart` (grep
//       `maybeRequestOnStartup` phải ra đúng 1 file).
//     * Đã cấp quyền rồi, hoặc user đã bỏ qua/từ chối trước đó ⇒ im lặng.
//
//  2. BẤM LÀ VÀO CHỖ MỞ PIN (1 bước, không qua dialog giải thích của app).
//     * Đi qua channel native `in4up/platform` →
//       `openBatteryOptimizationSettings()` trong `MainActivity.kt`, dùng
//       `Settings.ACTION_IGNORE_BATTERY_OPTIMIZATIONS` với `package:` của app
//       ⇒ Android mở THẲNG hộp thoại cho In4Up.
//     * `permission_handler` chỉ là ĐƯỜNG LÙI cho máy không có channel (ví dụ
//       plugin chưa đăng ký) — vì có ROM trả `denied` ngay mà không mở màn nào.
// ════════════════════════════════════════════════════════════════════════════

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/services.dart'
    show MethodChannel, MissingPluginException, PlatformException;
import 'package:in4up/core/language/localized_material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'battery_prompt_gate.dart';

class BatteryOptimizationService {
  BatteryOptimizationService._();

  static const String _prefsDeclinedKey = 'battery_opt_declined_v1';
  static final BatteryPromptGate _promptGate = BatteryPromptGate();

  /// Channel native — mở thẳng màn tối ưu pin của hệ thống.
  static const MethodChannel _platformChannel = MethodChannel('in4up/platform');

  /// Đã hiện thông báo pin trong PHIÊN app này chưa.
  ///
  /// Cấp process (static) — đây là thứ bảo đảm "chỉ 1 thông báo" ngay cả khi
  /// có nhiều nơi gọi nhầm. Reset mỗi lần app khởi động lại (đúng ý: mỗi lần
  /// mở app nhiều nhất 1 lần).
  static bool _shownThisSession = false;

  /// Dùng cho test: đặt lại trạng thái "đã hiện trong phiên".
  @visibleForTesting
  static void debugResetSessionFlag() => _shownThisSession = false;

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

  /// Gọi MỘT lần lúc khởi động app (sau frame đầu tiên).
  ///
  /// Không hỏi lại nếu: không phải Android · đã được cấp · user đã từ chối
  /// trước đó · hoặc đã hiện trong phiên này.
  static Future<void> maybeRequestOnStartup(BuildContext context) async {
    if (!isSupported) return;
    if (_shownThisSession) return;
    if (await isIgnoringBatteryOptimizations()) return;
    if (await hasDeclined()) return;
    if (!context.mounted) return;
    await requestPermission(context);
  }

  /// Dùng chung bởi startup và Settings. **Bấm vào là mở màn tối ưu pin của
  /// hệ thống** (1 bước), không hiện dialog giải thích phía trước.
  ///
  /// Trả `true` nếu đã được cấp (hoặc không cần). Trả `false` nếu user chưa
  /// cấp — khi đó `_setDeclined` ghi nhớ để startup không làm phiền lại; họ
  /// vẫn chủ động thử lại được từ Settings.
  static Future<bool> requestPermission(BuildContext context) async {
    if (!isSupported) return true;
    if (await isIgnoringBatteryOptimizations()) return true;

    // Chỉ một lần/phiên: chặn "2 thông báo pin" ngay từ gốc.
    if (_shownThisSession) return await isIgnoringBatteryOptimizations();
    if (!context.mounted || !_promptGate.tryEnter()) return false;
    _shownThisSession = true;

    try {
      // ƯU TIÊN 1: native intent — mở THẲNG hộp thoại cho In4Up.
      final opened = await _openSystemBatteryScreen();
      if (opened) {
        // Màn hệ thống đã mở; trạng thái thật chỉ biết được khi user quay lại.
        // Ghi "chưa từ chối" để lần mở app sau còn kiểm tra lại (nếu user đã
        // bấm Cho phép thì `isIgnoringBatteryOptimizations()` sẽ true và
        // không hỏi nữa).
        await _setDeclined(false);
        return await isIgnoringBatteryOptimizations();
      }

      // ƯU TIÊN 2 (đường lùi): permission_handler — có ROM tự mở màn, có ROM
      // trả denied ngay. Không bao giờ để crash.
      final status = await Permission.ignoreBatteryOptimizations.request();
      await _setDeclined(!status.isGranted);
      return status.isGranted;
    } catch (_) {
      await _setDeclined(true);
      return false;
    } finally {
      _promptGate.leave();
    }
  }

  /// Gọi channel native để mở màn tối ưu pin. Trả `false` nếu không mở được
  /// (máy không có channel, hoặc hệ thống không có màn nào phù hợp).
  static Future<bool> _openSystemBatteryScreen() async {
    try {
      final opened = await _platformChannel
          .invokeMethod<bool>('openBatteryOptimizationSettings');
      return opened ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
