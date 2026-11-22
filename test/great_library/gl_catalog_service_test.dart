// test/great_library/gl_catalog_service_test.dart — GLIB-003 (PLAN-049)
//
// Test thuần cho GlCatalogService + GlCatalogQuery + GlPackEntry:
//  - parse entry từ catalog doc (fields trải phẳng)
//  - cache TTL: fresh → không fetch; stale/force → fetch; lỗi mạng → cache cũ
//  - query filter (type/lang/level/tag/text) + sort (newest/downloads/rating)

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/great_library/models/gl_pack_entry.dart';
import 'package:in4up/features/great_library/models/pack_manifest.dart';
import 'package:in4up/features/great_library/services/gl_catalog_service.dart';

/// Transport giả: đếm số lần fetch, mô phỏng lỗi mạng.
class FakeTransport implements GlCatalogTransport {
  FakeTransport(this.docs);

  List<Map<String, dynamic>> docs;
  int fetchCalls = 0;
  bool throwOnFetch = false;

  @override
  Future<List<Map<String, dynamic>>> fetchPublishedPackDocs() async {
    fetchCalls++;
    if (throwOnFetch) {
      throw const GlCatalogException('mạng chập chờn (fake)');
    }
    return docs;
  }
}

Map<String, dynamic> docOf({
  required String id,
  String type = 'vocab',
  String srcLang = 'en',
  String dstLang = 'vi',
  String level = 'A2',
  List<String> tags = const ['verbs'],
  String title = 'Pack',
  String status = 'published',
  int downloads = 0,
  double rating = 0,
  int ratings = 0,
  String publishedAt = '2026-11-01T00:00:00.000Z',
  int version = 1,
}) {
  return <String, dynamic>{
    'schemaVersion': 1,
    'id': id,
    'type': type,
    'title': title,
    'description': 'mô tả $title',
    'srcLang': srcLang,
    'dstLang': dstLang,
    'tags': tags,
    'level': level,
    'author': <String, dynamic>{
      'uid': 'seed',
      'displayName': 'I4U Team',
      'verified': true,
    },
    'license': 'cc-by',
    'version': version,
    'status': status,
    'sizeBytes': 1000,
    'fileBytes': 1200,
    'fileSha256': 'a' * 64,
    'storage': <String, dynamic>{
      'backend': 'firebase',
      'path': 'packs/$id/$version.i4upack',
    },
    'stats': <String, dynamic>{
      'downloads': downloads,
      'rating': rating,
      'ratings': ratings,
    },
    'publishedAt': publishedAt,
  };
}

/// 3 entry mẫu khác nhau đủ chiều để test filter/sort.
List<Map<String, dynamic>> threeDocs() => <Map<String, dynamic>>[
      docOf(
          id: 'p_vocab',
          title: '500 động từ',
          downloads: 100,
          rating: 4.5,
          ratings: 20,
          publishedAt: '2026-11-10T00:00:00.000Z'),
      docOf(
          id: 'p_audio',
          type: 'audio',
          title: 'Truyện Grimm',
          level: 'B1',
          tags: const ['story'],
          downloads: 500,
          rating: 4.8,
          ratings: 50,
          publishedAt: '2026-11-12T00:00:00.000Z'),
      docOf(
          id: 'p_image',
          type: 'image',
          title: 'Đồ vật trong nhà',
          level: 'A1',
          tags: const ['house'],
          downloads: 30,
          rating: 3.9,
          ratings: 5,
          publishedAt: '2026-11-05T00:00:00.000Z'),
    ];

void main() {
  group('GlPackEntry parse', () {
    test('fromCatalogDoc: manifest phẳng + 3 field file tách đúng', () {
      final entry = GlPackEntry.fromCatalogDoc(docOf(id: 'p1'));
      expect(entry.packId, 'p1');
      expect(entry.manifest.type, PackType.vocab);
      expect(entry.manifest.license, PackLicense.ccBy);
      expect(entry.manifest.status, PackStatus.published);
      expect(entry.fileSha256, 'a' * 64);
      expect(entry.fileBytes, 1200);
      expect(entry.publishedAt, DateTime.parse('2026-11-01T00:00:00.000Z'));
      expect(entry.manifest.storage!.path, 'packs/p1/1.i4upack');
    });

    test('toJson → fromJson round-trip', () {
      final entry = GlPackEntry.fromCatalogDoc(docOf(id: 'p2'));
      final restored = GlPackEntry.fromJson(entry.toJson());
      expect(restored.packId, 'p2');
      expect(restored.manifest.toJson(), entry.manifest.toJson());
      expect(restored.fileBytes, entry.fileBytes);
      expect(restored.publishedAt, entry.publishedAt);
    });
  });

  group('GlCatalogService cache TTL', () {
    late DateTime now;
    GlCatalogService makeService(FakeTransport transport,
            {GlCatalogMemoryCache? cache}) =>
        GlCatalogService(
          transport: transport,
          cache: cache ?? GlCatalogMemoryCache(),
          ttl: const Duration(hours: 6),
          now: () => now,
        );

    setUp(() {
      now = DateTime.parse('2026-11-15T12:00:00.000Z');
    });

    test('lần đầu fetch → ghi cache; lần 2 trong TTL → không fetch lại',
        () async {
      final transport = FakeTransport(threeDocs());
      final cache = GlCatalogMemoryCache();
      final service = makeService(transport, cache: cache);

      final first = await service.getCatalog();
      expect(first, hasLength(3));
      expect(transport.fetchCalls, 1);

      final second = await service.getCatalog();
      expect(second, hasLength(3));
      expect(transport.fetchCalls, 1); // vẫn 1 — dùng cache
    });

    test('hết TTL → fetch lại; forceRefresh → fetch ngay cả khi fresh',
        () async {
      final transport = FakeTransport(threeDocs());
      final service = makeService(transport);

      await service.getCatalog();
      now = now.add(const Duration(hours: 7)); // quá TTL 6h
      await service.getCatalog();
      expect(transport.fetchCalls, 2);

      await service.getCatalog(forceRefresh: true);
      expect(transport.fetchCalls, 3);
    });

    test('fetch lỗi + có cache cũ → trả cache cũ (offline-first)', () async {
      final transport = FakeTransport(threeDocs());
      final service = makeService(transport);

      await service.getCatalog();
      now = now.add(const Duration(hours: 7));
      transport.throwOnFetch = true;

      final entries = await service.getCatalog();
      expect(entries, hasLength(3)); // cache cũ cứu
    });

    test('fetch lỗi + không cache → ném GlCatalogException', () async {
      final transport = FakeTransport(threeDocs())..throwOnFetch = true;
      final service = makeService(transport);

      await expectLater(service.getCatalog(), throwsA(isA<GlCatalogException>()));
    });

    test('cache hỏng (JSON rác) → coi như trống, fetch mới', () async {
      final cache = GlCatalogMemoryCache();
      await cache.write('{{{ rác');
      final transport = FakeTransport(threeDocs());
      final service = makeService(transport, cache: cache);

      final entries = await service.getCatalog();
      expect(entries, hasLength(3));
      expect(transport.fetchCalls, 1);
    });
  });

  group('GlCatalogQuery filter + sort', () {
    final entries =
        threeDocs().map(GlPackEntry.fromCatalogDoc).toList(growable: false);

    test('lọc theo type', () {
      final r = const GlCatalogQuery(type: PackType.audio).apply(entries);
      expect(r.single.packId, 'p_audio');
    });

    test('lọc theo level + tag', () {
      expect(
        const GlCatalogQuery(level: 'A1').apply(entries).single.packId,
        'p_image',
      );
      expect(
        const GlCatalogQuery(tag: 'STORY').apply(entries).single.packId,
        'p_audio',
      );
    });

    test('tìm text trong title (không phân biệt hoa thường)', () {
      final r = const GlCatalogQuery(text: 'grimm').apply(entries);
      expect(r.single.packId, 'p_audio');
      expect(const GlCatalogQuery(text: '  ').apply(entries), hasLength(3));
    });

    test('sort newest: publishedAt mới nhất lên đầu', () {
      final r = const GlCatalogQuery(sort: GlPackSort.newest).apply(entries);
      expect(r.map((e) => e.packId).toList(),
          ['p_audio', 'p_vocab', 'p_image']);
    });

    test('sort mostDownloaded + topRated', () {
      final byDl =
          const GlCatalogQuery(sort: GlPackSort.mostDownloaded).apply(entries);
      expect(byDl.first.packId, 'p_audio'); // 500 downloads

      final byRate =
          const GlCatalogQuery(sort: GlPackSort.topRated).apply(entries);
      expect(byRate.first.packId, 'p_audio'); // 4.8
      expect(byRate.last.packId, 'p_image'); // 3.9
    });

    test('kết hợp nhiều điều kiện', () {
      final r = const GlCatalogQuery(
        type: PackType.vocab,
        srcLang: 'en',
        dstLang: 'vi',
        text: 'động từ',
      ).apply(entries);
      expect(r.single.packId, 'p_vocab');
    });

    test('isEmpty nhận diện đúng query rỗng', () {
      expect(const GlCatalogQuery().isEmpty, isTrue);
      expect(const GlCatalogQuery(text: 'x').isEmpty, isFalse);
    });
  });
}
