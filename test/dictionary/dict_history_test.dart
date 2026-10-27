// DICT-HISTORY-001 — lịch sử tra từ của màn Từ điển (ADR-0018 P1).
//
// Phần THUẦN: thứ tự, khử trùng, giới hạn, lọc. Toàn bộ I/O
// (`SharedPreferences`) nằm ở widget, nên test chạy được trên CI.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/dictionary/services/dict_history.dart';

void main() {
  group('DictHistory.add', () {
    test('từ mới lên ĐẦU', () {
      final out = DictHistory.add(<String>['book', 'cat'], 'dog');
      expect(out, <String>['dog', 'book', 'cat']);
    });

    test('khử trùng không phân biệt hoa/thường, giữ dạng vừa tra', () {
      final out = DictHistory.add(<String>['Book', 'cat'], 'book');
      expect(out, <String>['book', 'cat'],
          reason: 'tra lại "book" thì lên đầu và giữ đúng chữ vừa gõ');
    });

    test('gộp khoảng trắng thừa; rỗng thì không lưu', () {
      expect(DictHistory.add(const <String>[], '  học   sinh '),
          <String>['học sinh']);
      expect(DictHistory.add(<String>['a'], '   '), <String>['a']);
      expect(DictHistory.add(<String>['a'], ''), <String>['a']);
    });

    test('cắt còn maxItems, bỏ phần cũ nhất', () {
      final current = <String>['w1', 'w2', 'w3'];
      final out = DictHistory.add(current, 'w0', maxItems: 3);
      expect(out, <String>['w0', 'w1', 'w2']);
    });

    test('không sửa danh sách gốc', () {
      final current = <String>['a'];
      DictHistory.add(current, 'b');
      expect(current, <String>['a']);
    });
  });

  group('DictHistory.remove / matching', () {
    test('bỏ đúng từ, không phân biệt hoa/thường', () {
      expect(DictHistory.remove(<String>['Book', 'cat'], 'book'),
          <String>['cat']);
    });

    test('lọc theo từ đang gõ (chứa, không phân biệt hoa/thường)', () {
      final history = <String>['hello', 'help', 'world'];
      expect(DictHistory.matching(history, 'hel'),
          <String>['hello', 'help']);
      expect(DictHistory.matching(history, 'xyz'), isEmpty);
    });

    test('ô tìm trống ⇒ trả lịch sử gần nhất theo giới hạn', () {
      final history = List<String>.generate(20, (i) => 'w$i');
      expect(DictHistory.matching(history, '', limit: 5), hasLength(5));
      expect(DictHistory.matching(history, '').first, 'w0');
    });
  });
}
