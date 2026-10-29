import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/app_language.dart';
import 'package:in4up/core/language/generated_ui_translations.dart';
import 'package:in4up/features/tipitaka/models/book.dart';
import 'package:in4up/features/tipitaka/models/reader_appearance.dart';
import 'package:in4up/features/tipitaka/models/segment.dart';
import 'package:in4up/features/tipitaka/services/tipitaka_markup.dart';
import 'package:in4up/features/tipitaka/services/tipitaka_tts.dart';

void main() {
  TipitakaBook book(String code, {String? metadata}) => TipitakaBook(
        id: code.hashCode,
        collectionId: 1,
        code: code,
        namePali: code,
        nameEn: code,
        nameVi: code,
        orderIndex: 0,
        metadataJson: metadata,
      );

  group('Tipiṭaka catalogue taxonomy', () {
    test('catalogue labels have English and Vietnamese translations', () {
      expect(generatedUiTranslations['Tam Tạng Chính Văn']?['en'], 'Canonical Tipiṭaka');
      expect(generatedUiTranslations['Tam Tạng Chính Văn']?['vi'], 'Tam Tạng Chính Văn');
      expect(generatedUiTranslations['Tạng Luật']?['en'], 'Vinaya Piṭaka');
      expect(generatedUiTranslations['Tạng Kinh']?['en'], 'Sutta Piṭaka');
      expect(generatedUiTranslations['Tạng → nhóm/bộ → bài kinh']?['en'],
          'Basket → collection → book');
    });

    test('edition codes route Mūla, Aṭṭhakathā and Ṭīkā to separate branches', () {
      expect(book('MN01M_MUL').catalogSection, TipitakaCatalogSection.canonical);
      expect(book('MN01A_ATT').catalogSection, TipitakaCatalogSection.commentary);
      expect(book('MN01T_TIK').catalogSection, TipitakaCatalogSection.subcommentary);
    });

    test('metadata and known chronicle titles expose extra/Sri Lankan branches', () {
      expect(
        book('PARITTA', metadata: '{"catalog_section":"extra-canonical"}')
            .catalogSection,
        TipitakaCatalogSection.extraCanonical,
      );
      expect(book('MAHAVAMSA').catalogSection, TipitakaCatalogSection.sriLanka);
    });

    test('bilingual reader mode resolves both text layers on one page', () {
      final visibility = TipitakaDisplayVisibility.resolve(
        mode: TipitakaDisplayMode.bilingual,
        hasPali: true,
      );
      expect(visibility.showPali, isTrue);
      expect(visibility.showTranslation, isTrue);
    });

    test('translation-only mode hides Pali without hiding the translation', () {
      final visibility = TipitakaDisplayVisibility.resolve(
        mode: TipitakaDisplayMode.translationOnly,
        hasPali: true,
      );
      expect(visibility.showPali, isFalse);
      expect(visibility.showTranslation, isTrue);
    });

    test('content-language labels use the complete app language catalog', () {
      for (final language in AppLanguageCatalog.languages) {
        expect(
          tipitakaLanguageLabel(language.translationCode),
          language.nativeName,
          reason: language.translationCode,
        );
      }
      expect(tipitakaLanguageLabel('zh_TW'), AppLanguageCatalog.languages.last.nativeName);
      expect(tipitakaLanguageLabel('pi'), 'Pāḷi');
    });
  });

  group('Tipiṭaka language-aware recitation', () {
    final segment = TipitakaSegment(
      id: 1,
      bookId: 1,
      reference: 'MN 1',
      paliText: 'Ānanda, ñāṇaṃ ṭhitaṃ; ḍhamma, ṇāma, lṭ.',
      translationVi: 'Bản dịch tiếng Việt.',
      translationEn: 'An English translation.',
      orderIndex: 0,
    );

    test('bilingual mode emits separate Hindi-Pāli and Vietnamese utterances', () {
      final chunks = tipitakaSpeechChunks(
        segment: segment,
        mode: TipitakaDisplayMode.bilingual,
        translationLanguage: 'vi',
      );
      expect(chunks.map((chunk) => chunk.languageCode), ['hi', 'vi']);
      expect(chunks.first.text, 'Aananda, nyaanam thitam; dhamma, naama, lt.');
      expect(chunks.last.text, 'Bản dịch tiếng Việt.');
    });

    test('single-language modes never include the other language', () {
      final paliOnly = tipitakaSpeechChunks(
        segment: segment,
        mode: TipitakaDisplayMode.paliOnly,
        translationLanguage: 'vi',
      );
      expect(paliOnly.map((chunk) => chunk.languageCode), ['hi']);
      final translationOnly = tipitakaSpeechChunks(
        segment: segment,
        mode: TipitakaDisplayMode.translationOnly,
        translationLanguage: 'en',
      );
      expect(translationOnly.map((chunk) => chunk.languageCode), ['en']);
      expect(translationOnly.single.text, 'An English translation.');
    });

    test('Pāli in a dynamic translation map remains the canonical text layer', () {
      const dynamicPali = TipitakaSegment(
        id: 2,
        bookId: 1,
        reference: 'MN 2',
        paliText: '',
        orderIndex: 1,
        translations: {'pi': 'Evaṃ me sutaṃ.', 'vi': 'Tôi nghe như vầy.'},
      );
      expect(dynamicPali.canonicalPaliText, 'Evaṃ me sutaṃ.');
      final chunks = tipitakaSpeechChunks(
        segment: dynamicPali,
        mode: TipitakaDisplayMode.bilingual,
        translationLanguage: 'vi',
      );
      expect(chunks.map((chunk) => chunk.languageCode), ['hi', 'vi']);
    });

    test('optional English secondary is spoken with an English voice', () {
      final chunks = tipitakaSpeechChunks(
        segment: segment,
        mode: TipitakaDisplayMode.bilingual,
        translationLanguage: 'vi',
        includeEnglish: true,
      );
      expect(chunks.map((chunk) => chunk.languageCode), ['hi', 'vi', 'en']);
      expect(chunks.last.text, 'An English translation.');
    });
  });
}
