// lib/models/waveform_data.dart
import 'package:flutter/material.dart';

class WaveformData {
  final List<double> samples; // Giá trị từ 0.0 đến 1.0
  final Duration duration;
  final int sampleRate; // samples per second

  WaveformData({
    required this.samples,
    required this.duration,
    this.sampleRate = 100, // 100 samples/second mặc định
  });

  // Tính index tương ứng với position
  int getIndexAtPosition(Duration position) {
    final progress = position.inMilliseconds / duration.inMilliseconds;
    return (progress * samples.length).round().clamp(0, samples.length - 1);
  }

  // Lấy mẫu trong khoảng thời gian
  List<double> getSamplesInRange(Duration start, Duration end) {
    final startIndex = getIndexAtPosition(start);
    final endIndex = getIndexAtPosition(end);

    if (startIndex >= endIndex || startIndex < 0 || endIndex > samples.length) {
      return [];
    }

    return samples.sublist(startIndex, endIndex);
  }

  // Downsample để performance tốt hơn
  WaveformData downsample(int targetSamples) {
    if (samples.length <= targetSamples) return this;

    final ratio = samples.length / targetSamples;
    final downsampled = <double>[];

    for (int i = 0; i < targetSamples; i++) {
      final start = (i * ratio).floor();
      final end = ((i + 1) * ratio).ceil().clamp(0, samples.length);

      // Lấy giá trị max trong chunk (để waveform rõ hơn)
      double maxValue = 0.0;
      for (int j = start; j < end; j++) {
        if (samples[j] > maxValue) maxValue = samples[j];
      }
      downsampled.add(maxValue);
    }

    return WaveformData(
      samples: downsampled,
      duration: duration,
      sampleRate: (targetSamples / duration.inSeconds).round(),
    );
  }
}

// Loop Region
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
