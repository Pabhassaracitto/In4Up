import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/translation/engines/hymt_prompts.dart';

void main() {
  group('HyMtPrompts', () {
    test('normalizes zh variants', () {
      expect(HyMtPrompts.normalizeCode('zh-CN'), 'ZH');
      expect(HyMtPrompts.normalizeCode('zh_TW'), 'ZH-HANT');
      expect(HyMtPrompts.normalizeCode('en-US'), 'EN');
    });

    test('supports Hindi and Vietnamese, not Sinhala', () {
      expect(HyMtPrompts.supports('HI'), isTrue);
      expect(HyMtPrompts.supports('vi'), isTrue);
      expect(HyMtPrompts.supports('si'), isFalse);
    });

    test('EN-VI uses English instruction', () {
      final p = HyMtPrompts.build(
        text: 'Hello',
        sourceLang: 'EN',
        targetLang: 'VI',
      );
      expect(p, contains('Translate the following segment into Vietnamese'));
      expect(p, contains('Hello'));
      expect(p.contains('将以下文本'), isFalse);
    });

    test('ZH-EN uses Chinese instruction', () {
      final p = HyMtPrompts.build(
        text: '你好',
        sourceLang: 'ZH',
        targetLang: 'EN',
      );
      expect(p, contains('将以下文本翻译为英语'));
      expect(p, contains('你好'));
    });

    test('cleanOutput strips prompt echo', () {
      const src = 'Hello world';
      expect(
        HyMtPrompts.cleanOutput('Translation: Xin chào</s>', src),
        'Xin chào',
      );
    });
  });
}
