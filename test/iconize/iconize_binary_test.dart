// test/iconize/iconize_binary_test.dart
//
// ICONIZE-001b — reader nhị phân đọc ĐÚNG asset thật trong assets/iconize/
// (sinh bởi tool/iconize/build_icon_assets.py). Hợp đồng format:
// tool/iconize/README.md. Test chạy từ gốc repo (flutter test).

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/iconize/data/iconize_binary.dart';
import 'package:in4up/features/iconize/models/iconize_span.dart';

Uint8List _load(String name) =>
    File('assets/iconize/$name').readAsBytesSync();

void main() {
  group('readIconizeHeader', () {
    test('magic sai → IconizeBinaryFormatException', () {
      final bad = Uint8List.fromList([
        ...'XXXX0001'.codeUnits,
        1, 0, 0, 0, 0, 0, 0, 0,
      ]);
      expect(() => readIconizeHeader(bad, 't'),
          throwsA(isA<IconizeBinaryFormatException>()));
    });

    test('file cụt → IconizeBinaryFormatException', () {
      expect(() => readIconizeHeader(Uint8List(7), 't'),
          throwsA(isA<IconizeBinaryFormatException>()));
    });
  });

  group('ConcretenessTable (asset thật)', () {
    final table = ConcretenessTable(_load('concreteness.bin'));

    test('cat = danh từ, concreteness >= 4.0', () {
      final e = table.lookup('cat');
      expect(e, isNotNull);
      expect(e!.pos, IconizePos.noun);
      expect(e.concreteness, greaterThanOrEqualTo(4.0));
    });

    test('từ trừu tượng dưới 3.5 không có mặt (freedom)', () {
      expect(table.lookup('freedom'), isNull);
      expect(table.contains('freedom'), isFalse);
    });

    test('biên bảng: không khớp trước phần tử đầu / sau phần tử cuối', () {
      expect(table.lookup('aaaaaaaaaaaa'), isNull);
      expect(table.lookup('zzzzzzzzzzzz'), isNull);
    });
  });

  group('IconIndexTable + IconsBundle (asset thật)', () {
    final index = IconIndexTable(_load('icon_index.bin'));
    final bundle = IconsBundle(_load('icons_bundle.bin'));

    test('cat|NOUN có icon; payload là SVG', () {
      final id = index.lookup('cat|NOUN');
      expect(id, isNotNull);
      expect(id, inInclusiveRange(0, bundle.count - 1));
      final svg = String.fromCharCodes(bundle.svgBytes(id!));
      expect(svg.trimLeft(), startsWith('<svg'));
      expect(bundle.name(id), isNotEmpty);
    });

    test('khóa sai POS không khớp (cat|ADJ)', () {
      expect(index.lookup('cat|ADJ'), isNull);
    });

    test('động từ không vào index v1 (run|VERB — chốt #1)', () {
      expect(index.lookup('run|VERB'), isNull);
    });

    test('iconId ngoài biên → exception, không crash im lặng', () {
      expect(() => bundle.svgBytes(bundle.count),
          throwsA(isA<IconizeBinaryFormatException>()));
      expect(() => bundle.svgBytes(-1),
          throwsA(isA<IconizeBinaryFormatException>()));
    });

    test('mọi iconId trong index đều trỏ vào bundle hợp lệ (10 mẫu)', () {
      for (final key in [
        'dog|NOUN', 'apple|NOUN', 'mouse|NOUN', 'bank|NOUN', 'house|NOUN',
        'tree|NOUN', 'fish|NOUN', 'bird|NOUN', 'book|NOUN', 'egg|NOUN',
      ]) {
        final id = index.lookup(key);
        expect(id, isNotNull, reason: '$key phải có trong index');
        final svg = bundle.svgBytes(id!);
        expect(svg.length, greaterThan(50), reason: '$key SVG quá nhỏ');
      }
    });

    // ICONIZE-001d: tầng render tra ngược "bundle:<tên>" → iconId.
    test('idForName khứ hồi với name() + tên lạ → null', () {
      for (final id in [0, bundle.count ~/ 2, bundle.count - 1]) {
        expect(bundle.idForName(bundle.name(id)), id);
      }
      expect(bundle.idForName('khong-ton-tai'), isNull);
      expect(bundle.idForName(''), isNull);
    });
  });
}
