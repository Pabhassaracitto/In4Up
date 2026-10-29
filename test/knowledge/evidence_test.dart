import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/knowledge/models/evidence.dart';

void main() {
  const producer = ProducerVersion(
    splitterVersion: 'split-1',
    extractorVersion: 'ext-1',
  );

  group('Evidence — schema mục 2.2', () {
    test('snapshotHash là SHA-256 chuẩn của excerpt (đối chiếu vector chuẩn)', () {
      final e = Evidence.record(
        unitId: 'u1',
        sourceType: EvidenceSourceType.pdf,
        sourceId: 'doc-1',
        locator: const EvidenceLocator(page: 3),
        excerpt: 'hello',
        producerVersion: producer,
        createdAt: DateTime.utc(2026, 1, 1),
      );

      // SHA-256("hello") — vector kiểm chứng công khai.
      expect(
        e.snapshotHash,
        '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824',
      );
    });

    test('verifyAgainst: khớp excerpt gốc ⇒ true; nguồn đã đổi ⇒ false', () {
      const originalText = 'The bank of the river was muddy.';
      final e = Evidence.record(
        unitId: 'u1',
        sourceType: EvidenceSourceType.web,
        sourceId: 'page-1',
        locator: const EvidenceLocator(url: 'https://example.com/story'),
        excerpt: originalText,
        producerVersion: producer,
        createdAt: DateTime.utc(2026, 1, 1),
      );

      expect(e.verifyAgainst(originalText), isTrue);
      // Trang web bị sửa nội dung ⇒ UI phải báo "Nguồn đã thay đổi":
      expect(e.verifyAgainst('The bank of the river was paved.'), isFalse);
    });

    test('locator PDF (page + rect + offset) round-trip', () {
      const locator = EvidenceLocator(
        page: 12,
        rect: LocatorRect(x: 0.1, y: 0.2, width: 0.3, height: 0.05),
        offset: 1520,
      );
      final clone = EvidenceLocator.fromJson(locator.toJson());

      expect(clone, equals(locator));
      // JSON chỉ chứa các key khác null:
      expect(locator.toJson().keys, unorderedEquals(['page', 'rect', 'offset']));
    });

    test('locator Web (url + scrollPercent) round-trip', () {
      const locator = EvidenceLocator(
        url: 'https://example.com/article',
        scrollPercent: 42.5,
      );
      final clone = EvidenceLocator.fromJson(locator.toJson());

      expect(clone, equals(locator));
      expect(locator.toJson().keys, unorderedEquals(['url', 'scrollPercent']));
    });

    test('locator Audio (timestampStart/End) round-trip', () {
      const locator = EvidenceLocator(timestampStart: 12.5, timestampEnd: 15.0);
      final clone = EvidenceLocator.fromJson(locator.toJson());

      expect(clone, equals(locator));
    });

    test('6 loại nguồn đều serialize/parse được', () {
      for (final type in EvidenceSourceType.values) {
        final e = Evidence.record(
          unitId: 'u1',
          sourceType: type,
          sourceId: 'src-${type.name}',
          locator: const EvidenceLocator(),
          excerpt: 'x',
          producerVersion: producer,
          createdAt: DateTime.utc(2026, 1, 1),
        );
        expect(Evidence.fromJson(e.toJson()).sourceType, equals(type));
      }
    });

    test('JSON round-trip đầy đủ mọi field', () {
      final e = Evidence.record(
        evidenceId: 'ev-1',
        unitId: 'u1',
        sourceType: EvidenceSourceType.youtube,
        sourceId: 'vid-9',
        locator: const EvidenceLocator(
          url: 'https://youtu.be/vid-9',
          timestampStart: 90.0,
          timestampEnd: 95.5,
        ),
        excerpt: 'a segment worth remembering',
        producerVersion: producer,
        createdAt: DateTime.utc(2026, 4, 1, 9, 15),
      );

      final clone = Evidence.fromJson(e.toJson());
      expect(clone.toJson(), equals(e.toJson()));
      expect(clone, equals(e));
    });

    test('copyWith(unitId) chỉ đổi unitId — phục vụ repoint khi merge', () {
      final e = Evidence.record(
        unitId: 'u-old',
        sourceType: EvidenceSourceType.text,
        sourceId: 'note-1',
        locator: const EvidenceLocator(offset: 10),
        excerpt: 'same excerpt',
        producerVersion: producer,
        createdAt: DateTime.utc(2026, 1, 1),
      );

      final repointed = e.copyWith(unitId: 'u-new');
      expect(repointed.unitId, 'u-new');
      expect(repointed.evidenceId, e.evidenceId);
      expect(repointed.excerpt, e.excerpt);
      expect(repointed.snapshotHash, e.snapshotHash);
      expect(repointed, isNot(equals(e)));
      expect(e.unitId, 'u-old', reason: 'bản gốc không đổi');
    });

    test('fromJson với sourceType lạ ⇒ FormatException', () {
      final json = <String, dynamic>{
        'evidenceId': 'ev-2',
        'unitId': 'u1',
        'sourceType': 'hologram',
        'sourceId': 's',
        'locator': <String, dynamic>{},
        'excerpt': 'x',
        'snapshotHash': '00',
        'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
        'producerVersion': producer.toJson(),
      };

      expect(() => Evidence.fromJson(json), throwsFormatException);
    });
  });
}
