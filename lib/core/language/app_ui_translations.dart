import 'generated_legacy_ui_fallbacks.dart';
import 'generated_priority_native_pack.dart';
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

  /// Template catalogs in precedence order.
  ///
  /// Kept as *separate* lists (not one merged list) so a template that exists in
  /// both the native pack and the English-only legacy catalog never resolves
  /// through the English one just because `sort` is unstable for equal lengths.
  /// Within a catalog, longer static text wins so a specific pattern
  /// (`{value0} từ · {value1} dòng`) beats a generic one (`{value0} từ`).
  static final List<List<_TranslationTemplate>> _templateCatalogs = [
    _sortedTemplates(
      generatedPriorityNativePack.entries
          .where((entry) => entry.key.contains('{'))
          .map(_TranslationTemplate.fromEntry),
    ),
    _sortedTemplates(
      priorityUiOverrides.entries
          .where((entry) => entry.key.contains('{'))
          .map(_TranslationTemplate.fromEntry),
    ),
    _sortedTemplates(
      generatedUiTranslations.entries
          .where((entry) => entry.key.contains('{'))
          .map(_TranslationTemplate.fromEntry),
    ),
    _sortedTemplates(
      generatedLegacyUiEnglishFallbacks.entries
          .where((entry) => entry.key.contains('{'))
          .map(_TranslationTemplate.fromEnglishEntry),
    ),
  ];

  static List<_TranslationTemplate> _sortedTemplates(
    Iterable<_TranslationTemplate> templates,
  ) =>
      templates.toList()
        ..sort((left, right) => right.staticLength.compareTo(left.staticLength));

  /// Locales that have native values in [generatedPriorityNativePack].
  static const Set<String> _nativePackLocales = {
    'zh',
    'zh_TW',
    'hi',
    'si',
    'my',
    'th',
    'ja',
  };

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

    // Native priority-locale pack wins for the priority locales: it carries
    // reviewed zh/zh_TW/hi/si/my/th/ja values for legacy chrome that the ARB
    // catalog never captured. Other locales keep looking in the richer catalogs
    // first so an existing de/fr translation is not downgraded to English.
    final native = generatedPriorityNativePack[sourceText];
    if (native != null && _nativePackLocales.contains(locale)) {
      return _valueForLocale(native, locale, sourceText);
    }

    final override = priorityUiOverrides[sourceText];
    if (override != null) {
      return _valueForLocale(override, locale, sourceText);
    }

    final exact = generatedUiTranslations[sourceText];
    if (exact != null) return _valueForLocale(exact, locale, sourceText);

    final legacyEnglish = generatedLegacyUiEnglishFallbacks[sourceText];
    if (legacyEnglish != null) return legacyEnglish;

    if (native != null) return _valueForLocale(native, locale, sourceText);

    if (allowTemplates) {
      for (final catalog in _templateCatalogs) {
        for (final template in catalog) {
          final translated = template.translate(sourceText, locale);
          if (translated != null) return translated;
        }
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
    if (generatedPriorityNativePack.containsKey(sourceText) ||
        priorityUiOverrides.containsKey(sourceText) ||
        generatedUiTranslations.containsKey(sourceText) ||
        generatedLegacyUiEnglishFallbacks.containsKey(sourceText)) {
      return true;
    }
    return _templateCatalogs.any(
      (catalog) => catalog.any((template) => template.matches(sourceText)),
    );
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
