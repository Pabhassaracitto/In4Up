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

}
