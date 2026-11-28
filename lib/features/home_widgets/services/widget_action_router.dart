// lib/features/home_widgets/services/widget_action_router.dart
//
// PLAN-050 · ADR-0040 — Bộ định tuyến hành động 1-chạm từ ngoài ứng dụng
// (`in4up://action/*`, `in4up://nav/*`, App Shortcuts, Quick Settings Tiles).
//
// Cùng kiến trúc `Host + Hàng đợi + Khử trùng lặp nhanh` đã kiểm chứng thực tế
// của `IncomingFileRouter` (`lib/core/files/incoming_file_router.dart`):
//   - Thuần Dart 100%, không import `MainShell` hay `dart:io` ⇒ chạy unit test
//     trực tiếp không cần dựng cây widget.
//   - Nếu sự kiện đến khi cold-start trước khi `MainShell` mount xong, xếp vào
//     hàng đợi `_pending` và xả tuần tự ngay khi `attachHost` được gọi.

import '../models/widget_action_link.dart';

abstract class WidgetActionHost {
  bool get isReady;

  Future<void> dispatchWidgetAction(WidgetActionRequest request);
}

class WidgetActionRouter {
  WidgetActionRouter({
    DateTime Function()? clock,
    this.dedupWindow = const Duration(milliseconds: 900),
  }) : _clock = clock ?? DateTime.now;

  static final WidgetActionRouter instance = WidgetActionRouter();

  final DateTime Function() _clock;
  final Duration dedupWindow;

  final List<WidgetActionRequest> _pending = <WidgetActionRequest>[];
  WidgetActionHost? _host;
  bool _draining = false;

  String? _lastSignature;
  DateTime? _lastDispatchedAt;

  int get pendingCount => _pending.length;

  /// Gắn `MainShell` host sau frame đầu tiên và xả mọi yêu cầu cold-start đang chờ.
  void attachHost(WidgetActionHost host) {
    _host = host;
    _drainPending();
  }

  void detachHost(WidgetActionHost host) {
    if (identical(_host, host)) {
      _host = null;
    }
  }

  /// Thử phân tích một URI thô; trả `true` nếu URI thuộc hợp đồng `action`/`nav`
  /// (hoặc `in4up://dict` rỗng để gõ tìm kiếm) và đã được tiếp nhận.
  bool tryHandleRawUri(
    String? raw, {
    String defaultSource = 'deep_link',
  }) {
    final parsed = WidgetActionDeepLink.parse(
      raw,
      defaultSource: defaultSource,
    );
    if (parsed == null) return false;
    enqueue(parsed);
    return true;
  }

  /// Thử phân tích danh sách tham số dòng lệnh (`argv`).
  bool tryHandleArguments(List<String> arguments) {
    final parsed = WidgetActionDeepLink.parseArguments(arguments);
    if (parsed == null) return false;
    enqueue(parsed);
    return true;
  }

  void enqueue(WidgetActionRequest request) {
    if (_isDuplicate(request)) return;
    _pending.add(request);
    _drainPending();
  }

  void resetForTest() {
    _pending.clear();
    _host = null;
    _draining = false;
    _lastSignature = null;
    _lastDispatchedAt = null;
  }

  bool _isDuplicate(WidgetActionRequest request) {
    final now = _clock();
    final sig = request.dedupSignature;
    if (_lastSignature == sig &&
        _lastDispatchedAt != null &&
        now.difference(_lastDispatchedAt!) < dedupWindow) {
      return true;
    }
    _lastSignature = sig;
    _lastDispatchedAt = now;
    return false;
  }

  Future<void> _drainPending() async {
    if (_draining) return;
    final host = _host;
    if (host == null || !host.isReady || _pending.isEmpty) return;

    _draining = true;
    try {
      while (_pending.isNotEmpty) {
        final currentHost = _host;
        if (currentHost == null || !currentHost.isReady) break;
        final next = _pending.removeAt(0);
        await currentHost.dispatchWidgetAction(next);
      }
    } finally {
      _draining = false;
    }
  }
}
