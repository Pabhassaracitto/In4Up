// lib/audio/audio_backend_support.dart
//
// PSRC-219 (audit 1.28.0) — Linux vẫn báo "could not play this track".
//
// GỐC — tầng PLUGIN, không phải codec và không phải file:
//   App phát âm thanh bằng `just_audio`. Backend của just_audio là plugin
//   theo từng nền tảng: Android (ExoPlayer), iOS/macOS (AVPlayer), Windows
//   (`just_audio_windows` — có trong `pubspec.yaml`), Web. **Linux không có
//   plugin nào**: `pubspec.yaml` không khai `just_audio_media_kit` /
//   `just_audio_libwinmedia`, và `linux/flutter/generated_plugin_registrant.cc`
//   chỉ đăng ký ffmpeg_kit / file_selector / fullscreen_window / record /
//   url_launcher / webview — không có trình phát âm thanh.
//   Vì vậy `AudioPlayer.setFilePath()` trên Linux ném
//   `MissingPluginException`; `AudioPlayerService.loadFile()` bắt mọi lỗi và
//   trả `false`, `PlayerProvider` gộp thành `AudioLoadErrorKind.loadFailed`,
//   UI hiện đúng một câu chung "Không phát được bài này" — người dùng không
//   phân biệt được "file hỏng" với "máy không có bộ phát trong app".
//
// CÁCH SỬA (trong phạm vi lane L2, không thêm dependency native):
//   1. Biết trước nền tảng nào KHÔNG có backend ⇒ không gọi
//      `setFilePath()` (không sinh MissingPluginException rồi nuốt nó).
//   2. Trả lỗi có KIỂU riêng (`AudioLoadErrorKind.backendUnsupported`) để UI
//      nói đúng nguyên nhân và mở đường thay thế (trình phát của hệ thống).
//   Phần còn lại — có bộ phát TRONG app cho Linux — cần một plugin native
//   (`just_audio_media_kit`/libmpv hoặc GStreamer) và một lần build thật trên
//   Linux; đã ghi vào `docs/project/beta-1.29.0/L2-audio-video.md` §
//   "Phát hiện thêm" để hub quyết định (không bundle thư viện native nặng
//   trong một lane không build được Linux).
//
// Hàm thuần dưới đây để CI khoá lại được trên host VM.

import 'dart:io';

import 'package:flutter/foundation.dart';

import '../services/linux_media_backends.dart';

/// Backend phát âm thanh TRONG app.
enum AudioBackend {
  /// Nền tảng có plugin just_audio (Android/iOS/macOS/Windows/Web).
  inApp,

  /// Không có plugin ⇒ mọi lần nạp đều thất bại.
  ///
  /// Linux rơi vào nhóm này ở tầng PLUGIN, nhưng `AudioPlaybackSupport`
  /// nâng lên `inApp` khi `LinuxMediaBackends` cắm được media_kit (PSRC-219).
  none,
}

/// Nền tảng → backend. Tách khỏi `Platform` để test thuần.
AudioBackend audioBackendFor(String operatingSystem) {
  switch (operatingSystem) {
    case 'android':
    case 'ios':
    case 'macos':
    case 'windows':
      return AudioBackend.inApp;
    // PSRC-219: Linux không có plugin just_audio trong cây dependency.
    case 'linux':
      return AudioBackend.none;
    default:
      return AudioBackend.none;
  }
}

/// Cổng tra cứu nền tảng hiện tại cho toàn app.
class AudioPlaybackSupport {
  const AudioPlaybackSupport._();

  /// Nền tảng hiện tại có phát âm thanh trong app được không.
  static bool get isInAppSupported {
    if (kIsWeb) return true; // just_audio_web luôn có
    final os = Platform.operatingSystem;
    // PSRC-219: Linux KHÔNG có plugin just_audio, nhưng `LinuxMediaBackends`
    // cắm backend media_kit (libmpv) lúc khởi động ⇒ hỏi cờ RUNTIME, không
    // đoán theo tên nền tảng. Máy thiếu libmpv ⇒ false ⇒ UI báo đúng
    // "chưa có bộ phát" + mở bằng trình phát của hệ thống.
    if (os == 'linux') return LinuxMediaBackends.ready;
    return audioBackendFor(os) == AudioBackend.inApp;
  }

  /// Lý do (khoá tiếng Việt nguồn — đi qua `context.uiText`) khi KHÔNG hỗ trợ.
  static const String unsupportedReasonKey =
      'Máy này chưa có bộ phát âm thanh trong app (Linux). Hãy mở bằng trình '
      'phát của hệ thống.';
}
