// in4up v11.0 — Painter đa màu speaker

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../controllers/rolling_waveform_controller.dart';
import '../../../models/waveform_data.dart';

const kSpeakerColors = <int, Color>{
  0: Color(0xFFECEFF1),
  1: Color(0xFF6C63FF),
  2: Color(0xFF4CAF50),
  3: Color(0xFFFF9800),
  4: Color(0xFFE91E63),
};

class RollingWaveformPainter extends CustomPainter {
  final RollingWaveformController controller;

  /// Key = joinKey hoặc segmentUid → speakerId
  /// Rỗng = mono-color (backward compatible)
  final Map<String, int> speakerColorMap;

  RollingWaveformPainter({
    required this.controller,
    this.speakerColorMap = const {},
  }) : super(repaint: controller);

  // Cached paints
  final _playheadPaint = Paint()
    ..color = const Color(0xFF6C63FF)
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;

  final _loopFillPaint = Paint()
    ..color = const Color(0xFF6C63FF).withValues(alpha: 0.15)
    ..style = PaintingStyle.fill;

  final _loopBorderPaint = Paint()
    ..color = const Color(0xFF6C63FF).withValues(alpha: 0.6)
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF0D0F1A),
    );

    final data = controller.waveformData;
    if (data == null || data.samples.isEmpty) {
      _paintEmpty(canvas, size);
      return;
    }

    final totalMs = controller.duration.inMilliseconds;
    if (totalMs <= 0) return;

    final currentMs = controller.position.inMilliseconds;
    final visibleMs = controller.visibleDuration.inMilliseconds;
    final msPerPx = visibleMs / size.width;
    final playheadX = size.width / 2;

    // 1. Speaker background regions
    if (speakerColorMap.isNotEmpty && data.segments != null) {
      _paintSpeakerRegions(
          canvas, size, data.segments!, currentMs, msPerPx, playheadX);
    }

    // 2. Loop regions
    for (final r in controller.loopRegions) {
      _paintLoopRegion(canvas, size, r, totalMs, currentMs, msPerPx, playheadX);
    }

    // 3. Waveform bars
    _paintBars(
        canvas, size, data.samples, totalMs, currentMs, msPerPx, playheadX);

    // 4. Playhead
    _paintPlayhead(canvas, size, playheadX);

    // 5. Time label
    _paintTimeLabel(canvas, size, controller.position, playheadX);
  }

  // ── Speaker Regions ───────────────────────────────────────

  void _paintSpeakerRegions(
    Canvas canvas,
    Size size,
    List<WaveformSegmentRef> segments,
    int currentMs,
    double msPerPx,
    double playheadX,
  ) {
    for (final seg in segments) {
      final speakerId =
          speakerColorMap[seg.joinKey] ?? speakerColorMap[seg.uid] ?? 0;

      final color = kSpeakerColors[speakerId] ?? kSpeakerColors[0]!;
      final endMs = (seg.endSeconds * 1000).round();

      final startX = playheadX + (seg.startMs - currentMs) / msPerPx;
      final endX = playheadX + (endMs - currentMs) / msPerPx;

      if (endX < 0 || startX > size.width) continue;

      final left = startX.clamp(0.0, size.width);
      final right = endX.clamp(0.0, size.width);
      if (right <= left) continue;

      // Background tint
      canvas.drawRect(
        Rect.fromLTWH(left, 0, right - left, size.height),
        Paint()
          ..color = color.withOpacity(speakerId == 0 ? 0.04 : 0.10)
          ..style = PaintingStyle.fill,
      );

      // Speaker boundary marker
      if (speakerId > 0) {
        canvas.drawLine(
          Offset(left, 0),
          Offset(left, size.height * 0.15),
          Paint()
            ..color = color.withValues(alpha: 0.4)
            ..strokeWidth = 1.0,
        );
      }
    }
  }

  // ── Waveform Bars ─────────────────────────────────────────

  void _paintBars(
    Canvas canvas,
    Size size,
    List<double> samples,
    int totalMs,
    int currentMs,
    double msPerPx,
    double playheadX,
  ) {
    const barW = 3.0;
    const spacing = 1.0;
    const step = barW + spacing;
    final barCount = (size.width / step).ceil() + 2;
    final halfH = size.height / 2;

    for (var i = 0; i < barCount; i++) {
      final barX = i * step;
      final barCenterX = barX + barW / 2;
      final barMs = currentMs + ((barCenterX - playheadX) * msPerPx).round();

      if (barMs < 0 || barMs > totalMs) continue;

      final sIdx = ((barMs / totalMs) * samples.length)
          .floor()
          .clamp(0, samples.length - 1);
      final amp = samples[sIdx].clamp(0.0, 1.0);
      final barH = math.max(2.0, amp * halfH * 0.9);
      final isPlayed = barMs <= currentMs;

      Color barColor;
      if (speakerColorMap.isNotEmpty) {
        final sid = _speakerIdAtMs(barMs);
        barColor = (kSpeakerColors[sid] ?? kSpeakerColors[1]!)
            .withOpacity(isPlayed ? 0.85 : 0.28);
      } else {
        barColor = const Color(0xFF6C63FF).withOpacity(isPlayed ? 0.85 : 0.25);
      }

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(barX, halfH - barH, barW, barH * 2),
          const Radius.circular(1.5),
        ),
        Paint()
          ..color = barColor
          ..style = PaintingStyle.fill,
      );
    }
  }

  int _speakerIdAtMs(int barMs) {
    final segs = controller.waveformData?.segments;
    if (segs == null || segs.isEmpty || speakerColorMap.isEmpty) {
      return 0;
    }
    for (final seg in segs) {
      final endMs = (seg.endSeconds * 1000).round();
      if (barMs >= seg.startMs && barMs <= endMs) {
        return speakerColorMap[seg.joinKey] ?? speakerColorMap[seg.uid] ?? 0;
      }
    }
    return 0;
  }

  // ── Loop Region ───────────────────────────────────────────

  void _paintLoopRegion(
    Canvas canvas,
    Size size,
    LoopRegion region,
    int totalMs,
    int currentMs,
    double msPerPx,
    double playheadX,
  ) {
    final startX =
        playheadX + (region.start.inMilliseconds - currentMs) / msPerPx;
    final endX = playheadX + (region.end.inMilliseconds - currentMs) / msPerPx;

    if (endX < 0 || startX > size.width) return;

    final left = startX.clamp(0.0, size.width);
    final right = endX.clamp(0.0, size.width);
    final rect = Rect.fromLTWH(left, 0, right - left, size.height);

    canvas.drawRect(rect, _loopFillPaint);
    canvas.drawRect(rect, _loopBorderPaint);
  }

  // ── Playhead ──────────────────────────────────────────────

  void _paintPlayhead(Canvas canvas, Size size, double playheadX) {
    canvas.drawLine(
      Offset(playheadX, 0),
      Offset(playheadX, size.height),
      _playheadPaint,
    );

    final tri = Path()
      ..moveTo(playheadX - 6, 0)
      ..lineTo(playheadX + 6, 0)
      ..lineTo(playheadX, 8)
      ..close();

    canvas.drawPath(
      tri,
      Paint()
        ..color = const Color(0xFF6C63FF)
        ..style = PaintingStyle.fill,
    );
  }

  // ── Time Label ────────────────────────────────────────────

  void _paintTimeLabel(
      Canvas canvas, Size size, Duration pos, double playheadX) {
    final mm = pos.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = pos.inSeconds.remainder(60).toString().padLeft(2, '0');

    final tp = TextPainter(
      text: TextSpan(
        text: '$mm:$ss',
        style: const TextStyle(
            color: Colors.white54, fontSize: 10, fontFamily: 'monospace'),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, Offset(playheadX + 8, 4));
  }

  // ── Empty State ───────────────────────────────────────────

  void _paintEmpty(Canvas canvas, Size size) {
    final tp = TextPainter(
      text: const TextSpan(
        text: 'Đang phân tích âm thanh...',
        style: TextStyle(color: Colors.white24, fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);

    tp.paint(
      canvas,
      Offset(
        (size.width - tp.width) / 2,
        (size.height - tp.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(RollingWaveformPainter old) =>
      old.controller != controller || old.speakerColorMap != speakerColorMap;
}
