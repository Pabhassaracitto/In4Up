// test/mascot/mascot_reply_parser_test.dart
//
// MASCOT-003 — parser câu trả lời "khoan dung": sai format ⇒ CHỈ LỜI NÓI,
// không thực thi gì (an toàn là mặc định — PLAN-050 §11).

import 'package:flutter_test/flutter_test.dart';

import 'package:in4up/features/mascot/mascot_reply_parser.dart';

void main() {
  group('dòng directive [[action:id]] — giao thức chính', () {
    test('bóc action + giữ lời nói', () {
      final parsed = parseMascotReply(
          'Mở PDF Reader cho bạn nhé.\n[[action:pdf_reader]]');
      expect(parsed.say, 'Mở PDF Reader cho bạn nhé.');
      expect(parsed.actionId, 'pdf_reader');
    });

    test('chấp nhận <<action:id>>', () {
      final parsed = parseMascotReply('Đi tới Từ điển.\n<<action:dictionary>>');
      expect(parsed.say, 'Đi tới Từ điển.');
      expect(parsed.actionId, 'dictionary');
    });

    test('chỉ có dòng action — lời nói rỗng vẫn trả id', () {
      final parsed = parseMascotReply('[[action:tab_read]]');
      expect(parsed.actionId, 'tab_read');
      expect(parsed.say, isEmpty);
    });

    test('id có khoảng trắng thừa vẫn khớp', () {
      expect(parseMascotReply('[[action: word_list ]]').actionId, 'word_list');
    });
  });

  group('JSON', () {
    test('fenced ```json``` với say + action.id', () {
      final parsed = parseMascotReply(
          '```json\n{"say": "Mở Tab Đọc.", "action": {"id": "tab_read"}}\n```');
      expect(parsed.say, 'Mở Tab Đọc.');
      expect(parsed.actionId, 'tab_read');
    });

    test('JSON nguyên văn không fence', () {
      final parsed =
          parseMascotReply('{"say": "Học tiếp nhé.", "action": {"id": "review"}}');
      expect(parsed.say, 'Học tiếp nhé.');
      expect(parsed.actionId, 'review');
    });

    test('JSON không say — action vẫn trả về', () {
      final parsed = parseMascotReply('{"action": {"id": "word_list"}}');
      expect(parsed.actionId, 'word_list');
    });

    test('JSON hỏng ⇒ coi như văn bản, KHÔNG thực thi', () {
      final parsed = parseMascotReply('{"say": "Gãy", "action": {"id":');
      expect(parsed.actionId, isNull);
      expect(parsed.say, isNotEmpty);
    });
  });

  group('văn bản thuần', () {
    test('không directive không JSON — nguyên văn là lời nói', () {
      final parsed = parseMascotReply('Từ "diligence" nghĩa là siêng năng.');
      expect(parsed.say, 'Từ "diligence" nghĩa là siêng năng.');
      expect(parsed.actionId, isNull);
    });

    test('chuỗi rỗng — rỗng sạch', () {
      final parsed = parseMascotReply('   ');
      expect(parsed.say, isEmpty);
      expect(parsed.actionId, isNull);
    });
  });
}
