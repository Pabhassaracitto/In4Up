/// ═══════════════════════════════════════════════════════════════
/// HEXAGRAM PAINTER — Word view (ADR-0019, D9 — cả 2 view + toggle)
///
/// 6 đỉnh trên 3 đường kính xuyên tâm. Input tam giác trong, Output
/// tam giác ngoài. Production gap = khoảng cách mirror.
///
/// Null-vertex contract: đỉnh chưa có bằng chứng → vòng rỗng nét đứt,
/// không tô. Envelope không nội suy qua null.
/// ═══════════════════════════════════════════════════════════════
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

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
  /// Mặc định = initials tiếng Việt. Widget cung cấp localized.
  final List<String> labels;

  const HexagramPainter({
    required this.mastery,
    this.showLabels = true,
    this.showGaps = true,
    this.inputColor = const Color(0xFF42A5F5),
    this.outputColor = const Color(0xFF66BB6A),
    this.gapColor = const Color(0xFFFFD54F),
    this.dotRadius = 5.0,
    this.labels = const ['H', 'N', 'Đ', 'D', 'Ỡ', 'V'],
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
            center: center, radius: radius, dim: pair[1],
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
    if (inputVerts.length >= 2) {
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
    if (outputVerts.length >= 2) {
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
    for (final entry in mastery.entries) {
      final pos = vertexPosition(
        center: center, radius: radius, dim: entry.key,
        mastery: entry.value,
      );
      if (pos == null) {
        // Null vertex: hollow dashed circle at R.
        _drawNullVertex(canvas, center, radius, entry.key);
      } else {
        final color = entry.key == SkillDimension.use ||
                entry.key == SkillDimension.speak ||
                entry.key == SkillDimension.write
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
    // Dashed circle.
    final path = ui.Path()
      ..addArc(Rect.fromCircle(center: pos, radius: dotRadius + 2), 0, 2 * math.pi);
    canvas.drawPath(path, paint);
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
        old.labels != labels;
  }
}

double _deg2rad(double deg) => deg * math.pi / 180.0;
