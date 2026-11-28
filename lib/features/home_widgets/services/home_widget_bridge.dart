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

  bool get isIosHost =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Android (`RemoteViews`) hoặc iOS (`WidgetKit`) đều nhận `WidgetSnapshot`.
  bool get isNativeWidgetHost => isAndroidHost || isIosHost;

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
    if (!isNativeWidgetHost) return false;
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

  /// Truy vấn số lượng từng loại Widget đang được ghim trên Launcher / WidgetKit.
  Future<NativeHomeWidgetStatus> getStatus() async {
    if (!isNativeWidgetHost) return NativeHomeWidgetStatus.unsupported;
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

  /// PLAN-050 P4: Ghim 1-chạm một tài liệu Đọc cụ thể (`RecentFile`) ra màn hình chính.
  Future<bool> pinDocumentShortcut({
    required String resourceId,
    required String title,
  }) {
    final safeId = _compactId(resourceId);
    if (safeId.isEmpty) return Future<bool>.value(false);
    return requestPinShortcut(
      id: 'doc_$safeId',
      shortLabel: _truncateShortcutLabel(title, fallback: 'Read'),
      deepLinkUri:
          'in4up://action/resume_read?id=${Uri.encodeQueryComponent(resourceId)}&src=pin_doc',
      iconKey: 'book',
    );
  }

  /// PLAN-050 P4: Ghim 1-chạm một bài Nghe / Pháp thoại (`RecentAudio`) ra màn hình chính.
  Future<bool> pinAudioShortcut({
    required String resourceId,
    required String title,
  }) {
    final safeId = _compactId(resourceId);
    if (safeId.isEmpty) return Future<bool>.value(false);
    return requestPinShortcut(
      id: 'audio_$safeId',
      shortLabel: _truncateShortcutLabel(title, fallback: 'Listen'),
      deepLinkUri:
          'in4up://action/resume_listen?id=${Uri.encodeQueryComponent(resourceId)}&autoplay=1&src=pin_audio',
      iconKey: 'headphones',
    );
  }

  /// PLAN-050 P4: Ghim 1-chạm một công cụ trong `ToolsOverlayV2` ra màn hình chính.
  Future<bool> pinToolShortcut({
    required String toolId,
    required String localizedLabel,
  }) {
    final spec = shortcutSpecForToolId(toolId);
    if (spec == null) return Future<bool>.value(false);
    return requestPinShortcut(
      id: 'tool_$toolId',
      shortLabel: _truncateShortcutLabel(localizedLabel, fallback: 'In4Up'),
      deepLinkUri: spec.deepLink,
      iconKey: spec.iconKey,
    );
  }

  /// Ánh xạ `toolId` của `ToolsOverlayV2` sang `(deepLink, iconKey)` an toàn.
  static ({String deepLink, String iconKey})? shortcutSpecForToolId(
    String toolId,
  ) {
    final clean = toolId.trim().toLowerCase();
    switch (clean) {
      case 'dictionary':
        return (
          deepLink: 'in4up://action/dict_search?autofocus=1&src=pin_tool',
          iconKey: 'search',
        );
      case 'live_cabin':
        return (
          deepLink: 'in4up://nav/studio?target=cabin&src=pin_tool',
          iconKey: 'mic',
        );
      case 'tipitaka':
        return (
          deepLink: 'in4up://nav/studio?target=tipitaka&src=pin_tool',
          iconKey: 'book',
        );
      case 'youtube_downloader':
        return (
          deepLink: 'in4up://nav/studio?target=youtube&src=pin_tool',
          iconKey: 'video',
        );
      case 'review':
        return (
          deepLink: 'in4up://action/review_due?mode=srs&src=pin_tool',
          iconKey: 'leaf',
        );
      case 'learn_by_heart':
        return (
          deepLink: 'in4up://action/review_due?mode=lhb&src=pin_tool',
          iconKey: 'leaf',
        );
      case 'home_widgets':
        return (
          deepLink: 'in4up://action/widget_settings?src=pin_tool',
          iconKey: 'sparkle',
        );
      case 'speak_mode':
      case 'youglish':
        return (
          deepLink: 'in4up://action/tool?id=$clean&src=pin_tool',
          iconKey: 'mic',
        );
      case 'sound_list':
      case 'media_tools':
      case 'video_player':
      case 'video_library':
        return (
          deepLink: 'in4up://action/tool?id=$clean&src=pin_tool',
          iconKey: 'headphones',
        );
      case 'write_mode':
      case 'web_reader':
      case 'pdf_reader':
      case 'word_list':
      case 'dict_manager':
      case 'dict_packs':
        return (
          deepLink: 'in4up://action/tool?id=$clean&src=pin_tool',
          iconKey: 'book',
        );
      case 'understand_tab':
      case 'understand_ai_coach':
      case 'timeline':
      case 'wordlist_stats':
      case 'stats':
      case 'word_map':
      case 'triangle':
      case 'venn':
      case 'shell_ui_settings':
        return (
          deepLink: 'in4up://action/tool?id=$clean&src=pin_tool',
          iconKey: 'sparkle',
        );
      default:
        return null;
    }
  }

  static String _compactId(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    if (cleaned.isEmpty) return '';
    return cleaned.length <= 40 ? cleaned : cleaned.substring(0, 40);
  }

  static String _truncateShortcutLabel(
    String raw, {
    required String fallback,
  }) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return fallback;
    final runes = trimmed.runes.toList(growable: false);
    if (runes.length <= 24) return trimmed;
    return '${String.fromCharCodes(runes.take(23))}…';
  }
}
