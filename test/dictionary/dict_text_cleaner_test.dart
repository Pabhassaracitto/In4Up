// DICT-CLEAN-001 — Unit test: làm sạch + cấu trúc hoá nội dung MDX.
//
// Mục tiêu: sheet tra cứu không còn đổ nguyên HTML/CSS/script/entity và không
// lặp nghĩa khi nhiều bộ từ điển cùng trả một từ.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/dictionary/models/dict_entry.dart';
import 'package:in4up/features/dictionary/services/dict_text_cleaner.dart';

void main() {
  group('DictTextCleaner.plain', () {
    test('bỏ script/style/link/comment + giải mã entity', () {
      const raw = '<link rel="stylesheet" href="style.css"/>'
          '<style>.entry{color:red;font-size:12px}</style>'
          '<script>var junk = 1;</script>'
          '<!-- hidden comment -->'
          '<b>hello</b> /həˈloʊ/&nbsp;— xin chào &amp; tạm biệt';

      final plain = DictTextCleaner.plain(raw);

      expect(plain, contains('hello'));
      expect(plain, contains('xin chào & tạm biệt'));
      expect(plain, isNot(contains('color')));
      expect(plain, isNot(contains('font-size')));
      expect(plain, isNot(contains('var junk')));
      expect(plain, isNot(contains('hidden comment')));
      expect(plain, isNot(contains('style.css')));
      // Hợp đồng ADR-0005: IPA PHẢI còn trong text phẳng để extractor trích.
      expect(plain, contains('/həˈloʊ/'));
    });

    test('bỏ dòng lặp lại đúng headword', () {
      const raw = '<div>hello</div><div>xin chào</div>';
      expect(DictTextCleaner.plain(raw, headword: 'hello'), 'xin chào');
    });

    test('bỏ URL trần, CSS declaration và dòng chỉ có ký hiệu', () {
      const raw = '<div>https://example.com/logo.png</div>'
          '<div>background-color: #fff;</div>'
          '<div>---</div>'
          '<div>quyển sách</div>';
      final plain = DictTextCleaner.plain(raw);
      expect(plain, 'quyển sách');
    });

    test('dòng trống / &nbsp; không tạo khoảng trắng thừa', () {
      const raw = '<div>a</div><div>&nbsp;</div><div></div><div>b</div>';
      expect(DictTextCleaner.plain(raw), 'a b');
    });
  });

  group('DictTextCleaner.parse', () {
    test('tách nhóm loại từ + nghĩa đánh số + ví dụ', () {
      const raw = '<div><span class="pos">n.</span></div>'
          '<div>1. a greeting</div>'
          '<div>2. a shout used to attract attention</div>'
          '<div>- she said hello</div>'
          '<div><span class="pos">v.</span></div>'
          '<div>1. to greet someone</div>';

      final parsed = DictTextCleaner.parse(raw, headword: 'hello');

      expect(parsed.groups, hasLength(2));
      expect(parsed.groups[0].pos, 'noun');
      expect(
        parsed.groups[0].senses.map((sense) => sense.text).toList(),
        <String>['a greeting', 'a shout used to attract attention'],
      );
      // Dòng bắt đầu bằng '-' là ví dụ của nghĩa ngay trước nó.
      expect(parsed.groups[0].senses[1].examples, contains('she said hello'));
      expect(parsed.groups[1].pos, 'verb');
      expect(parsed.groups[1].senses.single.text, 'to greet someone');
    });

    test('trích IPA hợp lệ, chặn respelling không phải IPA', () {
      final withIpa = DictTextCleaner.parse(
        '<div>/həˈloʊ/</div><div>xin chào</div>',
        headword: 'hello',
      );
      expect(withIpa.ipa, '/həˈloʊ/');

      final respelling = DictTextCleaner.parse(
        '<div>he-lō</div><div>xin chào</div>',
        headword: 'hello',
      );
      expect(respelling.ipa, isNull);
    });

    test('bullet <li> là danh sách NGHĨA, không bị coi là ví dụ', () {
      final parsed = DictTextCleaner.parse(
        '<ul><li>a thing</li><li>a place</li></ul>',
        headword: 'x',
      );
      expect(
        parsed.senses.map((sense) => sense.text).toList(),
        <String>['a thing', 'a place'],
      );
    });

    test('nghĩa trùng trong cùng entry bị khử', () {
      final parsed = DictTextCleaner.parse(
        '<div>1. quyển sách</div><div>2. quyển sách</div>',
        headword: 'book',
      );
      expect(parsed.senseCount, 1);
    });

    test('compactMeaning giới hạn số nghĩa + độ dài', () {
      final parsed = DictTextCleaner.parse(
        '<div>1. một</div><div>2. hai</div><div>3. ba</div><div>4. bốn</div>',
        headword: 'x',
      );
      expect(parsed.compactMeaning(maxSenses: 2), 'một • hai');
      expect(
        parsed.compactMeaning(maxSenses: 4, maxChars: 5).endsWith('…'),
        isTrue,
      );
    });
  });

  group('DictTextCleaner.merge', () {
    test('gộp nhiều bộ từ điển + khử nghĩa trùng + giữ nhãn nguồn', () {
      final merged = DictTextCleaner.merge(<DictSourceText>[
        const DictSourceText(
          headword: 'book',
          definition: '<div>1. quyển sách</div>',
          sourceLabel: 'Từ điển A',
        ),
        const DictSourceText(
          headword: 'book',
          definition: '<div>1. quyển sách</div><div>2. đặt vé</div>',
          sourceLabel: 'Từ điển B',
        ),
      ]);

      expect(merged.headword, 'book');
      expect(
        merged.senses.map((sense) => sense.text).toList(),
        <String>['quyển sách', 'đặt vé'],
      );
      expect(merged.sourceLabels, <String>['Từ điển A', 'Từ điển B']);
      expect(merged.sourceLabel, 'Từ điển A · Từ điển B');
    });

    test('IPA lấy từ cột phonetic khi HTML không có', () {
      final merged = DictTextCleaner.merge(<DictSourceText>[
        const DictSourceText(
          headword: 'book',
          definition: '<div>quyển sách</div>',
          phonetic: 'bʊk',
          sourceLabel: 'A',
        ),
      ]);
      expect(merged.ipa, '/bʊk/');
    });
  });

  group('DictEntry.plainDefinition', () {
    test('dùng pipeline mới nhưng vẫn giữ IPA cho IpaDefinitionExtractor', () {
      const entry = DictEntry(
        headword: 'hello',
        definition: '<style>.x{color:red}</style><b>/həˈloʊ/</b> xin chào',
        dictId: 'test',
      );
      expect(entry.plainDefinition, contains('/həˈloʊ/'));
      expect(entry.plainDefinition, contains('xin chào'));
      expect(entry.plainDefinition, isNot(contains('color')));
      expect(entry.definitionView.ipa, '/həˈloʊ/');
    });
  });
}
