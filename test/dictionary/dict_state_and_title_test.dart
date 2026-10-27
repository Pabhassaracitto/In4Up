// DICT-TITLE-001 / DICT-STATE-001 / DICT-ORDER-001 — 4 việc owner báo
// 2026-10-27, kiểm phần THUẦN (không Flutter, không I/O, chạy được trên CI).
//
// 1. Tên bộ từ điển sau khi cài hiện HTML thô:
//    `<html><b>SImple English Dictionary(EN-EN)</b></html>`
// 2. Tên bộ Anh–Việt hiện dấu `\` của định dạng MDX:
//    `Từ\điẻn\ Anh -\ Việt\ v1.1`
// 3. Cài xong mà nút "Tải & cài" vẫn xanh ⇒ nhận biết "đã cài" theo packId,
//    không theo tên (tên từ điển do người dựng .mdx đặt, khác tên trong
//    `packs.json`).
// 4. Đổi thứ tự ưu tiên bằng kéo thả.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/dictionary/models/dict_info.dart';
import 'package:in4up/features/dictionary/models/dict_pack.dart';
import 'package:in4up/features/dictionary/services/dict_list_order.dart';
import 'package:in4up/features/dictionary/services/dict_title_cleaner.dart';

DictInfo _dict(String id, {String? name, String? packId}) => DictInfo(
      id: id,
      name: name ?? id,
      entryCount: 10,
      dbPath: '/tmp/$id.db',
      importedAt: DateTime(2026, 10, 27),
      packId: packId,
    );

DictPack _pack({String id = 'en-en-simple-wiktionary', String name = 'Anh → Anh (Simple English Wiktionary)'}) =>
    DictPack(
      id: id,
      name: name,
      downloadUrl: 'https://example.com/a.mdx',
    );

void main() {
  group('DictTitleCleaner — tên bộ từ điển đọc được', () {
    test('bóc HTML của header .mdx (lỗi owner báo: EN-EN)', () {
      expect(
        DictTitleCleaner.clean(
          '<html><b>SImple English Dictionary(EN-EN)</b></html>',
        ),
        'SImple English Dictionary(EN-EN)',
      );
    });

    test('bỏ dấu \\ của định dạng MDX (lỗi owner báo: Anh–Việt)', () {
      expect(
        DictTitleCleaner.clean(r'Từ\điẻn\ Anh -\ Việt\ v1.1'),
        'Từ điẻn Anh - Việt v1.1',
      );
    });

    test('giải entity + bóc span có style', () {
      expect(
        DictTitleCleaner.clean(
          '<span style="color:red">Anh &amp; Việt</span>',
        ),
        'Anh & Việt',
      );
      expect(
        DictTitleCleaner.clean('&#84;ừ điển&#46;'),
        'Từ điển.',
      );
    });

    test('tên đã sạch giữ nguyên; tên rỗng ⇒ null', () {
      expect(DictTitleCleaner.clean('Từ điển Anh - Việt v1.1'),
          'Từ điển Anh - Việt v1.1');
      expect(DictTitleCleaner.clean('   '), isNull);
      expect(DictTitleCleaner.clean(null), isNull);
      expect(DictTitleCleaner.clean('<br>'), isNull);
    });

    test('không nuốt nội dung giữa hai dấu < > thật', () {
      expect(DictTitleCleaner.clean('a < b > c'), 'a < b > c');
    });

    test('cắt tên quá dài, giữ đuôi …', () {
      final long = DictTitleCleaner.clean('A' * 200)!;
      expect(long.length, lessThanOrEqualTo(DictTitleCleaner.maxLength));
      expect(long.endsWith('…'), isTrue);
    });

    test('needsClean — chỉ đúng khi bản ghi cũ còn bẩn (để nâng cấp manifest)',
        () {
      expect(
        DictTitleCleaner.needsClean('<html><b>X(EN-EN)</b></html>'),
        isTrue,
      );
      expect(DictTitleCleaner.needsClean('Tên sạch'), isFalse);
      expect(DictTitleCleaner.needsClean(null), isFalse);
    });
  });

  group('isPackInstalled — cài xong thì nút phải đổi trạng thái', () {
    test('khớp theo packId dù TÊN khác hoàn toàn (gốc lỗi "vẫn xanh")', () {
      final installed = <DictInfo>[
        _dict('d1', name: 'SImple English Dictionary(EN-EN)',
            packId: 'en-en-simple-wiktionary'),
      ];
      expect(isPackInstalled(_pack(), installed), isTrue);
    });

    test('chưa cài ⇒ false', () {
      expect(isPackInstalled(_pack(), const <DictInfo>[]), isFalse);
      expect(
        isPackInstalled(_pack(), <DictInfo>[_dict('other', name: 'Khác')]),
        isFalse,
      );
    });

    test('bản cài CŨ (không có packId) nhận ra qua tên file đã tải', () {
      // Đây đúng là tình huống máy owner: cài bằng 1.17.0 ⇒ manifest không có
      // `pack_id`, tên từ điển lấy từ header .mdx nên không khớp tên bộ.
      final pack = DictPack(
        id: 'en-en-simple-wiktionary',
        name: 'Anh → Anh (Simple English Wiktionary)',
        downloadUrl:
            'https://raw.githubusercontent.com/x/y/main/simple-en.mdx',
      );
      final installed = <DictInfo>[
        _dict('d1', name: 'SImple English Dictionary(EN-EN)')
            .copyWith(sourceFileName: 'simple-en.mdx'),
      ];
      expect(isPackInstalled(pack, installed), isTrue);
    });

    test('packSourceFileName lấy đúng basename, bỏ query/hash', () {
      expect(
        packSourceFileName('https://h/a/b/star_anhviet.mdx?raw=1#x'),
        'star_anhviet.mdx',
      );
      expect(packSourceFileName(''), '');
    });

    test('đường lùi cho bộ cài bằng bản cũ (manifest chưa có packId)', () {
      // Tên từ điển chứa id bộ ⇒ coi như đã cài.
      expect(
        isPackInstalled(
          _pack(),
          <DictInfo>[_dict('d1', name: 'en-en-simple-wiktionary (mdx)')],
        ),
        isTrue,
      );
      // Hoặc trùng tên bộ.
      expect(
        isPackInstalled(
          _pack(),
          <DictInfo>[
            _dict('d1', name: 'Anh → Anh (Simple English Wiktionary)'),
          ],
        ),
        isTrue,
      );
    });
  });

  group('applyReorder — chỉ số của ReorderableListView', () {
    test('kéo xuống: newIndex lớn hơn chỉ số thật 1 nên phải trừ 1', () {
      final out = applyReorder<String>(<String>['a', 'b', 'c'], 0, 2);
      expect(out, <String>['b', 'a', 'c']);
    });

    test('kéo lên không trừ', () {
      final out = applyReorder<String>(<String>['a', 'b', 'c'], 2, 0);
      expect(out, <String>['c', 'a', 'b']);
    });

    test('chỉ số ngoài phạm vi ⇒ trả nguyên bản sao, không ném', () {
      final src = <String>['a', 'b'];
      expect(applyReorder<String>(src, 5, 0), <String>['a', 'b']);
      expect(applyReorder<String>(src, -1, 0), <String>['a', 'b']);
      expect(applyReorder<String>(<String>[], 0, 0), isEmpty);
    });

    test('luôn trả bản sao (không sửa list gốc)', () {
      final src = <String>['a', 'b'];
      applyReorder<String>(src, 0, 1);
      expect(src, <String>['a', 'b']);
    });
  });

  group('applyDictOrder — thứ tự ưu tiên lưu vào manifest', () {
    test('sắp theo id cho trước', () {
      final dicts = <DictInfo>[_dict('a'), _dict('b'), _dict('c')];
      final out = applyDictOrder(dicts, <String>['c', 'a', 'b']);
      expect(out.map((d) => d.id).toList(), <String>['c', 'a', 'b']);
    });

    test('bộ mới cài (không có trong danh sách cũ) vẫn được giữ, ở cuối', () {
      final dicts = <DictInfo>[_dict('a'), _dict('b'), _dict('new')];
      final out = applyDictOrder(dicts, <String>['b', 'a']);
      expect(out.map((d) => d.id).toList(), <String>['b', 'a', 'new']);
    });

    test('id đã bị xoá / trùng bị bỏ qua', () {
      final dicts = <DictInfo>[_dict('a'), _dict('b')];
      final out =
          applyDictOrder(dicts, <String>['ghost', 'a', 'a', 'b']);
      expect(out.map((d) => d.id).toList(), <String>['a', 'b']);
    });
  });

  group('DictInfo.packId — đi qua manifest (json) với manifest cũ', () {
    test('round-trip giữ packId', () {
      final info = _dict('d1', name: 'X', packId: 'en-vi-ovdp');
      final restored = DictInfo.fromJson(info.toJson());
      expect(restored.packId, 'en-vi-ovdp');
    });

    test('manifest cũ không có pack_id ⇒ null, không ném', () {
      final json = _dict('d1').toJson()..remove('pack_id');
      expect(DictInfo.fromJson(json).packId, isNull);
    });
  });
}
