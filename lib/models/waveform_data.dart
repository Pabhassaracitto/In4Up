// in4up1.0 — Canonical WaveformData model
// Import duy nhất cho WaveformProvider + RollingWaveformPainter + Controller

import 'package:flutter/material.dart';

class LoopRegion {
  final Duration start;
  final Duration end;
  final Color color;

  LoopRegion({
    required this.start,
    required this.end,
    this.color = const Color(0xFF4CAF50),
  });

  bool contains(Duration position) {
    return position >= start && position <= end;
  }
}

/// Tham chiếu nhẹ tới SttSegment — chỉ chứa data cần cho painter
/// Tách khỏi SttSegment để tránh circular dependency
/// lib/ → packages/in4up_stt/
class WaveformSegmentRef {
  final String uid; // ContentId.segmentUid(...)
  final String joinKey; // startMs|textNorm — bridge tới SpeakerAnnotation
  final int startMs;
  final double endSeconds;

  const WaveformSegmentRef({
    required this.uid,
    required this.joinKey,
    required this.startMs,
    required this.endSeconds,
  });
}

class WaveformData {
  final List<double> samples;
  final Duration duration;

  /// Segments để painter tra speakerId theo timestamp
  /// null = file cũ chưa có diarization (backward compatible)
  final List<WaveformSegmentRef>? segments;

  const WaveformData({
    required this.samples,
    required this.duration,
    this.segments,
  });

  /// Backward-compat: không có segments
  factory WaveformData.simple({
    required List<double> samples,
    required Duration duration,
  }) =>
      WaveformData(samples: samples, duration: duration);

  /// Tạo bản sao với segments được đính kèm
  WaveformData withSegments(List<WaveformSegmentRef> segs) => WaveformData(
        samples: samples,
        duration: duration,
        segments: segs,
      );
}
