import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/pic_anki/models/pic_models.dart';
import 'package:in4up/features/pic_anki/services/pic_express_scorer.dart';
import 'package:in4up/knowledge/models/learning_state.dart';

void main() {
  group('NormRect', () {
    test('fromCorners chuẩn hoá và clamp', () {
      final r = NormRect.fromCorners(0.8, 0.7, 0.2, 0.3);
      expect(r.x, closeTo(0.2, 1e-9));
      expect(r.y, closeTo(0.3, 1e-9));
      expect(r.w, closeTo(0.6, 1e-9));
      expect(r.h, closeTo(0.4, 1e-9));
      expect(r.contains(0.5, 0.5), isTrue);
      expect(r.contains(0.1, 0.5), isFalse);
    });

    test('isUsable từ chối vết kéo nhỏ', () {
      expect(NormRect.fromCorners(0.5, 0.5, 0.51, 0.51).isUsable, isFalse);
      expect(NormRect.fromCorners(0.1, 0.1, 0.4, 0.4).isUsable, isTrue);
    });
  });

  group('PicReviewEngine', () {
    PicMask mask(String id, {DateTime? due, NormRect? rect}) {
      return PicMask(
        id: id,
        rect: rect ?? const NormRect(x: 0.1, y: 0.1, w: 0.2, h: 0.2),
        label: id,
        reading: SM2Snapshot(
          easeFactor: 2.5,
          interval: 0,
          repetitions: 0,
          dueDate: due ?? DateTime(2026, 9, 1),
        ),
      );
    }

    test('dueQueue chỉ lấy mask đến hạn, ổn định theo id', () {
      final now = DateTime(2026, 9, 5);
      final deck = PicDeck(
        id: 'd1',
        title: 't',
        imagePath: '/tmp/a.jpg',
        createdAt: now,
        masks: [
          mask('b', due: DateTime(2026, 9, 4)),
          mask('a', due: DateTime(2026, 9, 4)),
          mask('c', due: DateTime(2026, 9, 10)),
        ],
      );
      final q = PicReviewEngine.dueQueue(deck, now);
      expect(q.map((m) => m.id).toList(), ['a', 'b']);
    });

    test('ôn mask A không đổi due mask B', () {
      final now = DateTime(2026, 9, 5);
      var a = mask('a');
      final b = mask('b');
      a = PicReviewEngine.applyReading(
        mask: a,
        quality: PicReviewGrade.good,
        now: now,
      );
      expect(a.reading.dueDate.isAfter(now), isTrue);
      expect(b.reading.dueDate, DateTime(2026, 9, 1));
      expect(a.reading.interval, 1);
    });

    test('hitTest chọn vùng nhỏ hơn khi chồng', () {
      final big = mask('big', rect: const NormRect(x: 0, y: 0, w: 1, h: 1));
      final small =
          mask('small', rect: const NormRect(x: 0.4, y: 0.4, w: 0.1, h: 0.1));
      expect(PicReviewEngine.hitTest([big, small], 0.45, 0.45)?.id, 'small');
      expect(PicReviewEngine.hitTest([big, small], 0.05, 0.05)?.id, 'big');
    });

    test('JSON round-trip giữ mask độc lập', () {
      final now = DateTime(2026, 9, 5);
      final deck = PicDeck(
        id: 'd',
        title: 't',
        imagePath: '/x.jpg',
        createdAt: now,
        masks: [mask('a'), mask('b')],
        entities: const ['bowl', 'robe'],
      );
      final copy = PicDeck.fromJson(deck.toJson());
      expect(copy.masks.length, 2);
      expect(copy.entities, ['bowl', 'robe']);
      expect(copy.masks[0].id, 'a');
    });
  });

  group('PicExpressScorer', () {
    test('coverage + missing entities', () {
      final s = PicExpressScorer.score(
        entities: const ['bát', 'tăng', 'cây'],
        answer: 'Có một cái bát và cây xanh',
      );
      expect(s.total, 3);
      expect(s.matched, 2);
      expect(s.missing, ['tăng']);
      expect(s.hit, ['bát', 'cây']);
      expect(s.coverage, closeTo(2 / 3, 1e-9));
    });

    test('không entity → coverage 0, không ném', () {
      final s = PicExpressScorer.score(entities: const [], answer: 'hello');
      expect(s.total, 0);
      expect(s.coverage, 0);
    });
  });
}
