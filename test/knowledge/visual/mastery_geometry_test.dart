import 'package:flutter_test/flutter_test.dart';
import 'dart:math' as math;
import 'package:in4up/knowledge/models/learning_state.dart' show SkillDimension;
import 'package:in4up/knowledge/visual/mastery_geometry.dart';

void main() {
  const center = Offset(0, 0);
  const r = 100.0;

  group('Vertex angles (hexagram)', () {
    test('6 vertices, 3 mirror pairs on diameters', () {
      expect(kVertexAngle.length, 6);
      expect(kMirrorPairs.length, 3);

      // Mirror pairs: angles differ by 180°.
      for (final pair in kMirrorPairs) {
        final a = kVertexAngle[pair[0]]!;
        final b = kVertexAngle[pair[1]]!;
        expect((b - a).abs(), closeTo(180.0, 1e-10),
            reason: '${pair[0]} ↔ ${pair[1]} phải đối xứng 180°');
      }

      // Input (top triangle): understanding, listening, reading.
      // All angles in [30, 150] (upper half).
      for (final dim in [SkillDimension.understanding,
          SkillDimension.listening, SkillDimension.reading]) {
        expect(kVertexAngle[dim]!, greaterThanOrEqualTo(30.0));
        expect(kVertexAngle[dim]!, lessThanOrEqualTo(150.0));
      }

      // Output (bottom triangle): use, speak, write.
      // All angles in [210, 330] (lower half).
      for (final dim in [SkillDimension.use,
          SkillDimension.speak, SkillDimension.write]) {
        expect(kVertexAngle[dim]!, greaterThanOrEqualTo(210.0));
        expect(kVertexAngle[dim]!, lessThanOrEqualTo(330.0));
      }
    });

    test('understanding ↔ use: vertical diameter', () {
      expect(kVertexAngle[SkillDimension.understanding], 90.0);
      expect(kVertexAngle[SkillDimension.use], 270.0);
    });
  });

  group('vertexPosition', () {
    test('mastery null → null (null-vertex contract)', () {
      expect(
        vertexPosition(center: center, radius: r,
          dim: SkillDimension.understanding, mastery: null),
        isNull,
      );
    });

    test('mastery 0 → at center', () {
      final pos = vertexPosition(center: center, radius: r,
        dim: SkillDimension.understanding, mastery: 0.0);
      expect(pos, isNotNull);
      expect(pos!.distance, closeTo(0.0, 1e-10));
    });

    test('mastery 1 → at radius', () {
      final pos = vertexPosition(center: center, radius: r,
        dim: SkillDimension.understanding, mastery: 1.0);
      expect(pos, isNotNull);
      expect(pos!.distance, closeTo(r, 1e-10));
    });

    test('understanding at top (y < center.y)', () {
      final pos = vertexPosition(center: center, radius: r,
        dim: SkillDimension.understanding, mastery: 1.0);
      expect(pos!.dy, lessThan(center.dy), reason: 'understanding ở trên');
    });

    test('use at bottom (y > center.y)', () {
      final pos = vertexPosition(center: center, radius: r,
        dim: SkillDimension.use, mastery: 1.0);
      expect(pos!.dy, greaterThan(center.dy), reason: 'use ở dưới');
    });

    test('mastery clamp [0,1]', () {
      final pos = vertexPosition(center: center, radius: r,
        dim: SkillDimension.understanding, mastery: 2.0);
      expect(pos!.distance, closeTo(r, 1e-10),
          reason: 'mastery > 1 → clamp到 R');
    });
  });

  group('productionGap', () {
    test('cả 2 mirror có mastery → khoảng cách thực tế', () {
      // understanding (90°, m=1) ↔ use (270°, m=1): 2R
      final gap = productionGap(
        center: center, radius: r,
        mirrorPair: kMirrorPairs[0],
        masteryMap: {
          SkillDimension.understanding: 1.0,
          SkillDimension.use: 1.0,
        },
      );
      expect(gap, closeTo(2 * r, 1e-10),
          reason: 'cả 2 = 1 → gap = 2R');
    });

    test('1 null → null (envelope không nội suy)', () {
      final gap = productionGap(
        center: center, radius: r,
        mirrorPair: kMirrorPairs[0],
        masteryMap: {
          SkillDimension.understanding: 1.0,
          SkillDimension.use: null,
        },
      );
      expect(gap, isNull,
          reason: '1 null → không tính gap');
    });

    test('cả 2 null → null', () {
      final gap = productionGap(
        center: center, radius: r,
        mirrorPair: kMirrorPairs[0],
        masteryMap: {
          SkillDimension.understanding: null,
          SkillDimension.use: null,
        },
      );
      expect(gap, isNull);
    });

    test('partial mastery → gap proportional', () {
      // understanding m=0.5, use m=0.5 → gap = R
      final gap = productionGap(
        center: center, radius: r,
        mirrorPair: kMirrorPairs[0],
        masteryMap: {
          SkillDimension.understanding: 0.5,
          SkillDimension.use: 0.5,
        },
      );
      expect(gap, closeTo(r, 1e-10),
          reason: 'm1=m2=0.5 → gap = R');
    });
  });

  group('input/output mastery (scatter)', () {
    test('inputMastery: trung bình hiểu/nghe/đọc có evidence', () {
      final inp = inputMastery({
        SkillDimension.understanding: 0.8,
        SkillDimension.listening: 0.6,
        SkillDimension.reading: 0.4,
        SkillDimension.use: 0.9,  // không tính
      });
      expect(inp, closeTo(0.6, 1e-10),
          reason: '(0.8+0.6+0.4)/3 = 0.6');
    });

    test('inputMastery: không evidence → null (không bù 0)', () {
      final inp = inputMastery({
        SkillDimension.use: 0.9,
        SkillDimension.speak: 0.8,
      });
      expect(inp, isNull, reason: 'không input → null, không bù 0');
    });

    test('outputMastery: trung bình dùng/nói/viết có evidence', () {
      final out = outputMastery({
        SkillDimension.use: 0.7,
        SkillDimension.speak: 0.5,
        SkillDimension.write: 0.3,
      });
      expect(out, closeTo(0.5, 1e-10));
    });

    test('outputMastery: không evidence → null', () {
      final out = outputMastery({
        SkillDimension.understanding: 0.8,
        SkillDimension.listening: 0.6,
      });
      expect(out, isNull);
    });
  });

  group('scatterPosition + scatterGap', () {
    test('scatterPosition: x=input, y=output', () {
      final pos = scatterPosition(
        origin: Offset(0, 0), scale: 100.0,
        masteryMap: {
          SkillDimension.understanding: 0.8,
          SkillDimension.listening: 0.6,
          SkillDimension.reading: 0.4,
          SkillDimension.use: 0.9,
          SkillDimension.speak: 0.5,
          SkillDimension.write: 0.3,
        },
      );
      expect(pos, isNotNull);
      // x = input = 0.6 * 100 = 60
      expect(pos!.dx, closeTo(60.0, 1e-10));
      // y = output = 0.5 * 100 = 50 (y-down → negative)
      expect(pos.dy, closeTo(-50.0, 1e-10));
    });

    test('scatterPosition: thiếu output → null', () {
      final pos = scatterPosition(
        origin: Offset(0, 0), scale: 100.0,
        masteryMap: {
          SkillDimension.understanding: 0.8,
          SkillDimension.listening: 0.6,
          SkillDimension.reading: 0.4,
        },
      );
      expect(pos, isNull);
    });

    test('scatterGap: cân bằng (input=output) → 0', () {
      final gap = scatterGap(masteryMap: {
        SkillDimension.understanding: 0.6,
        SkillDimension.listening: 0.6,
        SkillDimension.reading: 0.6,
        SkillDimension.use: 0.6,
        SkillDimension.speak: 0.6,
        SkillDimension.write: 0.6,
      });
      expect(gap, closeTo(0.0, 1e-10));
    });

    test('scatterGap: mất cân bằng → > 0', () {
      final gap = scatterGap(masteryMap: {
        SkillDimension.understanding: 0.8,
        SkillDimension.listening: 0.8,
        SkillDimension.reading: 0.8,
        SkillDimension.use: 0.2,
        SkillDimension.speak: 0.2,
        SkillDimension.write: 0.2,
      });
      // |0.2 - 0.8| / √2 = 0.6 / √2 ≈ 0.424
      expect(gap, closeTo(0.6 / math.sqrt(2), 1e-10));
    });

    test('scatterGap: thiếu output → null', () {
      final gap = scatterGap(masteryMap: {
        SkillDimension.understanding: 0.8,
        SkillDimension.listening: 0.6,
        SkillDimension.reading: 0.4,
      });
      expect(gap, isNull);
    });
  });
}
