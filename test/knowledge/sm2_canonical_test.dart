// Test cho hàm SM-2 DUY NHẤT (lib/models/sm2_algorithm.dart) — Task 2 / ADR-0001.
//
// Đặt tại test/knowledge/ (thay vì test/models/) để nằm trong paths-filter
// của workflow CI hiện tại (.github/workflows/knowledge_tests.yml) — mọi
// push chạm SM-2 đều được kiểm tự động.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/knowledge/models/learning_state.dart'
    show kSm2AlgorithmVersion;
import 'package:in4up/models/sm2_algorithm.dart';
import 'package:in4up/models/word_entry.dart';

void main() {
  group('SM2Algorithm — hàm duy nhất, ngữ nghĩa Bản 2 (ADR-0001 / Task 2)', () {
    test('nhịp interval chuẩn: 1 → 6 → interval × EF', () {
      final r1 = SM2Algorithm.calculate(
          quality: 4, currentEF: 2.5, currentInterval: 0, currentReps: 0);
      expect(r1.interval, 1);
      expect(r1.repetitions, 1);

      final r2 = SM2Algorithm.calculate(
          quality: 4, currentEF: 2.5, currentInterval: 1, currentReps: 1);
      expect(r2.interval, 6);
      expect(r2.repetitions, 2);

      final r3 = SM2Algorithm.calculate(
          quality: 4, currentEF: 2.5, currentInterval: 6, currentReps: 2);
      expect(r3.interval, 15); // 6 × 2.5
      expect(r3.repetitions, 3);
    });

    test('fail (q<3): reset reps=0, interval=1, EF giảm theo CÔNG THỨC CHUẨN', () {
      final r = SM2Algorithm.calculate(
          quality: 0, currentEF: 2.5, currentInterval: 30, currentReps: 5);
      expect(r.repetitions, 0);
      expect(r.interval, 1);
      // EF: 2.5 + (0.1 − 5×0.18) = 2.5 − 0.8 = 1.7 (không phải trừ phẳng −0.2)
      expect(r.easeFactor, closeTo(1.7, 0.0001));
    });

    test('EF luôn trong [1.3, 2.5] dù fail liên tục', () {
      var ef = 1.4;
      for (var i = 0; i < 20; i++) {
        ef = SM2Algorithm.calculate(
                quality: 0, currentEF: ef, currentInterval: 1, currentReps: 0)
            .easeFactor;
      }
      expect(ef, greaterThanOrEqualTo(1.3));
      expect(ef, lessThanOrEqualTo(2.5));
    });

    test('KHÔNG còn thưởng/phạt interval bản cũ (×1.3 Easy / ×0.8 Hard)', () {
      // Easy q=5, EF 2.5, interval 10, reps 3 → đúng 25 (bản cũ sẽ ra 32).
      final easy = SM2Algorithm.calculate(
          quality: 5, currentEF: 2.5, currentInterval: 10, currentReps: 3);
      expect(easy.interval, 25);

      // Hard q=3 vẫn là pass → interval × EF, KHÔNG giảm 20%.
      final hard = SM2Algorithm.calculate(
          quality: 3, currentEF: 2.5, currentInterval: 10, currentReps: 3);
      expect(hard.interval, 25);
    });

    test('nextReview = now + interval ngày (tiêm được now cho test/compaction)', () {
      final t0 = DateTime.utc(2026, 8, 20, 8);
      final r = SM2Algorithm.calculate(
          quality: 4, currentEF: 2.5, currentInterval: 1, currentReps: 1, now: t0);
      expect(r.nextReview, t0.add(const Duration(days: 6)));
    });

    test('algorithmVersion phát hành từ hàm duy nhất = sm2-srd-v1', () {
      expect(kSm2AlgorithmVersion, 'sm2-srd-v1');
    });

    test(
        'TƯƠNG ĐƯƠNG: SkillReviewData.review() ≡ SM2Algorithm.calculate() '
        'trên lưới 384 tổ hợp đầu vào (không đổi due date dữ liệu cũ)',
        () {
      for (final q in [0, 1, 2, 3, 4, 5]) {
        for (final ef in [1.3, 1.7, 2.18, 2.5]) {
          for (final iv in [0, 1, 6, 30]) {
            for (final reps in [0, 1, 2, 5]) {
              final expected = SM2Algorithm.calculate(
                quality: q,
                currentEF: ef,
                currentInterval: iv,
                currentReps: reps,
              );
              final data = SkillReviewData(
                easeFactor: ef,
                interval: iv,
                repetitions: reps,
              );

              data.review(q);

              final tag = 'q=$q ef=$ef iv=$iv reps=$reps';
              expect(data.easeFactor, closeTo(expected.easeFactor, 0.0001),
                  reason: 'EF lệch tại $tag');
              expect(data.interval, expected.interval,
                  reason: 'interval lệch tại $tag');
              expect(data.repetitions, expected.repetitions,
                  reason: 'repetitions lệch tại $tag');
            }
          }
        }
      }
    });
  });
}
