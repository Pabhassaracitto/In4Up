// BISECT C10 — inline toàn bộ, không helper.
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/knowledge/models/learning_state.dart'
    show SkillDimension;
import 'package:in4up/knowledge/models/review_event.dart';
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
  test('minimal inline', () async {
    final store = InMemoryReviewEventStore();
    await store.append(_ev(1, 'u1'));
    expect(await store.activeCountOfUnit('u1'), 1);
  });

  test('batch helper dùng được', () {
    final b = _batch(3, 'u1');
    expect(b.length, 3);
    expect(b.first.eventId, 'e-u1-0');
  });
}
