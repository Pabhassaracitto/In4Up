// test/great_library/pack_storage_http_test.dart
//
// GLIB-008b — backend HTTPS tĩnh (GitHub Releases, không cần Blaze):
// URL ghép đúng, Range header, 404 → notFound, upload → unsupported;
// RoutingPackStorage dispatch theo ref.backend.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in4up/features/great_library/models/pack_manifest.dart';
import 'package:in4up/features/great_library/services/pack_storage_backend.dart';
import 'package:in4up/features/great_library/services/pack_storage_http.dart';

PackStorageRef _ref(String path, {String backend = 'https'}) =>
    PackStorageRef(backend: backend, path: path);

void main() {
  group('HttpPackStorage', () {
    test('download full: GET {baseUrl}/{path} → bytes', () async {
      String? seenUrl;
      final client = MockClient((req) async {
        seenUrl = req.url.toString();
        return http.Response.bytes(Uint8List.fromList([1, 2, 3]), 200);
      });
      final backend = HttpPackStorage(
          client: client, baseUrl: 'https://example.com/dl');
      final bytes = await backend.download(_ref('a.i4upack'));
      expect(bytes, [1, 2, 3]);
      expect(seenUrl, 'https://example.com/dl/a.i4upack');
    });

    test('download range: header bytes=start-end, 206 OK', () async {
      String? range;
      final client = MockClient((req) async {
        range = req.headers['Range'];
        return http.Response.bytes(Uint8List.fromList([9, 9]), 206);
      });
      final backend = HttpPackStorage(client: client);
      final bytes =
          await backend.download(_ref('a.i4upack'), start: 10, end: 20);
      expect(range, 'bytes=10-20');
      expect(bytes.length, 2);
    });

    test('404 → PackStorageException(notFound), không retry', () async {
      final client = MockClient((req) async => http.Response('nope', 404));
      final backend = HttpPackStorage(client: client);
      expect(
        () => backend.download(_ref('missing.i4upack')),
        throwsA(isA<PackStorageException>()
            .having((e) => e.code, 'code', PackStorageErrorCode.notFound)
            .having((e) => e.retryable, 'retryable', isFalse)),
      );
    });

    test('upload → ném upload-unsupported (read-only)', () {
      final backend = HttpPackStorage(client: MockClient((req) async => http.Response('', 200)));
      expect(
        () => backend.upload(_ref('a.i4upack'), [1]),
        throwsA(isA<PackStorageException>()
            .having((e) => e.message, 'message', contains('upload-unsupported'))),
      );
    });
  });

  group('RoutingPackStorage', () {
    test('dispatch theo ref.backend; backend lạ → lỗi không retry', () async {
      final httpBackend = HttpPackStorage(
        client: MockClient((req) async =>
            http.Response.bytes(Uint8List.fromList([7]), 200)),
        baseUrl: 'https://example.com/dl',
      );
      final routing = RoutingPackStorage(backends: {'https': httpBackend});
      expect(await routing.download(_ref('x.i4upack')), [7]);
      expect(
        () => routing.download(_ref('x.i4upack', backend: 'ftp')),
        throwsA(isA<PackStorageException>()
            .having((e) => e.message, 'message', contains('backend lạ'))),
      );
    });
  });
}
