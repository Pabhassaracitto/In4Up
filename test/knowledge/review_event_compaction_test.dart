// Test Task 5 — DoD (mục 8 bàn giao):
//   "Ghi 1000 event giả lập → RAM không tăng bất thường,
//    snapshot đúng sau compaction"
//
// Thiết kế RAM-bounded thể hiện ở tầng store: active-per-unit bị chặn
// quanh ngưỡng 500 (mục 2.4); tổng lịch sử append được đếm vĩnh viễn.
// Impl vật lý (Hive LazyBox/SQLite) sẽ gắn qua cùng interface.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/knowledge/models/learning_state.dart'
    show SM2Snapshot, SkillDimension, SM2Algorithm;
import 'package:in4up/knowledge/models/review_event.dart';
import 'package:in4up/knowledge/review/review_event_compactor.dart';
import 'package:in4up/knowledge/review/review_event_store.dart';
import 'package:in4up/knowledge/text/text_pipeline_worker.dart';

ReviewEvent _ev(
  int i,
  String unitId, {
  SkillRating? rating,
  DateTime? t,
  bool ignored = false,
  String device = 'test-device',
}) {
  final effectiveRating = rating ??
      (i % 4 == 0
          ? SkillRating.again
          : i % 4 == 1
              ? SkillRating.hard
              : i % 4 == 2
                  ? SkillRating.good
                  : SkillRating.easy);
  return ReviewEvent(
    eventId: 'e-$unitId-$i',
    unitId: unitId,
    skill: SkillDimension.listening,
    rating: effectiveRating,
    timestamp: t ?? DateTime.utc(2020, 1, 1).add(Duration(days: i)),
    deviceId: device,
    ignoredForMastery: ignored,
  );
}

List<ReviewEvent> _batch(int count, String unitId, {int from = 0}) =>
    [for (var i = 0; i < count; i++) _ev(from + i, unitId)];

void main() {
  group('ReviewEventStore — append-only (mục 2.4)', () {
    test('append trùng eventId ⇒ StateError (không có đường sửa/xóa)',
        () async {
      final store = InMemoryReviewEventStore();
      await store.append(_ev(1, 'u1'));
      await store.append(_ev(2, 'u1'));
      expect(() => store.append(_ev(1, 'u1')), throwsStateError);
      expect(await store.activeCountOfUnit('u1'), 2);
    });

    test('activeEventsOfUnit: lazy, lọc retired, sắp theo timestamp', () async {
      final store = InMemoryReviewEventStore();
      await store.append(_ev(5, 'u1'));
      await store.append(_ev(1, 'u1'));
      await store.append(_ev(9, 'u2')); // unit khác — không lọt vào
      final events = await store.activeEventsOfUnit('u1').toList();
      expect(events.map((e) => e.eventId).toList(), ['e-u1-1', 'e-u1-5']);
    });
  });

  group('ReviewEventCompactor — ngưỡng & replay', () {
    test('499 event ⇒ null; 500 event ⇒ record đủ lô', () {
      expect(
        ReviewEventCompactor.compact(unitId: 'u1', events: _batch(499, 'u1')),
        isNull,
      );
      final record =
          ReviewEventCompactor.compact(unitId: 'u1', events: _batch(500, 'u1'));
      expect(record, isNotNull);
      expect(record!.eventCount, 500);
      expect(record.replayedCount, 500);
      expect(record.compactedEventIds.length, 500);
    });

    test('replay ĐÚNG bằng hàm SM-2 duy nhất (so chuỗi thủ công)', () {
      final events = [
        _ev(0, 'u1', rating: SkillRating.good, t: DateTime.utc(2020, 1, 1)),
        _ev(1, 'u1', rating: SkillRating.easy, t: DateTime.utc(2020, 1, 3)),
        _ev(2, 'u1', rating: SkillRating.again, t: DateTime.utc(2020, 1, 9)),
        // pad lên 500 với good ở các mốc ngày tiếp theo:
        for (var i = 3; i < 500; i++)
          _ev(i, 'u1', rating: SkillRating.good,
              t: DateTime.utc(2020, 1, 10).add(Duration(days: i - 3))),
      ];

      // Chuỗi thủ công — gọi thẳng hàm chuẩn:
      var ef = 2.5, interval = 0, reps = 0;
      DateTime due = DateTime.utc(2020, 1, 1);
      for (final e in events) {
        final r = SM2Algorithm.calculate(
            quality: qualityOf(e.rating),
            currentEF: ef,
            currentInterval: interval,
            currentReps: reps,
            now: e.timestamp);
        ef = r.easeFactor;
        interval = r.interval;
        reps = r.repetitions;
        due = r.nextReview;
      }

      final record =
          ReviewEventCompactor.compact(unitId: 'u1', events: events);
      final b = record!.baseline;
      expect(b.easeFactor, closeTo(ef, 1e-9));
      expect(b.interval, interval);
      expect(b.repetitions, reps);
      expect(b.dueDate, due);
      expect(b.lastReviewedAt, events.last.timestamp);
    });

    test('ignoredForMastery: KHÔNG tính mastery nhưng vẫn được nghỉ hưu', () {
      final events = _batch(500, 'u1');
      // 100 event đầu bị flag ignore (thua conflict 2 thiết bị):
      final marked = [
        for (var i = 0; i < events.length; i++)
          i < 100 ? events[i].markedIgnoredForMastery() : events[i],
      ];
      final record =
          ReviewEventCompactor.compact(unitId: 'u1', events: marked);
      expect(record!.eventCount, 500);
      expect(record.replayedCount, 400);
      // Cả 500 (kể cả ignored) đều nằm trong lô nghỉ hưu — không rác:
      expect(record.compactedEventIds.length, 500);
    });

    test('rating mapping: 500 lần again ⇒ reps 0, interval 1, EF chạm sàn', () {
      final events = [
        for (var i = 0; i < 500; i++)
          _ev(i, 'u1', rating: SkillRating.again,
              t: DateTime.utc(2020, 1, 1).add(Duration(days: i)))
      ];
      final record =
          ReviewEventCompactor.compact(unitId: 'u1', events: events);
      final b = record!.baseline;
      expect(b.repetitions, 0);
      expect(b.interval, 1);
      expect(b.easeFactor, closeTo(1.3, 1e-9));
      expect(b.dueDate, events.last.timestamp.add(const Duration(days: 1)));
    });
  });

  group('BẤT BIẾN KHÔNG MẤT THÔNG TIN (associativity của compaction)', () {
    test('nén 2 chặng == replay 1000 event một mạch', () {
      final all = _batch(1000, 'u1');
      final first = all.sublist(0, 500);
      final rest = all.sublist(500);

      final direct = ReviewEventCompactor.compact(unitId: 'u1', events: all)!;
      final stage1 = ReviewEventCompactor.compact(unitId: 'u1', events: first)!;
      final stage2 = ReviewEventCompactor.compact(
          unitId: 'u1', events: rest, baseline: stage1.baseline)!;

      final b1 = direct.baseline;
      final b2 = stage2.baseline;
      expect(b2.easeFactor, closeTo(b1.easeFactor, 1e-9));
      expect(b2.interval, b1.interval);
      expect(b2.repetitions, b1.repetitions);
      expect(b2.dueDate, b1.dueDate);
      expect(b2.lastReviewedAt, b1.lastReviewedAt);
    });
  });

  group('DoD: 1000 event — RAM-bounded qua service + store', () {
    test('nén xong: active về 0, lịch sử append vẫn đếm đủ 1500', () async {
      final store = InMemoryReviewEventStore();
      final service = ReviewEventCompactionService(store);

      for (final e in _batch(1000, 'unitA')) {
        await store.append(e);
      }
      for (final e in _batch(500, 'unitB')) {
        await store.append(e);
      }
      expect(store.totalAppended, 1500);

      final recA = await service.compactUnit('unitA');
      expect(recA, isNotNull);
      expect(await store.activeCountOfUnit('unitA'), 0,
          reason: 'active set của unitA phải rỗng sau compaction');
      expect(await store.activeCountOfUnit('unitB'), 500,
          reason: 'unitB chưa nén — độc lập');

      final recB = await service.compactUnit('unitB');
      expect(recB, isNotNull);
      expect(await store.activeCountOfUnit('unitB'), 0);

      // Tổng active toàn store = 0 ⇒ RAM của lớp active không tăng
      // theo tổng lịch sử (chỉ baseline + records tăng — bounded).
      expect(store.totalRetired, 1500);
      expect(store.totalAppended, 1500, reason: 'dấu vết audit nguyên vẹn');
    });

    test('dưới ngưỡng: service trả null, KHÔNG nghỉ hưu gì', () async {
      final store = InMemoryReviewEventStore();
      final service = ReviewEventCompactionService(store);
      for (final e in _batch(499, 'u1')) {
        await store.append(e);
      }
      expect(await service.compactUnit('u1'), isNull);
      expect(await store.activeCountOfUnit('u1'), 499);
      expect(store.totalRetired, 0);
    });
  });

  group('Conflict resolver → compaction (mục 2.4 khép kín)', () {
    test('event thua conflict không lọt vào baseline', () {
      final t = DateTime.utc(2020, 1, 1, 10);
      final raw = <ReviewEvent>[
        // 2 event conflict cách 2 phút + 498 event thường:
        _ev(0, 'u1', rating: SkillRating.good, t: t, device: 'laptop'),
        _ev(1, 'u1', rating: SkillRating.easy,
            t: t.add(const Duration(minutes: 2)), device: 'phone'),
        for (var i = 2; i < 500; i++) _ev(i, 'u1'),
      ];
      final resolved = ReviewEventConflictResolver.resolveForMastery(raw);
      final ignoredCount =
          resolved.where((e) => e.ignoredForMastery).length;
      expect(ignoredCount, 1);

      final record =
          ReviewEventCompactor.compact(unitId: 'u1', events: resolved);
      expect(record!.replayedCount, 499);
    });
  });

  group('CompactionRecord — JSON & worker isolate', () {
    test('JSON round-trip giữ mọi field', () {
      final record =
          ReviewEventCompactor.compact(unitId: 'u1', events: _batch(500, 'u1'))!;
      final clone = CompactionRecord.fromJson(record.toJson());
      expect(clone.toJson(), equals(record.toJson()));
    });

    test('compact TRONG worker isolate == in-process (JSON hai chiều)',
        () async {
      final worker = await TextPipelineWorker.spawn()
          .timeout(const Duration(seconds: 10));
      try {
        final events = _batch(500, 'u9');
        final inProcess =
            ReviewEventCompactor.compact(unitId: 'u9', events: events);

        final viaWorker = await worker
            .compactReviewEvents(unitId: 'u9', events: events)
            .timeout(const Duration(seconds: 10));

        expect(viaWorker, isNotNull);
        // recordId là UUID sinh riêng — so PHẦN NGHĨA:
        expect(viaWorker!.eventCount, inProcess!.eventCount);
        expect(viaWorker.replayedCount, inProcess.replayedCount);
        expect(viaWorker.compactedEventIds, inProcess.compactedEventIds);
        expect(viaWorker.baseline.toJson(), equals(inProcess.baseline.toJson()));

        // Dưới ngưỡng ⇒ null:
        final small = await worker
            .compactReviewEvents(unitId: 'u9', events: _batch(10, 'u9'))
            .timeout(const Duration(seconds: 10));
        expect(small, isNull);
      } finally {
        worker.dispose();
      }
    });
  });
}
