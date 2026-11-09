import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/app_ui_translations.dart';
import 'package:in4up/features/ocr/ocr_ai_refine_service.dart';

void main() {
  group('OCR AI refinement availability', () {
    test('offers refinement only when the editable OCR text has content', () {
      expect(OcrAiRefinePolicy.shouldOffer('  '), isFalse);
      expect(OcrAiRefinePolicy.shouldOffer('\n\t'), isFalse);
      expect(OcrAiRefinePolicy.shouldOffer('Recognized words'), isTrue);
    });
  });

  test('OCR AI action and feedback are translated in all priority locales', () {
    const messages = [
      'Tinh chỉnh bằng AI',
      'Đang tinh chỉnh...',
      'Không thể tinh chỉnh lúc này. Kiểm tra cấu hình AI và kết nối rồi thử lại.',
      'Xem bản AI',
      'Xem bản trước AI',
    ];
    const locales = ['en', 'hi', 'zh', 'zh_TW', 'si'];

    for (final message in messages) {
      for (final locale in locales) {
        expect(
          AppUITranslations.translate(message, locale),
          isNot(message),
          reason: '$message has no translation for $locale',
        );
      }
    }
  });
}
