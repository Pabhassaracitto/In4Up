// test/word_import_parser_test.dart
//
// Fix import WordList "dán đúng hướng dẫn mà chưa chính xác":
//  1) Header `example_simple`/`example_complex` bị bỏ sót (key alias có
//     gạch dưới, key normalize không có) → giờ mapping đủ 8 cột.
//  2) meaning/example chứa dấu phẩy KHÔNG bọc nháy (Gemini hay sinh vậy)
//     → hàng dài hơn header → trước đây cột bị lệch phải; giờ căn lại
//     bằng mỏ neo word/ipa/language + chọn cột hấp thụ thông minh.
//  3) Header tiếng Việt có dấu (từ vựng, phiên âm, ví dụ đơn...) map đúng.
//  4) Hàng thiếu cột (thiếu IPA, thiếu cột cuối) vẫn nạp đúng chỗ.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/screens/tools/word_list/word_import_sheet.dart';

void main() {
  const header =
      'word, meaning, ipa, topic, example, example_simple, example_complex, language';
  final fields = WordTableParser.mapHeader(header);

  Map<String, String> parse(String row) =>
      WordTableParser.alignRow(WordTableParser.splitCsvLine(row, ','), fields);

  String g(Map<String, String> data, String key) => data[key] ?? '';

  group('WordTableParser.mapHeader', () {
    test('định dạng chuẩn 8 cột → map ĐỦ (kể cả example_simple/complex)', () {
      expect(fields, [
        'word',
        'meaning',
        'phonetic',
        'topic',
        'example',
        'exampleSimple',
        'exampleComplex',
        'language',
      ]);
    });

    test('header tiếng Việt có dấu + gạch dưới vẫn map đúng', () {
      final f = WordTableParser.mapHeader(
        'từ vựng, nghĩa, phiên âm, chủ đề, ví dụ, ví dụ đơn, ví dụ phức, ngôn ngữ',
      );
      expect(f, [
        'word',
        'meaning',
        'phonetic',
        'topic',
        'example',
        'exampleSimple',
        'exampleComplex',
        'language',
      ]);
    });
  });

  group('WordTableParser.alignRow — hàng chuẩn', () {
    test('8 ô khớp 1-1', () {
      final data = parse(
        'abundance, sự phong phú, /əˈbʌndəns/, nature, There is an abundance, A simple one, A complex one, en',
      );
      expect(data['word'], 'abundance');
      expect(data['meaning'], 'sự phong phú');
      expect(data['phonetic'], '/əˈbʌndəns/');
      expect(data['topic'], 'nature');
      expect(data['example'], 'There is an abundance');
      expect(data['exampleSimple'], 'A simple one');
      expect(data['exampleComplex'], 'A complex one');
      expect(data['language'], 'en');
    });

    test('ô bọc nháy kép chứa phẩy → giữ nguyên (CSV chuẩn)', () {
      final data = parse(
        'shift, "Chuyển tiếp, thay đổi trạng thái", /ʃɪft/, physics, It shifts the result, Simple shift, Complex shift, vi',
      );
      expect(data['meaning'], 'Chuyển tiếp, thay đổi trạng thái');
      expect(data['phonetic'], '/ʃɪft/');
      expect(data['topic'], 'physics');
      expect(data['language'], 'vi');
    });
  });

  group('WordTableParser.alignRow — dấu phẩy KHÔNG bọc nháy', () {
    test('meaning có phẩy → gộp vào meaning, không lệch cột', () {
      final data = parse(
        'abundance, sự phong phú, sự dư dả, /əˈbʌndəns/, nature, There is abundance, A simple one, A complex one, en',
      );
      expect(data['word'], 'abundance');
      expect(data['meaning'], 'sự phong phú, sự dư dả');
      expect(data['topic'], 'nature');
      expect(data['example'], 'There is abundance');
      expect(data['exampleSimple'], 'A simple one');
      expect(data['exampleComplex'], 'A complex one');
      expect(data['language'], 'en');
    });

    test('example có phẩy → gộp vào example', () {
      final data = parse(
        'abundance, sự phong phú, /əˈbʌndəns/, nature, There is, an abundance of food, A simple one, A complex one, en',
      );
      expect(data['topic'], 'nature');
      expect(data['example'], 'There is, an abundance of food');
      expect(data['exampleSimple'], 'A simple one');
      expect(data['exampleComplex'], 'A complex one');
      expect(data['language'], 'en');
    });

    test('phẩy ở example_simple → gộp đúng vào example_simple', () {
      final data = parse(
        'abundance, sự phong phú, /əˈbʌndəns/, nature, There is abundance, A simple, one, A complex one, en',
      );
      expect(data['example'], 'There is abundance');
      expect(data['exampleSimple'], 'A simple, one');
      expect(data['exampleComplex'], 'A complex one');
    });

    test('meaning VÀ example cùng có phẩy → cả hai đều đúng', () {
      final data = parse(
        'abundance, sự phong phú, sự dư dả, /əˈbʌndəns/, nature, There is, an abundance, of food, A simple one, A complex one, en',
      );
      expect(data['meaning'], 'sự phong phú, sự dư dả');
      expect(data['example'], 'There is, an abundance, of food');
      expect(data['exampleSimple'], 'A simple one');
      expect(data['exampleComplex'], 'A complex one');
      expect(data['language'], 'en');
    });

    test('meaning có phẩy + hàng thiếu ô ipa → vẫn khớp', () {
      final data = parse(
        'abundance, sự phong phú, sự dư dả, nature, There is abundance, A simple one, A complex one, en',
      );
      expect(data['meaning'], 'sự phong phú, sự dư dả');
      expect(data['topic'], 'nature');
      expect(data['example'], 'There is abundance');
      expect(data['language'], 'en');
      expect(g(data, 'phonetic'), '');
    });

    test('hàng thiếu ô ipa (7 ô, 8 cột) → các cột sau trượt trái, khớp', () {
      final data = parse(
        'abundance, sự phong phú, nature, There is abundance, A simple one, A complex one, en',
      );
      expect(data['meaning'], 'sự phong phú');
      expect(g(data, 'phonetic'), '');
      expect(data['topic'], 'nature');
      expect(data['example'], 'There is abundance');
      expect(data['exampleSimple'], 'A simple one');
      expect(data['exampleComplex'], 'A complex one');
      expect(data['language'], 'en');
    });

    test('hàng thiếu cột cuối (6 ô) → language vẫn về đúng cột', () {
      final data = parse(
        'abundance, sự phong phú, /əˈbʌndəns/, nature, There is abundance, en',
      );
      expect(data['word'], 'abundance');
      expect(data['topic'], 'nature');
      expect(g(data, 'language'), 'en');
      expect(g(data, 'exampleSimple'), '');
    });
  });

  group('WordTableParser — delimiter khác', () {
    test('tab: mapping + hàng chuẩn', () {
      final f = WordTableParser.mapHeader(
        'word\tmeaning\tipa\ttopic\texample\texample_simple\texample_complex\tlanguage',
      );
      expect(f[0], 'word');
      expect(f[7], 'language');
      final data = WordTableParser.alignRow(
        WordTableParser.splitCsvLine(
          'word1\tnghĩa 1\t/w/\ttopic\texample\texs\texc\ten',
          '\t',
        ),
        f,
      );
      expect(data['word'], 'word1');
      expect(data['meaning'], 'nghĩa 1');
      expect(data['language'], 'en');
    });

    test('phẩy trong meaning + delimiter ";" → gộp đúng', () {
      final f = WordTableParser.mapHeader(
        'word;meaning;ipa;topic;example;example_simple;example_complex;language',
      );
      final data = WordTableParser.alignRow(
        WordTableParser.splitCsvLine(
          'shift;Chuyển tiếp;thay đổi;/ʃɪft/;physics;It shifts;Simple;Complex;vi',
          ';',
        ),
        f,
      );
      expect(data['meaning'], 'Chuyển tiếp, thay đổi');
      expect(data['topic'], 'physics');
      expect(data['language'], 'vi');
    });
  });

  group('WordTableParser — header tiếng Việt end-to-end', () {
    test('header VN + hàng dữ liệu VN → đủ trường', () {
      final f = WordTableParser.mapHeader(
        'từ vựng, nghĩa, phiên âm, chủ đề, ví dụ, ví dụ đơn, ví dụ phức, ngôn ngữ',
      );
      final data = WordTableParser.alignRow(
        WordTableParser.splitCsvLine(
          'từ1, nghĩa 1, /f/, topic, example, exs, exc, vi',
          ',',
        ),
        f,
      );
      expect(data['word'], 'từ1');
      expect(data['meaning'], 'nghĩa 1');
      expect(data['phonetic'], '/f/');
      expect(data['exampleComplex'], 'exc');
      expect(data['language'], 'vi');
    });
  });

  group('WordTableParser — hành vi ngắn/mở rộng', () {
    test('hàng 2 ô (word, meaning) vẫn hoạt động', () {
      final data = parse('hello, world peace');
      expect(data['word'], 'hello');
      expect(data['meaning'], 'world peace');
    });

    test('ipa trống (ô rỗng) hàng chuẩn → không lệch', () {
      final data = parse(
        'abundance, sự phong phú, , nature, There is abundance, A simple one, A complex one, en',
      );
      expect(g(data, 'phonetic'), '');
      expect(data['topic'], 'nature');
      expect(data['meaning'], 'sự phong phú');
    });

    test('hàng 8 ô, ipa đúng chỗ → giữ 1-1 (không gộp nhầm)', () {
      final data = parse(
        'abundance, sự phong phú, /əˈbʌndəns/, nature, ex, exs, exc, en',
      );
      expect(data['phonetic'], '/əˈbʌndəns/');
      expect(data['topic'], 'nature');
      expect(data['example'], 'ex');
    });
  });
}
