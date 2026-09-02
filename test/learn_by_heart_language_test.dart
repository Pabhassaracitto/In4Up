import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/learn_by_heart/models/learn_by_heart_item.dart';
import 'package:in4up/features/learn_by_heart/models/recitation_language.dart';

void main() {
  group('RecitationLanguage', () {
    test('maps Pali and Sanskrit to an English-capable TTS voice', () {
      expect(RecitationLanguage.fromCode('pi').ttsLocale, 'en-US');
      expect(RecitationLanguage.fromCode('pali').code, 'pi');
      expect(RecitationLanguage.fromCode('sa').ttsLocale, 'en-US');
      expect(RecitationLanguage.fromCode('vi').ttsLocale, 'vi-VN');
      expect(RecitationLanguage.fromCode('en').ttsLocale, 'en-US');
    });

    test('never uses a Vietnamese voice for English or Pali text', () {
      expect(
        RecitationLanguage.speakLocale(
          declaredCode: 'vi',
          text: 'This is an English sentence and we are learning the language.',
        ),
        'en-US',
      );
      expect(
        RecitationLanguage.speakLocale(
          declaredCode: 'vi',
          text: 'Manopubbaṅgamā dhammā, manoseṭṭhā manomayā.',
        ),
        'en-US',
      );
    });

    test('keeps Vietnamese voice for Vietnamese diacritics', () {
      expect(
        RecitationLanguage.speakLocale(
          declaredCode: 'vi',
          text: 'Ý dẫn đầu các pháp, ý làm chủ, ý tạo.',
        ),
        'vi-VN',
      );
    });

    test('uses declared English even without stopwords when text is Latin', () {
      expect(
        RecitationLanguage.speakLocale(
          declaredCode: 'en',
          text: 'Hatred is never appeased by hatred.',
        ),
        'en-US',
      );
    });
  });

  group('LearnByHeartItem language sides', () {
    LearnByHeartItem item({
      MemorizeSide side = MemorizeSide.target,
      String sourceLang = 'pi',
      String targetLang = 'vi',
    }) {
      return LearnByHeartItem(
        id: 't1',
        title: 'Dhp 1',
        paliText: 'Manopubbaṅgamā dhammā.\nmanoseṭṭhā manomayā.',
        vietnameseText: 'Ý dẫn đầu các pháp.\nÝ làm chủ, ý tạo.',
        sourceLang: sourceLang,
        targetLang: targetLang,
        memorizeSide: side,
        createdAt: DateTime(2024, 1, 1),
      );
    }

    test('defaults memorize the translation side for old Pali/Việt items', () {
      final verse = item();
      expect(verse.memorizeText, contains('Ý dẫn đầu'));
      expect(verse.memorizeLang, 'vi');
      expect(verse.sourceLang, 'pi');
    });

    test('can memorize the source side (Pali or English)', () {
      final pali = item(side: MemorizeSide.source);
      expect(pali.memorizeText, contains('Manopubbaṅgamā'));
      expect(pali.memorizeLang, 'pi');

      final english = item(
        side: MemorizeSide.source,
        sourceLang: 'en',
        targetLang: 'vi',
      ).copyWith(paliText: 'Mind precedes all mental states.');
      expect(english.memorizeLang, 'en');
      expect(english.memorizeText, contains('Mind precedes'));
    });

    test('round-trips new language fields without dropping old JSON keys', () {
      final json = item(side: MemorizeSide.source, sourceLang: 'en').toJson();
      expect(json['paliText'], isNotEmpty);
      expect(json['vietnameseText'], isNotEmpty);
      expect(json['sourceLang'], 'en');
      expect(json['memorizeSide'], 'source');
      final restored = LearnByHeartItem.fromJson(json);
      expect(restored.memorizeSide, MemorizeSide.source);
      expect(restored.sourceLang, 'en');
    });

    test('old JSON without sourceLang still memorizes Vietnamese', () {
      final restored = LearnByHeartItem.fromJson({
        'id': 'old',
        'title': 'Dhp 1',
        'paliText': 'Manopubbaṅgamā dhammā.',
        'vietnameseText': 'Ý dẫn đầu các pháp.',
        'createdAt': '2024-01-01T00:00:00.000',
      });
      expect(restored.sourceLang, 'pi');
      expect(restored.targetLang, 'vi');
      expect(restored.memorizeSide, MemorizeSide.target);
      expect(restored.memorizeText, 'Ý dẫn đầu các pháp.');
    });
  });
}
