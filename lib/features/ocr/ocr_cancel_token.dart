// lib/features/ocr/ocr_cancel_token.dart
//
// I4U18-PDF-OCR-TTS-001 (Agent F · F2) — timeout + cancel token cho OCR.
//
// Vì sao cần: `TextRecognizer.processImage` là một lời gọi native KHÔNG có
// đường hủy. Trên trang PDF scan lớn (hoặc khi Play services đang cập nhật)
// nó có thể không bao giờ trả về → dialog "Đang nhận dạng chữ..." quay mãi,
// người dùng kẹt trong một modal `barrierDismissible: false` (đúng hiện
// tượng "OCR spinner vô hạn" của card).
//
// Không thể giết tiến trình native, nhưng CÓ THỂ ngừng chờ nó: chạy đua
// giữa (1) tác vụ, (2) đồng hồ timeout, (3) cancel token do người dùng bấm.
// Ai về trước quyết định trạng thái UI; kết quả của kẻ về sau bị bỏ qua —
// đó cũng chính là guard chống callback đến muộn (reentrancy).
//
// File này THUẦN DART (không Flutter, không plugin) để test chạy trên host.

import 'dart:async';

/// Hạn mặc định cho một lần nhận dạng. 25 s: ML Kit latin trên thiết bị
/// tầm trung xử lý một trang A4 ~1–3 s; quá 25 s gần như chắc chắn là kẹt.
const Duration kOcrDefaultTimeout = Duration(seconds: 25);

/// Kết quả của một lần chạy có canh giờ.
enum OcrRunStatus {
  /// Tác vụ trả về trước khi hết giờ / bị hủy.
  completed,

  /// Hết [kOcrDefaultTimeout] mà tác vụ chưa trả về.
  timedOut,

  /// Người dùng bấm hủy.
  cancelled,
}

/// Cờ hủy dùng chung cho một phiên OCR (một hoặc nhiều ảnh).
class OcrCancelToken {
  final Completer<void> _completer = Completer<void>();
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  /// Hoàn tất khi [cancel] được gọi (dùng để chạy đua với tác vụ).
  Future<void> get whenCancelled => _completer.future;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    if (!_completer.isCompleted) _completer.complete();
  }
}

/// Kết quả chạy có canh giờ: trạng thái + giá trị (chỉ khi `completed`).
class OcrRun<T> {
  final OcrRunStatus status;
  final T? value;

  const OcrRun._(this.status, this.value);

  // Không dùng const constructor: `const OcrRun<T>.cancelled()` không hợp lệ
  // bên trong hàm generic (hằng số không tham chiếu được biến kiểu).
  OcrRun.completed(T value) : this._(OcrRunStatus.completed, value);
  OcrRun.timedOut() : this._(OcrRunStatus.timedOut, null);
  OcrRun.cancelled() : this._(OcrRunStatus.cancelled, null);

  bool get isCompleted => status == OcrRunStatus.completed;
  bool get isTimedOut => status == OcrRunStatus.timedOut;
  bool get isCancelled => status == OcrRunStatus.cancelled;
}

/// Chạy [task] nhưng KHÔNG chờ quá [timeout], và dừng chờ ngay khi
/// [cancelToken] bị hủy.
///
/// Lỗi do [task] ném ra vẫn được ném tiếp cho caller (OcrService bắt và
/// chuyển thành `OcrResult.failure`) — trừ khi lúc đó ta đã bỏ cuộc, khi ấy
/// lỗi bị nuốt có chủ đích: không ai còn nghe nữa, và một unhandled error
/// sau khi UI đã đóng dialog chỉ tạo crash giả.
Future<OcrRun<T>> runOcrGuarded<T>(
  Future<T> Function() task, {
  Duration timeout = kOcrDefaultTimeout,
  OcrCancelToken? cancelToken,
}) {
  if (cancelToken?.isCancelled ?? false) {
    return Future<OcrRun<T>>.value(OcrRun<T>.cancelled());
  }

  final completer = Completer<OcrRun<T>>();
  Timer? timer;

  void finish(OcrRun<T> run) {
    if (completer.isCompleted) return;
    timer?.cancel();
    completer.complete(run);
  }

  timer = Timer(timeout, () => finish(OcrRun<T>.timedOut()));
  cancelToken?.whenCancelled.then((_) => finish(OcrRun<T>.cancelled()));

  Future<T>(task).then(
    (value) => finish(OcrRun<T>.completed(value)),
    onError: (Object error, StackTrace stack) {
      if (completer.isCompleted) return; // đã bỏ cuộc — nuốt có chủ đích
      timer?.cancel();
      completer.completeError(error, stack);
    },
  );

  return completer.future;
}
