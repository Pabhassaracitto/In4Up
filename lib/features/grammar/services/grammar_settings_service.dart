import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/grammar_highlight_settings.dart';

class GrammarSettingsService {
  GrammarSettingsService._();

  static const String settingsKey = 'grammar_highlight_settings_v1';
  static const String _compactLegendMigrationKey =
      'grammar_legend_compact_default_migrated_v1';

  static Future<GrammarHighlightSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(settingsKey);
    var settings = GrammarHighlightSettings.defaults();

    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          settings = GrammarHighlightSettings.fromJson(decoded);
        } else if (decoded is Map) {
          settings = GrammarHighlightSettings.fromJson(
            Map<String, dynamic>.from(decoded),
          );
        }
      } catch (_) {
        // Fall back to the current defaults for corrupt or obsolete settings.
      }
    }

    // Existing v1 settings were written when the Content Words legend opened
    // expanded by default. Compact it once for this UI update, then preserve a
    // user's later expand/collapse choice on every subsequent load.
    if (prefs.getBool(_compactLegendMigrationKey) != true) {
      settings = settings.copyWith(legendCollapsed: true);
      await prefs.setString(settingsKey, jsonEncode(settings.toJson()));
      await prefs.setBool(_compactLegendMigrationKey, true);
    }

    return settings;
  }

  static Future<void> save(GrammarHighlightSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(settingsKey, jsonEncode(settings.toJson()));
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(settingsKey);
    await prefs.remove(_compactLegendMigrationKey);
  }
}
