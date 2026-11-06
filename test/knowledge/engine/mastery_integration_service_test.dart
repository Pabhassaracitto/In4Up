import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/knowledge/engine/ema_engine.dart' show MasteryVector;
import 'package:in4up/knowledge/engine/mastery_integration_service.dart';
import 'package:in4up/knowledge/models/evidence_metadata.dart';
import 'package:in4up/knowledge/models/learning_state.dart'
    show LearningState, SkillDimension;
import 'package:in4up/knowledge/models/use_sub_test.dart' show UseSubTestType;
import 'package:in4up/knowledge/visual/mastery_geometry.dart'
    show scatterPosition;

void main() {
  final at = DateTime.utc(2026, 6, 1);
  const evidence = EvidenceMetadata(
    assistance: 0.0, confidence: 1.0, gradedBy: 'local-cloze/v1',
  );

  group('MasteryIntegrationService — event → SM-2 + EMA', () {
    test('integrate input skill: SM-2 + EMA tách biệt', () {
      final state = LearningState.initial(unitId: 'u1', now: at);
      final mastery = MasteryVector.initial;

      final result = MasteryIntegrationService.integrate(
        state: state,
        mastery: mastery,
        dim: SkillDimension.understanding,
        quality: 5, // q=5 → scoreNor=1.0
        evidence: evidence,
        now: at,
      );

      // SM-2: interval thay đổi (q=5 → reps=1, interval=1).
      expect(result.learningState.understanding.repetitions, 1);
      expect(result.learningState.understanding.interval, 1);

      // EMA: mastery tăng (q=5 → scoreNor=1.0, α=0.2, gate=1).
      // mastery = 0 + 0.2*1.0*(1.0-0.0) = 0.2
      expect(result.masteryVector.understanding, closeTo(0.2, 1e-10));

      // SM-2 và EMA KHÔNG ảnh hưởng nhau (tách biệt).
      // EMA không phụ thuộc interval.
      expect(result.masteryVector.understanding,
          closeTo(0.2, 1e-10),
          reason: 'EMA chỉ phụ thuộc scoreNor, không phụ thuộc SM-2 interval');
    });

    test('integrate sai (q=0): SM-2 reset + EMA giảm', () {
      final state = LearningState.initial(unitId: 'u1', now: at);
      final mastery = MasteryVector.initial;

      final result = MasteryIntegrationService.integrate(
        state: state,
        mastery: mastery,
        dim: SkillDimension.understanding,
        quality: 0,
        evidence: evidence,
        now: at,
      );

      // SM-2: fail → reps=0, interval=1.
      expect(result.learningState.understanding.repetitions, 0);
      expect(result.learningState.understanding.interval, 1);

      // EMA: q=0 → scoreNor=0 → mastery giữ 0 (gate=1, nhưng scoreNor=current=0).
      expect(result.masteryVector.understanding, closeTo(0.0, 1e-10));
    });

    test('integrate speak: hasSpeak = true', () {
      final state = LearningState.initial(unitId: 'u1', now: at);
      final mastery = MasteryVector.initial;

      final result = MasteryIntegrationService.integrate(
        state: state,
        mastery: mastery,
        dim: SkillDimension.speak,
        quality: 4,
        evidence: evidence,
        now: at,
      );

      expect(result.masteryVector.hasSpeak, isTrue);
      expect(result.masteryVector.speak, closeTo(0.16, 1e-10),
          reason: 'q=4 → scoreNor=0.8, α=0.2 → 0.16');
    });

    test('integrate use: cần subTest type', () {
      final state = LearningState.initial(unitId: 'u1', now: at);
      final mastery = MasteryVector.initial;

      final result = MasteryIntegrationService.integrate(
        state: state,
        mastery: mastery,
        dim: SkillDimension.use,
        quality: 5,
        evidence: evidence,
        subTest: UseSubTestType.inflection,
        now: at,
      );

      expect(result.masteryVector.hasUseForm, isTrue);
      expect(result.masteryVector.useForm, closeTo(0.2, 1e-10));
    });

    test('integrate use: default subTest = inflection', () {
      final state = LearningState.initial(unitId: 'u1', now: at);
      final mastery = MasteryVector.initial;

      // Không truyền subTest → mặc định inflection.
      final result = MasteryIntegrationService.integrate(
        state: state,
        mastery: mastery,
        dim: SkillDimension.use,
        quality: 5,
        evidence: evidence,
        now: at,
      );

      expect(result.masteryVector.hasUseForm, isTrue);
      expect(result.masteryVector.hasUseSentence, isFalse);
    });

    test('assistance bất đối xứng: đúng → giảm, sai → không giảm', () {
      final state = LearningState.initial(unitId: 'u1', now: at);

      // Đúng + assistance 0.75 → gate = 0.25 → |Δ| = 0.25·α
      final correctEvidence = const EvidenceMetadata(
        assistance: 0.75, confidence: 1.0, gradedBy: 'local/v1',
      );
      final r1 = MasteryIntegrationService.integrate(
        state: state,
        mastery: MasteryVector.initial,
        dim: SkillDimension.understanding,
        quality: 5,
        evidence: correctEvidence,
        now: at,
      );
      expect(r1.masteryVector.understanding, closeTo(0.05, 1e-10),
          reason: 'đúng + assistance 0.75 → gate=0.25 → Δ=0.25·α=0.05');

      // Sai + assistance 0.75 → gate = 1 → |Δ| = α (không giảm)
      final r2 = MasteryIntegrationService.integrate(
        state: state,
        mastery: MasteryVector.initial,
        dim: SkillDimension.understanding,
        quality: 0,
        evidence: correctEvidence,
        now: at,
      );
      expect(r2.masteryVector.understanding, closeTo(0.0, 1e-10),
          reason: 'sai + scoreNor=0 + current=0 → Δ=0 (gate=1 nhưng scoreNor=current)');
    });

    test('integrateBatch: nhiều event', () {
      final count = 5;
      final states = List.generate(count, (i) =>
          LearningState.initial(unitId: 'u$i', now: at));
      final masteries = List.generate(count, (_) => MasteryVector.initial);
      final dims = List.generate(count, (_) => SkillDimension.understanding);
      final qualities = List.generate(count, (i) => (i % 3) + 3); // 3,4,5,3,4
      final evidences = List.generate(count, (_) => evidence);

      final results = MasteryIntegrationService.integrateBatch(
        states: states,
        masteries: masteries,
        dims: dims,
        qualities: qualities,
        evidences: evidences,
        now: at,
      );

      expect(results, hasLength(count));
      // Mỗi result có state + mastery khác nhau (quality khác nhau).
      for (var i = 0; i < count; i++) {
        final scoreNor = qualities[i] / 5.0;
        expect(results[i].masteryVector.understanding,
            closeTo(0.2 * scoreNor, 1e-10));
      }
    });
  });

  group('Performance — 1000 từ ≤60ms (DoD P4)', () {
    test('integrateBatch 1000 từ < 60ms', () {
      final count = 1000;
      final states = List.generate(count, (i) =>
          LearningState.initial(unitId: 'u$i', now: at));
      final masteries = List.generate(count, (_) => MasteryVector.initial);
      final dims = List.generate(count, (_) => SkillDimension.understanding);
      final qualities = List.generate(count, (i) => (i % 6));
      final evidences = List.generate(count, (_) => evidence);

      final start = DateTime.now();
      final results = MasteryIntegrationService.integrateBatch(
        states: states,
        masteries: masteries,
        dims: dims,
        qualities: qualities,
        evidences: evidences,
        now: at,
      );
      final elapsed = DateTime.now().difference(start);

      expect(results, hasLength(count));
      // Pure Dart functions are fast — should be well under 60ms.
      // The DoD is ≤60ms for 1000 words.
      expect(elapsed.inMilliseconds, lessThanOrEqualTo(60),
          reason: '1000 từ integrateBatch ≤ 60ms (actual: ${elapsed.inMilliseconds}ms)');
    });

    test('scatterPosition 1000 từ < 60ms', () {
      final count = 1000;
      final masteryMaps = List.generate(count, (i) => <SkillDimension, double?>{
        SkillDimension.understanding: (i % 5) / 5.0,
        SkillDimension.listening: (i % 4) / 4.0,
        SkillDimension.reading: (i % 3) / 3.0,
        SkillDimension.use: (i % 2) / 2.0,
        SkillDimension.speak: (i % 3) / 3.0,
        SkillDimension.write: (i % 4) / 4.0,
      });

      final start = DateTime.now();
      for (final m in masteryMaps) {
        scatterPosition(
          origin: Offset(0, 0), scale: 100.0, masteryMap: m,
        );
      }
      final elapsed = DateTime.now().difference(start);

      expect(elapsed.inMilliseconds, lessThanOrEqualTo(60),
          reason: '1000 scatterPosition ≤ 60ms (actual: ${elapsed.inMilliseconds}ms)');
    });
  });
}
