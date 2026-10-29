// lib/screens/understand_mode/painters/understand_waveform_painter.dart

import 'package:flutter/material.dart';

class UnderstandWaveformPainter extends CustomPainter {
  final List<double> samples;
  final double progress;
  final List<Color> colors;
  final bool isPlaying;

  UnderstandWaveformPainter({
    required this.samples,
    required this.progress,
    required this.isPlaying,
    this.colors = const [Color(0xFF6C63FF), Color(0xFF2196F3)],
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;

    final width = size.width;
    final height = size.height;
    final centerY = height / 2;
    final barWidth = width / samples.length;

    for (int i = 0; i < samples.length; i++) {
      final x = i * barWidth;

      double sampleValue = samples[i].clamp(0.0, 1.0);
      final barHeight = sampleValue * (height * 0.8);
      final barY = centerY - barHeight / 2;

      final isPlayed = (i / samples.length) <= progress;

      final paint = Paint()
        ..color = isPlayed && isPlaying
            ? colors[0].withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;

      canvas.drawRect(
        Rect.fromLTWH(
          x,
          barY,
          barWidth - 1,
          barHeight,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant UnderstandWaveformPainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.progress != progress ||
        oldDelegate.isPlaying != isPlaying;
  }
}
