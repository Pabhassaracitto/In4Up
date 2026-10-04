/// ═══════════════════════════════════════════════════════════════
/// REVIEW EVENT — log append-only, nguồn sự thật cho SM-2
///
/// Handoff MATRIX KNOWLEDGE MVA v2.0 — schema mục 2.4.
///
/// Quy tắc cứng:
///  * Append-only: KHÔNG sửa/xóa record cũ (class này immutable hoàn toàn).
///  * Compaction (mục 2.4, triển khai ở Task 5): sau mỗi 500 event của
///    1 unit → nén thành baseline SM2Snapshot mới.
///  * Conflict 2 thiết bị: cùng unitId + skill, cách nhau < 5 phút
///    ⇒ chỉ event CÓ TIMESTAMP SỚM HƠN tính vào mastery; event còn lại
///    GIỮ trong log nhưng `ignoredForMastery = true`
///    (xem `ReviewEventConflictResolver`).
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:in4up/knowledge/models/learning_state.dart'
    show SkillDimension, kSm2AlgorithmVersion;

/// Xếp loại phản hồi của người dùng khi review (mục 2.4).
enum SkillRating { again, hard, good, easy }

class ReviewEvent {
  final String eventId;
  final String unitId;
  final SkillDimension skill;
  final SkillRating rating;
  final DateTime timestamp;
  final String deviceId;
  final String algorithmVersion;

  /// Mục 2.4 — event thua conflict: giữ trong log nhưng KHÔNG tính mastery.
  final bool ignoredForMastery;

  const ReviewEvent({
    required this.eventId,
    required this.unitId,
    required this.skill,
    required this.rating,
    required this.timestamp,
    required this.deviceId,
    this.algorithmVersion = kSm2AlgorithmVersion,
    this.ignoredForMastery = false,
  });

  /// Trả về bản copy đã gắn cờ thua conflict — không đột biến `this`.
  ReviewEvent markedIgnoredForMastery() => ReviewEvent(
        eventId: eventId,
        unitId: unitId,
        skill: skill,
        rating: rating,
        timestamp: timestamp,
        deviceId: deviceId,
        algorithmVersion: algorithmVersion,
        ignoredForMastery: true,
      );

  @override
  bool operator ==(Object other) {
    return other is ReviewEvent &&
        other.eventId == eventId &&
        other.unitId == unitId &&
        other.skill == skill &&
        other.rating == rating &&
        other.timestamp == timestamp &&
        other.deviceId == deviceId &&
        other.algorithmVersion == algorithmVersion &&
        other.ignoredForMastery == ignoredForMastery;
  }

  @override
  int get hashCode => Object.hash(
        eventId,
        unitId,
        skill,
        rating,
        timestamp,
        deviceId,
        algorithmVersion,
        ignoredForMastery,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'eventId': eventId,
        'unitId': unitId,
        'skill': skill.name,
        'rating': rating.name,
        'timestamp': timestamp.toIso8601String(),
        'deviceId': deviceId,
        'algorithmVersion': algorithmVersion,
        'ignoredForMastery': ignoredForMastery,
      };

  factory ReviewEvent.fromJson(Map<String, dynamic> json) {
    return ReviewEvent(
      eventId: json['eventId'] as String,
      unitId: json['unitId'] as String,
      skill: SkillDimension.values.firstWhere(
        (s) => s.name == json['skill'],
        orElse: () => throw FormatException(
            'SkillDimension không hợp lệ: ${json['skill']}'),
      ),
      rating: SkillRating.values.firstWhere(
        (r) => r.name == json['rating'],
        orElse: () => throw FormatException(
            'SkillRating không hợp lệ: ${json['rating']}'),
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      deviceId: json['deviceId'] as String,
      algorithmVersion:
          json['algorithmVersion'] as String? ?? kSm2AlgorithmVersion,
      ignoredForMastery: json['ignoredForMastery'] as bool? ?? false,
    );
  }
}

/// Mục 2.4 — xử lý conflict review trên 2 thiết bị sau khi sync:
/// cùng `unitId + skill`, khoảng cách timestamp < 5 phút wall-clock
/// ⇒ event MUỘN hơn bị đánh dấu `ignoredForMastery = true`.
///
/// Quy ước chuỗi (khi có nhiều event dồn dập cách nhau < 5 phút liên tiếp):
/// mốc so sánh là event ĐƯỢC TÍNH gần nhất — tránh lan truyền flag vô hạn
/// cho các chuỗi 4:59–4:59–4:59 phút.
class ReviewEventConflictResolver {
  /// Cửa sổ conflict theo wall-clock timestamp (mục 2.4).
  static const Duration conflictWindow = Duration(minutes: 5);

  /// Trả về danh sách MỚI giữ nguyên thứ tự input; các event thua conflict
  /// được thay bằng bản copy có `ignoredForMastery = true`.
  /// Input KHÔNG bị đột biến. Hàm idempotent: chạy lại cho cùng kết quả.
  static List<ReviewEvent> resolveForMastery(List<ReviewEvent> events) {
    // Sắp xếp theo (timestamp, eventId) — eventId làm tiebreak để kết quả
    // ổn định như nhau trên mọi thiết bị khi 2 event cùng timestamp.
    final sorted = <ReviewEvent>[...events]..sort((a, b) {
        final byTime = a.timestamp.compareTo(b.timestamp);
        if (byTime != 0) return byTime;
        return a.eventId.compareTo(b.eventId);
      });

    final ignoredEventIds = <String>{};
    final lastKeptBySkill = <String, DateTime>{};

    for (final event in sorted) {
      // Event đã bị ignore từ trước (chạy lại sau sync mới) không làm
      // dịch mốc conflict.
      if (event.ignoredForMastery) continue;
      final key = '${event.unitId}\u0000${event.skill.name}';
      final lastKept = lastKeptBySkill[key];
      if (lastKept != null &&
          event.timestamp.difference(lastKept) < conflictWindow) {
        ignoredEventIds.add(event.eventId);
      } else {
        lastKeptBySkill[key] = event.timestamp;
      }
    }

    return <ReviewEvent>[
      for (final event in events)
        ignoredEventIds.contains(event.eventId)
            ? event.markedIgnoredForMastery()
            : event,
    ];
  }
}
