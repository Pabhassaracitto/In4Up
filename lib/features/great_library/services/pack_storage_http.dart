// lib/features/great_library/services/pack_storage_http.dart
//
// GLIB-008b — backend HTTPS tĩnh (read-only): pack đặt trên host public bất
// kỳ hỗ trợ Range (GitHub Releases, CDN…). Dùng khi Firebase Storage không
// khả dụng (project Spark không có thẻ tín dụng → không bật được Storage).
//
// URL = {baseUrl}/{path}; baseUrl mặc định trỏ GitHub Release `gl-seed-v1`
// của repo app (seed pack do CI build + upload — xem workflow
// glib_seed_release.yml). Upload KHÔNG hỗ trợ (read-only) → contribute flow
// báo rõ để user chia sẻ file thủ công cho owner.

import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/pack_manifest.dart';
import 'pack_storage_backend.dart';

class HttpPackStorage implements PackStorageBackend {
  HttpPackStorage({
    http.Client? client,
    this.baseUrl = kDefaultSeedBaseUrl,
    this.requestTimeout = const Duration(seconds: 30),
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null;

  /// Base URL của GitHub Release chứa seed pack (CI tạo — không cần billing).
  static const String kDefaultSeedBaseUrl =
      'https://github.com/Pabhassaracitto/In4Up/releases/download/gl-seed-v1';

  final http.Client _client;
  final bool _ownsClient;
  final String baseUrl;
  final Duration requestTimeout;

  @override
  String get backendId => 'https';

  Uri _uri(PackStorageRef ref) =>
      Uri.parse('$baseUrl/${ref.path}'.replaceAll('//', '/').replaceFirst(
          'https:/', 'https://'));

  @override
  Uri publicUrl(PackStorageRef ref) => _uri(ref);

  @override
  Future<Uint8List> download(PackStorageRef ref,
      {int? start, int? end}) async {
    final headers = <String, String>{};
    if (start != null || end != null) {
      headers['Range'] = 'bytes=${start ?? 0}-${end ?? ''}';
    }
    final http.Response response;
    try {
      response = await _client
          .get(_uri(ref), headers: headers)
          .timeout(requestTimeout);
    } on TimeoutException {
      throw const PackStorageException(
          PackStorageErrorCode.network, 'timeout tải pack');
    } on http.ClientException catch (e) {
      throw PackStorageException(
          PackStorageErrorCode.network, 'lỗi mạng: ${e.message}');
    }
    // 200 (full) hoặc 206 (partial) đều chấp nhận — DownloadManager tự kiểm
    // độ dài để quyết restart/resume.
    if (response.statusCode == 200 || response.statusCode == 206) {
      return response.bodyBytes;
    }
    if (response.statusCode == 404) {
      throw PackStorageException(
          PackStorageErrorCode.notFound, 'không thấy ${ref.path}',
          statusCode: 404);
    }
    throw PackStorageException(
        PackStorageErrorCode.network, 'http ${response.statusCode}',
        statusCode: response.statusCode);
  }

  @override
  Future<int> contentLength(PackStorageRef ref) async {
    final http.Response response;
    try {
      response = await _client
          .head(_uri(ref))
          .timeout(requestTimeout);
    } on Object {
      // HEAD fail → thử GET range 0-0 để đọc Content-Range.
      final probe = await download(ref, start: 0, end: 0);
      return probe.length; // server không Range → trả full, caller tự xử
    }
    if (response.statusCode != 200) {
      throw PackStorageException(
          PackStorageErrorCode.network, 'HEAD http ${response.statusCode}',
          statusCode: response.statusCode);
    }
    return int.tryParse(response.headers['content-length'] ?? '') ?? 0;
  }

  @override
  Future<void> upload(PackStorageRef ref, List<int> bytes,
      {void Function(int sentBytes, int totalBytes)? onProgress}) {
    throw const PackStorageException(PackStorageErrorCode.unknown,
        'upload-unsupported: backend HTTPS tĩnh chỉ đọc — chia sẻ file .i4upack trực tiếp cho owner');
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}

/// Định tuyến theo `PackStorageRef.backend` — catalog có thể trộn pack trên
/// GitHub Releases ('https') và Firebase Storage ('firebase', khi owner có
/// Blaze). Backend lạ → ném ngay (không retry vô ích).
class RoutingPackStorage implements PackStorageBackend {
  RoutingPackStorage({required Map<String, PackStorageBackend> backends})
      : _backends = backends;

  final Map<String, PackStorageBackend> _backends;

  PackStorageBackend _for(PackStorageRef ref) {
    final backend = _backends[ref.backend];
    if (backend == null) {
      throw PackStorageException(PackStorageErrorCode.unknown,
          'backend lạ: ${ref.backend}');
    }
    return backend;
  }

  @override
  String get backendId => 'routing';

  @override
  Future<Uint8List> download(PackStorageRef ref, {int? start, int? end}) =>
      _for(ref).download(ref, start: start, end: end);

  @override
  Future<int> contentLength(PackStorageRef ref) => _for(ref).contentLength(ref);

  @override
  Future<void> upload(PackStorageRef ref, List<int> bytes,
          {void Function(int sentBytes, int totalBytes)? onProgress}) =>
      _for(ref).upload(ref, bytes, onProgress: onProgress);

  @override
  Uri publicUrl(PackStorageRef ref) => _for(ref).publicUrl(ref);
}
