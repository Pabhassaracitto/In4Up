import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

/// Cross-session performance metadata for the installed Tipiṭaka database.
///
/// Opening the reader used to re-derive cheap-but-not-free facts on every
/// screen: which translation columns actually contain text, and whether the
/// database carries structural heading rows at all. On a full canon
/// (~500 MB, millions of rows) a single "does `translation_my` contain text?"
/// probe is a full table scan, and the catalogue title subqueries repeat that
/// scan once per book.
///
/// Everything stored here is keyed by [TipitakaDb.fileFingerprint] — path +
/// byte size + modification time. Every import/replacement rewrites the file
/// atomically, so a changed fingerprint automatically invalidates the entry and
/// the values can never be served for different content. The values are also
/// strictly *accelerators*: a miss simply falls back to the SQLite query, and a
/// failure is swallowed so a damaged preferences file can never block reading.
class TipitakaPerfCache {
  TipitakaPerfCache._();

  /// Bumped whenever the stored shape changes; older keys are ignored.
  static const String _version = 'v1';

  static const int _maxMemoryEntries = 4;

  static final Map<String, Set<String>> _languagesMemory = {};
  static final Map<String, bool> _structuralMemory = {};

  static String _languagesKey(String fingerprint) =>
      'tipitaka.perf.$_version.languages:$fingerprint';

  static String _structuralKey(String fingerprint) =>
      'tipitaka.perf.$_version.structural:$fingerprint';

  /// Languages the current database can actually render.
  static Future<Set<String>?> loadLanguages(String fingerprint) async {
    final memo = _languagesMemory[fingerprint];
    if (memo != null) return memo;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_languagesKey(fingerprint));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      final languages = decoded.whereType<String>().toSet();
      _remember(_languagesMemory, fingerprint, languages);
      return languages;
    } catch (error) {
      debugPrint('⚠️ Tipitaka perf cache: languages không đọc được: $error');
      return null;
    }
  }

  static Future<void> saveLanguages(
    String fingerprint,
    Set<String> languages,
  ) async {
    _remember(_languagesMemory, fingerprint, languages);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _languagesKey(fingerprint),
        jsonEncode(languages.toList()..sort()),
      );
    } catch (error) {
      debugPrint('⚠️ Tipitaka perf cache: languages không ghi được: $error');
    }
  }

  /// Whether the database has any structural heading row (`book`/`chapter`/
  /// `heading`, or a raw CSCD `rend="…"` marker). When this is `false` the
  /// catalogue title subqueries are guaranteed to return `NULL`, so the app can
  /// skip them entirely instead of scanning every book.
  static Future<bool?> loadStructuralTitles(String fingerprint) async {
    final memo = _structuralMemory[fingerprint];
    if (memo != null) return memo;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_structuralKey(fingerprint));
      if (raw == null || raw.isEmpty) return null;
      final value = raw == '1';
      _remember(_structuralMemory, fingerprint, value);
      return value;
    } catch (error) {
      debugPrint('⚠️ Tipitaka perf cache: structural không đọc được: $error');
      return null;
    }
  }

  static Future<void> saveStructuralTitles(
    String fingerprint,
    bool hasStructuralTitles,
  ) async {
    _remember(_structuralMemory, fingerprint, hasStructuralTitles);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _structuralKey(fingerprint),
        hasStructuralTitles ? '1' : '0',
      );
    } catch (error) {
      debugPrint('⚠️ Tipitaka perf cache: structural không ghi được: $error');
    }
  }

  /// Drops every entry for [fingerprint] (used after an in-place import that
  /// could not change the file mtime, e.g. a rollback).
  static Future<void> forget(String fingerprint) async {
    _languagesMemory.remove(fingerprint);
    _structuralMemory.remove(fingerprint);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_languagesKey(fingerprint));
      await prefs.remove(_structuralKey(fingerprint));
    } catch (_) {
      // Cache eviction is best effort.
    }
  }

  /// Test/QA hook: forget everything held for this process.
  static void clearMemory() {
    _languagesMemory.clear();
    _structuralMemory.clear();
  }

  static void _remember<T>(Map<String, T> store, String key, T value) {
    store.remove(key);
    store[key] = value;
    while (store.length > _maxMemoryEntries) {
      store.remove(store.keys.first);
    }
  }
}
