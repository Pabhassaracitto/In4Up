// packages/in4up_stt/lib/stt_remote_slot.dart
//
// Slot single-flight cho STT qua API — WP2 (API-003) mục 4: "1 job
// transcribe tại một thời điểm; request kế tiếp → mã busy". Cùng khuôn mẫu
// `HyMtSlot` (lib/features/translation/engines/hymt_slot.dart) dùng cho
// Hy-MT offline — nhân bản trong package này vì `in4up_stt` không phụ
// thuộc ngược vào app layer.
//
// Khác biệt có chủ đích so với HyMtSlot: job STT có thể chạy NHIỀU PHÚT
// (file 30-60p, nhiều chunk) — caller kế tiếp không nên bị chặn chờ lâu,
// nên [maxWait] mặc định RẤT NGẮN (gần như báo busy ngay), thay vì 90s
// như Hy-MT (vốn dành cho request text ngắn).
//
// Pure (không Flutter/IO) — test bằng `flutter test` không cần thiết bị.
import 'dart:async';

class SttRemoteSlot {
  SttRemoteSlot({Duration maxWait = const Duration(seconds: 2)})
      : _maxWait = maxWait;

  final Duration _maxWait;
  bool _held = false;
  final List<Completer<void>> _waiters = <Completer<void>>[];

  /// Thời gian tối đa một caller chờ slot trước khi báo "busy".
  Duration get maxWait => _maxWait;

  /// Slot đang được giữ (bởi job đang chạy).
  bool get isHeld => _held;

  /// Số caller đang xếp hàng (không kể holder).
  int get pendingCount => _waiters.length;

  /// Lấy slot. Trả `true` nếu đã giữ (ngay lập tức, hoặc sau khi chờ trong
  /// [maxWait]); `false` = vẫn bận sau khi chờ — caller phải trả lỗi
  /// "busy" có cấu trúc ngay, không treo thêm.
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

  /// Trả slot. Có caller đang xếp hàng → trao thẳng cho caller đầu hàng
  /// (slot GIỮ nguyên — vẫn chỉ 1 holder); không thì slot trống.
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
