// lib/features/translation/cache/translation_cache.dart

import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cache thông minh: Memory LRU + Disk (SharedPreferences)
class TranslationCache {
  static final TranslationCache _instance = TranslationCache._();
  factory TranslationCache() => _instance;
  TranslationCache._();

  // Memory cache - LRU, tối đa 500 entries
  static const int _maxMemoryEntries = 500;
  final LinkedHashMap<String, String> _memoryCache =
      LinkedHashMap<String, String>();

  // Disk cache prefix
  static const String _diskPrefix = 'trans_cache_';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Stable across Dart VM sessions. `String.hashCode` is NOT — after
  /// restart the same sentence looked like a new case and was re-translated.
  ///
  /// [engine] tách Hy-MT / ML Kit / online — không dính bản dịch cũ khi
  /// đổi engine hoặc tắt offline-only.
  String _makeKey(
    String text,
    String sourceLang,
    String targetLang, {
    String engine = '',
  }) {
    final digest = md5
        .convert(utf8.encode(text.trim().toLowerCase()))
        .toString()
        .substring(0, 12);
    final eng = engine.trim().isEmpty ? 'any' : engine.trim();
    return '${sourceLang}_${targetLang}_${eng}_$digest';
  }

  String _legacyKey(String text, String sourceLang, String targetLang) {
    final digest = md5
        .convert(utf8.encode(text.trim().toLowerCase()))
        .toString()
        .substring(0, 12);
    return '${sourceLang}_${targetLang}_$digest';
  }

  /// Lưu bản dịch
  Future<void> put({
    required String text,
    required String sourceLang,
    required String targetLang,
    required String translation,
    String engine = '',
  }) async {
    final key = _makeKey(text, sourceLang, targetLang, engine: engine);

    // Memory cache
    if (_memoryCache.length >= _maxMemoryEntries) {
      _memoryCache.remove(_memoryCache.keys.first); // Xóa cũ nhất
    }
    _memoryCache[key] = translation;

    // Disk cache
    await init();
    await _prefs?.setString('$_diskPrefix$key', translation);
  }

  /// Lấy bản dịch từ cache.
  ///
  /// Khi [engine] được chỉ định: CHỈ trả key của engine đó — không fallback
  /// sang Hy-MT cũ / `any` / legacy. Đổi engine hoặc tắt offline-only phải
  /// dịch lại, không dính bản dịch cũ.
  Future<String?> get({
    required String text,
    required String sourceLang,
    required String targetLang,
    String engine = '',
  }) async {
    final keys = <String>[
      _makeKey(text, sourceLang, targetLang, engine: engine),
    ];
    if (engine.trim().isEmpty) {
      keys.add(_legacyKey(text, sourceLang, targetLang));
    }

    await init();
    for (final key in keys) {
      if (_memoryCache.containsKey(key)) {
        debugPrint(
            '💾 Cache HIT (memory): ${text.substring(0, text.length.clamp(0, 30))}...');
        return _memoryCache[key];
      }
      final diskResult = _prefs?.getString('$_diskPrefix$key');
      if (diskResult != null) {
        _memoryCache[key] = diskResult;
        debugPrint(
            '💾 Cache HIT (disk): ${text.substring(0, text.length.clamp(0, 30))}...');
        return diskResult;
      }
    }

    return null;
  }

  /// Kiểm tra có trong cache không
  Future<bool> contains({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async {
    final result = await get(
      text: text,
      sourceLang: sourceLang,
      targetLang: targetLang,
    );
    return result != null;
  }

  /// Xóa toàn bộ cache
  Future<void> clear() async {
    _memoryCache.clear();
    await init();
    final keys =
        _prefs?.getKeys().where((k) => k.startsWith(_diskPrefix)).toList() ??
            [];
    for (final key in keys) {
      await _prefs?.remove(key);
    }
    debugPrint('🗑️ Translation cache cleared');
  }

  /// Số lượng entries
  int get memorySize => _memoryCache.length;
}
