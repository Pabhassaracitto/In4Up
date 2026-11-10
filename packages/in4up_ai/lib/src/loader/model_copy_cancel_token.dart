import 'dart:async';
import 'dart:io';

/// Cooperative cancellation for model transfers.
class ModelCopyCancelToken {
  final Completer<void> _cancelled = Completer<void>();

  bool get isCancelled => _cancelled.isCompleted;
  Future<void> get whenCancelled => _cancelled.future;

  void cancel() {
    if (!isCancelled) _cancelled.complete();
  }

  void throwIfCancelled() {
    if (isCancelled) throw const ModelCopyCancelledException();
  }
}

class ModelCopyCancelledException implements Exception {
  const ModelCopyCancelledException();
}

/// Copies to a new staging file; callers must never pass an existing model.
Future<void> copyFileWithProgress({
  required File src,
  required File dest,
  void Function(double progress)? onProgress,
  ModelCopyCancelToken? cancelToken,
}) async {
  cancelToken?.throwIfCancelled();
  final total = await src.length();
  cancelToken?.throwIfCancelled();
  RandomAccessFile? output;
  var copied = 0;
  var complete = false;
  var created = false;
  try {
    // Exclusive creation prevents truncating a pre-existing model.
    await dest.create(exclusive: true);
    created = true;
    output = await dest.open(mode: FileMode.write);
    await for (final chunk in src.openRead()) {
      cancelToken?.throwIfCancelled();
      await output.writeFrom(chunk);
      copied += chunk.length;
      if (total > 0) onProgress?.call(copied / total);
    }
    cancelToken?.throwIfCancelled();
    await output.close();
    output = null;
    cancelToken?.throwIfCancelled();
    complete = true;
    onProgress?.call(1.0);
  } finally {
    await output?.close();
    if (created && !complete && await dest.exists()) await dest.delete();
  }
}
