// lib/features/great_library/services/pack_storage_firebase.dart
//
// GLIB-002 — Thư Viện Chung I4U (PLAN-049, ADR-0031 D3).
// Backend Firebase Storage qua REST thuần (đúng quy ước app: không kéo SDK
// Storage nặng — giống FirestoreRestClient đi qua REST):
//   download: GET  /v0/b/{bucket}/o/{encodeComponent(path)}?alt=media (+Range)
//   metadata: GET  /v0/b/{bucket}/o/{encodeComponent(path)}
//   upload:   POST /upload/v0/b/{bucket}/o?uploadType=media&name={...}
// Auth: Bearer từ FirebaseRestAuth().getIdToken() — download pack published
// là public (D5) nên thiếu token vẫn GET thường; upload bắt buộc có token.
//
// Bucket mặc định lấy từ DefaultFirebaseOptions (storageBucket) — truyền
// `bucketOverride` trong test.

import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../firebase_options.dart';
import '../../../services/firebase_rest_auth.dart';
import '../models/pack_manifest.dart';
import 'pack_storage_backend.dart';

class FirebasePackStorage implements PackStorageBackend {
  FirebasePackStorage({
    http.Client? client,
    String? bucketOverride,
    Future<String?> Function()? idTokenProvider,
    this.requestTimeout = const Duration(seconds: 30),
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _bucket = bucketOverride,
        _idTokenProvider = idTokenProvider;

  final http.Client _client;
  final bool _ownsClient;
  final String? _bucket;
  final Future<String?> Function()? _idTokenProvider;
  final Duration requestTimeout;

  @override
  String get backendId => 'firebase';

  String get bucket =>
      _bucket ?? DefaultFirebaseOptions.currentPlatform.storageBucket;

  Uri _objectUri(PackStorageRef ref) => Uri.https(
        'firebasestorage.googleapis.com',
        '/v0/b/$bucket/o/${Uri.encodeComponent(ref.path)}',
      );

  Uri _uploadUri(PackStorageRef ref) => Uri.https(
        'firebasestorage.googleapis.com',
        '/upload/v0/b/$bucket/o',
        <String, String>{
          'uploadType': 'media',
          'name': ref.path,
        },
      );

  Future<String?> _token() =>
      _idTokenProvider != null
          ? _idTokenProvider!()
          : FirebaseRestAuth().getIdToken();

  void _assertValidRef(PackStorageRef ref) {
    if (ref.path.isEmpty || ref.path.contains('..')) {
      throw PackStorageException(
          PackStorageErrorCode.invalidRef, 'path rỗng hoặc chứa ".."');
    }
  }

  @override
  Uri publicUrl(PackStorageRef ref) => Uri.https(
        'firebasestorage.googleapis.com',
        '/v0/b/$bucket/o/${Uri.encodeComponent(ref.path)}',
        const <String, String>{'alt': 'media'},
      );

  @override
  Future<Uint8List> download(PackStorageRef ref, {int? start, int? end}) async {
    _assertValidRef(ref);
    final headers = <String, String>{};
    if (start != null || end != null) {
      headers['Range'] =
          'bytes=${start ?? 0}-${end != null ? '$end' : ''}';
    }
    // Download public: chỉ đính token khi đã có (tránh bắt đăng nhập — D5).
    final token = await _safeToken();
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final http.Response response;
    try {
      response = await _client
          .get(publicUrl(ref), headers: headers)
          .timeout(requestTimeout);
    } on TimeoutException {
      throw const PackStorageException(
          PackStorageErrorCode.network, 'timeout khi tải pack');
    } on http.ClientException catch (e) {
      throw PackStorageException(PackStorageErrorCode.network, e.message);
    }
    _throwForStatus(response.statusCode, 'download ${ref.path}');
    return response.bodyBytes;
  }

  @override
  Future<int> contentLength(PackStorageRef ref) async {
    _assertValidRef(ref);
    final token = await _safeToken();
    final headers = <String, String>{
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final http.Response response;
    try {
      response = await _client
          .get(_objectUri(ref), headers: headers)
          .timeout(requestTimeout);
    } on TimeoutException {
      throw const PackStorageException(
          PackStorageErrorCode.network, 'timeout khi đọc metadata');
    } on http.ClientException catch (e) {
      throw PackStorageException(PackStorageErrorCode.network, e.message);
    }
    _throwForStatus(response.statusCode, 'metadata ${ref.path}');
    final size = RegExp(r'"size"\s*:\s*"(\d+)"').firstMatch(response.body);
    if (size == null) {
      throw PackStorageException(PackStorageErrorCode.unknown,
          'metadata thiếu trường size: ${response.bodyBytes.length} bytes');
    }
    return int.parse(size.group(1)!);
  }

  @override
  Future<void> upload(
    PackStorageRef ref,
    List<int> bytes, {
    void Function(int sentBytes, int totalBytes)? onProgress,
  }) async {
    _assertValidRef(ref);
    final token = await _token();
    if (token == null) {
      throw const PackStorageException(PackStorageErrorCode.unauthorized,
          'upload cần đăng nhập (contribute flow)');
    }
    final http.Response response;
    try {
      response = await _client
          .post(
            _uploadUri(ref),
            headers: <String, String>{
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/zip',
            },
            body: bytes,
          )
          .timeout(requestTimeout);
    } on TimeoutException {
      throw const PackStorageException(
          PackStorageErrorCode.network, 'timeout khi upload pack');
    } on http.ClientException catch (e) {
      throw PackStorageException(PackStorageErrorCode.network, e.message);
    }
    _throwForStatus(response.statusCode, 'upload ${ref.path}');
    onProgress?.call(bytes.length, bytes.length);
  }

  Future<String?> _safeToken() async {
    try {
      return await _token();
    } on Object {
      return null; // download public không bắt buộc auth (D5)
    }
  }

  void _throwForStatus(int statusCode, String what) {
    if (statusCode >= 200 && statusCode < 300) return;
    if (statusCode == 404) {
      throw PackStorageException(
          PackStorageErrorCode.notFound, '$what: không tồn tại',
          statusCode: statusCode);
    }
    if (statusCode == 401 || statusCode == 403) {
      throw PackStorageException(
          PackStorageErrorCode.unauthorized, '$what: bị từ chối quyền',
          statusCode: statusCode);
    }
    if (statusCode == 413 || statusCode == 429) {
      throw PackStorageException(
          PackStorageErrorCode.quota, '$what: vượt quota',
          statusCode: statusCode);
    }
    if (statusCode >= 500) {
      throw PackStorageException(
          PackStorageErrorCode.network, '$what: lỗi server',
          statusCode: statusCode);
    }
    throw PackStorageException(
        PackStorageErrorCode.unknown, '$what: http $statusCode',
        statusCode: statusCode);
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
