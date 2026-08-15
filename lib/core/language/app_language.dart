/// Canonical language metadata shared by app settings, translation and TTS.
///
/// The catalog intentionally mirrors the 26 languages exposed by the app
/// language setting. Translation codes stay uppercase for compatibility with
/// DeepL/DeepLX, while [ttsLocale] is the concrete locale passed to the native
/// speech engine.
class AppLanguage {
  final String translationCode;
  final String appLocaleCode;
  final String ttsLocale;
  final String flag;
  final String nativeName;
  final String englishName;
  final String vietnameseName;

  const AppLanguage({
    required this.translationCode,
    required this.appLocaleCode,
    required this.ttsLocale,
    required this.flag,
    required this.nativeName,
    required this.englishName,
    required this.vietnameseName,
  });

  String get shortCode => translationCode.split('-').first;
  String get languageTag => appLocaleCode.replaceAll('_', '-');
  String get pickerLabel => '$flag $nativeName';
  String get compactLabel => '$flag $translationCode';
}

class AppLanguageCatalog {
  AppLanguageCatalog._();

  static const languages = <AppLanguage>[
    AppLanguage(
      translationCode: 'AR',
      appLocaleCode: 'ar',
      ttsLocale: 'ar-SA',
      flag: '🇸🇦',
      nativeName: 'العربية',
      englishName: 'Arabic',
      vietnameseName: 'Content',
    ),
    AppLanguage(
      translationCode: 'BN',
      appLocaleCode: 'bn',
      ttsLocale: 'bn-BD',
      flag: '🇧🇩',
      nativeName: 'বাংলা',
      englishName: 'Bengali',
      vietnameseName: 'Bengali',
    ),
    AppLanguage(
      translationCode: 'BO',
      appLocaleCode: 'bo',
      ttsLocale: 'bo-CN',
      flag: '🏔️',
      nativeName: 'བོད་ཡིག',
      englishName: 'Tibetan',
      vietnameseName: 'Content',
    ),
    AppLanguage(
      translationCode: 'DE',
      appLocaleCode: 'de',
      ttsLocale: 'de-DE',
      flag: '🇩🇪',
      nativeName: 'Deutsch',
      englishName: 'German',
      vietnameseName: 'Content',
    ),
    AppLanguage(
      translationCode: 'EN',
      appLocaleCode: 'en',
      ttsLocale: 'en-US',
      flag: '🇬🇧',
      nativeName: 'English',
      englishName: 'English',
      vietnameseName: 'Anh',
    ),
    AppLanguage(
      translationCode: 'ES',
      appLocaleCode: 'es',
      ttsLocale: 'es-ES',
      flag: '🇪🇸',
      nativeName: 'Español',
      englishName: 'Spanish',
      vietnameseName: 'Content',
    ),
    AppLanguage(
      translationCode: 'FR',
      appLocaleCode: 'fr',
      ttsLocale: 'fr-FR',
      flag: '🇫🇷',
      nativeName: 'Français',
      englishName: 'French',
      vietnameseName: 'Content',
    ),
    AppLanguage(
      translationCode: 'HI',
      appLocaleCode: 'hi',
      ttsLocale: 'hi-IN',
      flag: '🇮🇳',
      nativeName: 'हिन्दी',
      englishName: 'Hindi',
      vietnameseName: 'Hindi',
    ),
    AppLanguage(
      translationCode: 'ID',
      appLocaleCode: 'id',
      ttsLocale: 'id-ID',
      flag: '🇮🇩',
      nativeName: 'Bahasa Indonesia',
      englishName: 'Indonesian',
      vietnameseName: 'Indonesia',
    ),
    AppLanguage(
      translationCode: 'IT',
      appLocaleCode: 'it',
      ttsLocale: 'it-IT',
      flag: '🇮🇹',
      nativeName: 'Italiano',
      englishName: 'Italian',
      vietnameseName: 'Ý',
    ),
    AppLanguage(
      translationCode: 'JA',
      appLocaleCode: 'ja',
      ttsLocale: 'ja-JP',
      flag: '🇯🇵',
      nativeName: '日本語',
      englishName: 'Japanese',
      vietnameseName: 'Content',
    ),
    AppLanguage(
      translationCode: 'KM',
      appLocaleCode: 'km',
      ttsLocale: 'km-KH',
      flag: '🇰🇭',
      nativeName: 'ភាសាខ្មែរ',
      englishName: 'Khmer',
      vietnameseName: 'Khmer',
    ),
    AppLanguage(
      translationCode: 'KO',
      appLocaleCode: 'ko',
      ttsLocale: 'ko-KR',
      flag: '🇰🇷',
      nativeName: '한국어',
      englishName: 'Korean',
      vietnameseName: 'Content',
    ),
    AppLanguage(
      translationCode: 'LO',
      appLocaleCode: 'lo',
      ttsLocale: 'lo-LA',
      flag: '🇱🇦',
      nativeName: 'ພາສາລາວ',
      englishName: 'Lao',
      vietnameseName: 'Content',
    ),
    AppLanguage(
      translationCode: 'MN',
      appLocaleCode: 'mn',
      ttsLocale: 'mn-MN',
      flag: '🇲🇳',
      nativeName: 'Монгол',
      englishName: 'Mongolian',
      vietnameseName: 'Content',
    ),
    AppLanguage(
      translationCode: 'MR',
      appLocaleCode: 'mr',
      ttsLocale: 'mr-IN',
      flag: '🇮🇳',
      nativeName: 'मराठी',
      englishName: 'Marathi',
      vietnameseName: 'Marathi',
    ),
    AppLanguage(
      translationCode: 'MY',
      appLocaleCode: 'my',
      ttsLocale: 'my-MM',
      flag: '🇲🇲',
      nativeName: 'မြန်မာ',
      englishName: 'Burmese',
      vietnameseName: 'Myanmar',
    ),
    AppLanguage(
      translationCode: 'PT',
      appLocaleCode: 'pt',
      ttsLocale: 'pt-PT',
      flag: '🇵🇹',
      nativeName: 'Content',
      englishName: 'Portuguese',
      vietnameseName: 'Content',
    ),
    AppLanguage(
      translationCode: 'RU',
      appLocaleCode: 'ru',
      ttsLocale: 'ru-RU',
      flag: '🇷🇺',
      nativeName: 'Русский',
      englishName: 'Russian',
      vietnameseName: 'Nga',
    ),
    AppLanguage(
      translationCode: 'SI',
      appLocaleCode: 'si',
      ttsLocale: 'si-LK',
      flag: '🇱🇰',
      nativeName: 'සිංහල',
      englishName: 'Sinhala',
      vietnameseName: 'Sinhala',
    ),
    AppLanguage(
      translationCode: 'TA',
      appLocaleCode: 'ta',
      ttsLocale: 'ta-IN',
      flag: '🇮🇳',
      nativeName: 'தமிழ்',
      englishName: 'Tamil',
      vietnameseName: 'Tamil',
    ),
    AppLanguage(
      translationCode: 'TE',
      appLocaleCode: 'te',
      ttsLocale: 'te-IN',
      flag: '🇮🇳',
      nativeName: 'తెలుగు',
      englishName: 'Telugu',
      vietnameseName: 'Telugu',
    ),
    AppLanguage(
      translationCode: 'TH',
      appLocaleCode: 'th',
      ttsLocale: 'th-TH',
      flag: '🇹🇭',
      nativeName: 'ไทย',
      englishName: 'Thai',
      vietnameseName: 'Content',
    ),
    AppLanguage(
      translationCode: 'VI',
      appLocaleCode: 'vi',
      ttsLocale: 'vi-VN',
      flag: '🇻🇳',
      nativeName: 'Content',
      englishName: 'Vietnamese',
      vietnameseName: 'Content',
    ),
    AppLanguage(
      translationCode: 'ZH',
      appLocaleCode: 'zh',
      ttsLocale: 'zh-CN',
      flag: '🇨🇳',
      nativeName: '中文（简体）',
      englishName: 'Chinese (Simplified)',
      vietnameseName: 'Content',
    ),
    AppLanguage(
      translationCode: 'ZH-TW',
      appLocaleCode: 'zh_TW',
      ttsLocale: 'zh-TW',
      flag: '🇹🇼',
      nativeName: '中文（繁體）',
      englishName: 'Chinese (Traditional)',
      vietnameseName: 'Content',
    ),
  ];

  static AppLanguage get english => languages[4];
  static AppLanguage get vietnamese => languages[23];

  static AppLanguage? maybeFromCode(String? rawCode) {
    if (rawCode == null || rawCode.trim().isEmpty) return null;
    final normalized = rawCode.trim().replaceAll('_', '-').toUpperCase();

    if (normalized == 'AUTO' || normalized == 'SYSTEM') return null;
    if (normalized == 'ZH-CN' || normalized == 'ZH-HANS') {
      return languages[24];
    }
    if (normalized == 'ZH-TW' ||
        normalized == 'ZH-HANT' ||
        normalized == 'ZH-HK') {
      return languages[25];
    }

    for (final language in languages) {
      final candidates = <String>{
        language.translationCode.toUpperCase(),
        language.appLocaleCode.replaceAll('_', '-').toUpperCase(),
        language.ttsLocale.toUpperCase(),
      };
      if (candidates.contains(normalized)) return language;
    }

    final base = normalized.split('-').first;
    for (final language in languages) {
      if (language.shortCode == base) return language;
    }
    return null;
  }

  static AppLanguage fromCode(
    String? code, {
    AppLanguage? fallback,
  }) =>
      maybeFromCode(code) ?? fallback ?? english;

  static String normalizeTranslationCode(
    String? code, {
    String fallback = 'EN',
  }) =>
      maybeFromCode(code)?.translationCode ?? fallback;
}