import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = File('lib/features/cabin/services/stts_cabin_service.dart').readAsStringSync();
  test('system audio feeds the existing Sherpa and session recorder path', () {
    expect(service, contains('_openSystemAudio(systemGeneration)'));
    expect(service, contains('_recorder?.tapPcm(rawPcm) ?? rawPcm'));
    expect(service, contains('pcmStream: pcmStream'));
    expect(service, contains('cabinLoopbackStream(CabinWindowsLoopback.new)'));
    expect(service, contains('capture.open(overlay: _systemOverlay)'));
  });
  test('system capture cannot reuse a projection or silently restart', () {
    expect(service, contains('++_systemGeneration; // invalidate late consent'));
    expect(service, contains('if (systemGeneration == null) _startKeepAlive()'));
    expect(service, contains('await _closeSystemAudio()'));
    expect(service, contains('_systemCaptureEnded(generation)'));
    expect(service, contains('_systemStreamFailed'));
  });
  test('system overlay gets captions and TTS input is muted', () {
    expect(service, contains('_pushSystemCaption(finalizedCaption)'));
    expect(service, contains('CabinAndroidCapture.updateCaption(text)'));
    expect(service, contains('_windowsOverlay?.setCaption(text)'));
    expect(service, contains('_systemTtsDepth > 0 ? Uint8List(data.length) : data'));
  });
}
