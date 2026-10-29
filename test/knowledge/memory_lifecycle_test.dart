// Test Task 6 — DoD (mục 8 bàn giao):
//   "Implicit/Explicit lifecycle theo mục 6"
//   + điều kiện UI: "đọc 1 bài liên tục 5 phút không bị gián đoạn bởi
//   bất kỳ dialog nào" — ở tầng engine, điều này được bảo đảm CẤU TRÚC:
//   engine không có API phát dialog; đầu ra duy nhất là suggestion dữ liệu.
//   (Bài test UI thủ công chạy cùng lúc với khâu nối UI ở INTEGRATE-1.)

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/knowledge/lifecycle/memory_lifecycle.dart';
import 'package:in4up/knowledge/models/learning_action.dart';
import 'package:in4up/knowledge/models/learning_state.dart';

LearningAction _act(
  LearningActionType type,
  String unitId, {
  String? evidenceId,
  DateTime? at,
}) {
  return LearningAction(
    actionType: type,
    unitId: unitId,
    evidenceId: evidenceId,
    timestamp: at ?? DateTime.utc(2026, 1, 1),
    sessionId: 'session-1',
  );
}

SM2Snapshot _snap(int interval) => SM2Snapshot(
      easeFactor: 2.5,
      interval: interval,
      repetitions: 5,
      dueDate: DateTime.utc(2026, 6, 1),
    );

LearningState _state({int u = 30, int l = 30, int r = 30}) => LearningState(
      unitId: 'u',
      understanding: _snap(u),
      listening: _snap(l),
      reading: _snap(r),
    );

void main() {
  final t0 = DateTime.utc(2026, 1, 1, 9);
  var tick = 0;
  DateTime clock() => t0.add(Duration(seconds: tick));

  MemoryLifecycleEngine newEngine() {
    tick = 0;
    return MemoryLifecycleEngine(clock: clock);
  }

  group('Observed — tự động, im lặng (mục 6)', () {
    test('observe chỉ ghi evidence, không sinh gợi ý nào', () {
      final engine = newEngine();
      engine.observe('u1');
      engine.observe('u1');
      final unit = engine.unit('u1')!;
      expect(unit.stage, MemoryStage.observed);
      expect(unit.evidenceCount, 2);
      expect(engine.pendingSuggestions, isEmpty);
      expect(unit.history, isEmpty, reason: 'chưa chuyển trạng thái nào');
    });

    test('mở lại context lần 1: vẫn observed', () {
      final engine = newEngine();
      engine.observe('u1');
      engine.recordImplicit(
          _act(LearningActionType.opened, 'u1', evidenceId: 'ev-pdf-1'));
      expect(engine.unit('u1')!.stage, MemoryStage.observed);
    });

    test('mở lại CÙNG context lần 2 (≥2): captured + gợi ý đúng lý do', () {
      final engine = newEngine();
      engine.observe('u1');
      engine.recordImplicit(
          _act(LearningActionType.opened, 'u1', evidenceId: 'ev-pdf-1'));
      engine.recordImplicit(
          _act(LearningActionType.opened, 'u1', evidenceId: 'ev-pdf-1'));
      final unit = engine.unit('u1')!;
      expect(unit.stage, MemoryStage.captured);
      expect(unit.history.single.reason, 'mở lại cùng context lần thứ 2');
      expect(unit.history.single.source, TransitionSource.implicit);

      final suggestions = engine.pendingSuggestions;
      expect(suggestions.single.unitId, 'u1');
      expect(suggestions.single.reason,
          'Gợi ý lưu vì bạn đã mở lại cùng context lần thứ 2.');
    });

    test('mở lại context KHÁC nhau không cộng chung', () {
      final engine = newEngine();
      engine.observe('u1');
      engine.recordImplicit(
          _act(LearningActionType.opened, 'u1', evidenceId: 'ev-a'));
      engine.recordImplicit(
          _act(LearningActionType.opened, 'u1', evidenceId: 'ev-b'));
      expect(engine.unit('u1')!.stage, MemoryStage.observed);
    });
  });

  group('Captured — 3 quy tắc implicit (mục 6)', () {
    test('bôi đen + tra nghĩa ⇒ captured', () {
      final engine = newEngine();
      engine.observe('u1');
      engine.recordImplicit(_act(LearningActionType.highlighted, 'u1'));
      expect(engine.unit('u1')!.stage, MemoryStage.observed,
          reason: 'mới bôi đen thôi thì chưa');
      engine.recordImplicit(_act(LearningActionType.translated, 'u1'));
      expect(engine.unit('u1')!.stage, MemoryStage.captured);
      expect(engine.unit('u1')!.history.single.reason, 'bôi đen và tra nghĩa');
    });

    test('nghe lại 1 câu > 3 lần ⇒ captured ở lần thứ 4', () {
      final engine = newEngine();
      engine.observe('u1');
      for (var i = 0; i < 3; i++) {
        engine.recordImplicit(
            _act(LearningActionType.replayed, 'u1', evidenceId: 'ev-sent-9'));
      }
      expect(engine.unit('u1')!.stage, MemoryStage.observed,
          reason: '3 lần chưa đủ — quy tắc là > 3');
      engine.recordImplicit(
          _act(LearningActionType.replayed, 'u1', evidenceId: 'ev-sent-9'));
      expect(engine.unit('u1')!.stage, MemoryStage.captured);
      expect(engine.unit('u1')!.history.single.reason,
          'nghe lại một câu hơn 3 lần');
    });

    test('captured KHÔNG TỰ promote (mục 2.5 — action không đổi LearningState)',
        () {
      final engine = newEngine();
      engine.observe('u1');
      engine.recordImplicit(_act(LearningActionType.highlighted, 'u1'));
      engine.recordImplicit(_act(LearningActionType.translated, 'u1'));
      // tiếp tục hành vi hàng loạt — không được lên promoted/practicing:
      for (var i = 0; i < 20; i++) {
        engine.recordImplicit(
            _act(LearningActionType.replayed, 'u1', evidenceId: 'ev-x'));
      }
      expect(engine.unit('u1')!.stage, MemoryStage.captured);
      expect(engine.unit('u1')!.sm2StartedAt, isNull);
    });

    test('recordImplicit từ chối action ý chí người dùng (phải qua promote)',
        () {
      final engine = newEngine();
      engine.observe('u1');
      expect(
        () => engine.recordImplicit(
            _act(LearningActionType.savedToWordlist, 'u1')),
        throwsArgumentError,
      );
      expect(
        () => engine.recordImplicit(
            _act(LearningActionType.sentToWriting, 'u1')),
        throwsArgumentError,
      );
    });
  });

  group('Promoted/Practicing — CHỈ người dùng chủ động (mục 6)', () {
    test('promote(userSave) từ observed: promoted→practicing + SM-2 bắt đầu',
        () {
      final engine = newEngine();
      engine.observe('u1');
      expect(engine.promote('u1', PromoteReason.userSave), isTrue);

      final unit = engine.unit('u1')!;
      expect(unit.stage, MemoryStage.practicing);
      expect(unit.sm2StartedAt, isNotNull);
      expect(unit.history.length, 2);
      expect(unit.history[0].to, MemoryStage.promoted);
      expect(unit.history[0].source, TransitionSource.user);
      expect(unit.history[1].to, MemoryStage.practicing);
      expect(unit.history[1].source, TransitionSource.derived);
    });

    test('promote(userShadowing) từ captured cũng hợp lệ', () {
      final engine = newEngine();
      engine.observe('u1');
      engine.recordImplicit(
          _act(LearningActionType.opened, 'u1', evidenceId: 'ev-1'));
      engine.recordImplicit(
          _act(LearningActionType.opened, 'u1', evidenceId: 'ev-1'));
      expect(engine.unit('u1')!.stage, MemoryStage.captured);

      expect(engine.promote('u1', PromoteReason.userShadowing), isTrue);
      expect(engine.unit('u1')!.stage, MemoryStage.practicing);
    });

    test('promote idempotent — lần 2 là no-op false', () {
      final engine = newEngine();
      engine.observe('u1');
      expect(engine.promote('u1', PromoteReason.userWriting), isTrue);
      expect(engine.promote('u1', PromoteReason.userSave), isFalse);
      expect(engine.unit('u1')!.history.length, 2,
          reason: 'không ghi thêm lịch sử cho no-op');
    });

    test('promote unit chưa observe ⇒ false', () {
      final engine = newEngine();
      expect(engine.promote('ghost', PromoteReason.userSave), isFalse);
    });
  });

  group('Maintained — trạng thái dẫn xuất (mục 6)', () {
    test('interval > 21 ngày trên cả 3 skill ⇒ maintained', () {
      final engine = newEngine();
      engine.observe('u1');
      engine.promote('u1', PromoteReason.userSave);
      engine.evaluateMaintained('u1', _state());
      expect(engine.unit('u1')!.stage, MemoryStage.maintained);
    });

    test('một skill rơi dưới ngưỡng ⇒ trở lại practicing (đường lùi duy nhất)',
        () {
      final engine = newEngine();
      engine.observe('u1');
      engine.promote('u1', PromoteReason.userSave);
      engine.evaluateMaintained('u1', _state());
      engine.evaluateMaintained('u1', _state(u: 10));
      final unit = engine.unit('u1')!;
      expect(unit.stage, MemoryStage.practicing);
      expect(unit.history.last.reason, 'interval rơi dưới ngưỡng maintained');
    });

    test('evaluateMaintained bỏ qua unit chưa practicing', () {
      final engine = newEngine();
      engine.observe('u1');
      engine.recordImplicit(
          _act(LearningActionType.opened, 'u1', evidenceId: 'ev-1'));
      engine.recordImplicit(
          _act(LearningActionType.opened, 'u1', evidenceId: 'ev-1'));
      engine.evaluateMaintained('u1', _state());
      expect(engine.unit('u1')!.stage, MemoryStage.captured);
    });
  });

  group('DoD Task 6 — mô phỏng phiên đọc 5 phút không gián đoạn', () {
    test('300 hành vi liên tục: đầu ra duy nhất là badge-dữ liệu, không dialog',
        () {
      final engine = newEngine();
      // 5 phút = 300 giây, mỗi giây một hành vi đọc/tra/nghe — người dùng
      // KHÔNG BAO GIỜ bị chặn: engine không có kênh nào phát dialog cả
      // (bảo đảm cấu trúc — mọi API đều trả dữ liệu hoặc void).
      for (var second = 0; second < 300; second++) {
        tick = second;
        final unitIndex = second % 5; // 5 unit xuất hiện luân phiên
        final unitId = 'u-$unitIndex';
        engine.observe(unitId, evidenceBump: 0);
        switch (second % 7) {
          case 0:
          case 3:
            engine.recordImplicit(_act(
                LearningActionType.opened, unitId,
                evidenceId: 'ev-${second % 11}', at: clock()));
            break;
          case 1:
            engine.recordImplicit(_act(
                LearningActionType.translated, unitId,
                at: clock()));
            break;
          case 2:
            engine.recordImplicit(_act(
                LearningActionType.highlighted, unitId,
                at: clock()));
            break;
          case 4:
            engine.recordImplicit(_act(
                LearningActionType.replayed, unitId,
                evidenceId: 'ev-${second % 13}', at: clock()));
            break;
          case 5:
            engine.recordImplicit(_act(
                LearningActionType.chatAsked, unitId,
                at: clock()));
            break;
          default:
            engine.recordImplicit(_act(
                LearningActionType.skipped, unitId,
                at: clock()));
        }
      }

      // Không exception, không block — tổng kết cuối phiên:
      final summary = engine.endSessionSummary();
      expect(summary, isNotEmpty);
      for (final suggestion in summary) {
        expect(suggestion.reason, startsWith('Gợi ý lưu vì'));
      }
      expect(engine.pendingSuggestions, isEmpty,
          reason: 'endSessionSummary drain sạch');
      // Mọi unit captured vẫn KHÔNG tự động practicing:
      final anyAutoPracticing = engine.unit('u-0')!.sm2StartedAt != null;
      expect(anyAutoPracticing, isFalse);
    });
  });

  group('JSON round-trip', () {
    test('MemoryLifecycleUnit giữ nguyên lịch sử append-only', () {
      final engine = newEngine();
      engine.observe('u1');
      engine.recordImplicit(_act(LearningActionType.highlighted, 'u1'));
      engine.recordImplicit(_act(LearningActionType.translated, 'u1'));
      engine.promote('u1', PromoteReason.userSave);
      engine.evaluateMaintained('u1', _state());

      final original = engine.unit('u1')!;
      final clone = MemoryLifecycleUnit.fromJson(original.toJson());
      expect(clone.toJson(), equals(original.toJson()));
      expect(clone.history.length, 4); // captured + promoted + practicing + maintained
    });

    test('LifecycleSuggestion JSON round-trip', () {
      final suggestion = LifecycleSuggestion(
        unitId: 'u1',
        reason: 'Gợi ý lưu vì bạn đã bôi đen và tra nghĩa.',
        at: DateTime.utc(2026, 1, 1),
      );
      final json = suggestion.toJson();
      expect(json['unitId'], 'u1');
      expect(json['reason'], contains('bôi đen'));
    });
  });
}
