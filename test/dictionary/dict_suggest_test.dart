// ADR-0018 (P1) — ô tìm của MÀN TỪ ĐIỂN cần GỢI Ý theo tiền tố.
//
// Vì sao có test này thay cho test widget của màn hình:
//   * `DictionaryService.lookupPrefix()` (bản cũ) DỪNG ở bộ từ điển đầu tiên
//     có kết quả. Người dùng có 2 bộ (Anh–Việt + Anh–Anh) sẽ chỉ thấy gợi ý
//     của bộ đứng đầu ⇒ phải có `suggest()` gộp + khử trùng.
//   * `lookup(word, dictId: …)` là thứ làm chip lọc bộ hoạt động; nếu ai đó bỏ
//     tham số này, chip sẽ "chọn bộ" mà kết quả vẫn lẫn — test này bắt.
//
// Chạy SQLite THẬT qua `sqflite_common_ffi` với `test()` thường (KHÔNG phải
// `testWidgets`): tổ hợp widget + plugin thật treo trên CI (xem ghi chú ở
// `.github/workflows/app_analyze.yml`, bước DICT-CLEAN-001).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/dictionary/models/dict_info.dart';
import 'package:in4up/features/dictionary/services/dictionary_service.dart';
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
    tempDir = await Directory.systemTemp.createTemp('in4up-dict-suggest-');
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

  Future<DictInfo> install(String name, Map<String, String> entries) async {
    final mdx = MdxTestBuilder(entries: entries)
        .writeToFile('${tempDir.path}/$name.mdx');
    final outcome = await DictionaryService.instance.importDictionaryBundle(
      absoluteFilePaths: <String>[mdx],
      rootPath: '',
      mode: DictStorageMode.linked,
    );
    expect(outcome.isSuccess, isTrue,
        reason: 'cài từ điển mẫu "$name" phải thành công');
    return outcome.imported.first;
  }

  /// Hai bộ: A có "hello/help/helium", B có "hello" (trùng) + "helper".
  Future<(DictInfo, DictInfo)> installTwo() async {
    final a = await install('en_vi_suggest_a', <String, String>{
      'hello': 'lời chào',
      'help': 'giúp đỡ',
      'helium': 'khí heli',
      'world': 'thế giới',
    });
    final b = await install('en_en_suggest_b', <String, String>{
      'hello': 'a greeting',
      'helper': 'one who helps',
    });
    expect(DictionaryService.instance.enabledDictionaries, hasLength(2),
        reason: 'phải cài được 2 bộ');
    return (a, b);
  }

  group('DictionaryService.suggest', () {
    test('gộp gợi ý từ MỌI bộ đang bật (bản lookupPrefix cũ chỉ lấy bộ đầu)',
        () async {
      await installTwo();

      final out = await DictionaryService.instance.suggest('hel');

      expect(out, contains('hello'));
      expect(out, contains('help'));
      expect(out, contains('helium'));
      // Chỉ có ở bộ thứ HAI — chính là ca mà `lookupPrefix()` cũ bỏ sót.
      expect(out, contains('helper'));
      expect(out, isNot(contains('world')));
    });

    test('khử trùng không phân biệt hoa/thường (2 bộ cùng có "hello")', () async {
      await installTwo();

      final out = await DictionaryService.instance.suggest('hel');
      final lower = out.map((word) => word.toLowerCase()).toList();

      expect(lower.where((word) => word == 'hello').length, 1,
          reason: '"hello" có ở cả 2 bộ nhưng chỉ được gợi ý 1 lần');
      expect(lower.length, lower.toSet().length);
    });

    test('tôn trọng limit', () async {
      await installTwo();

      final out = await DictionaryService.instance.suggest('hel', limit: 2);
      expect(out, hasLength(2));
    });

    test('dictId ⇒ chỉ gợi ý trong bộ đó', () async {
      final (_, b) = await installTwo();

      final out = await DictionaryService.instance.suggest(
        'hel',
        dictId: b.id,
      );

      expect(out, contains('helper'));
      expect(out, isNot(contains('helium')),
          reason: '"helium" chỉ có ở bộ Anh–Việt');
    });

    test('tiền tố rỗng / limit 0 ⇒ danh sách rỗng, không ném lỗi', () async {
      await installTwo();

      expect(await DictionaryService.instance.suggest('   '), isEmpty);
      expect(await DictionaryService.instance.suggest('hel', limit: 0),
          isEmpty);
    });

    test('không tiền tố nào khớp ⇒ rỗng (màn hình hiện "có phải bạn muốn")',
        () async {
      await installTwo();
      expect(await DictionaryService.instance.suggest('zzz'), isEmpty);
    });
  });

  group('DictionaryService.lookup(dictId:)', () {
    test('lọc đúng một bộ — chip lọc của màn Từ điển dựa vào đây', () async {
      final (a, b) = await installTwo();

      final fromEnEn =
          await DictionaryService.instance.lookup('hello', dictId: b.id);
      final fromEnVi =
          await DictionaryService.instance.lookup('hello', dictId: a.id);

      expect(fromEnEn, hasLength(1));
      expect(fromEnEn.first.plainDefinition, contains('a greeting'));
      expect(fromEnVi, hasLength(1));
      expect(fromEnVi.first.plainDefinition, contains('lời chào'));
    });

    test('không truyền dictId ⇒ gộp cả hai bộ (mặc định "Tất cả")', () async {
      await installTwo();
      final all = await DictionaryService.instance.lookup('hello');
      expect(all, hasLength(2));
    });

    test('từ chỉ có ở bộ kia ⇒ lọc theo bộ này trả rỗng', () async {
      final (_, b) = await installTwo();

      expect(
        await DictionaryService.instance.lookup('helium', dictId: b.id),
        isEmpty,
      );
    });
  });
}
