// DICT-SQLITE-001 (2026-10-28) — máy bắt cho "import từ điển đuôi .db".
//
// Trước bản này đường import CHỈ nhận `.mdx` (kèm `.mdd`/`.css`):
//   * `DictImportService` lọc `allowedExtensions: ['mdx','mdd','css']`
//     ⇒ file `.db` bị bộ chọn (SAF + file_picker) loại ngay từ đầu;
//   * `DictBundleScanner.scan()` không biết `.db` ⇒ có chọn được cũng báo
//     "Không tìm thấy file .mdx nào trong nguồn đã chọn".
//
// Test này khoá 3 việc:
//   1. scanner nhận đúng tên file SQLite (và bỏ qua index tạm của chính app);
//   2. luật ĐOÁN BẢNG/CỘT (`pickDefinitionMapping`) — hàm thuần, đây là chỗ
//      dễ sai nhất khi gặp file .db lạ;
//   3. nhận diện cặp ngôn ngữ từ tên file (chỉ để hiện nhãn).
//
// Không cần SQLite thật ⇒ chạy được trên CI host VM.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/dictionary/services/dict_bundle_scanner.dart';
import 'package:in4up/features/dictionary/services/dict_sqlite_importer.dart';

SqliteSourceTable t(
  String name,
  List<String> columns, {
  int rows = 100,
}) =>
    SqliteSourceTable(name: name, columns: columns, rowCount: rows);

void main() {
  group('DictBundleScanner.isSqliteName', () {
    test('nhận .db / .sqlite / .sqlite3, không phân biệt hoa thường', () {
      expect(DictBundleScanner.isSqliteName('anh_viet.db'), isTrue);
      expect(DictBundleScanner.isSqliteName('Oxford.DB'), isTrue);
      expect(DictBundleScanner.isSqliteName('dict.sqlite'), isTrue);
      expect(DictBundleScanner.isSqliteName('dict.SQLite3'), isTrue);
    });

    test('không nhận index tạm của chính app (tránh tự import rác)', () {
      expect(
        DictBundleScanner.isSqliteName(
          'abc123.dict.sqlite.rebuilding-1730000000000000',
        ),
        isFalse,
      );
      expect(
        DictBundleScanner.isSqliteName(
          'abc123.dict.sqlite.previous-1730000000000000',
        ),
        isFalse,
      );
    });

    test('không nhận đuôi khác (.mdx/.mdd/.css/.dbx)', () {
      expect(DictBundleScanner.isSqliteName('a.mdx'), isFalse);
      expect(DictBundleScanner.isSqliteName('a.mdd'), isFalse);
      expect(DictBundleScanner.isSqliteName('a.css'), isFalse);
      expect(DictBundleScanner.isSqliteName('a.dbx'), isFalse);
      expect(DictBundleScanner.isSqliteName('a.db.bak'), isFalse);
    });
  });

  group('pickDefinitionMapping — đoán bảng & cột', () {
    test('schema của chính app (dict_entries) — tin cậy cao', () {
      final mapping = pickDefinitionMapping([
        t('dict_entries', [
          'id',
          'headword',
          'definition',
          'phonetic',
          'audio_path',
          'part_of_speech',
          'dict_id',
        ], rows: 50000),
      ])!;
      expect(mapping.table, 'dict_entries');
      expect(mapping.headwordColumn, 'headword');
      expect(mapping.definitionColumn, 'definition');
      expect(mapping.phoneticColumn, 'phonetic');
      expect(mapping.partOfSpeechColumn, 'part_of_speech');
      expect(mapping.isConfident, isTrue);
    });

    test('bảng kiểu StarDict/Wiktionary: word + definition', () {
      final mapping = pickDefinitionMapping([
        t('stardict', ['id', 'word', 'definition'], rows: 12000),
      ])!;
      expect(mapping.headwordColumn, 'word');
      expect(mapping.definitionColumn, 'definition');
    });

    test('tên cột viết kiểu camelCase / viết tắt vẫn nhận', () {
      final mapping = pickDefinitionMapping([
        t('entries', ['WordId', 'HeadWord', 'MeaningHtml', 'Pos'], rows: 900),
      ])!;
      expect(mapping.headwordColumn, 'HeadWord');
      expect(mapping.definitionColumn, 'MeaningHtml');
      expect(mapping.partOfSpeechColumn, 'Pos');
    });

    test('nhiều bảng: chọn bảng giống từ điển, KHÔNG chọn bảng phụ', () {
      final mapping = pickDefinitionMapping([
        t('history', ['id', 'query', 'at'], rows: 300),
        t('settings', ['key', 'value'], rows: 5),
        t('words', ['id', 'term', 'gloss'], rows: 8000),
      ])!;
      expect(mapping.table, 'words');
      expect(mapping.headwordColumn, 'term');
      expect(mapping.definitionColumn, 'gloss');
    });

    test('cột vô danh (c1/c2) vẫn dùng được nhưng tin cậy thấp', () {
      final mapping = pickDefinitionMapping([
        t('data', ['c1', 'c2'], rows: 400),
      ])!;
      expect(mapping.headwordColumn, 'c1');
      expect(mapping.definitionColumn, 'c2');
      expect(mapping.isConfident, isFalse);
    });

    test('bảng hệ thống bị bỏ qua', () {
      final mapping = pickDefinitionMapping([
        t('sqlite_sequence', ['name', 'seq'], rows: 2),
        t('android_metadata', ['locale'], rows: 1),
        t('room_master_table', ['id', 'identity_hash'], rows: 1),
        t('words', ['word', 'meaning'], rows: 100),
      ])!;
      expect(mapping.table, 'words');
    });

    test('không có bảng dùng được → null (để UI báo rõ)', () {
      expect(pickDefinitionMapping(const []), isNull);
      expect(pickDefinitionMapping([t('one_col', ['only'], rows: 10)]), isNull);
    });

    test('không bao giờ chọn cột ID làm từ khoá', () {
      final mapping = pickDefinitionMapping([
        t('entries', ['id', 'word', 'definition'], rows: 100),
      ])!;
      expect(mapping.headwordColumn, isNot('id'));
      expect(mapping.definitionColumn, isNot('id'));
    });
  });

  group('detectLangPairFromFileName', () {
    test('mã 2 chữ: en-vi, zh_en', () {
      expect(detectLangPairFromFileName('en-vi.db').source, 'EN');
      expect(detectLangPairFromFileName('en-vi.db').target, 'VI');
      expect(detectLangPairFromFileName('zh_en.sqlite').source, 'ZH');
      expect(detectLangPairFromFileName('zh_en.sqlite').target, 'EN');
    });

    test('tên tiếng Việt không dấu / có dấu', () {
      expect(detectLangPairFromFileName('anh_viet.db').source, 'EN');
      expect(detectLangPairFromFileName('anh_viet.db').target, 'VI');
      expect(detectLangPairFromFileName('Pháp-Việt.db').source, 'FR');
      expect(detectLangPairFromFileName('Pháp-Việt.db').target, 'VI');
    });

    test('không đoán được thì để null (không bịa)', () {
      final pair = detectLangPairFromFileName('Oxford Advanced.db');
      expect(pair.source, isNull);
      expect(pair.target, isNull);
    });
  });
}
