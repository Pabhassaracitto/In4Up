// Test Task 7 — DoD (mục 8 bàn giao):
//   "Cho 1 bộ dữ liệu test, ranking output đúng thứ tự kỳ vọng thủ công"
// + lý do cụ thể (mục 5) + không mơ hồ "AI đề xuất" (glossary mục 1).

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/knowledge/attention/attention_score.dart';
import 'package:in4up/knowledge/models/learning_state.dart';
import 'package:in4up/knowledge/text/text_pipeline_worker.dart';

SM2Snapshot _snap({
  int interval = 30,
  int repetitions = 5,
  required DateTime due,
}) {
  return SM2Snapshot(
    easeFactor: 2.5,
    interval: interval,
    repetitions: repetitions,
    dueDate: due,
  );
}

LearningState _state({
  int interval = 30,
  int repetitions = 5,
  required DateTime due,
}) {
  return LearningState(
    unitId: 'u',
    understanding: _snap(interval: interval, repetitions: repetitions, due: due),
    listening: _snap(interval: interval, repetitions: repetitions, due: due),
    reading: _snap(interval: interval, repetitions: repetitions, due: due),
  );
}

void main() {
  final now = DateTime.utc(2026, 8, 20, 12);

  group('AttentionScore — công thức mục 5 (tính tay)', () {
    test('unit chưa promote: w1 + w3 + w4 (không có w2)', () {
      final r = AttentionRanker.score(
        AttentionInput(
          unitId: 'u-observed',
          goalSkill: SkillDimension.listening,
          appearsInCurrentSource: true,
          recentInteractionCount: 3,
        ),
        now: now,
      );
      // 0.4*1 + 0 + 0.2*1 + 0.1*(3/5) = 0.66
      expect(r.score, closeTo(0.66, 1e-9));
      expect(r.breakdown['w1_weak'], closeTo(0.4, 1e-9));
      expect(r.breakdown['w3_appears'], closeTo(0.2, 1e-9));
      expect(r.breakdown['w4_recent'], closeTo(0.06, 1e-9));
    });

    test('unit vững + không due + không xuất hiện: 0 điểm, lý do "không tiêu chí"',
        () {
      final r = AttentionRanker.score(
        AttentionInput(
          unitId: 'u-solid',
          state: _state(due: now.add(const Duration(days: 10))),
          goalSkill: SkillDimension.listening,
        ),
        now: now,
      );
      expect(r.score, 0.0);
      expect(r.reason, 'Không có tiêu chí nào bắn.');
    });

    test('yếu ở goal skill + đúng hạn + xuất hiện: 0.4+0.3+0.2 = 0.9', () {
      final r = AttentionRanker.score(
        AttentionInput(
          unitId: 'u-weak-due',
          state: _state(
            interval: 2,
            repetitions: 1,
            due: now,
          ),
          goalSkill: SkillDimension.listening,
          appearsInCurrentSource: true,
        ),
        now: now,
      );
      expect(r.score, closeTo(0.9, 1e-9));
      expect(r.reason, contains('nghe từ này chưa vững'));
      expect(r.reason, contains('đã đến hạn ôn tập'));
      expect(r.reason, contains('vừa xuất hiện trong bài đang mở'));
    });

    test('overdue tăng hệ số theo ngày, chặn ×1.5', () {
      final late5 = AttentionRanker.score(
        AttentionInput(
          unitId: 'u-late-5',
          state: _state(due: now.subtract(const Duration(days: 5))),
        ),
        now: now,
      );
      // w2 * (1 + 5*0.1) = 0.3 * 1.5
      expect(late5.score, closeTo(0.45, 1e-9));
      expect(late5.reason, contains('trễ 5 ngày'));

      final late40 = AttentionRanker.score(
        AttentionInput(
          unitId: 'u-late-40',
          state: _state(due: now.subtract(const Duration(days: 40))),
        ),
        now: now,
      );
      expect(late40.score, closeTo(0.45, 1e-9),
          reason: 'boost chặn ở 1.5 — trễ lâu hơn không vượt');

      final late2 = AttentionRanker.score(
        AttentionInput(
          unitId: 'u-late-2',
          state: _state(due: now.subtract(const Duration(days: 2))),
        ),
        now: now,
      );
      expect(late2.score, closeTo(0.36, 1e-9)); // 0.3 * 1.2
      expect(late2.score, lessThan(late5.score),
          reason: 'trễ nhiều hơn ⇒ điểm cao hơn');
    });

    test('goal skill lật kết quả w1 (hiểu vs nghe)', () {
      // weak ở listening (interval 2) nhưng understanding vững.
      final state = LearningState(
        unitId: 'u',
        understanding: _snap(due: now.add(const Duration(days: 30))),
        listening: _snap(interval: 2, repetitions: 1, due: now.add(const Duration(days: 30))),
        reading: _snap(due: now.add(const Duration(days: 30))),
      );
      final asListen = AttentionRanker.score(
        AttentionInput(unitId: 'u', state: state, goalSkill: SkillDimension.listening),
        now: now,
      );
      final asUnderstand = AttentionRanker.score(
        AttentionInput(unitId: 'u', state: state, goalSkill: SkillDimension.understanding),
        now: now,
      );
      expect(asListen.breakdown['w1_weak'], closeTo(0.4, 1e-9));
      expect(asUnderstand.breakdown['w1_weak'], 0.0);
      expect(asListen.reason, contains('nghe từ này chưa vững'));
    });

    test('tương tác gần đây bão hòa tại kRecentInteractionCap', () {
      final five = AttentionRanker.score(
        const AttentionInput(unitId: 'u', recentInteractionCount: 5),
        now: now,
      );
      final fifty = AttentionRanker.score(
        const AttentionInput(unitId: 'u', recentInteractionCount: 50),
        now: now,
      );
      expect(fifty.score, closeTo(five.score, 1e-9));
      expect(five.breakdown['w4_recent'], closeTo(0.1, 1e-9));
    });

    test('lý do KHÔNG chứa từ mơ hồ "AI đề xuất" (glossary mục 1)', () {
      final r = AttentionRanker.score(
        AttentionInput(
          unitId: 'u',
          state: _state(interval: 1, repetitions: 0, due: now),
          goalSkill: SkillDimension.reading,
          appearsInCurrentSource: true,
          recentInteractionCount: 2,
        ),
        now: now,
      );
      expect(r.reason, startsWith('Gợi ý vì'));
      expect(r.reason, contains('đọc từ này chưa vững'));
      expect(r.reason, contains('tương tác 2 lần'));
      expect(r.reason.contains('AI đề xuất'), isFalse);
      expect(r.reason.contains('AI suggest'), isFalse);
    });
  });

  group('AttentionRanker.rank — DoD: đúng thứ tự kỳ vọng thủ công', () {
    test('bộ dữ liệu 5 unit — thứ tự C > A > D = E (tie→unitId) > B', () {
      final ranked = AttentionRanker.rank(
        [
          // A: chưa promote + appears + 3 tương tác = 0.4+0.2+0.06 = 0.66
          const AttentionInput(
            unitId: 'u-A',
            goalSkill: SkillDimension.listening,
            appearsInCurrentSource: true,
            recentInteractionCount: 3,
          ),
          // B: vững, chưa due = 0.0
          AttentionInput(
            unitId: 'u-B',
            state: _state(due: now.add(const Duration(days: 10))),
            goalSkill: SkillDimension.listening,
          ),
          // C: yếu + đúng hạn + appears = 0.9
          AttentionInput(
            unitId: 'u-C',
            state: _state(interval: 2, repetitions: 1, due: now),
            goalSkill: SkillDimension.listening,
            appearsInCurrentSource: true,
          ),
          // D: trễ 5 ngày = 0.45
          AttentionInput(
            unitId: 'u-D',
            state: _state(due: now.subtract(const Duration(days: 5))),
          ),
          // E: trễ 40 ngày = 0.45 (chặn) — tie với D, unitId sau D
          AttentionInput(
            unitId: 'u-E',
            state: _state(due: now.subtract(const Duration(days: 40))),
          ),
        ],
        now: now,
      );

      expect(
        ranked.map((r) => r.unitId).toList(),
        ['u-C', 'u-A', 'u-D', 'u-E', 'u-B'],
      );
      expect(ranked.first.score, closeTo(0.9, 1e-9));
      expect(ranked.last.score, 0.0);
    });

    test('rỗng ⇒ danh sách rỗng; deterministic qua các lần gọi', () {
      expect(AttentionRanker.rank(const [], now: now), isEmpty);
      final inputs = [
        AttentionInput(
          unitId: 'u-X',
          state: _state(due: now.subtract(const Duration(days: 3))),
        ),
        const AttentionInput(unitId: 'u-Y', recentInteractionCount: 4),
      ];
      final a = AttentionRanker.rank(inputs, now: now);
      final b = AttentionRanker.rank(inputs, now: now);
      expect(
        [for (final r in b) r.toJson()],
        equals([for (final r in a) r.toJson()]),
      );
    });
  });

  group('JSON + worker isolate (mục 4)', () {
    test('AttentionInput/Result round-trip', () {
      final input = AttentionInput(
        unitId: 'u1',
        state: _state(interval: 3, repetitions: 1, due: now),
        goalSkill: SkillDimension.listening,
        appearsInCurrentSource: true,
        recentInteractionCount: 2,
      );
      final clone = AttentionInput.fromJson(input.toJson());
      expect(clone.toJson(), equals(input.toJson()));

      final result = AttentionRanker.score(input, now: now);
      final resultClone = AttentionResult.fromJson(result.toJson());
      expect(resultClone.toJson(), equals(result.toJson()));
    });

    test('rank trong worker isolate == in-process', () async {
      final worker = await TextPipelineWorker.spawn()
          .timeout(const Duration(seconds: 10));
      try {
        final inputs = [
          const AttentionInput(
            unitId: 'u-A',
            goalSkill: SkillDimension.listening,
            appearsInCurrentSource: true,
            recentInteractionCount: 3,
          ),
          AttentionInput(
            unitId: 'u-B',
            state: _state(due: now.subtract(const Duration(days: 5))),
          ),
          AttentionInput(
            unitId: 'u-C',
            state: _state(interval: 2, repetitions: 1, due: now),
            goalSkill: SkillDimension.reading,
            appearsInCurrentSource: true,
          ),
        ];
        final inProcess = AttentionRanker.rank(inputs, now: now);
        final viaWorker = await worker
            .rankAttention(inputs, now: now)
            .timeout(const Duration(seconds: 10));
        expect(
          [for (final r in viaWorker) r.toJson()],
          equals([for (final r in inProcess) r.toJson()]),
        );
      } finally {
        worker.dispose();
      }
    });
  });
}
