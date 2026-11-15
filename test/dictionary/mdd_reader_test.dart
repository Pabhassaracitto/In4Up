import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:in4up/features/dictionary/services/dict_device_channel.dart';
import 'package:in4up/features/dictionary/services/mdd_reader.dart';
import 'package:in4up/features/dictionary/services/random_access_source.dart';

import 'mdx_test_builder.dart';

class MemorySource implements RandomAccessSource {
  final Uint8List data;
  int position = 0;
  int bytesRead = 0;
  int largestRead = 0;
  bool closed = false;
  final int? virtualLength;
  MemorySource(this.data, {this.virtualLength});
  @override
  Future<int> get length async => virtualLength ?? data.length;
  @override
  Future<void> seek(int offset) async { position = offset; }
  @override
  Future<Uint8List> read(int count) async {
    if (closed) throw const RandomAccessSourceException('PERMISSION_LOST', 'lost');
    largestRead = count > largestRead ? count : largestRead;
    final end = position + count < data.length ? position + count : data.length;
    final result = Uint8List.sublistView(data, position, end);
    position = end;
    bytesRead += result.length;
    return result;
  }
  @override
  Future<void> close() async { closed = true; }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Uint8List fixture({int? split, int compression = 2}) => MdxTestBuilder(
        mdd: true, utf16: true, compressType: compression, recordSplitAt: split,
        entries: {'\\a.png': 'abcdef', '\\b.wav': 'audio'},
      ).build();

  test('indexes metadata only and reads records crossing blocks', () async {
    final source = MemorySource(fixture(split: 3));
    final reader = await MddReader.open(source);
    expect(source.bytesRead, lessThan(source.data.length));
    expect(await reader.readResource('/a.png'), 'abcdef'.codeUnits);
    expect(await reader.readResource('B.WAV'), 'audio'.codeUnits);
    expect(await reader.readResource('missing'), isNull);
    await source.close();
  });

  test('does not read a virtual gigabyte-sized file into memory', () async {
    final source = MemorySource(fixture(), virtualLength: 1220 * 1024 * 1024);
    final reader = await MddReader.open(source);
    expect(await reader.readResource('a.png'), 'abcdef'.codeUnits);
    expect(source.bytesRead, lessThan(4096));
    expect(source.largestRead, lessThan(4096));
  });

  test('rejects zlib output beyond the declared block size', () async {
    final data = MdxTestBuilder(mdd: true, utf16: true,
      entries: {'\\a': 'x' * 10000}).build();
    final bd = ByteData.sublistView(data);
    final headerSize = bd.getUint32(0);
    final keyHeader = 8 + headerSize;
    final indexSize = bd.getUint64(keyHeader + 24);
    final keySize = bd.getUint64(keyHeader + 32);
    final recordInfo = keyHeader + 44 + indexSize + keySize + 32;
    bd.setUint64(recordInfo + 8, 8);
    final reader = await MddReader.open(MemorySource(data));
    await expectLater(reader.readResource('a'), throwsFormatException);
  });

  test('aliases sharing an offset refer to the same resource', () async {
    final source = MemorySource(MdxTestBuilder(mdd: true, utf16: true,
      entries: {'\\a': 'same', '\\b': '', '\\c': 'next'},
      aliases: {'\\b': '\\a'}).build());
    final reader = await MddReader.open(source);
    expect(await reader.readResource('a'), 'same'.codeUnits);
    expect(await reader.readResource('b'), 'same'.codeUnits);
    expect(await reader.readResource('c'), 'next'.codeUnits);
  });

  test('supports uncompressed blocks and a reusable index', () async {
    final source = MemorySource(fixture(compression: 0));
    final reader = await MddReader.open(source);
    expect(await reader.readResource('a.png'), 'abcdef'.codeUnits);
    expect(await reader.readResource('a.png'), 'abcdef'.codeUnits);
  });

  test('does not accept traversal, absolute urls or encoded paths', () async {
    final reader = await MddReader.open(MemorySource(fixture()));
    for (final key in ['../a.png', '/x/../a.png', '//a.png', 'https://x/a.png',
      '%2e%2e/a.png', 'a.png?x', 'a.png#x', 'C:\\a.png', 'x//a.png']) {
      expect(await reader.readResource(key), isNull, reason: key);
    }
  });

  test('rejects unsupported and corrupt blocks, truncation and source loss', () async {
    await expectLater(MddReader.open(MemorySource(fixture(compression: 1))), throwsFormatException);
    final bad = fixture();
    bad[8] ^= 1;
    await expectLater(MddReader.open(MemorySource(bad)), throwsFormatException);
    await expectLater(MddReader.open(MemorySource(Uint8List.sublistView(fixture(), 0, 20))), throwsFormatException);
    final source = MemorySource(fixture());
    final reader = await MddReader.open(source);
    await source.close();
    await expectLater(reader.readResource('a.png'), throwsA(isA<RandomAccessSourceException>()));
  });

  test('refuses oversized resource without reading any record data', () async {
    final data = MdxTestBuilder(mdd: true, utf16: true, compressType: 0,
      entries: {'\\big': 'x' * (MddReader.maxAssetBytes + 1)}).build();
    final source = MemorySource(data);
    final reader = await MddReader.open(source);
    final before = source.bytesRead;
    await expectLater(reader.readResource('big'), throwsFormatException);
    expect(source.bytesRead, before);
  });
  test('searches ordered parts and closes every opened source', () async {
    final sources = <MemorySource>[];
    Future<RandomAccessSource> open(Map<String, String> entries) async {
      final source = MemorySource(MdxTestBuilder(mdd: true, utf16: true,
        entries: entries).build());
      sources.add(source);
      return source;
    }
    final parts = MddParts([
      () => open({'\\a': 'first'}),
      () => open({'\\b': 'second'}),
    ]);
    expect(await parts.readResource('b'), 'second'.codeUnits);
    expect(sources.length, 2);
    expect(sources.every((source) => source.closed), isTrue);
    expect(await parts.readResource('../b'), isNull);
    expect(sources.length, 2);
    final broken = MemorySource(Uint8List(4));
    await expectLater(MddParts([() async => broken]).readResource('b'), throwsFormatException);
    expect(broken.closed, isTrue);
  });

  test('reads an MDD through the SAF adapter and closes its handle', () async {
    const channel = MethodChannel('in4up/dictionary');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final bytes = fixture();
    var closes = 0;
    DictDeviceChannel.isSupportedOverride = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'openRandomAccess') return {'id': 'mdd', 'length': bytes.length};
      if (call.method == 'readRandomAccess') {
        final args = call.arguments as Map<dynamic, dynamic>;
        final offset = args['offset'] as int;
        final count = args['count'] as int;
        expect(count, lessThanOrEqualTo(SafRandomAccessSource.pageSize));
        return Uint8List.fromList(bytes.sublist(offset, offset + count));
      }
      if (call.method == 'closeRandomAccess') { closes++; return null; }
      throw MissingPluginException();
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      DictDeviceChannel.isSupportedOverride = null;
    });
    final parts = MddParts([() => SafRandomAccessSource.open('content://test/mdd')]);
    expect(await parts.readResource('a.png'), 'abcdef'.codeUnits);
    expect(closes, 1);
  });

}
