// test/great_library/pack_file_test.dart — GLIB-001 (PLAN-049)
//
// Test thuần cho PackFile: build → readManifest/extract round-trip, checksum
// payload/file, từ chối tên nguy hiểm & trùng lặp, quota kích thước.

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/great_library/models/pack_manifest.dart';
import 'package:in4up/features/great_library/services/pack_file.dart';

PackManifest baseManifest() => PackManifest(
      id: 'pack_test_0001',
      type: PackType.vocab,
      title: 'Pack test',
      srcLang: 'en',
      dstLang: 'vi',
      author: const PackAuthor(uid: 'tester', displayName: 'Tester'),
      license: PackLicense.selfMade,
    );

Map<String, List<int>> sampleData() => <String, List<int>>{
      'vocab.json': utf8.encode('[{"word":"run","meaning":"chạy"}]'),
    };

Map<String, List<int>> sampleMedia() => <String, List<int>>{
      'run.mp3': List<int>.filled(1024, 7),
      'run.jpg': List<int>.filled(2048, 3),
    };

void main() {
  group('PackFile.build → extract round-trip', () {
    test('build rồi extract trả lại đúng nội dung + manifest đã inject hash',
        () {
      final result = PackFile.build(
        manifest: baseManifest(),
        dataFiles: sampleData(),
        mediaFiles: sampleMedia(),
      );

      expect(result.manifest.payloadSha256, isNotNull);
      expect(result.manifest.payloadSha256, matches(RegExp(r'^[0-9a-f]{64}$')));
      // sizeBytes = tổng payload (không gồm overhead ZIP).
      final expectedPayload = sampleData()
              .values
              .fold<int>(0, (a, b) => a + b.length) +
          sampleMedia().values.fold<int>(0, (a, b) => a + b.length);
      expect(result.manifest.sizeBytes, expectedPayload);
      // entryCount tự suy ra khi caller không khai.
      expect(result.manifest.entryCount, 3);
      // fileSha256 khớp sha256 của đúng bytes trả về.
      expect(result.fileSha256, sha256.convert(result.bytes).toString());

      final contents = PackFile.extract(result.bytes);
      expect(contents.manifest.id, 'pack_test_0001');
      expect(utf8.decode(contents.dataFiles['vocab.json']!),
          '[{"word":"run","meaning":"chạy"}]');
      expect(contents.mediaFiles['run.mp3'], List<int>.filled(1024, 7));
      expect(contents.mediaFiles['run.jpg'], List<int>.filled(2048, 3));
    });

    test('readManifest chỉ cần bytes pack, không giải nén media', () {
      final result = PackFile.build(
        manifest: baseManifest(),
        dataFiles: sampleData(),
      );
      final manifest = PackFile.readManifest(result.bytes);
      expect(manifest.title, 'Pack test');
      expect(manifest.license, PackLicense.selfMade);
      expect(manifest.payloadSha256, result.manifest.payloadSha256);
    });

    test('manifest.validate pass sau build (hash đã inject hợp lệ)', () {
      final result = PackFile.build(
          manifest: baseManifest(),
          dataFiles: sampleData(),
          mediaFiles: sampleMedia());
      expect(result.manifest.validate(), isEmpty);
    });
  });

  group('PackFile.verify', () {
    test('pack nguyên vẹn → không lỗi', () {
      final result = PackFile.build(
          manifest: baseManifest(),
          dataFiles: sampleData(),
          mediaFiles: sampleMedia());
      expect(PackFile.verify(result.bytes), isEmpty);
      expect(
          PackFile.verify(result.bytes, expectedFileSha256: result.fileSha256),
          isEmpty);
    });

    test('fileSha256 kỳ vọng sai → file-sha256-mismatch', () {
      final result =
          PackFile.build(manifest: baseManifest(), dataFiles: sampleData());
      expect(
        PackFile.verify(result.bytes, expectedFileSha256: '0' * 64),
        contains('file-sha256-mismatch'),
      );
    });

    test('sửa 1 byte trong vùng nén → verify bắt được (corrupt hoặc mismatch)',
        () {
      final result = PackFile.build(
          manifest: baseManifest(),
          dataFiles: sampleData(),
          mediaFiles: sampleMedia());
      final tampered = Uint8List.fromList(result.bytes);
      tampered[tampered.length ~/ 2] ^= 0xFF;
      expect(PackFile.verify(tampered), isNotEmpty);
    });

    test('bytes rác hoàn toàn → corrupt-zip', () {
      final errors = PackFile.verify(utf8.encode('không phải zip'));
      expect(errors.single, startsWith('corrupt-zip'));
    });
  });

  group('PackFile.build — bảo vệ đầu vào', () {
    test('tên file chứa .. hoặc / đầu bị từ chối (chống zip-slip)', () {
      expect(
        () => PackFile.build(
            manifest: baseManifest(),
            dataFiles: <String, List<int>>{'../evil.json': const [1]}),
        throwsFormatException,
      );
      expect(
        () => PackFile.build(
            manifest: baseManifest(),
            mediaFiles: <String, List<int>>{'/abs.mp3': const [1]}),
        throwsFormatException,
      );
    });

    test('tên trùng giữa data/ và media/ bị từ chối', () {
      expect(
        () => PackFile.build(
          manifest: baseManifest(),
          dataFiles: <String, List<int>>{'a.bin': const [1]},
          mediaFiles: <String, List<int>>{'a.bin': const [2]},
        ),
        throwsFormatException,
      );
    });

    test('tên dành riêng manifest.json bị từ chối', () {
      expect(
        () => PackFile.build(
            manifest: baseManifest(),
            dataFiles: <String, List<int>>{'manifest.json': const [1]}),
        throwsFormatException,
      );
    });

    test('vượt quota payload → StateError', () {
      expect(
        () => PackFile.build(
          manifest: baseManifest(),
          mediaFiles: <String, List<int>>{
            'big.bin': List<int>.filled(64, 0),
          },
          maxPayloadBytes: 10,
        ),
        throwsStateError,
      );
    });

    test('manifest lỗi → FormatException kèm mã', () {
      final json = baseManifest().toJson()..['title'] = '';
      expect(
        () => PackFile.build(
            manifest: PackManifest.fromJson(json), dataFiles: sampleData()),
        throwsFormatException,
      );
    });
  });

  group('Tính ổn định của payloadSha256', () {
    test('cùng nội dung build 2 lần → payloadSha256 giống nhau', () {
      final a = PackFile.build(
          manifest: baseManifest(),
          dataFiles: sampleData(),
          mediaFiles: sampleMedia());
      final b = PackFile.build(
          manifest: baseManifest(),
          dataFiles: sampleData(),
          mediaFiles: sampleMedia());
      expect(a.manifest.payloadSha256, b.manifest.payloadSha256);
    });

    test('đổi nội dung 1 file → payloadSha256 đổi', () {
      final a = PackFile.build(
          manifest: baseManifest(), dataFiles: sampleData());
      final b = PackFile.build(manifest: baseManifest(), dataFiles: <String, List<int>>{
        'vocab.json': utf8.encode('[{"word":"walk","meaning":"đi bộ"}]'),
      });
      expect(a.manifest.payloadSha256, isNot(b.manifest.payloadSha256));
    });
  });
}
