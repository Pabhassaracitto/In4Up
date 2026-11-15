import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/dictionary/models/dict_info.dart';
import 'package:in4up/features/dictionary/services/dict_device_channel.dart';
import 'package:in4up/features/dictionary/services/dict_mdd_resources.dart';
import 'package:in4up/features/dictionary/services/random_access_source.dart';

import 'mdx_test_builder.dart';

DictInfo info({String? root, List<String>? parts, Map<String, String> uris = const {}}) => DictInfo(
  id: 'one', name: 'one', entryCount: 1, dbPath: '/index',
  importedAt: DateTime.utc(2026), resourcePath: root,
  sourceFileName: 'dict.mdx', mddPaths: parts, sourceUris: uris,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  setUp(() async { temp = await Directory.systemTemp.createTemp('mdd-resources-'); });
  tearDown(() async { if (await temp.exists()) await temp.delete(recursive: true); });

  String writePart(String name, Map<String, String> entries) =>
      MdxTestBuilder(mdd: true, utf16: true, entries: entries).writeToFile('${temp.path}/$name');

  test('legacy directory only selects exact stem and sorts numbered parts numerically', () async {
    final base = writePart('dict.mdd', {'\\a': 'base'});
    final ten = writePart('dict.10.mdd', {'\\c': 'ten'});
    final two = writePart('dict.2.mdd', {'\\b': 'two'});
    writePart('other.mdd', {'\\x': 'wrong dictionary'});
    final resources = DictMddResources(info(root: temp.path));
    expect(await resources.locations(), [base, two, ten]);
    expect(await resources.read('b'), 'two'.codeUnits);
    expect(await resources.read('x'), isNull);
  });

  test('manifest distinguishes empty explicit selection from legacy and survives JSON', () async {
    writePart('dict.mdd', {'\\a': 'base'});
    final explicit = info(root: temp.path, parts: []);
    final restored = DictInfo.fromJson(explicit.toJson());
    expect(restored.mddPaths, isEmpty);
    expect(await DictMddResources(restored).locations(), isEmpty);
    final old = info(root: temp.path);
    expect(DictInfo.fromJson(old.toJson()).mddPaths, isNull);
    expect(await DictMddResources(old).locations(), hasLength(1));
    expect(restored.copyWith(mddPaths: ['replacement']).mddPaths, ['replacement']);
  });

  test('explicit ordering wins and broken selected part is not silently skipped', () async {
    final a = writePart('a.mdd', {'\\a': 'first'});
    final b = writePart('b.mdd', {'\\a': 'second'});
    final resources = DictMddResources(info(parts: [b, a]));
    expect(await resources.read('a'), 'second'.codeUnits);
    final broken = DictMddResources(info(parts: ['${temp.path}/missing.mdd', a]));
    await expectLater(broken.read('a'), throwsA(isA<RandomAccessSourceException>()));
    expect(await broken.read('../a'), isNull);
    await expectLater(DictMddResources(info(parts: ['https://evil.test/file.mdd'])).read('a'), throwsFormatException);
  });

  test('legacy SAF manifest uses assigned names for ordering and closes handles', () async {
    final bytes = <String, Uint8List>{
      'content://provider/ten': MdxTestBuilder(mdd: true, utf16: true, entries: {'\\c': 'ten'}).build(),
      'content://provider/two': MdxTestBuilder(mdd: true, utf16: true, entries: {'\\b': 'two'}).build(),
    };
    const channel = MethodChannel('in4up/dictionary');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var closed = 0;
    DictDeviceChannel.isSupportedOverride = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      final args = call.arguments as Map<dynamic, dynamic>;
      if (call.method == 'openRandomAccess') {
        final uri = args['uri'] as String;
        return {'id': uri, 'length': bytes[uri]!.length};
      }
      if (call.method == 'readRandomAccess') {
        final data = bytes[args['id'] as String]!;
        final offset = args['offset'] as int;
        final count = args['count'] as int;
        return Uint8List.fromList(data.sublist(offset, offset + count));
      }
      if (call.method == 'closeRandomAccess') { closed++; return null; }
      throw MissingPluginException();
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      DictDeviceChannel.isSupportedOverride = null;
    });
    final resources = DictMddResources(info(uris: {
      'dict.10.mdd': 'content://provider/ten',
      'dict.2.mdd': 'content://provider/two',
      'dict.mdx': 'content://provider/mdx',
    }));
    expect(await resources.locations(), ['content://provider/two', 'content://provider/ten']);
    expect(await resources.read('c'), 'ten'.codeUnits);
    expect(closed, 2);
  });
}
