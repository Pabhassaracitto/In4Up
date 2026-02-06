import 'dart:math' as math;
import 'dart:typed_data';

/// Utility class for processing audio waveforms
class WaveformUtils {
  /// Extract waveform data from a list of samples to a smaller set of points for UI
  /// Returns a normalized list of amplitudes between 0.0 and 1.0
  static List<double> extractWaveform(List<double> samples,
      {int points = 100}) {
    if (samples.isEmpty) return List.filled(points, 0.1);

    final result = <double>[];
    final samplesPerPoint = (samples.length / points).ceil();

    for (int i = 0; i < points; i++) {
      final start = i * samplesPerPoint;
      var end = start + samplesPerPoint;
      if (end > samples.length) end = samples.length;

      if (start >= samples.length) {
        result.add(0.0);
        continue;
      }

      // Calculate RMS or Peak for this chunk
      double maxAmp = 0.0;
      for (int j = start; j < end; j++) {
        final amp = samples[j].abs();
        if (amp > maxAmp) maxAmp = amp;
      }
      result.add(maxAmp);
    }

    return normalize(result);
  }

  /// Normalize waveform data to 0.0 - 1.0 range
  static List<double> normalize(List<double> data) {
    if (data.isEmpty) return [];

    double maxVal = 0.0;
    for (var val in data) {
      maxVal = math.max(maxVal, val.abs());
    }

    if (maxVal == 0) return data;

    return data.map((e) => e / maxVal).toList();
  }

  /// Generate a dummy waveform for testing/loading states
  static List<double> generateDummyWaveform(int count) {
    final random = math.Random();
    return List.generate(count, (_) => 0.3 + random.nextDouble() * 0.4);
  }
}
