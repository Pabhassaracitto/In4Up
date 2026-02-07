import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// Quality levels for UltraTimeStretch V2 Engine
enum UltraQuality {
  preview, // Lowest latency
  standard, // Balanced
  highQuality, // Best for mobile
  ultraQuality, // Extreme slow speeds only (desktop)
}

/// Native function typedefs
typedef NativeCreateEngine = Pointer<Void> Function(
  Int32 sampleRate,
  Int32 channels,
  Int32 quality,
  Int8 preserveTransients,
  Int8 preserveFormants,
);
typedef CreateEngine = Pointer<Void> Function(
  int sampleRate,
  int channels,
  int quality,
  int preserveTransients,
  int preserveFormants,
);

typedef NativeDestroyEngine = Void Function(Pointer<Void> engine);
typedef DestroyEngine = void Function(Pointer<Void> engine);

typedef NativeSetSpeed = Void Function(Pointer<Void> engine, Float speed);
typedef SetSpeed = void Function(Pointer<Void> engine, double speed);

typedef NativeGetSpeed = Float Function(Pointer<Void> engine);
typedef GetSpeed = double Function(Pointer<Void> engine);

typedef NativeSetPitch = Void Function(Pointer<Void> engine, Float semitones);
typedef SetPitch = void Function(Pointer<Void> engine, double semitones);

typedef NativeProcess = Int32 Function(
  Pointer<Void> engine,
  Pointer<Float> input,
  Int32 inputFrames,
  Pointer<Float> output,
  Int32 maxOutputFrames,
);
typedef Process = int Function(
  Pointer<Void> engine,
  Pointer<Float> input,
  int inputFrames,
  Pointer<Float> output,
  int maxOutputFrames,
);

typedef NativeGetLatency = Int32 Function(Pointer<Void> engine);
typedef GetLatency = int Function(Pointer<Void> engine);

typedef NativeGetVersion = Pointer<Utf8> Function();
typedef GetVersion = Pointer<Utf8> Function();

typedef NativeReset = Void Function(Pointer<Void> engine);
typedef Reset = void Function(Pointer<Void> engine);

typedef NativeGetActiveEngineMode = Int32 Function(Pointer<Void> engine);
typedef GetActiveEngineMode = int Function(Pointer<Void> engine);

typedef NativeGetCurrentSpeed = Float Function(Pointer<Void> engine);
typedef GetCurrentSpeed = double Function(Pointer<Void> engine);

/// FFI Bindings for UltraTimeStretch V2 Native Engine
class UltraEngineFFIV2 {
  static UltraEngineFFIV2? _instance;
  DynamicLibrary? _lib;
  Pointer<Void>? _enginePtr;
  bool _isLoaded = false;

  // Native functions
  late CreateEngine _createEngine;
  late DestroyEngine _destroyEngine;
  late SetSpeed _setSpeed;
  GetSpeed? _getSpeed;
  SetPitch? _setPitch;
  late Process _process;
  GetLatency? _getLatency;
  GetVersion? _getVersion;
  Reset? _reset;
  GetActiveEngineMode? _getActiveEngineMode;
  GetCurrentSpeed? _getCurrentSpeed;

  UltraEngineFFIV2._internal();

  factory UltraEngineFFIV2() {
    _instance ??= UltraEngineFFIV2._internal();
    return _instance!;
  }

  /// Load the native library
  bool load() {
    if (_isLoaded) return true;

    try {
      if (Platform.isAndroid) {
        _lib = DynamicLibrary.open('libultratimestretch.so');
      } else if (Platform.isWindows) {
        try {
          _lib = DynamicLibrary.open('UltraTimeStretch_V2.dll');
        } catch (e) {
          _lib = DynamicLibrary.open('ultratimestretch.dll');
        }
      } else if (Platform.isIOS || Platform.isMacOS) {
        _lib = DynamicLibrary.process();
      } else {
        print('Platform not supported');
        return false;
      }

      _bindFunctions();
      _isLoaded = true;
      return true;
    } catch (e) {
      print('Failed to load UltraTimeStretch V2 library: $e');
      return false;
    }
  }

  void _bindFunctions() {
    if (_lib == null) return;

    try {
      _createEngine = _lib!
          .lookup<NativeFunction<NativeCreateEngine>>('CreateEngineV2')
          .asFunction();
    } on ArgumentError {
      _createEngine = _lib!
          .lookup<NativeFunction<NativeCreateEngine>>('CreateEngine')
          .asFunction();
    }

    _destroyEngine = _lib!
        .lookup<NativeFunction<NativeDestroyEngine>>('DestroyEngine')
        .asFunction();

    _setSpeed =
        _lib!.lookup<NativeFunction<NativeSetSpeed>>('SetSpeed').asFunction();

    try {
      _getSpeed =
          _lib!.lookup<NativeFunction<NativeGetSpeed>>('GetSpeed').asFunction();
    } on ArgumentError {
      _getSpeed = null;
    }

    try {
      _setPitch =
          _lib!.lookup<NativeFunction<NativeSetPitch>>('SetPitch').asFunction();
    } on ArgumentError {
      _setPitch = null;
    }

    _process = _lib!
        .lookup<NativeFunction<NativeProcess>>('ProcessAudio')
        .asFunction();

    try {
      _getLatency = _lib!
          .lookup<NativeFunction<NativeGetLatency>>('GetLatency')
          .asFunction();
    } on ArgumentError {
      _getLatency = null;
    }

    try {
      _getVersion = _lib!
          .lookup<NativeFunction<NativeGetVersion>>('GetVersion')
          .asFunction();
    } on ArgumentError {
      _getVersion = null;
    }

    try {
      _reset = _lib!.lookup<NativeFunction<NativeReset>>('Reset').asFunction();
    } on ArgumentError {
      _reset = null;
    }

    try {
      _getActiveEngineMode = _lib!
          .lookup<NativeFunction<NativeGetActiveEngineMode>>(
              'GetActiveEngineMode')
          .asFunction();
    } catch (_) {
      _getActiveEngineMode = null;
    }

    try {
      _getCurrentSpeed = _lib!
          .lookup<NativeFunction<NativeGetCurrentSpeed>>('GetCurrentSpeed')
          .asFunction();
    } catch (_) {
      _getCurrentSpeed = null;
    }
  }

  /// Get library version
  String getVersion() {
    if (_lib == null) return 'V2.0.0 (Mock)';
    if (_getVersion == null) return 'V2.0.0 (Native N/A)';

    try {
      final versionPtr = _getVersion!();
      final version = versionPtr.toDartString();
      malloc.free(versionPtr);
      return version;
    } catch (e) {
      return 'V2.0.0';
    }
  }

  /// Get supported features
  List<String> getSupportedFeatures() {
    return [
      'Multi-Resolution Phase Vocoder',
      'Harmonic-Percussive Separation',
      'Formant Preservation',
      'Spectral Peak Interpolation',
      'Extreme Speed Range (0.05x - 10x)',
      'Transient Detection',
      'SIMD Optimization (NEON/AVX)',
    ];
  }

  /// Initialize the V2 engine
  bool initialize({
    int sampleRate = 44100,
    int channels = 2,
    UltraQuality quality = UltraQuality.highQuality,
    bool preserveTransients = true,
    bool preserveFormants = true,
  }) {
    if (!_isLoaded) {
      print('Library not loaded');
      return false;
    }

    try {
      _enginePtr = _createEngine(
        sampleRate,
        channels,
        quality.index,
        preserveTransients ? 1 : 0,
        preserveFormants ? 1 : 0,
      );

      if (_enginePtr == nullptr || _enginePtr!.address == 0) {
        print('Failed to create V2 engine');
        return false;
      }

      print('V2 Engine created successfully');
      return true;
    } catch (e) {
      print('Error initializing V2 engine: $e');
      return false;
    }
  }

  /// Set playback speed (0.05 to 10.0)
  void setSpeed(double speed) {
    if (_enginePtr == null) return;

    final clampedSpeed = speed.clamp(0.05, 10.0);

    try {
      _setSpeed(_enginePtr!, clampedSpeed);
    } catch (e) {
      print('Error setting speed: $e');
    }
  }

  /// Get current speed
  double getSpeed() {
    if (_enginePtr == null) return 1.0;
    if (_getSpeed == null) return 1.0;

    try {
      return _getSpeed!(_enginePtr!);
    } catch (e) {
      print('Error getting speed: $e');
      return 1.0;
    }
  }

  /// Set pitch shift in semitones (-24 to +24)
  void setPitch(double semitones) {
    if (_enginePtr == null) return;
    if (_setPitch == null) return;

    final clampedPitch = semitones.clamp(-24.0, 24.0);

    try {
      _setPitch!(_enginePtr!, clampedPitch);
    } catch (e) {
      print('Error setting pitch: $e');
    }
  }

  /// Process audio buffer
  Float32List processAudio(
    Float32List input,
    int inputFrames,
    int maxOutputFrames,
  ) {
    if (_enginePtr == null) {
      print('Engine not initialized');
      return Float32List(0);
    }

    final inputPtr = malloc.allocate<Float>(input.length * sizeOf<Float>());
    final outputPtr =
        malloc.allocate<Float>(maxOutputFrames * 2 * sizeOf<Float>());

    try {
      // Copy input to native memory
      for (int i = 0; i < input.length; i++) {
        inputPtr[i] = input[i];
      }

      // Process
      final outputFrames = _process(
        _enginePtr!,
        inputPtr,
        inputFrames,
        outputPtr,
        maxOutputFrames,
      );

      // Copy output back to Dart
      final output = Float32List(outputFrames * 2);
      for (int i = 0; i < outputFrames * 2; i++) {
        output[i] = outputPtr[i];
      }

      return output;
    } catch (e) {
      print('Error processing audio: $e');
      return Float32List(0);
    } finally {
      malloc.free(inputPtr);
      malloc.free(outputPtr);
    }
  }

  /// Get engine latency in samples
  int getLatency() {
    if (_enginePtr == null) return 0;
    if (_getLatency == null) return 0;

    try {
      return _getLatency!(_enginePtr!);
    } catch (e) {
      print('Error getting latency: $e');
      return 0;
    }
  }

  /// Reset engine state
  void reset() {
    if (_enginePtr == null) return;
    if (_reset == null) return;

    try {
      _reset!(_enginePtr!);
    } catch (e) {
      print('Error resetting: $e');
    }
  }

  /// Debug: Get current active engine mode
  /// 0=V1_Standard, 1=V2_Hybrid, 2=V2_MultiRes
  String debugActiveMode() {
    if (_enginePtr == null || _getActiveEngineMode == null)
      return 'N/A (Not Init/Symbol Missing)';
    final m = _getActiveEngineMode!(_enginePtr!);
    switch (m) {
      case 0:
        return 'V1_Standard (>0.5x)';
      case 1:
        return 'V2_Hybrid (0.15x-0.5x)';
      case 2:
        return 'V2_MultiRes (<0.15x)';
      default:
        return 'Unknown($m)';
    }
  }

  /// Check if engine is initialized
  bool get isInitialized => _enginePtr != null && _enginePtr!.address != 0;

  /// Dispose resources
  void dispose() {
    if (_enginePtr != null && _enginePtr!.address != 0) {
      try {
        _destroyEngine(_enginePtr!);
      } catch (e) {
        print('Error destroying engine: $e');
      }
      _enginePtr = null;
    }

    _instance = null;
    _isLoaded = false;
  }
}
