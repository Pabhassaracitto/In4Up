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
      expect(generatedUiTranslations['Tạng Luật']?['hi'], 'विनय पिटक');
      expect(generatedUiTranslations['Tạng Kinh']?['zh'], '经藏');
      expect(generatedUiTranslations['Tạng Kinh']?['zh_TW'], '經藏');
      expect(generatedUiTranslations['Tạng Kinh']?['si'], 'සූත්‍ර පිටකය');
    });

    test('edition codes route Mūla, Aṭṭhakathā and Ṭīkā to separate branches', () {
      expect(book('MN01M_MUL').catalogSection, TipitakaCatalogSection.canonical);
      expect(book('MN01A_ATT').catalogSection, TipitakaCatalogSection.commentary);
      expect(book('MN01T_TIK').catalogSection, TipitakaCatalogSection.subcommentary);
    });

    test('source edition takes precedence over words in a title', () {
      TipitakaBook sourceBook(String code, String title) => TipitakaBook(
        id: 90, collectionId: 1, code: code, namePali: '',
        nameEn: title, nameVi: '', orderIndex: 0,
        metadataJson: '{"source_table":"$code"}',
      );
      expect(sourceBook('vin01m_mul', 'Commentary on Sri Lanka').catalogSection,
          TipitakaCatalogSection.canonical);
      expect(sourceBook('vin01a_att', 'History of the council').catalogSection,
          TipitakaCatalogSection.commentary);
      expect(sourceBook('vin01t1_tik', 'Dictionary').catalogSection,
          TipitakaCatalogSection.subcommentary);
    });

    test('CSCD source hierarchy overrides misleading importer collections', () {
      expect(book('S0101M_MUL').catalogSection, TipitakaCatalogSection.canonical);
      expect(book('S0101M_MUL').cscdLocation!.parents, ['Dīghanikāya']);
      expect(book('S0201M_MUL').cscdLocation!.parents, ['Majjhimanikāya']);
      expect(book('E0101N_MUL').catalogSection, TipitakaCatalogSection.extraCanonical);
      expect(book('E0103N_ATT').catalogSection, TipitakaCatalogSection.extraCanonical);
      expect(book('E1201N_NRF').catalogSection, TipitakaCatalogSection.sriLanka);
      expect(book('VIN04T_NRF').catalogSection, TipitakaCatalogSection.subcommentary);
      expect(book('S0402M1_MUL').cscdLocation!.order,
          lessThan(book('S0402M2_MUL').cscdLocation!.order));
      expect(book('UNRECOGNIZED').cscdLocation, isNull);
    });

    test('metadata and known titles expose extra/Sri Lankan branches', () {
      expect(
        book('PARITTA', metadata: '{"catalog_section":"extra-canonical"}')
            .catalogSection,
        TipitakaCatalogSection.extraCanonical,
      );
      expect(book('VISUDDHIMAGGA').catalogSection,
          TipitakaCatalogSection.extraCanonical);
      expect(book('VSM01').catalogSection,
          TipitakaCatalogSection.extraCanonical);
      expect(book('BUDDHIST_COUNCIL_QA').catalogSection,
          TipitakaCatalogSection.extraCanonical);
      expect(
        TipitakaBook(
          id: 4,
          collectionId: 1,
          code: 'LEDITEXT01',
          namePali: '',
          nameEn: 'Collected Texts of Ledi Sayadaw',
          nameVi: 'Tuyển Tập Ledi Sayadaw',
          orderIndex: 2,
        ).catalogSection,
        TipitakaCatalogSection.extraCanonical,
      );
      expect(
        TipitakaBook(
          id: 5,
          collectionId: 1,
          code: 'COUNCIL_QA',
          namePali: '',
          nameEn: '',
          nameVi: 'Vấn Đáp Kết Tập Kinh Điển',
          orderIndex: 3,
        ).catalogSection,
        TipitakaCatalogSection.extraCanonical,
      );
      expect(
        TipitakaBook(
          id: 2,
          collectionId: 1,
          code: 'EXTRA01',
          namePali: '',
          nameEn: '',
          nameVi: 'Thanh Tịnh Đạo',
          orderIndex: 0,
        ).catalogSection,
        TipitakaCatalogSection.extraCanonical,
      );
      expect(
        TipitakaBook(
          id: 3,
          collectionId: 1,
          code: 'EXTRA02',
          namePali: '',
          nameEn: '',
          nameVi: 'Vấn Đáp Kết Tập Kinh Điển',
          orderIndex: 1,
        ).catalogSection,
        TipitakaCatalogSection.extraCanonical,
      );
      expect(book('LEDISAYADAW').catalogSection,
          TipitakaCatalogSection.extraCanonical);
      expect(book('MAHAVAMSA').catalogSection, TipitakaCatalogSection.sriLanka);
    });

    test('demo fallback is recognizable by the model', () {
      expect(book('DEMO').isDemo, isTrue);
      expect(book('MN01M_MUL').isDemo, isFalse);
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
