import 'package:flutter/foundation.dart';

/// Yêu cầu chuyển tab của MainShell từ màn hình đang push phía trên
/// (vd. Cabin → "Mở trong Tab Đọc"). MainShell lắng nghe [pending].
enum ShellNavigationTarget { read, understand }

class ShellNavigationRequest {
  ShellNavigationRequest._();

  static final ValueNotifier<ShellNavigationTarget?> pending =
      ValueNotifier<ShellNavigationTarget?>(null);

  static void openRead() {
    pending.value = null;
    pending.value = ShellNavigationTarget.read;
  }

  static void openUnderstand() {
    pending.value = null;
    pending.value = ShellNavigationTarget.understand;
  }
}
