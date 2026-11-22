// lib/features/great_library/services/pack_storage_backend.dart
//
// GLIB-002 — Thư Viện Chung I4U (PLAN-049, ADR-0031 D3).
// Interface trừu tượng cho storage pluggable: backend đầu là Firebase Storage
// (firebase_pack_storage.dart); khi Firebase hết quota thêm Supabase
// (supabase_pack_storage.dart) mà không đụng code UI/catalog.
//
// Manifest/catalog ghi rõ `storage.backend` + `storage.path` ⇒ hai backend
// song hành, pack cũ không cần migrate khi đổi backend cho pack mới.
//
// Thuần Dart — test bằng fake backend (test/great_library/).

import 'dart:typed_data';

import '../models/pack_manifest.dart';

/// Mã lỗi ổn định cho tầng storage — DownloadManager quyết định retry theo đây.
enum PackStorageErrorCode {
  /// Object không tồn tại — không retry.
  notFound,

  /// Thiếu/sai quyền (upload chưa đăng nhập, rules chặn) — không retry.
  unauthorized,

  /// Lỗi mạng/timeout/5xx — retry được.
  network,

  /// Vượt quota storage — không retry, báo owner (cờ chuyển backend).
  quota,

  /// `PackStorageRef` rỗng/sai định dạng — lỗi lập trình, không retry.
  invalidRef,

  /// Lỗi không phân loại.
  unknown,
}

class PackStorageException implements Exception {
  const PackStorageException(this.code, this.message, {this.statusCode});

  final PackStorageErrorCode code;
  final String message;
  final int? statusCode;

  /// Có nên retry không (DownloadManager dùng).
  bool get retryable => code == PackStorageErrorCode.network;

  @override
  String toString() =>
      'PackStorageException($code${statusCode != null ? ', http $statusCode' : ''}): $message';
}

abstract class PackStorageBackend {
  /// Id ổn định ghi trong manifest/catalog: 'firebase' | 'supabase'.
  String get backendId;

  /// Tải (toàn bộ hoặc byte-range khi truyền [start]/[end], inclusive).
  ///
  /// Backend KHÔNG hỗ trợ range có quyền trả toàn bộ object — caller
  /// (PackDownloadManager) nhận biết qua độ dài và tự restart.
  Future<Uint8List> download(PackStorageRef ref, {int? start, int? end});

  /// Dung lượng object (byte) — phục vụ resume/progress.
  Future<int> contentLength(PackStorageRef ref);

  /// Upload nguyên object (pack ≤ 200 MB, uploadType=media là đủ).
  /// Cần quyền ghi theo rules của backend (contribute flow yêu cầu đăng nhập).
  Future<void> upload(
    PackStorageRef ref,
    List<int> bytes, {
    void Function(int sentBytes, int totalBytes)? onProgress,
  });

  /// URL đọc public (D5: tải pack published không cần đăng nhập).
  Uri publicUrl(PackStorageRef ref);
}
