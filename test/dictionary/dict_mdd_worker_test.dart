import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/dictionary/models/dict_info.dart';
import 'package:in4up/features/dictionary/services/dict_device_channel.dart';
import 'package:in4up/features/dictionary/services/dict_mdd_worker.dart';
import 'package:in4up/features/dictionary/services/random_access_source.dart';

import 'mdx_test_builder.dart';

DictInfo dictionary(List<String> parts) => DictInfo(
  id: 'd', name: 'd', entryCount: 1, dbPath: '/index',
  importedAt: DateTime.utc(2026), mddPaths: parts,
);
Uint8List fixture(String value) => MdxTestBuilder(mdd: true, utf16: true,
  entries: {'\\a': value}).build();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('worker reads ordered filesystem parts and does not cache old bytes', () async {
    final dir = await Directory.systemTemp.createTemp('mdd-worker-');
    addTearDown(() => dir.delete(recursive: true));
    final first = File('${dir.path}/first.mdd')..writeAsBytesSync(
      MdxTestBuilder(mdd: true, utf16: true, entries: {'\\b': 'other'}).build());
    final second = File('${dir.path}/second.mdd')..writeAsBytesSync(fixture('one'));
    final pool = MddWorkerPool();
    final dict = dictionary([first.path, second.path]);
    expect(await pool.start(dict, 'a').result, 'one'.codeUnits);
    second.writeAsBytesSync(fixture('two'));
    expect(await pool.start(dict, 'a').result, 'two'.codeUnits);
    expect(await pool.start(dict, 'absent').result, isNull);
    expect(await pool.start(dict, '../a').result, isNull);
    second.deleteSync();
    await expectLater(pool.start(dict, 'a').result,
      throwsA(isA<RandomAccessSourceException>().having((e) => e.needsReselect, 'needsReselect', isTrue)));
  });

  test('SAF RPC closes resources and propagates permission loss', () async {
    const channel = MethodChannel('in4up/dictionary');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final bytes = fixture('saf');
    var closed = 0;
    var revoked = false;
    DictDeviceChannel.isSupportedOverride = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'openRandomAccess') {
        if (revoked) throw PlatformException(code: 'PERMISSION_LOST', message: 'revoked');
        return {'id': 'saf', 'length': bytes.length};
      }
      if (call.method == 'readRandomAccess') {
        final args = call.arguments as Map<dynamic, dynamic>;
        final offset = args['offset'] as int;
        final count = args['count'] as int;
        expect(count, lessThanOrEqualTo(64 * 1024));
        return Uint8List.fromList(bytes.sublist(offset, offset + count));
      }
      if (call.method == 'closeRandomAccess') { closed++; return null; }
      throw MissingPluginException();
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      DictDeviceChannel.isSupportedOverride = null;
    });
    final pool = MddWorkerPool();
    final dict = dictionary(['content://provider/mdd']);
    expect(await pool.start(dict, 'a').result, 'saf'.codeUnits);
    expect(closed, 1);
    revoked = true;
    await expectLater(pool.start(dict, 'a').result,
      throwsA(isA<RandomAccessSourceException>().having((e) => e.code, 'code', 'PERMISSION_LOST')));
    expect(closed, 1);
  });

  test('cancel waits for an in-flight SAF open, closes late handle; queue is bounded', () async {
    const channel = MethodChannel('in4up/dictionary');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final opening = Completer<void>();
    final release = Completer<void>();
    final bytes = fixture('wait');
    var closed = 0;
    DictDeviceChannel.isSupportedOverride = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'openRandomAccess') {
        if (!opening.isCompleted) opening.complete();
        await release.future;
        return {'id': 'late', 'length': bytes.length};
      }
      if (call.method == 'closeRandomAccess') { closed++; return null; }
      if (call.method == 'readRandomAccess') throw StateError('Read after cancellation');
      throw MissingPluginException();
    });
    addTearDown(() {
      if (!release.isCompleted) release.complete();
      messenger.setMockMethodCallHandler(channel, null);
      DictDeviceChannel.isSupportedOverride = null;
    });
    final pool = MddWorkerPool(maxQueued: 1);
    final dict = dictionary(['content://provider/mdd']);
    final first = pool.start(dict, 'a');
    final firstError = expectLater(first.result, throwsA(isA<MddReadCancelled>()));
    await opening.future.timeout(const Duration(seconds: 10));
    final queued = pool.start(dict, 'a');
    final queuedError = expectLater(queued.result, throwsA(isA<MddReadCancelled>()));
    expect(() => pool.start(dict, 'a'), throwsStateError);
    await queued.cancel();
    await queuedError;
    var completed = false;
    final cancelled = first.cancel().then((_) { completed = true; });
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    release.complete();
    await cancelled.timeout(const Duration(seconds: 10));
    await firstError;
    expect(closed, 1);
    await first.cancel();
    expect(closed, 1);
  });

  test('cancel waits for an outstanding SAF page read before closing', () async {
    const channel = MethodChannel('in4up/dictionary');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final reading = Completer<void>();
    final release = Completer<void>();
    final bytes = fixture('wait');
    var closed = 0;
    DictDeviceChannel.isSupportedOverride = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'openRandomAccess') return {'id': 'page', 'length': bytes.length};
      if (call.method == 'readRandomAccess') {
        if (!reading.isCompleted) reading.complete();
        await release.future;
        final args = call.arguments as Map<dynamic, dynamic>;
        final offset = args['offset'] as int;
        final count = args['count'] as int;
        return Uint8List.fromList(bytes.sublist(offset, offset + count));
      }
      if (call.method == 'closeRandomAccess') { closed++; return null; }
      throw MissingPluginException();
    });
    addTearDown(() {
      if (!release.isCompleted) release.complete();
      messenger.setMockMethodCallHandler(channel, null);
      DictDeviceChannel.isSupportedOverride = null;
    });
    final task = MddWorkerPool().start(dictionary(['content://provider/mdd']), 'a');
    final error = expectLater(task.result, throwsA(isA<MddReadCancelled>()));
    await reading.future.timeout(const Duration(seconds: 10));
    final cancellation = task.cancel();
    await Future<void>.delayed(Duration.zero);
    expect(closed, 0);
    release.complete();
    await cancellation.timeout(const Duration(seconds: 10));
    await error;
    expect(closed, 1);
  });

  test('batch indexes a part once, preserves order and bounds resources', () async {
    const channel = MethodChannel('in4up/dictionary');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final bytes = MdxTestBuilder(mdd: true, utf16: true,
      entries: {'\\a': 'first', '\\b': 'second'}).build();
    var opened = 0;
    var closed = 0;
    DictDeviceChannel.isSupportedOverride = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'openRandomAccess') { opened++; return {'id': 'part', 'length': bytes.length}; }
      if (call.method == 'readRandomAccess') {
        final args = call.arguments as Map<dynamic, dynamic>;
        final offset = args['offset'] as int;
        return Uint8List.fromList(bytes.sublist(offset, offset + (args['count'] as int)));
      }
      if (call.method == 'closeRandomAccess') { closed++; return null; }
      throw MissingPluginException();
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      DictDeviceChannel.isSupportedOverride = null;
    });
    final pool = MddWorkerPool();
    final dict = dictionary(['content://provider/mdd']);
    final result = await pool.startBatch(dict, ['b', 'a', '../a', 'b']).results;
    expect(result, ['second'.codeUnits, 'first'.codeUnits, null, 'second'.codeUnits]);
    expect(opened, 1);
    expect(closed, 1);
    await expectLater(pool.startBatch(dict, ['a'], maxItemBytes: 4).results, throwsFormatException);
    await expectLater(pool.startBatch(dict, ['a', 'b'], maxTotalBytes: 10).results, throwsFormatException);
    expect(() => pool.startBatch(dict, List.filled(5, 'a')), throwsArgumentError);
    expect(closed, 3);
  });

  test('corrupt MDD is a format error and invalid pool limits rejected', () async {
    final dir = await Directory.systemTemp.createTemp('mdd-worker-bad-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/bad.mdd')..writeAsBytesSync([0, 0, 0, 0]);
    await expectLater(MddWorkerPool().start(dictionary([file.path]), 'a').result,
      throwsFormatException);
    expect(() => MddWorkerPool(maxConcurrent: 3), throwsArgumentError);
  });
}
