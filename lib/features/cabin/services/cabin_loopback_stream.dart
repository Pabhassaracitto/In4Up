import 'dart:async';
import 'dart:typed_data';

import 'cabin_loopback_pcm.dart';

/// A single system-audio capture session. Implementations must return whole
/// interleaved float frames; an empty list means no packet is ready yet.
abstract interface class CabinLoopbackDevice {
  void start();
  int get sampleRate;
  int get channels;
  Float32List read(int maxFrames);
  void close();
}

/// Pulls a bounded native loopback queue into the same PCM format used by the
/// offline Cabin recognizer. This is not connected to the UI or ASR yet.
/// Cancelling the subscription releases the device (after at most one poll).
Stream<Uint8List> cabinLoopbackStream(
  CabinLoopbackDevice Function() createDevice, {
  Duration pollInterval = const Duration(milliseconds: 20),
  int maxFrames = 4096,
}) async* {
  if (pollInterval <= Duration.zero || maxFrames <= 0) {
    throw ArgumentError('The polling interval and frame limit must be positive');
  }
  final device = createDevice();
  try {
    device.start();
    final rate = device.sampleRate;
    final channels = device.channels;
    if (rate <= 0 || rate > 384000 || channels <= 0 || channels > 32) {
      throw StateError('Unsupported loopback audio format');
    }
    final converter = CabinLoopbackPcmConverter(
      inputSampleRate: rate,
      channels: channels,
    );
    while (true) {
      final floats = device.read(maxFrames);
      if (floats.length > maxFrames * channels || floats.length % channels != 0) {
        throw StateError('Invalid loopback audio packet');
      }
      if (floats.isEmpty) {
        await Future<void>.delayed(pollInterval);
        continue;
      }
      final pcm = converter.convert(floats);
      if (pcm.isNotEmpty) yield pcm;
    }
  } finally {
    device.close();
  }
}
