import 'dart:math';
import 'package:flutter/material.dart';
import '../models/audio_marker.dart';

class AdvancedWaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final double zoomLevel;
  final double scrollOffset;
  final Duration audioDuration;
  final Duration currentPosition;
  final Duration? selectionStart;
  final Duration? selectionEnd;
  final List<AudioMarker> markers;
  final AudioMarker? selectedMarker;
  final Color waveColor;
  final Color playedColor;
  final Color selectionColor;
  final bool showGrid;
  final bool showTimeLabels;

  AdvancedWaveformPainter({
    required this.waveformData,
    required this.zoomLevel,
    required this.scrollOffset,
    required this.audioDuration,
    required this.currentPosition,
    this.selectionStart,
    this.selectionEnd,
    required this.markers,
    this.selectedMarker,
    this.waveColor = const Color(0xFF6C63FF),
    this.playedColor = const Color(0xFF4CAF50),
    this.selectionColor = const Color(0xFFFFD700),
    this.showGrid = true,
    this.showTimeLabels = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;

    final height = size.height;
    final width = size.width;
    final centerY = height / 2;

    // Tính phạm vi hiển thị
    final visibleRange = 1.0 / zoomLevel;
    final startIndex = (scrollOffset * waveformData.length).floor();
    final endIndex = min(
      waveformData.length,
      ((scrollOffset + visibleRange) * waveformData.length).ceil(),
    );

    // Vẽ grid nếu bật
    if (showGrid) {
      _drawGrid(canvas, size, startIndex, endIndex);
    }

    // Vẽ selection
    if (selectionStart != null) {
      _drawSelection(canvas, size);
    }

    // Vẽ markers (regions trước)
    for (final marker in markers.where((m) => m.isRegion)) {
      _drawMarkerRegion(canvas, size, marker);
    }

    // Vẽ waveform
    _drawWaveform(canvas, size, startIndex, endIndex, centerY);

    // Vẽ markers (points sau)
    for (final marker in markers.where((m) => m.isPoint)) {
      _drawMarkerPoint(canvas, size, marker);
    }

    // Vẽ marker labels
    for (final marker in markers) {
      _drawMarkerLabel(canvas, size, marker);
    }

    // Vẽ playhead (vị trí hiện tại)
    _drawPlayhead(canvas, size);

    // Vẽ time labels
    if (showTimeLabels) {
      _drawTimeLabels(canvas, size, startIndex, endIndex);
    }
  }

  void _drawGrid(Canvas canvas, Size size, int startIndex, int endIndex) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1;

    // Horizontal center line
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );

    // Vertical grid lines (based on time)
    if (audioDuration.inMilliseconds == 0) return;

    final visibleDurationMs = audioDuration.inMilliseconds / zoomLevel;
    final startTimeMs = scrollOffset * audioDuration.inMilliseconds;

    // Tính khoảng cách grid phù hợp với zoom
    double gridIntervalMs;
    if (visibleDurationMs < 1000) {
      gridIntervalMs = 100; // 0.1 giây
    } else if (visibleDurationMs < 5000) {
      gridIntervalMs = 500; // 0.5 giây
    } else if (visibleDurationMs < 30000) {
      gridIntervalMs = 1000; // 1 giây
    } else if (visibleDurationMs < 60000) {
      gridIntervalMs = 5000; // 5 giây
    } else {
      gridIntervalMs = 10000; // 10 giây
    }

    final firstGridMs = (startTimeMs / gridIntervalMs).ceil() * gridIntervalMs;

    for (double ms = firstGridMs; ms < startTimeMs + visibleDurationMs; ms += gridIntervalMs) {
      final x = _timeToX(Duration(milliseconds: ms.toInt()), size.width);
      if (x >= 0 && x <= size.width) {
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, size.height),
          paint,
        );
      }
    }
  }

  void _drawWaveform(Canvas canvas, Size size, int startIndex, int endIndex, double centerY) {
    if (startIndex >= endIndex) return;

    final samplesInView = endIndex - startIndex;
    final pixelsPerSample = size.width / samplesInView;

    // Paint cho phần chưa phát
    final unplayedPaint = Paint()
      ..color = waveColor
      ..strokeWidth = max(1, pixelsPerSample * 0.8)
      ..strokeCap = StrokeCap.round;

    // Paint cho phần đã phát
    final playedPaint = Paint()
      ..color = playedColor
      ..strokeWidth = max(1, pixelsPerSample * 0.8)
      ..strokeCap = StrokeCap.round;

    // Vị trí hiện tại
    final currentX = _timeToX(currentPosition, size.width);

    for (int i = startIndex; i < endIndex; i++) {
      final x = (i - startIndex) * pixelsPerSample;
      final amplitude = waveformData[i] * (size.height * 0.4);

      final paint = x < currentX ? playedPaint : unplayedPaint;

      // Vẽ cả phía trên và phía dưới
      canvas.drawLine(
        Offset(x, centerY - amplitude),
        Offset(x, centerY + amplitude),
        paint,
      );
    }
  }

  void _drawSelection(Canvas canvas, Size size) {
    if (selectionStart == null) return;

    final startX = _timeToX(selectionStart!, size.width);
    final endX = selectionEnd != null
        ? _timeToX(selectionEnd!, size.width)
        : startX;

    final left = min(startX, endX);
    final right = max(startX, endX);

    // Vùng chọn
    final rect = Rect.fromLTRB(left, 0, right, size.height);
    final paint = Paint()
      ..color = selectionColor.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, paint);

    // Viền
    final borderPaint = Paint()
      ..color = selectionColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(rect, borderPaint);
  }

  void _drawMarkerRegion(Canvas canvas, Size size, AudioMarker marker) {
    final startX = _timeToX(marker.startTime, size.width);
    final endX = _timeToX(marker.endTime!, size.width);

    if (endX < 0 || startX > size.width) return;

    final left = max(0.0, startX);
    final right = min(size.width, endX);

    // Vùng đánh dấu
    final rect = Rect.fromLTRB(left, 0, right, size.height);
    final isSelected = marker.id == selectedMarker?.id;

    final paint = Paint()
      ..color = marker.color.withOpacity(isSelected ? 0.4 : 0.2)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, paint);

    // Viền
    final borderPaint = Paint()
      ..color = marker.color
      ..strokeWidth = isSelected ? 3 : 2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(rect, borderPaint);
  }

  void _drawMarkerPoint(Canvas canvas, Size size, AudioMarker marker) {
    final x = _timeToX(marker.startTime, size.width);
    if (x < 0 || x > size.width) return;

    final isSelected = marker.id == selectedMarker?.id;

    // Đường dọc
    final linePaint = Paint()
      ..color = marker.color
      ..strokeWidth = isSelected ? 3 : 2;
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      linePaint,
    );

    // Đầu marker (hình tam giác)
    final path = Path()
      ..moveTo(x - 8, 0)
      ..lineTo(x + 8, 0)
      ..lineTo(x, 12)
      ..close();

    final markerPaint = Paint()
      ..color = marker.color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, markerPaint);
  }

  void _drawMarkerLabel(Canvas canvas, Size size, AudioMarker marker) {
    if (marker.label.isEmpty) return;

    final x = _timeToX(marker.startTime, size.width);
    if (x < -50 || x > size.width + 50) return;

    // Background cho label
    final textSpan = TextSpan(
      text: marker.label,
      style: TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        backgroundColor: marker.color.withOpacity(0.8),
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    // Vẽ ở phía trên
    final labelX = (x - textPainter.width / 2).clamp(0.0, size.width - textPainter.width);
    textPainter.paint(canvas, Offset(labelX, 14));
  }

  void _drawPlayhead(Canvas canvas, Size size) {
    final x = _timeToX(currentPosition, size.width);
    if (x < 0 || x > size.width) return;

    // Đường playhead
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      paint,
    );

    // Đầu playhead
    final headPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(x - 6, 0)
      ..lineTo(x + 6, 0)
      ..lineTo(x, 10)
      ..close();
    canvas.drawPath(path, headPaint);
  }

  void _drawTimeLabels(Canvas canvas, Size size, int startIndex, int endIndex) {
    if (audioDuration.inMilliseconds == 0) return;

    final visibleDurationMs = audioDuration.inMilliseconds / zoomLevel;
    final startTimeMs = scrollOffset * audioDuration.inMilliseconds;

    // Tính khoảng cách label
    double labelIntervalMs;
    if (visibleDurationMs < 2000) {
      labelIntervalMs = 500;
    } else if (visibleDurationMs < 10000) {
      labelIntervalMs = 1000;
    } else if (visibleDurationMs < 60000) {
      labelIntervalMs = 5000;
    } else {
      labelIntervalMs = 10000;
    }

    final firstLabelMs = (startTimeMs / labelIntervalMs).ceil() * labelIntervalMs;

    for (double ms = firstLabelMs; ms < startTimeMs + visibleDurationMs; ms += labelIntervalMs) {
      final x = _timeToX(Duration(milliseconds: ms.toInt()), size.width);
      if (x >= 0 && x <= size.width - 30) {
        final timeText = _formatTime(Duration(milliseconds: ms.toInt()));

        final textSpan = TextSpan(
          text: timeText,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 9,
          ),
        );

        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(canvas, Offset(x - textPainter.width / 2, size.height - 12));
      }
    }
  }

  double _timeToX(Duration time, double width) {
    if (audioDuration.inMilliseconds == 0) return 0;

    final timeRatio = time.inMilliseconds / audioDuration.inMilliseconds;
    final visibleRange = 1.0 / zoomLevel;
    final relativePosition = (timeRatio - scrollOffset) / visibleRange;

    return relativePosition * width;
  }

  String _formatTime(Duration d) {
    if (d.inMilliseconds < 1000) {
      return '${d.inMilliseconds}ms';
    } else if (d.inSeconds < 60) {
      final secs = d.inSeconds;
      final ms = d.inMilliseconds % 1000 ~/ 100;
      return '$secs.${ms}s';
    } else {
      final mins = d.inMinutes;
      final secs = d.inSeconds % 60;
      return '$mins:${secs.toString().padLeft(2, '0')}';
    }
  }

  @override
  bool shouldRepaint(covariant AdvancedWaveformPainter oldDelegate) {
    return waveformData != oldDelegate.waveformData ||
        zoomLevel != oldDelegate.zoomLevel ||
        scrollOffset != oldDelegate.scrollOffset ||
        currentPosition != oldDelegate.currentPosition ||
        selectionStart != oldDelegate.selectionStart ||
        selectionEnd != oldDelegate.selectionEnd ||
        markers != oldDelegate.markers ||
        selectedMarker != oldDelegate.selectedMarker;
  }
}