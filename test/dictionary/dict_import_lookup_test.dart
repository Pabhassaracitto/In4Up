// DICT-001 §8 — Integration: import .mdx → lookup → auto-fill meaning,
// và Acceptance Test #4 (xóa), #5 (đa từ điển), #6 (file hỏng → lỗi rõ).
//
// Chạy SQLite qua sqflite_common_ffi; thư mục documents ghi đè bằng
// DictionaryService.documentsDirectoryOverride (test seam).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/dictionary/models/dict_info.dart';
import 'package:in4up/features/dictionary/services/dictionary_service.dart';
import 'package:in4up/features/dictionary/services/dict_device_channel.dart';
import 'package:in4up/features/dictionary/services/dict_db_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'mdx_test_builder.dart';

void main() {
  late Directory tempDir;
  late Directory docsDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('in4up-dict-import-');
    docsDir = Directory('${tempDir.path}/docs');
    await docsDir.create(recursive: true);
    DictionaryService.documentsDirectoryOverride = docsDir;
    DictionaryService.resetForTest();
  });

  tearDown(() async {
    DictionaryService.resetForTest();
    DictionaryService.documentsDirectoryOverride = null;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<String> writeMdx(String name, Map<String, String> entries) async {
    return MdxTestBuilder(entries: entries)
        .writeToFile('${tempDir.path}/$name');
  }

  test('AT #1: import .mdx → danh sách có từ điển + entryCount > 0', () async {
    final mdx = await writeMdx('en_vi_a.mdx', {
      'hello': '<b>hello</b> — xin chào',
      'world': 'thế giới',
      'book': 'quyển sách',
    });

    final outcome = await DictionaryService.instance.importDictionaryBundle(
      absoluteFilePaths: [mdx],
      rootPath: '',
      mode: DictStorageMode.linked,
    );

    expect(outcome.isSuccess, isTrue, reason: 'Import phải thành công');
    expect(outcome.imported, hasLength(1));
    final dict = outcome.imported.first;
    expect(dict.entryCount, 3);
    expect(dict.name, 'Test Dictionary');
    expect(dict.sourceLang, 'en');
    expect(dict.targetLang, 'vi');
    expect(File(dict.dbPath).existsSync(), isTrue);
  });

  test('AT #2 + #3: lookup trả nghĩa; meaning auto-fill lấy từ kết quả đầu',
      () async {
    final mdx = await writeMdx('en_vi_b.mdx', {
      'hello': 'xin chào — lời chào',
    });
    await DictionaryService.instance.importDictionaryBundle(
      absoluteFilePaths: [mdx],
      rootPath: '',
      mode: DictStorageMode.linked,
    );

    final entries = await DictionaryService.instance.lookup('hello');
    expect(entries, isNotEmpty);
    // WordActionsSheet auto-fill: bestMeaning = entries.first.plainDefinition
    final bestMeaning = entries.first.plainDefinition;
    expect(bestMeaning, contains('xin chào'));

    // Lookup không phân biệt hoa/thường (§4).
    expect(await DictionaryService.instance.lookup('HELLO'), isNotEmpty);
  });

  test('AT #5: import nhiều từ điển → lookup gộp kết quả từ tất cả', () async {
    final a = await writeMdx('en_vi_c.mdx', {
      'hello': 'từ điển C — xin chào',
      'only_c': 'chỉ có ở C',
    });
    final b = await writeMdx('en_vi_d.mdx', {
      'hello': 'từ điển D — hello',
      'only_d': 'chỉ có ở D',
    });
    await DictionaryService.instance.importDictionaryBundle(
      absoluteFilePaths: [a],
      rootPath: '',
      mode: DictStorageMode.linked,
    );
    await DictionaryService.instance.importDictionaryBundle(
      absoluteFilePaths: [b],
      rootPath: '',
      mode: DictStorageMode.linked,
    );

    expect(DictionaryService.instance.dictionaries, hasLength(2));

    final hello = await DictionaryService.instance.lookup('hello');
    expect(hello, hasLength(2));
    expect(hello.map((e) => e.definition).toSet(),
        containsAll(['từ điển C — xin chào', 'từ điển D — hello']));

    expect(await DictionaryService.instance.lookup('only_c'), hasLength(1));
    expect(await DictionaryService.instance.lookup('only_d'), hasLength(1));
  });

  test('AT #4: xóa từ điển → lookup không còn trả kết quả từ dict đó',
      () async {
    final mdx = await writeMdx('en_vi_e.mdx', {'hello': 'nghĩa E'});
    final outcome = await DictionaryService.instance.importDictionaryBundle(
      absoluteFilePaths: [mdx],
      rootPath: '',
      mode: DictStorageMode.linked,
    );
    final dictId = outcome.imported.first.id;
    expect(await DictionaryService.instance.lookup('hello'), hasLength(1));

    await DictionaryService.instance.deleteDict(dictId);

    expect(DictionaryService.instance.dictionaries, isEmpty);
    expect(await DictionaryService.instance.lookup('hello'), isEmpty);
    // Index SQLite đã xoá khỏi storage.
    expect(File(outcome.imported.first.dbPath).existsSync(), isFalse);
  });

  test('toggle tắt từ điển → không tham gia lookup; bật lại → có lại',
      () async {
    final mdx = await writeMdx('en_vi_f.mdx', {'hello': 'nghĩa F'});
    final outcome = await DictionaryService.instance.importDictionaryBundle(
      absoluteFilePaths: [mdx],
      rootPath: '',
      mode: DictStorageMode.linked,
    );
    final dictId = outcome.imported.first.id;

    await DictionaryService.instance.toggleDict(dictId, false);
    expect(await DictionaryService.instance.lookup('hello'), isEmpty);

    await DictionaryService.instance.toggleDict(dictId, true);
    expect(await DictionaryService.instance.lookup('hello'), hasLength(1));
  });

  test('AT #6: file .mdx hỏng → lỗi rõ trong outcome, không crash', () async {
    final broken = File('${tempDir.path}/broken.mdx');
    broken.writeAsBytesSync(List.generate(128, (i) => i));

    final outcome = await DictionaryService.instance.importDictionaryBundle(
      absoluteFilePaths: [broken.path],
      rootPath: '',
      mode: DictStorageMode.linked,
    );

    expect(outcome.isSuccess, isFalse);
    expect(outcome.error, isNotNull);
    // Lỗi phải nêu lý do cụ thể (tên set + lý do parse).
    // suggestedName bỏ đuôi file → error chứa 'broken' (không có .mdx).
    expect(outcome.error, contains('broken'));
    expect(outcome.error, contains('định dạng'));
  });

  test('manifest persisted — khởi động lại vẫn còn từ điển', () async {
    final mdx = await writeMdx('en_vi_g.mdx', {'hello': 'nghĩa G'});
    await DictionaryService.instance.importDictionaryBundle(
      absoluteFilePaths: [mdx],
      rootPath: '',
      mode: DictStorageMode.linked,
    );

    // Giả lập khởi động lại: reset singleton (manifest vẫn ở docs dir).
    DictionaryService.resetForTest();
    await DictionaryService.instance.ensureInitialized();

    expect(DictionaryService.instance.dictionaries, hasLength(1));
    expect(await DictionaryService.instance.lookup('hello'), hasLength(1));
    expect(File('${docsDir.path}/dictionaries/manifest.json').existsSync(),
        isTrue);
  });
  for (final mode in [DictStorageMode.linked, DictStorageMode.imported]) {
    test('MDD bundle lookup and manifest persistence: ${mode.name}', () async {
      final mdx = await writeMdx('media.mdx', {'hello': 'hello'});
      final two = MdxTestBuilder(mdd: true, utf16: true,
        entries: {'\\b': 'second'}).writeToFile('${tempDir.path}/media.2.mdd');
      final base = MdxTestBuilder(mdd: true, utf16: true,
        entries: {'\\a': 'first'}).writeToFile('${tempDir.path}/media.mdd');
      final ten = MdxTestBuilder(mdd: true, utf16: true,
        entries: {'\\c': 'tenth'}).writeToFile('${tempDir.path}/media.10.mdd');
      final outcome = await DictionaryService.instance.importDictionaryBundle(
        absoluteFilePaths: [mdx, ten, two, base], rootPath: '', mode: mode);
      expect(outcome.isSuccess, isTrue, reason: outcome.error);
      final dict = outcome.imported.single;
      expect(dict.mddPaths, hasLength(3));
      expect(dict.mddPaths!.map((p) => p.split('/').last),
        ['media.mdd', 'media.2.mdd', 'media.10.mdd']);
      if (mode == DictStorageMode.imported) {
        expect(dict.mddPaths!.every((p) => p.startsWith(dict.resourcePath!)), isTrue);
      } else {
        expect(dict.mddPaths, [base, two, ten]);
      }
      expect(await DictionaryService.instance.readMddResource(dict.id, 'b'), 'second'.codeUnits);
      DictionaryService.resetForTest();
      await DictionaryService.instance.ensureInitialized();
      expect(DictionaryService.instance.dictionaries.single.mddPaths, dict.mddPaths);
      expect(await DictionaryService.instance.readMddResource(dict.id, 'c'), 'tenth'.codeUnits);
      expect(await DictionaryService.instance.lookup('hello'), hasLength(1));
    });
  }

  test('resource revision invalidates on reimport, relink and delete', () async {
    final service = DictionaryService.instance;
    final mdx = await writeMdx('images.mdx', {'hello': 'hello'});
    final before = service.resourceRevision.value;
    final outcome = await service.importDictionaryBundle(absoluteFilePaths: [mdx],
      rootPath: '', mode: DictStorageMode.linked);
    expect(service.resourceRevision.value, greaterThan(before));
    final id = outcome.imported.single.id;
    var revision = service.resourceRevision.value;
    await service.toggleDict(id, false);
    expect(service.resourceRevision.value, greaterThan(revision));
    revision = service.resourceRevision.value;
    await service.toggleDict(id, true);
    expect(service.resourceRevision.value, greaterThan(revision));
    revision = service.resourceRevision.value;
    expect(await service.relinkSafSource(id, treeUri: 'content://provider/tree/root',
      sourceWasFolder: true, files: [const DictDeviceFile(uri: 'content://provider/mdx',
        name: 'images.mdx', relativePath: 'images.mdx', sizeBytes: 1, extension: 'mdx')]), isTrue);
    expect(service.resourceRevision.value, greaterThan(revision));
    revision = service.resourceRevision.value;
    await service.deleteDict(id);
    expect(service.resourceRevision.value, greaterThan(revision));
  });

  test('SAF relink replaces selected MDD locations and persists them', () async {
    final mdx = await writeMdx('media.mdx', {'hello': 'hello'});
    final outcome = await DictionaryService.instance.importDictionaryBundle(
      absoluteFilePaths: [mdx], rootPath: '', mode: DictStorageMode.linked);
    final id = outcome.imported.single.id;
    DictDeviceFile file(String name, String uri) => DictDeviceFile(
      uri: uri, name: name, relativePath: name, sizeBytes: 1,
      extension: name.endsWith('.mdx') ? 'mdx' : 'mdd');
    final changed = await DictionaryService.instance.relinkSafSource(id,
      treeUri: 'content://provider/tree/root', sourceWasFolder: true,
      files: [file('media.mdx', 'content://provider/mdx'),
        file('media.10.mdd', 'content://provider/ten'),
        file('media.2.mdd', 'content://provider/two')]);
    expect(changed, isTrue);
    expect(DictionaryService.instance.dictionaries.single.mddPaths,
      ['content://provider/two', 'content://provider/ten']);
    DictionaryService.resetForTest();
    await DictionaryService.instance.ensureInitialized();
    expect(DictionaryService.instance.dictionaries.single.mddPaths,
      ['content://provider/two', 'content://provider/ten']);
    expect(await DictionaryService.instance.lookup('hello'), hasLength(1));
  });

  test('failed optional copy is reported and never registered as a part', () async {
    final mdx = await writeMdx('partial.mdx', {'hello': 'hello'});
    final missing = '${tempDir.path}/partial.1.mdd';
    final outcome = await DictionaryService.instance.importDictionaryBundle(
      absoluteFilePaths: [mdx, missing], rootPath: '', mode: DictStorageMode.imported);
    expect(outcome.isSuccess, isTrue, reason: outcome.error);
    expect(outcome.imported.single.mddPaths, isEmpty);
    expect(outcome.imported.single.missingResources, contains('partial.1.mdd'));
    expect(outcome.missingParts, contains('partial.1.mdd'));
    expect(await DictionaryService.instance.lookup('hello'), hasLength(1));
  });

  test('lookup report distinguishes missing, partial DB error, and truncation', () async {
    final a = await writeMdx('report-a.mdx', {'hello': 'original'});
    final b = await writeMdx('report-b.mdx', {'hello': 'other'});
    final first = (await DictionaryService.instance.importDictionaryBundle(
      absoluteFilePaths: [a], rootPath: '', mode: DictStorageMode.linked)).imported.single;
    final second = (await DictionaryService.instance.importDictionaryBundle(
      absoluteFilePaths: [b], rootPath: '', mode: DictStorageMode.linked)).imported.single;
    await DictDbService.insertBatch(first.dbPath, [
      for (var i = 0; i < 10; i++)
        {'headword': 'hello', 'definition': 'extra $i', 'dict_id': first.id},
    ]);
    var report = await DictionaryService.instance.lookupWithReport('hello');
    expect(report.entries, hasLength(11)); // 10 from first, 1 from second
    expect(report.truncatedSources, [first.name]);
    expect(report.failedSources, isEmpty);
    report = await DictionaryService.instance.lookupWithReport('absent');
    expect(report.entries, isEmpty);
    expect(report.failedSources, isEmpty);
    expect(report.truncatedSources, isEmpty);

    // A real SQLite schema failure, not a simulated missing word.
    final db = await openDatabase(second.dbPath);
    await db.execute('DROP TABLE dict_entries');
    await db.close();
    report = await DictionaryService.instance.lookupWithReport('hello');
    expect(report.entries, hasLength(10));
    expect(report.failedSources, [second.name]);
    expect(report.truncatedSources, [first.name]);
    expect((await DictionaryService.instance.lookup('hello')), hasLength(10));
    report = await DictionaryService.instance.lookupWithReport('absent', dictId: second.id);
    expect(report.entries, isEmpty);
    expect(report.failedSources, [second.name]);
  });

}
