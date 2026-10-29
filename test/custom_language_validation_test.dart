import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/app_ui_translations.dart';
import 'package:in4up/models/vocab_context.dart';
import 'package:in4up/models/vocabulary_type.dart';
import 'package:in4up/models/word_entry.dart';
import 'package:in4up/widgets/vocab_entry_meta.dart';

void main() {
  group('Custom language code validation and normalization (WLIST-LANG-001)', () {
    test('accepts valid 2 to 4 letter ISO/custom language codes', () {
      expect(validateCustomLanguageCode('pi'), isNull);
      expect(validateCustomLanguageCode('PI'), isNull);
      expect(validateCustomLanguageCode('  lo  '), isNull);
      expect(validateCustomLanguageCode('my'), isNull);
      expect(validateCustomLanguageCode('pali'), isNull);
      expect(validateCustomLanguageCode('de'), isNull);
      expect(validateCustomLanguageCode('fra'), isNull);
    });

    test('normalizes valid language codes to lowercase trimmed string', () {
      expect(normalizeCustomLanguageCode('pi'), 'pi');
      expect(normalizeCustomLanguageCode('PI'), 'pi');
      expect(normalizeCustomLanguageCode('  LO  '), 'lo');
      expect(normalizeCustomLanguageCode(' Pali '), 'pali');
      expect(normalizeCustomLanguageCode('MY'), 'my');
    });

    test('rejects empty or whitespace-only language code', () {
      expect(validateCustomLanguageCode(''), isNotNull);
      expect(validateCustomLanguageCode('   '), isNotNull);
      expect(validateCustomLanguageCode(null), isNotNull);
      expect(normalizeCustomLanguageCode(''), isNull);
      expect(normalizeCustomLanguageCode('   '), isNull);
    });

    test('rejects codes shorter than 2 or longer than 4 characters', () {
      expect(validateCustomLanguageCode('a'), isNotNull);
      expect(validateCustomLanguageCode('latin'), isNotNull);
      expect(validateCustomLanguageCode('english'), isNotNull);
      expect(normalizeCustomLanguageCode('a'), isNull);
      expect(normalizeCustomLanguageCode('latin'), isNull);
    });

    test('rejects codes containing digits, spaces, punctuation or non-Latin characters', () {
      expect(validateCustomLanguageCode('p1'), isNotNull);
      expect(validateCustomLanguageCode('p i'), isNotNull);
      expect(validateCustomLanguageCode('p-i'), isNotNull);
      expect(validateCustomLanguageCode('p_i'), isNotNull);
      expect(validateCustomLanguageCode('tiếng'), isNotNull);
      expect(validateCustomLanguageCode('пали'), isNotNull);
      expect(normalizeCustomLanguageCode('p1'), isNull);
      expect(normalizeCustomLanguageCode('p i'), isNull);
    });
  });

  group('WordEntry language persistence and filtering by custom language', () {
    test('creates and tags WordEntry with custom normalized language', () {
      final customLang = normalizeCustomLanguageCode('pi')!;
      final entry = WordEntry(
        id: 'v_test_001',
        word: 'anatta',
        meaning: 'vô ngã',
        language: customLang,
        languages: [customLang],
        vocabType: VocabularyType.word,
      );

      expect(entry.language, 'pi');
      expect(entry.languages, contains('pi'));

      // Thêm ngôn ngữ khác
      entry.addLanguage('pali');
      expect(entry.languages, containsAll(['pi', 'pali']));

      // Thêm trùng lặp (không bị nhân đôi)
      entry.addLanguage('pi');
      expect(entry.languages.where((l) => l == 'pi').length, 1);
    });

    test('filters list of WordEntry items by custom language code', () {
      final entries = [
        WordEntry(
          id: '1',
          word: 'apple',
          meaning: 'quả táo',
          language: 'en',
          languages: ['en'],
        ),
        WordEntry(
          id: '2',
          word: 'dukkha',
          meaning: 'khổ',
          language: 'pi',
          languages: ['pi'],
        ),
        WordEntry(
          id: '3',
          word: 'anicca',
          meaning: 'vô thường',
          language: 'pi',
          languages: ['pi', 'pali'],
        ),
        WordEntry(
          id: '4',
          word: 'sati',
          meaning: 'chánh niệm',
          language: 'pali',
          languages: ['pali'],
        ),
      ];

      final piFiltered = entries.where((e) => e.languages.contains('pi')).toList();
      expect(piFiltered.map((e) => e.word), containsAll(['dukkha', 'anicca']));
      expect(piFiltered.length, 2);

      final paliFiltered = entries.where((e) => e.languages.contains('pali')).toList();
      expect(paliFiltered.map((e) => e.word), containsAll(['anicca', 'sati']));
      expect(paliFiltered.length, 2);
    });
  });

  group('Rule 5 i18n — UI labels for custom language creation and errors', () {
    const testLabels = [
      '＋ Thêm ngôn ngữ…',
      'Tạo ngôn ngữ mới… (Enter để chọn)',
      'Mã ngôn ngữ phải từ 2 đến 4 ký tự (vd: pi, lo, my)',
      'Mã ngôn ngữ chỉ được chứa chữ cái Latin (a-z)',
      'Mã ngôn ngữ không được để trống',
    ];

    for (final label in testLabels) {
      test('label "$label" translates to non-empty English without Vietnamese chars', () {
        final en = AppUITranslations.translate(label, 'en');
        expect(en, isNotEmpty, reason: '$label has empty English translation');
        expect(
          RegExp(r'[đĐơƠưƯảạằắẳẵặầấẩẫậẻẽẹềếểễệỉĩịỏọồốổỗộờớởỡợủũụừứửữựỳỷỹỵ]').hasMatch(en),
          isFalse,
          reason: 'English translation for "$label" still contains Vietnamese: $en',
        );
      });
    }
  });
}
