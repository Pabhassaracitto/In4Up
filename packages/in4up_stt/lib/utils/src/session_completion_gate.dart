// packages/in4up_stt/lib/utils/src/session_completion_gate.dart
//
// PSRC-177/180 (audit 1.26.0) — CỔNG CHỜ SESSION FFmpegKit KẾT THÚC.
//
// VÌ SAO CẦN (đây là gốc của cả hai issue, không phải lỗi FFmpeg):
//   `FFmpegKit.executeWithArgumentsAsync` **trả về NGAY** khi session vừa được
//   tạo. Tài liệu của chính plugin (`lib/ffmpeg_kit.dart`) ghi nguyên văn:
//   *"Note that this method returns immediately and does not wait the execution
//   to complete. You must use an [FFmpegSessionCompleteCallback] if you want to
//   be notified about the result."*
//   Và `AbstractSession.getReturnCode()`:
//   *"return code is only set for sessions that end with COMPLETED state. If a
//   session is not started, still running or failed then this method returns
//   null."*
//
//   Bản P0 (AVTOOL-001) đọc `getReturnCode()` + `getOutput()` ngay sau lời gọi
//   ⇒ code = null (⇒ `ReturnCode.isSuccess(null)` = false) và output = '' ⇒
//     • "Tạo lời" báo *chuyển đổi âm thanh thất bại (FfmpegKit)* dù FFmpeg
//       đang chạy đúng (PSRC-180);
//     • probe rỗng ⇒ `audioStreamCount == 0` ⇒ *"File nguồn không có âm thanh"*
//       (PSRC-177).
//
// Cổng này là hàm THUẦN (không import plugin) nên test được trên host VM:
// nó buộc đường gọi phải `await gate.future` trước khi đọc kết quả, và chịu
// được cả 2 tín hiệu kết thúc: complete callback của native, hoặc đường huỷ
// (native treo ⇒ không được để UI quay mãi).

import 'dart:async';

/// Cổng một lần: mở đúng một lần, các lần gọi sau bị bỏ qua (không ném).
class SessionCompletionGate<T> {
  final Completer<T> _completer = Completer<T>();

  /// Đã có tín hiệu kết thúc chưa.
  bool get isCompleted => _completer.isCompleted;

  /// Future hoàn tất khi session kết thúc (hoặc khi đường huỷ mở cổng).
  ///
  /// KHÔNG có timeout mặc định: một lệnh FFmpeg hợp lệ có thể chạy hàng chục
  /// phút (xuất 2 giờ audio trên máy yếu). Đường huỷ tự mở cổng.
  Future<T> get future => _completer.future;

  /// Mở cổng. Trả `true` nếu đây là tín hiệu đầu tiên.
  ///
  /// Dùng cho complete callback của FFmpegKit: plugin có thể gọi callback
  /// muộn hơn sau khi người dùng đã bấm Huỷ ⇒ lần gọi thứ hai phải là no-op
  /// thay vì `StateError: Future already completed`.
  bool complete(T value) {
    if (_completer.isCompleted) return false;
    _completer.complete(value);
    return true;
  }
}
