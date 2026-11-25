// lib/core/navigation/shell_navigation_request.dart
//
// Yêu cầu chuyển tab của MainShell từ màn hình đang push phía trên
// (vd. Cabin → "Mở trong Tab Đọc"). MainShell lắng nghe [pending].
enum ShellNavigationTarget {
  read,

  /// YT-MEDIA-LIB-001 (#10 owner 2026-10-28): "Kho media YouTube" có nút
  /// *gửi sang Nghe* — mở tab Nghe (chế độ 0) sau khi nạp file âm thanh.
  listen,

  /// MASCOT-001 (PLAN-050/ADR-0036 D3): các đích bổ sung cho palette
  /// «Mở nhanh» và linh vật Sara — giữ nguyên hợp đồng read/listen cũ.
  home,
  understand,
  remember,

  /// Mở một tool của shell qua `_handleTool` — id đọc từ [pendingToolId].
  tool,
}

class ShellNavigationRequest {
  ShellNavigationRequest._();

  static final ValueNotifier<ShellNavigationTarget?> pending =
      ValueNotifier<ShellNavigationTarget?>(null);

  /// MASCOT-001: payload cho đích [ShellNavigationTarget.tool] — đặt TRƯỚC
  /// khi phát [pending]; MainShell đọc rồi tự xoá.
  static final ValueNotifier<String?> pendingToolId =
      ValueNotifier<String?>(null);

  static void openRead() {
    pending.value = null;
    pending.value = ShellNavigationTarget.read;
  }

  static void openListen() {
    pending.value = null;
    pending.value = ShellNavigationTarget.listen;
  }

  /// MASCOT-001: mở tool của shell (id trùng `_handleTool` trong
  /// `main_shell.dart`). Gọi được từ mọi route đang push.
  static void openTool(String toolId) {
    pendingToolId.value = toolId;
    pending.value = null;
    pending.value = ShellNavigationTarget.tool;
  }

  static void openHome() {
    pending.value = null;
    pending.value = ShellNavigationTarget.home;
  }

  static void openUnderstand() {
    pending.value = null;
    pending.value = ShellNavigationTarget.understand;
  }

  static void openRemember() {
    pending.value = null;
    pending.value = ShellNavigationTarget.remember;
  }
}
