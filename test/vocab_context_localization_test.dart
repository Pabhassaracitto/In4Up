import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/app_ui_translations.dart';
import 'package:in4up/models/vocab_context.dart';

void main() {
  group('VocabContext localization boundaries', () {
    test('localizes generated PDF positions without translating source names', () {
      final vocabContext = VocabContext.fromPdf(
        fileName: 'Tài liệu của tôi.pdf',
        page: 42,
        surroundingText: 'Nội dung do người dùng cung cấp',
      );

      final position = AppUITranslations.translate(
        vocabContext.pageOrPosition!,
        'en',
      );

      expect(vocabContext.hasGeneratedPositionLabel, isTrue);
      expect(position, 'page 42');
      expect(
        vocabContext.composeDisplaySource(position),
        'Tài liệu của tôi.pdf, page 42',
      );
      expect(
        vocabContext.surroundingText,
        'Nội dung do người dùng cung cấp',
      );
    });

    test('keeps external web metadata outside generated-position translation', () {
      final vocabContext = VocabContext.fromWeb(
        url: 'https://example.com/article',
        pageTitle: 'Trang của người dùng',
        surroundingText: 'Nội dung tiếng Việt trên web',
      );

      expect(vocabContext.hasGeneratedPositionLabel, isFalse);
      expect(
        vocabContext.composeDisplaySource(vocabContext.pageOrPosition),
        'Trang của người dùng, example.com',
      );
    });

    test('localizes precision UI fragments but preserves anchor text', () {
      final vocabContext = VocabContext(
        id: 'context-1',
        sourceType: 'pdf',
        surroundingText: 'Document content',
        encounteredAt: DateTime(2026),
        pageIndexHint: 1,
        lineIndexHint: 2,
        scrollProgressHint: 0.5,
        anchorText: 'Đoạn neo của người dùng',
      );

      final translatedParts = vocabContext.precisionSummaryParts
          .map((part) => AppUITranslations.translate(part, 'en'))
          .toList();

      expect(
        translatedParts,
        [
          'page 2',
          'line 3',
          'scroll 50%',
          'anchor "Đoạn neo của người dùng"',
        ],
      );
    });
  });
}
