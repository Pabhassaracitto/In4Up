// lib/services/linux_media_backends_io.dart
//
// PSRC-219 + PSRC-220 (beta 1.29.0, lane L2) — backend phát ÂM THANH và
// VIDEO cho Linux (media_kit / libmpv).

import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:media_kit/media_kit.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';

/// Cắm backend media_kit (libmpv) cho Linux và nhớ trạng thái.
///
/// Gọi MỘT lần trong `main()` ngay sau `WidgetsFlutterBinding.ensureInitialized()`
/// và TRƯỚC khi tạo `AudioPlayer`/`VideoPlayerController` đầu tiên.
class LinuxMediaBackends {
  LinuxMediaBackends._();

  static bool _ready = false;
  static String? _libMpvPath;

  /// `true` = đã cắm backend và tìm thấy libmpv ⇒ phát được TRONG app.
  ///
  /// `AudioPlaybackSupport.isInAppSupported` và
  /// `VideoPlaybackSupport.supportsInAppPlayback` đọc cờ này thay vì đoán
  /// theo `Platform.isLinux`, nhờ vậy máy thiếu libmpv vẫn nhận được câu báo
  /// đúng ("máy chưa có bộ phát") + nút mở bằng trình phát của hệ thống.
  static bool get ready => _ready;

  /// Đường dẫn libmpv đã tìm thấy (log/chẩn đoán).
  static String? get libMpvPath => _libMpvPath;

  /// Các vị trí phổ biến khi `ldconfig` không dùng được (NixOS, Flatpak…).
  static const List<String> candidateLibMpvPaths = <String>[
    '/usr/lib/x86_64-linux-gnu/libmpv.so.2',
    '/usr/lib/aarch64-linux-gnu/libmpv.so.2',
    '/usr/lib/arm-linux-gnueabihf/libmpv.so.2',
    '/usr/lib64/libmpv.so.2',
    '/usr/lib/libmpv.so.2',
    '/usr/local/lib/libmpv.so.2',
    '/usr/lib/x86_64-linux-gnu/libmpv.so.1',
    '/usr/lib/aarch64-linux-gnu/libmpv.so.1',
    '/usr/lib64/libmpv.so.1',
    '/usr/lib/libmpv.so.1',
    '/usr/local/lib/libmpv.so.1',
  ];

  /// Cắm backend (Linux only). Trả `true` khi phát được trong app.
  ///
  /// Không có libmpv ⇒ trả `false` và KHÔNG đăng ký gì: giữ nguyên hành vi
  /// "báo đúng nguyên nhân + mở bằng trình phát của hệ thống" (PSRC-219/220).
  static bool install() {
    if (kIsWeb || !Platform.isLinux) return false;
    if (_ready) return true;

    final libmpv = locateLibMpv();
    if (libmpv == null) {
      debugPrint(
        '[LinuxMediaBackends] Không thấy libmpv ⇒ giữ fallback mở bằng trình '
        'phát của hệ thống. Cài: sudo apt install libmpv2 (Debian/Ubuntu), '
        'sudo dnf install mpv-libs (Fedora), sudo pacman -S mpv (Arch).',
      );
      return false;
    }

    try {
      // media_kit cần ensureInitialized trước khi tạo Player/Controller.
      MediaKit.ensureInitialized();

      // PSRC-219: đăng ký JustAudioPlatform cho Linux. `windows: false` —
      // Windows đã có plugin riêng (`just_audio_windows`).
      JustAudioMediaKit.ensureInitialized(linux: true, windows: false);

      // PSRC-220: đăng ký VideoPlayerPlatform cho Linux. Chỉ `linux: true` —
      // Android/iOS/macOS giữ backend gốc của video_player (không cần libmpv).
      VideoPlayerMediaKit.ensureInitialized(linux: true);

      _libMpvPath = libmpv;
      _ready = true;
      debugPrint('[LinuxMediaBackends] Sẵn sàng (libmpv: $libmpv)');
      return true;
    } catch (e) {
      debugPrint('[LinuxMediaBackends] Cắm backend thất bại: $e');
      _ready = false;
      _libMpvPath = null;
      return false;
    }
  }

  /// Tìm libmpv: `ldconfig -p` trước, rồi các đường dẫn quen thuộc.
  static String? locateLibMpv() {
    // 1) ldconfig -p (Debian/Ubuntu/Fedora/Arch đều có).
    for (final args in <List<String>>[
      <String>['-p'],
      <String>[],
    ]) {
      try {
        final result = Process.runSync('ldconfig', args);
        if (result.exitCode != 0) continue;
        final found = findLibMpvInLdconfig('${result.stdout}');
        if (found != null) return found;
      } catch (_) {
        // ldconfig không có (NixOS…) — thử đường dẫn cứng bên dưới.
      }
    }

    // 2) Đường dẫn quen thuộc.
    for (final path in candidateLibMpvPaths) {
      try {
        if (File(path).existsSync()) return path;
      } catch (_) {
        // bỏ qua
      }
    }

    // 3) LD_LIBRARY_PATH (bản đóng gói tự nhúng libmpv cạnh binary).
    final env = Platform.environment['LD_LIBRARY_PATH'];
    if (env != null && env.isNotEmpty) {
      for (final dir in env.split(':')) {
        if (dir.trim().isEmpty) continue;
        for (final name in <String>['libmpv.so.2', 'libmpv.so.1']) {
          final candidate = '$dir/$name';
          try {
            if (File(candidate).existsSync()) return candidate;
          } catch (_) {
            // bỏ qua
          }
        }
      }
    }
    return null;
  }
}

/// Tách libmpv ra khỏi output của `ldconfig -p` — hàm THUẦN để CI khoá lại
/// được trên host bất kỳ.
///
/// Mẫu thật (Ubuntu 24.04):
/// `	libmpv.so.2 (libc6,x86-64) => /lib/x86_64-linux-gnu/libmpv.so.2`
///
/// Ưu tiên `libmpv.so.2` (mpv ≥ 0.35, API mới nhất) rồi mới tới `.so.1` và
/// `.so`. Trả `null` khi không có dòng nào.
String? findLibMpvInLdconfig(String output) {
  final pattern = RegExp(r'libmpv\.so[\w.]*\s.*?=>\s*(\S+)');
  String? fallback;
  for (final line in output.split('\n')) {
    final match = pattern.firstMatch(line);
    final path = match?.group(1);
    if (path == null || path.isEmpty) continue;
    if (line.contains('libmpv.so.2')) return path;
    fallback ??= path;
  }
  return fallback;
}
