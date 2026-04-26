// lib/models/waveform_data.dart
import 'package:flutter/material.dart';

class WaveformData {
  final List<double> samples;
  final Duration duration;
  final int sampleRate;

  WaveformData({
    required this.samples,
    required this.duration,
    this.sampleRate = 100,
  });

  int getIndexAtPosition(Duration position) {
    final durMs = duration.inMilliseconds;
    if (durMs <= 0 || samples.isEmpty) return 0;

    final progress = position.inMilliseconds / durMs;
    if (progress.isNaN || progress.isInfinite) return 0;

    return (progress * samples.length)
        .clamp(0.0, samples.isEmpty ? 0.0 : (samples.length - 1).toDouble())
        .round();
  }

  List<double> getSamplesInRange(Duration start, Duration end) {
    if (duration.inMilliseconds <= 0 || samples.isEmpty) return [];

    final startIndex = getIndexAtPosition(start);
    final endIndex = getIndexAtPosition(end);

    if (startIndex >= endIndex || startIndex < 0 || endIndex > samples.length) {
      return [];
    }

    return samples.sublist(startIndex, endIndex);
  }

  WaveformData downsample(int targetSamples) {
    if (samples.length <= targetSamples) return this;

    final ratio = samples.length / targetSamples;
    final downsampled = <double>[];

    for (int i = 0; i < targetSamples; i++) {
      final start = (i * ratio).floor();
      final end = ((i + 1) * ratio).ceil().clamp(0, samples.length);

      double maxValue = 0.0;
      for (int j = start; j < end; j++) {
        if (samples[j] > maxValue) maxValue = samples[j];
      }
      downsampled.add(maxValue);
    }

    return WaveformData(
      samples: downsampled,
      duration: duration,
      sampleRate: duration.inSeconds > 0
          ? (targetSamples / duration.inSeconds).round()
          : sampleRate,
    );
  }
}

class LoopRegion {
  final Duration start;
  final Duration end;
  final Color color;
// Loop Region
  LoopRegion({
    required this.start,
    required this.end,
    this.color = const Color(0xFF4CAF50),
  });

  bool contains(Duration position) {
    return position >= start && position <= end;
  }
}
