// BATTERY-OPT-001 — Xin quyền "Dừng tối ưu mức sử dụng pin".
//
// Vì in4up chạy các model nặng (Whisper/STT, AI, dịch offline) và phát audio
// dài ở chế độ nền, Android sẽ bóp CPU/mạng hoặc giết tiến trình khi app bị
// "tối ưu pin". Service này hiển thị một dialog giải thích (Từ chối / Cho phép)
// rồi mới mở hộp thoại hệ thống, và chỉ hỏi lại khi người dùng chưa cho phép.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BatteryOptimizationService {
  BatteryOptimizationService._();

  static const String _prefsDeclinedKey = 'battery_opt_declined_v1';

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

  /// Người dùng đã bấm "Từ chối" trước đó → không làm phiền nữa.
  static Future<bool> hasDeclined() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsDeclinedKey) ?? false;
  }

  static Future<void> _setDeclined(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsDeclinedKey, value);
  }

  /// Gọi một lần lúc khởi động app (sau frame đầu tiên).
  /// Không hỏi lại nếu đã được cấp hoặc người dùng đã từ chối.
  static Future<void> maybeRequestOnStartup(BuildContext context) async {
    if (!isSupported) return;
    if (await isIgnoringBatteryOptimizations()) return;
    if (await hasDeclined()) return;
    if (!context.mounted) return;
    await requestWithDialog(context);
  }

  /// Hiển thị dialog giải thích rồi mở hộp thoại hệ thống nếu người dùng đồng ý.
  /// Trả về true nếu cuối cùng app được miễn tối ưu pin.
  static Future<bool> requestWithDialog(BuildContext context) async {
    if (!isSupported) return true;
    if (await isIgnoringBatteryOptimizations()) return true;
    if (!context.mounted) return false;

    final allow = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _BatteryOptimizationDialog(),
    );

    if (allow != true) {
      await _setDeclined(true);
      return false;
    }

    try {
      final status = await Permission.ignoreBatteryOptimizations.request();
      // Người dùng đã chấp nhận hỏi → không đánh dấu "declined",
      // nếu hệ thống chưa cấp thì lần sau vẫn có thể hỏi lại.
      await _setDeclined(false);
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }
}

class _BatteryOptimizationDialog extends StatelessWidget {
  const _BatteryOptimizationDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      icon: const Icon(Icons.battery_charging_full_rounded, size: 32),
      title: const Text('Dừng tối ưu mức sử dụng pin?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'In4up sec có thể chạy ngầm. Mức sử dụng pin sẽ không bị hạn chế.',
          ),
          const SizedBox(height: 12),
          Text(
            'Cần thiết để nhận dạng giọng nói, chạy model AI và phát audio '
            'liên tục mà không bị hệ thống tạm dừng.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Từ chối'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Cho phép'),
        ),
      ],
    );
  }
}
