import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/grammar_highlight_settings.dart';

class GrammarSettingsService {
  GrammarSettingsService._();

  static const String settingsKey = 'grammar_highlight_settings_v1';

  static Future<GrammarHighlightSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(settingsKey);
    if (raw == null || raw.trim().isEmpty) {
      return GrammarHighlightSettings.defaults();
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return GrammarHighlightSettings.fromJson(decoded);
      }
      if (decoded is Map) {
        return GrammarHighlightSettings.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      }
    } catch (_) {}

    return GrammarHighlightSettings.defaults();
  }

  static Future<void> save(GrammarHighlightSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(settingsKey, jsonEncode(settings.toJson()));
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(settingsKey);
  }
}
