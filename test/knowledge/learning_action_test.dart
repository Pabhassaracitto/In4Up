import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/knowledge/models/learning_action.dart';

void main() {
  group('LearningAction — schema mục 2.5 (tín hiệu hành vi, KHÔNG phải mastery)',
      () {
    test('JSON round-trip toàn bộ 8 loại hành vi', () {
      for (final type in LearningActionType.values) {
        final a = LearningAction(
          actionType: type,
          unitId: 'u1',
          evidenceId: 'ev-1',
          timestamp: DateTime.utc(2026, 1, 1, 9),
          sessionId: 'session-7',
        );
        final clone = LearningAction.fromJson(a.toJson());
        expect(clone.toJson(), equals(a.toJson()),
            reason: 'round-trip thất bại tại ${type.name}');
      }
    });

    test('unitId/evidenceId nullable — hành vi không gắn unit cụ thể vẫn hợp lệ', () {
      final a = LearningAction(
        actionType: LearningActionType.skipped,
        timestamp: DateTime.utc(2026, 1, 1, 9),
        sessionId: 'session-7',
      );

      final clone = LearningAction.fromJson(a.toJson());
      expect(clone.unitId, isNull);
      expect(clone.evidenceId, isNull);
      expect(clone.actionType, LearningActionType.skipped);
    });

    test('fromJson với actionType lạ ⇒ FormatException', () {
      final json = <String, dynamic>{
        'actionType': 'teleported',
        'timestamp': DateTime.utc(2026, 1, 1).toIso8601String(),
        'sessionId': 's',
      };
      expect(() => LearningAction.fromJson(json), throwsFormatException);
    });
  });
}
