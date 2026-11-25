// ADR-0018 P2 — smart split cho `ACTION_PROCESS_TEXT` (bôi chữ ở app khác).
// Thuần Dart: KHÔNG plugin, KHÔNG Flutter widget ⇒ chạy trên CI không treo
// (bài học run 40575300780). Đầu vào đến từ ứng dụng KHÁC — ma trận ca xấu
// là phần quan trọng nhất.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/dictionary/services/process_text_route.dart';

void main() {
  group('một từ ⇒ DictionaryScreen', () {
    test('từ thường', () {
      final route = routeProcessText('ubiquitous');
      expect(route, isNotNull);
      expect(route!.action, ProcessTextAction.dictionary);
      expect(route.text, 'ubiquitous');
    });

    test('một từ tiếng Việt không khoảng trắng', () {
      final route = routeProcessText('nhiệtđộ');
      expect(route!.action, ProcessTextAction.dictionary);
      expect(route.text, 'nhiệtđộ');
    });

    test('trim khoảng trắng hai đầu', () {
      final route = routeProcessText('  hello  ');
      expect(route!.action, ProcessTextAction.dictionary);
      expect(route.text, 'hello');
    });

    test('chữ hoa giữ nguyên (không lowercase — từ khoá tra cứu)',
        () {
      final route = routeProcessText('iPhone');
      expect(route!.action, ProcessTextAction.dictionary);
      expect(route.text, 'iPhone');
    });

    test('một token đúng 64 rune ⇒ vẫn là từ (biên trần DictDeepLink)',
        () {
      final word = 'a'.padRight(64, 'a');
      final route = routeProcessText(word);
      expect(route!.action, ProcessTextAction.dictionary);
      expect(route.text, word);
      expect(word.runes.length, 64);
    });
  });

  group('cụm/câu ⇒ dịch', () {
    test('cụm tiếng Việt có dấu', () {
      final route = routeProcessText('học sinh');
      expect(route!.action, ProcessTextAction.translate);
      expect(route.text, 'học sinh');
    });

    test('cụm nhiều từ', () {
      final route = routeProcessText('how are you');
      expect(route!.action, ProcessTextAction.translate);
      expect(route.text, 'how are you');
    });

    test('câu đầy đủ', () {
      final route =
          routeProcessText('The quick brown fox jumps over the lazy dog.');
      expect(route!.action, ProcessTextAction.translate);
    });

    test('nhiều dòng (bôi chữ từ PDF)', () {
      final route = routeProcessText('dòng một\ndòng hai');
      expect(route!.action, ProcessTextAction.translate);
      expect(route.text, 'dòng một\ndòng hai');
    });

    test('tab giữa các từ', () {
      final route = routeProcessText('hello\tworld');
      expect(route!.action, ProcessTextAction.translate);
    });

    test('token dài hơn 64 rune ⇒ không phải từ để tra ⇒ dịch', () {
      final route = routeProcessText('a'.padRight(65, 'a'));
      expect(route!.action, ProcessTextAction.translate);
    });

    test('URL một token ≤64 ⇒ là một token ⇒ đi từ điển (không crash)',
        () {
      final route = routeProcessText('https://example.com/a');
      expect(route, isNotNull);
      expect(route!.action, ProcessTextAction.dictionary);
      expect(route.text, 'https://example.com/a');
    });
  });

  group('dữ liệu không tin được (từ ứng dụng khác)', () {
    test('chuỗi rỗng ⇒ bỏ qua', () {
      expect(routeProcessText(''), isNull);
    });

    test('toàn khoảng trắng ⇒ bỏ qua', () {
      expect(routeProcessText('   '), isNull);
      expect(routeProcessText('\n\t  \n'), isNull);
    });

    test('ký tự điều khiển bị loại, chữ thường được giữ', () {
      final route = routeProcessText('hello\u0000\u001B');
      expect(route, isNotNull);
      expect(route!.action, ProcessTextAction.dictionary);
      expect(route.text, 'hello');
    });

    test('ký tự điều khiển giữa từ ⇒ còn lại vẫn tra được', () {
      final route = routeProcessText('un\u0007believable');
      expect(route!.action, ProcessTextAction.dictionary);
      expect(route.text, 'unbelievable');
    });

    test('NUL + khoảng trắng ⇒ không ném exception, tách đúng', () {
      final route = routeProcessText('\u0000how are you\u0000');
      expect(route, isNotNull);
      expect(route!.action, ProcessTextAction.translate);
      expect(route.text, 'how are you');
    });

    test('emoji/Unicode lạ không ném exception', () {
      final route = routeProcessText('🎉 chúc mừng 🎊');
      expect(route, isNotNull);
      expect(route!.action, ProcessTextAction.translate);
      expect(route.text, '🎉 chúc mừng 🎊');
    });
  });

  group('ProcessTextRoute — bất biến', () {
    test('== và hashCode theo (action, text)', () {
      final a = routeProcessText('hello');
      final b = routeProcessText('hello');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), contains('dictionary'));
    });
  });
}
