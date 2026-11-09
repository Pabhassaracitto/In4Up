// lib/features/ocr/ocr_native_bridge.dart
//
// OCR-SCAN-CRASH-001 — cầu nối Dart ↔ native cho lane quét tài liệu.
//
// Kênh `in4up/ocr` (MainActivity.kt) trả lời đúng ba câu hỏi mà lớp Dart
// KHÔNG thể trả lời được, nhưng lại quyết định app có sống hay không:
//
//   1. `probeCapabilities` — máy có Google Play services (và có đang bật)
//      không, RAM bao nhiêu, SDK bao nhiêu. Document Scanner là thư viện
//      "unbundled": model + logic + UI nằm trong Play services, mở nó khi máy
//      không có GMS là tự ném lỗi ở luồng native (xem `ocr_precheck.dart`).
//   2. `beginScanSession` / `endScanSession` — đánh dấu "đang có phiên quét
//      chạy". MainActivity lưu cờ này vào `onSaveInstanceState`; nếu activity
//      bị hệ thống huỷ giữa lúc máy quét mở thì instance mới biết mà nói cho
//      Dart (giả thuyết 2 — mất activity result).
//   3. `pollScanSignal` — nhịp hỏi của `watchOcrScan` (ocr_scan_guard.dart):
//      phiên có bị cắt ngang không, có vết crash native không.
//
// Seam test: gán đè `OcrNativeBridge.invoke` (cùng mẫu với
// `OcrImagePicker.pick`) — trên host VM không có MethodChannel nào đăng ký.

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show MethodCall, MethodChannel;

import 'ocr_scan_guard.dart';

/// Chữ ký hàm gọi native — khai báo để test thay thế được.
typedef OcrNativeInvoke = Future<Object?> Function(
  String method,
  Map<Object?, Object?>? arguments,
);

class OcrNativeBridge {
  OcrNativeBridge._();

  static final OcrNativeBridge instance = OcrNativeBridge._();

  static const String channelName = 'in4up/ocr';

  /// Native gọi ngược lên Dart khi bắt được crash ở lane quét.
  static const String nativeCrashCallback = 'onOcrNativeCrash';

  static const MethodChannel _channel = MethodChannel(channelName);

  /// Implementation thật. Test gán đè hàm này (nhớ khôi phục ở tearDown).
  static OcrNativeInvoke invoke = _invokeOverChannel;

  static Future<Object?> _invokeOverChannel(
    String method,
    Map<Object?, Object?>? arguments,
  ) {
    return _channel.invokeMethod<Object?>(method, arguments);
  }

  String? _capturedCrash;
  bool _crashListenerAttached = false;

  /// Gắn listener nhận `onOcrNativeCrash` — gọi một lần lúc mở luồng OCR.
  ///
  /// Idempotent: gọi lại không chồng handler (mỗi lần gọi sẽ thay handler cũ,
  /// nên phải nhớ trạng thái).
  void attachCrashListener() {
    if (_crashListenerAttached) return;
    _crashListenerAttached = true;
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == nativeCrashCallback) {
        _capturedCrash = call.arguments?.toString();
      }
      return null;
    });
  }

  /// Khả năng thiết bị cho `OcrPrecheck.decide`. null = kênh không trả map
  /// (bản cài cũ chưa có kênh, hoặc native lỗi) — caller tự quyết cách an toàn.
  Future<Map<Object?, Object?>?> probeCapabilities() async {
    final raw = await invoke('probeCapabilities', null);
    if (raw is Map) return Map<Object?, Object?>.from(raw);
    return null;
  }

  /// Bắt đầu/kết thúc phiên quét — native dùng để lưu trạng thái qua
  /// `onSaveInstanceState`. Lỗi kênh KHÔNG được làm chết luồng quét: đây là
  /// lớp an toàn phụ, không phải điều kiện bắt buộc.
  Future<void> beginScanSession() => _fireAndForget('beginScanSession');

  Future<void> endScanSession() => _fireAndForget('endScanSession');

  /// Một nhịp hỏi trạng thái phiên (dùng làm `poll` cho `watchOcrScan`).
  ///
  /// Vết crash do native đẩy lên (`onOcrNativeCrash`) được ưu tiên hơn câu trả
  /// lời đồng bộ, vì nó là bằng chứng đã xảy ra rồi.
  Future<OcrScanSnapshot> pollScanSignal() async {
    final captured = _capturedCrash;
    if (captured != null) {
      _capturedCrash = null;
      return OcrScanSnapshot(OcrScanSignal.nativeCrash, crashTrace: captured);
    }

    final raw = await invoke('pollScanSignal', null);
    if (raw is! Map) return OcrScanSnapshot.idle;

    final map = Map<Object?, Object?>.from(raw);
    final signal = map['signal']?.toString();
    if (signal == 'interrupted') {
      return const OcrScanSnapshot(OcrScanSignal.interrupted);
    }
    if (signal == 'nativeCrash') {
      return OcrScanSnapshot(
        OcrScanSignal.nativeCrash,
        crashTrace: map['trace']?.toString(),
      );
    }
    return OcrScanSnapshot.idle;
  }

  /// Vết crash đã bắt mà chưa ai đọc (UI chẩn đoán dùng).
  String? takeCapturedCrash() {
    final trace = _capturedCrash;
    _capturedCrash = null;
    return trace;
  }

  Future<void> _fireAndForget(String method) async {
    try {
      await invoke(method, null);
    } catch (e) {
      debugPrint('⚠️ OcrNativeBridge.$method: $e');
    }
  }
}
