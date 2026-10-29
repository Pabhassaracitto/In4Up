// lib/features/ocr/ocr_scan_guard.dart
//
// OCR-SCAN-CRASH-001 (giả thuyết 2) — canh phiên quét Document Scanner.
//
// Vì sao cần: plugin `google_mlkit_document_scanner` 0.5.0 giữ ĐÚNG MỘT ô
// `pendingResult` và chỉ trả lời Dart khi `onActivityResult` tới (đối chiếu
// source tại commit release `f29f844` = 0.5.0 — KANBAN OCR-SCAN-CRASH-001).
// Nếu activity bị hệ thống huỷ giữa lúc máy quét đang mở (máy ít RAM, bật
// "Don't keep activities", tiến trình bị giết), instance plugin MỚI không còn
// `pendingResult` → `scanDocument()` KHÔNG BAO GIỜ hoàn tất: màn hình đứng im
// không lỗi, không toast. Cùng lúc, crash native ở lane quét (giả thuyết 1/3)
// cũng làm mất luôn đầu dây trả lời.
//
// Không thể buộc native trả lời, nhưng CÓ THỂ ngừng CHỜ nó: chạy đua giữa
// (1) tác vụ quét và (2) nhịp hỏi trạng thái phiên ở tầng native (activity có
// bị huỷ? có vết crash không?). Ai về trước quyết định; kẻ về sau bị bỏ qua —
// cùng bài học với `runOcrGuarded` (xem `ocr_cancel_token.dart`).
//
// File này THUẦN DART (không Flutter, không plugin) → test chạy trên host VM.

import 'dart:async';

/// Tín hiệu tầng native trả về cho một phiên quét đang chờ.
enum OcrScanSignal {
  /// Chưa có gì bất thường — cứ chờ tiếp.
  none,

  /// Activity/tiến trình bị hệ thống huỷ trong lúc máy quét đang mở.
  interrupted,

  /// Vết crash native ở lane quét đã được bắt (xem `ocr_native_bridge.dart`).
  nativeCrash,
}

/// Một lần hỏi trạng thái: tín hiệu + vết crash (nếu có).
class OcrScanSnapshot {
  final OcrScanSignal signal;

  /// Vết lỗi native (chỉ có khi [signal] == [OcrScanSignal.nativeCrash]).
  final String? crashTrace;

  const OcrScanSnapshot(this.signal, {this.crashTrace});

  /// Không có gì bất thường.
  static const OcrScanSnapshot idle = OcrScanSnapshot(OcrScanSignal.none);
}

/// Kết quả "chạy đua" của một phiên quét.
class OcrScanWatch<T> {
  final OcrScanSignal signal;
  final T? value;
  final String? crashTrace;

  const OcrScanWatch._(this.signal, this.value, this.crashTrace);

  /// Máy quét trả kết quả trước khi có tín hiệu bất thường.
  OcrScanWatch.completed(T value) : this._(OcrScanSignal.none, value, null);

  /// Bị cắt ngang bởi tín hiệu native — giá trị của máy quét (nếu về sau) bị bỏ.
  OcrScanWatch.aborted(OcrScanSignal signal, {String? crashTrace})
      : this._(signal, null, crashTrace);

  bool get isCompleted => signal == OcrScanSignal.none;
  bool get isInterrupted => signal == OcrScanSignal.interrupted;
  bool get isNativeCrash => signal == OcrScanSignal.nativeCrash;
  bool get isAborted => !isCompleted;
}

/// Nhịp hỏi mặc định. 800 ms: đủ nhanh để người dùng không thấy "đứng im",
/// đủ thưa để không spam MethodChannel trong lúc máy quét mở hàng phút.
const Duration kOcrScanPollInterval = Duration(milliseconds: 800);

/// Diễn giải một lỗi thô từ plugin máy quét thành thông báo có ích.
class OcrScanErrorInfo {
  /// Người dùng bấm huỷ trong máy quét — KHÔNG phải lỗi, không hiện gì.
  final bool isCancellation;

  /// Câu nguồn tiếng Việt (đã đăng ký catalog; UI dịch qua `uiText`).
  final String message;

  /// Lỗi thuộc nhóm "Play services thiếu/lỗi" → mời người dùng mở Play services.
  final bool suggestPlayServices;

  const OcrScanErrorInfo({
    required this.isCancellation,
    required this.message,
    this.suggestPlayServices = false,
  });
}

/// Ánh xạ lỗi của `google_mlkit_document_scanner` **0.5.0** → thông báo có ích.
///
/// Chuỗi lỗi native (đọc tại đúng commit release `f29f844` của plugin):
///   `result.error("DocumentScanner", "Operation cancelled")`
///   `result.error("DocumentScanner", "Failed to start document scanner")`
///   `result.error("DocumentScanner", "Invalid options")`
///   `result.error("DocumentScanner", "Unknown Error")`
/// → phía Dart là `PlatformException(code: 'DocumentScanner', message: …)`.
///
/// Vì sao phải phân biệt: trước đây cả bốn câu đều rơi vào một snackbar
/// `'Lỗi: …'` đỏ. "Operation cancelled" là người dùng bấm Back (không phải
/// lỗi), còn "Failed to start…" gần như luôn là Play services thiếu/cũ/không
/// tải được module (giả thuyết 1) — hai chuyện khác nhau, phải nói khác nhau.
OcrScanErrorInfo classifyOcrScannerError(Object error) {
  final text = error.toString();
  final isPlatformException = text.contains('PlatformException');
  final isDocumentScannerChannel = text.contains('DocumentScanner');
  final isMissingPlugin = text.contains('MissingPluginException');

  if (isDocumentScannerChannel && text.contains('Operation cancelled')) {
    return const OcrScanErrorInfo(
      isCancellation: true,
      message: '',
    );
  }

  if (isMissingPlugin) {
    return const OcrScanErrorInfo(
      isCancellation: false,
      message:
          'Bản cài này thiếu plugin máy quét tài liệu (ML Kit) — hãy cập nhật app hoặc chọn ảnh có sẵn.',
    );
  }

  if (isDocumentScannerChannel &&
      (text.contains('Failed to start document scanner') ||
          text.contains('Unknown Error'))) {
    return const OcrScanErrorInfo(
      isCancellation: false,
      message:
          'Không mở được máy quét tài liệu — thiếu hoặc lỗi Google Play services. Cài/cập nhật rồi thử lại.',
      suggestPlayServices: true,
    );
  }

  if (isDocumentScannerChannel && text.contains('Invalid options')) {
    return const OcrScanErrorInfo(
      isCancellation: false,
      message:
          'Cấu hình máy quét không hợp lệ — hãy chọn ảnh có sẵn thay thế.',
    );
  }

  return OcrScanErrorInfo(
    isCancellation: false,
    message:
        'Máy quét tài liệu gặp lỗi không mong đợi — hãy thử lại hoặc chọn ảnh có sẵn.',
    suggestPlayServices: isPlatformException,
  );
}

/// Chạy [scan] nhưng ngừng chờ ngay khi [poll] báo có sự cố.
///
/// Lỗi do [scan] ném ra vẫn được ném tiếp cho caller (OcrService bắt và chuyển
/// thành kết quả có thông báo) — trừ khi ta đã bỏ cuộc trước đó, khi ấy lỗi đến
/// muộn bị nuốt có chủ đích: không ai còn nghe nữa, và một unhandled error sau
/// khi UI đã đóng chỉ tạo crash giả.
///
/// `scan` KHÔNG có đường huỷ ở native; future của nó (nếu về muộn) bị bỏ đi —
/// đúng như `runOcrGuarded` làm với `TextRecognizer.processImage`.
Future<OcrScanWatch<T>> watchOcrScan<T>({
  required Future<T> Function() scan,
  required Future<OcrScanSnapshot> Function() poll,
  Duration interval = kOcrScanPollInterval,
}) {
  final completer = Completer<OcrScanWatch<T>>();
  Timer? timer;
  var polling = false;
  var stopped = false;

  void finish(OcrScanWatch<T> watch) {
    if (completer.isCompleted) return;
    if (stopped) return;
    stopped = true;
    timer?.cancel();
    completer.complete(watch);
  }

  timer = Timer.periodic(interval, (_) async {
    if (stopped || completer.isCompleted || polling) return;
    polling = true;
    try {
      final snapshot = await poll();
      if (!stopped && snapshot.signal != OcrScanSignal.none) {
        finish(
          OcrScanWatch<T>.aborted(
            snapshot.signal,
            crashTrace: snapshot.crashTrace,
          ),
        );
      }
    } catch (_) {
      // Kênh native hỏng giữa phiên (đúng lúc tiến trình bị huỷ) — im lặng
      // bỏ qua nhịp này, không được làm chết phiên quét vì lỗi chẩn đoán.
    } finally {
      polling = false;
    }
  });

  Future<T>(scan).then(
    (value) => finish(OcrScanWatch<T>.completed(value)),
    onError: (Object error, StackTrace stack) {
      if (completer.isCompleted || stopped) return; // đã bỏ cuộc — nuốt có chủ đích
      stopped = true;
      timer?.cancel();
      completer.completeError(error, stack);
    },
  );

  return completer.future;
}
