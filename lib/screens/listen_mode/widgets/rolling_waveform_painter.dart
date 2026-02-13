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
    final centerY = size.height / 2;

    // Tính toán window hiển thị
    final visibleDuration = controller.visibleDuration;
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

    final samplesPerPixel = visibleSamples.length / size.width;

    // Vẽ từng bar
    for (int i = 0; i < size.width.toInt(); i++) {
      final sampleIndex = (i * samplesPerPixel).floor();
      if (sampleIndex >= visibleSamples.length) break;

      final amplitude = visibleSamples[sampleIndex];
      final barHeight = amplitude * (size.height / 2) * 0.9; // 90% max height

      // Xác định màu dựa vào vị trí so với playhead
      Color barColor;
      if (i < playheadX - 5) {
        barColor = pastColor; // Quá khứ
      } else if (i > playheadX + 5) {
        barColor = futureColor; // Tương lai
      } else {
        barColor = currentColor; // Hiện tại (vùng highlight)
      }

      // Vẽ bar (symmetric)
      final rect = Rect.fromLTWH(
        i.toDouble(),
        centerY - barHeight / 2,
        1.5, // bar width
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
      final loopRect = Rect.fromLTWH(
        drawStartX,
        0,
        drawEndX - drawStartX,
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
    final halfVisibleMs = visibleMs / 2;

    // Kiểm tra nếu position nằm ngoài visible window
    if (delta.abs() > halfVisibleMs) return null;

    // Tính X dựa vào khoảng cách từ playhead
    final pixelsPerMs = screenWidth / visibleMs;
    return playheadX + (delta * pixelsPerMs);
  }

  @override
  bool shouldRepaint(covariant RollingWaveformPainter oldDelegate) {
    // SỬA LỖI: Luôn trả về true hoặc so sánh properties nếu cần thiết.
    // Vì controller là mutable object, so sánh reference (==) sẽ luôn trả về false.
    return true;
  }
}
