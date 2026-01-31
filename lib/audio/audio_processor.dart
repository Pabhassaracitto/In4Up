import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'audio_processor_ffi.dart';

class AudioProcessor {
  late final AudioProcessorFFI _ffi;
  late final Pointer<Void> _enginePtr;

  AudioProcessor({
    required int sampleRate,
    required int channels,
  }) {
    _ffi = AudioProcessorFFI();
    _enginePtr = _ffi.createEngine(sampleRate, channels);

    if (_enginePtr.address == 0) {
      throw Exception('Failed to create UltraTimeStretch engine');
    }
  }

  void setSpeed(double speed) {
    _ffi.setSpeed(_enginePtr, speed);
  }

  Float32List process(Float32List input, int inputFrames, int maxOutputFrames) {
    final inputPtr = malloc.allocate<Float>(input.length * sizeOf<Float>());
    final outputPtr =
        malloc.allocate<Float>(maxOutputFrames * 2 * sizeOf<Float>());

    try {
      // Copy input
      for (int i = 0; i < input.length; i++) {
        inputPtr[i] = input[i];
      }

      // Process
      final outputFrames = _ffi.process(
        _enginePtr,
        inputPtr,
        inputFrames,
        outputPtr,
        maxOutputFrames,
      );

      // Copy output
      final output = Float32List(outputFrames * 2);
      for (int i = 0; i < outputFrames * 2; i++) {
        output[i] = outputPtr[i];
      }

      return output;
    } finally {
      malloc.free(inputPtr);
      malloc.free(outputPtr);
    }
  }

  void dispose() {
    if (_enginePtr.address != 0) {
      _ffi.destroyEngine(_enginePtr);
    }
  }
}
