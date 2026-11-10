import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Small local persistence layer for the web-only entrypoint.
///
/// `shared_preferences` maps to browser local storage on Web. The payloads are
/// intentionally bounded and JSON-based so the Web Core does not pull Hive or
/// native filesystem code into its browser entrypoint.
class WebLocalStore {
  WebLocalStore(this._prefs);

  static const String draftKey = 'web_core_draft_v1';
  static const String savedWordsKey = 'web_core_saved_words_v1';
  static const String recentTextsKey = 'web_core_recent_texts_v1';

  final SharedPreferences _prefs;

  String get draft => _prefs.getString(draftKey) ?? '';

  List<String> get savedWords {
    final raw = _prefs.getString(savedWordsKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<String>()
          .map((word) => word.trim())
          .where((word) => word.isNotEmpty)
          .take(500)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveDraft(String text) async {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      await _prefs.remove(draftKey);
      return;
    }
    await _prefs.setString(draftKey, text);
  }

  Future<void> saveWords(Iterable<String> words) async {
    final normalized = words
        .map((word) => word.trim())
        .where((word) => word.isNotEmpty)
        .fold<List<String>>(<String>[], (result, word) {
          if (!result.contains(word)) result.add(word);
          return result;
        });
    await _prefs.setString(savedWordsKey, jsonEncode(normalized.take(500).toList()));
  }

  Future<void> addRecentText(String text) async {
    final normalized = text.trim();
    if (normalized.isEmpty) return;

    final previous = _decodeRecentTexts();
    final next = <String>[normalized, ...previous.where((item) => item != normalized)]
        .take(10)
        .toList(growable: false);
    await _prefs.setString(recentTextsKey, jsonEncode(next));
  }

  List<String> get recentTexts => _decodeRecentTexts();

  List<String> _decodeRecentTexts() {
    final raw = _prefs.getString(recentTextsKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded.whereType<String>().take(10).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}
