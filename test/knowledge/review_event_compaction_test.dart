// Test Task 5 — DoD (mục 8 bàn giao):
//   "Ghi 1000 event giả lập → RAM không tăng bất thường,
//    snapshot đúng sau compaction"
//
// Thiết kế RAM-bounded thể hiện ở tầng store: active-per-unit bị chặn
// quanh ngưỡng 500 (mục 2.4); tổng lịch sử append được đếm vĩnh viễn.
// Impl vật lý (Hive LazyBox/SQLite) sẽ gắn qua cùng interface.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/knowledge/models/learning_state.dart'
    show SkillDimension, SM2Algorithm;
import 'package:in4up/knowledge/models/review_event.dart';
import 'package:in4up/knowledge/review/review_event_compactor.dart';
import 'package:in4up/knowledge/review/review_event_store.dart';

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

}
