// IN4-26 (I4U-BRAND-001) — AI Chat hiển thị "I2U" thay vì "I4U" (brand
// của app là I4U/In4Up). Test máy bắt: nguồn UI + catalog fallback không
// được còn "I2U" ở bất kỳ đâu.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IN4-26 — brand I4U (không còn I2U)', () {
    test('ai_chat_screen.dart dùng I4U, không còn I2U', () {
      final src =
          File('lib/screens/ai_chat/ai_chat_screen.dart').readAsStringSync();
      expect(src.contains('I2U'), isFalse,
          reason: 'Còn chuỗi "I2U" — brand đúng là I4U');
      expect(src.contains('Hỏi I4U về từ vựng, ngữ pháp...'), isTrue);
      expect(src.contains('Trợ lý học tập I4U'), isTrue);
    });

    test('legacy fallbacks: key + value I4U (không còn I2U)', () {
      final src = File(
              'lib/core/language/generated_legacy_ui_fallbacks.dart')
          .readAsStringSync();
      expect(
        RegExp('I2U').hasMatch(src),
        isFalse,
        reason: 'Fallback catalog còn "I2U" — brand đúng là I4U',
      );
      expect(
        src.contains(
            "'Hỏi I4U về từ vựng, ngữ pháp...': 'Ask I4U about vocabulary, grammar...'"),
        isTrue,
      );
      expect(src.contains("'Trợ lý học tập I4U': 'I4U learning assistant'"),
          isTrue);
    });
  });
}
