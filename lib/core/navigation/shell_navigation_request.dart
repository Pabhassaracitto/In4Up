import 'package:flutter/foundation.dart';

/// Yêu cầu chuyển tab của MainShell từ màn hình đang push phía trên
/// (vd. Cabin → "Mở trong Tab Đọc"). MainShell lắng nghe [pending].
enum ShellNavigationTarget { read }

class ShellNavigationRequest {
  ShellNavigationRequest._();

  static final ValueNotifier<ShellNavigationTarget?> pending =
      ValueNotifier<ShellNavigationTarget?>(null);

  static void openRead() {
    pending.value = null;
    pending.value = ShellNavigationTarget.read;
  }
}
