/// ═══════════════════════════════════════════════════════════════
/// HEXAGRAM PAINTER — Word view (ADR-0019, D9 — cả 2 view + toggle)
///
/// 6 đỉnh trên 3 đường kính xuyên tâm. Input tam giác trong, Output
/// tam giác ngoài. Production gap = chênh lệch bán kính mirror.
///
/// Null-vertex contract: đỉnh chưa có bằng chứng → vòng rỗng nét đứt,
/// không tô. Envelope không nội suy qua null.
/// ═══════════════════════════════════════════════════════════════
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/learning_state.dart' show SkillDimension;
import 'mastery_geometry.dart';

/// Painter vẽ hexagram mastery cho 1 từ.
class HexagramPainter extends CustomPainter {
  /// Bảng mastery cho 6 trục. null = chưa đánh giá.
  final Map<SkillDimension, double?> mastery;

  final bool showLabels;
  final bool showGaps;
  final Color inputColor;
  final Color outputColor;
  final Color gapColor;
  final double dotRadius;

  /// Labels cho 6 đỉnh (theo thứ tự SkillDimension.values).
  /// Mặc định là số thứ tự 1–6; legend trong UI cung cấp nhãn bản địa.
  final List<String> labels;

  const HexagramPainter({
    required this.mastery,
    this.showLabels = true,
    this.showGaps = true,
    this.inputColor = const Color(0xFF42A5F5),
    this.outputColor = const Color(0xFF66BB6A),
    this.gapColor = const Color(0xFFFFD54F),
    this.dotRadius = 5.0,
    this.labels = const ['1', '2', '3', '4', '5', '6'],
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.40;

    // ── Frame: 6 vertex positions (đánh dấu khu vực) ──
    final framePaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Neutral guides make the six axes and scale visible on a dark surface.
    framePaint.color = Colors.white24;
    canvas.drawCircle(center, radius, framePaint);
    canvas.drawCircle(center, radius * 0.5, framePaint);
    for (final pair in kMirrorPairs) {
      final start = vertexPosition(
        center: center, radius: radius, dim: pair[0], mastery: 1.0,
      )!;
      final end = vertexPosition(
        center: center, radius: radius, dim: pair[1], mastery: 1.0,
      )!;
      canvas.drawLine(start, end, framePaint);
    }

    // ── Production gaps (mirror pairs) ──
    if (showGaps) {
      for (final pair in kMirrorPairs) {
        final gap = productionGap(
          center: center, radius: radius,
          mirrorPair: pair, masteryMap: mastery,
        );
        if (gap != null) {
          final posA = vertexPosition(
            center: center, radius: radius, dim: pair[0],
            mastery: mastery[pair[0]],
          )!;
          final posB = vertexPosition(
            center: center, radius: radius, dim: pair[0],
            mastery: mastery[pair[1]],
          )!;
          canvas.drawLine(posA, posB, Paint()
            ..color = gapColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..strokeCap = StrokeCap.round);
        }
      }
    }

    // ── Input triangle (understanding, listening, reading) ──
    final inputVerts = <Offset>[];
    for (final dim in [SkillDimension.understanding,
        SkillDimension.listening, SkillDimension.reading]) {
      final pos = vertexPosition(
        center: center, radius: radius, dim: dim,
        mastery: mastery[dim],
      );
      if (pos != null) inputVerts.add(pos);
    }
    if (inputVerts.length == 3) {
      canvas.drawPath(
        Path()..addPolygon(inputVerts, true),
        Paint()
          ..color = inputColor.withValues(alpha: 0.15)
          ..style = PaintingStyle.fill,
      );
    }
    if (inputVerts.length == 3) {
      canvas.drawPath(
        Path()..addPolygon(inputVerts, true),
        Paint()
          ..color = inputColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // ── Output triangle (use, speak, write) ──
    final outputVerts = <Offset>[];
    for (final dim in [SkillDimension.use,
        SkillDimension.speak, SkillDimension.write]) {
      final pos = vertexPosition(
        center: center, radius: radius, dim: dim,
        mastery: mastery[dim],
      );
      if (pos != null) outputVerts.add(pos);
    }
    if (outputVerts.length == 3) {
      canvas.drawPath(
        Path()..addPolygon(outputVerts, true),
        Paint()
          ..color = outputColor.withValues(alpha: 0.15)
          ..style = PaintingStyle.fill,
      );
    }
    if (outputVerts.length == 3) {
      canvas.drawPath(
        Path()..addPolygon(outputVerts, true),
        Paint()
          ..color = outputColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // ── Vertices (filled dots + null hollow dashed) ──
    for (final dim in SkillDimension.values) {
      final pos = vertexPosition(
        center: center, radius: radius, dim: dim,
        mastery: mastery[dim],
      );
      if (pos == null) {
        // Null vertex: hollow dashed circle at R.
        _drawNullVertex(canvas, center, radius, dim);
      } else {
        final color = dim == SkillDimension.use ||
                dim == SkillDimension.speak ||
                dim == SkillDimension.write
            ? outputColor
            : inputColor;
        canvas.drawCircle(pos, dotRadius, Paint()..color = color);
      }
    }

    // ── Labels ──
    if (showLabels) {
      _drawLabels(canvas, center, radius);
    }
  }

  void _drawNullVertex(
      Canvas canvas, Offset center, double radius, SkillDimension dim) {
    final angle = _deg2rad(kVertexAngle[dim]!);
    final pos = Offset(
      center.dx + radius * math.cos(angle),
      center.dy - radius * math.sin(angle),
    );
    final paint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    // Six separate arcs, not a solid circle: unknown ≠ an evaluated zero.
    final rect = Rect.fromCircle(center: pos, radius: dotRadius + 2);
    for (var i = 0; i < 6; i++) {
      canvas.drawArc(rect, i * math.pi / 3, math.pi / 6, false, paint);
    }
  }

  void _drawLabels(Canvas canvas, Offset center, double radius) {
    const colors = <SkillDimension, Color>{
      SkillDimension.understanding: Color(0xFF42A5F5),
      SkillDimension.listening: Color(0xFF42A5F5),
      SkillDimension.reading: Color(0xFF42A5F5),
      SkillDimension.use: Color(0xFF66BB6A),
      SkillDimension.speak: Color(0xFF66BB6A),
      SkillDimension.write: Color(0xFF66BB6A),
    };

    for (var i = 0; i < SkillDimension.values.length; i++) {
      final dim = SkillDimension.values[i];
      final angle = _deg2rad(kVertexAngle[dim]!);
      final labelR = radius + 18;
      final pos = Offset(
        center.dx + labelR * math.cos(angle),
        center.dy - labelR * math.sin(angle),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: colors[dim],
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant HexagramPainter old) {
    return old.mastery != mastery ||
        old.showLabels != showLabels ||
        old.showGaps != showGaps ||
        old.inputColor != inputColor ||
        old.outputColor != outputColor ||
        old.gapColor != gapColor ||
        old.dotRadius != dotRadius ||
        old.labels != labels;
  }
}

double _deg2rad(double deg) => deg * math.pi / 180.0;
