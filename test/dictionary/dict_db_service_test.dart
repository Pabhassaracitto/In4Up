// DICT-001 §8 — Unit test: DictDbService (SQLite qua sqflite_common_ffi).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/dictionary/services/dict_db_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDir;
  late String dbPath;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('in4up-dict-db-');
    dbPath = '${tempDir.path}/test.dict.sqlite';
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> seedEntries(List<String> words) async {
    await DictDbService.createDb(dbPath);
    await DictDbService.insertBatch(dbPath, [
      for (final w in words)
        {
          'headword': w,
          'definition': '<b>nghĩa của $w</b>',
          'phonetic': null,
          'audio_path': null,
          'part_of_speech': null,
          'dict_id': 'dict-a',
        },
    ]);
  }

  test('createDb bật WAL mode (import dict lớn — §6)', () async {
    await DictDbService.createDb(dbPath);
    final db = await openDatabase(dbPath, readOnly: true);
    final rows = await db.rawQuery('PRAGMA journal_mode');
    await db.close();
    expect(rows.first.values.first.toString().toLowerCase(), 'wal');
  });

  test('insertBatch + lookup chính xác', () async {
    await seedEntries(['hello', 'world']);
    final entries = await DictDbService.lookup(dbPath, 'hello');
    expect(entries, hasLength(1));
    expect(entries.first.headword, 'hello');
    expect(entries.first.plainDefinition, 'nghĩa của hello');
    expect(entries.first.dictId, 'dict-a');
  });

  test('lookup không phân biệt hoa/thường (§4)', () async {
    await seedEntries(['hello']);
    expect(await DictDbService.lookup(dbPath, 'HELLO'), hasLength(1));
    expect(await DictDbService.lookup(dbPath, 'HeLLo'), hasLength(1));
    expect(await DictDbService.lookup(dbPath, 'hell'), isEmpty);
  });

  test('lookupPrefix — prefix match cho autocomplete', () async {
    await seedEntries(['hello', 'help', 'helix', 'world']);
    final entries = await DictDbService.lookupPrefix(dbPath, 'hel');
    expect(entries, hasLength(3));
    expect(
      entries.map((e) => e.headword).toSet(),
      {'hello', 'help', 'helix'},
    );
  });

  test('insertBatch nhiều đợt — entry cộng dồn (import theo flush)', () async {
    await DictDbService.createDb(dbPath);
    await DictDbService.insertBatch(dbPath, [
      {
        'headword': 'a',
        'definition': 'x',
        'phonetic': null,
        'audio_path': null,
        'part_of_speech': null,
        'dict_id': 'd',
      },
    ]);
    await DictDbService.insertBatch(dbPath, [
      for (final w in ['b', 'c'])
        {
          'headword': w,
          'definition': 'x',
          'phonetic': null,
          'audio_path': null,
          'part_of_speech': null,
          'dict_id': 'd',
        },
    ]);
    expect(await DictDbService.lookup(dbPath, 'a'), hasLength(1));
    expect(await DictDbService.lookup(dbPath, 'b'), hasLength(1));
    expect(await DictDbService.lookup(dbPath, 'c'), hasLength(1));
  });

  test('deleteDb xoá sạch file index (AT #4)', () async {
    await seedEntries(['hello']);
    expect(File(dbPath).existsSync(), isTrue);
    await DictDbService.deleteDb(dbPath);
    expect(File(dbPath).existsSync(), isFalse);
  });
}
