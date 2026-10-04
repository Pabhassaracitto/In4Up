// test/word_import_parser_image_url_test.dart
//
// LOTTIE-001 — parser CSV với cột image_url (link ảnh/Lottie) ở CUỐI header:
//  1) Header map đúng alias (EN + VI).
//  2) Hàng đủ cột → imageUrl vào đúng chỗ.
//  3) meaning chứa dấu phẩy không bọc nháy (hàng dài hơn header) → căn mỏ
//     neo vẫn giữ, imageUrl vẫn là ô cuối cùng.
//  4) Hàng thiếu URL (ổn định: các cột text khác không bị xô lệch).
//  5) Hàng thiếu IPA nhưng có URL → language trượt về kề cuối (nhánh
//     shift-left riêng cho đuôi media).
//  6) Hàng thiếu language nhưng có URL → URL không bị zip nhầm vào ô
//     language.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/screens/tools/word_list/word_import_sheet.dart';

void main() {
  const header =
      'word, meaning, ipa, topic, example, language, image_url';
  const url = 'https://cdn.example.com/lottie/butterfly.json';
  final fields = WordTableParser.mapHeader(header);

  Map<String, String> parse(String row) =>
      WordTableParser.alignRow(WordTableParser.splitCsvLine(row, ','), fields);

  String g(Map<String, String> data, String key) => data[key] ?? '';

  group('mapHeader — cột image_url', () {
    test('header chuẩn 7 cột → map đủ, image_url ở cuối', () {
      expect(fields, [
        'word',
        'meaning',
        'phonetic',
        'topic',
        'example',
        'language',
        'imageUrl',
      ]);
    });

    test('alias tiếng Việt + các tên khác của cột minh họa', () {
      expect(WordTableParser.mapHeader('từ vựng, hình ảnh'),
          ['word', 'imageUrl']);
      expect(WordTableParser.mapHeader('word, ảnh minh họa'),
          ['word', 'imageUrl']);
      expect(WordTableParser.mapHeader('word, lottie'), ['word', 'imageUrl']);
      expect(
          WordTableParser.mapHeader('word, illustration'), ['word', 'imageUrl']);
    });
  });

  group('alignRow — hàng có image_url', () {
    test('hàng đủ 7 cột → imageUrl vào đúng chỗ', () {
      final data = parse(
        'butterfly, con bướm, /ˈbʌtərflaɪ/, animals, A butterfly lands on the flower, en, $url',
      );
      expect(g(data, 'word'), 'butterfly');
      expect(g(data, 'meaning'), 'con bướm');
      expect(g(data, 'phonetic'), '/ˈbʌtərflaɪ/');
      expect(g(data, 'topic'), 'animals');
      expect(g(data, 'example'), 'A butterfly lands on the flower');
      expect(g(data, 'language'), 'en');
      expect(g(data, 'imageUrl'), url);
    });

    test('meaning chứa phẩy không bọc nháy → căn mỏ neo, imageUrl vẫn đúng',
        () {
      final data = parse(
        'abundance, sự phong phú, dồi dào, /əˈbʌndəns/, nature, There is an abundance of flowers, en, $url',
      );
      expect(g(data, 'word'), 'abundance');
      expect(g(data, 'meaning'), 'sự phong phú, dồi dào');
      expect(g(data, 'phonetic'), '/əˈbʌndəns/');
      expect(g(data, 'topic'), 'nature');
      expect(g(data, 'example'), 'There is an abundance of flowers');
      expect(g(data, 'language'), 'en');
      expect(g(data, 'imageUrl'), url);
    });

    test('hàng thiếu URL (6 ô / 7 cột) → language đúng, imageUrl rỗng', () {
      final data = parse(
        'abundance, sự phong phú, /əˈbʌndəns/, nature, There is an abundance of flowers, en',
      );
      expect(g(data, 'language'), 'en');
      expect(g(data, 'imageUrl'), '');
      expect(g(data, 'example'), 'There is an abundance of flowers');
    });

    test('hàng thiếu IPA nhưng có URL → các ô sau ipa trượt trái đúng', () {
      final data = parse(
        'abundance, sự phong phú, nature, There is an abundance of flowers, en, $url',
      );
      expect(g(data, 'word'), 'abundance');
      expect(g(data, 'meaning'), 'sự phong phú');
      expect(g(data, 'phonetic'), '');
      expect(g(data, 'topic'), 'nature');
      expect(g(data, 'example'), 'There is an abundance of flowers');
      expect(g(data, 'language'), 'en');
      expect(g(data, 'imageUrl'), url);
    });

    test('hàng thiếu language nhưng có URL → URL về imageUrl, language rỗng',
        () {
      final data = parse(
        'abundance, sự phong phú, /əˈbʌndəns/, nature, There is an abundance of flowers, $url',
      );
      expect(g(data, 'phonetic'), '/əˈbʌndəns/');
      expect(g(data, 'topic'), 'nature');
      expect(g(data, 'example'), 'There is an abundance of flowers');
      expect(g(data, 'language'), '');
      expect(g(data, 'imageUrl'), url);
    });

    test('URL ảnh tĩnh (.webp) cũng vào imageUrl (widget tự phân loại)', () {
      const img = 'https://cdn.example.com/img/butterfly.webp';
      final data = parse('butterfly, con bướm, , , , en, $img');
      expect(g(data, 'imageUrl'), img);
    });
  });
}
