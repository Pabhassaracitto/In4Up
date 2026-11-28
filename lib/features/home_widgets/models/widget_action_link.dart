// lib/features/home_widgets/models/widget_action_link.dart
//
// PLAN-050 · ADR-0040 — Bộ phân tích & xác thực URI hành động 1-chạm từ ngoài app
// (`in4up://action/...`, `in4up://nav/...`, `i4u://...`, `https://in4up.app/...`).
//
// Thuần Dart 100% (không import Flutter/dart:io):
//   - Chạy kiểm thử đơn vị trực tiếp trên CI không cần máy ảo.
//   - Không bao giờ ném ngoại lệ với bất kỳ chuỗi lạ/hỏng nào từ bên ngoài.
//   - Mọi đích điều hướng đều nằm trong danh sách trắng (whitelist tĩnh).

/// Loại hành động 1-chạm được phép gọi từ Widget / App Shortcut / Quick Tile.
enum WidgetActionKind {
  /// Mở màn hình Từ điển kèm tự động đặt con trỏ vào ô tìm kiếm.
  dictSearch,

  /// Mở QuickCaptureSheet và bắt đầu thu âm nhận diện giọng nói ngay.
  voiceCapture,

  /// Chạy luồng quét tài liệu OCR (qua OcrPrecheck an toàn).
  ocrScan,

  /// Bật/tắt bong bóng Dịch màn hình toàn hệ thống (Android) hoặc mở hướng dẫn quyền.
  screenTranslate,

  /// Mở màn hình I4U AI Chat.
  aiChat,

  /// Vào thẳng phiên ôn tập từ vựng SRS (`srs`) hoặc Thuộc lòng (`lhb`).
  reviewDue,

  /// Mở lại đúng tài liệu đang đọc gần nhất (PDF/Văn bản/Thư viện Đọc).
  resumeRead,

  /// Mở lại bài nghe / Pháp thoại gần nhất (tùy chọn tự phát tiếp `autoPlay`).
  resumeListen,

  /// Mở màn cài đặt «Widget & Lối tắt màn hình chính» trong ứng dụng.
  widgetSettings,

  /// Chuyển thẳng tới một phòng Studio hoặc công cụ cốt lõi.
  openStudio,
}

/// Đích phòng Studio hợp lệ cho `in4up://nav/studio?target=...`.
enum WidgetStudioTarget {
  home('home'),
  read('read'),
  write('write'),
  listen('listen'),
  speak('speak'),
  watch('watch'),
  understand('understand'),
  remember('remember'),
  cabin('cabin'),
  tipitaka('tipitaka'),
  youtube('youtube');

  const WidgetStudioTarget(this.wireName);

  final String wireName;

  static WidgetStudioTarget? fromWireName(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final clean = raw.trim().toLowerCase();
    for (final target in WidgetStudioTarget.values) {
      if (target.wireName == clean) return target;
    }
    return null;
  }
}

/// Chế độ ôn tập của hành động `review_due`.
enum WidgetReviewMode {
  srs('srs'),
  learnByHeart('lhb');

  const WidgetReviewMode(this.wireName);

  final String wireName;

  static WidgetReviewMode fromWireName(String? raw) {
    final clean = (raw ?? '').trim().toLowerCase();
    if (clean == 'lhb' || clean == 'learn_by_heart') {
      return WidgetReviewMode.learnByHeart;
    }
    return WidgetReviewMode.srs;
  }
}

/// Yêu cầu hành động đã được làm sạch và xác thực an toàn.
class WidgetActionRequest {
  final WidgetActionKind kind;
  final WidgetStudioTarget? studioTarget;
  final WidgetReviewMode reviewMode;
  final bool autoPlay;
  final bool autoFocus;
  final bool autoStart;
  final String source;

  const WidgetActionRequest({
    required this.kind,
    this.studioTarget,
    this.reviewMode = WidgetReviewMode.srs,
    this.autoPlay = false,
    this.autoFocus = false,
    this.autoStart = false,
    this.source = 'widget',
  });

  /// Khóa chữ ký để khử trùng lặp intent bắn kép sát nhau (< 900 ms).
  String get dedupSignature =>
      '${kind.name}|${studioTarget?.wireName ?? ''}|${reviewMode.wireName}|$autoPlay|$source';

  @override
  bool operator ==(Object other) =>
      other is WidgetActionRequest &&
      other.kind == kind &&
      other.studioTarget == studioTarget &&
      other.reviewMode == reviewMode &&
      other.autoPlay == autoPlay &&
      other.autoFocus == autoFocus &&
      other.autoStart == autoStart &&
      other.source == source;

  @override
  int get hashCode => Object.hash(
        kind,
        studioTarget,
        reviewMode,
        autoPlay,
        autoFocus,
        autoStart,
        source,
      );

  @override
  String toString() =>
      'WidgetActionRequest($kind, studio=${studioTarget?.wireName}, '
      'review=${reviewMode.wireName}, autoPlay=$autoPlay, src=$source)';
}

class WidgetActionDeepLink {
  WidgetActionDeepLink._();

  static const Set<String> appSchemes = <String>{'in4up', 'i4u'};
  static const Set<String> httpsHosts = <String>{
    'in4up.app',
    'www.in4up.app',
  };

  /// Giới hạn chiều dài URI hợp lý để chặn chuỗi rác quá lớn từ bên ngoài.
  static const int maxUriLength = 512;

  /// Phân tích một chuỗi URI thô thành [WidgetActionRequest].
  /// Trả về `null` nếu URI không thuộc hợp đồng `action`/`nav` (hoặc là link tra
  /// từ cụ thể `in4up://dict?w=hello` vốn do `DictDeepLink` xử lý).
  static WidgetActionRequest? parse(
    String? raw, {
    String defaultSource = 'deep_link',
  }) {
    if (raw == null) return null;
    final cleaned = _stripControl(raw).trim();
    if (cleaned.isEmpty || cleaned.length > maxUriLength) return null;

    Uri? uri;
    try {
      uri = Uri.parse(cleaned);
    } catch (_) {
      return null;
    }

    final scheme = uri.scheme.toLowerCase();
    if (appSchemes.contains(scheme)) {
      return _parseAppScheme(uri, defaultSource: defaultSource);
    }

    if ((scheme == 'https' || scheme == 'http') &&
        httpsHosts.contains(uri.host.toLowerCase())) {
      return _parseHttpsScheme(uri, defaultSource: defaultSource);
    }

    return null;
  }

  /// Quét danh sách tham số dòng lệnh (`argv`) và trả về yêu cầu hợp lệ đầu tiên.
  static WidgetActionRequest? parseArguments(List<String> args) {
    for (final arg in args) {
      if (arg.isEmpty || arg.startsWith('-')) continue;
      final parsed = parse(arg, defaultSource: 'argv');
      if (parsed != null) return parsed;
    }
    return null;
  }

  static WidgetActionRequest? _parseAppScheme(
    Uri uri, {
    required String defaultSource,
  }) {
    final host = uri.host.toLowerCase();
    final segments = uri.pathSegments
        .map((segment) => segment.trim().toLowerCase())
        .where((segment) => segment.isNotEmpty)
        .toList();
    final src = _sanitizeSource(uri.queryParameters['src'], defaultSource);

    // Trường hợp đặc biệt: `in4up://dict` KHÔNG có từ cần tra (`w`/`word`/`q`/`text`)
    // ⇒ mở màn hình Từ điển trống để người dùng gõ ngay (auto-focus bàn phím).
    // Nếu CÓ từ cần tra, trả `null` để `DictDeepLink` xử lý như cũ (tương thích 100%).
    if (host == 'dict' || host == 'dictionary' || host == 'lookup') {
      if (_hasExplicitQueryWord(uri)) return null;
      return WidgetActionRequest(
        kind: WidgetActionKind.dictSearch,
        autoFocus: _parseBool(uri.queryParameters['autofocus'], fallback: true),
        source: src,
      );
    }

    if (host == 'action') {
      final actionName = segments.isNotEmpty
          ? segments.first
          : (uri.queryParameters['name'] ?? '').trim().toLowerCase();
      return _buildAction(actionName, uri, source: src);
    }

    if (host == 'nav') {
      final rawTarget = (segments.isNotEmpty && segments.first != 'studio')
          ? segments.first
          : (segments.length >= 2
              ? segments[1]
              : uri.queryParameters['target']);
      final studio = WidgetStudioTarget.fromWireName(rawTarget);
      if (studio == null) return null;
      return WidgetActionRequest(
        kind: WidgetActionKind.openStudio,
        studioTarget: studio,
        source: src,
      );
    }

    return null;
  }

  static WidgetActionRequest? _parseHttpsScheme(
    Uri uri, {
    required String defaultSource,
  }) {
    final segments = uri.pathSegments
        .map((segment) => segment.trim().toLowerCase())
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.isEmpty) return null;
    final src = _sanitizeSource(uri.queryParameters['src'], defaultSource);

    final head = segments.first;
    if (head == 'dict' || head == 'dictionary' || head == 'lookup') {
      if (_hasExplicitQueryWord(uri)) return null;
      return WidgetActionRequest(
        kind: WidgetActionKind.dictSearch,
        autoFocus: _parseBool(uri.queryParameters['autofocus'], fallback: true),
        source: src,
      );
    }

    if (head == 'action' && segments.length >= 2) {
      return _buildAction(segments[1], uri, source: src);
    }

    if (head == 'nav') {
      final rawTarget = segments.length >= 2 && segments[1] != 'studio'
          ? segments[1]
          : (segments.length >= 3
              ? segments[2]
              : uri.queryParameters['target']);
      final studio = WidgetStudioTarget.fromWireName(rawTarget);
      if (studio == null) return null;
      return WidgetActionRequest(
        kind: WidgetActionKind.openStudio,
        studioTarget: studio,
        source: src,
      );
    }

    return null;
  }

  static WidgetActionRequest? _buildAction(
    String actionName,
    Uri uri, {
    required String source,
  }) {
    switch (actionName) {
      case 'dict':
      case 'dict_search':
        return WidgetActionRequest(
          kind: WidgetActionKind.dictSearch,
          autoFocus:
              _parseBool(uri.queryParameters['autofocus'], fallback: true),
          source: source,
        );
      case 'voice_capture':
      case 'quick_capture':
        return WidgetActionRequest(
          kind: WidgetActionKind.voiceCapture,
          autoStart:
              _parseBool(uri.queryParameters['autostart'], fallback: true),
          source: source,
        );
      case 'ocr':
      case 'ocr_scan':
        return WidgetActionRequest(
          kind: WidgetActionKind.ocrScan,
          source: source,
        );
      case 'screen_translate':
        return WidgetActionRequest(
          kind: WidgetActionKind.screenTranslate,
          source: source,
        );
      case 'ai_chat':
        return WidgetActionRequest(
          kind: WidgetActionKind.aiChat,
          autoFocus:
              _parseBool(uri.queryParameters['autofocus'], fallback: true),
          source: source,
        );
      case 'review':
      case 'review_due':
        return WidgetActionRequest(
          kind: WidgetActionKind.reviewDue,
          reviewMode: WidgetReviewMode.fromWireName(uri.queryParameters['mode']),
          source: source,
        );
      case 'resume_read':
        return WidgetActionRequest(
          kind: WidgetActionKind.resumeRead,
          source: source,
        );
      case 'resume_listen':
        return WidgetActionRequest(
          kind: WidgetActionKind.resumeListen,
          autoPlay:
              _parseBool(uri.queryParameters['autoplay'], fallback: false),
          source: source,
        );
      case 'widget_settings':
      case 'widgets':
        return WidgetActionRequest(
          kind: WidgetActionKind.widgetSettings,
          source: source,
        );
      default:
        return null;
    }
  }

  static bool _hasExplicitQueryWord(Uri uri) {
    for (final key in const <String>['w', 'word', 'q', 'text']) {
      final val = uri.queryParameters[key];
      if (val != null && val.trim().isNotEmpty) return true;
    }
    return false;
  }

  static bool _parseBool(String? raw, {required bool fallback}) {
    if (raw == null) return fallback;
    final clean = raw.trim().toLowerCase();
    if (clean == '1' || clean == 'true' || clean == 'yes') return true;
    if (clean == '0' || clean == 'false' || clean == 'no') return false;
    return fallback;
  }

  static String _sanitizeSource(String? raw, String fallback) {
    if (raw == null) return fallback;
    final clean = raw.trim().toLowerCase();
    if (clean.isEmpty || clean.length > 32) return fallback;
    if (!RegExp(r'^[a-z0-9_-]+$').hasMatch(clean)) return fallback;
    return clean;
  }

  static String _stripControl(String value) {
    if (!value.runes.any((rune) => rune < 0x20 || rune == 0x7F)) return value;
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      if (rune < 0x20 || rune == 0x7F) continue;
      buffer.writeCharCode(rune);
    }
    return buffer.toString();
  }
}
