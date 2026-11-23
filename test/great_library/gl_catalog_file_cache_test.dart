// test/great_library/gl_catalog_file_cache_test.dart
//
// GLIB-004b — GlCatalogFileCache: ghi/đọc snapshot ra đĩa, file hỏng → null,
// ghi đè an toàn (tmp + rename).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/great_library/services/gl_catalog_file_cache.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('gl_cache_test');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('chưa có file → null', () async {
    expect(await GlCatalogFileCache(dir).read(), isNull);
  });

  test('write → read round-trip', () async {
    final cache = GlCatalogFileCache(dir);
    await cache.write('{"fetchedAt":"x","entries":[]}');
    expect(await cache.read(), '{"fetchedAt":"x","entries":[]}');
  });

  test('write 2 lần → bản sau thắng', () async {
    final cache = GlCatalogFileCache(dir);
    await cache.write('v1');
    await cache.write('v2');
    expect(await cache.read(), 'v2');
  });

  test('file rác → đọc vẫn trả nguyên chuỗi (parse là việc của service)',
      () async {
    final cache = GlCatalogFileCache(dir);
    await File('${dir.path}/catalog_cache.json').writeAsString('not-json');
    expect(await cache.read(), 'not-json');
  });
}
