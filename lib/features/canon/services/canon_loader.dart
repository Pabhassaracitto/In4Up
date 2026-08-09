// lib/features/canon/services/canon_loader.dart
//
// Loader đọc .md từ assets, parse frontmatter, cache vào Hive để lần sau
// mở app không phải parse lại (đỡ tốn CPU).

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive_flutter/hive_flutter.dart';

import '../models/canon_entry.dart';
import 'canon_frontmatter_parser.dart';

class CanonLoader {
  static const String _cacheBoxName = 'canon_cache';
  static const String _cacheMetaKey = 'canon_cache_meta'; // { assetPath: hash }

  // Danh sách asset .md — thêm file mới vào đây và pubspec.yaml
  static const List<String> assetPaths = [
    'assets/canon/dhammapada_001-002.md',
    'assets/canon/kinh_tu_niem_xu_mn10.md',
    'assets/canon/kinh_chuyen_phap_luan_sn56.11.md',
  ];

  Box<String> get _box => Hive.box<String>(_cacheBoxName);

  Future<void> init() async {
    if (!Hive.isBoxOpen(_cacheBoxName)) {
      await Hive.openBox<String>(_cacheBoxName);
    }
  }

  Future<void> ensureOpen() async => init();

  /// Load tất cả, ưu tiên cache, chỉ parse lại nếu file đổi (theo length hash đơn giản)
  Future<List<CanonEntry>> loadAll({bool forceRefresh = false}) async {
    await ensureOpen();
    final out = <CanonEntry>[];
    for (final path in assetPaths) {
      final entry = await _loadOne(path, forceRefresh: forceRefresh);
      if (entry != null) out.add(entry);
    }
    // sort theo id để ổn định
    out.sort((a, b) => a.id.compareTo(b.id));
    return out;
  }

  Future<CanonEntry?> _loadOne(String assetPath, {bool forceRefresh = false}) async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final cacheKey = 'canon:$assetPath';
      // naive hash: length + first 200 chars hash
      final hash = '${raw.length}:${raw.substring(0, raw.length.clamp(0, 200)).hashCode}';
      final metaRaw = _box.get(_cacheMetaKey);
      Map<String, dynamic> meta = {};
      if (metaRaw != null) {
        try {
          meta = (jsonDecode(metaRaw) as Map).cast<String, dynamic>();
        } catch (_) {}
      }

      if (!forceRefresh && meta[assetPath] == hash) {
        final cachedJson = _box.get(cacheKey);
        if (cachedJson != null) {
          try {
            final map = jsonDecode(cachedJson) as Map<String, dynamic>;
            final entry = CanonEntry.fromJson(map);
            // merge personalNote đã lưu riêng nếu có
            final note = _box.get('note:${entry.id}');
            if (note != null && note.isNotEmpty) {
              return entry.copyWith(personalNote: note);
            }
            return entry;
          } catch (_) {}
        }
      }

      // parse fresh
      final entry = CanonFrontMatterParser.parse(raw: raw, sourcePath: assetPath);
      await _box.put(cacheKey, jsonEncode(entry.toJson()));
      meta[assetPath] = hash;
      await _box.put(_cacheMetaKey, jsonEncode(meta));
      // merge note nếu có
      final note = _box.get('note:${entry.id}');
      if (note != null && note.isNotEmpty) {
        return entry.copyWith(personalNote: note);
      }
      return entry;
    } catch (e) {
      debugPrint('CanonLoader load $assetPath error: $e');
      return null;
    }
  }

  Future<CanonEntry?> getById(String id) async {
    await ensureOpen();
    // tìm trong cache trước
    for (final k in _box.keys) {
      if (!k.toString().startsWith('canon:')) continue;
      final json = _box.get(k);
      if (json == null) continue;
      try {
        final map = jsonDecode(json) as Map<String, dynamic>;
        if (map['id'] == id) {
          final entry = CanonEntry.fromJson(map);
          final note = _box.get('note:$id');
          if (note != null && note.isNotEmpty) return entry.copyWith(personalNote: note);
          return entry;
        }
      } catch (_) {}
    }
    // fallback: loadAll và tìm
    final all = await loadAll();
    try {
      return all.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> savePersonalNote(String canonId, String note) async {
    await ensureOpen();
    await _box.put('note:$canonId', note);
  }

  String? getPersonalNote(String canonId) {
    if (!Hive.isBoxOpen(_cacheBoxName)) return null;
    return _box.get('note:$canonId');
  }

  Future<void> clearCache() async {
    await ensureOpen();
    await _box.clear();
  }
}
