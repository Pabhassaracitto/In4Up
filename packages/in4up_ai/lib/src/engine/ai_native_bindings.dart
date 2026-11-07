import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';

/// Thông tin đọc thẳng từ header GGUF — KHÔNG cần load model vào RAM
/// (HYMT-003). Dùng để trả lời "file này llama.cpp đã pin có load được không"
/// TRƯỚC khi hứa với người dùng, thay vì đoán qua magic + kích thước.
class GgufInfo {
  const GgufInfo({
    required this.arch,
    required this.quant,
    required this.supported,
    required this.hasChatTemplate,
    required this.tensorCount,
  });

  /// `general.architecture` trong GGUF ("hunyuan-dense", "llama", …).
  final String arch;

  /// Loại quant của tensor đầu ("q2_0", "q1_0", "f16", "UNKNOWN:41"…).
  final String quant;

  /// `false` = llama.cpp đã pin CHẮC CHẮN không load được file này.
  final bool supported;

  /// GGUF có `tokenizer.chat_template` (Jinja) hay không.
  final bool hasChatTemplate;

  final int tensorCount;

  bool get isHunyuan => arch.contains('hunyuan');

  /// Số byte đầu file cần đọc để inspect (8 MB) — xem
  /// `IN4UP_AI_GGUF_PREFIX_BYTES` bên C.
  static const int prefixBytes = 8 * 1024 * 1024;

  @override
  String toString() =>
      'GgufInfo(arch=$arch, quant=$quant, supported=$supported, '
      'template=$hasChatTemplate, tensors=$tensorCount)';
}

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
            _library.lookupFunction<_DestroyNative, _Destroy>(destroySymbol),
        // HYMT-003: symbol chẩn đoán là TUỲ CHỌN — bản native cũ không có
        // cũng không được làm hỏng engine, chỉ mất phần "nói rõ nguyên nhân".
        _inspect = _lookupInspect(_library),
        _readLog = _lookupLastLog(_library);

  final ffi.DynamicLibrary _library;
  final _Create _create;
  final _Generate _generate;
  final _FreeString _freeString;
  final _Destroy _destroy;
  final _Inspect? _inspect;
  final _LastLog? _readLog;

  static _Inspect? _lookupInspect(ffi.DynamicLibrary lib) {
    try {
      return lib.lookupFunction<_InspectNative, _Inspect>(
          'in4up_ai_inspect_gguf');
    } catch (_) {
      return null;
    }
  }

  static _LastLog? _lookupLastLog(ffi.DynamicLibrary lib) {
    try {
      return lib.lookupFunction<_LastLogNative, _LastLog>('in4up_ai_last_log');
    } catch (_) {
      return null;
    }
  }

  /// Bản native có symbol chẩn đoán GGUF hay không (build cũ = false).
  bool get canInspectGguf => _inspect != null;

  /// Bản native có đọc được log llama.cpp hay không.
  bool get canReadLog => _readLog != null;

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

  /// Đọc header/KV của file GGUF từ [prefix] (N byte đầu file, xem
  /// [GgufInfo.prefixBytes]). `null` = bản native không có symbol chẩn đoán
  /// hoặc prefix không parse được.
  ///
  /// Không cấp phát model, không gọi `llama_backend_init` ⇒ rẻ, gọi được trên
  /// luồng UI trước khi quyết định "dịch bằng Hy-MT hay báo lỗi rõ".
  GgufInfo? inspectGguf(List<int> prefix) {
    final inspect = _inspect;
    if (inspect == null || prefix.isEmpty) return null;
    final buf = calloc<ffi.Uint8>(prefix.length);
    final arch = calloc<ffi.Char>(64);
    final quant = calloc<ffi.Char>(32);
    final supported = calloc<ffi.Int>();
    final hasTemplate = calloc<ffi.Int>();
    final nTensors = calloc<ffi.Int>();
    try {
      buf.asTypedList(prefix.length).setAll(0, prefix);
      final rc = inspect(buf, prefix.length, arch, 64, quant, 32, supported,
          hasTemplate, nTensors);
      if (rc != 0) return null;
      return GgufInfo(
        arch: arch.cast<Utf8>().toDartString(),
        quant: quant.cast<Utf8>().toDartString(),
        supported: supported.value != 0,
        hasChatTemplate: hasTemplate.value != 0,
        tensorCount: nTensors.value,
      );
    } catch (_) {
      return null;
    } finally {
      calloc.free(buf);
      calloc.free(arch);
      calloc.free(quant);
      calloc.free(supported);
      calloc.free(hasTemplate);
      calloc.free(nTensors);
    }
  }

  /// Log llama.cpp/ggml gần nhất (tối đa [maxBytes]). Rỗng nếu bản native
  /// không hỗ trợ. Đây là nguồn DUY NHẤT giải thích được "load failed" thật
  /// sự (unknown architecture / wrong tensor type / OOM).
  String lastLog({int maxBytes = 8192}) {
    final read = _readLog;
    if (read == null) return '';
    final buf = calloc<ffi.Char>(maxBytes);
    try {
      read(buf, maxBytes);
      return buf.cast<Utf8>().toDartString();
    } catch (_) {
      return '';
    } finally {
      calloc.free(buf);
    }
  }
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

typedef _InspectNative = ffi.Int32 Function(
    ffi.Pointer<ffi.Uint8>,
    ffi.Int32,
    ffi.Pointer<ffi.Char>,
    ffi.Int32,
    ffi.Pointer<ffi.Char>,
    ffi.Int32,
    ffi.Pointer<ffi.Int>,
    ffi.Pointer<ffi.Int>,
    ffi.Pointer<ffi.Int>);
typedef _Inspect = int Function(
    ffi.Pointer<ffi.Uint8>,
    int,
    ffi.Pointer<ffi.Char>,
    int,
    ffi.Pointer<ffi.Char>,
    int,
    ffi.Pointer<ffi.Int>,
    ffi.Pointer<ffi.Int>,
    ffi.Pointer<ffi.Int>);

typedef _LastLogNative = ffi.Void Function(ffi.Pointer<ffi.Char>, ffi.Int32);
typedef _LastLog = void Function(ffi.Pointer<ffi.Char>, int);
