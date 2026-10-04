import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';

/// Optional FFI adapter for the local GGUF backend.
///
/// Symbol names stay `in4up_ai_*` so a future native build can ship
/// `libin4up_ai_native`. Older `in2up_ai_*` symbols are also accepted.
class AiNativeBindings {
  AiNativeBindings._(
    this._library, {
    required String createSymbol,
    required String generateSymbol,
    required String freeStringSymbol,
    required String destroySymbol,
  })  : _create =
            _library.lookupFunction<_CreateNative, _Create>(createSymbol),
        _generate =
            _library.lookupFunction<_GenerateNative, _Generate>(generateSymbol),
        _freeString = _library
            .lookupFunction<_FreeStringNative, _FreeString>(freeStringSymbol),
        _destroy =
            _library.lookupFunction<_DestroyNative, _Destroy>(destroySymbol);

  final ffi.DynamicLibrary _library;
  final _Create _create;
  final _Generate _generate;
  final _FreeString _freeString;
  final _Destroy _destroy;

  static const _symbolSets = [
    (
      create: 'in4up_ai_create',
      generate: 'in4up_ai_generate',
      freeString: 'in4up_ai_free_string',
      destroy: 'in4up_ai_destroy',
    ),
    (
      create: 'in2up_ai_create',
      generate: 'in2up_ai_generate',
      freeString: 'in2up_ai_free_string',
      destroy: 'in2up_ai_destroy',
    ),
  ];

  static AiNativeBindings? tryLoad() {
    try {
      final library = Platform.isAndroid
          ? _openFirst(['libin4up_ai_native.so', 'libin2up_ai_native.so'])
          : Platform.isWindows
              ? _openFirst(['in4up_ai_native.dll', 'in2up_ai_native.dll'])
              : Platform.isLinux
                  ? _openFirst(
                      ['libin4up_ai_native.so', 'libin2up_ai_native.so'])
                  : Platform.isMacOS || Platform.isIOS
                      ? ffi.DynamicLibrary.process()
                      : null;
      if (library == null) return null;
      for (final symbols in _symbolSets) {
        try {
          return AiNativeBindings._(
            library,
            createSymbol: symbols.create,
            generateSymbol: symbols.generate,
            freeStringSymbol: symbols.freeString,
            destroySymbol: symbols.destroy,
          );
        } catch (_) {
          continue;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static ffi.DynamicLibrary? _openFirst(List<String> names) {
    for (final name in names) {
      try {
        return ffi.DynamicLibrary.open(name);
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  ffi.Pointer<ffi.Void> create(String modelPath,
      {int contextSize = 2048, int threads = 4}) {
    final path = modelPath.toNativeUtf8();
    try {
      return _create(path.cast<ffi.Char>(), contextSize, threads);
    } finally {
      calloc.free(path);
    }
  }

  String? generate(
    ffi.Pointer<ffi.Void> handle,
    String prompt, {
    int maxTokens = 256,
    double temperature = 0.2,
  }) {
    final promptPtr = prompt.toNativeUtf8();
    final outputPtr = calloc<ffi.Pointer<ffi.Char>>();
    try {
      final result = _generate(
        handle,
        promptPtr.cast<ffi.Char>(),
        maxTokens,
        temperature,
        outputPtr,
      );
      if (result < 0 || outputPtr.value == ffi.nullptr) return null;
      return outputPtr.value.cast<Utf8>().toDartString();
    } finally {
      if (outputPtr.value != ffi.nullptr) _freeString(outputPtr.value);
      calloc.free(outputPtr);
      calloc.free(promptPtr);
    }
  }

  void destroy(ffi.Pointer<ffi.Void> handle) => _destroy(handle);
}

typedef _CreateNative = ffi.Pointer<ffi.Void> Function(
    ffi.Pointer<ffi.Char>, ffi.Int32, ffi.Int32);
typedef _Create = ffi.Pointer<ffi.Void> Function(
    ffi.Pointer<ffi.Char>, int, int);
typedef _GenerateNative = ffi.Int32 Function(ffi.Pointer<ffi.Void>,
    ffi.Pointer<ffi.Char>, ffi.Int32, ffi.Float, ffi.Pointer<ffi.Pointer<ffi.Char>>);
typedef _Generate = int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Char>,
    int, double, ffi.Pointer<ffi.Pointer<ffi.Char>>);
typedef _FreeStringNative = ffi.Void Function(ffi.Pointer<ffi.Char>);
typedef _FreeString = void Function(ffi.Pointer<ffi.Char>);
typedef _DestroyNative = ffi.Void Function(ffi.Pointer<ffi.Void>);
typedef _Destroy = void Function(ffi.Pointer<ffi.Void>);
