import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/cabin/services/cabin_loopback_pcm.dart';

List<int> samples(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  return [for (var i = 0; i < bytes.length; i += 2) data.getInt16(i, Endian.little)];
}

void main() {
  test('rejects invalid formats and partial frames without changing clock', () {
    expect(() => CabinLoopbackPcmConverter(inputSampleRate: 0, channels: 1), throwsArgumentError);
    expect(() => CabinLoopbackPcmConverter(inputSampleRate: 48000, channels: 0), throwsArgumentError);
    final converter = CabinLoopbackPcmConverter(inputSampleRate: 16000, channels: 2);
    expect(() => converter.convert(Float32List.fromList([0.5])), throwsArgumentError);
    expect(samples(converter.convert(Float32List.fromList([0.5, 0.5]))), [16384]);
  });

  test('downmixes and writes saturated signed little-endian PCM', () {
    final converter = CabinLoopbackPcmConverter(inputSampleRate: 16000, channels: 2);
    final out = converter.convert(Float32List.fromList([
      1, 1, -1, -1, 1, -1, 4, 4, -4, -4, double.nan, double.infinity,
    ]));
    expect(samples(out), [32767, -32768, 0, 32767, -32768, 0]);
    expect(out.sublist(0, 4), [255, 127, 0, 128]);
  });

  test('packet boundaries do not change the resampled signal or clock', () {
    for (final rate in [8000, 16000, 44100, 48000]) {
      final input = Float32List.fromList(List.generate(
        rate * 2,
        (i) => math.sin(i * 0.01),
      ));
      final whole = CabinLoopbackPcmConverter(inputSampleRate: rate, channels: 2);
      final split = CabinLoopbackPcmConverter(inputSampleRate: rate, channels: 2);
      final actual = BytesBuilder();
      // Deliberately nonuniform, but always complete stereo frames.
      for (var i = 0; i < input.length;) {
        final end = math.min(i + 374, input.length);
        actual.add(split.convert(Float32List.sublistView(input, i, end)));
        i = end;
      }
      expect(actual.takeBytes(), whole.convert(input), reason: 'rate $rate');
      // Exactly one second of stereo input; upsampling needs the next frame
      // for the final fractional sample.
      expect(samples(whole.resetAndConvert(input)).length,
          rate < 16000 ? 15999 : 16000);
    }
  });

  test('interpolates across packets and handles empty input', () {
    final converter = CabinLoopbackPcmConverter(inputSampleRate: 8000, channels: 1);
    expect(converter.convert(Float32List(0)), isEmpty);
    expect(samples(converter.convert(Float32List.fromList([0]))), [0]);
    expect(samples(converter.convert(Float32List.fromList([1]))), [16384, 32767]);
  });

  test('downsample clock skips input frames even across packets', () {
    final converter = CabinLoopbackPcmConverter(inputSampleRate: 48000, channels: 1);
    expect(samples(converter.convert(Float32List.fromList([0, 0.1]))), [0]);
    expect(samples(converter.convert(Float32List.fromList([0.2, 0.75]))), [24575]);
  });

  test('reset starts a fresh sample clock', () {
    final converter = CabinLoopbackPcmConverter(inputSampleRate: 48000, channels: 1);
    final packet = Float32List.fromList([0.25, 0.5]);
    final first = converter.convert(packet);
    converter.reset();
    expect(converter.convert(packet), first);
  });
}

extension on CabinLoopbackPcmConverter {
  Uint8List resetAndConvert(Float32List input) {
    reset();
    return convert(input);
  }
}
