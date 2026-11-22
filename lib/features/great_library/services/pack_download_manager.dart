// lib/features/great_library/services/pack_download_manager.dart
//
// GLIB-002 — Thư Viện Chung I4U (PLAN-049, ADR-0031 D3/D5).
// Download manager cho pack `.i4upack`: hàng đợi tuần tự, resume theo
// byte-range, retry backoff, verify sha256 file sau khi tải.
//
// Thuần Dart: persistence qua [PackDownloadStore] trừu tượng (impl file thật
// bằng path_provider sẽ nối ở GLIB-004/005; test dùng in-memory store).
//
// Luồng resume:
//   partialLength == expectedBytes        → verify luôn
//   0 < partialLength < expectedBytes     → GET Range: bytes=offset- …
//     · server trả đúng phần còn lại      → ghép → verify
//     · server trả NGUYÊN file (bỏ range) → bỏ partial, dùng bản mới
//     · server trả thiếu (đứt giữa chừng) → lưu partial, retry sẽ resume tiếp
//   partialLength == 0                    → tải mới; thiếu byte → partial+retry
//
// Checksum sai sau khi đủ byte → xoá partial, tải lại từ đầu ở attempt sau;
// hết maxAttempts → failed (không giữ file rác — AT của card).

import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../models/pack_manifest.dart';
import 'pack_storage_backend.dart';

enum PackDownloadState { queued, downloading, verifying, completed, failed, canceled }

class PackDownloadProgress {
  const PackDownloadProgress({
    required this.state,
    required this.receivedBytes,
    required this.totalBytes,
  });

  final PackDownloadState state;
  final int receivedBytes;
  final int totalBytes;

  double get fraction =>
      totalBytes <= 0 ? 0 : receivedBytes / totalBytes.clamp(1, totalBytes);
}

class PackDownloadResult {
  const PackDownloadResult._(this.state, {this.errorCode, this.errorMessage});

  final PackDownloadState state;
  final PackStorageErrorCode? errorCode;
  final String? errorMessage;

  bool get isSuccess => state == PackDownloadState.completed;

  factory PackDownloadResult.completed() =>
      const PackDownloadResult._(PackDownloadState.completed);
  factory PackDownloadResult.canceled() =>
      const PackDownloadResult._(PackDownloadState.canceled);
  factory PackDownloadResult.failed(
          PackStorageErrorCode code, String message) =>
      PackDownloadResult._(PackDownloadState.failed,
          errorCode: code, errorMessage: message);
}

/// Token huỷ đơn giản: UI giữ instance và gọi [cancel].
class PackDownloadCancel {
  bool _canceled = false;
  bool get isCanceled => _canceled;
  void cancel() => _canceled = true;
}

/// Persistence trừu tượng cho file đang tải dở / đã xong.
abstract class PackDownloadStore {
  /// Số byte đã tải dở (0 = chưa có partial).
  Future<int> partialLength(String packId);
  Future<void> appendPartial(String packId, List<int> chunk);
  Future<Uint8List?> readPartial(String packId);
  Future<void> saveFinal(String packId, Uint8List bytes);
  Future<Uint8List?> readFinal(String packId);
  Future<void> clearPartial(String packId);
}

class PackDownloadManager {
  PackDownloadManager({
    required PackStorageBackend backend,
    required PackDownloadStore store,
    this.maxAttempts = 3,
    Duration Function(int attempt)? backoff,
    Future<void> Function(Duration)? sleeper,
  })  : _backend = backend,
        _store = store,
        _backoff = backoff ?? _defaultBackoff,
        _sleeper = sleeper ?? Future<void>.delayed;

  final PackStorageBackend _backend;
  final PackDownloadStore _store;
  final int maxAttempts;
  final Duration Function(int attempt) _backoff;
  final Future<void> Function(Duration) _sleeper;

  static Duration _defaultBackoff(int attempt) =>
      Duration(milliseconds: 200 * (1 << attempt));

  /// Chuỗi tuần tự: mọi lượt tải xếp sau lượt trước (P0 tải 1 pack/lần).
  Future<void>? _tail;

  /// Tải pack về store. Không ném — kết quả nằm trong [PackDownloadResult].
  Future<PackDownloadResult> downloadPack({
    required String packId,
    required PackStorageRef ref,
    required int expectedBytes,
    required String expectedFileSha256,
    void Function(PackDownloadProgress progress)? onProgress,
    PackDownloadCancel? cancelToken,
  }) {
    final run = (_tail ?? Future<void>.value()).then(
      (_) => _run(
        packId: packId,
        ref: ref,
        expectedBytes: expectedBytes,
        expectedFileSha256: expectedFileSha256,
        onProgress: onProgress,
        cancelToken: cancelToken,
      ),
    );
    // Không để lỗi lập trình của một lượt làm hỏng cả hàng đợi.
    _tail = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<PackDownloadResult> _run({
    required String packId,
    required PackStorageRef ref,
    required int expectedBytes,
    required String expectedFileSha256,
    void Function(PackDownloadProgress progress)? onProgress,
    PackDownloadCancel? cancelToken,
  }) async {
    void emit(PackDownloadState state, int received) => onProgress?.call(
        PackDownloadProgress(
            state: state, receivedBytes: received, totalBytes: expectedBytes));

    PackStorageException lastError = const PackStorageException(
        PackStorageErrorCode.unknown, 'chưa chạy attempt nào');

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (cancelToken?.isCanceled == true) {
        return PackDownloadResult.canceled();
      }
      if (attempt > 0) await _sleeper(_backoff(attempt - 1));

      try {
        var offset = await _store.partialLength(packId);
        if (offset > expectedBytes) {
          // Partial lớn hơn file đích: dữ liệu rác — xoá, tải lại từ đầu.
          await _store.clearPartial(packId);
          offset = 0;
        }

        Uint8List? complete;
        if (offset == expectedBytes) {
          complete = await _store.readPartial(packId);
          if (complete == null) offset = 0; // partial mất giữa chừng
        }

        if (complete == null) {
          emit(PackDownloadState.downloading, offset);
          final chunk = await _backend.download(
            ref,
            start: offset > 0 ? offset : null,
          );
          if (offset > 0) {
            if (chunk.length == expectedBytes) {
              // Server bỏ qua Range, trả nguyên file — dùng bản mới.
              await _store.clearPartial(packId);
              complete = chunk;
            } else if (chunk.length == expectedBytes - offset) {
              await _store.appendPartial(packId, chunk);
              complete = await _store.readPartial(packId);
            } else {
              // Đứt giữa chừng: lưu phần nhận được, attempt sau resume tiếp.
              if (chunk.isNotEmpty &&
                  chunk.length < expectedBytes - offset) {
                await _store.appendPartial(packId, chunk);
                emit(PackDownloadState.downloading,
                    await _store.partialLength(packId));
              }
              throw const PackStorageException(PackStorageErrorCode.network,
                  'short-body khi resume');
            }
          } else {
            if (chunk.length == expectedBytes) {
              complete = chunk;
            } else if (chunk.length < expectedBytes) {
              await _store.appendPartial(packId, chunk);
              emit(PackDownloadState.downloading,
                  await _store.partialLength(packId));
              throw const PackStorageException(PackStorageErrorCode.network,
                  'short-body: ${chunk.length}/$expectedBytes');
            } else {
              throw const PackStorageException(PackStorageErrorCode.unknown,
                  'server trả nhiều hơn dung lượng khai báo');
            }
          }
        }

        if (complete == null) {
          throw const PackStorageException(
              PackStorageErrorCode.network, 'không đọc được dữ liệu đã tải');
        }

        emit(PackDownloadState.verifying, expectedBytes);
        if (sha256.convert(complete).toString() != expectedFileSha256) {
          await _store.clearPartial(packId);
          lastError = const PackStorageException(
              PackStorageErrorCode.unknown, 'checksum mismatch');
          continue; // attempt sau tải lại từ đầu
        }
        await _store.saveFinal(packId, complete);
        await _store.clearPartial(packId);
        emit(PackDownloadState.completed, expectedBytes);
        return PackDownloadResult.completed();
      } on PackStorageException catch (e) {
        lastError = e;
        if (!e.retryable) {
          emit(PackDownloadState.failed, 0);
          return PackDownloadResult.failed(e.code, e.message);
        }
      } on Object catch (e) {
        lastError = PackStorageException(
            PackStorageErrorCode.network, 'lỗi không mong đợi: $e');
      }
    }

    emit(PackDownloadState.failed, 0);
    return PackDownloadResult.failed(lastError.code, lastError.message);
  }
}
