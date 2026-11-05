import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/knowledge/engine/session_bundler.dart';
import 'package:in4up/knowledge/models/learning_state.dart'
    show LearningState, SM2Snapshot, SkillDimension;

void main() {
  const now = DateTime.utc(2026, 6, 1);

  group('Session Bundler — ADR-0020', () {
    final future = now.add(const Duration(days: 30));

    test('bundle: gom skill đến hạn cùng từ thành 1 thẻ', () {
      // Unit A: understanding + listening due, rest not due.
      // initial(now: future) → mọi skill dueDate = future (không due).
      // Override 2 skill → dueDate = now (due).
      final a = LearningState.initial(unitId: 'a', now: future)
          .withSkill(
            SkillDimension.understanding,
            SM2Snapshot(
              easeFactor: 2.5, interval: 0, repetitions: 0, dueDate: now,
            ),
            lastReviewEventId: 'ev-a1',
          )
          .withSkill(
            SkillDimension.listening,
            SM2Snapshot(
              easeFactor: 2.5, interval: 0, repetitions: 0, dueDate: now,
            ),
            lastReviewEventId: 'ev-a2',
          );

      // Unit B: initial(now: now) → mọi skill dueDate = now (due).
      final b = LearningState.initial(unitId: 'b', now: now);

      final cards = SessionBundler.bundle(states: [a, b], now: now);

      // Unit A có 2 skill due → 1 thẻ.
      expect(cards.any((c) => c.unitId == 'a'), isTrue);
      final cardA = cards.firstWhere((c) => c.unitId == 'a');
      expect(cardA.dueCount, 2);
      expect(cardA.dueSkills, containsAll([
        SkillDimension.understanding, SkillDimension.listening,
      ]));
      expect(cardA.dueSkills, isNot(contains(SkillDimension.reading)));

      // Unit B — initial → all due → 1 thẻ.
      expect(cards.any((c) => c.unitId == 'b'), isTrue);
    });

    test('bundle: unit không có skill due → không có thẻ', () {
      // initial(now: future) → mọi skill dueDate = future > now → không due.
      final a = LearningState.initial(unitId: 'a', now: future);

      final cards = SessionBundler.bundle(states: [a], now: now);
      expect(cards, isEmpty);
    });

    test('bundle: xét đủ 6 trục (input + output)', () {
      // Only use + speak due; input + write not due.
      final a = LearningState.initial(unitId: 'a', now: future)
          .withSkill(
            SkillDimension.use,
            SM2Snapshot(
              easeFactor: 2.5, interval: 0, repetitions: 0, dueDate: now,
            ),
            lastReviewEventId: 'ev-a1',
          )
          .withSkill(
            SkillDimension.speak,
            SM2Snapshot(
              easeFactor: 2.5, interval: 0, repetitions: 0, dueDate: now,
            ),
            lastReviewEventId: 'ev-a2',
          );

      final cards = SessionBundler.bundle(states: [a], now: now);
      expect(cards, hasLength(1));
      expect(cards.first.dueCount, 2);
      expect(cards.first.dueSkills, containsAll([
        SkillDimension.use, SkillDimension.speak,
      ]));
      // Input skills không due.
      expect(cards.first.dueSkills, isNot(contains(SkillDimension.understanding)));
    });

    test('meetsBundlingDod: bundle ≤ baseline (+20%)', () {
      // Baseline: 3 skill due riêng → 3 thẻ. Bundle: 1 từ → 1 thẻ.
      final cards = const [
        SessionCard(unitId: 'a', dueSkills: [
          SkillDimension.understanding,
          SkillDimension.listening,
          SkillDimension.reading,
        ]),
      ];
      expect(SessionBundler.meetsBundlingDod(
        cards: cards, totalDueSkills: 3,
      ), isTrue, reason: 'bundle 1 thẻ ≤ baseline 3 thẻ');
    });

    test('meetsBundlingDod: không skill due → true', () {
      expect(SessionBundler.meetsBundlingDod(
        cards: const [], totalDueSkills: 0,
      ), isTrue);
    });

    test('bundle: 0 state → 0 card', () {
      expect(SessionBundler.bundle(states: [], now: now), isEmpty);
    });
  });
}
