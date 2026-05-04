import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../../models/waveform_data.dart';
import '../controllers/rolling_waveform_controller.dart';

class RollingWaveformPainter extends CustomPainter {
  final RollingWaveformController controller;
  final Color pastColor;
  final Color currentColor;
  final Color futureColor;
  final Color playheadColor;

  RollingWaveformPainter({
    required this.controller,
    this.pastColor = const Color(0xFF444444),
    this.currentColor = const Color(0xFF6C63FF),
    this.futureColor = const Color(0xFF888888),
    this.playheadColor = const Color(0xFFFFFFFF),
  }) : super(
            repaint:
                controller); // THÊM: Lắng nghe controller để repaint tự động

  @override
  void paint(Canvas canvas, Size size) {
    final waveformData = controller.waveformData;
    if (waveformData == null || waveformData.samples.isEmpty) {
      return;
    }

    // Playhead ở giữa màn hình
    final playheadX = size.width * 0.5;

    // Vẽ waveform
    _drawWaveform(canvas, size, playheadX, waveformData);

    // Vẽ loop regions
    _drawLoopRegions(canvas, size, playheadX);

    // Vẽ playhead (cuối cùng để nổi bật)
    _drawPlayhead(canvas, size, playheadX);
  }

  void _drawWaveform(
      Canvas canvas, Size size, double playheadX, WaveformData data) {
    if (data.samples.isEmpty ||
        data.duration.inMilliseconds <= 0 ||
        size.width <= 0 ||
        size.height <= 0) {
      return;
    }

    final centerY = size.height / 2;
    final visibleDuration = controller.visibleDuration;
    if (visibleDuration.inMilliseconds == 0) return;
    final halfVisible =
        Duration(milliseconds: visibleDuration.inMilliseconds ~/ 2);

    final windowStart = controller.position - halfVisible;
    final windowEnd = controller.position + halfVisible;

    // Lấy samples trong window
    final startIndex = data.getIndexAtPosition(Duration(
        milliseconds:
            windowStart.inMilliseconds.clamp(0, data.duration.inMilliseconds)));
    final endIndex = data.getIndexAtPosition(Duration(
        milliseconds:
            windowEnd.inMilliseconds.clamp(0, data.duration.inMilliseconds)));

    // Downsample nếu quá nhiều points
    final visibleSamples = data.samples.sublist(
      startIndex.clamp(0, data.samples.length),
      endIndex.clamp(0, data.samples.length),
    );

    // Tránh lỗi chia cho 0 nếu size.width = 0
    if (size.width <= 0) return;

    const double barWidth = 2.0;
    const double spacing = 1.0;
    final double step = barWidth + spacing;

    final barsCount = size.width / step;
    if (barsCount <= 0) return;

    final samplesPerStep = visibleSamples.length / barsCount;
    if (samplesPerStep.isNaN ||
        samplesPerStep.isInfinite ||
        samplesPerStep <= 0) {
      return;
    }

    for (double x = 0; x < size.width; x += step) {
      final sampleIndex = (x / step * samplesPerStep).floor();
      if (sampleIndex >= visibleSamples.length) break;
      if (sampleIndex < 0) continue;

      final amplitude = visibleSamples[sampleIndex];
      final safeAmplitude =
          amplitude.isFinite ? amplitude.clamp(0.0, 1.0) : 0.0;
      final barHeight = safeAmplitude * (size.height / 2) * 0.9;

      Color barColor;
      if (x < playheadX - 5) {
        barColor = pastColor; // Quá khứ
      } else if (x > playheadX + 5) {
        barColor = futureColor; // Tương lai
      } else {
        barColor = currentColor; // Hiện tại (vùng highlight)
      }

      // Vẽ bar (symmetric)
      final rect = Rect.fromLTWH(
        x,
        centerY - barHeight / 2,
        barWidth,
        barHeight,
      );

      final paint = Paint()
        ..color = barColor
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(1)),
        paint,
      );
    }
  }

  void _drawLoopRegions(Canvas canvas, Size size, double playheadX) {
    for (final region in controller.loopRegions) {
      // Tính vị trí screen của loop markers
      final startX = _positionToScreenX(region.start, size.width, playheadX);
      final endX = _positionToScreenX(region.end, size.width, playheadX);

      // Chỉ vẽ nếu ít nhất một phần của vùng loop nằm trong màn hình
      if (startX == null && endX == null) continue;

      // Xử lý trường hợp một đầu nằm ngoài màn hình
      final drawStartX = startX ??
          (region.start < controller.position ? -100.0 : size.width + 100.0);
      final drawEndX = endX ??
          (region.end < controller.position ? -100.0 : size.width + 100.0);

      // Vẽ vùng loop (overlay)
      // Clamp coordinates để tránh lỗi render khi giá trị quá lớn
      final safeStartX = drawStartX.clamp(-10000.0, size.width + 10000.0);
      final safeEndX = drawEndX.clamp(-10000.0, size.width + 10000.0);
      final safeWidth =
          (safeEndX - safeStartX).clamp(0.0, size.width + 20000.0);

      final loopRect = Rect.fromLTWH(
        safeStartX,
        0,
        safeWidth,
        size.height,
      );

      final loopPaint = Paint()
        ..color = region.color.withValues(alpha: 0.1)
        ..style = PaintingStyle.fill;

      canvas.drawRect(loopRect, loopPaint);

      // Vẽ marker A (start) nếu trong màn hình
      if (startX != null) {
        _drawLoopMarker(canvas, size, startX, 'A', region.color);
      }

      // Vẽ marker B (end) nếu trong màn hình
      if (endX != null) {
        _drawLoopMarker(canvas, size, endX, 'B', region.color);
      }
    }
  }

  void _drawLoopMarker(
      Canvas canvas, Size size, double x, String label, Color color) {
    // Vẽ line
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      linePaint,
    );

    // Vẽ label
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(x - textPainter.width / 2, 4),
    );
  }

  void _drawPlayhead(Canvas canvas, Size size, double playheadX) {
    final paint = Paint()
      ..color = playheadColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Vẽ line
    canvas.drawLine(
      Offset(playheadX, 0),
      Offset(playheadX, size.height),
      paint,
    );

    // Vẽ triangle đầu
    final path = Path()
      ..moveTo(playheadX - 6, 0)
      ..lineTo(playheadX + 6, 0)
      ..lineTo(playheadX, 8)
      ..close();

    final trianglePaint = Paint()
      ..color = playheadColor
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, trianglePaint);
  }

  double? _positionToScreenX(
      Duration position, double screenWidth, double playheadX) {
    final delta = position.inMilliseconds - controller.position.inMilliseconds;
    final visibleMs = controller.visibleDuration.inMilliseconds;
    if (visibleMs == 0) return null;
    final halfVisibleMs = visibleMs / 2;

    // Kiểm tra nếu position nằm ngoài visible window
    if (delta.abs() > halfVisibleMs) return null;

    // Tính X dựa vào khoảng cách từ playhead
    final pixelsPerMs = screenWidth / visibleMs;
    return playheadX + (delta * pixelsPerMs);
  }

  @override
  bool shouldRepaint(covariant RollingWaveformPainter oldDelegate) {
    // Tối ưu hóa: Tránh repaint khi sai lệch vị trí cực nhỏ (< 5ms)
    return oldDelegate.controller.position != controller.position ||
        oldDelegate.controller.zoom != controller.zoom ||
        oldDelegate.controller.waveformData != controller.waveformData ||
        !listEquals(
            oldDelegate.controller.loopRegions, controller.loopRegions) ||
        oldDelegate.currentColor != currentColor ||
        oldDelegate.pastColor != pastColor;
  }
}
