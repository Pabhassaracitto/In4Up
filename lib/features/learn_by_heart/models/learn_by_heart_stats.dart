// lib/features/learn_by_heart/models/learn_by_heart_stats.dart

/// Số liệu "nhịp học" của module Thuộc Lòng (nguồn cục bộ: SharedPreferences).
///
/// Được đồng bộ đa thiết bị kèm danh sách bài (LHB-006):
/// bản nào có [lastActiveDate] mới hơn thắng; cùng ngày → streak lớn hơn.
class LearnByHeartStats {
  final int streak;

  /// Ngày hoạt động gần nhất, định dạng `Y-M-D` (KHÔNG zero-pad — giữ nguyên
  /// quy ước cũ của `LearnByHeartStorage._dateKey` để dữ liệu cũ không lệch).
  final String lastActiveDate;

  const LearnByHeartStats({this.streak = 0, this.lastActiveDate = ''});

  bool get isEmpty => lastActiveDate.isEmpty && streak <= 0;

  Map<String, dynamic> toJson() => {
        'streak': streak,
        'lastActiveDate': lastActiveDate,
      };

  static LearnByHeartStats fromJson(Map<String, dynamic> json) {
    final rawStreak = json['streak'];
    final int streak;
    if (rawStreak is num) {
      streak = rawStreak.toInt();
    } else {
      streak = int.tryParse('$rawStreak') ?? 0;
    }
    return LearnByHeartStats(
      streak: streak < 0 ? 0 : streak,
      lastActiveDate: '${json['lastActiveDate'] ?? ''}',
    );
  }

  /// Thứ tự ngày (số) để so sánh "mới hơn" giữa 2 khoá `Y-M-D`.
  /// Khoá rỗng/hỏng → 0 (coi như cũ nhất).
  static int dayOrdinal(String dateKey) {
    final parts = dateKey.split('-');
    if (parts.length != 3) return 0;
    final y = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final d = int.tryParse(parts[2]) ?? 0;
    return y * 10000 + m * 100 + d;
  }

  /// Hòa giải 2 bên: ngày mới hơn thắng; cùng ngày → streak lớn hơn.
  static LearnByHeartStats reconcile(
      LearnByHeartStats local, LearnByHeartStats remote) {
    final localDay = dayOrdinal(local.lastActiveDate);
    final remoteDay = dayOrdinal(remote.lastActiveDate);
    if (remoteDay > localDay) return remote;
    if (localDay > remoteDay) return local;
    return LearnByHeartStats(
      streak: local.streak >= remote.streak ? local.streak : remote.streak,
      lastActiveDate: local.lastActiveDate,
    );
  }

  @override
  String toString() =>
      'LearnByHeartStats(streak: $streak, lastActiveDate: $lastActiveDate)';
}
