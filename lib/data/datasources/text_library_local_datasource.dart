// lib/data/datasources/text_library_local_datasource.dart
//
// Cache local cho TextLibrary — Hive (offline-first).
// Trước đây TextLibraryService chỉ đọc Firestore nên mất mạng là trắng.
// Giờ lưu cache để mở app là có dữ liệu tức thì (0ms).

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../services/text_library_service.dart';

class TextLibraryLocalDataSource {
  static const String boxName = 'text_library_cache';
  static const String pendingBoxName = 'text_library_pending';

  Box<String> get _box => Hive.box<String>(boxName);

  Future<void> init() async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<String>(boxName);
    }
    if (!Hive.isBoxOpen(pendingBoxName)) {
      await Hive.openBox<String>(pendingBoxName);
    }
  }

  Future<void> ensureOpen() async => init();

  List<TextLibraryEntry> getAll() {
    final out = <TextLibraryEntry>[];
    for (final json in _box.values) {
      try {
        final map = jsonDecode(json) as Map<String, dynamic>;
        // map chứa id + fields, tạo TextLibraryEntry thủ công
        out.add(_fromCacheMap(map));
      } catch (e) {
        debugPrint('TextLibraryLocalDataSource corrupt: $e');
      }
    }
    // sort updatedAt desc
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }

  TextLibraryEntry? getById(String id) {
    final json = _box.get(id);
    if (json == null) return null;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return _fromCacheMap(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> put(TextLibraryEntry entry) async {
    await _box.put(entry.id, jsonEncode(_toCacheMap(entry)));
  }

  Future<void> putAll(List<TextLibraryEntry> entries) async {
    final m = <String, String>{
      for (final e in entries) e.id: jsonEncode(_toCacheMap(e)),
    };
    await _box.putAll(m);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Future<void> clear() async {
    await _box.clear();
  }

  Stream<BoxEvent> watch() => _box.watch();

  // ── Helpers ────────────────────────────────────────────

  Map<String, dynamic> _toCacheMap(TextLibraryEntry e) => {
        'id': e.id,
        'title': e.title,
        'content': e.content,
        'category': e.category,
        'wordCount': e.wordCount,
        'createdAt': e.createdAt.toIso8601String(),
        'updatedAt': e.updatedAt.toIso8601String(),
      };

  TextLibraryEntry _fromCacheMap(Map<String, dynamic> m) => TextLibraryEntry(
        id: m['id'] as String,
        title: m['title'] as String? ?? 'Không có tiêu đề',
        content: m['content'] as String? ?? '',
        category: m['category'] as String?,
        wordCount: m['wordCount'] as int? ?? 0,
        createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(m['updatedAt'] as String? ?? '') ?? DateTime.now(),
      );

  // ── Pending queue (cho offline create/update/delete) ──

  Box<String> get _pendingBox => Hive.box<String>(pendingBoxName);

  void markPending(String id, String op) {
    // op: upsert:<id> hoặc delete:<id>
    _pendingBox.put(id, op);
  }

  void clearPending(String id) => _pendingBox.delete(id);
  Map<dynamic, String> get pendingOps => Map.from(_pendingBox.toMap());
  bool get hasPending => _pendingBox.isNotEmpty;
}
