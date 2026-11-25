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

  test('overlay and channel require consent and stop on detach', () {
    final plugin = File('android/app/src/main/kotlin/com/in4up/cabin/CabinSystemAudioPlugin.kt').readAsStringSync();
    final main = File('android/app/src/main/kotlin/com/in4up/MainActivity.kt').readAsStringSync();
    expect(plugin, contains('Settings.canDrawOverlays(activity)'));
    expect(plugin, contains('CabinSystemAudioService.cancelRequest()'));
    expect(plugin, contains('queued.incrementAndGet() > 30'));
    expect(plugin, contains('sink?.endOfStream()'));
    expect(activity, contains('CabinSystemAudioService.isCurrent(requestId)'));
    expect(service, contains('WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY'));
    expect(service, contains('removeView(it)'));
    expect(main, contains('cabinSystemAudioPlugin?.detach()'));
  });

  test('notification strings ship with all priority locales', () {
    for (final locale in ['values', 'values-vi', 'values-hi', 'values-zh', 'values-zh-rTW', 'values-si']) {
      final text = File('android/app/src/main/res/$locale/strings_cabin_audio.xml').readAsStringSync();
      for (final key in ['cabin_audio_channel', 'cabin_audio_notification_title', 'cabin_audio_notification_body', 'cabin_audio_stop']) {
        expect(text, contains('name="$key"'), reason: '$locale: $key');
      }
    }
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
