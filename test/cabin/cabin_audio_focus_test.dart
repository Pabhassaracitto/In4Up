import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/cabin/services/cabin_record_config.dart';
import 'package:record/record.dart';

void main() {
  test('Android Cabin PCM does not pause when its TTS takes audio focus', () {
    final config = cabinRecordConfig(isAndroid: true);
    expect(config.encoder, AudioEncoder.pcm16bits);
    expect(config.sampleRate, 16000);
    expect(config.numChannels, 1);
    expect(config.audioInterruption, AudioInterruptionMode.none);
    // The Android plugin consumes this serialized enum index, not the Dart enum.
    expect(config.toMap()['audioInterruption'], AudioInterruptionMode.none.index);
  });

  test('other platforms retain the plugin interruption default', () {
    final config = cabinRecordConfig(isAndroid: false);
    expect(config.audioInterruption, const RecordConfig().audioInterruption);
  });

  test('Sherpa live capture actually uses the Cabin PCM configuration', () {
    final source = File('lib/features/cabin/services/stts_cabin_service.dart')
        .readAsStringSync();
    final start = source.indexOf('await recorder.startStream(');
    expect(start, greaterThanOrEqualTo(0));
    final end = source.indexOf(');', start);
    final call = source.substring(start, end);
    expect(call, contains('cabinRecordConfig('));
    expect(call, contains('TargetPlatform.android'));
  });
}
