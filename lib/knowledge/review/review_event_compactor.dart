/// ═══════════════════════════════════════════════════════════════
/// REVIEW EVENT COMPACTOR — nén log thành baseline snapshot (mục 2.4)
///
/// "Compaction: sau mỗi 500 event của 1 unit → nén thành baseline
///  SM2Snapshot mới + nghỉ hưu event đã nén (giữ tổng số records có
///  kiểm soát, tránh OOM Hive)."
///
/// Nguyên tắc:
///  * Replay bằng HÀM SM-2 DUY NHẤT (ADR-0001), tiêm `now = timestamp`
///    của từng event ⇒ DETERMINISTIC — cùng input luôn cùng baseline.
///  * KHÔNG MẤT THÔNG TIN mastery: bất biến kết hợp được kiểm bằng test —
///    replay(baseline1 + 500 event sau) == replay(1000 event một mạch).
///  * Event `ignoredForMastery` KHÔNG tính vào mastery (mục 2.4) nhưng
///    vẫn được nghỉ hưu cùng lô (không để rác tồn активных mãi).
///  * Thuần chức năng — chạy được trong worker isolate (mục 4).
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:uuid/uuid.dart';

import 'package:in4up/knowledge/models/learning_state.dart'
    show SM2Snapshot, kSm2AlgorithmVersion;
import 'package:in4up/knowledge/models/review_event.dart';
import 'package:in4up/models/sm2_algorithm.dart';

/// Ngưỡng nén theo bàn giao mục 2.4 (sau mỗi 500 event của 1 unit).
const int kCompactionThreshold = 500;

/// Bản ghi một lần compaction — append-only, giữ dấu vết các event
/// đã nằm gọn trong baseline (truy vết được, không mất âm thầm).
class CompactionRecord {
  final String recordId;
  final String unitId;

  /// Mọi eventId đã nén (kể cả ignored — để idle set không phình).
  final List<String> compactedEventIds;

  /// Tổng event trong lô.
  final int eventCount;

  /// Số event thực sự được tính vào mastery (bỏ ignoredForMastery).
  final int replayedCount;

  /// Baseline sau replay — điểm khởi đầu cho các event tiếp theo.
  final SM2Snapshot baseline;

  final DateTime createdAt;

  const CompactionRecord({
    required this.recordId,
    required this.unitId,
    required this.compactedEventIds,
    required this.eventCount,
    required this.replayedCount,
    required this.baseline,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'recordId': recordId,
        'unitId': unitId,
        'compactedEventIds': compactedEventIds,
        'eventCount': eventCount,
        'replayedCount': replayedCount,
        'baseline': baseline.toJson(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory CompactionRecord.fromJson(Map<String, dynamic> json) =>
      CompactionRecord(
        recordId: json['recordId'] as String,
        unitId: json['unitId'] as String,
        compactedEventIds:
            (json['compactedEventIds'] as List<dynamic>? ?? const <dynamic>[])
                .whereType<String>()
                .toList(),
        eventCount: json['eventCount'] as int? ?? 0,
        replayedCount: json['replayedCount'] as int? ?? 0,
        baseline: SM2Snapshot.fromJson(
            json['baseline'] as Map<String, dynamic>),
        createdAt: json['createdAt'] == null
            ? DateTime.fromMillisecondsSinceEpoch(0)
            : DateTime.parse(json['createdAt'] as String),
      );
}

/// Ánh xạ rating (schema mục 2.4) → quality SM-2 (0–5).
/// again = fail; hard/good/easy đều pass với cường độ tăng dần.
int qualityOf(SkillRating rating) {
  switch (rating) {
    case SkillRating.again:
      return 0;
    case SkillRating.hard:
      return 3;
    case SkillRating.good:
      return 4;
    case SkillRating.easy:
      return 5;
  }
}

class ReviewEventCompactor {
  ReviewEventCompactor._();

  /// Nén [events] ACTIVE của một unit (đã loại ignored khi replay).
  /// Trả null nếu chưa chạm ngưỡng [kCompactionThreshold].
  /// [baseline] là baseline của lần nén TRƯỚC (nếu có) — replay tiếp nối.
  static CompactionRecord? compact({
    required String unitId,
    required List<ReviewEvent> events,
    SM2Snapshot? baseline,
    String? recordId,
    DateTime? now,
  }) {
    if (events.length < kCompactionThreshold) return null;

    final replayable = events
        .where((e) => !e.ignoredForMastery)
        .toList()
      ..sort((a, b) {
        final byTime = a.timestamp.compareTo(b.timestamp);
        if (byTime != 0) return byTime;
        return a.eventId.compareTo(b.eventId);
      });

    // Khởi điểm: baseline trước đó, hoặc EF 2.5 / interval 0 / reps 0
    // (tương đương SM2Snapshot.initial nhưng dueDate sẽ bị ghi đè bởi
    // kết quả replay đầu tiên).
    var easeFactor = baseline?.easeFactor ?? 2.5;
    var interval = baseline?.interval ?? 0;
    var repetitions = baseline?.repetitions ?? 0;
    SM2Snapshot state = baseline ??
        SM2Snapshot(
          easeFactor: easeFactor,
          interval: interval,
          repetitions: repetitions,
          dueDate: now ?? DateTime.now(),
          lastReviewedAt: null,
        );

    for (final event in replayable) {
      final result = SM2Algorithm.calculate(
        quality: qualityOf(event.rating),
        currentEF: easeFactor,
        currentInterval: interval,
        currentReps: repetitions,
        now: event.timestamp,
      );
      easeFactor = result.easeFactor;
      interval = result.interval;
      repetitions = result.repetitions;
      state = SM2Snapshot(
        easeFactor: result.easeFactor,
        interval: result.interval,
        repetitions: result.repetitions,
        dueDate: result.nextReview,
        lastReviewedAt: event.timestamp,
        algorithmVersion: kSm2AlgorithmVersion,
      );
    }

    return CompactionRecord(
      recordId: recordId ?? const Uuid().v4(),
      unitId: unitId,
      compactedEventIds: List.unmodifiable(
          events.map((e) => e.eventId)),
      eventCount: events.length,
      replayedCount: replayable.length,
      baseline: state,
      createdAt: now ?? DateTime.now(),
    );
  }
}

/// Orchestrator nối store ↔ compactor. Chạy per-unit — active set
/// per-unit bị chặn quanh ngưỡng ⇒ RAM không tăng bất thường (mục 3).
class ReviewEventCompactionService {
  final ReviewEventStore store;

  ReviewEventCompactionService(this.store);

  /// Nén 1 unit nếu vượt ngưỡng. Trả về record (null nếu chưa đủ lô).
  /// [previousBaseline] từ lần nén trước (do caller quản lý — LearningState).
  Future<CompactionRecord?> compactUnit(
    String unitId, {
    SM2Snapshot? previousBaseline,
    DateTime? now,
  }) async {
    final events = await store.activeEventsOfUnit(unitId).toList();
    final record = ReviewEventCompactor.compact(
      unitId: unitId,
      events: events,
      baseline: previousBaseline,
      now: now,
    );
    if (record == null) return null;
    await store.retire(record.compactedEventIds.toSet());
    return record;
  }
}
