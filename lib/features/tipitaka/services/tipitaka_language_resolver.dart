/// Resolves which imported language should be used for Tipiṭaka catalogue
/// titles and reading surfaces (PSRC-159).
///
/// The app UI locale is *not* necessarily the language of an imported
/// translation: a reader using an English interface may have only Pāli and
/// Vietnamese packs installed. Falling back to `pi` in that case makes the
/// whole catalogue look Pāli-only. This resolver picks an actually imported
/// translation, with a deterministic order so all screens agree.
class TipitakaLanguageResolver {
  const TipitakaLanguageResolver._();

  /// Default priority when neither the UI locale nor a saved reader language
  /// matches an imported pack. Vietnamese is the app's source locale, English
  /// is the canonical fallback for every other locale (AGENTS.md rule #5).
  static const List<String> defaultPriority = ['vi', 'en', 'my', 'th'];

  static String normalize(String code) {
    final normalized = code.trim().toLowerCase().replaceAll('_', '-');
    return switch (normalized) {
      'zh-cn' || 'zh-hans' => 'zh',
      'zh-hant' || 'zh-hk' || 'zh-tw-hant' => 'zh-tw',
      'pi-roman' || 'pali' => 'pi',
      _ => normalized,
    };
  }

  static bool _isPali(String code) => code == 'pi' || code.startsWith('pi-');

  static bool _matches(String candidate, String wanted) {
    if (candidate == wanted) return true;
    if (!wanted.contains('-') && candidate.startsWith('$wanted-')) return true;
    if (!candidate.contains('-') && wanted.startsWith('$candidate-')) {
      return true;
    }
    return false;
  }

  static String? _find(String? wanted, Set<String> translations) {
    if (wanted == null) return null;
    final normalized = normalize(wanted);
    if (normalized.isEmpty || _isPali(normalized)) return null;
    for (final code in translations) {
      if (_matches(code, normalized)) return code;
    }
    return null;
  }

  /// Imported translation languages, normalized and without the Pāli source.
  static Set<String> translationLanguages(Set<String> availableLanguages) => {
        for (final code in availableLanguages)
          if (!_isPali(normalize(code))) normalize(code),
      };

  /// Returns a language code that actually exists in [availableLanguages].
  ///
  /// Order: saved/requested language → app UI locale → default priority →
  /// first remaining imported language → `pi` (Pāli-only DB) → `en`.
  static String resolve({
    required Set<String> availableLanguages,
    String? preferredLanguage,
    String? uiLanguage,
    List<String> priority = defaultPriority,
  }) {
    final translations = translationLanguages(availableLanguages);
    if (translations.isEmpty) {
      return availableLanguages.any((code) => _isPali(normalize(code)))
          ? 'pi'
          : 'en';
    }
    for (final candidate in <String?>[
      preferredLanguage,
      uiLanguage,
      ...priority,
    ]) {
      final match = _find(candidate, translations);
      if (match != null) return match;
    }
    final sorted = translations.toList()..sort();
    return sorted.first;
  }
}

/// Convenience top-level function used by screens.
String resolveTipitakaDisplayLanguage({
  required Set<String> availableLanguages,
  String? preferredLanguage,
  String? uiLanguage,
}) =>
    TipitakaLanguageResolver.resolve(
      availableLanguages: availableLanguages,
      preferredLanguage: preferredLanguage,
      uiLanguage: uiLanguage,
    );
