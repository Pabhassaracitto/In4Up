import 'dart:async';

/// Slot single-flight: tại một thời điểm chỉ MỘT request Hy-MT được xử lý
/// (HYMT-002 mục 1).
///
/// Caller đầu tiên lấy slot ngay; các caller sau xếp hàng FIFO và chờ tối
/// đa [maxWait] — quá hạn thì [acquire] trả `false` và caller trả trạng
/// thái "đang bận" có cấu trúc NGAY, không treo thêm 2 phút.
///
/// Pure (không Flutter/IO) — test đơn giản bằng `flutter test`.
class HyMtSlot {
  HyMtSlot({Duration maxWait = const Duration(seconds: 90)})
      : _maxWait = maxWait;

  final Duration _maxWait;
  bool _held = false;
  final List<Completer<void>> _waiters = <Completer<void>>[];

  /// Thời gian tối đa một caller chờ slot trước khi báo "busy".
  Duration get maxWait => _maxWait;

  /// Slot đang được giữ (bởi request đang chạy).
  bool get isHeld => _held;

  /// Số caller đang xếp hàng (không kể holder).
  int get pendingCount => _waiters.length;

  /// Lấy slot. Trả `true` nếu đã giữ (ngay lập tức, hoặc sau khi chờ
  /// trong [maxWait]); `false` = vẫn bận sau khi chờ — caller phải trả
  /// lỗi "busy" có cấu trúc, không tiếp tục treo.
  Future<bool> acquire() async {
    if (!_held) {
      _held = true;
      return true;
    }
    final waiter = Completer<void>();
    _waiters.add(waiter);
    try {
      await waiter.future.timeout(_maxWait);
      return true;
    } on TimeoutException {
      _waiters.remove(waiter);
      return false;
    }
  }

  /// Trả slot. Nếu có caller đang xếp hàng, slot được trao thẳng cho
  /// caller đầu hàng (slot GIỮ nguyên — vẫn chỉ 1 holder); nếu không thì
  /// slot trống.
  void release() {
    if (!_held) return;
    if (_waiters.isNotEmpty) {
      final next = _waiters.removeAt(0);
      if (!next.isCompleted) next.complete();
      return;
    }
    _held = false;
  }
}
