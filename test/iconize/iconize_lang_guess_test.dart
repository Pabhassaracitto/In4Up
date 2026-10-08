// ICONIZE-001d — test heuristic đoán ngôn ngữ (thuần Dart).
//
// Nguyên tắc kiểm: đoán SAI chỉ được phép sai về phía 'other' (mất icon —
// vô hại), không bao giờ gán 'en' cho câu Latin không có bằng chứng EN.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/iconize/engine/iconize_lang_guess.dart';

void main() {
  group('khai báo tường minh thắng heuristic', () {
    test('declared en', () {
      expect(guessIconizeLang('Bonjour le monde', declared: 'EN'), 'en');
    });
    test('declared vi', () {
      expect(guessIconizeLang('hello world', declared: 'vi'), 'vi');
    });
    test('AUTO/rỗng/null rơi về heuristic', () {
      expect(guessIconizeLang('The cat sleeps.', declared: 'AUTO'), 'en');
      expect(guessIconizeLang('The cat sleeps.', declared: ''), 'en');
      expect(guessIconizeLang('The cat sleeps.'), 'en');
    });
  });

  group('heuristic', () {
    test('dấu tiếng Việt → vi', () {
      expect(guessIconizeLang('Trời mưa to quá.'), 'vi');
      expect(guessIconizeLang('Cuốn sách trên bàn.'), 'vi');
    });
    test('ASCII + stopword EN → en', () {
      expect(guessIconizeLang('The rain falls on the window.'), 'en');
      expect(guessIconizeLang('She gave him a quick kiss.'), 'en');
    });
    test('Latin KHÔNG stopword EN → other (an toàn trước)', () {
      // "chat" tiếng Pháp = mèo — nếu đoán bừa 'en' sẽ icon hóa sai nghĩa.
      expect(guessIconizeLang('Le chat dort.'), 'other');
      expect(guessIconizeLang('Buku di meja.'), 'other');
    });
    test('phi Latin → other', () {
      expect(guessIconizeLang('猫が眠る。'), 'other');
      expect(guessIconizeLang('बिल्ली सो रही है।'), 'other');
    });
    test('không có chữ → other', () {
      expect(guessIconizeLang('12345 !!!'), 'other');
      expect(guessIconizeLang(''), 'other');
    });
  });
}
