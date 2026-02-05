// lib/utils/waveform_utils.dart
// Chuyển đổi dữ liệu waveform từ JustAudio sang định dạng của chúng ta, và tạo waveform giả để test.
import 'dart:typed_data';
import 'package:just_waveform/just_waveform.dart';
import '../models/waveform_data.dart';

class WaveformUtils {
  // Convert JustAudio waveform to our WaveformData
  static WaveformData fromJustWaveform(Waveform waveform) {
    final samples = <double>[];

    for (int i = 0; i < waveform.length; i++) {
      final channel0 = waveform.dataInChannel(0, i);
      final channel1 =
          waveform.channels > 1 ? waveform.dataInChannel(1, i) : channel0;

      // Average của 2 channels
      final average = (channel0 + channel1) / 2;

      // Normalize về 0.0 - 1.0
      final normalized = (average + 128) / 256;
      samples.add(normalized.clamp(0.0, 1.0));
    }

    return WaveformData(
      samples: samples,
      duration: waveform.duration,
      sampleRate: (samples.length / waveform.duration.inSeconds).round(),
    );
  }

  // Generate dummy waveform for testing
  static WaveformData generateDummy(Duration duration) {
    final sampleRate = 100;
    final totalSamples = (duration.inSeconds * sampleRate).toInt();
    final samples = <double>[];

    for (int i = 0; i < totalSamples; i++) {
      // Tạo waveform giả với nhiều tần số
      final t = i / sampleRate;
      final value =
          0.3 * (1 + dart.math.sin(2 * dart.math.pi * 1 * t)) + // Base wave
              0.2 * (1 + dart.math.sin(2 * dart.math.pi * 5 * t)) + // Mid freq
              0.1 * (1 + dart.math.sin(2 * dart.math.pi * 20 * t)); // High freq

      samples.add((value / 0.6).clamp(0.0, 1.0));
    }

    return WaveformData(
      samples: samples,
      duration: duration,
      sampleRate: sampleRate,
    );
  }
}
