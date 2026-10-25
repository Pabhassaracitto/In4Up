// DICT-CLEAN-002 (owner 2026-10-25, mục 3): "chọn từ đã có từ điển nhưng nó
// hiện nhiều phần dư và không thấy nghĩa đâu hết: 0000015105 reading …".
//
// Nguyên nhân: một số bộ MDX (bản export wordlist) chèn MÃ BẢN GHI + nhãn
// metadata (`reading`, `ipa`…) vào đầu nội dung entry; CSS của từ điển ẩn các
// khối `span.meta`/`span.domClass`… nhưng pipeline cũ chỉ bóc thẻ nên CHỮ của
// khối ẩn vẫn lọt vào phần "nghĩa".
//
// Test này khoá: mã bản ghi + nhãn metadata + khối bị CSS ẩn KHÔNG được vào
// nghĩa; loại từ ghi ở đầu dòng (`n. quyển sách`) phải thành nhóm loại từ;
// IPA vẫn phải giữ (hợp đồng ADR-0005).

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/dictionary/models/dict_entry.dart';
import 'package:in4up/features/dictionary/services/dict_text_cleaner.dart';

void main() {
  group('mã bản ghi + nhãn metadata ở đầu dòng', () {
    test('"0000015105 reading …" không còn lọt vào nghĩa', () {
      final parsed = DictTextCleaner.parse(
        '<div>0000015105 reading n. quyển sách</div>'
        '<div>v. đọc</div>',
        headword: 'book',
      );

      expect(parsed.groups, hasLength(2));
      expect(parsed.groups[0].pos, 'noun');
      expect(parsed.groups[0].senses.single.text, 'quyển sách');
      expect(parsed.groups[1].pos, 'verb');
      expect(parsed.groups[1].senses.single.text, 'đọc');

      final all = parsed.senses.map((s) => s.text).join(' ');
      expect(all.contains('0000015105'), isFalse);
      expect(all.contains('reading'), isFalse);
    });

    test('dòng chỉ có mã bản ghi bị bỏ hoàn toàn', () {
      final plain = DictTextCleaner.plain(
        '<div>0000015105</div><div>quyển sách</div>',
        headword: 'book',
      );
      expect(plain, 'quyển sách');
    });

    test('nhãn metadata có dấu hai chấm được bóc, IPA vẫn giữ để trích', () {
      final parsed = DictTextCleaner.parse(
        '<div>reading: /ˈriːdɪŋ/</div><div>việc đọc</div>',
        headword: 'reading',
      );
      expect(parsed.ipa, '/ˈriːdɪŋ/');
      expect(
        parsed.senses.map((s) => s.text).toList(),
        <String>['việc đọc'],
      );
    });

    test('nghĩa thật mở đầu bằng chữ "reading" KHÔNG bị cắt', () {
      final parsed = DictTextCleaner.parse(
        '<div>reading a book is fun</div>',
        headword: 'x',
      );
      expect(
        parsed.senses.single.text,
        'reading a book is fun',
        reason: 'chỉ bỏ chữ metadata khi phần sau chắc chắn là dữ liệu '
            'từ điển (loại từ / IPA / số hiệu nghĩa)',
      );
    });
  });

  group('khối bị CSS của từ điển ẩn (tham khảo lad.css)', () {
    test('span.meta / span.domClass / div.entry-headword không vào nghĩa', () {
      const raw = '<div class="entry-body">'
          '<span class="meta">0000015105</span>'
          '<div class="entry-headword">book</div>'
          '<span class="domClass">N</span>'
          '<div>quyển sách</div>'
          '</div>';
      final plain = DictTextCleaner.plain(raw, headword: 'book');
      expect(plain, 'quyển sách');
      expect(plain.contains('0000015105'), isFalse);
    });
  });

  group('loại từ ghi ngay đầu dòng nghĩa', () {
    test('n. / v. tách thành nhóm loại từ + nghĩa sạch', () {
      final parsed = DictTextCleaner.parse(
        '<div>n. quyển sách</div><div>v. đọc</div>',
        headword: 'book',
      );
      expect(parsed.groups.map((g) => g.pos).toList(), <String>['noun', 'verb']);
      expect(parsed.groups[0].senses.single.text, 'quyển sách');
      expect(parsed.groups[1].senses.single.text, 'đọc');
    });

    test('nhãn loại từ + nghĩa đánh số vẫn tách đúng', () {
      final parsed = DictTextCleaner.parse(
        '<div>n. 1. quyển sách 2. sổ sách</div>',
        headword: 'book',
      );
      expect(parsed.groups.single.pos, 'noun');
      expect(
        parsed.groups.single.senses.map((s) => s.text).toList(),
        <String>['quyển sách', 'sổ sách'],
      );
    });

    test('từ bắt đầu giống nhãn loại từ (detail) KHÔNG bị cắt', () {
      final parsed = DictTextCleaner.parse(
        '<div>detail of the plan</div>',
        headword: 'x',
      );
      expect(parsed.groups.single.senses.single.text, 'detail of the plan');
      expect(parsed.groups.single.pos, isNull);
    });
  });

  group('DictEntry.compactDefinition', () {
    test('không trả về chuỗi rác khi entry chỉ có mã bản ghi + nhãn', () {
      const entry = DictEntry(
        headword: 'book',
        definition: '<div>0000015105 reading</div><div>n. quyển sách</div>',
        dictId: 'd',
      );
      final compact = entry.compactDefinition;
      expect(compact, contains('quyển sách'));
      expect(compact.contains('0000015105'), isFalse);
      expect(compact.contains('reading'), isFalse);
    });
  });
}
