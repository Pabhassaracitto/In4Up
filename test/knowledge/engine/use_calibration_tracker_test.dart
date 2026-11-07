import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/knowledge/engine/ema_engine.dart' show MasteryVector;
import 'package:in4up/knowledge/engine/use_calibration_tracker.dart';
import 'package:in4up/knowledge/models/evidence_metadata.dart';
import 'package:in4up/knowledge/models/learning_state.dart'
    show LearningState, SkillDimension;

void main() {
  final at = DateTime.utc(2026, 6, 1);
  const evidence = EvidenceMetadata(
    assistance: 0.0, confidence: 1.0, gradedBy: 'local-cloze/v1',
  );

  group('UseCalibrationTracker', () {
    test('record: ghi nhận sample', () {
      final tracker = UseCalibrationTracker();
      final mv = MasteryVector.initial.update(
        dim: SkillDimension.understanding,
        scoreNor: 1.0,
        evidence: evidence,
      );
      tracker.record(mv, at);

      expect(tracker.count, 1);
      expect(tracker.samples.first.useForm, 0.0);
      expect(tracker.samples.first.useDisplay, 0.0);
    });

    test('hasTwoWeeksCalibration: < 14 ngày → false', () {
      final tracker = UseCalibrationTracker();
      final mv = MasteryVector.initial;
      tracker.record(mv, at);

      expect(tracker.hasTwoWeeksCalibration(at), isFalse);
    });

    test('hasTwoWeeksCalibration: >= 14 ngày → true', () {
      final tracker = UseCalibrationTracker();
      final mv = MasteryVector.initial;
      final later = at.add(const Duration(days: 14));
      tracker.record(mv, later);

      expect(tracker.hasTwoWeeksCalibration(at), isTrue);
    });

    test('suggestAlpha: dữ liệu mỏng → giữ default', () {
      final tracker = UseCalibrationTracker();
      for (var i = 0; i < 5; i++) {
        tracker.record(MasteryVector.initial, at.add(Duration(days: i)));
      }
      expect(tracker.suggestAlpha(defaultAlpha: 0.2), 0.2);
    });

    test('isReadyForLevelAnnouncement: cần 14 ngày + 20 sample', () {
      final tracker = UseCalibrationTracker();
      for (var i = 0; i < 19; i++) {
        tracker.record(MasteryVector.initial, at.add(Duration(days: i)));
      }
      // 19 sample < 20 → không ready.
      expect(tracker.isReadyForLevelAnnouncement(since: at), isFalse);

      // Thêm 1 sample ở 14 ngày sau.
      tracker.record(MasteryVector.initial, at.add(const Duration(days: 14)));
      expect(tracker.isReadyForLevelAnnouncement(since: at), isTrue);
    });

    test('reset: xóa tất cả sample', () {
      final tracker = UseCalibrationTracker();
      tracker.record(MasteryVector.initial, at);
      tracker.record(MasteryVector.initial, at);
      expect(tracker.count, 2);

      tracker.reset();
      expect(tracker.count, 0);
    });
  });

  group('HexagonRollbackFlag', () {
    test('on/off', () {
      expect(HexagonRollbackFlag.on(), HexagonFlagState.on);
      expect(HexagonRollbackFlag.off(), HexagonFlagState.off);
    });

    test('toggle', () {
      expect(HexagonRollbackFlag.toggle(HexagonFlagState.on),
          HexagonFlagState.off);
      expect(HexagonRollbackFlag.toggle(HexagonFlagState.off),
          HexagonFlagState.on);
    });

    test('isRollback: off = rollback', () {
      expect(HexagonRollbackFlag.isRollback(HexagonFlagState.off), isTrue);
      expect(HexagonRollbackFlag.isRollback(HexagonFlagState.on), isFalse);
    });

    test('rollback sẵn sàng: flag tắt → Venn/Triangle chạy', () {
      // Rollback không cần code rollback — chỉ cần tắt flag.
      final state = HexagonRollbackFlag.off();
      expect(HexagonRollbackFlag.isRollback(state), isTrue,
          reason: 'flag tắt → rollback về Venn/Triangle');
    });
  });
}
