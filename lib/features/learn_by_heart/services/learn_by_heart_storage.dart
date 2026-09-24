// lib/features/learn_by_heart/services/learn_by_heart_storage.dart

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/dhammapada_seed_data.dart';
import '../models/learn_by_heart_item.dart';
import '../models/learn_by_heart_stats.dart';

/// Kho cục bộ của module Thuộc Lòng — offline-first.
///
/// Ngoài dữ liệu bài học, lớp này giữ luôn **trạng thái đồng bộ** (LHB-006):
///  - `pending`: id bài có thay đổi cục bộ chưa đẩy lên cloud;
///  - `tombstones`: id bài đã xoá kèm mốc thời gian (chống hồi sinh khi pull).
///
/// Lớp này KHÔNG biết gì về mạng/Firebase — chỉ đọc/ghi SharedPreferences.
class LearnByHeartStorage {
  static const String _keyItems = 'learn_by_heart_items_v1';
  static const String _keyStreak = 'learn_by_heart_streak_v1';
  static const String _keyLastActiveDate = 'learn_by_heart_last_date_v1';
  static const String _keyTodayReviewCount = 'learn_by_heart_today_count_v1';

  /// Hàng đợi thay đổi cục bộ (StringList các id).
  static const String _keyPending = 'learn_by_heart_pending_v1';

  /// Bia mộ các bài đã xoá: JSON `{id: ISO8601}`.
  static const String _keyTombstones = 'learn_by_heart_tombstones_v1';

  static final LearnByHeartStorage instance = LearnByHeartStorage._();
  LearnByHeartStorage._();

  SharedPreferences? _prefs;

  Future<SharedPreferences> get prefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Chỉ dùng trong test: xoá cache prefs (khi mock đổi giữa các test case).
  @visibleForTesting
  void debugResetPrefsCache() {
    _prefs = null;
  }

  // ══════════════════════════════════════════════════════════════
  // BÀI HỌC THUỘC LÒNG
  // ══════════════════════════════════════════════════════════════

  /// Đọc danh sách bài; nếu máy chưa có gì → nạp Seed Data (như trước giờ).
  ///
  /// Bài đã bị xoá (có tombstone) KHÔNG được seed lại — tránh hồi sinh bài
  /// người dùng đã xoá ở thiết bị khác.
  Future<List<LearnByHeartItem>> loadItems() async {
    final items = await readItems();
    if (items.isNotEmpty) return items;

    final initialSeeds = await _seedItems();
    await saveItems(initialSeeds);
    return initialSeeds;
  }

  /// Đọc RAW: KHÔNG seed. Lớp đồng bộ dùng hàm này để không tự sinh dữ liệu
  /// trong lúc kéo/đẩy (kể cả khi người dùng đã xoá hết bài).
  Future<List<LearnByHeartItem>> readItems() async {
    final p = await prefs;
    final jsonList = p.getStringList(_keyItems);
    if (jsonList == null || jsonList.isEmpty) return <LearnByHeartItem>[];

    final items = <LearnByHeartItem>[];
    for (final jsonStr in jsonList) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        items.add(LearnByHeartItem.fromJson(map));
      } catch (e) {
        debugPrint('⚠️ LearnByHeartStorage parse error: $e');
      }
    }
    return items;
  }

  Future<List<LearnByHeartItem>> _seedItems() async {
    final tombstones = await loadTombstones();
    final seeds = DhammapadaSeedData.getInitialItems();
    if (tombstones.isEmpty) return seeds;
    return seeds.where((i) => !tombstones.containsKey(i.id)).toList();
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

  /// Số liệu nhịp học (streak + ngày hoạt động gần nhất) để đồng bộ.
  Future<LearnByHeartStats> readStats() async {
    final p = await prefs;
    return LearnByHeartStats(
      streak: p.getInt(_keyStreak) ?? 0,
      lastActiveDate: p.getString(_keyLastActiveDate) ?? '',
    );
  }

  /// Ghi đè số liệu nhịp học (dùng khi hòa giải với cloud hoặc khi ôn tập).
  Future<void> writeStats(LearnByHeartStats stats) async {
    final p = await prefs;
    await p.setInt(_keyStreak, stats.streak);
    await p.setString(_keyLastActiveDate, stats.lastActiveDate);
  }

  /// Reset toàn bộ về dữ liệu hạt giống ban đầu.
  ///
  /// Reset là hành động CỤC BỘ: hàng đợi pending bị xoá (các sửa đổi đang chờ
  /// không còn tương ứng với dữ liệu mới), nhưng tombstone được GIỮ để bài đã
  /// xoá không hồi sinh. Dữ liệu cloud sẽ quay lại ở lần pull kế tiếp —
  /// muốn xoá thật thì xoá từng bài như bình thường.
  Future<List<LearnByHeartItem>> resetToDefaults() async {
    final p = await prefs;
    await p.remove(_keyItems);
    await p.remove(_keyStreak);
    await p.remove(_keyLastActiveDate);
    await p.remove(_keyTodayReviewCount);
    await p.remove(_keyPending);
    final initialSeeds = await _seedItems();
    await saveItems(initialSeeds);
    return initialSeeds;
  }

  // ══════════════════════════════════════════════════════════════
  // TRẠNG THÁI ĐỒNG BỘ (pending + tombstones)
  // ══════════════════════════════════════════════════════════════

  /// Id các bài có thay đổi cục bộ chưa đẩy lên cloud.
  Future<Set<String>> loadPendingIds() async {
    final p = await prefs;
    final list = p.getStringList(_keyPending);
    if (list == null || list.isEmpty) return <String>{};
    return list.where((id) => id.trim().isNotEmpty).toSet();
  }

  Future<void> savePendingIds(Set<String> ids) async {
    final p = await prefs;
    final clean = ids.where((id) => id.trim().isNotEmpty).toList()..sort();
    if (clean.isEmpty) {
      await p.remove(_keyPending);
      return;
    }
    await p.setStringList(_keyPending, clean);
  }

  Future<void> markPending(String id) async {
    if (id.trim().isEmpty) return;
    final p = await prefs;
    final list = p.getStringList(_keyPending) ?? <String>[];
    if (list.contains(id)) return;
    list.add(id);
    await p.setStringList(_keyPending, list);
  }

  Future<void> clearPending(Iterable<String> ids) async {
    final remove = ids.toSet();
    if (remove.isEmpty) return;
    final p = await prefs;
    final list = p.getStringList(_keyPending) ?? <String>[];
    final kept = list.where((id) => !remove.contains(id)).toList();
    if (kept.length == list.length) return;
    if (kept.isEmpty) {
      await p.remove(_keyPending);
      return;
    }
    await p.setStringList(_keyPending, kept);
  }

  /// Bia mộ: `id → thời điểm xoá`.
  Future<Map<String, DateTime>> loadTombstones() async {
    final p = await prefs;
    final raw = p.getString(_keyTombstones);
    if (raw == null || raw.trim().isEmpty) return <String, DateTime>{};

    final out = <String, DateTime>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        decoded.forEach((key, value) {
          final id = '$key'.trim();
          if (id.isEmpty) return;
          final at = LearnByHeartItem.parseStamp(value);
          if (at != null) out[id] = at;
        });
      }
    } catch (e) {
      debugPrint('⚠️ LearnByHeartStorage tombstones parse error: $e');
    }
    return out;
  }

  Future<void> saveTombstones(Map<String, DateTime> tombstones) async {
    final p = await prefs;
    final clean = <String, String>{};
    tombstones.forEach((id, at) {
      if (id.trim().isEmpty) return;
      clean[id] = at.toUtc().toIso8601String();
    });
    if (clean.isEmpty) {
      await p.remove(_keyTombstones);
      return;
    }
    await p.setString(_keyTombstones, jsonEncode(clean));
  }

  Future<void> addTombstone(String id, {DateTime? at}) async {
    if (id.trim().isEmpty) return;
    final map = await loadTombstones();
    final stamp = at ?? DateTime.now();
    final current = map[id];
    if (current != null && current.isAfter(stamp)) return;
    map[id] = stamp;
    await saveTombstones(map);
  }

  String _dateKey(DateTime dt) => '${dt.year}-${dt.month}-${dt.day}';
}
