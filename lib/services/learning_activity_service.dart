// lib/services/learning_activity_service.dart
//
// HOME-STREAK-001 — kho "hoạt động học thật theo ngày".
//
// Vì sao có file này: `FocusProvider` cũ chỉ tăng streak trong `saveEffort()`
// (slider nỗ lực đã bỏ ở HOME-001 ⇒ không còn caller ⇒ streak luôn 0). Thẻ
// "Nhịp điệu học tập" vì thế không có số liệu thật. Từ đây:
//
//   • Các nơi phát sinh hành động học thật gọi `record(...)` (xem hooks trong
//     VocabularyProvider / MemoryController / ReadModeScreen /
//     LearnByHeartProvider / ShadowingProvider / TranslationService).
//   • Kho gộp theo NGÀY ĐỊA PHƯƠNG, lưu 1 chuỗi JSON nhỏ trong
//     SharedPreferences (không lưu từng event thô) + danh sách khoá chống
//     trùng cho vài ngày gần nhất.
//   • `record` là idempotent theo (ngày, kind, sourceKey): rebuild UI, mở lại
//     app, hay gọi lặp cùng một hành động đều KHÔNG nhân đôi số liệu.
//
// Timezone: quyết định "sự kiện thuộc ngày nào" được chốt tại thời điểm ghi,
// theo giờ địa phương của máy (xem `learningDayKey`). Dữ liệu lưu là khoá ngày
// dạng chuỗi nên đọc lại ở timezone khác vẫn giữ nguyên lịch sử đã ghi —
// không có chuyện cùng một event bị tính lại sang ngày khác.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/learning_activity.dart';

/// Nơi lưu payload thô — tách interface để test không cần plugin/native.
abstract class LearningActivityStorage {
  Future<String?> read();

  Future<void> write(String payload);
}

/// Bản dùng thật: một chuỗi JSON trong SharedPreferences.
class SharedPreferencesLearningActivityStorage
    implements LearningActivityStorage {
  const SharedPreferencesLearningActivityStorage(this.prefsKey);

  final String prefsKey;

  @override
  Future<String?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(prefsKey);
    } catch (e) {
      debugPrint('🎯 LearningActivity: read failed ($e)');
      return null;
    }
  }

  @override
  Future<void> write(String payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, payload);
    } catch (e) {
      debugPrint('🎯 LearningActivity: write failed ($e)');
    }
  }
}

/// Bản trong bộ nhớ — dùng cho test (kể cả test "mở lại app": tạo service mới
/// trên cùng một storage) và cho đường khôi phục khi plugin lỗi.
class InMemoryLearningActivityStorage implements LearningActivityStorage {
  InMemoryLearningActivityStorage([this.payload]);

  String? payload;

  int writeCount = 0;

  @override
  Future<String?> read() async => payload;

  @override
  Future<void> write(String value) async {
    payload = value;
    writeCount++;
  }
}

class LearningActivityService extends ChangeNotifier {
  LearningActivityService({
    LearningActivityStorage? storage,
    DateTime Function()? clock,
  })  : _storage = storage ??
            const SharedPreferencesLearningActivityStorage(prefsKey),
        _clock = clock ?? DateTime.now;

  /// Khoá SharedPreferences (gói gọn 1 chuỗi JSON).
  static const String prefsKey = 'in4up_learning_activity_v1';

  static const int schemaVersion = 1;

  /// Giữ tối đa ~13 tháng dữ liệu ngày (đủ cho streak dài + biểu đồ năm).
  static const int retentionDays = 400;

  /// Khoá chống trùng chỉ cần cho vài ngày gần nhất (persist gọn).
  static const int dedupeRetentionDays = 3;

  /// Trần khoá chống trùng mỗi ngày (chống phình dữ liệu).
  static const int maxSourceKeysPerDay = 300;

  static const String _autoKeyPrefix = 'auto:';

  static LearningActivityService? _instance;

  /// Singleton dùng trong app (xem `lib/main.dart` — gián tiếp qua FocusProvider).
  static LearningActivityService get instance =>
      _instance ??= LearningActivityService();

  /// Cho test/khôi phục: đổi (hoặc bỏ) singleton.
  @visibleForTesting
  static void debugSetInstance(LearningActivityService? service) {
    _instance = service;
  }

  final LearningActivityStorage _storage;
  final DateTime Function() _clock;

  final Map<String, Map<LearningActivityKind, int>> _dayCounts = {};
  final Map<String, List<String>> _dayKeys = {};

  Future<void>? _loading;
  bool _loaded = false;
  bool _disposed = false;
  int _autoSequence = 0;

  bool get isLoaded => _loaded;

  /// Hoàn tất nạp lần đầu (test await; UI không cần chặn).
  Future<void> get ready => _ensureLoaded();

  // ─────────────────────────── GHI ───────────────────────────

  /// Ghi một hoạt động học thật.
  ///
  /// [sourceKey] là danh tính của hành động trong ngày (vd id từ, id tài liệu,
  /// id bài LHB, `hash(câu nguồn)` khi dịch). Bỏ trống ⇒ sự kiện luôn được
  /// tính (dùng cho hành động không lặp lại được, vd gõ tay).
  ///
  /// Trả `true` nếu sự kiện được tính, `false` nếu bị chặn vì trùng.
  Future<bool> record(
    LearningActivityKind kind, {
    String sourceKey = '',
    int amount = 1,
    DateTime? at,
  }) async {
    if (amount <= 0) return false;
    await _ensureLoaded();
    if (_disposed) return false;

    final instant = at ?? _clock();
    final dayKey = learningDayKey(instant);

    final keys = _dayKeys.putIfAbsent(dayKey, () => <String>[]);
    final normalizedKey = sourceKey.trim();
    final resolvedKey = normalizedKey.isEmpty
        ? '$_autoKeyPrefix${_autoSequence++}'
        : normalizedKey;
    final dedupeKey = '${kind.wireName}|$resolvedKey';
    if (keys.contains(dedupeKey)) return false;

    keys.add(dedupeKey);
    if (keys.length > maxSourceKeysPerDay) {
      keys.removeRange(0, keys.length - maxSourceKeysPerDay);
    }

    final counts = _dayCounts.putIfAbsent(
      dayKey,
      () => <LearningActivityKind, int>{},
    );
    counts[kind] = (counts[kind] ?? 0) + amount;

    _prune();
    await _persist();
    _notify();
    return true;
  }

  /// Xoá sạch (dùng cho test / "đặt lại thống kê" nếu sau này cần).
  Future<void> reset() async {
    await _ensureLoaded();
    _dayCounts.clear();
    _dayKeys.clear();
    _autoSequence = 0;
    await _persist();
    _notify();
  }

  // ─────────────────────────── ĐỌC ───────────────────────────

  LearningDayActivity activityOn(DateTime instant) =>
      _activityForKey(learningDayKey(instant));

  LearningDayActivity get today => activityOn(_clock());

  bool get activeToday => today.isActive;

  /// [days] ngày gần nhất, cũ → mới, phần tử cuối là ngày của [now].
  List<LearningDayActivity> recentDays({int days = 7, DateTime? now}) {
    if (days <= 0) return const [];
    final base = learningDayStart(now ?? _clock());
    return [
      for (var offset = days - 1; offset >= 0; offset--)
        _activityForKey(learningDayKey(learningDayShift(base, -offset))),
    ];
  }

  /// Số ngày học liên tiếp đang giữ.
  ///
  /// • Hôm nay có học  ⇒ đếm ngược từ hôm nay.
  /// • Hôm nay chưa học nhưng HÔM QUA có ⇒ giữ nguyên chuỗi (không tụt lúc
  ///   00:00 khi người học chưa kịp học), nhưng KHÔNG cộng thêm.
  /// • Nghỉ trọn một ngày ⇒ chuỗi về 0 (ngày không học không tăng).
  int streak({DateTime? now}) {
    final base = learningDayStart(now ?? _clock());
    var day = base;
    if (!activityOn(day).isActive) {
      day = learningDayShift(day, -1);
      if (!activityOn(day).isActive) return 0;
    }

    var length = 0;
    while (activityOn(day).isActive && length <= retentionDays) {
      length++;
      day = learningDayShift(day, -1);
    }
    return length;
  }

  /// Ảnh chụp cho UI (thẻ Nhịp điệu học tập).
  LearningStreakSnapshot snapshot({int days = 7, DateTime? now}) {
    final instant = now ?? _clock();
    final recent = recentDays(days: days, now: instant);
    final todayActivity = activityOn(instant);
    return LearningStreakSnapshot(
      today: todayActivity,
      streak: streak(now: instant),
      recentDays: recent,
      activeToday: todayActivity.isActive,
    );
  }

  /// Khoá nguồn ổn định cho văn bản tự do (vd câu đã dịch) — FNV-1a 32-bit,
  /// cùng input luôn ra cùng khoá giữa các lần chạy/khởi động lại.
  static String stableSourceKey(String raw) {
    var hash = 0x811c9dc5;
    for (final unit in raw.codeUnits) {
      hash ^= unit & 0xff;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  // ─────────────────────── NẠP / LƯU ───────────────────────

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loading ??= _load();
    await _loading;
  }

  Future<void> _load() async {
    try {
      final payload = await _storage.read();
      if (payload != null && payload.isNotEmpty) {
        _decode(jsonDecode(payload));
      }
    } catch (e) {
      debugPrint('🎯 LearningActivity: decode failed ($e)');
    } finally {
      _loaded = true;
      _prune();
      _notify();
    }
  }

  Future<void> _persist() async {
    try {
      await _storage.write(_encode());
    } catch (e) {
      debugPrint('🎯 LearningActivity: persist failed ($e)');
    }
  }

  String _encode() {
    final days = <String, Map<String, int>>{};
    _dayCounts.forEach((dayKey, counts) {
      if (counts.isEmpty) return;
      days[dayKey] = {
        for (final entry in counts.entries) entry.key.wireName: entry.value,
      };
    });
    return jsonEncode({
      'v': schemaVersion,
      'days': days,
      'keys': _dayKeys,
    });
  }

  void _decode(Object? raw) {
    if (raw is! Map) return;

    final days = raw['days'];
    if (days is Map) {
      days.forEach((dayKey, value) {
        if (dayKey is! String || value is! Map) return;
        final counts = <LearningActivityKind, int>{};
        value.forEach((wireName, amount) {
          if (wireName is! String || amount is! int || amount <= 0) return;
          final kind = LearningActivityKind.fromWireName(wireName);
          if (kind == null) return;
          counts[kind] = amount;
        });
        if (counts.isNotEmpty) _dayCounts[dayKey] = counts;
      });
    }

    final keys = raw['keys'];
    if (keys is Map) {
      keys.forEach((dayKey, value) {
        if (dayKey is! String || value is! List) return;
        _dayKeys[dayKey] = value.whereType<String>().toList();
      });
    }

    var longest = 0;
    for (final list in _dayKeys.values) {
      if (list.length > longest) longest = list.length;
    }
    _autoSequence = longest;
  }

  /// Bỏ dữ liệu quá cũ và khoá chống trùng của các ngày đã qua.
  void _prune() {
    final todayStart = learningDayStart(_clock());
    final oldestDay = learningDayShift(todayStart, -retentionDays);
    final oldestDedupeDay =
        learningDayShift(todayStart, -(dedupeRetentionDays - 1));

    _dayCounts.removeWhere((dayKey, _) {
      final day = learningDayFromKey(dayKey);
      return day == null || day.isBefore(oldestDay);
    });

    _dayKeys.removeWhere((dayKey, _) {
      final day = learningDayFromKey(dayKey);
      return day == null || day.isBefore(oldestDedupeDay);
    });
  }

  LearningDayActivity _activityForKey(String dayKey) => LearningDayActivity(
        dayKey: dayKey,
        counts: _dayCounts[dayKey] ?? const {},
      );

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
