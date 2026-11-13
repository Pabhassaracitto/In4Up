// lib/services/linux_media_backends_stub.dart
//
// Bản dùng cho WEB (và bất kỳ nền tảng nào không có `dart:io`): không có
// backend Linux, mọi thứ trả về "không sẵn sàng" để `AudioPlaybackSupport` /
// `VideoPlaybackSupport` dùng đường cũ (web đã có just_audio_web +
// video_player_web nên không cần gì ở đây).

/// Xem `linux_media_backends.dart` (bản `_io` giữ phần thật).
class LinuxMediaBackends {
  LinuxMediaBackends._();

  /// Luôn `false` ngoài Linux-desktop.
  static bool get ready => false;

  /// Luôn `null` ngoài Linux-desktop.
  static String? get libMpvPath => null;

  /// Không làm gì ngoài Linux-desktop.
  static bool install() => false;

  /// Không dò được ngoài Linux-desktop.
  static String? locateLibMpv() => null;
}

/// Bản stub của hàm thuần trong `_io` (test chạy trên VM nên dùng bản thật).
String? findLibMpvInLdconfig(String output) => null;
