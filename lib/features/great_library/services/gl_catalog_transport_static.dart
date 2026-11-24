// lib/features/great_library/services/gl_catalog_transport_static.dart
//
// GLIB-008b — catalog tĩnh (read-only): tải `catalog_seed.json` (release
// asset GitHub, CI build kèm pack). Dùng khi Firestore rules chưa deploy /
// project không Blaze — app P0 đọc được seed catalog mà không cần Console.
//
// Mỗi entry trong JSON là doc gl_packs trải phẳng (khớp
// GlPackEntry.fromCatalogDoc).

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'gl_catalog_service.dart';
import 'pack_storage_http.dart';

class StaticGlCatalogTransport implements GlCatalogTransport {
  StaticGlCatalogTransport({
    http.Client? client,
    this.url = '${HttpPackStorage.kDefaultSeedBaseUrl}/catalog_seed.json',
    this.requestTimeout = const Duration(seconds: 20),
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  final String url;
  final Duration requestTimeout;

  @override
  Future<List<Map<String, dynamic>>> fetchPublishedPackDocs() async {
    final http.Response response;
    try {
      response =
          await _client.get(Uri.parse(url)).timeout(requestTimeout);
    } on TimeoutException {
      throw const GlCatalogException('timeout khi tải catalog tĩnh');
    } on http.ClientException catch (e) {
      throw GlCatalogException('lỗi mạng khi tải catalog tĩnh', cause: e);
    }
    if (response.statusCode != 200) {
      throw GlCatalogException('catalog tĩnh http ${response.statusCode}');
    }
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List) {
        throw const GlCatalogException('catalog tĩnh sai định dạng');
      }
      return decoded
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList(growable: false);
    } on FormatException {
      throw const GlCatalogException('catalog tĩnh sai định dạng');
    }
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}

/// Gộp nhiều nguồn catalog (static seed + Firestore khi rules đã deploy).
/// Nguồn lỗi bị bỏ qua — chỉ ném khi TẤT CẢ cùng lỗi. Trùng id: nguồn sau
/// ghi đè (Firestore thắng static khi cùng pack).
class CompositeGlCatalogTransport implements GlCatalogTransport {
  CompositeGlCatalogTransport(this._transports);

  final List<GlCatalogTransport> _transports;

  @override
  Future<List<Map<String, dynamic>>> fetchPublishedPackDocs() async {
    final byId = <String, Map<String, dynamic>>{};
    Object? lastError;
    var ok = 0;
    for (final t in _transports) {
      try {
        for (final doc in await t.fetchPublishedPackDocs()) {
          final id = (doc['id'] as String?) ?? '';
          if (id.isNotEmpty) byId[id] = doc;
        }
        ok++;
      } on Object catch (e) {
        lastError = e;
      }
    }
    if (ok == 0) {
      throw lastError ??
          const GlCatalogException('mọi nguồn catalog đều lỗi');
    }
    return byId.values.toList(growable: false);
  }
}
