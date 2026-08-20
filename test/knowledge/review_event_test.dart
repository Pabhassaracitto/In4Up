import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/knowledge/models/learning_state.dart';
import 'package:in4up/knowledge/models/review_event.dart';

ReviewEvent _ev(
  String id,
  String unitId,
  SkillDimension skill,
  DateTime t, {
  String device = 'dev-a',
  bool ignored = false,
}) {
  return ReviewEvent(
    eventId: id,
    unitId: unitId,
    skill: skill,
    rating: SkillRating.good,
    timestamp: t,
    deviceId: device,
    ignoredForMastery: ignored,
  );
}

void main() {
  group('ReviewEvent — schema mục 2.4 (append-only, immutable)', () {
    test('JSON round-trip toàn bộ lưới 3 skill × 4 rating', () {
      for (final skill in SkillDimension.values) {
        for (final rating in SkillRating.values) {
          final e = ReviewEvent(
            eventId: 'ev-${skill.name}-${rating.name}',
            unitId: 'u1',
            skill: skill,
            rating: rating,
            timestamp: DateTime.utc(2026, 1, 1, 10, 30),
            deviceId: 'pixel-8',
          );
          final clone = ReviewEvent.fromJson(e.toJson());
          expect(clone.toJson(), equals(e.toJson()),
              reason: 'round-trip thất bại tại $skill/$rating');
        }
      }
    });

    test('markedIgnoredForMastery trả bản MỚI — bản cũ nguyên vẹn (append-only)', () {
      final e = _ev('e1', 'u1', SkillDimension.listening, DateTime.utc(2026, 1, 1));
      final flagged = e.markedIgnoredForMastery();

      expect(flagged.ignoredForMastery, isTrue);
      expect(flagged.eventId, e.eventId);
      expect(e.ignoredForMastery, isFalse, reason: 'event gốc không bao giờ bị sửa');
    });
  });

  group('ReviewEventConflictResolver — conflict 2 thiết bị (mục 2.4)', () {
    test('cùng unit+skill cách 2 phút ⇒ event MUỘN bị ignore, event SỚM được tính', () {
      final t1 = DateTime.utc(2026, 1, 1, 10, 0);
      final t2 = DateTime.utc(2026, 1, 1, 10, 2);

      // Input cố tình đưa event muộn lên trước — output phải giữ thứ tự input.
      final out = ReviewEventConflictResolver.resolveForMastery([
        _ev('e-late', 'u1', SkillDimension.listening, t2, device: 'phone'),
        _ev('e-early', 'u1', SkillDimension.listening, t1, device: 'laptop'),
      ]);

      expect(out.length, 2);
      expect(out[0].eventId, 'e-late');
      expect(out[0].ignoredForMastery, isTrue,
          reason: 'event muộn hơn ⇒ không tính mastery');
      expect(out[1].eventId, 'e-early');
      expect(out[1].ignoredForMastery, isFalse);
    });

    test('cách 6 phút (≥ cửa sổ 5 phút) ⇒ cả hai đều được tính', () {
      final t1 = DateTime.utc(2026, 1, 1, 10, 0);
      final t2 = DateTime.utc(2026, 1, 1, 10, 6);

      final out = ReviewEventConflictResolver.resolveForMastery([
        _ev('e1', 'u1', SkillDimension.listening, t1),
        _ev('e2', 'u1', SkillDimension.listening, t2),
      ]);

      expect(out.every((e) => !e.ignoredForMastery), isTrue);
    });

    test('trong 5 phút nhưng KHÁC skill ⇒ không conflict (3 skill tách biệt)', () {
      final t = DateTime.utc(2026, 1, 1, 10, 0);
      final out = ReviewEventConflictResolver.resolveForMastery([
        _ev('e1', 'u1', SkillDimension.listening, t),
        _ev('e2', 'u1', SkillDimension.reading, t.add(const Duration(minutes: 1))),
      ]);

      expect(out.every((e) => !e.ignoredForMastery), isTrue);
    });

    test('trong 5 phút nhưng KHÁC unit ⇒ không conflict', () {
      final t = DateTime.utc(2026, 1, 1, 10, 0);
      final out = ReviewEventConflictResolver.resolveForMastery([
        _ev('e1', 'u1', SkillDimension.listening, t),
        _ev('e2', 'u2', SkillDimension.listening, t.add(const Duration(minutes: 1))),
      ]);

      expect(out.every((e) => !e.ignoredForMastery), isTrue);
    });

    test('cùng timestamp: tiebreak ổn định theo eventId — không đúa may rủi', () {
      final t = DateTime.utc(2026, 1, 1, 10, 0);
      final out = ReviewEventConflictResolver.resolveForMastery([
        _ev('bbb', 'u1', SkillDimension.listening, t, device: 'phone'),
        _ev('aaa', 'u1', SkillDimension.listening, t, device: 'laptop'),
      ]);

      expect(
          out.firstWhere((e) => e.eventId == 'aaa').ignoredForMastery, isFalse);
      expect(
          out.firstWhere((e) => e.eventId == 'bbb').ignoredForMastery, isTrue);
    });

    test('idempotent: chạy lại resolver cho cùng kết quả (an toàn khi sync nhiều đợt)', () {
      final t1 = DateTime.utc(2026, 1, 1, 10, 0);
      final t2 = DateTime.utc(2026, 1, 1, 10, 1);
      final events = [
        _ev('e1', 'u1', SkillDimension.listening, t1),
        _ev('e2', 'u1', SkillDimension.listening, t2),
      ];

      final once = ReviewEventConflictResolver.resolveForMastery(events);
      final twice = ReviewEventConflictResolver.resolveForMastery(once);

      expect(twice.map((e) => e.toJson()), equals(once.map((e) => e.toJson())));
    });

    test('input KHÔNG bị đột biến', () {
      final t1 = DateTime.utc(2026, 1, 1, 10, 0);
      final t2 = DateTime.utc(2026, 1, 1, 10, 2);
      final input = [
        _ev('e1', 'u1', SkillDimension.listening, t1),
        _ev('e2', 'u1', SkillDimension.listening, t2),
      ];

      ReviewEventConflictResolver.resolveForMastery(input);

      expect(input.every((e) => !e.ignoredForMastery), isTrue);
    });
  });
}
