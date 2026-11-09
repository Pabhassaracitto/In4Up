// packages/in4up_ai/lib/src/loader/model_copy_cancel_token.dart
//
// PSRC-23 — Token huỷ copy/download model (logic thuần, không plugin).
//
// Tách riêng để test được mà không cần path_provider/FilePicker:
// test chỉ import file này + dart:io (temp dir), không đụng plugin.

import 'dart:io';

/// Token huỷ copy/download model — `cancel()` từ UI (nút Huỷ) hoặc facade
/// dispose. `cancel()` idempotent: gọi 2 lần không ném exception.
/// Kiểm tra giữa các chunk copy/download (không đọc cả file 2GB vào RAM).
class ModelCopyCancelToken {
  bool _cancelled = false;

  /// True sau khi [cancel] được gọi.
  bool get isCancelled => _cancelled;

  /// Huỷ copy/download đang chạy. Gọi 2 lần vẫn an toàn (no-op lần 2).
  void cancel() {
    _cancelled = true;
  }

  /// Ném [ModelCopyCancelledException] nếu đã bị huỷ — gọi giữa các chunk.
  void throwIfCancelled() {
    if (_cancelled) throw const ModelCopyCancelledException();
  }
}

/// Lỗi huỷ copy/download do người dùng bấm Huỷ (không phải lỗi kỹ thuật).
class ModelCopyCancelledException implements Exception {
  const ModelCopyCancelledException();

  @override
  String toString() => 'Model copy cancelled by user';
}

/// Copy file theo chunk kèm tiến độ + kiểm tra huỷ giữa các chunk.
///
/// Dùng chung cho import model (.gguf 1–2GB): copy theo stream chunk
/// (không đọc cả file vào RAM). Khi [cancelToken] bị huỷ giữa chừng:
/// đóng sink, XOÁ file đích dở dang (không để lại .gguf cụt khiến engine
/// báo "model hỏng"), rồi ném [ModelCopyCancelledException].
Future<void> copyFileWithProgress({
  required File src,
  required File dest,
  void Function(double progress)? onProgress,
  ModelCopyCancelToken? cancelToken,
}) async {
  final total = await src.length();
  var copied = 0;
  final sink = dest.openWrite();
  var cancelled = false;
  try {
    await for (final chunk in src.openRead()) {
      if (cancelToken?.isCancelled == true) {
        cancelled = true;
        break;
      }
      sink.add(chunk);
      copied += chunk.length;
      if (total > 0) onProgress?.call(copied / total);
    }
    if (!cancelled) cancelToken?.throwIfCancelled();
  } finally {
    await sink.close();
  }
  if (cancelled) {
    try {
      if (await dest.exists()) await dest.delete();
    } catch (_) {}
    throw const ModelCopyCancelledException();
  }
  onProgress?.call(1.0);
}
