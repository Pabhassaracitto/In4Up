import 'package:flutter/foundation.dart';

/// Yêu cầu chuyển tab của MainShell từ màn hình đang push phía trên
/// (vd. Cabin → "Mở trong Tab Đọc"). MainShell lắng nghe [pending].
enum ShellNavigationTarget {
  read,

  /// YT-MEDIA-LIB-001 (#10 owner 2026-10-28): "Kho media YouTube" có nút
  /// *gửi sang Nghe* — mở tab Nghe (chế độ 0) sau khi nạp file âm thanh.
  listen,
}

class ShellNavigationRequest {
  ShellNavigationRequest._();

  static final ValueNotifier<ShellNavigationTarget?> pending =
      ValueNotifier<ShellNavigationTarget?>(null);

  static void openRead() {
    pending.value = null;
    pending.value = ShellNavigationTarget.read;
  }

  static void openListen() {
    pending.value = null;
    pending.value = ShellNavigationTarget.listen;
  }
}
