// lib/screens/memory_mode/services/memory_storage_service.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/memory_item.dart';

class MemoryStorageService {
  static const String _keyItems = 'memory_items_v2';
  static const String _keyTodayReviewed = 'memory_today_reviewed';
  static const String _keyTodayCorrect = 'memory_today_correct';
  static const String _keyLastDate = 'memory_last_date';
  static const String _keyStreak = 'memory_streak';

  // --- SỬA LỖI 1: Constructor cú pháp sai ---
  static final MemoryStorageService instance = MemoryStorageService._();
  MemoryStorageService._();
  // ------------------------------------------

  SharedPreferences? _prefs;

  Future<SharedPreferences> get prefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ==================== ITEMS ====================

  Future<void> saveItems(List<MemoryItem> items) async {
    final p = await prefs;
    final jsonList = items.map((i) => jsonEncode(i.toJson())).toList();
    await p.setStringList(_keyItems, jsonList);
    debugPrint('🧠 Storage: saved ${items.length} items');
  }

  Future<List<MemoryItem>> loadItems() async {
    final p = await prefs;
    final jsonList = p.getStringList(_keyItems);
    if (jsonList == null || jsonList.isEmpty) return [];

    final items = <MemoryItem>[];
    for (final jsonStr in jsonList) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        items.add(MemoryItem.fromJson(map));
      } catch (e) {
        debugPrint('🧠 Storage: parse error: $e');
      }
    }
    debugPrint('🧠 Storage: loaded ${items.length} items');
    return items;
  }

  // ==================== TODAY STATS ====================

  Future<void> saveTodayStats(int reviewed, int correct) async {
    final p = await prefs;
    final today = _todayKey();
    final lastDate = p.getString(_keyLastDate) ?? '';

    // Ngày mới → reset + cập nhật streak
    if (lastDate != today) {
      final yesterday =
          _dateKey(DateTime.now().subtract(const Duration(days: 1)));
      final oldStreak = p.getInt(_keyStreak) ?? 0;

      if (lastDate == yesterday) {
        await p.setInt(_keyStreak, oldStreak + 1);
      } else {
        await p.setInt(_keyStreak, reviewed > 0 ? 1 : 0);
      }
      await p.setString(_keyLastDate, today);
    }

    await p.setInt(_keyTodayReviewed, reviewed);
    await p.setInt(_keyTodayCorrect, correct);
  }

  Future<Map<String, int>> loadTodayStats() async {
    final p = await prefs;
    final today = _todayKey();
    final lastDate = p.getString(_keyLastDate) ?? '';

    if (lastDate != today) {
      return {'reviewed': 0, 'correct': 0, 'streak': p.getInt(_keyStreak) ?? 0};
    }

    return {
      'reviewed': p.getInt(_keyTodayReviewed) ?? 0,
      'correct': p.getInt(_keyTodayCorrect) ?? 0,
      'streak': p.getInt(_keyStreak) ?? 0,
    };
  }

  // ==================== HELPERS ====================

  String _todayKey() => _dateKey(DateTime.now());

  // --- SỬA LỖI 2: String interpolation bị sai ---
  String _dateKey(DateTime dt) => '${dt.year}-${dt.month}-${dt.day}';
  // ----------------------------------------------

  Future<void> clearAll() async {
    final p = await prefs;
    await p.remove(_keyItems);
    await p.remove(_keyTodayReviewed);
    await p.remove(_keyTodayCorrect);
    await p.remove(_keyLastDate);
    await p.remove(_keyStreak);
    debugPrint('🧠 Storage: cleared all');
  }
}
