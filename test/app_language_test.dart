import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/app_language.dart';
import 'package:in4up/features/tts/language_detector.dart';

void main() {
  group('AppLanguageCatalog', () {
    test('contains the same 26 languages exposed by app settings', () {
      expect(AppLanguageCatalog.languages, hasLength(26));
      expect(
        AppLanguageCatalog.languages.map((e) => e.translationCode).toSet(),
        hasLength(26),
      );
      expect(
        AppLanguageCatalog.languages.map((e) => e.appLocaleCode).toSet(),
        hasLength(26),
      );
      expect(
        AppLanguageCatalog.languages.every(
          (e) => e.flag.isNotEmpty && e.ttsLocale.contains('-'),
        ),
        isTrue,
      );
    });

    test('normalizes translation, app and TTS locale codes', () {
      expect(AppLanguageCatalog.fromCode('vi-VN').translationCode, 'VI');
      expect(AppLanguageCatalog.fromCode('zh_TW').translationCode, 'ZH-TW');
      expect(AppLanguageCatalog.fromCode('zh-Hant').ttsLocale, 'zh-TW');
      expect(AppLanguageCatalog.fromCode('en_US').ttsLocale, 'en-US');
    });
  });

  group('LanguageDetector', () {
    final samples = <String, String>{
      'مرحبا كيف حالك اليوم': 'AR',
      'এটি একটি বাংলা বাক্য': 'BN',
      'འདི་ནི་བོད་ཡིག་གི་ཚིག་ཡིན།': 'BO',
      'Das ist ein deutscher Satz und wir lernen die Sprache.': 'DE',
      'This is an English sentence and we are learning the language.': 'EN',
      'Esta es una frase en español y nosotros aprendemos el idioma.': 'ES',
      'Bonjour, ceci est une phrase française et nous apprenons la langue.': 'FR',
      'यह हिन्दी में एक वाक्य है और हम सीख रहे हैं': 'HI',
      'Ini adalah kalimat bahasa Indonesia yang sedang kami pelajari.': 'ID',
      'Questa è una frase italiana e noi impariamo la lingua.': 'IT',
      'これは日本語の文章です。言語を勉強しています。': 'JA',
      'នេះគឺជាប្រយោគភាសាខ្មែរ': 'KM',
      '이것은 한국어 문장입니다': 'KO',
      'ນີ້ແມ່ນປະໂຫຍກພາສາລາວ': 'LO',
      'Сайн байна уу бид монгол хэл сурч байна': 'MN',
      'हे मराठी वाक्य आहे आणि आपण भाषा शिकत आहोत': 'MR',
      'ဤသည်မှာ မြန်မာစာကြောင်း ဖြစ်သည်': 'MY',
      'Esta é uma frase em português e nós aprendemos a língua.': 'PT',
      'Это русское предложение и мы изучаем язык.': 'RU',
      'මෙය සිංහල වාක්‍යයකි': 'SI',
      'இது ஒரு தமிழ் வாக்கியம்': 'TA',
      'ఇది తెలుగు వాక్యం': 'TE',
      'นี่คือประโยคภาษาไทย': 'TH',
      'Xin chào, đây là một câu tiếng Việt và chúng tôi đang học.': 'VI',
      '这是一个中文句子，我们正在学习语言。': 'ZH',
      '這是一個中文句子，我們正在學習語言。': 'ZH-TW',
    };

    for (final entry in samples.entries) {
      test('detects ${entry.value}', () {
        expect(
          LanguageDetector.detectLanguage(entry.key).translationCode,
          entry.value,
        );
      });
    }

    test('uses document language as fallback for short ambiguous lines', () {
      expect(
        LanguageDetector.detectLanguage(
          'Merci',
          fallback: AppLanguageCatalog.fromCode('FR'),
        ).translationCode,
        'FR',
      );
    });

    test('returns a concrete TTS locale', () {
      expect(LanguageDetector.detect('Xin chào thế giới'), 'vi-VN');
      expect(LanguageDetector.detect('Hello world'), 'en-US');
      expect(LanguageDetector.detect('こんにちは世界'), 'ja-JP');
    });
  });
}
