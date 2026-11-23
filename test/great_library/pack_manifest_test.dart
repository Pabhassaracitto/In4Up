// test/great_library/pack_manifest_test.dart — GLIB-001 (PLAN-049)
//
// Test thuần cho PackManifest: JSON round-trip, validate() mã lỗi ổn định,
// enum append-only parse, schemaVersion từ tương lai bị từ chối.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/great_library/models/pack_manifest.dart';

PackManifest validManifest() => PackManifest(
      id: 'pack_seed_0001',
      type: PackType.vocab,
      title: '500 động từ thông dụng nhất',
      description: 'Bộ động từ A1–B1 kèm audio TTS.',
      srcLang: 'en',
      dstLang: 'vi',
      tags: const ['verbs', 'cefr-a2'],
      level: 'A2',
      author: const PackAuthor(uid: 'seed', displayName: 'I4U Team'),
      license: PackLicense.ccBy,
      version: 1,
      sizeBytes: 12345,
      entryCount: 500,
      status: PackStatus.published,
      storage: const PackStorageRef(
          backend: 'firebase', path: 'packs/pack_seed_0001/1.i4upack'),
      createdAt: DateTime.utc(2026, 11, 15),
      updatedAt: DateTime.utc(2026, 11, 15),
    );

void main() {
  group('PackManifest JSON round-trip', () {
    test('toJson → fromJson giữ nguyên mọi trường', () {
      final manifest = validManifest();
      final restored = PackManifest.fromJson(manifest.toJson());
      expect(restored.id, manifest.id);
      expect(restored.type, PackType.vocab);
      expect(restored.title, manifest.title);
      expect(restored.srcLang, 'en');
      expect(restored.dstLang, 'vi');
      expect(restored.tags, ['verbs', 'cefr-a2']);
      expect(restored.level, 'A2');
      expect(restored.author.displayName, 'I4U Team');
      expect(restored.author.verified, isFalse);
      expect(restored.license, PackLicense.ccBy);
      expect(restored.version, 1);
      expect(restored.sizeBytes, 12345);
      expect(restored.entryCount, 500);
      expect(restored.status, PackStatus.published);
      expect(restored.storage!.backend, 'firebase');
      expect(restored.storage!.path, endsWith('1.i4upack'));
      expect(restored.createdAt, DateTime.utc(2026, 11, 15));
    });

    test('toJsonString/fromJsonString tương đương', () {
      final manifest = validManifest();
      final restored = PackManifest.fromJsonString(manifest.toJsonString());
      expect(restored.toJson(), manifest.toJson());
    });

    test('trường tuỳ chọn vắng mặt → default an toàn', () {
      final restored = PackManifest.fromJson(const {
        'id': 'p1',
        'type': 'audio',
        'title': 'Audio pack',
        'license': 'cc0',
      });
      expect(restored.tags, isEmpty);
      expect(restored.level, 'mixed');
      expect(restored.status, PackStatus.pending);
      expect(restored.storage, isNull);
      expect(restored.stats.downloads, 0);
      expect(restored.schemaVersion, 1);
    });
  });

  group('PackManifest.validate', () {
    test('manifest hợp lệ → không lỗi', () {
      expect(validManifest().validate(), isEmpty);
      expect(validManifest().isValid, isTrue);
    });

    test('thiếu type/license → mã lỗi tương ứng', () {
      final json = validManifest().toJson()
        ..['type'] = 'khong-ton-tai'
        ..['license'] = null;
      final manifest = PackManifest.fromJson(json);
      final errors = manifest.validate();
      expect(errors, contains('type-missing-or-unknown'));
      expect(errors, contains('license-missing-or-unknown'));
    });

    test('title rỗng / quá dài', () {
      final json = validManifest().toJson()..['title'] = '  ';
      expect(PackManifest.fromJson(json).validate(), contains('title-empty'));
      final longJson = validManifest().toJson()
        ..['title'] = 'a' * (kMaxPackTitleLength + 1);
      final errors = PackManifest.fromJson(longJson).validate();
      print('TITLE-TEST errors=$errors'); // CI chặn blob log — đọc qua annotation
      expect(errors, contains('title-too-long'));
    });

    test('version < 1 và size âm bị bắt', () {
      final json = validManifest().toJson()
        ..['version'] = 0
        ..['sizeBytes'] = -5;
      final errors = PackManifest.fromJson(json).validate();
      expect(errors, contains('version-invalid'));
      expect(errors, contains('size-negative'));
    });

    test('payloadSha256 sai định dạng bị bắt; đúng 64 hex thì qua', () {
      final bad = validManifest().copyWith(payloadSha256: 'xyz');
      expect(bad.validate(), contains('payload-sha256-invalid'));
      final ok = validManifest().copyWith(
          payloadSha256: 'a' * 64);
      expect(ok.validate(), isNot(contains('payload-sha256-invalid')));
    });

    test('schemaVersion tương lai → schema-unsupported', () {
      final json = validManifest().toJson()
        ..['schemaVersion'] = kPackSchemaVersion + 1;
      expect(PackManifest.fromJson(json).validate(),
          contains('schema-unsupported'));
    });

    test('level ngoài tập CEFR bị bắt', () {
      final json = validManifest().toJson()..['level'] = 'A0';
      expect(PackManifest.fromJson(json).validate(), contains('level-invalid'));
    });

    test('storage thiếu backend/path bị bắt', () {
      final manifest = validManifest()
          .copyWith(storage: const PackStorageRef(backend: '', path: ''));
      expect(manifest.validate(), contains('storage-invalid'));
    });

    test('id chứa ký tự lạ bị bắt', () {
      final json = validManifest().toJson()..['id'] = 'p/../etc';
      expect(PackManifest.fromJson(json).validate(),
          contains('id-invalid-chars'));
    });
  });

  group('Enum append-only wire values', () {
    test('PackType parse đủ 3 giá trị hiện có', () {
      expect(PackType.tryParse('vocab'), PackType.vocab);
      expect(PackType.tryParse('audio'), PackType.audio);
      expect(PackType.tryParse('image'), PackType.image);
      expect(PackType.tryParse('video'), isNull);
      expect(PackType.tryParse(null), isNull);
    });

    test('PackLicense wire values ổn định', () {
      expect(PackLicense.cc0.wire, 'cc0');
      expect(PackLicense.ccBy.wire, 'cc-by');
      expect(PackLicense.ccByNc.wire, 'cc-by-nc');
      expect(PackLicense.selfMade.wire, 'self-made');
      expect(PackLicense.permissionGranted.wire, 'permission-granted');
    });

    test('PackStatus round-trip', () {
      for (final status in PackStatus.values) {
        expect(PackStatus.tryParse(status.wire), status);
      }
      expect(PackStatus.tryParse('deleted'), isNull);
    });
  });
}
