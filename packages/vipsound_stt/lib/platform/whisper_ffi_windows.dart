// packages/vipsound_stt/lib/stt_engine_whisper_mobile.dart
import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

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

/// Định nghĩa Struct để khớp với ABI của whisper.cpp
base class WhisperFullParams extends Struct {
  @Int32()
  external int strategy;

  @Int32()
  external int n_threads;

  @Int32()
  external int n_max_text_ctx;

  @Int32()
  external int offset_ms;

  @Int32()
  external int duration_ms;

  @Uint8()
  external int translate;

  @Uint8()
  external int no_context;

  @Uint8()
  external int no_timestamps;

  @Uint8()
  external int single_segment;

  @Uint8()
  external int print_special;

  @Uint8()
  external int print_progress;

  @Uint8()
  external int print_realtime;

  @Uint8()
  external int print_timestamps;
}

typedef NativeWhisperFullDefaultParamsByRef = Void Function(
    Pointer<WhisperFullParams>, Int32);
typedef WhisperFullDefaultParamsByRef = void Function(
    Pointer<WhisperFullParams>, int);

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
  late WhisperFullDefaultParamsByRef _defaultParamsByRef;

  bool load() {
    if (_loaded) return true;

    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;

      debugPrint('📁 EXE Dir: $exeDir');

      // List all DLLs in folder
      final dllFiles = Directory(exeDir)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.dll'))
          .map((f) => p.basename(f.path))
          .toList();

      debugPrint('📦 Available DLLs: ${dllFiles.join(", ")}');

      // ★ Load dependencies với full path và SetDllDirectory
      final dependencies = [
        'ggml.dll',
        'ggml-base.dll',
      ];

      // Set DLL search path (Windows API)
      _setDllDirectory(exeDir);

      for (final dll in dependencies) {
        final fullPath = p.join(exeDir, dll);

        if (!File(fullPath).existsSync()) {
          debugPrint('⚠️ $dll not found, trying to continue...');

          // Auto-create ggml-base.dll if missing
          if (dll == 'ggml-base.dll') {
            final ggmlPath = p.join(exeDir, 'ggml.dll');
            if (File(ggmlPath).existsSync()) {
              File(ggmlPath).copySync(fullPath);
              debugPrint('✅ Created ggml-base.dll from ggml.dll');
            }
          }
          continue;
        }

        try {
          final lib = DynamicLibrary.open(fullPath);
          debugPrint('✅ Loaded: $dll');
        } catch (e) {
          debugPrint('❌ Failed to load $dll: $e');

          // Try load by name only (let system search)
          try {
            DynamicLibrary.open(dll);
            debugPrint('✅ Loaded $dll (system search)');
          } catch (e2) {
            debugPrint('❌ Also failed with system search: $e2');
            return false;
          }
        }
      }

      // Load whisper.dll
      final whisperPath = p.join(exeDir, 'whisper.dll');
      if (!File(whisperPath).existsSync()) {
        debugPrint('❌ whisper.dll not found at: $whisperPath');
        return false;
      }

      _lib = DynamicLibrary.open(whisperPath);
      _bindFunctions();
      _loaded = true;

      debugPrint('✅✅ whisper.dll loaded successfully!');
      return true;
    } catch (e, stack) {
      debugPrint('❌ Load error: $e');
      debugPrint('Stack: $stack');
      return false;
    }
  }

// Helper to set DLL search directory (Windows only)
  void _setDllDirectory(String dir) {
    try {
      final kernel32 = DynamicLibrary.open('kernel32.dll');
      final setDllDirectory = kernel32.lookupFunction<
          Int32 Function(Pointer<Utf16>),
          int Function(Pointer<Utf16>)>('SetDllDirectoryW');

      final dirPtr = dir.toNativeUtf16();
      setDllDirectory(dirPtr);
      malloc.free(dirPtr);

      debugPrint('✅ SetDllDirectory: $dir');
    } catch (e) {
      debugPrint('⚠️ SetDllDirectory failed: $e (non-fatal)');
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

    _defaultParamsByRef = _lib!
        .lookup<NativeFunction<NativeWhisperFullDefaultParamsByRef>>(
            'whisper_full_default_params_by_ref')
        .asFunction();
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
    Pointer<WhisperFullParams> params = nullptr;
    Pointer<Float> samplesPtr = nullptr;

    try {
      // 1. Init context
      ctx = _initFromFile(modelPathNative);
      if (ctx.address == 0) {
        return WhisperFfiResult.error('whisper_init_from_file thất bại');
      }
      debugPrint('✅ Whisper context created');

      // 2. Allocate typed struct and get default params by ref
      params = calloc<WhisperFullParams>();
      _defaultParamsByRef(params, 0); // 0 = GREEDY
      debugPrint('✅ Default whisper params loaded');

      // 3. Alloc samples
      samplesPtr = malloc.allocate<Float>(pcmSamples.length * sizeOf<Float>());
      for (int i = 0; i < pcmSamples.length; i++) {
        samplesPtr[i] = pcmSamples[i];
      }

      // 4. Run
      debugPrint(
          '🎯 whisper_full: ${pcmSamples.length} samples, lang=$language');
      final ret =
          _full(ctx, params.cast<Void>(), samplesPtr, pcmSamples.length);

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
      if (params != nullptr) calloc.free(params);
      if (ctx != nullptr && ctx.address != 0) _free(ctx);
      malloc.free(modelPathNative);
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
