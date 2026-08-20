// BISECT C4 — probe: dùng đủ mọi import, không logic phức tạp.
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/knowledge/models/learning_state.dart'
    show SM2Snapshot, SkillDimension, SM2Algorithm;
import 'package:in4up/knowledge/models/review_event.dart';
import 'package:in4up/knowledge/review/review_event_compactor.dart';
import 'package:in4up/knowledge/review/review_event_store.dart';
import 'package:in4up/knowledge/text/text_pipeline_worker.dart';

void main() {
  test('probe symbols', () {
    expect(SkillDimension.values.length, 3);
    final r = SM2Algorithm.calculate(quality: 4);
    expect(r.interval, 1);
    final snap = SM2Snapshot.initial(now: DateTime.utc(2026, 1, 1));
    expect(snap.easeFactor, 2.5);
    final ev = ReviewEvent(
      eventId: 'p1',
      unitId: 'u',
      skill: SkillDimension.reading,
      rating: SkillRating.good,
      timestamp: DateTime.utc(2026, 1, 1),
      deviceId: 'd',
    );
    expect(ev.eventId, 'p1');
    expect(qualityOf(SkillRating.easy), 5);
    final store = InMemoryReviewEventStore();
    expect(store.totalAppended, 0);
    expect(kCompactionThreshold, 500);
  });

  test('probe worker spawn không cần cho analyze — chỉ type', () {
    final probe = <String, dynamic>{'op': 'probe'};
    expect(probe['op'], 'probe');
    // TextPipelineWorker được nhắc qua import — đảm bảo không unused:
    expect(TextPipelineWorker.spawn, isNotNull);
  });
}
