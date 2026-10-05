import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How canonical Pāli and the primary translation are combined on screen.
enum TipitakaDisplayMode {
  /// Pāli paragraph followed by its translation (OpenTipitaka's one-page
  /// bilingual flow).
  bilingual,

  /// Canonical Pāli only, for readers studying the source.
  paliOnly,

  /// Translation only, for a clean reading surface.
  translationOnly,
}

/// Reader-local color surface. It overrides the app theme only inside the
/// reader subtree, like the sepia/night modes of professional e-readers.
enum TipitakaReadingTheme { system, light, sepia, dark }

/// Persistent display settings for the Tipiṭaka reader.
///
/// The singleton survives screen rebuilds and restores itself from
/// `SharedPreferences`, so a reader who prefers sepia, Pāli-only, English at
/// 130% keeps that setup across restarts and across workspace tabs.
class TipitakaReaderAppearance extends ChangeNotifier {
  TipitakaReaderAppearance._();

  static final TipitakaReaderAppearance instance = TipitakaReaderAppearance._();

  static const _kDisplayMode = 'tipitaka.reader.display_mode';
  static const _kPrimaryLanguage = 'tipitaka.reader.primary_language';
  static const _kEnglishSecondary = 'tipitaka.reader.english_secondary';
  static const _kFontScale = 'tipitaka.reader.font_scale';
  static const _kReadingTheme = 'tipitaka.reader.reading_theme';

  static const minFontScale = 0.8;
  static const maxFontScale = 1.6;

  bool _loaded = false;
  TipitakaDisplayMode _displayMode = TipitakaDisplayMode.bilingual;
  String _primaryLanguage = 'vi';
  bool _englishSecondary = false;
  double _fontScale = 1;
  TipitakaReadingTheme _readingTheme = TipitakaReadingTheme.system;

  TipitakaDisplayMode get displayMode => _displayMode;
  String get primaryLanguage => _primaryLanguage;
  bool get englishSecondary => _englishSecondary;
  double get fontScale => _fontScale;
  TipitakaReadingTheme get readingTheme => _readingTheme;

  /// Loads persisted values once. Safe to call from every reader `initState`.
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeIndex = (prefs.getInt(_kDisplayMode) ?? 0)
          .clamp(0, TipitakaDisplayMode.values.length - 1)
          .toInt();
      _displayMode = TipitakaDisplayMode.values[modeIndex];
      final language = prefs.getString(_kPrimaryLanguage)?.trim();
      if (language != null && language.isNotEmpty) {
        _primaryLanguage = language;
      }
      _englishSecondary = prefs.getBool(_kEnglishSecondary) ?? false;
      _fontScale = (prefs.getDouble(_kFontScale) ?? 1)
          .clamp(minFontScale, maxFontScale)
          .toDouble();
      final themeIndex = (prefs.getInt(_kReadingTheme) ?? 0)
          .clamp(0, TipitakaReadingTheme.values.length - 1)
          .toInt();
      _readingTheme = TipitakaReadingTheme.values[themeIndex];
    } catch (_) {
      // Preferences are best-effort: keep in-memory defaults on failure.
    }
    _loaded = true;
    notifyListeners();
  }

  set displayMode(TipitakaDisplayMode value) {
    if (value == _displayMode) return;
    _displayMode = value;
    _persist();
    notifyListeners();
  }

  set primaryLanguage(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty || normalized == _primaryLanguage) return;
    _primaryLanguage = normalized;
    _persist();
    notifyListeners();
  }

  set englishSecondary(bool value) {
    if (value == _englishSecondary) return;
    _englishSecondary = value;
    _persist();
    notifyListeners();
  }

  set fontScale(double value) {
    final clamped =
        value.clamp(minFontScale, maxFontScale).toDouble();
    if (clamped == _fontScale) return;
    _fontScale = clamped;
    _persist();
    notifyListeners();
  }

  set readingTheme(TipitakaReadingTheme value) {
    if (value == _readingTheme) return;
    _readingTheme = value;
    _persist();
    notifyListeners();
  }

  /// Restores factory defaults (bilingual, Vietnamese, 100%, system theme).
  void reset() {
    _displayMode = TipitakaDisplayMode.bilingual;
    _primaryLanguage = 'vi';
    _englishSecondary = false;
    _fontScale = 1;
    _readingTheme = TipitakaReadingTheme.system;
    _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    if (!_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kDisplayMode, _displayMode.index);
      await prefs.setString(_kPrimaryLanguage, _primaryLanguage);
      await prefs.setBool(_kEnglishSecondary, _englishSecondary);
      await prefs.setDouble(_kFontScale, _fontScale);
      await prefs.setInt(_kReadingTheme, _readingTheme.index);
    } catch (_) {
      // Persistence failures must never break reading.
    }
  }
}
