// lib/features/learn_by_heart/services/learn_by_heart_storage.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/dhammapada_seed_data.dart';
import '../models/learn_by_heart_item.dart';

class LearnByHeartStorage {
  static const String _keyItems = 'learn_by_heart_items_v1';
  static const String _keyStreak = 'learn_by_heart_streak_v1';
  static const String _keyLastActiveDate = 'learn_by_heart_last_date_v1';
  static const String _keyTodayReviewCount = 'learn_by_heart_today_count_v1';

  static final LearnByHeartStorage instance = LearnByHeartStorage._();
  LearnByHeartStorage._();

  SharedPreferences? _prefs;

  Future<SharedPreferences> get prefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Tải toàn bộ danh sách bài học thuộc lòng (Nếu rỗng thì tự nạp Seed Data)
  Future<List<LearnByHeartItem>> loadItems() async {
    final p = await prefs;
    final jsonList = p.getStringList(_keyItems);

    if (jsonList == null || jsonList.isEmpty) {
      final initialSeeds = DhammapadaSeedData.getInitialItems();
      await saveItems(initialSeeds);
      return initialSeeds;
    }

    final items = <LearnByHeartItem>[];
    for (final jsonStr in jsonList) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        items.add(LearnByHeartItem.fromJson(map));
      } catch (e) {
        debugPrint('⚠️ LearnByHeartStorage parse error: $e');
      }
    }

    if (items.isEmpty) {
      final initialSeeds = DhammapadaSeedData.getInitialItems();
      await saveItems(initialSeeds);
      return initialSeeds;
    }

    return items;
  }

  /// Lưu danh sách bài học thuộc lòng
  Future<void> saveItems(List<LearnByHeartItem> items) async {
    final p = await prefs;
    final jsonList = items.map((i) => jsonEncode(i.toJson())).toList();
    await p.setStringList(_keyItems, jsonList);
  }

  /// Ghi nhận 1 lần ôn tập thành công và tính streak
  Future<int> recordStudySession() async {
    final p = await prefs;
    final today = _dateKey(DateTime.now());
    final lastDate = p.getString(_keyLastActiveDate) ?? '';
    int streak = p.getInt(_keyStreak) ?? 0;
    int todayCount = p.getInt(_keyTodayReviewCount) ?? 0;

    if (lastDate != today) {
      final yesterday = _dateKey(DateTime.now().subtract(const Duration(days: 1)));
      if (lastDate == yesterday) {
        streak += 1;
      } else if (lastDate.isEmpty) {
        streak = 1;
      } else {
        streak = 1;
      }
      todayCount = 1;
      await p.setString(_keyLastActiveDate, today);
    } else {
      todayCount += 1;
    }

    await p.setInt(_keyStreak, streak);
    await p.setInt(_keyTodayReviewCount, todayCount);
    return streak;
  }

  /// Lấy streak hiện tại
  Future<int> getStreak() async {
    final p = await prefs;
    final today = _dateKey(DateTime.now());
    final yesterday = _dateKey(DateTime.now().subtract(const Duration(days: 1)));
    final lastDate = p.getString(_keyLastActiveDate) ?? '';
    final streak = p.getInt(_keyStreak) ?? 0;

    if (lastDate == today || lastDate == yesterday) {
      return streak;
    }
    return 0;
  }

  /// Reset toàn bộ về dữ liệu hạt giống ban đầu
  Future<List<LearnByHeartItem>> resetToDefaults() async {
    final p = await prefs;
    await p.remove(_keyItems);
    await p.remove(_keyStreak);
    await p.remove(_keyLastActiveDate);
    await p.remove(_keyTodayReviewCount);
    final initialSeeds = DhammapadaSeedData.getInitialItems();
    await saveItems(initialSeeds);
    return initialSeeds;
  }

  String _dateKey(DateTime dt) => '${dt.year}-${dt.month}-${dt.day}';
}
