import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart' as material;
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/dictionary/models/dict_info.dart';
import 'package:in4up/features/dictionary/services/dict_image_policy.dart';
import 'package:in4up/features/dictionary/services/dict_mdd_worker.dart';
import 'package:in4up/features/dictionary/widgets/dict_source_images.dart';

import 'mdx_test_builder.dart';

final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==');

class FakeRead implements DictImageRead {
  final completer = Completer<List<Uint8List?>>();
  int cancellations = 0;
  @override
  Future<List<Uint8List?>> get results => completer.future;
  @override
  Future<void> cancel() async {
    cancellations++;
    if (!completer.isCompleted) completer.completeError(StateError('cancelled'));
  }
}

void main() {
  test('extracts only local MDD image keys and skips active content', () {
    final keys = DictImagePolicy.extract(
      '<script><img src="inside.png"></script><iframe><img src="f.png"></iframe>'
      '<img src="https://example.test/a.png"><img src="file:///a.png">'
      '<img src="../a.png"><img src="%2e%2e/a.png"><img src="x.svg">'
      '<img src="\\pic.PNG"><img src="pic.png"><img src="p.jpg">'
      '<img src="b.jpeg"><img src="c.png"><img src="extra.png">');
    expect(keys, ['pic.png', 'p.jpg', 'b.jpeg', 'c.png']);
  });

  test('checks image bytes, dimensions, animation and malformed headers', () {
    final size = DictImagePolicy.inspect(png);
    expect(size?.width, 1);
    expect(size?.height, 1);
    final huge = Uint8List.fromList(png);
    ByteData.sublistView(huge).setUint32(16, 2049);
    expect(DictImagePolicy.inspect(huge), isNull);
    final animated = Uint8List.fromList([
      ...png.sublist(0, 33), 0, 0, 0, 0, 97, 99, 84, 76, 0, 0, 0, 0,
      ...png.sublist(33),
    ]);
    expect(DictImagePolicy.inspect(animated), isNull);
    expect(DictImagePolicy.inspect(Uint8List.sublistView(png, 0, 30)), isNull);
    expect(DictImagePolicy.inspect(Uint8List(DictImagePolicy.maxBytes + 1)), isNull);
    final jpg = Uint8List.fromList([255,216,255,192,0,11,8,0,2,0,3,1,1,17,0,255,218,0,8,1,1,0,0,63,0]);
    expect(DictImagePolicy.inspect(jpg)?.width, 3);
    expect(DictImagePolicy.inspect(jpg)?.height, 2);
    expect(DictImagePolicy.inspect(Uint8List.fromList([255,216,255,218,0,2,0,0,0,0,0,0])), isNull);
  });

  test('bounded batch reads synthetic PNG from a real worker', () async {
    final dir = await Directory.systemTemp.createTemp('dict-image-mdd-');
    addTearDown(() => dir.delete(recursive: true));
    final mdd = MdxTestBuilder(mdd: true, utf16: true,
      entries: {'\\pic.png': String.fromCharCodes(png)}).writeToFile('${dir.path}/dict.mdd');
    final info = DictInfo(id: 'd', name: 'd', entryCount: 1, dbPath: '/unused',
      importedAt: DateTime.utc(2026), mddPaths: [mdd]);
    final keys = DictImagePolicy.extract('<img src="pic.png">');
    final results = await MddWorkerPool().startBatch(info, keys,
      maxItemBytes: DictImagePolicy.maxBytes).results;
    expect(results.single, png);
    expect(DictImagePolicy.inspect(results.single!)?.width, 1);
  });

  testWidgets('loads only on request and drops images when the source changes', (tester) async {
    final revision = ValueNotifier<int>(0);
    final read = FakeRead();
    var starts = 0;
    await tester.pumpWidget(material.MaterialApp(home: material.Scaffold(body:
      DictSourceImages(dictId: 'd', definition: '<img src="p.png">', sourceChanges: revision,
        startRead: (id, keys) async { starts++; expect(keys, ['p.png']); return read; }))));
    expect(starts, 0);
    await tester.tap(find.byType(material.TextButton));
    await tester.pump();
    expect(starts, 1);
    read.completer.complete([png]);
    await tester.pump();
    expect(find.byType(material.Image), findsOneWidget);
    revision.value++;
    await tester.pump();
    expect(find.byType(material.Image), findsNothing);
    await tester.pumpWidget(const material.SizedBox.shrink());
    revision.dispose();
  });

  testWidgets('cancels a late task after invalidation and never shows stale bytes', (tester) async {
    final revision = ValueNotifier<int>(0);
    final start = Completer<DictImageRead>();
    final read = FakeRead();
    await tester.pumpWidget(material.MaterialApp(home: material.Scaffold(body:
      DictSourceImages(dictId: 'd', definition: '<img src="p.png">', sourceChanges: revision,
        startRead: (id, keys) => start.future))));
    await tester.tap(find.byType(material.TextButton));
    await tester.pump();
    revision.value++;
    await tester.pump();
    start.complete(read);
    await tester.pump();
    expect(read.cancellations, 1);
    expect(find.byType(material.Image), findsNothing);
    await tester.pumpWidget(const material.SizedBox.shrink());
    revision.dispose();
  });

  testWidgets('disposal cancels an active image read', (tester) async {
    final revision = ValueNotifier<int>(0);
    final read = FakeRead();
    await tester.pumpWidget(material.MaterialApp(home: material.Scaffold(body:
      DictSourceImages(dictId: 'd', definition: '<img src="p.png">', sourceChanges: revision,
        startRead: (id, keys) async => read))));
    await tester.tap(find.byType(material.TextButton));
    await tester.pump();
    await tester.pumpWidget(const material.SizedBox.shrink());
    await tester.pump();
    expect(read.cancellations, 1);
    revision.dispose();
  });
}
