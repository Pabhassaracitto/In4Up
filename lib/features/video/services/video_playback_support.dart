// lib/features/video/services/video_playback_support.dart
//
// PSRC-220 (audit 1.28.0) — Linux mở .mp4 ở tab View báo
//   "cannot open video: UnimplementedError int() has not been implemented".
//
// GỐC — tầng PLUGIN: `video_player` chỉ có implementation cho
//   Android / iOS / macOS / Web. Trên Linux (và Windows trong cây dependency
//   này) `VideoPlayerPlatform.instance` vẫn là bản mặc định của
//   `video_player_platform_interface`, mà mọi method của nó
//   `throw UnimplementedError()`. Lỗi hiện ra dưới dạng
//   "UnimplementedError int() has not been implemented" vì
//   `VideoPlayerController.file(...).initialize()` hỏi
//   `create()`/`buildView()` trước cả khi chạm file.
//   `VideoPlayerScreen._initPlayer()` bắt `catch (_)` rồi chỉ bật cờ
//   `_initFailed` ⇒ màn hình chỉ nói "Không phát được video này", không nói
//   vì sao và không có đường nào xem được file.
//
// CÁCH SỬA (trong phạm vi lane L2, không thêm dependency native):
//   1. Biết trước nền tảng nào KHÔNG có backend ⇒ không khởi tạo controller
//      (không đi vào nhánh UnimplementedError).
//   2. Hiện lý do + đường thay thế THẬT: mở tệp bằng trình phát của hệ điều
//      hành (`lib/services/external_open_service.dart` → `xdg-open` /
//      `explorer` / `open`).
//   Phần còn lại — phát TRONG app trên Linux — cần backend `media_kit`/libmpv
//   và một lần build Linux thật; đã ghi vào phiếu lane § "Phát hiện thêm".
//
// Hàm thuần dưới đây để CI khoá lại được trên host VM.

import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../services/linux_media_backends.dart';

/// Cách phát video trên nền tảng hiện tại.
enum VideoPlaybackBackend {
  /// Dùng `video_player` trong app.
  inApp,

  /// Không có plugin ⇒ chỉ mở được bằng trình phát của hệ điều hành.
  externalOnly,
}

/// Nền tảng → backend phát video.
VideoPlaybackBackend videoPlaybackBackendFor(String operatingSystem) {
  switch (operatingSystem) {
    case 'android':
    case 'ios':
    case 'macos':
      return VideoPlaybackBackend.inApp;
    // PSRC-220: Linux/Windows không có plugin video_player trong cây này.
    case 'linux':
    case 'windows':
      return VideoPlaybackBackend.externalOnly;
    default:
      return VideoPlaybackBackend.externalOnly;
  }
}

/// Cổng tra cứu cho UI.
class VideoPlaybackSupport {
  const VideoPlaybackSupport._();

  /// Có phát được video TRONG app trên nền tảng này không.
  static bool get supportsInAppPlayback {
    if (kIsWeb) return true; // video_player_web luôn có
    final os = Platform.operatingSystem;
    // PSRC-220: Linux không có plugin video_player, nhưng `LinuxMediaBackends`
    // cắm backend media_kit (libmpv) lúc khởi động ⇒ hỏi cờ RUNTIME. Máy thiếu
    // libmpv ⇒ false ⇒ màn hình giữ câu báo đúng + nút mở bằng trình phát hệ
    // thống thay vì hiện khung đen.
    if (os == 'linux') return LinuxMediaBackends.ready;
    return videoPlaybackBackendFor(os) == VideoPlaybackBackend.inApp;
  }

  /// Khoá tiếng Việt nguồn cho lý do (đi qua `context.uiText`).
  static const String externalOnlyReasonKey =
      'Máy này chưa có bộ phát video trong app (Linux/Windows). Hãy mở tệp '
      'bằng trình phát của hệ thống — vẫn xem được bình thường.';
}
