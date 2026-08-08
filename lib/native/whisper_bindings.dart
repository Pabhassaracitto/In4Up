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

// ── whisper_context_params + hỗ trợ cho whisper_init_from_file_with_params ──

final class _WhisperAhead extends Struct {
  @Int32()
  external int n_text_layer;

  @Int32()
  external int n_head;
}

final class _WhisperAheads extends Struct {
  @Size()
  external int n_heads;

  external Pointer<_WhisperAhead> heads;
}

final class WhisperContextParams extends Struct {
  @Bool()
  external bool use_gpu;

  @Bool()
  external bool flash_attn;

  @Int32()
  external int gpu_device;

  @Bool()
  external bool dtw_token_timestamps;

  @Int32()
  external int dtw_aheads_preset;

  @Int32()
  external int dtw_n_top;

  external _WhisperAheads dtw_aheads;

  @Size()
  external int dtw_mem_size;
}

typedef whisper_context_default_params_native =
    WhisperContextParams Function();
typedef WhisperContextDefaultParams =
    WhisperContextParams Function();

typedef whisper_init_from_file_with_params_native = Pointer<Void> Function(
    Pointer<Utf8>, WhisperContextParams);
typedef WhisperInitFromFileWithParams =
    Pointer<Void> Function(Pointer<Utf8>, WhisperContextParams);

// ── API deprecated (chỉ fallback cho DLL cũ) ───────────────────────────────

typedef whisper_init_from_file_native = Pointer<Void> Function(
    Pointer<Utf8> path);
typedef WhisperInitFromFile = Pointer<Void> Function(Pointer<Utf8> path);

/// Initializes the whisper context from a model file.
/// Returns null if initialization fails.
Pointer<Void>? whisperInitFromFile(String path) {
  final pathPtr = path.toNativeUtf8();
  final lib = WhisperBindings.lib;

  try {
    // Ưu tiên API mới (recommended): whisper_init_from_file_with_params.
    // Lưu ý: lookupFunction() đã trả thẳng Dart function — KHÔNG gọi thêm
    // .asFunction() (chỉ dùng .asFunction cho lookup() cũ).
    try {
      final contextDefaultParams = lib.lookupFunction<
          whisper_context_default_params_native, WhisperContextDefaultParams>(
          'whisper_context_default_params');
      final initWithParams = lib.lookupFunction<
          whisper_init_from_file_with_params_native,
          WhisperInitFromFileWithParams>('whisper_init_from_file_with_params');
      final cparams = contextDefaultParams();
      return initWithParams(pathPtr, cparams);
    } catch (_) {
      // fallthrough → API deprecated
    }

    final func = lib.lookupFunction<whisper_init_from_file_native,
        WhisperInitFromFile>('whisper_init_from_file');
    return func(pathPtr);
  } finally {
    calloc.free(pathPtr);
  }
}
