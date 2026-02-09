import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// Native function signatures
typedef NativeCreateFunc = Pointer<Void> Function(
    Int32 sampleRate, Int32 channels);
typedef CreateFunc = Pointer<Void> Function(int sampleRate, int channels);

typedef NativeDestroyFunc = Void Function(Pointer<Void> engine);
typedef DestroyFunc = void Function(Pointer<Void> engine);

typedef NativeSetSpeedFunc = Void Function(Pointer<Void> engine, Float speed);
typedef SetSpeedFunc = void Function(Pointer<Void> engine, double speed);

typedef NativeProcessFunc = Int32 Function(
    Pointer<Void> engine,
    Pointer<Float> input,
    Int32 inputFrames,
    Pointer<Float> output,
    Int32 maxOutputFrames);
typedef ProcessFunc = int Function(Pointer<Void> engine, Pointer<Float> input,
    int inputFrames, Pointer<Float> output, int maxOutputFrames);

class AudioProcessorFFI {
  late final DynamicLibrary _dylib;
  late final CreateFunc _create;
  late final DestroyFunc _destroy;
  late final SetSpeedFunc _setSpeed;
  late final ProcessFunc _process;

  AudioProcessorFFI() {
    // Load platform-specific library
    if (Platform.isAndroid) {
      _dylib = DynamicLibrary.open('libultratimestretch.so');
    } else if (Platform.isWindows) {
      _dylib = DynamicLibrary.open('ultratimestretch.dll');
    } else if (Platform.isIOS || Platform.isMacOS) {
      _dylib = DynamicLibrary.process();
    } else {
      throw UnsupportedError('Unsupported platform');
    }

    // Bind functions
    _create = _dylib
        .lookup<NativeFunction<NativeCreateFunc>>('CreateEngine')
        .asFunction();

    _destroy = _dylib
        .lookup<NativeFunction<NativeDestroyFunc>>('DestroyEngine')
        .asFunction();

    _setSpeed = _dylib
        .lookup<NativeFunction<NativeSetSpeedFunc>>('SetSpeed')
        .asFunction();

    _process = _dylib
        .lookup<NativeFunction<NativeProcessFunc>>('ProcessAudio')
        .asFunction();
  }

  Pointer<Void> createEngine(int sampleRate, int channels) {
    return _create(sampleRate, channels);
  }

  void destroyEngine(Pointer<Void> engine) {
    _destroy(engine);
  }

  void setSpeed(Pointer<Void> engine, double speed) {
    _setSpeed(engine, speed);
  }

  int process(
    Pointer<Void> engine,
    Pointer<Float> input,
    int inputFrames,
    Pointer<Float> output,
    int maxOutputFrames,
  ) {
    return _process(engine, input, inputFrames, output, maxOutputFrames);
  }
}
