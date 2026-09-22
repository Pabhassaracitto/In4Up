// test/line_ipa_service_test.dart
//
// Unit test P1 (READ-IPA-001): LineIpaService.buildLineIpa —
// eligibility (chặn chữ Việt/Pali), join phoneme `''`, cache theo content.
// Dùng wordIpaOverride seam → không cần asset CMU Dict trong test.
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/services/line_ipa_service.dart';

void main() {
  setUp(() {
    LineIpaService.clearCache();
    LineIpaService.wordIpaOverride = null;
  });

  tearDown(() {
    LineIpaService.wordIpaOverride = null;
    LineIpaService.clearCache();
  });

  String? Function(String) fakeTable(Map<String, String> table) {
    return (word) => table[word.toLowerCase()];
  }

  group('buildLineIpa — eligibility', () {
    test('dòng Anh ASCII → IPA từng từ, join bằng space', () {
      LineIpaService.wordIpaOverride = fakeTable({
        'she': 'ʃiː',
        'sells': 'sɛlz',
        'seashells': 'ˈsiːʃɛlz',
      });
      expect(
        LineIpaService.buildLineIpa('She sells seashells'),
        'ʃiː sɛlz ˈsiːʃɛlz',
      );
    });

    test('dấu câu bám quanh từ bị bỏ, không lọt vào dòng IPA', () {
      LineIpaService.wordIpaOverride = fakeTable({
        'hello': 'həˈloʊ',
        'world': 'wɝld',
      });
      expect(LineIpaService.buildLineIpa('Hello, (world)!'), 'həˈloʊ wɝld');
    });

    test('token toàn dấu câu bị bỏ qua, không tính là từ', () {
      LineIpaService.wordIpaOverride = fakeTable({
        'hello': 'həˈloʊ',
        'world': 'wɝld',
      });
      // Token "—" là punct-only → skip; dòng vẫn hợp lệ.
      expect(LineIpaService.buildLineIpa('Hello — world'), 'həˈloʊ wɝld');
    });

    test('chứa chữ không-ASCII (Việt) → null cả dòng', () {
      var called = false;
      LineIpaService.wordIpaOverride = (_) {
        called = true;
        return 'x';
      };
      expect(LineIpaService.buildLineIpa('Xin chào'), isNull);
      expect(LineIpaService.buildLineIpa('đây là tiếng Việt'), isNull);
      // Eligibility fail TRƯỚC khi resolve → resolver không được gọi.
      expect(called, isFalse);
    });

    test('digit bám ngoài từ bị strip → từ vẫn hợp lệ', () {
      // "covid19" → strip "19" (digit không phải letter) → core "covid".
      LineIpaService.wordIpaOverride = fakeTable({
        'covid': 'koʊvɪd',
        'rules': 'ruːlz',
      });
      expect(LineIpaService.buildLineIpa('covid19 rules'), 'koʊvɪd ruːlz');
      expect(LineIpaService.buildLineIpa('covid, rules'), 'koʊvɪd ruːlz');
    });

    test('hyphen nội tại không đủ eligibility → null (v1 chặt)', () {
      LineIpaService.wordIpaOverride = (_) => 'x';
      expect(LineIpaService.buildLineIpa('a well-known fact'), isNull);
    });

    test('từ có apostrophe hợp lệ', () {
      LineIpaService.wordIpaOverride = fakeTable({'don\'t': 'doʊnt'});
      expect(LineIpaService.buildLineIpa("Don't panic"), 'doʊnt');
    });

    test('dòng không có từ nào (toàn punct/số/rỗng) → null', () {
      LineIpaService.wordIpaOverride = (_) => 'x';
      expect(LineIpaService.buildLineIpa('!!! ... —'), isNull);
      expect(LineIpaService.buildLineIpa(''), isNull);
      expect(LineIpaService.buildLineIpa('   '), isNull);
      expect(LineIpaService.buildLineIpa('123 456'), isNull);
    });

    test('resolver trả rỗng cho mọi từ → null', () {
      LineIpaService.wordIpaOverride = (_) => '';
      expect(LineIpaService.buildLineIpa('Hello world'), isNull);
    });
  });

  group('buildLineIpa — join semantics', () {
    test('join(\'\') không thêm dấu chấm (khác ipaString)', () {
      LineIpaService.wordIpaOverride = (w) => switch (w.toLowerCase()) {
        'world' => 'wˈɝld',
        _ => '',
      };
      expect(LineIpaService.buildLineIpa('world'), 'wˈɝld');
      expect(LineIpaService.buildLineIpa('world'), isNot(contains('.')));
    });
  });

  group('buildLineIpa — cache', () {
    test('cùng content → resolver chỉ chạy 1 lần', () {
      var calls = 0;
      LineIpaService.wordIpaOverride = (w) {
        calls++;
        return 'x';
      };
      final a = LineIpaService.buildLineIpa('Hello world');
      final b = LineIpaService.buildLineIpa('Hello world');
      expect(calls, 1);
      expect(a, b);
      expect(LineIpaService.cacheSize, 1);
    });

    test('cache cả kết quả null (dòng Việt không tốn повтор compute)', () {
      var calls = 0;
      LineIpaService.wordIpaOverride = (w) {
        calls++;
        return 'x';
      };
      expect(LineIpaService.buildLineIpa('chào'), isNull);
      expect(LineIpaService.buildLineIpa('chào'), isNull);
      // "chào" fail eligibility trước resolve → calls luôn 0;
      // dùng dòng punct để xác minh cache chứa null:
      expect(LineIpaService.buildLineIpa('!!!'), isNull);
      expect(LineIpaService.buildLineIpa('!!!'), isNull);
      expect(calls, 0);
      expect(LineIpaService.cacheSize, 2);
    });

    test('clearCache → compute lại', () {
      var calls = 0;
      LineIpaService.wordIpaOverride = (w) {
        calls++;
        return 'x';
      };
      LineIpaService.buildLineIpa('Hello');
      LineIpaService.clearCache();
      expect(LineIpaService.cacheSize, 0);
      LineIpaService.buildLineIpa('Hello');
      expect(calls, 2);
    });

    test('tràn cache → clear-all rồi tiếp tục', () {
      // Ghi vượt cap 600 để ép clear-all.
      for (var i = 0; i < 601; i++) {
        LineIpaService.buildLineIpa('line $i');
      }
      // Sau vòng trên: entry cuối cùng được ghi sau khi clear → size ≤ 1
      // (clear xảy ra trước khi insert cuối). Chạy tiếp 1 dòng nữa.
      LineIpaService.buildLineIpa('after overflow');
      expect(LineIpaService.cacheSize, lessThanOrEqualTo(2));
    });
  });
}
