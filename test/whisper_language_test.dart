// STT-LATIN-001 — Whisper language code + script guard.
//
// Lý do test tồn tại: người dùng chọn "Tiếng Hindi" cho file mp3 nhưng lời
// tạo ra toàn chữ LATIN. Có 2 lớp lỗi, cả 2 đều ở tầng mã:
//   1) mã ngôn ngữ truyền thẳng vào whisper.cpp ('en-US', 'hi-IN', 'pi') →
//      whisper_lang_id() trả -1 → plugin báo "unknown language" (hoặc âm
//      thầm rơi về default "en" của whisper_full_default_params) → decode
//      theo tiếng Anh → chữ Latin;
//   2) 'auto' bị app map cứng về 'en' (auto-TOC) → cùng triệu chứng.
// Những test này khóa hành vi chuẩn hóa + phát hiện "Latin-hóa".

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_stt/in4up_stt.dart';

void main() {
  group('WhisperLanguage.code — chuẩn hóa mã cho whisper.cpp', () {
    test('giữ nguyên mã hợp lệ', () {
      expect(WhisperLanguage.code('hi'), 'hi');
      expect(WhisperLanguage.code('vi'), 'vi');
      expect(WhisperLanguage.code('en'), 'en');
      expect(WhisperLanguage.code('zh'), 'zh');
      expect(WhisperLanguage.code('th'), 'th');
      expect(WhisperLanguage.code('si'), 'si');
      expect(WhisperLanguage.code('ta'), 'ta');
    });

    test('bỏ region/variant (BCP-47 → 2 ký tự)', () {
      expect(WhisperLanguage.code('hi-IN'), 'hi');
      expect(WhisperLanguage.code('en-US'), 'en');
      expect(WhisperLanguage.code('vi_VN'), 'vi');
      expect(WhisperLanguage.code('zh_TW'), 'zh');
      expect(WhisperLanguage.code('zh-Hant-TW'), 'zh');
      expect(WhisperLanguage.code('pt-BR'), 'pt');
      expect(WhisperLanguage.code('ES'), 'es');
      expect(WhisperLanguage.code('  hi  '), 'hi');
    });

    test('rỗng/null/system → auto (KHÔNG bao giờ là "en")', () {
      expect(WhisperLanguage.code(''), 'auto');
      expect(WhisperLanguage.code(null), 'auto');
      expect(WhisperLanguage.code('auto'), 'auto');
      expect(WhisperLanguage.code('system'), 'auto');
      expect(WhisperLanguage.code('detect'), 'auto');
    });

    test('mã Whisper không hỗ trợ → auto, không làm fail cả job', () {
      // Pali: app có chip 'pi' (Tipiṭaka) nhưng whisper.cpp không có ngôn ngữ
      // này → trước đây plugin ném "unknown language = pi".
      final r = WhisperLanguage.resolve('pi');
      expect(r.code, 'auto');
      expect(r.unsupported, isTrue);
      expect(WhisperLanguage.code('pali'), 'auto');
      expect(WhisperLanguage.code('xx'), 'auto');
      expect(WhisperLanguage.code('ky'), 'auto'); // Kyrgyz: không có trong 99
      expect(WhisperLanguage.supported.contains('ky'), isFalse);
    });

    test('danh sách 99 mã Whisper khớp g_lang (kiểm tra số lượng)', () {
      // whisper.cpp v1.5.4 `g_lang` có đúng 100 mục (99 ngôn ngữ OpenAI +
      // Cantonese 'yue'). Danh sách lệch sẽ làm fallback sai im lặng.
      expect(WhisperLanguage.supported.length, 100);
      expect(WhisperLanguage.supported, contains('hi'));
      expect(WhisperLanguage.supported, contains('yue'));
      expect(WhisperLanguage.supported, contains('haw'));
      expect(WhisperLanguage.supported.contains('auto'), isFalse);
    });

    test('resolve đánh dấu changed khi mã bị biến đổi', () {
      expect(WhisperLanguage.resolve('hi').changed, isFalse);
      expect(WhisperLanguage.resolve('hi-IN').changed, isTrue);
      expect(WhisperLanguage.resolve('fil').code, 'tl');
      expect(WhisperLanguage.resolve('iw').code, 'he');
      expect(WhisperLanguage.resolve('in').code, 'id');
      expect(WhisperLanguage.resolve('vie').code, 'vi');
    });
  });

  group('WhisperLanguage.scriptFor — bảng chữ theo ngôn ngữ', () {
    test('ngôn ngữ ngoài Latin có script riêng', () {
      expect(WhisperLanguage.scriptFor('hi'), 'devanagari');
      expect(WhisperLanguage.scriptFor('mr'), 'devanagari');
      expect(WhisperLanguage.scriptFor('bn'), 'bengali');
      expect(WhisperLanguage.scriptFor('zh'), 'han');
      expect(WhisperLanguage.scriptFor('ja'), 'kana');
      expect(WhisperLanguage.scriptFor('ko'), 'hangul');
      expect(WhisperLanguage.scriptFor('th'), 'thai');
      expect(WhisperLanguage.scriptFor('ar'), 'arabic');
      expect(WhisperLanguage.scriptFor('ru'), 'cyrillic');
    });

    test('Latin + unknown/auto → null hoặc latin (không báo oan)', () {
      expect(WhisperLanguage.scriptFor('vi'), 'latin');
      expect(WhisperLanguage.scriptFor('en'), 'latin');
      expect(WhisperLanguage.scriptFor('id'), 'latin');
      expect(WhisperLanguage.scriptFor('auto'), isNull);
      expect(WhisperLanguage.scriptFor(null), isNull);
      expect(WhisperLanguage.scriptFor('zz'), isNull);
    });
  });

  group('WhisperLanguage.latinizedFor — bắt lỗi "Hindi ra chữ Latin"', () {
    test('Devanagari thật → KHÔNG phải lỗi', () {
      const hindi = 'मैं घर जा रहा हूँ और खाना खाऊँगा';
      expect(
        WhisperLanguage.latinizedFor(language: 'hi', text: hindi),
        isFalse,
      );
    });

    test('Latin roman hóa → là lỗi', () {
      const romanized =
          'main ghar ja raha hoon aur khana khaunga subah jaldi uthna hai';
      expect(
        WhisperLanguage.latinizedFor(language: 'hi', text: romanized),
        isTrue,
      );
    });

    test('văn bản quá ngắn → không đoán', () {
      expect(
        WhisperLanguage.latinizedFor(language: 'hi', text: 'ok hello'),
        isFalse,
      );
      expect(
        WhisperLanguage.latinizedFor(language: 'hi', text: '   '),
        isFalse,
      );
    });

    test('auto / ngôn ngữ Latin → không bao giờ báo lỗi script', () {
      const latin = 'this is plain english text that looks like hindi audio';
      expect(
        WhisperLanguage.latinizedFor(language: 'auto', text: latin),
        isFalse,
      );
      expect(
        WhisperLanguage.latinizedFor(language: 'en', text: latin),
        isFalse,
      );
      expect(
        WhisperLanguage.latinizedFor(language: 'pi', text: latin),
        isFalse,
      );
    });

    test('Hán/Hàn/Thái cũng được phát hiện', () {
      expect(
        WhisperLanguage.latinizedFor(
          language: 'zh',
          text: 'women jintian zai jia li chi fan he shui jiao',
        ),
        isTrue,
      );
      expect(
        WhisperLanguage.latinizedFor(
          language: 'zh',
          text: '我们今天在家里吃饭然后睡觉，明天再去公园',
        ),
        isFalse,
      );
      expect(
        WhisperLanguage.latinizedFor(
          language: 'ko',
          text: 'hangureul jeonhago sipjiman roman hwa doe-eotseumnida',
        ),
        isTrue,
      );
    });

    test('script khác trong cùng văn bản → không báo (có thể là trích dẫn)',
        () {
      // Trích dẫn tiếng Anh lẫn trong lời Hindi là chuyện bình thường.
      const mixed =
          'मैं घर जा रहा हूँ but I will call you back in ten minutes only';
      expect(
        WhisperLanguage.latinizedFor(language: 'hi', text: mixed),
        isFalse,
      );
    });
  });

  group('WhisperLanguage.prefersStrongModel — model theo script', () {
    test('script ngoài Latin cần model ≥ base', () {
      expect(WhisperLanguage.prefersStrongModel('hi'), isTrue);
      expect(WhisperLanguage.prefersStrongModel('hi-IN'), isTrue);
      expect(WhisperLanguage.prefersStrongModel('zh'), isTrue);
      expect(WhisperLanguage.prefersStrongModel('th'), isTrue);
      expect(WhisperLanguage.prefersStrongModel('ar'), isTrue);
    });

    test('Latin/auto giữ chính sách tiny-first (RAM)', () {
      expect(WhisperLanguage.prefersStrongModel('vi'), isFalse);
      expect(WhisperLanguage.prefersStrongModel('en'), isFalse);
      expect(WhisperLanguage.prefersStrongModel('id'), isFalse);
      expect(WhisperLanguage.prefersStrongModel('auto'), isFalse);
      expect(WhisperLanguage.prefersStrongModel('pi'), isFalse);
    });
  });

  group('SttConfig — language mặc định là auto, honorWhisperModel', () {
    test('default config không còn ép "en-US"', () {
      const cfg = SttConfig();
      expect(cfg.language, 'auto');
      expect(WhisperLanguage.code(cfg.language), 'auto');
      expect(cfg.honorWhisperModel, isFalse);
    });

    test('copyWith giữ honorWhisperModel', () {
      final cfg = SttConfig.deepLearning.copyWith(
        whisperModel: WhisperModelLevel.small,
        honorWhisperModel: true,
      );
      expect(cfg.honorWhisperModel, isTrue);
      expect(cfg.whisperModel, WhisperModelLevel.small);
      expect(cfg.language, SttConfig.deepLearning.language);
      // copyWith(null) không được bật cờ.
      expect(cfg.copyWith().honorWhisperModel, isTrue);
    });
  });
}
