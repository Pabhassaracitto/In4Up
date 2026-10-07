// lib/features/screen_translate/screen_translate_channel.dart
//
// Cầu MethodChannel cho lane "dịch màn hình toàn hệ thống"
// (XLAT-SCR-002 · ADR-0011).
//
// Hai channel, hai chiều rõ ràng:
//  - `in4up/screentranslate` (control): UI engine → native (bật/tắt, quyền).
//  - `in4up/screentranslate/worker`: service → engine NỀN (đẩy frame xuống
//    Dart, nhận lại danh sách khối đã dịch).
//
// Mọi lỗi PlatformException được NUỐT ở đây và quy về giá trị an toàn
// (false/`ScreenTranslateResult.failure`) — nút trong Cài đặt không bao giờ
// được phép ném exception lên UI chỉ vì máy không có service.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/services.dart';

import 'screen_translate_models.dart';
import 'screen_translate_permission.dart';

/// Client phía Dart cho channel điều khiển.
///
/// Nhận [MethodChannel] qua constructor để test bơm channel giả
/// (`TestDefaultBinaryMessengerBinding`) mà không cần thiết bị.
class ScreenTranslateChannel {
  ScreenTranslateChannel({MethodChannel? channel})
      : _channel = channel ??
            const MethodChannel(ScreenTranslateProtocol.controlChannel);

  final MethodChannel _channel;

  /// CHỈ Android: iOS không cho overlay toàn hệ thống, desktop/web không có
  /// MediaProjection. UI dùng cờ này để ẨN nút (tiêu chí nghiệm thu #6).
  static bool get platformSupported => !kIsWeb && Platform.isAndroid;

  Future<bool> isSupported() async {
    if (!platformSupported) return false;
    return _boolCall(ScreenTranslateProtocol.methodIsSupported);
  }

  /// Đã được cấp "Hiển thị trên ứng dụng khác" (SYSTEM_ALERT_WINDOW) chưa.
  Future<bool> hasOverlayPermission() =>
      _boolCall(ScreenTranslateProtocol.methodHasOverlayPermission);

  /// Mở `Settings.ACTION_MANAGE_OVERLAY_PERMISSION`. Trả về false nếu không
  /// mở được (ROM lạ) — UI phải hướng dẫn tay chứ không im lặng.
  Future<bool> requestOverlayPermission() =>
      _boolCall(ScreenTranslateProtocol.methodRequestOverlayPermission);

  Future<bool> isRunning() =>
      _boolCall(ScreenTranslateProtocol.methodIsRunning);

  /// Ảnh chụp trạng thái QUYỀN (XLAT-SCR-003).
  ///
  /// Dùng để hiện đúng hướng dẫn TRƯỚC khi user bấm bong bóng, thay vì để họ
  /// bấm rồi không thấy gì. Trả [ScreenTranslateNativeStatus.fallback] khi
  /// native chưa đăng ký method (build cũ / chạy test).
  Future<ScreenTranslateNativeStatus> status() async {
    if (!platformSupported) return ScreenTranslateNativeStatus.fallback;
    try {
      final raw = await _channel.invokeMethod<Object?>(
        ScreenTranslateProtocol.methodStatus,
      );
      if (raw is Map) return ScreenTranslateNativeStatus.fromMap(raw);
      return ScreenTranslateNativeStatus.fallback;
    } on MissingPluginException {
      debugPrint('ℹ️ screentranslate: native chưa đăng ký method status');
      return ScreenTranslateNativeStatus.fallback;
    } on PlatformException catch (e) {
      debugPrint('❌ screentranslate.status: ${e.code} ${e.message}');
      return ScreenTranslateNativeStatus.fallback;
    }
  }

  /// Xin consent MediaProjection ngay (chỉ gọi khi app đang ở foreground).
  ///
  /// Đây là đường CHÍNH: Android 10+ chặn mở activity từ nền, nên consent phải
  /// được xin lúc app còn hiện trên màn hình.
  Future<bool> requestConsent() =>
      _boolCall(ScreenTranslateProtocol.methodRequestConsent);

  /// Bật bong bóng. Native sẽ tự xin consent MediaProjection khi user BẤM
  /// bong bóng lần đầu của phiên (Android 14+ bắt buộc hỏi lại mỗi phiên).
  Future<bool> start({required String targetLanguage}) => _boolCall(
        ScreenTranslateProtocol.methodStart,
        <String, Object?>{'targetLanguage': targetLanguage},
      );

  Future<bool> stop() => _boolCall(ScreenTranslateProtocol.methodStop);

  /// Đổi ngôn ngữ đích khi service đang chạy (không cần tắt/bật lại).
  Future<bool> setTargetLanguage(String targetLanguage) => _boolCall(
        ScreenTranslateProtocol.methodSetTargetLanguage,
        <String, Object?>{'targetLanguage': targetLanguage},
      );

  Future<bool> _boolCall(String method, [Map<String, Object?>? args]) async {
    if (!platformSupported) return false;
    try {
      final value = await _channel.invokeMethod<bool>(method, args);
      return value ?? false;
    } on MissingPluginException {
      // Build cũ chưa có native: coi như không hỗ trợ, KHÔNG crash.
      debugPrint('ℹ️ screentranslate: native chưa đăng ký method $method');
      return false;
    } on PlatformException catch (e) {
      debugPrint('❌ screentranslate.$method: ${e.code} ${e.message}');
      return false;
    }
  }
}

/// Phía engine NỀN: lắng nghe frame từ service, trả kết quả đã dịch.
///
/// [onFrame] nhận đúng map thô của native và trả [ScreenTranslateResult];
/// toàn bộ phần OCR + dịch nằm ở `ScreenTranslateController` nên lớp này
/// mỏng và test được bằng cách gọi handler trực tiếp.
class ScreenTranslateWorkerBinding {
  ScreenTranslateWorkerBinding({
    MethodChannel? channel,
    required this.onFrame,
    this.onStopped,
  }) : _channel = channel ??
            const MethodChannel(ScreenTranslateProtocol.workerChannel);

  final MethodChannel _channel;
  final Future<ScreenTranslateResult> Function(Map<Object?, Object?> frame)
      onFrame;
  final void Function()? onStopped;

  /// Gắn handler và báo cho native biết engine nền đã sẵn sàng.
  Future<void> attach() async {
    _channel.setMethodCallHandler(handleCall);
    try {
      await _channel.invokeMethod<void>(
        ScreenTranslateProtocol.methodWorkerReady,
      );
    } on PlatformException catch (e) {
      debugPrint('❌ screentranslate worker ready: ${e.code} ${e.message}');
    }
  }

  /// Public để test gọi thẳng (không cần binary messenger giả).
  Future<Object?> handleCall(MethodCall call) async {
    switch (call.method) {
      case ScreenTranslateProtocol.methodOnFrame:
        final args = call.arguments;
        if (args is! Map) {
          return ScreenTranslateResult.failure('Frame rỗng').toMap();
        }
        final result = await onFrame(args);
        return result.toMap();
      case ScreenTranslateProtocol.methodOnStopped:
        onStopped?.call();
        return null;
      default:
        throw MissingPluginException(
          'screentranslate worker: method ${call.method} không hỗ trợ',
        );
    }
  }

  /// Báo tiến trình ("Đang nhận dạng chữ…") để notification/bong bóng đổi
  /// trạng thái thay vì đứng im 3 giây.
  Future<void> reportProgress(String stage) async {
    try {
      await _channel.invokeMethod<void>(
        ScreenTranslateProtocol.methodReportProgress,
        <String, Object?>{'stage': stage},
      );
    } on PlatformException catch (_) {
      // Tiến trình là trang trí — không được làm hỏng lượt dịch.
    } on MissingPluginException catch (_) {
      // Test chạy không có native.
    }
  }
}
