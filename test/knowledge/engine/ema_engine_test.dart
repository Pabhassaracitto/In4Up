import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/knowledge/engine/ema_engine.dart';
import 'package:in4up/knowledge/models/evidence_metadata.dart';
import 'package:in4up/knowledge/models/learning_state.dart' show SkillDimension;
import 'package:in4up/knowledge/models/use_sub_test.dart' show UseSubTestType, UseSubTestTypeInfo;

void main() {
  const alpha = 0.2;

  group('EMA patch A′ — ADR-0016 (3 mandatory)', () {
    test('1. clozeChoice đúng, assistance 0.75 → |Δ| ≈ 0.25·α', () {
      // q=5 → scoreNor=1.0, current=0 → Δ = α·confidence·(1-0.75)·(1-0)
      //      = α·1.0·0.25·1.0 = 0.25·α
      final evidence = const EvidenceMetadata(
        assistance: 0.75,
        confidence: 1.0,
        gradedBy: 'local-cloze/v1',
      );
      final result = emaUpdate(
        current: 0.0,
        scoreNor: 1.0,
        assistance: 0.75,
        confidence: 1.0,
        alpha: alpha,
      );
      expect(result, closeTo(alpha * 0.25, 1e-10),
          reason: 'đúng + assistance 0.75 → gate=0.25 → |Δ|=0.25·α');
    });

    test('2. Sai, assistance 0.75 → |Δ| đủ cường độ α (gate=1)', () {
      // q=0 → scoreNor=0.0, current=0.5 → Δ = α·confidence·1.0·(0-0.5)
      // assistance KHÔNG làm giảm (gate=1 cho sai).
      final wrong = emaUpdate(
        current: 0.5,
        scoreNor: 0.0,
        assistance: 0.75,
        confidence: 1.0,
        alpha: alpha,
      );
      final noAssistance = emaUpdate(
        current: 0.5,
        scoreNor: 0.0,
        assistance: 0.0,
        confidence: 1.0,
        alpha: alpha,
      );
      // gate=1 bất kể assistance → 2 kết quả bằng nhau.
      expect(wrong, closeTo(noAssistance, 1e-10),
          reason: 'sai → gate=1, assistance không ảnh hưởng');
      // |Δ| = α·0.5 (cường độ đầy đủ, không bị assistance giảm).
      expect(wrong, closeTo(0.5 - alpha * 0.5, 1e-10));
    });

    test('3. confidence 0.2 → cả 2 chiều gần đứng yên', () {
      final evidence = const EvidenceMetadata(
        assistance: 0.0,
        confidence: 0.2,
        gradedBy: 'local-cloze/v1',
      );
      // Đúng: Δ = α·0.2·1.0·(1-0.5) = 0.02 → gần đứng yên.
      final correct = emaUpdate(
        current: 0.5,
        scoreNor: 1.0,
        assistance: 0.0,
        confidence: 0.2,
        alpha: alpha,
      );
      expect(correct, closeTo(0.52, 1e-10),
          reason: 'confidence 0.2 → đúng cũng gần đứng yên');

      // Sai: Δ = α·0.2·1.0·(0-0.5) = -0.02 → gần đứng yên.
      final wrong = emaUpdate(
        current: 0.5,
        scoreNor: 0.0,
        assistance: 0.0,
        confidence: 0.2,
        alpha: alpha,
      );
      expect(wrong, closeTo(0.48, 1e-10),
          reason: 'confidence 0.2 → sai cũng gần đứng yên');
    });
  });

  group('MasteryVector — 6 trục / 2 nhóm', () {
    test('initial: mọi trục 0.0, không evidence', () {
      final mv = MasteryVector.initial;
      expect(mv.understanding, 0.0);
      expect(mv.listening, 0.0);
      expect(mv.reading, 0.0);
      expect(mv.speak, 0.0);
      expect(mv.write, 0.0);
      expect(mv.useDisplay, 0.0);
      expect(mv.hasOutputEvidence, isFalse);
      expect(mv.hasInputEvidence, isFalse);
    });

    test('update input skill — valueOf đúng trục', () {
      final evidence = const EvidenceMetadata(
        assistance: 0.0, confidence: 1.0, gradedBy: 'local/v1',
      );
      final mv = MasteryVector.initial.update(
        dim: SkillDimension.understanding,
        scoreNor: 1.0,
        evidence: evidence,
      );
      expect(mv.understanding, closeTo(alpha, 1e-10));
      expect(mv.listening, 0.0);
      expect(mv.reading, 0.0);
      expect(mv.valueOf(SkillDimension.understanding), closeTo(alpha, 1e-10));
    });

    test('update speak/write — hasSpeak/hasWrite = true', () {
      final evidence = const EvidenceMetadata(
        assistance: 0.0, confidence: 1.0, gradedBy: 'local/v1',
      );
      final mv = MasteryVector.initial.update(
        dim: SkillDimension.speak,
        scoreNor: 1.0,
        evidence: evidence,
      );
      expect(mv.hasSpeak, isTrue);
      expect(mv.hasWrite, isFalse);
      expect(mv.speak, closeTo(alpha, 1e-10));
    });

    test('use KHÔNG được update() trực tiếp — assert', () {
      final evidence = const EvidenceMetadata(
        assistance: 0.0, confidence: 1.0, gradedBy: 'local/v1',
      );
      expect(() => MasteryVector.initial.update(
        dim: SkillDimension.use,
        scoreNor: 1.0,
        evidence: evidence,
      ), throwsAssertionError);
    });
  });

  group('Mastery con Dùng — ADR-0018 (2 EMA con, không bù 0)', () {
    const evidence = EvidenceMetadata(
      assistance: 0.0, confidence: 1.0, gradedBy: 'local-cloze/v1',
    );

    test('useDisplay = trung bình sub-test có evidence', () {
      // Cả 2 sub-test = 1.0 → useForm = useSentence = α → useDisplay = α
      final mv = MasteryVector.initial
          .updateUse(subTest: UseSubTestType.inflection, scoreNor: 1.0, evidence: evidence)
          .updateUse(subTest: UseSubTestType.clozeSentence, scoreNor: 1.0, evidence: evidence);
      expect(mv.hasUseForm, isTrue);
      expect(mv.hasUseSentence, isTrue);
      expect(mv.useForm, closeTo(alpha, 1e-10));
      expect(mv.useSentence, closeTo(alpha, 1e-10));
      expect(mv.useDisplay, closeTo(alpha, 1e-10),
          reason: 'cả 2 sub-test = 1.0 → useDisplay = α');
      expect(mv.useIsPartial, isFalse);
    });

    test('chỉ 1 sub-test → useIsPartial, KHÔNG bù 0', () {
      // Chỉ form = 1.0 → useDisplay = useForm = α (chỉ 1 part), useIsPartial = true
      final mv = MasteryVector.initial.updateUse(
        subTest: UseSubTestType.inflection,
        scoreNor: 1.0,
        evidence: evidence,
      );
      expect(mv.hasUseForm, isTrue);
      expect(mv.hasUseSentence, isFalse);
      expect(mv.useDisplay, closeTo(alpha, 1e-10),
          reason: 'chỉ form → useDisplay = useForm = α');
      expect(mv.useIsPartial, isTrue,
          reason: 'chỉ 1 sub-test → nhãn "một phần"');
    });

    test('không sub-test nào → useDisplay = 0.0, useIsPartial = false', () {
      final mv = MasteryVector.initial;
      expect(mv.useDisplay, 0.0);
      expect(mv.useIsPartial, isFalse);
      expect(mv.hasUse, isFalse);
    });

    test('sub-test form vs sentence update EMA con riêng', () {
      final mv = MasteryVector.initial
          .updateUse(subTest: UseSubTestType.inflection, scoreNor: 1.0, evidence: evidence)
          .updateUse(subTest: UseSubTestType.clozeSentence, scoreNor: 0.0, evidence: evidence);
      // useForm = α (q=5), useSentence = 0 (q=0, nhưng đã có evidence)
      expect(mv.useForm, closeTo(alpha, 1e-10));
      expect(mv.useSentence, closeTo(0.0, 1e-10));
      expect(mv.hasUseSentence, isTrue);
      // useDisplay = trung bình = (α + 0) / 2
      expect(mv.useDisplay, closeTo(alpha / 2, 1e-10));
    });

    test('collocation/aiSentence — Phase 2, isSentence = true', () {
      expect(UseSubTestType.collocation.isSentence, isTrue);
      expect(UseSubTestType.aiSentence.isSentence, isTrue);
      expect(UseSubTestType.collocation.isForm, isFalse);
      expect(UseSubTestType.inflection.isPhase1, isTrue);
      expect(UseSubTestType.collocation.isPhase1, isFalse);
    });
  });
}
