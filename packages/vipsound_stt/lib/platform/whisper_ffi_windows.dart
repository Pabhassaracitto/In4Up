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

/// Định nghĩa Struct để khớp với ABI của `whisper_vad_params` trong `whisper.h`
base class WhisperVadParams extends Struct {
  @Float()
  external double threshold;
  @Int32()
  external int min_speech_duration_ms;
  @Int32()
  external int min_silence_duration_ms;
  @Float()
  external double max_speech_duration_s;
  @Int32()
  external int speech_pad_ms;
  @Float()
  external double samples_overlap;
}

/// Định nghĩa Struct để khớp với ABI của `whisper_full_params` trong `whisper.h`
/// Cần định nghĩa TẤT CẢ các trường để đảm bảo ABI tương thích và tránh corrupt memory.
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

  // [EXPERIMENTAL] token-level timestamps
  @Uint8()
  external int token_timestamps;
  @Float()
  external double thold_pt;
  @Float()
  external double thold_ptsum;
  @Int32()
  external int max_len;
  @Uint8()
  external int split_on_word;
  @Int32()
  external int max_tokens;

  // [EXPERIMENTAL] speed-up techniques
  @Uint8()
  external int debug_mode;
  @Int32()
  external int audio_ctx;

  // [EXPERIMENTAL] [TDRZ] tinydiarize
  @Uint8()
  external int tdrz_enable;

  external Pointer<Utf8> suppress_regex;

  external Pointer<Utf8> initial_prompt;
  @Uint8()
  external int carry_initial_prompt;
  external Pointer<Int32> prompt_tokens;
  @Int32()
  external int prompt_n_tokens;

  external Pointer<Utf8> language;
  @Uint8()
  external int detect_language;

  @Uint8()
  external int suppress_blank;
  @Uint8()
  external int suppress_nst;

  @Float()
  external double temperature;
  @Float()
  external double max_initial_ts;
  @Float()
  external double length_penalty;

  // fallback parameters
  @Float()
  external double temperature_inc;
  @Float()
  external double entropy_thold;
  @Float()
  external double logprob_thold;
  @Float()
  external double no_speech_thold;

  // Nested structs (greedy and beam_search) - Dart FFI flattens these
  @Int32() // greedy.best_of
  external int greedy_best_of;

  @Int32() // beam_search.beam_size
  external int beam_search_beam_size;
  @Float() // beam_search.patience
  external double beam_search_patience;

  // Callbacks - represented as Pointer<Void> to match size/alignment
  external Pointer<Void> new_segment_callback;
  external Pointer<Void> new_segment_callback_user_data;
  external Pointer<Void> progress_callback;
  external Pointer<Void> progress_callback_user_data;
  external Pointer<Void> encoder_begin_callback;
  external Pointer<Void> encoder_begin_callback_user_data;
  external Pointer<Void> abort_callback;
  external Pointer<Void> abort_callback_user_data;
  external Pointer<Void> logits_filter_callback;
  external Pointer<Void> logits_filter_callback_user_data;

  // Grammar
  external Pointer<Pointer<Void>> grammar_rules;
  @Size() // size_t n_grammar_rules;
  external int n_grammar_rules;
  @Size() // size_t i_start_rule;
  external int i_start_rule;
  @Float() // float grammar_penalty;
  external double grammar_penalty;

  // Voice Activity Detection (VAD) params
  @Uint8()
  external int vad;
  external Pointer<Utf8> vad_model_path;

  external WhisperVadParams vad_params; // Nested struct
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
  // Removed _free from here, it's defined below
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
      // Get the directory of the executable
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

      // Load dependencies with full path and SetDllDirectory
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

          // Auto-create ggml-base.dll if missing (common workaround)
          if (dll == 'ggml-base.dll') {
            final ggmlPath = p.join(exeDir, 'ggml.dll');
            if (File(ggmlPath).existsSync()) {
              File(ggmlPath).copySync(fullPath);
              debugPrint('✅ Created ggml-base.dll from ggml.dll');
            } else {
              debugPrint('❌ ggml.dll not found to create ggml-base.dll');
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
      return true; // Return true if whisper.dll loaded
    } catch (e, stack) {
      debugPrint('❌ Load error: $e');
      debugPrint('Stack: $stack');
      return false;
    }
  }

// Helper to set DLL search directory (Windows only)
  void _setDllDirectory(String dir) {
    // Restored this function
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
    // Bind _initFromFile
    _initFromFile = _lib!
        .lookup<NativeFunction<NativeWhisperInitFromFile>>(
            'whisper_init_from_file')
        .asFunction();

    _free = _lib!
        .lookup<NativeFunction<NativeWhisperFree>>('whisper_free')
        .asFunction();

    // Bind _full
    _full = _lib!
        .lookup<NativeFunction<NativeWhisperFull>>('whisper_full')
        .asFunction();

    // Bind _nSegments
    _nSegments = _lib!
        .lookup<NativeFunction<NativeWhisperFullNSegments>>(
            'whisper_full_n_segments')
        .asFunction();

    _getSegmentText = _lib!
        .lookup<NativeFunction<NativeWhisperFullGetSegmentText>>(
            'whisper_full_get_segment_text')
        .asFunction();

    // Bind _getSegmentT0
    _getSegmentT0 = _lib!
        .lookup<NativeFunction<NativeWhisperFullGetSegmentT0>>(
            'whisper_full_get_segment_t0')
        .asFunction();

    // Bind _getSegmentT1
    _getSegmentT1 = _lib!
        .lookup<NativeFunction<NativeWhisperFullGetSegmentT1>>(
            'whisper_full_get_segment_t1')
        .asFunction();

    // Bind _defaultParamsByRef
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
    Pointer<Uint8> paramsRaw = nullptr;
    Pointer<Float> samplesPtr = nullptr;

    try {
      // 1. Init context
      ctx = _initFromFile(modelPathNative);
      if (ctx.address == 0) {
        return WhisperFfiResult.error('whisper_init_from_file thất bại');
      }
      debugPrint('✅ Whisper context created');

      // 2. Allocate large raw buffer to avoid ABI mismatch/buffer overflow (Safe Fix)
      paramsRaw = calloc<Uint8>(1024);
      _defaultParamsByRef(paramsRaw.cast<WhisperFullParams>(), 0); // 0 = GREEDY

      // ✅ Force disable VAD by zeroing memory vùng cuối (đảm bảo không crash do ABI mismatch)
      for (int i = 128; i < 256; i++) {
        paramsRaw[i] = 0;
      }
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
          _full(ctx, paramsRaw.cast<Void>(), samplesPtr, pcmSamples.length);

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
      if (paramsRaw != nullptr) calloc.free(paramsRaw);
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
