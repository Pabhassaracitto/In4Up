// lib/screens/memory_mode/painters/garden_painter.dart

import 'dart:math';
import 'package:flutter/material.dart';
import '../models/memory_stage.dart';

/// Vẽ background vườn cây cho Memory Garden View
/// Tạo hiệu ứng visual nhẹ nhàng, organic
class GardenPainter extends CustomPainter {
  final Map<MemoryStage, int> distribution;
  final double animationValue; // 0.0 - 1.0 for breathing animation
  final Color baseColor;

  GardenPainter({
    required this.distribution,
    this.animationValue = 0.0,
    this.baseColor = const Color(0xFF0D0D1A),
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawGroundGradient(canvas, size);
    _drawSoftClouds(canvas, size);
    _drawStageGlow(canvas, size);
  }

  /// Gradient nền đất
  void _drawGroundGradient(Canvas canvas, Size size) {
    final rect =
        Rect.fromLTWH(0, size.height * 0.7, size.width, size.height * 0.3);
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.transparent,
        const Color(0xFF1B5E20).withValues(alpha: 0.05),
        const Color(0xFF1B5E20).withValues(alpha: 0.1),
      ],
    );

    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
  }

  /// Mây nhẹ decoration
  void _drawSoftClouds(Canvas canvas, Size size) {
    final random = Random(42); // Fixed seed for consistent look

    for (int i = 0; i < 3; i++) {
      final x = random.nextDouble() * size.width;
      final y = 20 + random.nextDouble() * size.height * 0.2;
      final radius = 30 + random.nextDouble() * 50;

      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.015 + animationValue * 0.005)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.8);

      canvas.drawCircle(
        Offset(x, y + sin(animationValue * pi * 2) * 3),
        radius,
        paint,
      );
    }
  }

  /// Glow nhẹ cho mỗi stage có items
  void _drawStageGlow(Canvas canvas, Size size) {
    final total = distribution.values.fold(0, (a, b) => a + b);
    if (total == 0) return;

    double xOffset = 0;

    for (final stage in MemoryStage.values) {
      final count = distribution[stage] ?? 0;
      if (count == 0) continue;

      final ratio = count / total;
      final width = size.width * ratio;
      final centerX = xOffset + width / 2;
      final centerY = size.height * 0.85;
      final radius = width * 0.4 + 20;

      final paint = Paint()
        ..color =
            stage.primaryColor.withValues(alpha: 0.04 + animationValue * 0.02)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius);

      canvas.drawCircle(Offset(centerX, centerY), radius, paint);

      xOffset += width;
    }
  }

  @override
  bool shouldRepaint(GardenPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue ||
      oldDelegate.distribution != distribution;
}
