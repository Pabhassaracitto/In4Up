// test/great_library/gl_catalog_transport_static_test.dart
//
// GLIB-008b — StaticGlCatalogTransport (catalog JSON từ GitHub Release) +
// CompositeGlCatalogTransport (static + Firestore, nguồn lỗi bị bỏ qua).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in4up/features/great_library/services/gl_catalog_service.dart';
import 'package:in4up/features/great_library/services/gl_catalog_transport_static.dart';

Map<String, dynamic> _doc(String id) => {
      'id': id,
      'type': 'vocab',
      'title': 'Pack $id',
      'description': 'd',
      'srcLang': 'en',
      'dstLang': 'vi',
      'tags': const <String>[],
      'level': 'A2',
      'author': const {'uid': 'seed-in4up', 'displayName': 'In4Up Seed'},
      'license': 'cc0',
      'version': 1,
      'sizeBytes': 100,
      'entryCount': 5,
      'stats': const {'downloads': 0, 'rating': 0, 'ratings': 0},
      'status': 'published',
      'storage': {'backend': 'https', 'path': '$id.i4upack'},
      'fileSha256': 'abc',
      'fileBytes': 200,
    };

void main() {
  test('static transport: parse JSON list → docs', () async {
    final client = MockClient((req) async => http.Response.bytes(
        utf8.encode(jsonEncode([_doc('p1'), _doc('p2')])), 200));
    final t = StaticGlCatalogTransport(client: client);
    final docs = await t.fetchPublishedPackDocs();
    expect(docs.length, 2);
    expect(docs.first['id'], 'p1');
  });

  test('static transport: http lỗi → GlCatalogException', () {
    final t = StaticGlCatalogTransport(
        client: MockClient((req) async => http.Response('x', 500)));
    expect(() => t.fetchPublishedPackDocs(),
        throwsA(isA<GlCatalogException>()));
  });

  test('composite: Firestore lỗi → vẫn trả static (P0 không cần rules)',
      () async {
    final staticT = StaticGlCatalogTransport(
        client: MockClient((req) async => http.Response.bytes(
            utf8.encode(jsonEncode([_doc('seed1')])), 200)));
    final composite = CompositeGlCatalogTransport([
      staticT,
      _FailingTransport(),
    ]);
    final docs = await composite.fetchPublishedPackDocs();
    expect(docs.single['id'], 'seed1');
  });

  test('composite: merge + trùng id thì nguồn sau (Firestore) thắng', () async {
    final staticT = StaticGlCatalogTransport(
        client: MockClient((req) async => http.Response.bytes(
            utf8.encode(jsonEncode([_doc('p1')])), 200)));
    final composite = CompositeGlCatalogTransport([
      staticT,
      _ListTransport([_doc('p1')..['title'] = 'Bản Firestore', _doc('p2')]),
    ]);
    final docs = await composite.fetchPublishedPackDocs();
    expect(docs.length, 2);
    final p1 = docs.firstWhere((d) => d['id'] == 'p1');
    expect(p1['title'], 'Bản Firestore');
  });

  test('composite: TẤT CẢ nguồn lỗi → ném lỗi', () {
    final composite = CompositeGlCatalogTransport(
        [_FailingTransport(), _FailingTransport()]);
    expect(() => composite.fetchPublishedPackDocs(), throwsA(anything));
  });
}

class _FailingTransport implements GlCatalogTransport {
  @override
  Future<List<Map<String, dynamic>>> fetchPublishedPackDocs() =>
      throw const GlCatalogException('rules chưa deploy');
}

class _ListTransport implements GlCatalogTransport {
  _ListTransport(this.docs);
  final List<Map<String, dynamic>> docs;
  @override
  Future<List<Map<String, dynamic>>> fetchPublishedPackDocs() async => docs;
}
