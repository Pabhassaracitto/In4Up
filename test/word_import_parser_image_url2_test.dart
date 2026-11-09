// test/word_import_parser_image_url2_test.dart
//
// VOCAB-MEDIA-003 (ADR-0013) — CSV có HAI cột minh họa ở cuối header
// (`…, language, image_url, image_url_2`):
//  1) Header map đúng alias (EN + VI + "2").
//  2) Hàng đủ cột → 2 URL vào đúng 2 chỗ.
//  3) Hàng chỉ có 1 URL (thiếu cột 2) → ổn định, không xô lệch cột text.
//  4) Hàng thiếu IPA nhưng có 2 URL → language trượt, 2 URL vẫn đúng chỗ.
//  5) Hàng thiếu cả language (URL đứng cuối) → URL không nhét vào ô language.
//  6) Header CŨ (1 cột image_url) vẫn hành xử y như trước (hồi quy).

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/screens/tools/word_list/word_import_sheet.dart';

void main() {
  const url1 = 'https://cdn.example.com/static/butterfly.webp';
  const url2 = 'https://cdn.example.com/lottie/butterfly.json';

  Map<String, String> parse(String header, String row) => WordTableParser.alignRow(
        WordTableParser.splitCsvLine(row, ','),
        WordTableParser.mapHeader(header),
      );

  String g(Map<String, String> data, String key) => data[key] ?? '';

  group('mapHeader — cột image_url_2', () {
    test('header 8 cột → map đủ, 2 cột media ở cuối', () {
      expect(
        WordTableParser.mapHeader(
            'word, meaning, ipa, topic, example, language, image_url, image_url_2'),
        [
          'word',
          'meaning',
          'phonetic',
          'topic',
          'example',
          'language',
          'imageUrl',
          'imageUrl2',
        ],
      );
    });

    test('alias khác của cột media 2 (ảnh 2 / animation2 / image2)', () {
      expect(WordTableParser.mapHeader('word, ảnh 2'),
          ['word', 'imageUrl2']);
      expect(WordTableParser.mapHeader('word, animation2'),
          ['word', 'imageUrl2']);
      expect(WordTableParser.mapHeader('word, image2'),
          ['word', 'imageUrl2']);
      expect(WordTableParser.mapHeader('word, minh họa 2'),
          ['word', 'imageUrl2']);
    });

    test('KHÔNG va chạm normKey: 1 cột image_url ≠ imageUrl2 (hậu tố "2")', () {
      // `normKey` bỏ chữ số ⇒ `image_url_2` và `image_url` cùng thành
      // `imageurl`; nếu nhét alias `…_2` thẳng vào bảng alias thì bản ghi thêm
      // sau ĐÈ bản ghi trước và header 1 cột bị map nhầm sang imageUrl2.
      expect(WordTableParser.mapHeader('word, image_url'),
          ['word', 'imageUrl']);
      expect(WordTableParser.mapHeader('word, image_url, image_url_2'),
          ['word', 'imageUrl', 'imageUrl2']);
      expect(WordTableParser.resolveHeaderField('image_url_2'), 'imageUrl2');
      expect(WordTableParser.resolveHeaderField('image_url'), 'imageUrl');
      // Alias tiếng Việt: có/không hậu tố "2" phải khác nhau.
      expect(WordTableParser.mapHeader('word, ảnh'), ['word', 'imageUrl']);
      expect(WordTableParser.mapHeader('word, ảnh 2'), ['word', 'imageUrl2']);
      expect(WordTableParser.mapHeader('word, hình'), ['word', 'imageUrl']);
      expect(WordTableParser.mapHeader('word, hình 2'), ['word', 'imageUrl2']);
    });

    test('header CŨ 7 cột vẫn map y như trước (không hồi quy)', () {
      expect(
        WordTableParser.mapHeader(
            'word, meaning, ipa, topic, example, language, image_url'),
        [
          'word',
          'meaning',
          'phonetic',
          'topic',
          'example',
          'language',
          'imageUrl',
        ],
      );
    });
  });

  group('alignRow — hàng có image_url_2', () {
    const header2 =
        'word, meaning, ipa, topic, example, language, image_url, image_url_2';

    test('hàng đủ 8 cột → 2 URL vào đúng 2 chỗ', () {
      final data = parse(header2,
          'butterfly, con bướm, /ˈbʌtərflaɪ/, animals, A butterfly lands, en, $url1, $url2');
      expect(g(data, 'word'), 'butterfly');
      expect(g(data, 'meaning'), 'con bướm');
      expect(g(data, 'phonetic'), '/ˈbʌtərflaɪ/');
      expect(g(data, 'topic'), 'animals');
      expect(g(data, 'example'), 'A butterfly lands');
      expect(g(data, 'language'), 'en');
      expect(g(data, 'imageUrl'), url1);
      expect(g(data, 'imageUrl2'), url2);
    });

    test('hàng 7 ô (thiếu URL thứ hai) → các cột text không xô lệch', () {
      final data = parse(header2,
          'butterfly, con bướm, /ˈbʌtərflaɪ/, animals, A butterfly lands, en, $url1');
      expect(g(data, 'language'), 'en');
      expect(g(data, 'imageUrl'), url1);
      expect(g(data, 'imageUrl2'), '');
    });

    test('meaning chứa phẩy không bọc nháy → căn mỏ neo vẫn đúng 2 URL', () {
      final data = parse(header2,
          'abundance, sự phong phú, dồi dào, /əˈbʌndəns/, nature, There is an abundance, en, $url1, $url2');
      expect(g(data, 'meaning'), 'sự phong phú, dồi dào');
      expect(g(data, 'phonetic'), '/əˈbʌndəns/');
      expect(g(data, 'language'), 'en');
      expect(g(data, 'imageUrl'), url1);
      expect(g(data, 'imageUrl2'), url2);
    });

    test('thiếu IPA nhưng có 2 URL → language trượt về kề cụm media', () {
      final data = parse(header2,
          'butterfly, con bướm, animals, A butterfly lands, en, $url1, $url2');
      expect(g(data, 'word'), 'butterfly');
      expect(g(data, 'meaning'), 'con bướm');
      expect(g(data, 'topic'), 'animals');
      expect(g(data, 'example'), 'A butterfly lands');
      expect(g(data, 'language'), 'en');
      expect(g(data, 'imageUrl'), url1);
      expect(g(data, 'imageUrl2'), url2);
    });

    test('thiếu cột language (7 ô: 2 URL đứng cuối) → URL không vào ô language',
        () {
      // Hàng 7 ô của header 8 cột có 2 nghĩa; đây là nghĩa "thiếu language"
      // (ô language bị URL chiếm) → sửa lại, đẩy URL về đúng 2 cột media.
      final data = parse(header2,
          'butterfly, con bướm, /ˈbʌtərflaɪ/, animals, A butterfly lands, $url1, $url2');
      expect(g(data, 'language'), '');
      expect(g(data, 'imageUrl'), url1);
      expect(g(data, 'imageUrl2'), url2);
      expect(g(data, 'example'), 'A butterfly lands');
    });

    test('hàng 7 ô nghĩa "thiếu URL 2" → language GIỮ NGUYÊN (không sửa nhầm)',
        () {
      final data = parse(header2,
          'butterfly, con bướm, /ˈbʌtərflaɪ/, animals, A butterfly lands, en, $url1');
      expect(g(data, 'language'), 'en');
      expect(g(data, 'imageUrl'), url1);
      expect(g(data, 'imageUrl2'), '');
    });
  });

  group('hồi quy — header 1 cột media vẫn như LOTTIE-001', () {
    const header1 =
        'word, meaning, ipa, topic, example, language, image_url';

    test('hàng đủ 7 cột → imageUrl đúng, imageUrl2 không xuất hiện', () {
      final data = parse(header1,
          'butterfly, con bướm, /ˈbʌtərflaɪ/, animals, A butterfly lands, en, $url1');
      expect(g(data, 'language'), 'en');
      expect(g(data, 'imageUrl'), url1);
      expect(data.containsKey('imageUrl2'), isFalse);
    });

    test('thiếu IPA nhưng có URL → vẫn nhận đúng (như trước)', () {
      final data = parse(header1,
          'butterfly, con bướm, animals, A butterfly lands, en, $url1');
      expect(g(data, 'language'), 'en');
      expect(g(data, 'imageUrl'), url1);
    });
  });
}
