// lib/features/mascot/shell_action_hub.dart
//
// MASCOT-001 — Cầu thực thi giữa registry linh vật và MainShell (PLAN-050 §5,
// ADR-0036 D3).
//
// MainShell gắn callbacks khi initState và gỡ khi dispose. Palette/linh vật
// gọi [ShellActionHub.instance.execute] từ bất kỳ đâu (kể cả khi có route
// push phía trên shell — shell vẫn mounted vì là root screen):
// - tab  → ShellNavigationRequest (hợp đồng mở rộng, giữ openRead/openListen cũ);
// - mode → callback _setListenMode/_setReadMode của shell;
// - tool → callback _handleTool (đúng dispatcher quick actions hiện có);
// - playback → P0 CHƯA nối: trả `executed: false`, không ném — parser cũ
//   voice_command giữ nguyên cho luồng phát lại tab Nghe.

import '../core/navigation/shell_navigation_request.dart';
import 'mascot_intent_registry.dart';

/// Callbacks shell đăng ký cho hub. Tất cả đều là hàm có sẵn của
/// `main_shell.dart` — không đổi hành vi shell.
class ShellActionCallbacks {
  final void Function(int index) onSetListenMode;

  final void Function(int index) onSetReadMode;

  final Future<void> Function(String toolId) onHandleTool;

  const ShellActionCallbacks({
    required this.onSetListenMode,
    required this.onSetReadMode,
    required this.onHandleTool,
  });
}

/// Kết quả thực thi — caller hiển thị phản hồi đúng sự thật (không fake).
class MascotActionExecution {
  final MascotActionDef action;

  final bool executed;

  /// Lý do khi không thực thi được (vd hub chưa gắn, nhóm chưa nối).
  final String? reason;

  const MascotActionExecution(this.action, this.executed, {this.reason});
}

class ShellActionHub {
  ShellActionHub._();

  static final ShellActionHub instance = ShellActionHub._();

  ShellActionCallbacks? _callbacks;

  bool get isAttached => _callbacks != null;

  /// MainShell gọi trong initState. Gắn đè bằng callbacks mới cũng được
  /// (shell chỉ có một thể hiện sống).
  void attach(ShellActionCallbacks callbacks) {
    _callbacks = callbacks;
  }

  /// MainShell gọi trong dispose — chỉ gỡ khi đúng thể hiện đã gắn.
  void detach(ShellActionCallbacks callbacks) {
    if (identical(_callbacks, callbacks)) {
      _callbacks = null;
    }
  }

  /// Thực thi một hành động đã đăng ký. KHÔNG ném exception — mọi lỗi trả về
  /// qua [MascotActionExecution.executed] = false + [reason].
  Future<MascotActionExecution> execute(MascotActionDef action) async {
    switch (action.group) {
      case MascotActionGroup.tab:
        switch (action.id) {
          case 'tab_home':
            ShellNavigationRequest.openHome();
          case 'tab_listen':
            ShellNavigationRequest.openListen();
          case 'tab_read':
            ShellNavigationRequest.openRead();
          case 'tab_understand':
            ShellNavigationRequest.openUnderstand();
          case 'tab_remember':
            ShellNavigationRequest.openRemember();
          default:
            return MascotActionExecution(action, false,
                reason: 'Tab không hỗ trợ: ${action.id}');
        }
        return MascotActionExecution(action, true);

      case MascotActionGroup.mode:
        final callbacks = _callbacks;
        if (callbacks == null) {
          return MascotActionExecution(action, false,
              reason: 'Shell chưa gắn hub');
        }
        switch (action.id) {
          case 'mode_listen':
            callbacks.onSetListenMode(0);
          case 'mode_speak':
            callbacks.onSetListenMode(1);
          case 'mode_watch':
            callbacks.onSetListenMode(2);
          case 'mode_read':
            callbacks.onSetReadMode(0);
          case 'mode_write':
            callbacks.onSetReadMode(1);
          default:
            return MascotActionExecution(action, false,
                reason: 'Mode không hỗ trợ: ${action.id}');
        }
        return MascotActionExecution(action, true);

      case MascotActionGroup.tool:
        final callbacks = _callbacks;
        if (callbacks == null) {
          return MascotActionExecution(action, false,
              reason: 'Shell chưa gắn hub');
        }
        await callbacks.onHandleTool(action.id);
        return MascotActionExecution(action, true);

      case MascotActionGroup.playback:
        // P0: chỉ đăng ký định danh + từ khoá; nối executor phát lại ở P2
        // (vòng giọng) — không tự chế đường phát thứ hai.
        return MascotActionExecution(action, false,
            reason: 'Playback chưa nối ở P0 (PLAN-050 §9)');
    }
  }
}
