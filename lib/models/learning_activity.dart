// lib/models/learning_activity.dart
//
// HOME-STREAK-001 — mô hình "hoạt động học thật theo ngày" cho thẻ
// "Nhịp điệu học tập" (FocusStreakCard).
//
// Nguyên tắc (theo yêu cầu B6):
//   • Sự kiện chỉ được ghi từ NƠI HÀNH ĐỘNG THẬT xảy ra (lưu/import từ, mở
//     tài liệu để đọc, ôn LHB, shadowing, dịch) — không ghi trong build()/
//     rebuild, không phụ thuộc "effort slider" đã bỏ ở HOME-001.
//   • Mỗi sự kiện có khoá nguồn (`sourceKey`) để kho đọc lại là idempotent:
//     cùng một hành động trong cùng một ngày chỉ tính một lần.
//   • Một sự kiện thuộc về "ngày" theo GIỜ ĐỊA PHƯƠNG của máy
//     (`DateTime.toLocal()`), khoá ngày là 'YYYY-MM-DD'. Khoá ngày được lưu
//     nguyên văn — đọc lại không phụ thuộc timezone hiện tại (xem
//     lib/services/learning_activity_service.dart).

import 'package:flutter/foundation.dart';

/// Loại hoạt động học thật được tính cho streak.
enum LearningActivityKind {
  /// Mở/đọc một tài liệu (mỗi tài liệu tính 1 lần/ngày).
  readDocument('read_doc'),

  /// Số phút thực sự đọc (nhịp 1 phút/lần, có khoá chống trùng).
  readingMinutes('read_min'),

  /// Lưu/import từ vựng (WordList hoặc Vườn trí nhớ).
  vocabulary('vocab'),

  /// Ôn/đánh giá một bài Learn By Heart.
  learnByHeart('lhb'),

  /// Một lượt shadowing đã phân tích xong.
  shadowing('shadowing'),

  /// Một câu/đoạn đã dịch.
  translation('translation');

  const LearningActivityKind(this.wireName);

  /// Tên lưu bền — đổi tên enum vẫn đọc được dữ liệu cũ.
  final String wireName;

  static LearningActivityKind? fromWireName(String value) {
    for (final kind in LearningActivityKind.values) {
      if (kind.wireName == value) return kind;
    }
    return null;
  }
}

/// Khoá ngày 'YYYY-MM-DD' theo giờ địa phương của [instant].
///
/// KHÔNG dùng UTC: người học ở UTC+7 học lúc 06:00 sáng phải rơi vào đúng
/// ngày của họ, không bị lệch sang hôm trước.
String learningDayKey(DateTime instant) {
  final local = instant.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

/// Nửa đêm địa phương của ngày chứa [instant].
DateTime learningDayStart(DateTime instant) {
  final local = instant.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Dịch ngày theo số ngày, an toàn với DST (dùng constructor, không cộng
/// Duration — cộng Duration qua ngày đổi giờ có thể lệch múi giờ).
DateTime learningDayShift(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);

/// Parse khoá ngày 'YYYY-MM-DD' → nửa đêm địa phương. Trả `null` nếu hỏng.
DateTime? learningDayFromKey(String dayKey) {
  final parts = dayKey.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final parsed = DateTime(year, month, day);
  if (parsed.month != month || parsed.day != day) return null;
  return parsed;
}

/// Số liệu học tập đã gộp của MỘT ngày (không lưu từng event thô — persist gọn).
@immutable
class LearningDayActivity {
  LearningDayActivity({
    required this.dayKey,
    Map<LearningActivityKind, int> counts = const {},
  }) : counts = Map.unmodifiable(
          Map<LearningActivityKind, int>.fromEntries(
            counts.entries.where((e) => e.value > 0),
          ),
        );

  factory LearningDayActivity.empty(String dayKey) =>
      LearningDayActivity(dayKey: dayKey);

  /// 'YYYY-MM-DD' theo giờ địa phương.
  final String dayKey;

  final Map<LearningActivityKind, int> counts;

  int countOf(LearningActivityKind kind) => counts[kind] ?? 0;

  int get totalEvents =>
      counts.values.fold<int>(0, (sum, value) => sum + value);

  bool get isActive => totalEvents > 0;

  /// Số ngày trong tháng (nhãn trục cho biểu đồ 7 ngày, không cần dịch).
  int get dayOfMonth => learningDayFromKey(dayKey)?.day ?? 0;

  Map<String, int> toJson() => {
        for (final entry in counts.entries) entry.key.wireName: entry.value,
      };

  @override
  String toString() => 'LearningDayActivity($dayKey, $counts)';
}

/// Ảnh chụp để vẽ thẻ: hôm nay + streak + N ngày gần nhất.
@immutable
class LearningStreakSnapshot {
  const LearningStreakSnapshot({
    required this.today,
    required this.streak,
    required this.recentDays,
    required this.activeToday,
  });

  final LearningDayActivity today;

  /// Số ngày học liên tiếp (đang giữ chuỗi).
  final int streak;

  /// Cũ → mới; phần tử cuối là hôm nay.
  final List<LearningDayActivity> recentDays;

  final bool activeToday;

  /// Tổng hoạt động cao nhất trong cửa sổ hiển thị (để scale biểu đồ).
  int get maxDayTotal => recentDays.fold<int>(
        0,
        (max, day) => day.totalEvents > max ? day.totalEvents : max,
      );

  int get activeDaysInWindow => recentDays.where((day) => day.isActive).length;
}
