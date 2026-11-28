// lib/features/home_widgets/models/widget_quick_action.dart
//
// PLAN-050 · ADR-0040 — Danh mục các nút hành động 1-chạm trên «Thanh Lệnh Nhanh»
// (Home Screen Widget 4x1 / 4x2) và mục ghim lối tắt riêng.
//
// Thuần dữ liệu bất biến, không phụ thuộc dart:io (an toàn 100% cho cả Web/CI).

/// Tám hành động nhanh người dùng có thể chọn đặt lên 3 ô phải của Thanh Lệnh Nhanh
/// (cạnh ô tìm Từ điển cố định bên trái).
enum WidgetQuickActionId {
  voiceCapture('voice_capture'),
  ocrScan('ocr_scan'),
  screenTranslate('screen_translate'),
  aiChat('ai_chat'),
  liveCabin('live_cabin'),
  reviewDue('review_due'),
  tipitaka('tipitaka'),
  youtube('youtube');

  const WidgetQuickActionId(this.wireKey);

  /// Khoá lưu bền trong SharedPreferences & gửi qua JSON cho Native Widget.
  final String wireKey;

  static WidgetQuickActionId? fromWireKey(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final item in WidgetQuickActionId.values) {
      if (item.wireKey == raw) return item;
    }
    return null;
  }

  /// Nhãn nguồn tiếng Việt ngắn gọn (đi qua `AppUITranslations.translate` /
  /// `context.uiText` — tuân thủ tuyệt đối Rule #5).
  String get sourceTitle {
    switch (this) {
      case WidgetQuickActionId.voiceCapture:
        return 'Ghi chú nói';
      case WidgetQuickActionId.ocrScan:
        return 'Quét OCR';
      case WidgetQuickActionId.screenTranslate:
        return 'Dịch màn hình';
      case WidgetQuickActionId.aiChat:
        return 'I4U AI Chat';
      case WidgetQuickActionId.liveCabin:
        return 'Dịch Live Cabin';
      case WidgetQuickActionId.reviewDue:
        return 'Ôn tập ngay';
      case WidgetQuickActionId.tipitaka:
        return 'Tipiṭaka';
      case WidgetQuickActionId.youtube:
        return 'YouTube';
    }
  }

  /// Mô tả phụ hiển thị trong màn cấu hình Widget.
  String get sourceSubtitle {
    switch (this) {
      case WidgetQuickActionId.voiceCapture:
        return 'Bật mic nhận diện giọng nói và lưu từ ngay';
      case WidgetQuickActionId.ocrScan:
        return 'Chụp trang sách và nhận diện chữ đưa vào Đọc';
      case WidgetQuickActionId.screenTranslate:
        return 'Bật bong bóng dịch đè lên ứng dụng khác';
      case WidgetQuickActionId.aiChat:
        return 'Hỏi đáp về từ vựng và ngữ pháp';
      case WidgetQuickActionId.liveCabin:
        return 'Dịch cabin song song trực tiếp từ giọng nói';
      case WidgetQuickActionId.reviewDue:
        return 'Vào thẳng phiên ôn thẻ SRS đến hạn hôm nay';
      case WidgetQuickActionId.tipitaka:
        return 'Mở thẳng thư viện Kinh điển Pāli song ngữ';
      case WidgetQuickActionId.youtube:
        return 'Tìm và học nghe qua video phụ đề';
    }
  }

  /// Chỉ Android mới hỗ trợ bong bóng dịch màn hình toàn hệ thống.
  bool isSupportedOn({required bool isAndroid}) {
    if (this == WidgetQuickActionId.screenTranslate) return isAndroid;
    return true;
  }

  /// URI điều hướng chuẩn 1-chạm khi bấm nút trên Widget / Shortcut.
  String get deepLinkUri {
    switch (this) {
      case WidgetQuickActionId.voiceCapture:
        return 'in4up://action/voice_capture?autostart=1&src=widget';
      case WidgetQuickActionId.ocrScan:
        return 'in4up://action/ocr_scan?src=widget';
      case WidgetQuickActionId.screenTranslate:
        return 'in4up://action/screen_translate?src=widget';
      case WidgetQuickActionId.aiChat:
        return 'in4up://action/ai_chat?autofocus=1&src=widget';
      case WidgetQuickActionId.liveCabin:
        return 'in4up://nav/studio?target=cabin&src=widget';
      case WidgetQuickActionId.reviewDue:
        return 'in4up://action/review_due?mode=srs&src=widget';
      case WidgetQuickActionId.tipitaka:
        return 'in4up://nav/studio?target=tipitaka&src=widget';
      case WidgetQuickActionId.youtube:
        return 'in4up://nav/studio?target=youtube&src=widget';
    }
  }

  /// Khoá biểu tượng vector bên phía Android `res/drawable/ic_widget_*.xml`.
  String get nativeIconKey {
    switch (this) {
      case WidgetQuickActionId.voiceCapture:
        return 'mic';
      case WidgetQuickActionId.ocrScan:
        return 'ocr';
      case WidgetQuickActionId.screenTranslate:
        return 'translate';
      case WidgetQuickActionId.aiChat:
        return 'sparkle';
      case WidgetQuickActionId.liveCabin:
        return 'cabin';
      case WidgetQuickActionId.reviewDue:
        return 'leaf';
      case WidgetQuickActionId.tipitaka:
        return 'book';
      case WidgetQuickActionId.youtube:
        return 'play';
    }
  }

  /// Ba nút mặc định theo chốt Q2 của PLAN-050:
  /// Android: Ghi chú nói · Quét OCR · Dịch màn hình.
  /// Nền tảng không có Dịch màn hình: thay ô thứ 3 bằng I4U AI Chat.
  static List<WidgetQuickActionId> defaultQuickBarSlots({
    required bool isAndroid,
  }) {
    return <WidgetQuickActionId>[
      WidgetQuickActionId.voiceCapture,
      WidgetQuickActionId.ocrScan,
      isAndroid
          ? WidgetQuickActionId.screenTranslate
          : WidgetQuickActionId.aiChat,
    ];
  }

  /// Chuẩn hoá danh sách 3 ô nút người dùng lưu: khử trùng, lọc nút không hỗ trợ
  /// trên nền tảng hiện tại, và bù đủ đúng 3 ô từ danh sách mặc định.
  static List<WidgetQuickActionId> normalizeSlots(
    Iterable<String>? rawKeys, {
    required bool isAndroid,
    int slotCount = 3,
  }) {
    final result = <WidgetQuickActionId>[];
    if (rawKeys != null) {
      for (final raw in rawKeys) {
        final parsed = fromWireKey(raw.trim());
        if (parsed == null) continue;
        if (!parsed.isSupportedOn(isAndroid: isAndroid)) continue;
        if (!result.contains(parsed)) {
          result.add(parsed);
          if (result.length >= slotCount) break;
        }
      }
    }

    final fallbacks = <WidgetQuickActionId>[
      ...defaultQuickBarSlots(isAndroid: isAndroid),
      ...WidgetQuickActionId.values,
    ];
    for (final candidate in fallbacks) {
      if (result.length >= slotCount) break;
      if (!candidate.isSupportedOn(isAndroid: isAndroid)) continue;
      if (!result.contains(candidate)) {
        result.add(candidate);
      }
    }
    return List<WidgetQuickActionId>.unmodifiable(result);
  }
}
