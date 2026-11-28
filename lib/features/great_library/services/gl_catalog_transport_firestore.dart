// lib/features/great_library/services/gl_catalog_transport_firestore.dart
//
// GLIB-003 — Thư Viện Chung I4U (PLAN-049, ADR-0036 D2/D5).
// Transport thật: đọc `gl_packs` (status=published) qua Firestore REST
// **không bắt buộc đăng nhập** (D5) — rules cho read public pack published;
// token chỉ đính khi sẵn có (để admin còn đọc được cả pack ẩn sau này).
//
// Không dùng FirestoreRestClient._get vì đường đó BẮT BUỘC idToken (client đó
// sinh ra cho sync cá nhân). Ở đây chỉ tái dùng `decodeFields` (public) của
// FirestoreRestClient để giải mã value Firestore → Dart.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../services/firebase_rest_auth.dart';
import '../../../services/firestore_rest_client.dart';
import 'gl_catalog_service.dart';

class FirestoreGlCatalogTransport implements GlCatalogTransport {
  FirestoreGlCatalogTransport({
    http.Client? client,
    String? projectIdOverride,
    Future<String?> Function()? idTokenProvider,
    this.requestTimeout = const Duration(seconds: 20),
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _projectIdOverride = projectIdOverride,
        _idTokenProvider = idTokenProvider;

  final http.Client _client;
  final bool _ownsClient;
  final String? _projectIdOverride;
  final Future<String?> Function()? _idTokenProvider;
  final Duration requestTimeout;

  String get _projectId =>
      _projectIdOverride ?? FirestoreRestClient().projectId;

  Uri get _runQueryUri => Uri.https(
        'firestore.googleapis.com',
        '/v1/projects/$_projectId/databases/(default)/documents:runQuery',
      );

  @override
  Future<List<Map<String, dynamic>>> fetchPublishedPackDocs() async {
    // where status == 'published' — BẮT BUỘC để rules `allow read: if
    // resource.data.status == 'published'` chấp nhận LIST (Firestore yêu cầu
    // query chỉ chạm doc đọc được).
    final body = <String, dynamic>{
      'parent': 'projects/$_projectId/databases/(default)/documents',
      'structuredQuery': <String, dynamic>{
        'from': <Map<String, dynamic>>[
          <String, dynamic>{'collectionId': 'gl_packs'},
        ],
        'where': <String, dynamic>{
          'fieldFilter': <String, dynamic>{
            'field': <String, dynamic>{'fieldPath': 'status'},
            'op': 'EQUAL',
            'value': <String, dynamic>{'stringValue': 'published'},
          },
        },
      },
    };

    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = await _safeToken();
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final http.Response response;
    try {
      response = await _client
          .post(_runQueryUri, headers: headers, body: jsonEncode(body))
          .timeout(requestTimeout);
    } on TimeoutException {
      throw const GlCatalogException('timeout khi tải catalog');
    } on http.ClientException catch (e) {
      throw GlCatalogException('lỗi mạng khi tải catalog', cause: e);
    }
    if (response.statusCode != 200) {
      throw GlCatalogException(
          'Firestore http ${response.statusCode} khi tải catalog',
          cause: response.body);
    }

    final List<dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as List<dynamic>;
    } on Object {
      throw GlCatalogException('catalog response không phải JSON list',
          cause: response.body);
    }

    final decoder = FirestoreRestClient(); // chỉ mượn decodeFields (pure)
    final result = <Map<String, dynamic>>[];
    for (final item in decoded) {
      final doc = (item as Map<String, dynamic>)['document'];
      if (doc is! Map<String, dynamic>) continue;
      final fields = doc['fields'] as Map<String, dynamic>?;
      if (fields == null) continue;
      result.add(decoder.decodeFields(fields));
    }
    return result;
  }

  Future<String?> _safeToken() async {
    try {
      final provider = _idTokenProvider;
      if (provider != null) return await provider();
      return await FirebaseRestAuth().getIdToken();
    } on Object {
      return null; // public read không cần token (D5)
    }
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
