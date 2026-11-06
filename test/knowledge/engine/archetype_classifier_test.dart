import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/knowledge/engine/archetype_classifier.dart';
import 'package:in4up/knowledge/engine/ema_engine.dart' show MasteryVector;
import 'package:in4up/knowledge/models/evidence_metadata.dart';
import 'package:in4up/knowledge/models/learning_state.dart' show SkillDimension;
import 'package:in4up/knowledge/models/use_sub_test.dart' show UseSubTestType;

void main() {
  const evidence = EvidenceMetadata(
    assistance: 0.0, confidence: 1.0, gradedBy: 'local/v1',
  );

  /// Build MV: mỗi skill update [iterations] lần → EMA hội tụ về scoreNor.
  /// scoreNor=1.0 → ~0.99 (cao); 0.0 → 0.0 (thấp); 0.6 → ~0.54 (trung bình).
  MasteryVector buildMV({
    double? understanding,
    double? listening,
    double? reading,
    double? speak,
    double? write,
    double? useForm,
    double? useSentence,
    int iterations = 10,
  }) {
    var mv = MasteryVector.initial;
    for (var i = 0; i < iterations; i++) {
      if (understanding != null) {
        mv = mv.update(
          dim: SkillDimension.understanding, scoreNor: understanding, evidence: evidence,
        );
      }
      if (listening != null) {
        mv = mv.update(
          dim: SkillDimension.listening, scoreNor: listening, evidence: evidence,
        );
      }
      if (reading != null) {
        mv = mv.update(
          dim: SkillDimension.reading, scoreNor: reading, evidence: evidence,
        );
      }
      if (speak != null) {
        mv = mv.update(
          dim: SkillDimension.speak, scoreNor: speak, evidence: evidence,
        );
      }
      if (write != null) {
        mv = mv.update(
          dim: SkillDimension.write, scoreNor: write, evidence: evidence,
        );
      }
      if (useForm != null) {
        mv = mv.updateUse(
          subTest: UseSubTestType.inflection, scoreNor: useForm, evidence: evidence,
        );
      }
      if (useSentence != null) {
        mv = mv.updateUse(
          subTest: UseSubTestType.clozeSentence, scoreNor: useSentence, evidence: evidence,
        );
      }
    }
    return mv;
  }

  group('Archetype classifier — ADR-0019', () {
    final classifier = const ArchetypeClassifier();

    test('blindSpot: không evidence', () {
      expect(classifier.classify(MasteryVector.initial), Archetype.blindSpot);
    });

    test('blindSpot: mọi skill thấp', () {
      final mv = buildMV(
        understanding: 0.0, listening: 0.0, reading: 0.0,
        speak: 0.0, write: 0.0, useForm: 0.0, useSentence: 0.0,
      );
      expect(classifier.classify(mv), Archetype.blindSpot);
    });

    test('passiveListener: chỉ listening cao', () {
      final mv = buildMV(
        listening: 1.0,
        understanding: 0.0, reading: 0.0,
      );
      expect(classifier.classify(mv), Archetype.passiveListener);
    });

    test('textReader: chỉ reading cao', () {
      final mv = buildMV(
        reading: 1.0,
        understanding: 0.0, listening: 0.0,
      );
      expect(classifier.classify(mv), Archetype.textReader);
    });

    test('receptiveHoarder: input cao, không output', () {
      final mv = buildMV(
        understanding: 1.0, listening: 1.0, reading: 1.0,
      );
      expect(classifier.classify(mv), Archetype.receptiveHoarder);
    });

    test('imitativeSpeaker: chỉ speak cao, input thấp', () {
      final mv = buildMV(
        speak: 1.0,
        understanding: 0.0, listening: 0.0, reading: 0.0,
      );
      expect(classifier.classify(mv), Archetype.imitativeSpeaker);
    });

    test('productiveAsymmetric: speak + write cao, input thấp', () {
      final mv = buildMV(
        speak: 1.0, write: 1.0,
        understanding: 0.0, listening: 0.0, reading: 0.0,
      );
      expect(classifier.classify(mv), Archetype.productiveAsymmetric);
    });

    test('fullMastery: input + output đều cao', () {
      final mv = buildMV(
        understanding: 1.0, listening: 1.0, reading: 1.0,
        speak: 1.0, write: 1.0, useForm: 1.0, useSentence: 1.0,
      );
      expect(classifier.classify(mv), Archetype.fullMastery);
    });

    test('functionalBalanced: cả input+output ở mức trung bình', () {
      final mv = buildMV(
        understanding: 0.6, listening: 0.6, reading: 0.6,
        speak: 0.6, write: 0.6, useForm: 0.6, useSentence: 0.6,
      );
      expect(classifier.classify(mv), Archetype.functionalBalanced);
    });

    test('Gate: không output evidence → không lên fullMastery', () {
      final mv = buildMV(
        understanding: 1.0, listening: 1.0, reading: 1.0,
      );
      final arch = classifier.classify(mv);
      expect(arch, isNot(Archetype.fullMastery));
      expect(arch, Archetype.receptiveHoarder);
    });

    test('Archetype label — 8 label không rỗng', () {
      for (final a in Archetype.values) {
        expect(a.label.isNotEmpty, isTrue, reason: '$a có label');
      }
      expect(Archetype.values.length, 8);
    });
  });
}
