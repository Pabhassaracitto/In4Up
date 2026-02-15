// lib/features/translation/cache/translation_cache.dart

import 'dart:collection';
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

  /// Tạo cache key
  String _makeKey(String text, String sourceLang, String targetLang) {
    final hash = text.trim().toLowerCase().hashCode;
    return '${sourceLang}_${targetLang}_$hash';
  }

  /// Lưu bản dịch
  Future<void> put({
    required String text,
    required String sourceLang,
    required String targetLang,
    required String translation,
  }) async {
    final key = _makeKey(text, sourceLang, targetLang);

    // Memory cache
    if (_memoryCache.length >= _maxMemoryEntries) {
      _memoryCache.remove(_memoryCache.keys.first); // Xóa cũ nhất
    }
    _memoryCache[key] = translation;

    // Disk cache
    await init();
    await _prefs?.setString('$_diskPrefix$key', translation);
  }

  /// Lấy bản dịch từ cache
  Future<String?> get({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async {
    final key = _makeKey(text, sourceLang, targetLang);

    // Thử memory trước (nhanh)
    if (_memoryCache.containsKey(key)) {
      debugPrint(
          '💾 Cache HIT (memory): ${text.substring(0, text.length.clamp(0, 30))}...');
      return _memoryCache[key];
    }

    // Thử disk
    await init();
    final diskResult = _prefs?.getString('$_diskPrefix$key');
    if (diskResult != null) {
      // Đưa lên memory
      _memoryCache[key] = diskResult;
      debugPrint(
          '💾 Cache HIT (disk): ${text.substring(0, text.length.clamp(0, 30))}...');
      return diskResult;
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
