import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/cabin/services/cabin_pcm_gate.dart';

void main() {
  test('muting produces PCM silence of identical length without changing input', () {
    final pcm = Uint8List.fromList([255, 127, 0, 128]);
    expect(gateCabinSystemPcm(pcm, mute: true), [0, 0, 0, 0]);
    expect(pcm, [255, 127, 0, 128]);
    expect(gateCabinSystemPcm(pcm, mute: false), pcm);
  });
}
