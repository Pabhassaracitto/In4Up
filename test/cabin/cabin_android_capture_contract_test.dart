import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  final activity = File('android/app/src/main/kotlin/com/in4up/cabin/CabinCaptureRequestActivity.kt').readAsStringSync();
  final service = File('android/app/src/main/kotlin/com/in4up/cabin/CabinSystemAudioService.kt').readAsStringSync();

  test('capture has its own non-exported service and consent activity', () {
    expect(manifest, contains('com.in4up.cabin.CabinSystemAudioService'));
    expect(manifest, contains('com.in4up.cabin.CabinCaptureRequestActivity'));
    expect(activity, contains('manager.createScreenCaptureIntent()'));
    expect(activity, contains('CabinSystemAudioService.ACTION_START'));
  });

  test('starts projection FGS before consuming consent and cleans up', () {
    expect(service.indexOf('startCaptureForeground()'),
        lessThan(service.indexOf('manager.getMediaProjection(resultCode, data)')));
    expect(service, contains('p.registerCallback(projectionCallback, main)'));
    expect(service, contains('setAudioPlaybackCaptureConfig(config)'));
    expect(service, contains('setSampleRate(16000)'));
    expect(service, contains('AudioFormat.CHANNEL_IN_MONO'));
    expect(service, contains('record?.release()'));
    expect(service, contains('projection?.stop()'));
    expect(service, contains('START_NOT_STICKY'));
  });
}
