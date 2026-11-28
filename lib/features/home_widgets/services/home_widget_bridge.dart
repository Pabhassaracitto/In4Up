// lib/features/home_widgets/services/home_widget_bridge.dart
//
// PLAN-050 · ADR-0040 — Cầu nối mỏng `MethodChannel('in4up/home_widget')` +
// lưu cấu hình 3 ô nút Thanh Lệnh Nhanh trong `SharedPreferences`.
//
// Không dùng gói bên thứ ba; không import `dart:io` (an toàn cho Web build gate
// `lib/main_web.dart` và môi trường unit test).

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/widget_quick_action.dart';
import '../models/widget_snapshot.dart';

/// Định danh 4 loại Home Screen Widget phía Android `com.in4up.widgets.*`.
enum HomeWidgetKind {
  quickBar('quick_bar'),
  continueLearning('continue_learning'),
  flashcardSrs('flashcard_srs'),
  streakPulse('streak_pulse');

  const HomeWidgetKind(this.wireKey);

  final String wireKey;
}

/// Trạng thái hiện tại của hệ thống Widget trả về từ tầng Native.
class NativeHomeWidgetStatus {
  final bool isSupportedPlatform;
  final bool isRequestPinSupported;
  final Map<HomeWidgetKind, int> activeCounts;

  const NativeHomeWidgetStatus({
    required this.isSupportedPlatform,
    required this.isRequestPinSupported,
    required this.activeCounts,
  });

  static const NativeHomeWidgetStatus unsupported = NativeHomeWidgetStatus(
    isSupportedPlatform: false,
    isRequestPinSupported: false,
    activeCounts: <HomeWidgetKind, int>{},
  );

  int countOf(HomeWidgetKind kind) => activeCounts[kind] ?? 0;

  int get totalPinnedCount =>
      activeCounts.values.fold<int>(0, (sum, value) => sum + value);
}

class HomeWidgetBridge {
  HomeWidgetBridge._();

  static final HomeWidgetBridge instance = HomeWidgetBridge._();

  static const MethodChannel _channel = MethodChannel('in4up/home_widget');
  static const String quickSlotsPrefsKey = 'home_widget_quick_slots_v1';

  final ValueNotifier<int> configRevision = ValueNotifier<int>(0);

  bool get isAndroidHost =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Đọc 3 ô nút đã chọn của Thanh Lệnh Nhanh (bù mặc định tự động).
  Future<List<WidgetQuickActionId>> loadQuickBarSlots() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(quickSlotsPrefsKey);
      return WidgetQuickActionId.normalizeSlots(
        raw,
        isAndroid: isAndroidHost,
      );
    } catch (_) {
      return WidgetQuickActionId.defaultQuickBarSlots(
        isAndroid: isAndroidHost,
      );
    }
  }

  /// Lưu 3 ô nút của Thanh Lệnh Nhanh và tăng `configRevision` để đồng bộ ngay.
  Future<List<WidgetQuickActionId>> saveQuickBarSlots(
    Iterable<WidgetQuickActionId> actions,
  ) async {
    final normalized = WidgetQuickActionId.normalizeSlots(
      actions.map((item) => item.wireKey),
      isAndroid: isAndroidHost,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        quickSlotsPrefsKey,
        normalized.map((item) => item.wireKey).toList(growable: false),
      );
    } catch (_) {
      // Giữ trải nghiệm mượt nếu SharedPreferences tạm thời không khả dụng.
    }
    configRevision.value++;
    return normalized;
  }

  /// Đẩy bản chụp `WidgetSnapshot` sang Native và làm mới mọi Widget đang ghim.
  Future<bool> syncSnapshot(WidgetSnapshot snapshot) async {
    if (!isAndroidHost) return false;
    try {
      final ok = await _channel.invokeMethod<bool>(
        'syncSnapshot',
        <String, Object?>{
          'json': snapshot.toEncodedJson(),
        },
      );
      return ok ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Truy vấn số lượng từng loại Widget đang được ghim trên Launcher.
  Future<NativeHomeWidgetStatus> getStatus() async {
    if (!isAndroidHost) return NativeHomeWidgetStatus.unsupported;
    try {
      final raw = await _channel
          .invokeMapMethod<String, dynamic>('getStatus');
      if (raw == null) return NativeHomeWidgetStatus.unsupported;
      final countsMap = (raw['counts'] as Map<dynamic, dynamic>?) ??
          const <dynamic, dynamic>{};
      final parsedCounts = <HomeWidgetKind, int>{};
      for (final kind in HomeWidgetKind.values) {
        final rawCount = countsMap[kind.wireKey];
        parsedCounts[kind] = rawCount is int ? rawCount : 0;
      }
      return NativeHomeWidgetStatus(
        isSupportedPlatform: true,
        isRequestPinSupported: raw['requestPinSupported'] == true,
        activeCounts: Map<HomeWidgetKind, int>.unmodifiable(parsedCounts),
      );
    } on MissingPluginException {
      return NativeHomeWidgetStatus.unsupported;
    } on PlatformException {
      return NativeHomeWidgetStatus.unsupported;
    }
  }

  /// Mở hộp thoại hệ thống Android 8.0+ để ghim thẳng 1 Widget ra màn hình chính.
  Future<bool> requestPinWidget(HomeWidgetKind kind) async {
    if (!isAndroidHost) return false;
    try {
      final ok = await _channel.invokeMethod<bool>(
        'requestPinWidget',
        <String, Object?>{
          'kind': kind.wireKey,
        },
      );
      return ok ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Mở hộp thoại hệ thống Android 8.0+ để ghim 1 biểu tượng Lối tắt 1-chạm riêng
  /// (ví dụ «Ghi chú nói», «Tipiṭaka», «Phòng Nói») ra màn hình chính.
  Future<bool> requestPinShortcut({
    required String id,
    required String shortLabel,
    required String deepLinkUri,
    required String iconKey,
  }) async {
    if (!isAndroidHost) return false;
    try {
      final ok = await _channel.invokeMethod<bool>(
        'requestPinShortcut',
        <String, Object?>{
          'id': id,
          'shortLabel': shortLabel,
          'deepLink': deepLinkUri,
          'iconKey': iconKey,
        },
      );
      return ok ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
