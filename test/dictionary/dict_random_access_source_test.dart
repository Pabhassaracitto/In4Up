import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/dictionary/models/dict_entry.dart';
import 'package:in4up/features/dictionary/models/dict_info.dart';
import 'package:in4up/features/dictionary/services/dict_db_service.dart';
import 'package:in4up/features/dictionary/services/dict_device_channel.dart';
import 'package:in4up/features/dictionary/services/dictionary_service.dart';
import 'package:in4up/features/dictionary/services/mdx_parser.dart';
import 'package:in4up/features/dictionary/services/random_access_source.dart';

import 'mdx_test_builder.dart';

class _MemoryRandomAccessSource implements RandomAccessSource {
  final Uint8List bytes;
  int position = 0;
  bool closed = false;

  _MemoryRandomAccessSource(List<int> bytes)
      : bytes = Uint8List.fromList(bytes);

  @override
  Future<int> get length async => bytes.length;

  @override
  Future<void> seek(int offset) async {
    if (closed) throw StateError('closed');
    if (offset < 0 || offset > bytes.length) {
      throw RangeError.range(offset, 0, bytes.length, 'offset');
    }
    position = offset;
  }

  @override
  Future<Uint8List> read(int count) async {
    if (closed) throw StateError('closed');
    if (count < 0) throw RangeError.value(count, 'count');
    final end = (position + count).clamp(0, bytes.length).toInt();
    final result = Uint8List.fromList(bytes.sublist(position, end));
    position = end;
    return result;
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

void main() {
  group('RandomAccessSource', () {
    test('memory source reads requested offsets and clips at EOF', () async {
      final source = _MemoryRandomAccessSource(List.generate(10, (i) => i));

      expect(await source.length, 10);
      await source.seek(3);
      expect(await source.read(4), [3, 4, 5, 6]);
      await source.seek(8);
      expect(await source.read(20), [8, 9]);
      expect(await source.read(1), isEmpty);
      await source.seek(10);
      expect(await source.read(0), isEmpty);
      await expectLater(source.seek(11), throwsA(isA<RangeError>()));
      await source.close();
      expect(source.closed, isTrue);
    });

    test('file source supports random seek and EOF boundaries', () async {
      final dir = await Directory.systemTemp.createTemp('dict-ras-file-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/bytes.bin')
        ..writeAsBytesSync(List.generate(10, (i) => i));
      final source = await FileRandomAccessSource.open(file.path);
      addTearDown(source.close);

      expect(await source.length, 10);
      await source.seek(7);
      expect(await source.read(8), [7, 8, 9]);
      await source.seek(0);
      expect(await source.read(2), [0, 1]);
    });

    test('SAF source reads bounded pages and reuses cached pages', () async {
      const channel = MethodChannel('in4up/dictionary');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final bytes = Uint8List.fromList(
        List.generate(SafRandomAccessSource.pageSize + 10, (i) => i % 251),
      );
      var readCalls = 0;
      var closeCalls = 0;
      DictDeviceChannel.isSupportedOverride = true;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'openRandomAccess') {
          return <String, Object>{'id': 'test-handle', 'length': bytes.length};
        }
        if (call.method == 'readRandomAccess') {
          readCalls++;
          final args = call.arguments as Map<dynamic, dynamic>;
          final offset = args['offset'] as int;
          final count = args['count'] as int;
          return Uint8List.fromList(bytes.sublist(offset, offset + count));
        }
        if (call.method == 'closeRandomAccess') {
          closeCalls++;
          return null;
        }
        throw MissingPluginException('Unexpected method: ${call.method}');
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
        DictDeviceChannel.isSupportedOverride = null;
      });

      final source = await SafRandomAccessSource.open(
        'content://provider/document/test-mdx',
      );
      addTearDown(source.close);
      expect(await source.length, bytes.length);
      await source.seek(SafRandomAccessSource.pageSize - 2);
      expect(
        await source.read(4),
        bytes.sublist(SafRandomAccessSource.pageSize - 2,
            SafRandomAccessSource.pageSize + 2),
      );
      expect(readCalls, 2, reason: 'The read crosses exactly two 64 KiB pages.');

      await source.seek(0);
      expect(await source.read(1), [bytes.first]);
      expect(readCalls, 2, reason: 'The first page should be served from cache.');
      await source.close();
      expect(closeCalls, 1);
    });
  });

  test('MDX parser reads a dictionary from an in-memory source', () async {
    final bytes = MdxTestBuilder(entries: {
      'hello': '<b>hello</b> — xin chào',
      'world': 'thế giới',
    }).build();
    final source = _MemoryRandomAccessSource(bytes);
    final entries = <DictEntry>[];
    final done = Completer<void>();
    Object? error;

    MdxParser.parseSource(source, dictId: 'memory-dict').listen(
      entries.add,
      onError: (Object caught) => error = caught,
      onDone: () => done.complete(),
    );
    await done.future.timeout(const Duration(seconds: 10));

    expect(error, isNull);
    expect(entries, hasLength(2));
    expect(entries.map((entry) => entry.headword), ['hello', 'world']);
    expect(entries.first.definition, contains('xin chào'));
    expect(source.closed, isTrue);
  });

  test('revoked SAF source becomes needsReselect and retains the SQLite index',
      () async {
    final temp = await Directory.systemTemp.createTemp('dict-needs-reselect-');
    const channel = MethodChannel('in4up/dictionary');
    addTearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      DictDeviceChannel.isSupportedOverride = null;
      DictionaryService.linkedSourceAccessProbeOverride = null;
      DictionaryService.documentsDirectoryOverride = null;
      DictionaryService.resetForTest();
      if (await temp.exists()) await temp.delete(recursive: true);
    });
    final docs = Directory('${temp.path}/docs');
    final dictsDir = Directory('${docs.path}/dictionaries')
      ..createSync(recursive: true);
    DictionaryService.documentsDirectoryOverride = docs;
    DictionaryService.resetForTest();

    const sourceName = 'en_vi_linked.mdx';
    final dictId = md5
        .convert(utf8.encode(sourceName))
        .toString()
        .substring(0, 12);
    final dbFile = File('${dictsDir.path}/$dictId.dict.sqlite');
    await DictDbService.createDb(dbFile.path);
    await DictDbService.insertBatch(dbFile.path, [
      DictEntry(
        headword: 'hello',
        definition: 'xin chào',
        dictId: dictId,
      ).toMap(),
    ]);
    final info = DictInfo(
      id: dictId,
      name: 'Linked Dictionary',
      entryCount: 1,
      dbPath: dbFile.path,
      importedAt: DateTime.utc(2026, 10, 7),
      storageMode: DictStorageMode.linked,
      sourceFolder: 'content://provider/tree/root',
      sourceMdxUri: 'content://provider/document/dead-mdx',
      sourceFileName: sourceName,
    );
    File('${dictsDir.path}/manifest.json')
        .writeAsStringSync(jsonEncode([info.toJson()]));

    DictionaryService.linkedSourceAccessProbeOverride = (_) async => false;
    await DictionaryService.instance.ensureInitialized();
    final refreshed = await DictionaryService.instance.refreshLinkedSources();

    expect(refreshed, hasLength(1));
    expect(refreshed.single.needsReselect, isTrue);
    expect(dbFile.existsSync(), isTrue,
        reason: 'A dead URI must not remove the already-built index.');
    expect(await DictionaryService.instance.lookup('hello'), hasLength(1));

    // A failed linked re-import (revoked URI) must not delete or replace the
    // last good index while reporting that the source needs reselection.
    DictDeviceChannel.isSupportedOverride = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'openRandomAccess') {
        throw PlatformException(
          code: 'PERMISSION_LOST',
          message: 'persisted grant was revoked',
        );
      }
      throw MissingPluginException(
        'Unexpected dictionary method: ${call.method}',
      );
    });
    final failedImport =
        await DictionaryService.instance.importSafDictionaryBundle(
      files: [
        DictDeviceFile(
          uri: 'content://provider/document/dead-mdx',
          name: sourceName,
          relativePath: sourceName,
          sizeBytes: 10,
          extension: 'mdx',
        ),
      ],
      mode: DictStorageMode.linked,
      treeUri: 'content://provider/tree/root',
      sourceWasFolder: true,
    );
    expect(failedImport.needsReselect, isTrue);
    expect(dbFile.existsSync(), isTrue);
    expect(await DictionaryService.instance.lookup('hello'), hasLength(1));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);

    // Simulate another app launch: both the warning and SQLite lookup survive
    // loading the persisted manifest while the original SAF URI stays revoked.
    DictionaryService.resetForTest();
    DictionaryService.linkedSourceAccessProbeOverride = (_) async => false;
    await DictionaryService.instance.ensureInitialized();
    final afterRestart =
        await DictionaryService.instance.refreshLinkedSources();
    expect(afterRestart.single.needsReselect, isTrue);
    final retainedLookup = await DictionaryService.instance.lookup('hello');
    expect(retainedLookup, hasLength(1));
    expect(retainedLookup.single.plainDefinition, 'xin chào');

    final saved = jsonDecode(
      File('${dictsDir.path}/manifest.json').readAsStringSync(),
    ) as List<dynamic>;
    expect((saved.single as Map<String, dynamic>)['needs_reselect'], isTrue);
  });
}
