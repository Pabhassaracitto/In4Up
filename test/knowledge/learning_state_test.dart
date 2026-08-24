import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/knowledge/models/learning_state.dart';

void main() {
  group('LearningState — schema mục 2.3', () {
    test('SM2Snapshot.initial: EF 2.5, interval 0, reps 0, algorithmVersion bắt buộc', () {
      final s = SM2Snapshot.initial(now: DateTime.utc(2026, 1, 1));

      expect(s.easeFactor, 2.5);
      expect(s.interval, 0);
      expect(s.repetitions, 0);
      expect(s.lastReviewedAt, isNull);
      expect(s.algorithmVersion, kSm2AlgorithmVersion);
      expect(s.algorithmVersion, isNotEmpty,
          reason: 'mục 2.3: algorithmVersion là bắt buộc');
    });

    test(
        'VÙNG CẤM MỤC 0: 3 skill TÁCH BIỆT — đổi listening không đổi understanding/reading',
        () {
      final state =
          LearningState.initial(unitId: 'u1', now: DateTime.utc(2026, 1, 1));

      final newListen = SM2Snapshot(
        easeFactor: 2.3,
        interval: 6,
        repetitions: 2,
        dueDate: DateTime.utc(2026, 1, 7),
        lastReviewedAt: DateTime.utc(2026, 1, 1),
      );

      final updated = state.withSkill(
        SkillDimension.listening,
        newListen,
        lastReviewEventId: 'ev-42',
      );

      expect(updated.listening, equals(newListen));
      expect(updated.understanding, equals(state.understanding));
      expect(updated.reading, equals(state.reading));
      expect(updated.lastReviewEventId, 'ev-42');

      // Không có hàm nào gộp 3 skill thành 1 — chỉ thay từng skill một.
      expect(updated.skill(SkillDimension.understanding),
          equals(state.skill(SkillDimension.understanding)));
    });

    test('skill() truy vấn đúng chiều kỹ năng', () {
      final state = LearningState.initial(unitId: 'u1');
      expect(state.skill(SkillDimension.understanding), equals(state.understanding));
      expect(state.skill(SkillDimension.listening), equals(state.listening));
      expect(state.skill(SkillDimension.reading), equals(state.reading));
    });

    test('JSON round-trip đầy đủ (3 skill + lastReviewEventId)', () {
      final state = LearningState.initial(unitId: 'u1', now: DateTime.utc(2026, 1, 1));
      final evolved = state
          .withSkill(
            SkillDimension.reading,
            SM2Snapshot(
              easeFactor: 2.6,
              interval: 10,
              repetitions: 3,
              dueDate: DateTime.utc(2026, 1, 20),
              lastReviewedAt: DateTime.utc(2026, 1, 10),
            ),
            lastReviewEventId: 'ev-7',
          )
          .withSkill(
            SkillDimension.understanding,
            SM2Snapshot(
              easeFactor: 2.4,
              interval: 3,
              repetitions: 1,
              dueDate: DateTime.utc(2026, 1, 6),
              lastReviewedAt: DateTime.utc(2026, 1, 3),
            ),
            lastReviewEventId: 'ev-8',
          );

      final clone = LearningState.fromJson(evolved.toJson());

      expect(clone.toJson(), equals(evolved.toJson()));
      expect(clone, equals(evolved));
    });
  });
}
