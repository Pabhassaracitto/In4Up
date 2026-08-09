// lib/data/datasources/vocab_local_datasource.dart
//
// DataSource local cho vocab — Hive.
// Tách riêng để VocabRepository không phải biết chi tiết Hive box.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../models/word_entry.dart';

class VocabLocalDataSource {
  static const String boxName = 'vocabulary_v2';
  static const String metaBoxName = 'vocabulary_meta';
  static const String pendingBoxName = 'vocab_sync_pending';
  static const String customLanguagesKey = 'custom_languages';
  static const String customTopicsKey = 'custom_topics';

  Box<String> get _box => Hive.box<String>(boxName);
  Box<String> get _metaBox => Hive.box<String>(metaBoxName);

  Future<void> init() async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<String>(boxName);
    }
    if (!Hive.isBoxOpen(metaBoxName)) {
      await Hive.openBox<String>(metaBoxName);
    }
    if (!Hive.isBoxOpen(pendingBoxName)) {
      await Hive.openBox<String>(pendingBoxName);
    }
  }

  Future<void> ensureOpen() async {
    await init();
  }

  // ── CRUD ───────────────────────────────────────────────

  List<WordEntry> getAll() {
    final out = <WordEntry>[];
    for (final json in _box.values) {
      try {
        final map = jsonDecode(json) as Map<String, dynamic>;
        out.add(WordEntry.fromJson(map));
      } catch (e) {
        debugPrint('VocabLocalDataSource: corrupt entry skipped: $e');
      }
    }
    return out;
  }

  WordEntry? getById(String id) {
    final json = _box.get(id);
    if (json == null) return null;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return WordEntry.fromJson(map);
    } catch (e) {
      debugPrint('VocabLocalDataSource.getById error: $e');
      return null;
    }
  }

  WordEntry? findByWord(String word) {
    final normalized = word.toLowerCase().trim();
    for (final json in _box.values) {
      try {
        final map = jsonDecode(json) as Map<String, dynamic>;
        if ((map['word'] as String?)?.toLowerCase().trim() == normalized) {
          return WordEntry.fromJson(map);
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> put(WordEntry entry) async {
    await _box.put(entry.id, jsonEncode(entry.toJson()));
  }

  Future<void> putAll(List<WordEntry> entries) async {
    final map = <String, String>{
      for (final e in entries) e.id: jsonEncode(e.toJson()),
    };
    await _box.putAll(map);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Future<void> clearAll() async {
    await _box.clear();
  }

  Stream<BoxEvent> watch() => _box.watch();

  // ── Meta ───────────────────────────────────────────────

  Set<String> readMetaSet(String key) {
    try {
      final raw = _metaBox.get(key);
      if (raw == null || raw.isEmpty) return <String>{};
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => e.toString()).where((e) => e.isNotEmpty).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> saveMetaSet(String key, Set<String> values) async {
    await _metaBox.put(key, jsonEncode(values.toList()..sort()));
  }

  Set<String> get customLanguages => readMetaSet(customLanguagesKey);
  Set<String> get customTopics => readMetaSet(customTopicsKey);

  // ── Search (in-memory, sẽ được thay bằng FTS khi lượng data lớn) ──

  List<WordEntry> search(String query, {String? language, String? topic}) {
    if (query.trim().isEmpty && language == null && topic == null) {
      return getAll();
    }
    final q = query.toLowerCase().trim();
    return getAll().where((w) {
      if (language != null && w.language != language) return false;
      if (topic != null && w.topic != topic) return false;
      if (q.isEmpty) return true;
      return w.word.toLowerCase().contains(q) ||
          w.meaning.toLowerCase().contains(q) ||
          w.contexts.any((c) => c.surroundingText.toLowerCase().contains(q)) ||
          (w.phonetic ?? '').toLowerCase().contains(q);
    }).toList();
  }

  int get count => _box.length;
}
