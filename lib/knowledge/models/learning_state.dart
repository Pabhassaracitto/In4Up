/// ═══════════════════════════════════════════════════════════════
/// LEARNING STATE — trạng thái ghi nhớ (SNAPSHOT, KHÔNG phải log)
///
/// Handoff MATRIX KNOWLEDGE MVA v2.0 — schema mục 2.3.
///
/// Quy tắc cứng:
///  * 3 skill TÁCH BIỆT (Hiểu–Nghe–Đọc) — vùng bảo vệ mục 0: KHÔNG gộp
///    thành 1 điểm số duy nhất.
///  * Nguồn sự thật của SM-2 là `ReviewEvent` (append-only);
///    file này chỉ là snapshot hiện hành để render UI nhanh.
/// ═══════════════════════════════════════════════════════════════
library;

/// Version công thức SM-2 đã phát hành snapshot này (bắt buộc — mục 2.3).
///
/// ADR-0001 (duyệt 2026-08-19, đã triển khai ở Task 2): hằng số do chính
/// hàm SM-2 DUY NHẤT phát hành — `lib/models/sm2_algorithm.dart`.
/// Re-export tại đây để knowledge module import một chỗ.
export 'package:in4up/models/sm2_algorithm.dart' show kSm2AlgorithmVersion;
import 'package:in4up/models/sm2_algorithm.dart' show kSm2AlgorithmVersion;

/// 3 chiều kỹ năng — TÁCH BIỆT, không gộp (mục 0).
enum SkillDimension { understanding, listening, reading }

class SM2Snapshot {
  final double easeFactor;

  /// Số ngày đến lần review tiếp.
  final int interval;

  final int repetitions;

  final DateTime dueDate;
  final DateTime? lastReviewedAt;

  /// Bắt buộc (mục 2.3) — biết snapshot được tính bởi công thức nào.
  final String algorithmVersion;

  const SM2Snapshot({
    required this.easeFactor,
    required this.interval,
    required this.repetitions,
    required this.dueDate,
    this.lastReviewedAt,
    this.algorithmVersion = kSm2AlgorithmVersion,
  });

  /// Trạng thái khởi điểm: chưa học, due ngay lập tức.
  factory SM2Snapshot.initial({DateTime? now}) => SM2Snapshot(
        easeFactor: 2.5,
        interval: 0,
        repetitions: 0,
        dueDate: now ?? DateTime.now(),
        lastReviewedAt: null,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'easeFactor': easeFactor,
        'interval': interval,
        'repetitions': repetitions,
        'dueDate': dueDate.toIso8601String(),
        'lastReviewedAt': lastReviewedAt?.toIso8601String(),
        'algorithmVersion': algorithmVersion,
      };

  factory SM2Snapshot.fromJson(Map<String, dynamic> json) => SM2Snapshot(
        easeFactor: (json['easeFactor'] as num).toDouble(),
        interval: json['interval'] as int,
        repetitions: json['repetitions'] as int,
        dueDate: DateTime.parse(json['dueDate'] as String),
        lastReviewedAt: json['lastReviewedAt'] == null
            ? null
            : DateTime.parse(json['lastReviewedAt'] as String),
        algorithmVersion:
            json['algorithmVersion'] as String? ?? kSm2AlgorithmVersion,
      );

  @override
  bool operator ==(Object other) {
    return other is SM2Snapshot &&
        other.easeFactor == easeFactor &&
        other.interval == interval &&
        other.repetitions == repetitions &&
        other.dueDate == dueDate &&
        other.lastReviewedAt == lastReviewedAt &&
        other.algorithmVersion == algorithmVersion;
  }

  @override
  int get hashCode => Object.hash(
        easeFactor,
        interval,
        repetitions,
        dueDate,
        lastReviewedAt,
        algorithmVersion,
      );
}

class LearningState {
  final String unitId;

  /// 3 skill TÁCH BIỆT — vùng bảo vệ mục 0.
  final SM2Snapshot understanding;
  final SM2Snapshot listening;
  final SM2Snapshot reading;

  /// Event cuối cùng đã được tính vào state — để audit/replay từ log.
  final String lastReviewEventId;

  LearningState({
    required this.unitId,
    required this.understanding,
    required this.listening,
    required this.reading,
    this.lastReviewEventId = '',
  });

  factory LearningState.initial({required String unitId, DateTime? now}) {
    return LearningState(
      unitId: unitId,
      understanding: SM2Snapshot.initial(now: now),
      listening: SM2Snapshot.initial(now: now),
      reading: SM2Snapshot.initial(now: now),
    );
  }

  /// Lấy snapshot theo chiều kỹ năng.
  SM2Snapshot skill(SkillDimension dimension) {
    switch (dimension) {
      case SkillDimension.understanding:
        return understanding;
      case SkillDimension.listening:
        return listening;
      case SkillDimension.reading:
        return reading;
    }
  }

  /// Trả về state mới: đúng 1 skill được thay, 2 skill còn lại GIỮ NGUYÊN.
  LearningState withSkill(
    SkillDimension dimension,
    SM2Snapshot snapshot, {
    required String lastReviewEventId,
  }) {
    switch (dimension) {
      case SkillDimension.understanding:
        return LearningState(
          unitId: unitId,
          understanding: snapshot,
          listening: listening,
          reading: reading,
          lastReviewEventId: lastReviewEventId,
        );
      case SkillDimension.listening:
        return LearningState(
          unitId: unitId,
          understanding: understanding,
          listening: snapshot,
          reading: reading,
          lastReviewEventId: lastReviewEventId,
        );
      case SkillDimension.reading:
        return LearningState(
          unitId: unitId,
          understanding: understanding,
          listening: listening,
          reading: snapshot,
          lastReviewEventId: lastReviewEventId,
        );
    }
  }

  @override
  bool operator ==(Object other) {
    return other is LearningState &&
        other.unitId == unitId &&
        other.understanding == understanding &&
        other.listening == listening &&
        other.reading == reading &&
        other.lastReviewEventId == lastReviewEventId;
  }

  @override
  int get hashCode => Object.hash(
        unitId,
        understanding,
        listening,
        reading,
        lastReviewEventId,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'unitId': unitId,
        'skills': <String, dynamic>{
          'understanding': understanding.toJson(),
          'listening': listening.toJson(),
          'reading': reading.toJson(),
        },
        'lastReviewEventId': lastReviewEventId,
      };

  factory LearningState.fromJson(Map<String, dynamic> json) {
    final skills = json['skills'] as Map<String, dynamic>;
    return LearningState(
      unitId: json['unitId'] as String,
      understanding:
          SM2Snapshot.fromJson(skills['understanding'] as Map<String, dynamic>),
      listening: SM2Snapshot.fromJson(skills['listening'] as Map<String, dynamic>),
      reading: SM2Snapshot.fromJson(skills['reading'] as Map<String, dynamic>),
      lastReviewEventId: json['lastReviewEventId'] as String? ?? '',
    );
  }
}
