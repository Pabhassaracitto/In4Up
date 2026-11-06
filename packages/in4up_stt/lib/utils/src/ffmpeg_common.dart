// packages/in4up_stt/lib/utils/src/ffmpeg_common.dart
//
// AVTOOL-001 (PLAN-046 P0) — KIỂU DÙNG CHUNG cho 2 đường FFmpeg.
//
// Vì sao tách file riêng: `ffmpeg_runner.dart` (mặt tiền) và
// `ffmpeg_process_impl.dart` (đường desktop) cần cùng `FfmpegRunResult` /
// `FfmpegCancelToken`. Nếu để chúng trong `ffmpeg_runner.dart` thì file impl
// buộc phải import ngược lại mặt tiền ⇒ vòng import. Ở đây KHÔNG import gì
// của FFmpegKit lẫn `dart:io`, nên cả hai phía đều dùng được mà không vòng.

/// Kết quả chung cho cả 2 đường (Kit trên mobile, Process trên desktop).
class FfmpegRunResult {
  const FfmpegRunResult({
    required this.success,
    required this.cancelled,
    required this.output,
  });

  final bool success;
  final bool cancelled;

  /// 30–40 dòng log cuối (đủ để phân loại lỗi, không phình bộ nhớ).
  final String output;
}

/// Token huỷ dùng chung — lớp gọi (media_export) chỉ cầm 1 đối tượng, không
/// cần biết đang chạy nền tảng nào.
///
/// Thiết kế kiểu "listener" thay vì giữ tham chiếu tới 2 token cụ thể: nhờ vậy
/// file này không phải import impl nào (tránh vòng import), và vẫn huỷ được
/// cả 2 đường — mỗi đường tự đăng ký cách huỷ của mình.
class FfmpegCancelToken {
  final List<void Function()> _listeners = <void Function()>[];
  bool _cancelRequested = false;

  bool get isCancelled => _cancelRequested;

  /// Đăng ký cách huỷ. Nếu đã huỷ trước đó thì gọi ngay (không mất tín hiệu).
  void onCancel(void Function() callback) {
    if (_cancelRequested) {
      callback();
      return;
    }
    _listeners.add(callback);
  }

  Future<void> cancel() async {
    if (_cancelRequested) return;
    _cancelRequested = true;
    for (final listener in List<void Function()>.of(_listeners)) {
      try {
        listener();
      } catch (_) {
        // Huỷ là best-effort: một đường lỗi không được chặn đường còn lại.
      }
    }
    _listeners.clear();
  }
}
