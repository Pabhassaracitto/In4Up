// test/audio_import_service_test.dart
// SHADOW-FILE-001 — persistent audio import:
//  - copy vào audio_imports/ khi path nằm trong cache (volatile)
//  - dedup an toàn: cùng nội dung → reuse; khác nội dung cùng tên → đổi tên,
//    KHÔNG ghi đè; không xóa dữ liệu cũ
//  - path stable (desktop/Music…) thì giữ nguyên, không nhân đôi bộ nhớ
//  - findImportedMatch: khôi phục path cache chết khi đúng 1 file trùng tên
//
// Lưu ý môi trường: sandbox "cache" đặt dưới Directory.systemTemp (Linux = /tmp
// → mọi path bên trong là volatile, hợp cho các test copy). Sandbox "stable"
// đặt dưới Directory.current (workspace, không chứa marker cache/temp) để kiểm
// logic giữ nguyên path ổn định.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/services/audio_import_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory cacheSandbox; // volatile (system temp, có /tmp/ trong path)
  late Directory stableSandbox; // non-volatile (workspace, không marker)
  late Directory docsDir;
  late AudioImportService service;

  Directory sub(Directory base, String name) {
    final dir = Directory(p.join(base.path, name));
    dir.createSync(recursive: true);
    return dir;
  }

  File writeFile(Directory dir, String name, List<int> bytes) {
    final file = File(p.join(dir.path, name));
    file.writeAsBytesSync(bytes, flush: true);
    return file;
  }

  List<int> bytesOf(int seed, int length) =>
      List<int>.generate(length, (i) => (seed + i) % 251);

  setUp(() {
    cacheSandbox = Directory.systemTemp.createTempSync('audio_import_cache_');
    stableSandbox = Directory(p.join(
      Directory.current.path,
      '.test_tmp_audio_import_${DateTime.now().microsecondsSinceEpoch}',
    ));
    stableSandbox.createSync(recursive: true);
    docsDir = sub(cacheSandbox, 'docs');
    service = AudioImportService(appDocumentsDirOverride: () async => docsDir);
  });

  tearDown(() {
    try {
      cacheSandbox.deleteSync(recursive: true);
    } catch (_) {}
    try {
      stableSandbox.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('isVolatilePath', () {
    test('Android file_picker cache là volatile', () {
      expect(
        AudioImportService.isVolatilePath(
          '/data/user/0/com.in4up.beta/cache/file_picker/1788698176215/Out.m4a',
        ),
        isTrue,
      );
    });

    test('thư mục Music/Documents không volatile', () {
      expect(
        AudioImportService.isVolatilePath('/storage/emulated/0/Music/a.mp3'),
        isFalse,
      );
      expect(
        AudioImportService.isVolatilePath('/home/user/Documents/a.mp3'),
        isFalse,
      );
    });

    test('audio_imports (persistent) không volatile', () {
      expect(
        AudioImportService.isVolatilePath(
          '/data/user/0/com.in4up.beta/app_flutter/audio_imports/a.m4a',
        ),
        isFalse,
      );
    });

    test('Windows temp volatile; content:// không tính path', () {
      expect(
        AudioImportService.isVolatilePath(
          r'C:\Users\me\AppData\Local\Temp\pick.mp3',
        ),
        isTrue,
      );
      expect(
        AudioImportService.isVolatilePath(
          'content://media/external/audio/media/1',
        ),
        isFalse,
      );
    });
  });

  group('ensurePersistent', () {
    test('copy file từ cache vào audio_imports/, giữ đúng tên gốc', () async {
      final cacheDir = sub(cacheSandbox, 'cache/file_picker/111');
      final src =
          writeFile(cacheDir, 'Out & about - poem.m4a', bytesOf(7, 50 * 1024));

      final res = await service.ensurePersistent(
        sourcePath: src.path,
        displayName: 'Out & about - poem.m4a',
      );

      final expectedDir = p.join(docsDir.path, 'audio_imports');
      expect(p.dirname(res.path), expectedDir);
      expect(p.basename(res.path), 'Out & about - poem.m4a');
      expect(res.importedIntoLibrary, isTrue);
      expect(res.reusedExisting, isFalse);
      expect(res.sizeBytes, 50 * 1024);
      expect(await File(res.path).readAsBytes(), await src.readAsBytes());
    });

    test('chọn lại đúng file (cùng size+nội dung) → reuse, không nhân đôi',
        () async {
      final cacheDir = sub(cacheSandbox, 'cache/file_picker/222');
      writeFile(cacheDir, 'song.mp3', bytesOf(3, 100 * 1024));

      // Lần pick 1 (path cache timestamp 222).
      final first = await service.ensurePersistent(
          sourcePath: p.join(cacheDir.path, 'song.mp3'));

      // Lần pick 2 từ cache mới (timestamp khác — giả lập restart).
      final cacheDir2 = sub(cacheSandbox, 'cache/file_picker/333');
      writeFile(cacheDir2, 'song.mp3', bytesOf(3, 100 * 1024));
      final second = await service.ensurePersistent(
          sourcePath: p.join(cacheDir2.path, 'song.mp3'));

      expect(second.path, first.path);
      expect(second.reusedExisting, isTrue);
      expect(second.identity, first.identity);

      final imports =
          Directory(p.join(docsDir.path, 'audio_imports')).listSync();
      expect(imports.whereType<File>(), hasLength(1));
    });

    test('KHÁC nội dung nhưng trùng tên → đổi tên, KHÔNG ghi đè file cũ',
        () async {
      final cacheDir = sub(cacheSandbox, 'cache/file_picker/444');
      final a = writeFile(cacheDir, 'lesson.m4a', bytesOf(1, 4096));
      final first = await service.ensurePersistent(sourcePath: a.path);

      final cacheDir2 = sub(cacheSandbox, 'cache/file_picker/555');
      final b = writeFile(cacheDir2, 'lesson.m4a', bytesOf(99, 4096));
      final second = await service.ensurePersistent(sourcePath: b.path);

      expect(second.path, isNot(first.path));
      expect(p.basename(second.path), 'lesson (2).m4a');
      // File cũ còn nguyên nội dung (không bị ghi đè/xóa).
      expect(await File(first.path).readAsBytes(), await a.readAsBytes());
      expect(await File(second.path).readAsBytes(), await b.readAsBytes());
      final imports = Directory(p.join(docsDir.path, 'audio_imports'))
          .listSync()
          .whereType<File>()
          .toList();
      expect(imports, hasLength(2));
    });

    test('identity ổn định qua các lần import cùng nội dung', () async {
      final d1 = sub(cacheSandbox, 'cache/x1');
      final d2 = sub(cacheSandbox, 'cache/x2');
      final f1 = writeFile(d1, 't.mp3', bytesOf(42, 8200));
      final f2 = writeFile(d2, 't.mp3', bytesOf(42, 8200));
      final r1 = await service.ensurePersistent(sourcePath: f1.path);
      final r2 = await service.ensurePersistent(sourcePath: f2.path);
      expect(r1.identity, r2.identity);
    });

    test('file ở vị trí ổn định (Music) → giữ path gốc, không copy', () async {
      final musicDir = sub(stableSandbox, 'Music');
      final song = writeFile(musicDir, 'song.mp3', bytesOf(5, 2048));

      final res = await service.ensurePersistent(sourcePath: song.path);

      expect(res.path, song.path);
      expect(res.importedIntoLibrary, isFalse);
      expect(Directory(p.join(docsDir.path, 'audio_imports')).existsSync(),
          isFalse);
    });

    test('đã nằm trong audio_imports/ → idempotent, không copy lại', () async {
      final importsDir = sub(docsDir, 'audio_imports');
      final kept = writeFile(importsDir, 'kept.mp3', bytesOf(8, 1024));

      final res = await service.ensurePersistent(sourcePath: kept.path);

      expect(res.path, kept.path);
      expect(res.reusedExisting, isFalse);
      expect(res.importedIntoLibrary, isFalse);
    });

    test('nguồn không tồn tại (cache đã bị dọn) → ném exception rõ ràng',
        () async {
      final ghost = p.join(
          cacheSandbox.path, 'cache', 'file_picker', '999', 'ghost.m4a');
      expect(
        () => service.ensurePersistent(sourcePath: ghost),
        throwsA(isA<AudioImportException>()),
      );
    });

    test('tên file có ký tự cấm được sanitize nhưng giữ unicode/dấu', () async {
      final cacheDir = sub(cacheSandbox, 'cache/pick');
      final src = writeFile(cacheDir, 'bai_tho.m4a', bytesOf(11, 1500));

      final res = await service.ensurePersistent(
        sourcePath: src.path,
        displayName: 'Bài thơ: mùa thu?.m4a',
      );

      // ':' và '?' bị thay bằng khoảng trắng, phần còn lại giữ nguyên.
      expect(p.basename(res.path), 'Bài thơ mùa thu .m4a');
      expect(await File(res.path).exists(), isTrue);
    });
  });

  group('findImportedMatch — khôi phục path cache chết', () {
    test('đúng 1 file trùng basename → trả path persistent', () async {
      final importsDir = sub(docsDir, 'audio_imports');
      writeFile(importsDir, 'poem.m4a', bytesOf(1, 512));

      final hit = await service.findImportedMatch(
        '/data/user/0/x/cache/file_picker/111/poem.m4a',
      );
      expect(hit, p.join(importsDir.path, 'poem.m4a'));
    });

    test('basename khác đuôi (2) vẫn tính riêng; trùng case-insensitive nhiều '
        'file → mơ hồ → null', () async {
      final importsDir = sub(docsDir, 'audio_imports');
      writeFile(importsDir, 'lesson.mp3', bytesOf(1, 256));
      writeFile(importsDir, 'lesson (2).mp3', bytesOf(1, 256));

      // 'lesson.mp3' chỉ khớp 1 file ('lesson (2).mp3' khác basename).
      final hit1 = await service.findImportedMatch('/cache/ab/lesson.mp3');
      expect(hit1, isNotNull);

      writeFile(importsDir, 'poem.m4a', bytesOf(1, 256));
      writeFile(importsDir, 'Poem.M4A', bytesOf(2, 256));
      // so khớp case-insensitive → 2 kết quả → mơ hồ → null, không đoán bừa.
      final hit2 = await service.findImportedMatch('/cache/ab/poem.m4a');
      expect(hit2, isNull);
    });

    test('không có file nào → null', () async {
      sub(docsDir, 'audio_imports');
      final hit = await service.findImportedMatch('/cache/ab/missing.m4a');
      expect(hit, isNull);
    });
  });

  group('sanitizeFileName', () {
    test('giữ tên thường, thay ký tự cấm, không rỗng', () {
      expect(AudioImportService.sanitizeFileName('a b.mp3'), 'a b.mp3');
      expect(
        AudioImportService.sanitizeFileName('a/b\\c:d.mp3'),
        'a b c d.mp3',
      );
      expect(AudioImportService.sanitizeFileName(''), 'audio');
      expect(AudioImportService.sanitizeFileName('  '), 'audio');
      expect(AudioImportService.sanitizeFileName('..'), 'audio');
    });
  });
}
