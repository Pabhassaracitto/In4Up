// DICT-001 §8 — Unit test: MdxParser (mock binary data).
//
// File MDX tổng hợp dựng bởi MdxTestBuilder theo đặc tả
// writemdict/fileformat.md (đối chiếu mdict-utils readmdict.py) — phủ:
// - engine 2.0 & 1.2, UTF-8 & UTF-16, multi key/record block
// - biến thể v1.2 có key index nén (graceful fallback)
// - file hỏng/mã hoá/bảng mã lạ/LZO/engine 3.0 → lỗi rõ, không crash (AT #6)
// - progress callback

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/dictionary/models/dict_entry.dart';
import 'package:in4up/features/dictionary/services/mdx_parser.dart';

import 'mdx_test_builder.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('in4up-mdx-parser-');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<(List<DictEntry>, Object?)> parseFile(String path,
      {void Function(double, String)? onProgress}) async {
    final entries = <DictEntry>[];
    Object? error;
    final done = Completer<void>();
    final progressCalls = <double>[];
    MdxParser.parse(
      path,
      dictId: 'test-dict',
      onProgress: onProgress ??
          (p, _) {
            progressCalls.add(p);
          },
    ).listen(
      entries.add,
      onError: (Object e) => error = e,
      onDone: () => done.complete(),
    );
    await done.future.timeout(const Duration(seconds: 20));
    return (entries, error);
  }

  group('MdxParser — engine 2.0', () {
    test('UTF-8: parse headword + definition HTML', () async {
      final path = MdxTestBuilder(entries: {
        'hello': '<b>hello</b> /həˈloʊ/ — xin chào',
        'world': '<i>world</i> — thế giới',
      }).writeToFile('${tempDir.path}/en_vi_2_0.mdx');

      final (entries, error) = await parseFile(path);

      expect(error, isNull, reason: 'Không được lỗi với file hợp lệ');
      expect(entries, hasLength(2));
      expect(entries[0].headword, 'hello');
      expect(entries[0].definition, contains('xin chào'));
      expect(entries[0].dictId, 'test-dict');
      expect(entries[1].headword, 'world');
      expect(entries[1].plainDefinition, contains('thế giới'));
    });

    test('UTF-16: ngôn ngữ CJK', () async {
      final path = MdxTestBuilder(
        version: 2.0,
        utf16: true,
        entries: {
          'こんにちは': 'hello (Japanese greeting)',
          '日本語': 'Japanese language — tiếng Nhật',
        },
      ).writeToFile('${tempDir.path}/ja_en_2_0.mdx');

      final (entries, error) = await parseFile(path);

      expect(error, isNull);
      expect(entries, hasLength(2));
      expect(entries.map((e) => e.headword),
          containsAll(['こんにちは', '日本語']));
      expect(
        entries.firstWhere((e) => e.headword == '日本語').definition,
        contains('tiếng Nhật'),
      );
    });

    test('multi key block + multi record block (8 entry → 2+2 block)',
        () async {
      final entriesMap = {
        for (var i = 0; i < 8; i++) 'word$i': 'nghĩa $i — <b>entry $i</b>',
      };
      final path = MdxTestBuilder(entries: entriesMap)
          .writeToFile('${tempDir.path}/multi_block.mdx');

      final (entries, error) = await parseFile(path);

      expect(error, isNull);
      expect(entries, hasLength(8));
      for (var i = 0; i < 8; i++) {
        final e = entries.firstWhere((e) => e.headword == 'word$i');
        expect(e.definition, contains('entry $i'));
      }
    });

    test('progress callback kết thúc ở 1.0', () async {
      final path = MdxTestBuilder(entries: {
        'a': 'nghĩa a',
        'b': 'nghĩa b',
      }).writeToFile('${tempDir.path}/progress.mdx');

      final progresses = <double>[];
      final (entries, error) = await parseFile(
        path,
        onProgress: (p, message) => progresses.add(p),
      );

      expect(error, isNull);
      expect(entries, hasLength(2));
      expect(progresses, isNotEmpty);
      expect(progresses.last, 1.0);
      // Thông điệp progress locale-trung lập (không cần dịch).
      expect(progresses.length, greaterThanOrEqualTo(1));
    });
  });

  group('MdxParser — engine 1.2', () {
    test('UTF-8: số u32, key index RAW', () async {
      final path = MdxTestBuilder(
        version: 1.2,
        entries: {
          'hello': 'xin chào (1.2)',
          'world': 'thế giới (1.2)',
        },
      ).writeToFile('${tempDir.path}/v12.mdx');

      final (entries, error) = await parseFile(path);

      expect(error, isNull);
      expect(entries, hasLength(2));
      expect(entries[0].headword, 'hello');
      expect(entries[0].definition, contains('1.2'));
    });

    test('v1.2 key index nén (biến thể) → fallback giải nén vẫn đọc được',
        () async {
      final path = MdxTestBuilder(
        version: 1.2,
        forceCompressedKeyIndexV12: true,
        entries: {
          'hello': 'xin chào (fallback)',
          'world': 'thế giới (fallback)',
        },
      ).writeToFile('${tempDir.path}/v12_compressed_index.mdx');

      final (entries, error) = await parseFile(path);

      expect(error, isNull);
      expect(entries, hasLength(2));
      expect(entries[0].definition, contains('fallback'));
    });
  });

  group('MdxParser — file hỏng/lạ (AT #6: lỗi rõ, không crash)', () {
    test('file không tồn tại → MdxParseException', () async {
      final (_, error) = await parseFile('${tempDir.path}/khong_co.mdx');
      expect(error, isA<MdxParseException>());
      expect(error.toString(), contains('không tồn tại'));
    });

    test('file rác → MdxParseException "sai định dạng"', () async {
      final path = File('${tempDir.path}/garbage.mdx');
      path.writeAsBytesSync(List.generate(256, (i) => i % 251));
      final (_, error) = await parseFile(path.path);
      expect(error, isA<MdxParseException>());
    });

    test('file rỗng → MdxParseException', () async {
      final path = File('${tempDir.path}/empty.mdx');
      path.writeAsBytesSync([]);
      final (_, error) = await parseFile(path.path);
      expect(error, isA<MdxParseException>());
    });

    test('Encrypted=2 → báo chưa hỗ trợ mã hoá', () async {
      final path = MdxTestBuilder(
        headerOverrides: {'Encrypted': '2'},
        entries: {'hello': 'bất khả thi'},
      ).writeToFile('${tempDir.path}/encrypted.mdx');
      final (_, error) = await parseFile(path);
      expect(error, isA<MdxParseException>());
      expect(error.toString(), contains('mã hoá'));
    });

    test('Encoding=GBK → báo bảng mã không hỗ trợ', () async {
      final path = MdxTestBuilder(
        headerOverrides: {'Encoding': 'GBK'},
        entries: {'hello': 'không đọc được'},
      ).writeToFile('${tempDir.path}/gbk.mdx');
      final (_, error) = await parseFile(path);
      expect(error, isA<MdxParseException>());
      expect(error.toString(), contains('Bảng mã không hỗ trợ'));
    });

    test('engine 3.0 → báo chưa hỗ trợ', () async {
      final path = MdxTestBuilder(
        headerOverrides: {'GeneratedByEngineVersion': '3.0'},
        entries: {'hello': 'bản 3.0'},
      ).writeToFile('${tempDir.path}/v3.mdx');
      final (_, error) = await parseFile(path);
      expect(error, isA<MdxParseException>());
      expect(error.toString(), contains('3.0'));
    });

    test('comp=1 (LZO) → báo kiểu nén không hỗ trợ', () async {
      final path = MdxTestBuilder(
        compressType: 1,
        entries: {'hello': 'không giải nén được'},
      ).writeToFile('${tempDir.path}/lzo.mdx');
      final (_, error) = await parseFile(path);
      expect(error, isA<MdxParseException>());
      expect(error.toString(), contains('Kiểu nén không hỗ trợ'));
    });
  });

  group('MdxParser.detectLanguage', () {
    test('đọc Title từ header + ngôn ngữ từ tên file', () async {
      final path = MdxTestBuilder(entries: {'hello': 'x'})
          .writeToFile('${tempDir.path}/en_vi_bdict.mdx');
      final info = await MdxParser.detectLanguage(path);
      expect(info['name'], 'Test Dictionary');
      expect(info['source_lang'], 'en');
      expect(info['target_lang'], 'vi');
    });

    test('file không tồn tại → map rỗng, không throw', () async {
      final info = await MdxParser.detectLanguage('${tempDir.path}/nope.mdx');
      expect(info, isEmpty);
    });
  });
}
