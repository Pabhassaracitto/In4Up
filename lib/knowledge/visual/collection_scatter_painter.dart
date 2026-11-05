/// ═══════════════════════════════════════════════════════════════
/// COLLECTION SCATTER PAINTER — xem toàn kho (ADR-0019, D9)
///
/// x = Input mastery (avg hiểu/nghe/đọc), y = Output mastery
/// (avg dùng/nói/viết). Đường chéo = cân bằng. Production gap =
/// khoảng cách tới đường chéo.
///
/// Null-vertex contract: từ thiếu input hoặc output → không plot.
/// ═══════════════════════════════════════════════════════════════
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/learning_state.dart' show SkillDimension;
import 'mastery_geometry.dart';

/// 1 điểm scatter = 1 từ.
class ScatterPoint {
  final String unitId;
  final Map<SkillDimension, double?> mastery;

  const ScatterPoint({
    required this.unitId,
    required this.mastery,
  });
}

/// Painter vẽ scatter plot toàn kho.
class CollectionScatterPainter extends CustomPainter {
  final List<ScatterPoint> points;
  final Color dotColor;
  final Color diagonalColor;
  final Color gapColor;

  const CollectionScatterPainter({
    required this.points,
    this.dotColor = const Color(0xFF42A5F5),
    this.diagonalColor = Colors.grey.shade300,
    this.gapColor = const Color(0xFFFFD54F),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(20.0, size.height - 20.0);
    final scale = math.min(size.width, size.height) - 40.0;

    // ── Axis frame ──
    canvas.drawLine(origin, Offset(origin.dx + scale, origin.dy),
        Paint()
          ..color = Colors.grey.shade400
          ..strokeWidth = 1.0);
    canvas.drawLine(origin, Offset(origin.dx, origin.dy - scale),
        Paint()
          ..color = Colors.grey.shade400
          ..strokeWidth = 1.0);

    // ── Diagonal (y = x = cân bằng) ──
    canvas.drawLine(
      origin,
      Offset(origin.dx + scale, origin.dy - scale),
      Paint()
        ..color = diagonalColor
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // ── Points + gap lines ──
    for (final p in points) {
      final pos = scatterPosition(
        origin: origin, scale: scale, masteryMap: p.mastery,
      );
      if (pos == null) continue; // thiếu input hoặc output → không plot

      final gap = scatterGap(masteryMap: p.mastery);

      // Production gap line (tới đường chéo).
      if (gap != null && gap > 0.01) {
        // Foot of perpendicular from (x, y) to diagonal y = x.
        // In [0,1]² space: foot = ((x+y)/2, (x+y)/2).
        final inp = inputMastery(p.mastery)!;
        final out = outputMastery(p.mastery)!;
        final footX = (inp + out) / 2 * scale;
        final footY = (inp + out) / 2 * scale;
        final foot = Offset(origin.dx + footX, origin.dy - footY);
        canvas.drawLine(pos, foot, Paint()
          ..color = gapColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0);
      }

      // Dot.
      canvas.drawCircle(pos, 4.0, Paint()..color = dotColor);
    }
  }

  @override
  bool shouldRepaint(covariant CollectionScatterPainter old) {
    return old.points != points;
  }
}
