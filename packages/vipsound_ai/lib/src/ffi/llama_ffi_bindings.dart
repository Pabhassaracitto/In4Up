import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// ── Native function typedefs ──────────────────────────────

typedef NativeLlamaCreate = Pointer<Void> Function(
  Pointer<Utf8> modelPath,
  Int32 nCtx,
  Int32 nThreads,
);
typedef LlamaCreate = Pointer<Void> Function(
  Pointer<Utf8> modelPath,
  int nCtx,
  int nThreads,
);

typedef NativeLlamaDestroy = Void Function(Pointer<Void> ctx);
typedef LlamaDestroy = void Function(Pointer<Void> ctx);

typedef NativeLlamaInfer = Int32 Function(
  Pointer<Void> ctx,
  Pointer<Utf8> prompt,
  Pointer<Utf8> outputBuf,
  Int32 bufSize,
  Int32 maxTokens,
  Float temperature,
);
typedef LlamaInfer = int Function(
  Pointer<Void> ctx,
  Pointer<Utf8> prompt,
  Pointer<Utf8> outputBuf,
  int bufSize,
  int maxTokens,
  double temperature,
);

typedef NativeLlamaIsValid = Int32 Function(Pointer<Void> ctx);
typedef LlamaIsValid = int Function(Pointer<Void> ctx);

typedef NativeLlamaReset = Void Function(Pointer<Void> ctx);
typedef LlamaReset = void Function(Pointer<Void> ctx);

typedef NativeLlamaModelInfo = Pointer<Utf8> Function(Pointer<Void> ctx);
typedef LlamaModelInfo = Pointer<Utf8> Function(Pointer<Void> ctx);

typedef NativeLlamaVersion = Pointer<Utf8> Function();
typedef LlamaVersion = Pointer<Utf8> Function();

// ── FFI Bindings class ────────────────────────────────────

class LlamaFfiBindings {
  static LlamaFfiBindings? _instance;
  factory LlamaFfiBindings() => _instance ??= LlamaFfiBindings._();
  LlamaFfiBindings._();

  DynamicLibrary? _lib;
  bool _isLoaded = false;

  // Bound functions
  LlamaCreate? _create;
  LlamaDestroy? _destroy;
  LlamaInfer? _infer;
  LlamaIsValid? _isValid;
  LlamaReset? _reset;
  LlamaModelInfo? _modelInfo;
  LlamaVersion? _version;

  // ── Load library ─────────────────────────────────────────

  bool load() {
    if (_isLoaded) return true;

    try {
      if (Platform.isAndroid) {
        _lib = DynamicLibrary.open('libllama.so');
      } else if (Platform.isIOS || Platform.isMacOS) {
        // iOS: static link → dùng process()
        _lib = DynamicLibrary.process();
      } else if (Platform.isWindows) {
        _lib = DynamicLibrary.open('llama.dll');
      } else if (Platform.isLinux) {
         _lib = DynamicLibrary.open('libllama.so');
      } else {
        return false;
      }

      _bindAll();
      _isLoaded = true;
      return true;
    } catch (e) {
      return false;
    }
  }

  void _bindAll() {
    if (_lib == null) return;

    _create = _lib!
        .lookup<NativeFunction<NativeLlamaCreate>>('llama_bridge_create')
        .asFunction();

    _destroy = _lib!
        .lookup<NativeFunction<NativeLlamaDestroy>>('llama_bridge_destroy')
        .asFunction();

    _infer = _lib!
        .lookup<NativeFunction<NativeLlamaInfer>>('llama_bridge_infer')
        .asFunction();

    _isValid = _lib!
        .lookup<NativeFunction<NativeLlamaIsValid>>('llama_bridge_is_valid')
        .asFunction();

    _reset = _lib!
        .lookup<NativeFunction<NativeLlamaReset>>('llama_bridge_reset')
        .asFunction();

    try {
      _modelInfo = _lib!
          .lookup<NativeFunction<NativeLlamaModelInfo>>('llama_bridge_model_info')
          .asFunction();
    } catch (_) {}

    try {
      _version = _lib!
          .lookup<NativeFunction<NativeLlamaVersion>>('llama_bridge_version')
          .asFunction();
    } catch (_) {}
  }

  // ── Public API ────────────────────────────────────────────

  bool get isLoaded => _isLoaded;

  Pointer<Void> createContext(String modelPath, {int nCtx = 2048, int nThreads = 4}) {
    if (_create == null) return nullptr;

    final pathPtr = modelPath.toNativeUtf8();
    try {
      return _create!(pathPtr, nCtx, nThreads);
    } finally {
      malloc.free(pathPtr);
    }
  }

  void destroyContext(Pointer<Void> ctx) {
    if (_destroy == null || ctx == nullptr) return;
    _destroy!(ctx);
  }

  /// Chạy inference - trả về output string hoặc null nếu lỗi
  String? runInference(
    Pointer<Void> ctx,
    String prompt, {
    int maxTokens = 512,
    double temperature = 0.1,
  }) {
    if (_infer == null || ctx == nullptr) return null;

    const bufSize = 8192; // 8KB output buffer
    final promptPtr = prompt.toNativeUtf8();
    final outputPtr = malloc.allocate<Utf8>(bufSize);

    try {
      final bytesWritten = _infer!(
        ctx,
        promptPtr,
        outputPtr,
        bufSize,
        maxTokens,
        temperature,
      );

      if (bytesWritten <= 0) return null;
      return outputPtr.toDartString();
    } finally {
      malloc.free(promptPtr);
      malloc.free(outputPtr);
    }
  }

  bool isContextValid(Pointer<Void> ctx) {
    if (_isValid == null || ctx == nullptr) return false;
    return _isValid!(ctx) == 1;
  }

  void resetContext(Pointer<Void> ctx) {
    if (_reset == null || ctx == nullptr) return;
    _reset!(ctx);
  }

  String getModelInfo(Pointer<Void> ctx) {
    if (_modelInfo == null || ctx == nullptr) return 'unknown';
    return _modelInfo!(ctx).toDartString();
  }

  String getVersion() {
    if (_version == null) return 'unknown';
    return _version!().toDartString();
  }
}
