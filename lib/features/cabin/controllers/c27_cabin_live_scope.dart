import 'package:flutter/foundation.dart';

import '../models/c27_cabin_live_state.dart';
import 'c27_cabin_live_controller.dart';

/// C-27 wiring scope — giữ controller phiên Cabin chia sẻ giữa Full Cabin
/// Viewport (`LiveCabinScreen`), `LiveCaptionBubble` (shell) và Handoff Drawer
/// (doc 42 §1, §10; doc 43). Pure ChangeNotifier — không widget, không IO.
///
/// Dùng `C27CabinLiveScope.instance` trong app; constructor public để test
/// tạo scope riêng (tránh rò rỉ state giữa các test).
class C27CabinLiveScope extends ChangeNotifier {
  C27CabinLiveScope() {
    _bindController();
  }

  C27CabinLiveScope._() {
    _bindController();
  }

  /// Scope dùng chung toàn app (shell + màn Cabin + bubble).
  static final C27CabinLiveScope instance = C27CabinLiveScope._();

  /// Controller phiên Cabin duy nhất của phiên làm việc hiện tại.
  final C27CabinLiveController controller = C27CabinLiveController();

  void _bindController() {
    // The shell listens to the scope, not directly to the controller. Forward
    // controller transitions so the bubble/handoff chip rebuild immediately
    // when listening, pause, reconnect or handoff state changes.
    controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  /// Full Cabin Viewport đang mở — bubble ẩn khi viewport mở (doc 42 §10.2:
  /// bubble nhường chỗ Full Cabin Viewport, không đè lên nhau).
  bool viewportOpen = false;

  /// Handoff gần nhất gửi sang Hiểu/Nhớ (shell hiện chip "Quay lại Cabin Live").
  C27Handoff? handoffInbox;

  /// Workspace đích của handoff đang chờ shell chuyển tab (consume 1 lần).
  C27SourceType? _pendingHandoffTarget;

  /// Phiên đang chạy theo state machine (bubble chỉ hiện khi đúng).
  bool get sessionActive {
    final s = controller.state;
    return s == C27CabinLiveState.listening ||
        s == C27CabinLiveState.translating ||
        s == C27CabinLiveState.speaking ||
        s == C27CabinLiveState.paused ||
        s == C27CabinLiveState.reconnecting ||
        s == C27CabinLiveState.handoffActive;
  }

  void setViewportOpen(bool value) {
    if (viewportOpen == value) return;
    viewportOpen = value;
    notifyListeners();
  }

  /// Đặt handoff + đích — shell lắng nghe và tự chuyển tab tương ứng.
  void setHandoff(C27SourceType target, C27Handoff handoff) {
    _pendingHandoffTarget = target;
    handoffInbox = handoff;
    notifyListeners();
  }

  /// Lấy và xoá đích đang chờ (shell tiêu thụ 1 lần rồi giữ inbox cho chip).
  C27SourceType? consumePendingTarget() {
    final target = _pendingHandoffTarget;
    _pendingHandoffTarget = null;
    return target;
  }

  /// Dọn handoff sau khi đã quay lại Cabin Live (chip biến mất).
  void clearHandoffInbox() {
    if (handoffInbox == null && _pendingHandoffTarget == null) return;
    handoffInbox = null;
    _pendingHandoffTarget = null;
    notifyListeners();
  }
}
