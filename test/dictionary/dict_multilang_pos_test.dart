// DICT-I18N-001 (owner 2026-10-27: "cách hiển thị từ điển đã ok chưa?").
//
// Ba lỗi hiển thị có thật được khoá bằng test này:
//
// 1. **Sinhala bị xoá sạch.** `_letterRe` (dùng bởi `_isJunkSense`) chỉ khai
//    báo Latin/Cyrillic/Ả-rập/Devanagari/Thái/Nhật/Hán/Hàn. Tiếng Sinhala
//    (U+0D80–U+0DFF) — một trong 5 ngôn ngữ ưu tiên của app — KHÔNG khớp ⇒
//    mọi dòng nghĩa Sinhala bị coi là "không có chữ" ⇒ bị xoá. Tra một từ
//    tiếng Sinhala ra trang trống. Cùng lỗi: Tamil, Bengali, Telugu, Kannada,
//    Malayalam, Khmer, Myanmar, Lào.
// 2. **Nhãn loại từ Trung/Nhật/Hindi/Sinhala bị coi là NGHĨA.** `名詞`,
//    `〔名〕`, `संज्ञा`, `නාම පදය` không có trong bảng `_posTokens` ⇒ hiện
//    thành một bullet vô nghĩa thay vì nhóm loại từ.
// 3. **Viết tắt tiếng Việt `dt.` / `đt.` / `tt.`** (từ điển Việt–Việt kiểu
//    Hồ Ngọc Đức) cũng rơi vào nghĩa, không thành nhóm loại từ.
//
// Ngoài ra `pos` là MÃ (`noun`) để gộp nhiều bộ từ điển — UI phải hiển thị
// tên đã dịch (`posDisplaySource`), không in thẳng "noun" cho người đọc.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/dictionary/services/dict_text_cleaner.dart';

void main() {
  group('DICT-I18N-001 (1) — không xoá nghĩa của các script ưu tiên', () {
    test('Sinhala (si) được GIỮ, không bị coi là rác', () {
      final parsed = DictTextCleaner.parse(
        '<div>ගස</div><div>ශාකයක් වන දේ</div>',
        headword: 'ගස',
      );
      expect(
        parsed.senses.map((s) => s.text).toList(),
        contains('ශාකයක් වන දේ'),
        reason: 'Sinhala nằm ngoài _letterRe cũ ⇒ câu này bị xoá mất',
      );
      expect(parsed.plainText, contains('ශාකයක්'));
    });

    test('Tamil / Bengali / Telugu cũng được giữ', () {
      for (final sample in <String>[
        'மரம் ஒரு தாவரம்',
        'গাছ একটি উদ্ভিদ',
        'చెట్టు ఒక మొక్క',
      ]) {
        final parsed = DictTextCleaner.parse('<div>$sample</div>');
        expect(
          parsed.plainText,
          contains(sample),
          reason: 'script của "$sample" chưa có trong _letterRe',
        );
      }
    });

    test('Latin / Hán / Devanagari / Hàn vẫn giữ nguyên (không hồi quy)', () {
      for (final sample in <String>[
        'a tree is a plant',
        '树木是一种植物',
        'पेड़ एक पौधा है',
        '나무는 식물이다',
      ]) {
        expect(DictTextCleaner.parse('<div>$sample</div>').plainText,
            contains(sample));
      }
    });
  });

  group('DICT-I18N-001 (2) — nhãn loại từ đa ngữ thành NHÓM, không thành nghĩa',
      () {
    test('Trung: nhãn một chữ trong ngoặc toàn độ rộng 〔名〕/【动】', () {
      final parsed = DictTextCleaner.parse(
        '<div>〔名〕</div><div>树木</div><div>【动】</div><div>种树</div>',
        headword: '树',
      );
      expect(parsed.groups.map((g) => g.pos).toList(), <String>['noun', 'verb']);
      expect(parsed.groups[0].senses.single.text, '树木');
      expect(parsed.groups[1].senses.single.text, '种树');
    });

    test('Trung phồn thể: cả từ 名詞 / 動詞', () {
      final parsed = DictTextCleaner.parse(
        '<div>名詞</div><div>樹木</div><div>動詞</div><div>種樹</div>',
        headword: '樹',
      );
      expect(parsed.groups.map((g) => g.pos).toList(), <String>['noun', 'verb']);
    });

    test('Hindi: संज्ञा / क्रिया', () {
      final parsed = DictTextCleaner.parse(
        '<div>संज्ञा</div><div>पौधा</div><div>क्रिया</div><div>उगाना</div>',
        headword: 'पेड़',
      );
      expect(parsed.groups.map((g) => g.pos).toList(), <String>['noun', 'verb']);
      expect(parsed.groups[0].senses.single.text, 'पौधा');
    });

    test('Sinhala: නාම පදය / ක්‍රියා පදය', () {
      final parsed = DictTextCleaner.parse(
        '<div>නාම පදය</div><div>ශාකයක්</div>'
        '<div>ක්‍රියා පදය</div><div>වැවීම</div>',
        headword: 'ගස',
      );
      expect(parsed.groups.map((g) => g.pos).toList(), <String>['noun', 'verb']);
      expect(parsed.groups[0].senses.single.text, 'ශාකයක්');
    });
  });

  group('DICT-I18N-001 (3) — viết tắt tiếng Việt (từ điển Việt–Việt)', () {
    test('"dt." / "đt." / "tt." tách thành nhóm loại từ', () {
      final parsed = DictTextCleaner.parse(
        '<div>dt. 1. quyển sách</div><div>đt. đọc</div><div>tt. hay, thú vị</div>',
        headword: 'sách',
      );
      expect(
        parsed.groups.map((g) => g.pos).toList(),
        <String>['noun', 'verb', 'adj'],
        reason: 'dòng "dt." trước đây thành một NGHĨA vô nghĩa',
      );
      expect(parsed.groups[0].senses.single.text, 'quyển sách');
      // Nhãn `dt.` không được sót lại trong danh sách nghĩa.
      expect(
        parsed.senses.map((s) => s.text).join(' '),
        isNot(contains('dt.')),
      );
      expect(
        parsed.senses.map((s) => s.text).join(' '),
        isNot(contains('tt.')),
      );
    });
  });

  group('DICT-I18N-001 (4) — không hiện lại headword thành một "nghĩa"', () {
    test('headword Sinhala lặp lại trong thân entry bị bỏ', () {
      final parsed = DictTextCleaner.parse(
        '<div>ගස</div><div>ශාකයක් වන දේ</div>',
        headword: 'ගස',
      );
      expect(
        parsed.groups.expand((g) => g.senses).map((s) => s.text).toList(),
        <String>['ශාකයක් වන දේ'],
        reason: '_isHeadwordOnly cũ chỉ so được chữ Latin ⇒ "ගස: ගස"',
      );
    });

    test('headword Hán/Hindi lặp lại cũng bị bỏ', () {
      for (final pair in <List<String>>[
        <String>['树', '树木'],
        <String>['पेड़', 'पौधा'],
      ]) {
        final parsed = DictTextCleaner.parse(
          '<div>${pair[0]}</div><div>${pair[1]}</div>',
          headword: pair[0],
        );
        expect(
          parsed.groups.expand((g) => g.senses).map((s) => s.text).toList(),
          <String>[pair[1]],
        );
      }
    });
  });

  group('posDisplaySource — hiển thị tên loại từ, không in mã', () {
    test('mã quen thuộc ⇒ nhãn tiếng Việt nguồn (để uiText dịch)', () {
      expect(DictTextCleaner.posDisplaySource('noun'), 'Danh từ');
      expect(DictTextCleaner.posDisplaySource('verb'), 'Động từ');
      expect(DictTextCleaner.posDisplaySource('adj'), 'Tính từ');
      expect(DictTextCleaner.posDisplaySource('measure'), 'Lượng từ');
      expect(DictTextCleaner.posDisplaySource('particle'), 'Trợ từ');
    });

    test('mã lạ / rỗng ⇒ null để UI hiện nguyên văn nhãn gốc', () {
      expect(DictTextCleaner.posDisplaySource(null), isNull);
      expect(DictTextCleaner.posDisplaySource(''), isNull);
      expect(DictTextCleaner.posDisplaySource('danh-tu-tu-che'), isNull);
    });
  });

  group('DICT-VIEW-002 — không cắt cụt loại từ của entry lớn', () {
    test('8 nhóm loại từ đều được giữ (trước đây trần là 6)', () {
      const labels = <String>[
        'n. một',
        'v. hai',
        'adj. ba',
        'adv. bốn',
        'prep. năm',
        'conj. sáu',
        'pron. bảy',
        'interj. tám',
      ];
      final parsed = DictTextCleaner.parse(
        '<div>${labels.join('</div><div>')}</div>',
        headword: 'x',
      );
      expect(parsed.groups, hasLength(8));
      expect(parsed.groups.last.pos, 'interj');
    });
  });
}
