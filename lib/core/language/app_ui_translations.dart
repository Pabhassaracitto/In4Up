import 'generated_legacy_ui_fallbacks.dart';
import 'generated_ui_translations.dart';
import 'priority_ui_overrides.dart';

/// Translation bridge for presentation strings that have not yet been migrated
/// to generated [AppLocalizations] getters.
///
/// Only exact, reviewed ARB source messages (and their placeholder forms) are
/// translated. Unknown text is returned unchanged, which is important for
/// documents, vocabulary and other user-provided content.
class AppUITranslations {
  AppUITranslations._();

  static final List<_TranslationTemplate> _templates = ([
    ...priorityUiOverrides.entries
        .where((entry) => entry.key.contains('{'))
        .map(_TranslationTemplate.fromEntry),
    ...generatedUiTranslations.entries
        .where((entry) => entry.key.contains('{'))
        .map(_TranslationTemplate.fromEntry),
    ...generatedLegacyUiEnglishFallbacks.entries
        .where((entry) => entry.key.contains('{'))
        .map(_TranslationTemplate.fromEnglishEntry),
  ]..sort(
      (left, right) => right.staticLength.compareTo(left.staticLength),
    ));

  /// Translates a known Vietnamese UI source message for [localeCode].
  ///
  /// English is the canonical fallback for every non-Vietnamese locale. Locale
  /// subtags are preserved, so Traditional Chinese (`zh-TW`, `zh_Hant`) does
  /// not accidentally resolve through Simplified Chinese.
  static String translate(
    String sourceText,
    String localeCode, {
    bool allowTemplates = true,
  }) {
    final locale = canonicalLocaleCode(localeCode);
    if (locale == 'vi') return sourceText;

    final override = priorityUiOverrides[sourceText];
    if (override != null) {
      return _valueForLocale(override, locale, sourceText);
    }

    final exact = generatedUiTranslations[sourceText];
    if (exact != null) return _valueForLocale(exact, locale, sourceText);

    final legacyEnglish = generatedLegacyUiEnglishFallbacks[sourceText];
    if (legacyEnglish != null) return legacyEnglish;

    if (allowTemplates) {
      for (final template in _templates) {
        final translated = template.translate(sourceText, locale);
        if (translated != null) return translated;
      }
    }

    // Never guess at runtime content. Hard-coded presentation messages belong
    // in an ARB and will then be picked up by this bridge automatically.
    return sourceText;
  }

  /// Translates only exact reviewed messages.
  ///
  /// This is used by the global legacy [Text] shim so arbitrary document or
  /// vocabulary content cannot accidentally match a placeholder template such
  /// as `{value0} phút` or `Lỗi: {value0}`. Interpolated UI strings must opt in
  /// explicitly through `BuildContext.uiText` at their rendering boundary.
  static String translateExact(String sourceText, String localeCode) {
    return translate(sourceText, localeCode, allowTemplates: false);
  }

  static bool containsSource(String sourceText) {
    if (priorityUiOverrides.containsKey(sourceText) ||
        generatedUiTranslations.containsKey(sourceText) ||
        generatedLegacyUiEnglishFallbacks.containsKey(sourceText)) {
      return true;
    }
    return _templates.any((template) => template.matches(sourceText));
  }

  static String canonicalLocaleCode(String localeCode) {
    final normalized = localeCode.trim().replaceAll('-', '_');
    if (normalized.isEmpty) return 'en';

    final parts = normalized.split('_');
    final language = parts.first.toLowerCase();
    if (language == 'zh') {
      final subtags = parts.skip(1).map((part) => part.toLowerCase()).toSet();
      if (subtags.contains('tw') ||
          subtags.contains('hant') ||
          subtags.contains('hk') ||
          subtags.contains('mo')) {
        return 'zh_TW';
      }
      return 'zh';
    }
    return language;
  }

  static String _valueForLocale(
    Map<String, String> translations,
    String locale, [
    String? sourceText,
  ]) {
    return translations[locale] ??
        translations['en'] ??
        sourceText ??
        translations.values.first;
  }
}

class _TranslationTemplate {
  final RegExp pattern;
  final List<String> placeholderNames;
  final Map<String, String> translations;
  final int staticLength;

  const _TranslationTemplate({
    required this.pattern,
    required this.placeholderNames,
    required this.translations,
    required this.staticLength,
  });

  factory _TranslationTemplate.fromEntry(
    MapEntry<String, Map<String, String>> entry,
  ) {
    return _TranslationTemplate._fromSource(entry.key, entry.value);
  }

  factory _TranslationTemplate.fromEnglishEntry(
    MapEntry<String, String> entry,
  ) {
    return _TranslationTemplate._fromSource(
      entry.key,
      {'en': entry.value},
    );
  }

  factory _TranslationTemplate._fromSource(
    String source,
    Map<String, String> translations,
  ) {
    final placeholderPattern = RegExp(r'\{([A-Za-z_][A-Za-z0-9_]*)\}');
    final names = <String>[];
    final pattern = StringBuffer('^');
    var cursor = 0;

    for (final match in placeholderPattern.allMatches(source)) {
      pattern.write(RegExp.escape(source.substring(cursor, match.start)));
      pattern.write('(.*?)');
      names.add(match.group(1)!);
      cursor = match.end;
    }
    pattern.write(RegExp.escape(source.substring(cursor)));
    pattern.write(r'$');

    return _TranslationTemplate(
      pattern: RegExp(pattern.toString(), dotAll: true),
      placeholderNames: names,
      translations: translations,
      staticLength: source.replaceAll(placeholderPattern, '').length,
    );
  }

  bool matches(String sourceText) => pattern.hasMatch(sourceText);

  String? translate(String sourceText, String locale) {
    final match = pattern.firstMatch(sourceText);
    if (match == null) return null;

    final values = <String, String>{};
    for (var index = 0; index < placeholderNames.length; index++) {
      values[placeholderNames[index]] = match.group(index + 1)!;
    }

    final target = AppUITranslations._valueForLocale(translations, locale);
    return target.replaceAllMapped(
      RegExp(r'\{([A-Za-z_][A-Za-z0-9_]*)\}'),
      (placeholder) => values[placeholder.group(1)] ?? placeholder.group(0)!,
    );
  }
}
