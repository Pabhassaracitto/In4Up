// BISECT C10 — inline toàn bộ, không helper.
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/knowledge/models/learning_state.dart'
    show SkillDimension;
import 'package:in4up/knowledge/models/review_event.dart';
import 'package:in4up/knowledge/review/review_event_store.dart';

void main() {
  test('minimal inline', () async {
    final store = InMemoryReviewEventStore();
    await store.append(ReviewEvent(
      eventId: 'e1',
      unitId: 'u1',
      skill: SkillDimension.listening,
      rating: SkillRating.good,
      timestamp: DateTime.utc(2026, 1, 1),
      deviceId: 'd',
    ));
    expect(await store.activeCountOfUnit('u1'), 1);
  });
}
