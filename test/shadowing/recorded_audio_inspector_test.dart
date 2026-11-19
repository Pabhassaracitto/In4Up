import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/shadowing/services/offline_stt_service.dart';

void _ascii(ByteData data, int offset, String text) {
  for (var i = 0; i < text.length; i++) {
    data.setUint8(offset + i, text.codeUnitAt(i));
  }
}

Uint8List _wav(List<int> samples) {
  final bytes = Uint8List(44 + samples.length * 2);
  final data = ByteData.sublistView(bytes);
  _ascii(data, 0, 'RIFF');
  data.setUint32(4, bytes.length - 8, Endian.little);
  _ascii(data, 8, 'WAVE');
  _ascii(data, 12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, 1, Endian.little); // mono
  data.setUint32(24, 44100, Endian.little);
  data.setUint32(28, 88200, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  _ascii(data, 36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(44 + i * 2, samples[i], Endian.little);
  }
  return bytes;
}

void main() {
  test('distinguishes missing, silent, and audible microphone captures', () async {
    final dir = await Directory.systemTemp.createTemp('shadowing-audio-');
    addTearDown(() => dir.delete(recursive: true));
    final silentFile = File('${dir.path}/silent.wav')..writeAsBytesSync(_wav([0, 12, -80, 20]));
    final audibleFile = File('${dir.path}/audible.wav')..writeAsBytesSync(_wav([0, 600, -900, 200]));

    expect(await RecordedAudioInspector.inspect('${dir.path}/missing.wav'), RecordedAudioSignal.missing);
    expect(await RecordedAudioInspector.inspect(silentFile.path), RecordedAudioSignal.silent);
    expect(await RecordedAudioInspector.inspect(audibleFile.path), RecordedAudioSignal.audible);
  });

  test('unsupported audio is delegated to STT instead of called silence', () async {
    final dir = await Directory.systemTemp.createTemp('shadowing-audio-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/other.bin')..writeAsBytesSync(List<int>.filled(60, 7));
    expect(await RecordedAudioInspector.inspect(file.path), RecordedAudioSignal.unknown);
  });

  test('transcription result model differentiates recognized and failed output', () {
    expect(const ShadowingTranscription(text: 'hello').hasText, isTrue);
    expect(const ShadowingTranscription(text: ' ').hasText, isFalse);
    expect(const ShadowingTranscription(errorCode: 'no_audio').errorCode, 'no_audio');
    expect(const ShadowingTranscription(errorCode: 'recognition_error').errorCode, 'recognition_error');
  });
}
