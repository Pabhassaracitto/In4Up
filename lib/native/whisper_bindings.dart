import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

class WhisperBindings {
  static DynamicLibrary? _lib;

  static DynamicLibrary get lib {
    if (_lib != null) return _lib!;

    if (Platform.isWindows) {
      // In production, whisper.dll should be in the same folder as the .exe
      _lib = DynamicLibrary.open('whisper.dll');
      return _lib!;
    }

    throw UnsupportedError(
        'Native Whisper is currently only configured for Windows.');
  }
}

// Ví dụ: map 1 hàm từ whisper.h
typedef whisper_init_from_file_native = Pointer<Void> Function(
    Pointer<Utf8> path);
typedef WhisperInitFromFile = Pointer<Void> Function(Pointer<Utf8> path);

/// Initializes the whisper context from a model file.
/// Returns null if initialization fails.
Pointer<Void>? whisperInitFromFile(String path) {
  final pathPtr = path.toNativeUtf8();
  final func = WhisperBindings.lib
      .lookup<NativeFunction<whisper_init_from_file_native>>(
          'whisper_init_from_file')
      .asFunction<WhisperInitFromFile>();

  final ctx = func(pathPtr);
  calloc.free(pathPtr);
  return ctx;
}
