// packages/vipsound_stt/lib/stt_engine_whisper_mobile.dart
import 'dart:ffi';
import 'dart:io';
import 'dart:async';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';

// ─── Native typedefs ──────────────────────────────────────────────────────────

typedef NativeWhisperInitFromFile = Pointer<Void> Function(
    Pointer<Utf8> pathModel);
typedef WhisperInitFromFileFn = Pointer<Void> Function(Pointer<Utf8> pathModel);

typedef NativeWhisperFree = Void Function(Pointer<Void> ctx);
typedef WhisperFreeFn = void Function(Pointer<Void> ctx);

typedef NativeWhisperFull = Int32 Function(Pointer<Void> ctx,
    Pointer<Void> params, Pointer<Float> samples, Int32 nSamples);
typedef WhisperFullFn = int Function(Pointer<Void> ctx, Pointer<Void> params,
    Pointer<Float> samples, int nSamples);

typedef NativeWhisperFullDefaultParamsByRef = Void Function(
    Pointer<Void> params, Int32 strategy);
typedef WhisperFullDefaultParamsByRefFn = void Function(
    Pointer<Void> params, int strategy);

typedef NativeWhisperFullNSegments = Int32 Function(Pointer<Void> ctx);
typedef WhisperFullNSegmentsFn = int Function(Pointer<Void> ctx);

typedef NativeWhisperFullGetSegmentText = Pointer<Utf8> Function(
    Pointer<Void> ctx, Int32 iSegment);
typedef WhisperFullGetSegmentTextFn = Pointer<Utf8> Function(
    Pointer<Void> ctx, int iSegment);

typedef NativeWhisperFullGetSegmentT0 = Int64 Function(
    Pointer<Void> ctx, Int32 iSegment);
typedef WhisperFullGetSegmentT0Fn = int Function(
    Pointer<Void> ctx, int iSegment);

typedef NativeWhisperFullGetSegmentT1 = Int64 Function(
    Pointer<Void> ctx, Int32 iSegment);
typedef WhisperFullGetSegmentT1Fn = int Function(
    Pointer<Void> ctx, int iSegment);

// ─── Result model ─────────────────────────────────────────────────────────────

class WhisperFfiSegment {
  final String text;
  final int startMs; // milliseconds
  final int endMs;

  const WhisperFfiSegment({
    required this.text,
    required this.startMs,
    required this.endMs,
  });
}

class WhisperFfiResult {
  final List<WhisperFfiSegment> segments;
  final String fullText;
  final String? error;

  bool get hasError => error != null;

  const WhisperFfiResult({
    required this.segments,
    required this.fullText,
    this.error,
  });

  factory WhisperFfiResult.error(String msg) => WhisperFfiResult(
        segments: const [],
        fullText: '',
        error: msg,
      );
}

// ─── FFI Wrapper ──────────────────────────────────────────────────────────────

/// Direct FFI binding cho whisper.dll trên Windows.
/// Bypass hoàn toàn whisper_flutter_new (không có Windows support).
class WhisperFfiWindows {
  static WhisperFfiWindows? _instance;
  factory WhisperFfiWindows() => _instance ??= WhisperFfiWindows._internal();
  WhisperFfiWindows._internal();

  DynamicLibrary? _lib;
  bool _loaded = false;

  late WhisperInitFromFileFn _initFromFile;
  late WhisperFreeFn _free;
  late WhisperFullFn _full;
  late WhisperFullNSegmentsFn _nSegments;
  late WhisperFullGetSegmentTextFn _getSegmentText;
  late WhisperFullGetSegmentT0Fn _getSegmentT0;
  late WhisperFullGetSegmentT1Fn _getSegmentT1;
  WhisperFullDefaultParamsByRefFn? _defaultParamsByRef;

  // whisper_full_params size ~512 bytes (safe upper bound cho mọi version)
  static const int _kParamsSize = 512;

  bool load() {
    if (_loaded) return true;

    try {
      // ★ FIX: Dùng full path thay vì tên DLL
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final dllPath = '$exeDir\\whisper.dll'; // ← Backslash Windows
      final ggmlPath = '$exeDir\\ggml.dll';

      debugPrint('🔍 Loading DLL: $dllPath');

      // Check file exists
      if (!File(dllPath).existsSync()) {
        debugPrint('❌ whisper.dll not found at: $dllPath');
        return false;
      }

      if (!File(ggmlPath).existsSync()) {
        debugPrint(
            '⚠️ ggml.dll not found at: $ggmlPath (may cause load failure)');
      }

      // ★ Load ggml.dll trước (dependency)
      try {
        DynamicLibrary.open(ggmlPath);
        debugPrint('✅ ggml.dll loaded');
      } catch (e) {
        debugPrint('⚠️ ggml.dll load warning: $e');
      }

      // Load whisper.dll
      _lib = DynamicLibrary.open(dllPath);
      _bindFunctions();
      _loaded = true;

      debugPrint('✅ whisper.dll loaded successfully');
      return true;
    } catch (e, stack) {
      debugPrint('❌ Failed to load whisper.dll: $e');
      debugPrint('Stack: $stack');
      return false;
    }
  }

  void _bindFunctions() {
    _initFromFile = _lib!
        .lookup<NativeFunction<NativeWhisperInitFromFile>>(
            'whisper_init_from_file')
        .asFunction();

    _free = _lib!
        .lookup<NativeFunction<NativeWhisperFree>>('whisper_free')
        .asFunction();

    _full = _lib!
        .lookup<NativeFunction<NativeWhisperFull>>('whisper_full')
        .asFunction();

    _nSegments = _lib!
        .lookup<NativeFunction<NativeWhisperFullNSegments>>(
            'whisper_full_n_segments')
        .asFunction();

    _getSegmentText = _lib!
        .lookup<NativeFunction<NativeWhisperFullGetSegmentText>>(
            'whisper_full_get_segment_text')
        .asFunction();

    _getSegmentT0 = _lib!
        .lookup<NativeFunction<NativeWhisperFullGetSegmentT0>>(
            'whisper_full_get_segment_t0')
        .asFunction();

    _getSegmentT1 = _lib!
        .lookup<NativeFunction<NativeWhisperFullGetSegmentT1>>(
            'whisper_full_get_segment_t1')
        .asFunction();

    // Optional - có trong whisper.cpp mới
    try {
      _defaultParamsByRef = _lib!
          .lookup<NativeFunction<NativeWhisperFullDefaultParamsByRef>>(
              'whisper_full_default_params_by_ref')
          .asFunction();
    } catch (_) {
      _defaultParamsByRef = null;
    }
  }

  /// Transcribe PCM samples bằng model tại [modelPath]
  Future<WhisperFfiResult> transcribe({
    required String modelPath,
    required List<double> pcmSamples,
    String language = 'en',
  }) async {
    if (!_loaded && !load()) {
      return WhisperFfiResult.error('whisper.dll chưa được load');
    }

    if (!File(modelPath).existsSync()) {
      return WhisperFfiResult.error('Model không tồn tại: $modelPath');
    }

    final modelPathNative = modelPath.toNativeUtf8();
    Pointer<Void> ctx = nullptr;
    Pointer<Void> paramsPtr = nullptr;
    Pointer<Float> samplesPtr = nullptr;

    try {
      // 1. Init context
      ctx = _initFromFile(modelPathNative);
      if (ctx.address == 0) {
        return WhisperFfiResult.error('whisper_init_from_file thất bại');
      }
      debugPrint('✅ Whisper context created');

      // 2. Alloc & fill params
      paramsPtr = malloc.allocate<Void>(_kParamsSize);
      _fillParams(paramsPtr, language);

      // 3. Alloc samples
      samplesPtr = malloc.allocate<Float>(pcmSamples.length * sizeOf<Float>());
      for (int i = 0; i < pcmSamples.length; i++) {
        samplesPtr[i] = pcmSamples[i];
      }

      // 4. Run
      debugPrint(
          '🎯 whisper_full: ${pcmSamples.length} samples, lang=$language');
      final ret = _full(ctx, paramsPtr, samplesPtr, pcmSamples.length);

      if (ret != 0) {
        return WhisperFfiResult.error('whisper_full trả về lỗi: $ret');
      }

      // 5. Extract segments
      final nSeg = _nSegments(ctx);
      debugPrint('📝 Whisper: $nSeg segments');

      final segments = <WhisperFfiSegment>[];

      for (int i = 0; i < nSeg; i++) {
        final textPtr = _getSegmentText(ctx, i);
        if (textPtr.address == 0) continue;

        final text = textPtr.toDartString().trim();
        final t0 = _getSegmentT0(ctx, i); // centiseconds
        final t1 = _getSegmentT1(ctx, i);

        if (text.isNotEmpty && !_isNoise(text)) {
          segments.add(WhisperFfiSegment(
            text: text,
            startMs: t0 * 10, // centiseconds → ms
            endMs: t1 * 10,
          ));
        }
      }

      final fullText = segments.map((s) => s.text).join(' ');
      debugPrint('✅ Whisper done: ${fullText.length} chars');

      return WhisperFfiResult(segments: segments, fullText: fullText);
    } catch (e, stack) {
      debugPrint('❌ WhisperFfiWindows.transcribe error: $e\n$stack');
      return WhisperFfiResult.error(e.toString());
    } finally {
      // Free theo đúng thứ tự
      if (samplesPtr != nullptr) malloc.free(samplesPtr);
      if (paramsPtr != nullptr) malloc.free(paramsPtr);
      if (ctx != nullptr && ctx.address != 0) _free(ctx);
      malloc.free(modelPathNative);
    }
  }

  void _fillParams(Pointer<Void> params, String language) {
    // Zero toàn bộ buffer trước
    final bytePtr = params.cast<Uint8>();
    for (int i = 0; i < _kParamsSize; i++) {
      bytePtr[i] = 0;
    }

    final int32Ptr = params.cast<Int32>();

    // whisper_full_params layout (whisper.cpp, stable):
    // [0]  int strategy          = 0 (GREEDY)
    // [1]  int n_threads         = 4
    // [2]  int n_max_text_ctx    = 16384
    // [3]  int offset_ms         = 0
    // [4]  int duration_ms       = 0 (0 = toàn bộ)
    int32Ptr[0] = 0; // GREEDY
    int32Ptr[1] = 4; // n_threads
    int32Ptr[2] = 16384; // n_max_text_ctx
    int32Ptr[3] = 0; // offset_ms
    int32Ptr[4] = 0; // duration_ms

    // bool fields bắt đầu từ offset 20 (sau 5 int32 = 20 bytes)
    // [20] bool translate        = false
    // [21] bool no_context       = false
    // [22] bool no_timestamps    = false
    // [23] bool single_segment   = false
    // [24] bool print_special    = false
    // [25] bool print_progress   = false
    // [26] bool print_realtime   = false
    // [27] bool print_timestamps = true
    bytePtr[20] = 0; // translate = false
    bytePtr[21] = 0; // no_context = false
    bytePtr[22] = 0; // no_timestamps = false
    bytePtr[23] = 0; // single_segment = false
    bytePtr[24] = 0; // print_special = false
    bytePtr[25] = 0; // print_progress = false
    bytePtr[26] = 0; // print_realtime = false
    bytePtr[27] = 1; // print_timestamps = true

    // language string pointer tại offset 72 (sau bool fields + padding)
    // Để null → whisper tự detect, hoặc dùng whisper_full_default_params_by_ref
    // Nếu có _defaultParamsByRef thì dùng nó thay thế toàn bộ logic trên
    if (_defaultParamsByRef != null) {
      _defaultParamsByRef!(params, 0); // 0 = GREEDY
    }
  }

  bool _isNoise(String text) {
    final upper = text.toUpperCase();
    return upper.contains('[MUSIC]') ||
        upper.contains('[NOISE]') ||
        upper.contains('[LAUGHTER]') ||
        upper.contains('[BLANK_AUDIO]');
  }
}
