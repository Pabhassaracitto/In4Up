// lib/widgets/advanced_waveform_painter.dart
// VipSound - Advanced Waveform Painter
// Version 2.0 - Beautiful visualization with mode-aware theming

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/audio_marker.dart';

class AdvancedWaveformPainter extends CustomPainter {
  // Data
  final List<double> waveformData;
  final double zoomLevel;
  final double scrollOffset;
  final Duration audioDuration;
  final Duration currentPosition;

  // Selection
  final Duration? selectionStart;
  final Duration? selectionEnd;

  // Markers
  final List<AudioMarker> markers;
  final AudioMarker? selectedMarker;

  // Loop
  final Duration? loopStart;
  final Duration? loopEnd;
  final bool isLooping;

  // Theme Colors (với defaults)
  final Color waveformColor;
  final Color waveformPlayedColor;
  final Color selectionColor;
  final Color gridColor;
  final Color playheadColor;
  final Color backgroundColor;

  // Style options
  final bool showGrid;
  final bool showTimeLabels;
  final bool showCenterLine;
  final bool mirrorWaveform;
  final double waveformStyle; // 0 = bars, 1 = smooth curve

  AdvancedWaveformPainter({
    required this.waveformData,
    this.zoomLevel = 1.0,
    this.scrollOffset = 0.0,
    this.audioDuration = Duration.zero,
    this.currentPosition = Duration.zero,
    this.selectionStart,
    this.selectionEnd,
    this.markers = const [],
    this.selectedMarker,
    this.loopStart,
    this.loopEnd,
    this.isLooping = false,
    // Theme colors with defaults
    this.waveformColor = const Color(0xFFB39DDB),
    this.waveformPlayedColor = const Color(0xFF6C63FF),
    this.selectionColor = const Color(0x406C63FF),
    this.gridColor = const Color(0x206C63FF),
    this.playheadColor = const Color(0xFFFF5252),
    this.backgroundColor = const Color(0xFF1A1A2E),
    // Style options
    this.showGrid = true,
    this.showTimeLabels = true,
    this.showCenterLine = true,
    this.mirrorWaveform = true,
    this.waveformStyle = 0.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) {
      _drawEmptyState(canvas, size);
      return;
    }

    // Draw layers in order (back to front)
    _drawBackground(canvas, size);
    _drawGrid(canvas, size);
    _drawLoopRegion(canvas, size);
    _drawSelection(canvas, size);
    _drawMarkerRegions(canvas, size);
    _drawWaveform(canvas, size);
    _drawMarkerPoints(canvas, size);
    _drawPlayhead(canvas, size);
    _drawTimeLabels(canvas, size);
  }

  // ==================== EMPTY STATE ====================

  void _drawEmptyState(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = waveformColor.withOpacity(0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw placeholder wave pattern
    final path = Path();
    final centerY = size.height / 2;

    for (double x = 0; x < size.width; x += 20) {
      final y = centerY + math.sin(x * 0.05) * 20;
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // Draw text
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Đang chờ dữ liệu sóng âm...',
        style: TextStyle(
          color: waveformColor.withOpacity(0.5),
          fontSize: 12,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );
  }

  // ==================== BACKGROUND ====================

  void _drawBackground(Canvas canvas, Size size) {
    // Gradient background
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        backgroundColor.withOpacity(0.8),
        backgroundColor,
        backgroundColor.withOpacity(0.8),
      ],
    );

    canvas.drawRect(
      rect,
      Paint()..shader = gradient.createShader(rect),
    );

    // Center line
    if (showCenterLine) {
      final centerPaint = Paint()
        ..color = waveformColor.withOpacity(0.2)
        ..strokeWidth = 1;

      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        centerPaint,
      );
    }
  }

  // ==================== GRID ====================

  void _drawGrid(Canvas canvas, Size size) {
    if (!showGrid || audioDuration.inMilliseconds == 0) return;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    // Calculate visible range
    final visibleRange = 1.0 / zoomLevel;
    final startRatio = scrollOffset;
    final endRatio = scrollOffset + visibleRange;

    // Calculate grid interval based on zoom level
    double intervalSeconds;
    if (zoomLevel < 2) {
      intervalSeconds = 30; // 30 second intervals
    } else if (zoomLevel < 5) {
      intervalSeconds = 10; // 10 second intervals
    } else if (zoomLevel < 15) {
      intervalSeconds = 5; // 5 second intervals
    } else if (zoomLevel < 30) {
      intervalSeconds = 2; // 2 second intervals
    } else if (zoomLevel < 60) {
      intervalSeconds = 1; // 1 second intervals
    } else {
      intervalSeconds = 0.5; // 0.5 second intervals
    }

    final totalSeconds = audioDuration.inMilliseconds / 1000;
    final startSecond = (startRatio * totalSeconds / intervalSeconds).floor() * intervalSeconds;
    final endSecond = endRatio * totalSeconds;

    // Draw vertical grid lines
    for (double sec = startSecond; sec <= endSecond; sec += intervalSeconds) {
      final ratio = sec / totalSeconds;
      final x = _ratioToX(ratio, size.width);

      if (x >= 0 && x <= size.width) {
        // Main grid line
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, size.height),
          gridPaint,
        );

        // Sub-grid lines (lighter)
        if (zoomLevel > 10 && intervalSeconds >= 1) {
          final subGridPaint = Paint()
            ..color = gridColor.withOpacity(0.3)
            ..strokeWidth = 0.3;

          for (int i = 1; i < 4; i++) {
            final subSec = sec + (intervalSeconds / 4) * i;
            final subRatio = subSec / totalSeconds;
            final subX = _ratioToX(subRatio, size.width);

            if (subX >= 0 && subX <= size.width) {
              canvas.drawLine(
                Offset(subX, size.height * 0.3),
                Offset(subX, size.height * 0.7),
                subGridPaint,
              );
            }
          }
        }
      }
    }

    // Draw horizontal grid lines
    final horizontalGridPaint = Paint()
      ..color = gridColor.withOpacity(0.3)
      ..strokeWidth = 0.3;

    for (int i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        horizontalGridPaint,
      );
    }
  }

  // ==================== LOOP REGION ====================

  void _drawLoopRegion(Canvas canvas, Size size) {
    if (loopStart == null || loopEnd == null) return;
    if (audioDuration.inMilliseconds == 0) return;

    final startRatio = loopStart!.inMilliseconds / audioDuration.inMilliseconds;
    final endRatio = loopEnd!.inMilliseconds / audioDuration.inMilliseconds;

    final startX = _ratioToX(startRatio, size.width);
    final endX = _ratioToX(endRatio, size.width);

    if (endX < 0 || startX > size.width) return;

    final clampedStartX = startX.clamp(0.0, size.width);
    final clampedEndX = endX.clamp(0.0, size.width);

    // Loop region background
    final loopColor = isLooping
        ? const Color(0xFF4CAF50)
        : const Color(0xFFFF9800);

    final loopRect = Rect.fromLTRB(clampedStartX, 0, clampedEndX, size.height);

    // Gradient fill
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        loopColor.withOpacity(0.3),
        loopColor.withOpacity(0.1),
        loopColor.withOpacity(0.3),
      ],
    );

    canvas.drawRect(
      loopRect,
      Paint()..shader = gradient.createShader(loopRect),
    );

    // Loop region border
    final borderPaint = Paint()
      ..color = loopColor.withOpacity(0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawRect(loopRect, borderPaint);

    // A marker
    _drawLoopMarker(canvas, clampedStartX, size.height, 'A', loopColor);

    // B marker
    _drawLoopMarker(canvas, clampedEndX, size.height, 'B', loopColor);

    // Glow effect when looping
    if (isLooping) {
      final glowPaint = Paint()
        ..color = loopColor.withOpacity(0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

      canvas.drawRect(loopRect, glowPaint);
    }
  }

  void _drawLoopMarker(Canvas canvas, double x, double height, String label, Color color) {
    // Triangle marker at top
    final trianglePath = Path()
      ..moveTo(x, 0)
      ..lineTo(x - 8, -12)
      ..lineTo(x + 8, -12)
      ..close();

    canvas.drawPath(
      trianglePath,
      Paint()..color = color,
    );

    // Label
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(x - textPainter.width / 2, -10),
    );

    // Vertical line
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(x, 0),
      Offset(x, height),
      linePaint,
    );
  }

  // ==================== SELECTION ====================

  void _drawSelection(Canvas canvas, Size size) {
    if (selectionStart == null) return;
    if (audioDuration.inMilliseconds == 0) return;

    final startRatio = selectionStart!.inMilliseconds / audioDuration.inMilliseconds;
    final startX = _ratioToX(startRatio, size.width);

    if (selectionEnd != null) {
      // Draw selection range
      final endRatio = selectionEnd!.inMilliseconds / audioDuration.inMilliseconds;
      final endX = _ratioToX(endRatio, size.width);

      final clampedStartX = math.min(startX, endX).clamp(0.0, size.width);
      final clampedEndX = math.max(startX, endX).clamp(0.0, size.width);

      final selectionRect = Rect.fromLTRB(clampedStartX, 0, clampedEndX, size.height);

      // Selection fill with animation-like pattern
      final selectionPaint = Paint()..color = selectionColor;
      canvas.drawRect(selectionRect, selectionPaint);

      // Selection border (dashed effect)
      final borderPaint = Paint()
        ..color = waveformPlayedColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      canvas.drawRect(selectionRect, borderPaint);

      // Selection handles
      _drawSelectionHandle(canvas, clampedStartX, size.height);
      _drawSelectionHandle(canvas, clampedEndX, size.height);

      // Duration label
      final duration = (selectionEnd! - selectionStart!).abs();
      _drawDurationLabel(canvas, clampedStartX, clampedEndX, size.height, duration);
    } else {
      // Draw selection start line
      if (startX >= 0 && startX <= size.width) {
        final linePaint = Paint()
          ..color = waveformPlayedColor
          ..strokeWidth = 2;

        canvas.drawLine(
          Offset(startX, 0),
          Offset(startX, size.height),
          linePaint,
        );

        _drawSelectionHandle(canvas, startX, size.height);
      }
    }
  }

  void _drawSelectionHandle(Canvas canvas, double x, double height) {
    final handlePaint = Paint()
      ..color = waveformPlayedColor
      ..style = PaintingStyle.fill;

    // Top handle
    canvas.drawCircle(Offset(x, 8), 6, handlePaint);

    // Bottom handle
    canvas.drawCircle(Offset(x, height - 8), 6, handlePaint);

    // Inner circle (white)
    final innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(x, 8), 3, innerPaint);
    canvas.drawCircle(Offset(x, height - 8), 3, innerPaint);
  }

  void _drawDurationLabel(Canvas canvas, double startX, double endX, double height, Duration duration) {
    final text = _formatDuration(duration);

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: waveformPlayedColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final centerX = (startX + endX) / 2;
    final labelX = centerX - textPainter.width / 2;

    // Background
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        labelX - 6,
        height / 2 - textPainter.height / 2 - 4,
        textPainter.width + 12,
        textPainter.height + 8,
      ),
      const Radius.circular(4),
    );

    canvas.drawRRect(
      bgRect,
      Paint()..color = waveformPlayedColor.withOpacity(0.9),
    );

    textPainter.paint(
      canvas,
      Offset(labelX, height / 2 - textPainter.height / 2),
    );
  }

  // ==================== MARKER REGIONS ====================

  void _drawMarkerRegions(Canvas canvas, Size size) {
    if (audioDuration.inMilliseconds == 0) return;

    for (final marker in markers) {
      if (!marker.isRegion) continue;

      final startRatio = marker.startTime.inMilliseconds / audioDuration.inMilliseconds;
      final endRatio = marker.endTime!.inMilliseconds / audioDuration.inMilliseconds;

      final startX = _ratioToX(startRatio, size.width);
      final endX = _ratioToX(endRatio, size.width);

      if (endX < 0 || startX > size.width) continue;

      final clampedStartX = startX.clamp(0.0, size.width);
      final clampedEndX = endX.clamp(0.0, size.width);

      final isSelected = selectedMarker?.id == marker.id;
      final opacity = isSelected ? 0.4 : 0.2;

      final rect = Rect.fromLTRB(clampedStartX, 0, clampedEndX, size.height);

      // Region fill
      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          marker.color.withOpacity(opacity),
          marker.color.withOpacity(opacity * 0.5),
          marker.color.withOpacity(opacity),
        ],
      );

      canvas.drawRect(
        rect,
        Paint()..shader = gradient.createShader(rect),
      );

      // Region border
      if (isSelected) {
        final borderPaint = Paint()
          ..color = marker.color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;

        canvas.drawRect(rect, borderPaint);

        // Glow effect
        final glowPaint = Paint()
          ..color = marker.color.withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

        canvas.drawRect(rect, glowPaint);
      }

      // Label at top
      if (marker.label.isNotEmpty && (clampedEndX - clampedStartX) > 30) {
        _drawRegionLabel(canvas, clampedStartX, clampedEndX, marker.label, marker.color);
      }
    }
  }

  void _drawRegionLabel(Canvas canvas, double startX, double endX, String label, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    );

    final maxWidth = (endX - startX) - 8;
    textPainter.layout(maxWidth: maxWidth > 20 ? maxWidth : 20);

    final labelX = startX + 4;
    final labelY = 4.0;

    // Background
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        labelX - 2,
        labelY,
        textPainter.width + 4,
        textPainter.height + 4,
      ),
      const Radius.circular(3),
    );

    canvas.drawRRect(
      bgRect,
      Paint()..color = color.withOpacity(0.8),
    );

    textPainter.paint(canvas, Offset(labelX, labelY + 2));
  }

  // ==================== WAVEFORM ====================

  void _drawWaveform(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;

    final visibleRange = 1.0 / zoomLevel;
    final startIndex = (scrollOffset * waveformData.length).floor();
    final endIndex = ((scrollOffset + visibleRange) * waveformData.length).ceil();

    final clampedStart = startIndex.clamp(0, waveformData.length - 1);
    final clampedEnd = endIndex.clamp(0, waveformData.length);

    final samplesPerPixel = (clampedEnd - clampedStart) / size.width;
    final barWidth = math.max(1.0, size.width / (clampedEnd - clampedStart) - 0.5);

    final centerY = size.height / 2;
    final maxAmplitude = size.height * 0.45;

    // Calculate current position for played portion
    double playedRatio = 0;
    if (audioDuration.inMilliseconds > 0) {
      playedRatio = currentPosition.inMilliseconds / audioDuration.inMilliseconds;
    }

    // Draw waveform bars
    for (int i = clampedStart; i < clampedEnd; i++) {
      final x = (i - clampedStart) / (clampedEnd - clampedStart) * size.width;
      final amplitude = waveformData[i].clamp(0.0, 1.0);
      final barHeight = amplitude * maxAmplitude;

      // Determine if this bar is "played"
      final sampleRatio = i / waveformData.length;
      final isPlayed = sampleRatio <= playedRatio;

      // Check if in loop region
      bool isInLoop = false;
      if (loopStart != null && loopEnd != null && audioDuration.inMilliseconds > 0) {
        final loopStartRatio = loopStart!.inMilliseconds / audioDuration.inMilliseconds;
        final loopEndRatio = loopEnd!.inMilliseconds / audioDuration.inMilliseconds;
        isInLoop = sampleRatio >= loopStartRatio && sampleRatio <= loopEndRatio;
      }

      // Choose color
      Color barColor;
      if (isPlayed) {
        barColor = waveformPlayedColor;
      } else if (isInLoop && isLooping) {
        barColor = waveformColor.withOpacity(0.8);
      } else {
        barColor = waveformColor.withOpacity(0.6);
      }

      // Create gradient for each bar
      final barGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          barColor,
          barColor.withOpacity(0.7),
          barColor,
        ],
      );

      final barRect = mirrorWaveform
          ? Rect.fromCenter(
        center: Offset(x, centerY),
        width: barWidth,
        height: barHeight * 2,
      )
          : Rect.fromLTWH(
        x,
        centerY - barHeight,
        barWidth,
        barHeight,
      );

      final paint = Paint()
        ..shader = barGradient.createShader(barRect);

      // Draw with rounded corners for smoother look
      canvas.drawRRect(
        RRect.fromRectAndRadius(barRect, Radius.circular(barWidth / 2)),
        paint,
      );

      // Add subtle glow for played portion
      if (isPlayed) {
        final glowPaint = Paint()
          ..color = waveformPlayedColor.withOpacity(0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

        canvas.drawRRect(
          RRect.fromRectAndRadius(barRect, Radius.circular(barWidth / 2)),
          glowPaint,
        );
      }
    }
  }

  // ==================== MARKER POINTS ====================

  void _drawMarkerPoints(Canvas canvas, Size size) {
    if (audioDuration.inMilliseconds == 0) return;

    for (final marker in markers) {
      if (marker.isRegion) continue;

      final ratio = marker.startTime.inMilliseconds / audioDuration.inMilliseconds;
      final x = _ratioToX(ratio, size.width);

      if (x < -10 || x > size.width + 10) continue;

      final isSelected = selectedMarker?.id == marker.id;

      // Vertical line
      final linePaint = Paint()
        ..color = marker.color.withOpacity(isSelected ? 1.0 : 0.7)
        ..strokeWidth = isSelected ? 3 : 2;

      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        linePaint,
      );

      // Marker icon/diamond at center
      _drawMarkerIcon(canvas, x, size.height / 2, marker, isSelected);

      // Top indicator
      _drawMarkerTopIndicator(canvas, x, marker, isSelected);

      // Glow effect if selected
      if (isSelected) {
        final glowPaint = Paint()
          ..color = marker.color.withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

        canvas.drawLine(
          Offset(x, 0),
          Offset(x, size.height),
          glowPaint..strokeWidth = 6,
        );
      }
    }
  }

  void _drawMarkerIcon(Canvas canvas, double x, double y, AudioMarker marker, bool isSelected) {
    final size = isSelected ? 14.0 : 10.0;

    // Diamond shape
    final path = Path()
      ..moveTo(x, y - size)
      ..lineTo(x + size, y)
      ..lineTo(x, y + size)
      ..lineTo(x - size, y)
      ..close();

    // Fill
    canvas.drawPath(
      path,
      Paint()..color = marker.color,
    );

    // Border
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withOpacity(0.8)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    // Inner icon based on type
    final iconPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    switch (marker.type) {
      case MarkerType.difficult:
      // Exclamation mark
        canvas.drawCircle(Offset(x, y + 2), 1.5, iconPaint);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(x, y - 2), width: 2, height: 5),
            const Radius.circular(1),
          ),
          iconPaint,
        );
        break;
      case MarkerType.important:
      // Star-like
        canvas.drawCircle(Offset(x, y), 3, iconPaint);
        break;
      default:
      // Simple dot
        canvas.drawCircle(Offset(x, y), 2, iconPaint);
    }
  }

  void _drawMarkerTopIndicator(Canvas canvas, double x, AudioMarker marker, bool isSelected) {
    final triangleSize = isSelected ? 8.0 : 6.0;

    final path = Path()
      ..moveTo(x, triangleSize)
      ..lineTo(x - triangleSize, 0)
      ..lineTo(x + triangleSize, 0)
      ..close();

    canvas.drawPath(
      path,
      Paint()..color = marker.color,
    );

    // Label if selected
    if (isSelected && marker.label.isNotEmpty) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: marker.label,
          style: TextStyle(
            color: marker.color,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      // Position label to avoid edge
      var labelX = x - textPainter.width / 2;
      labelX = labelX.clamp(4.0, double.infinity);

      textPainter.paint(canvas, Offset(labelX, triangleSize + 4));
    }
  }

  // ==================== PLAYHEAD ====================

  void _drawPlayhead(Canvas canvas, Size size) {
    if (audioDuration.inMilliseconds == 0) return;

    final ratio = currentPosition.inMilliseconds / audioDuration.inMilliseconds;
    final x = _ratioToX(ratio, size.width);

    if (x < 0 || x > size.width) return;

    // Glow effect
    final glowPaint = Paint()
      ..color = playheadColor.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      glowPaint..strokeWidth = 8,
    );

    // Main line
    final linePaint = Paint()
      ..color = playheadColor
      ..strokeWidth = 2.5;

    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      linePaint,
    );

    // Top triangle
    final trianglePath = Path()
      ..moveTo(x, 0)
      ..lineTo(x - 6, -8)
      ..lineTo(x + 6, -8)
      ..close();

    canvas.drawPath(
      trianglePath,
      Paint()..color = playheadColor,
    );

    // Bottom triangle
    final bottomTrianglePath = Path()
      ..moveTo(x, size.height)
      ..lineTo(x - 6, size.height + 8)
      ..lineTo(x + 6, size.height + 8)
      ..close();

    canvas.drawPath(
      bottomTrianglePath,
      Paint()..color = playheadColor,
    );

    // Time label near playhead
    _drawPlayheadTime(canvas, x, size.height);
  }

  void _drawPlayheadTime(Canvas canvas, double x, double height) {
    final text = _formatDuration(currentPosition);

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Position above bottom triangle
    final labelY = height + 12;
    var labelX = x - textPainter.width / 2;

    // Keep label visible
    labelX = labelX.clamp(2.0, double.infinity);

    // Background
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        labelX - 4,
        labelY,
        textPainter.width + 8,
        textPainter.height + 4,
      ),
      const Radius.circular(4),
    );

    canvas.drawRRect(
      bgRect,
      Paint()..color = playheadColor,
    );

    textPainter.paint(canvas, Offset(labelX, labelY + 2));
  }

  // ==================== TIME LABELS ====================

  void _drawTimeLabels(Canvas canvas, Size size) {
    if (!showTimeLabels || audioDuration.inMilliseconds == 0) return;

    final visibleRange = 1.0 / zoomLevel;
    final startRatio = scrollOffset;
    final endRatio = scrollOffset + visibleRange;

    // Calculate label interval
    double intervalSeconds;
    if (zoomLevel < 2) {
      intervalSeconds = 60; // 1 minute intervals
    } else if (zoomLevel < 5) {
      intervalSeconds = 30; // 30 second intervals
    } else if (zoomLevel < 15) {
      intervalSeconds = 10; // 10 second intervals
    } else if (zoomLevel < 30) {
      intervalSeconds = 5; // 5 second intervals
    } else {
      intervalSeconds = 2; // 2 second intervals
    }

    final totalSeconds = audioDuration.inMilliseconds / 1000;
    final startSecond = (startRatio * totalSeconds / intervalSeconds).floor() * intervalSeconds;
    final endSecond = endRatio * totalSeconds;

    for (double sec = startSecond; sec <= endSecond; sec += intervalSeconds) {
      final ratio = sec / totalSeconds;
      final x = _ratioToX(ratio, size.width);

      if (x < 0 || x > size.width - 30) continue;

      final duration = Duration(seconds: sec.toInt());
      final text = _formatTimeLabel(duration);

      final textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: gridColor.withOpacity(2.0).withAlpha(180),
            fontSize: 9,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      // Draw at bottom
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height - textPainter.height - 4),
      );
    }
  }

  // ==================== HELPERS ====================

  double _ratioToX(double ratio, double width) {
    final visibleRange = 1.0 / zoomLevel;
    final normalizedRatio = (ratio - scrollOffset) / visibleRange;
    return normalizedRatio * width;
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes;
    final secs = d.inSeconds % 60;
    final ms = d.inMilliseconds % 1000 ~/ 10;
    return '$mins:${secs.toString().padLeft(2, '0')}.${ms.toString().padLeft(2, '0')}';
  }

  String _formatTimeLabel(Duration d) {
    final mins = d.inMinutes;
    final secs = d.inSeconds % 60;
    if (mins > 0) {
      return '$mins:${secs.toString().padLeft(2, '0')}';
    }
    return '0:${secs.toString().padLeft(2, '0')}';
  }

  @override
  bool shouldRepaint(covariant AdvancedWaveformPainter oldDelegate) {
    return oldDelegate.waveformData != waveformData ||
        oldDelegate.zoomLevel != zoomLevel ||
        oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.currentPosition != currentPosition ||
        oldDelegate.selectionStart != selectionStart ||
        oldDelegate.selectionEnd != selectionEnd ||
        oldDelegate.markers != markers ||
        oldDelegate.selectedMarker != selectedMarker ||
        oldDelegate.loopStart != loopStart ||
        oldDelegate.loopEnd != loopEnd ||
        oldDelegate.isLooping != isLooping ||
        oldDelegate.waveformColor != waveformColor ||
        oldDelegate.waveformPlayedColor != waveformPlayedColor;
  }
}