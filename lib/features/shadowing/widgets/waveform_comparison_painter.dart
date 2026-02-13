// NEW - Vẽ so sánh sóng
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Vẽ 2 sóng âm chồng lên nhau để so sánh
class WaveformComparisonPainter extends CustomPainter {
  final List<double> originalWaveform;
  final List<double> recordedWaveform;
  final Color originalColor;
  final Color recordedColor;
  final bool showDifference;
  final double animationProgress; // 0.0 - 1.0 cho animation reveal

  WaveformComparisonPainter({
    required this.originalWaveform,
    required this.recordedWaveform,
    this.originalColor = const Color(0xFF6C63FF),
    this.recordedColor = const Color(0xFF4CAF50),
    this.showDifference = true,
    this.animationProgress = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (originalWaveform.isEmpty) return;

    final centerY = size.height / 2;
    final maxAmplitude = size.height * 0.4;

    // Normalize để cả 2 waveform có cùng số samples
    final targetLength =
        math.max(originalWaveform.length, recordedWaveform.length);
    final normalizedOriginal = _resample(originalWaveform, targetLength);
    final normalizedRecorded = recordedWaveform.isNotEmpty
        ? _resample(recordedWaveform, targetLength)
        : <double>[];

    final pixelsPerSample = size.width / targetLength;

    // 1. Vẽ center line
    final centerLinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      centerLinePaint,
    );

    // 2. Vẽ vùng chênh lệch (nếu bật)
    if (showDifference && normalizedRecorded.isNotEmpty) {
      _drawDifferenceArea(
        canvas,
        size,
        normalizedOriginal,
        normalizedRecorded,
        centerY,
        maxAmplitude,
        pixelsPerSample,
      );
    }

    // 3. Vẽ waveform gốc (mờ hơn, ở dưới)
    _drawWaveform(
      canvas,
      normalizedOriginal,
      centerY,
      maxAmplitude,
      pixelsPerSample,
      originalColor.withValues(alpha: 0.4),
      strokeWidth: 3,
      animatedLength: targetLength, // Luôn hiển thị đầy đủ
    );

    // 4. Vẽ waveform đã ghi (đậm hơn, ở trên, với animation)
    if (normalizedRecorded.isNotEmpty) {
      final animatedLength = (targetLength * animationProgress).round();
      _drawWaveform(
        canvas,
        normalizedRecorded,
        centerY,
        maxAmplitude,
        pixelsPerSample,
        recordedColor,
        strokeWidth: 2,
        animatedLength: animatedLength,
      );
    }

    // 5. Vẽ legend
    _drawLegend(canvas, size);
  }

  void _drawWaveform(
    Canvas canvas,
    List<double> waveform,
    double centerY,
    double maxAmplitude,
    double pixelsPerSample,
    Color color, {
    double strokeWidth = 2,
    int? animatedLength,
  }) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final length = animatedLength ?? waveform.length;

    for (int i = 0; i < length && i < waveform.length; i++) {
      final x = i * pixelsPerSample;
      final amplitude = waveform[i].clamp(0.0, 1.0);
      final y = centerY - (amplitude * maxAmplitude);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        // Smooth curve
        final prevX = (i - 1) * pixelsPerSample;
        final controlX = (prevX + x) / 2;
        path.quadraticBezierTo(prevX, path.getBounds().bottom, controlX, y);
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // Mirror (bottom half)
    final mirrorPath = Path();
    for (int i = 0; i < length && i < waveform.length; i++) {
      final x = i * pixelsPerSample;
      final amplitude = waveform[i].clamp(0.0, 1.0);
      final y = centerY + (amplitude * maxAmplitude);

      if (i == 0) {
        mirrorPath.moveTo(x, y);
      } else {
        mirrorPath.lineTo(x, y);
      }
    }

    canvas.drawPath(mirrorPath, paint);
  }

  void _drawDifferenceArea(
    Canvas canvas,
    Size size,
    List<double> original,
    List<double> recorded,
    double centerY,
    double maxAmplitude,
    double pixelsPerSample,
  ) {
    final length = math.min(original.length, recorded.length);

    for (int i = 0; i < length; i++) {
      final x = i * pixelsPerSample;
      final origAmp = original[i].clamp(0.0, 1.0);
      final recAmp = recorded[i].clamp(0.0, 1.0);

      final diff = (origAmp - recAmp).abs();

      if (diff > 0.1) {
        // Chênh lệch đáng kể - highlight
        final color = diff > 0.3
            ? Colors.red.withValues(alpha: 0.2)
            : Colors.orange.withValues(alpha: 0.15);

        final paint = Paint()..color = color;

        final top = centerY - (math.max(origAmp, recAmp) * maxAmplitude);
        final bottom = centerY + (math.max(origAmp, recAmp) * maxAmplitude);

        canvas.drawRect(
          Rect.fromLTRB(x, top, x + pixelsPerSample, bottom),
          paint,
        );
      }
    }
  }

  void _drawLegend(Canvas canvas, Size size) {
    const legendY = 8.0;
    const spacing = 12.0;

    // Original legend
    final originalPaint = Paint()..color = originalColor.withValues(alpha: 0.6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(8, legendY, 20, 4),
        const Radius.circular(2),
      ),
      originalPaint,
    );

    final originalText = TextPainter(
      text: const TextSpan(
        text: 'Mẫu',
        style: TextStyle(color: Colors.white54, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    );
    originalText.layout();
    originalText.paint(canvas, const Offset(32, legendY - 3));

    // Recorded legend
    final recordedPaint = Paint()..color = recordedColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(32 + originalText.width + spacing, legendY, 20, 4),
        const Radius.circular(2),
      ),
      recordedPaint,
    );

    final recordedText = TextPainter(
      text: const TextSpan(
        text: 'Bạn',
        style: TextStyle(color: Colors.white70, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    );
    recordedText.layout();
    recordedText.paint(
      canvas,
      Offset(32 + originalText.width + spacing + 24, legendY - 3),
    );
  }

  List<double> _resample(List<double> waveform, int targetLength) {
    if (waveform.isEmpty) return [];
    if (waveform.length == targetLength) return waveform;

    final result = <double>[];
    final ratio = waveform.length / targetLength;

    for (int i = 0; i < targetLength; i++) {
      final sourceIndex = (i * ratio).floor();
      result.add(waveform[sourceIndex.clamp(0, waveform.length - 1)]);
    }

    return result;
  }

  @override
  bool shouldRepaint(covariant WaveformComparisonPainter oldDelegate) {
    return oldDelegate.originalWaveform != originalWaveform ||
        oldDelegate.recordedWaveform != recordedWaveform ||
        oldDelegate.animationProgress != animationProgress;
  }
}
