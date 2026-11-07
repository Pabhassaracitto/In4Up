import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/translation/engines/hymt_prompts.dart';

/// HYMT-004 (2026-11-06) — hồi quy cho nguyên nhân "Hy-MT trả về rỗng".
///
/// chat_template.jinja chính thức của `tencent/HY-MT1.5-1.8B` là
/// `<｜hy_begin▁of▁sentence｜><｜hy_User｜>{content}<｜hy_Assistant｜>` và KHÔNG
/// dùng `<|im_start|>`/BOS thường. Gửi chuỗi thô là lý do số 1 khiến model nhả
/// rỗng hoặc nhả lại nguyên prompt trên thiết bị.
void main() {
  const bos = '\uFF5C'; // ｜
  const sep = '\u2581'; // ▁

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

  group('HyMtPrompts — khung lượt Hy-MT1.5 (HYMT-004)', () {
    test('token khung đúng từng ký tự như chat template của Tencent', () {
      expect(HyMtPrompts.bosToken,
          '<${bos}hy_begin${sep}of${sep}sentence$bos>');
      expect(HyMtPrompts.userToken, '<${bos}hy_User$bos>');
      expect(HyMtPrompts.assistantToken, '<${bos}hy_Assistant$bos>');
      // Không được lẫn token của dòng chat khác.
      expect(HyMtPrompts.userToken.contains('im_start'), isFalse);
      expect(HyMtPrompts.bosToken.runes.contains(0x2581), isTrue);
      expect(HyMtPrompts.bosToken.runes.contains(0xFF5C), isTrue);
    });

    test('build() bọc đúng thứ tự BOS → User → body → Assistant', () {
      final p = HyMtPrompts.build(
        text: 'Hello',
        sourceLang: 'EN',
        targetLang: 'VI',
      );
      expect(p, startsWith(HyMtPrompts.bosToken + HyMtPrompts.userToken));
      expect(p, endsWith(HyMtPrompts.assistantToken));
      expect(
        p,
        '${HyMtPrompts.bosToken}${HyMtPrompts.userToken}'
        '${HyMtPrompts.instruction(sourceLang: 'EN', targetLang: 'VI')}'
        '\n\nHello${HyMtPrompts.assistantToken}',
      );
      // Chỉ MỘT khung: model không được thấy 2 lượt user.
      expect(HyMtPrompts.userToken.allMatches(p).length, 1);
    });

    test('withTurnTokens=false giữ chỉ thị + văn bản, không token', () {
      final p = HyMtPrompts.build(
        text: '你好',
        sourceLang: 'ZH',
        targetLang: 'VI',
        withTurnTokens: false,
      );
      expect(p.contains(HyMtPrompts.userToken), isFalse);
      expect(p, contains('将以下文本翻译为越南语'));
      expect(p, contains('你好'));
    });

    test('instruction tách rời = phần đầu của build (không lệch nội dung)',
        () {
      final instruction =
          HyMtPrompts.instruction(sourceLang: 'EN', targetLang: 'VI');
      final p = HyMtPrompts.build(
        text: 'Good morning',
        sourceLang: 'EN',
        targetLang: 'VI',
      );
      expect(p, contains(instruction));
      // Text nguồn nằm SAU chỉ thị, cách 1 dòng trống (đúng model card).
      expect(p.indexOf('Good morning'), greaterThan(p.indexOf(instruction)));
      expect(p.contains('$instruction\n\nGood morning'), isTrue);
    });

    test('cleanOutput cắt token khung nếu model nhả lại', () {
      expect(
        HyMtPrompts.cleanOutput(
          '${HyMtPrompts.assistantToken}Xin chào bạn.',
          'Hello my friend',
        ),
        'Xin chào bạn.',
      );
      expect(
        HyMtPrompts.cleanOutput(
          'Xin chào bạn.${HyMtPrompts.assistantToken}',
          'Hello my friend',
        ),
        'Xin chào bạn.',
      );
      expect(
        HyMtPrompts.cleanOutput('Xin chào<|endoftext|>', 'Hi there friend'),
        'Xin chào',
      );
      expect(
        HyMtPrompts.cleanOutput('Xin chào<|eos|>', 'Hi there friend'),
        'Xin chào',
      );
    });

    test('cleanOutput không phá bản dịch hợp lệ có ký tự ｜', () {
      const src = 'Ký hiệu ｜ trong câu';
      expect(HyMtPrompts.cleanOutput(src, src), src);
    });
  });
}
