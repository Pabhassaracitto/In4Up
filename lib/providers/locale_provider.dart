import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  static const String _localeKey = 'app_locale';

  Locale? _locale;

  LocaleProvider(this._prefs) {
    _loadLocale();
  }

  Locale? get locale => _locale;

  void _loadLocale() {
    final localeCode = _prefs.getString(_localeKey);
    if (localeCode != null && localeCode.isNotEmpty) {
      final parts = localeCode.split('_');
      if (parts.length == 2) {
        _locale = Locale(parts[0], parts[1]);
      } else {
        _locale = Locale(parts[0]);
      }
    }
  }

  Future<void> setLocale(Locale? newLocale) async {
    _locale = newLocale;
    if (newLocale == null) {
      await _prefs.remove(_localeKey);
    } else {
      final localeCode = newLocale.countryCode != null 
          ? '${newLocale.languageCode}_${newLocale.countryCode}' 
          : newLocale.languageCode;
      await _prefs.setString(_localeKey, localeCode);
    }
    notifyListeners();
  }
}
