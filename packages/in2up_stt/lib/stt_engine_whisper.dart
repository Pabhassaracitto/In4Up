// packages/in2up_stt/lib/stt_engine_whisper.dart
//
// in2up v11.0 — Stateless Whisper Engine
// Đã rà soát và sửa toàn bộ FFI signatures theo whisper.cpp chuẩn.
//
// NGUỒN THAM KHẢO:
//   https://github.com/ggerganov/whisper.cpp/blob/master/whisper.h
//   Commit được verify: master branch, struct whisper_full_params
//
// NGUYÊN TẮC AN TOÀN BỘ NHỚ:
// ┌────────────────────────────────────────────────────────────────────┐
// │  1. Mọi calloc.alloc() đều có calloc.free() tương ứng trong      │
// │     finally block.                                                 │
// │  2. whisper_context được free trong finally của _transcribeCore.  │
// │  3. Không giữ Pointer qua ranh giới hàm (no escaping pointers).  │
// │  4. String C (const char*) từ Whisper KHÔNG được free —          │
// │     chúng thuộc về context, giải phóng cùng whisper_free().      │
// │  5. Struct params được cấp phát bằng calloc, giải phóng sau      │
// │     whisper_full() hoàn thành.                                    │
// └────────────────────────────────────────────────────────────────────┘

import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'models/content_id.dart';
import 'models/stt_isolate_payload.dart';
import 'models/stt_model_info.dart';
import 'models/stt_result.dart';

// ═══════════════════════════════════════════════════════════════════════════
// PHẦN 1: FFI TYPE DEFINITIONS — ĐÃ RÀ SOÁT VỚI WHISPER.H
// ═══════════════════════════════════════════════════════════════════════════

final class WhisperContext extends ffi.Opaque {}

final class WhisperState extends ffi.Opaque {}

// ─────────────────────────────────────────────────────────────────────────────
// whisper_context_params + các struct hỗ trợ
// (whisper.h — dùng cho whisper_init_from_file_with_params)
// ─────────────────────────────────────────────────────────────────────────────

final class WhisperAhead extends ffi.Struct {
  @ffi.Int32()
  external int n_text_layer;

  @ffi.Int32()
  external int n_head;
}

final class WhisperAheads extends ffi.Struct {
  @ffi.Size()
  external int n_heads;

  external ffi.Pointer<WhisperAhead> heads;
}

final class WhisperContextParams extends ffi.Struct {
  @ffi.Bool()
  external bool use_gpu;

  @ffi.Bool()
  external bool flash_attn;

  @ffi.Int32()
  external int gpu_device;

  @ffi.Bool()
  external bool dtw_token_timestamps;

  @ffi.Int32()
  external int dtw_aheads_preset;

  @ffi.Int32()
  external int dtw_n_top;

  external WhisperAheads dtw_aheads;

  @ffi.Size()
  external int dtw_mem_size;
}

// ─────────────────────────────────────────────────────────────────────────────
// Callback typedefs (Native) cho các con trỏ hàm trong whisper_full_params
// ─────────────────────────────────────────────────────────────────────────────

typedef _WhisperNewSegmentCbN = ffi.Void Function(ffi.Pointer<WhisperContext>,
    ffi.Pointer<WhisperState>, ffi.Int32, ffi.Pointer<ffi.Void>);

typedef _WhisperProgressCbN = ffi.Void Function(ffi.Pointer<WhisperContext>,
    ffi.Pointer<WhisperState>, ffi.Int32, ffi.Pointer<ffi.Void>);

typedef _WhisperEncoderBeginCbN = ffi.Bool Function(
    ffi.Pointer<WhisperContext>, ffi.Pointer<WhisperState>, ffi.Pointer<ffi.Void>);

typedef _GgmlAbortCbN = ffi.Bool Function(ffi.Pointer<ffi.Void>);

typedef _WhisperLogitsFilterCbN = ffi.Void Function(
    ffi.Pointer<WhisperContext>,
    ffi.Pointer<WhisperState>,
    ffi.Pointer<WhisperTokenData>,
    ffi.Int32,
    ffi.Pointer<ffi.Float>,
    ffi.Pointer<ffi.Void>);

// ─────────────────────────────────────────────────────────────────────────────
// Struct nhỏ nhúng trong whisper_full_params
// ─────────────────────────────────────────────────────────────────────────────

final class _WhisperGreedyParams extends ffi.Struct {
  @ffi.Int32()
  external int best_of;
}

final class _WhisperBeamSearchParams extends ffi.Struct {
  @ffi.Int32()
  external int beam_size;

  @ffi.Float()
  external double patience;
}

final class WhisperGrammarElement extends ffi.Struct {
  @ffi.Int32()
  external int type;

  @ffi.Uint32()
  external int value;
}

final class WhisperVadParams extends ffi.Struct {
  @ffi.Float()
  external double threshold;

  @ffi.Int32()
  external int min_speech_duration_ms;

  @ffi.Int32()
  external int min_silence_duration_ms;

  @ffi.Float()
  external double max_speech_duration_s;

  @ffi.Int32()
  external int speech_pad_ms;

  @ffi.Float()
  external double samples_overlap;
}

// ─────────────────────────────────────────────────────────────────────────────
// whisper_full_params — ĐẦY ĐỦ theo whisper.h (không cắt bớt trường)
// ─────────────────────────────────────────────────────────────────────────────

final class WhisperFullParams extends ffi.Struct {
  @ffi.Int32()
  external int strategy;

  @ffi.Int32()
  external int n_threads;

  @ffi.Int32()
  external int n_max_text_ctx;

  @ffi.Int32()
  external int offset_ms;

  @ffi.Int32()
  external int duration_ms;

  @ffi.Bool()
  external bool translate;

  @ffi.Bool()
  external bool no_context;

  @ffi.Bool()
  external bool no_timestamps;

  @ffi.Bool()
  external bool single_segment;

  @ffi.Bool()
  external bool print_special;

  @ffi.Bool()
  external bool print_progress;

  @ffi.Bool()
  external bool print_realtime;

  @ffi.Bool()
  external bool print_timestamps;

  @ffi.Bool()
  external bool token_timestamps;

  @ffi.Float()
  external double thold_pt;

  @ffi.Float()
  external double thold_ptsum;

  @ffi.Int32()
  external int max_len;

  @ffi.Bool()
  external bool split_on_word;

  @ffi.Int32()
  external int max_tokens;

  @ffi.Bool()
  external bool debug_mode;

  @ffi.Int32()
  external int audio_ctx;

  @ffi.Bool()
  external bool tdrz_enable;

  external ffi.Pointer<ffi.Char> suppress_regex;

  external ffi.Pointer<ffi.Char> initial_prompt;

  @ffi.Bool()
  external bool carry_initial_prompt;

  external ffi.Pointer<ffi.Int32> prompt_tokens;

  @ffi.Int32()
  external int prompt_n_tokens;

  external ffi.Pointer<ffi.Char> language;

  @ffi.Bool()
  external bool detect_language;

  @ffi.Bool()
  external bool suppress_blank;

  @ffi.Bool()
  external bool suppress_nst;

  @ffi.Float()
  external double temperature;

  @ffi.Float()
  external double max_initial_ts;

  @ffi.Float()
  external double length_penalty;

  @ffi.Float()
  external double temperature_inc;

  @ffi.Float()
  external double entropy_thold;

  @ffi.Float()
  external double logprob_thold;

  @ffi.Float()
  external double no_speech_thold;

  external _WhisperGreedyParams greedy;

  external _WhisperBeamSearchParams beam_search;

  external ffi.Pointer<ffi.NativeFunction<_WhisperNewSegmentCbN>>
      new_segment_callback;

  external ffi.Pointer<ffi.Void> new_segment_callback_user_data;

  external ffi.Pointer<ffi.NativeFunction<_WhisperProgressCbN>>
      progress_callback;

  external ffi.Pointer<ffi.Void> progress_callback_user_data;

  external ffi.Pointer<ffi.NativeFunction<_WhisperEncoderBeginCbN>>
      encoder_begin_callback;

  external ffi.Pointer<ffi.Void> encoder_begin_callback_user_data;

  external ffi.Pointer<ffi.NativeFunction<_GgmlAbortCbN>> abort_callback;

  external ffi.Pointer<ffi.Void> abort_callback_user_data;

  external ffi.Pointer<ffi.NativeFunction<_WhisperLogitsFilterCbN>>
      logits_filter_callback;

  external ffi.Pointer<ffi.Void> logits_filter_callback_user_data;

  external ffi.Pointer<ffi.Pointer<WhisperGrammarElement>> grammar_rules;

  @ffi.Size()
  external int n_grammar_rules;

  @ffi.Size()
  external int i_start_rule;

  @ffi.Float()
  external double grammar_penalty;

  @ffi.Bool()
  external bool vad;

  external ffi.Pointer<ffi.Char> vad_model_path;

  external WhisperVadParams vad_params;
}

final class WhisperTokenData extends ffi.Struct {
  @ffi.Int32()
  external int id;

  @ffi.Int32()
  external int tid;

  @ffi.Float()
  external double p;

  @ffi.Float()
  external double plog;

  @ffi.Float()
  external double pt;

  @ffi.Float()
  external double ptsum;

  @ffi.Int64()
  external int t0;

  @ffi.Int64()
  external int t1;

  @ffi.Int64()
  external int t_dtw;

  @ffi.Float()
  external double vlen;
}

// ═══════════════════════════════════════════════════════════════════════════
// PHẦN 2: FFI FUNCTION TYPEDEFS
// ═══════════════════════════════════════════════════════════════════════════

// whisper_init_from_file_with_params — API mới (recommended trong whisper.h),
// thay thế cho whisper_init_from_file bị deprecated (có thể bị bỏ khỏi build).
typedef _WhisperContextDefaultParamsN = WhisperContextParams Function();
typedef _WhisperContextDefaultParamsD = WhisperContextParams Function();

typedef _WhisperInitFromFileWithParamsN = ffi.Pointer<WhisperContext> Function(
    ffi.Pointer<ffi.Char>, WhisperContextParams);
typedef _WhisperInitFromFileWithParamsD = ffi.Pointer<WhisperContext> Function(
    ffi.Pointer<ffi.Char>, WhisperContextParams);

// whisper_init_from_file — API deprecated, giữ lại làm fallback cho DLL cũ.
typedef _WhisperInitFromFileN = ffi.Pointer<WhisperContext> Function(
    ffi.Pointer<ffi.Char>);
typedef _WhisperInitFromFileD = ffi.Pointer<WhisperContext> Function(
    ffi.Pointer<ffi.Char>);

typedef _WhisperFreeN = ffi.Void Function(ffi.Pointer<WhisperContext>);
typedef _WhisperFreeD = void Function(ffi.Pointer<WhisperContext>);

typedef _WhisperFullDefaultParamsN = WhisperFullParams Function(ffi.Int32);
typedef _WhisperFullDefaultParamsD = WhisperFullParams Function(int);

typedef _WhisperFullN = ffi.Int32 Function(ffi.Pointer<WhisperContext>,
    WhisperFullParams, ffi.Pointer<ffi.Float>, ffi.Int32);
typedef _WhisperFullD = int Function(ffi.Pointer<WhisperContext>,
    WhisperFullParams, ffi.Pointer<ffi.Float>, int);

typedef _WhisperFullNSegsN = ffi.Int32 Function(ffi.Pointer<WhisperContext>);
typedef _WhisperFullNSegsD = int Function(ffi.Pointer<WhisperContext>);

typedef _WhisperGetSegTextN = ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<WhisperContext>, ffi.Int32);
typedef _WhisperGetSegTextD = ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<WhisperContext>, int);

typedef _WhisperGetSegT0N = ffi.Int64 Function(
    ffi.Pointer<WhisperContext>, ffi.Int32);
typedef _WhisperGetSegT0D = int Function(ffi.Pointer<WhisperContext>, int);

typedef _WhisperGetSegT1N = ffi.Int64 Function(
    ffi.Pointer<WhisperContext>, ffi.Int32);
typedef _WhisperGetSegT1D = int Function(ffi.Pointer<WhisperContext>, int);

typedef _WhisperFullNTokensN = ffi.Int32 Function(
    ffi.Pointer<WhisperContext>, ffi.Int32);
typedef _WhisperFullNTokensD = int Function(ffi.Pointer<WhisperContext>, int);

typedef _WhisperGetTokenDataN = WhisperTokenData Function(
    ffi.Pointer<WhisperContext>, ffi.Int32, ffi.Int32);
typedef _WhisperGetTokenDataD = WhisperTokenData Function(
    ffi.Pointer<WhisperContext>, int, int);

typedef _WhisperGetTokenTextN = ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<WhisperContext>, ffi.Int32, ffi.Int32);
typedef _WhisperGetTokenTextD = ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<WhisperContext>, int, int);

// ═══════════════════════════════════════════════════════════════════════════
// PHẦN 2B: LANGUAGE PINNER
// ═══════════════════════════════════════════════════════════════════════════

class _LanguagePinner {
  ffi.Pointer<Utf8>? _ptr;

  ffi.Pointer<ffi.Char> pin(String languageCode) {
    assert(_ptr == null, 'LanguagePinner đã được dùng — gọi dispose() trước');
    _ptr = languageCode.toNativeUtf8(allocator: calloc);
    return _ptr!.cast<ffi.Char>();
  }

  void dispose() {
    if (_ptr != null) {
      calloc.free(_ptr!);
      _ptr = null;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PHẦN 3: FFI LIBRARY WRAPPER
// ═══════════════════════════════════════════════════════════════════════════

class _WhisperLib {
  // Init functions — có thể không có trong mọi build:
  //  - whisper_context_default_params + whisper_init_from_file_with_params
  //    (API mới, recommended trong whisper.h)
  //  - whisper_init_from_file (API deprecated, chỉ dùng khi DLL cũ)
  final _WhisperContextDefaultParamsD? whisperContextDefaultParams;
  final _WhisperInitFromFileWithParamsD? whisperInitFromFileWithParams;
  final _WhisperInitFromFileD? whisperInitFromFile;

  // Các hàm còn lại — bắt buộc có (đều là API ổn định).
  final _WhisperFreeD whisperFree;
  final _WhisperFullDefaultParamsD whisperFullDefaultParams;
  final _WhisperFullD whisperFull;
  final _WhisperFullNSegsD whisperFullNSegments;
  final _WhisperGetSegTextD whisperFullGetSegmentText;
  final _WhisperGetSegT0D whisperFullGetSegmentT0;
  final _WhisperGetSegT1D whisperFullGetSegmentT1;
  final _WhisperFullNTokensD whisperFullNTokens;
  final _WhisperGetTokenDataD whisperFullGetTokenData;
  final _WhisperGetTokenTextD whisperFullGetTokenText;

  /// Lookup một symbol nhưng KHÔNG ném lỗi nếu thiếu → trả về null.
  /// Dùng try/catch quanh [ffi.DynamicLibrary.lookupFunction] (giống cách
  /// [ffi.DynamicLibrary.open] có thể ném lỗi khi symbol không tồn tại).
  static _WhisperContextDefaultParamsD? _lookupContextDefaultParams(
          ffi.DynamicLibrary dylib) =>
      _safe(() => dylib
          .lookupFunction<_WhisperContextDefaultParamsN,
              _WhisperContextDefaultParamsD>('whisper_context_default_params'));

  static _WhisperInitFromFileWithParamsD? _lookupInitFromFileWithParams(
          ffi.DynamicLibrary dylib) =>
      _safe(() => dylib
          .lookupFunction<_WhisperInitFromFileWithParamsN,
              _WhisperInitFromFileWithParamsD>(
              'whisper_init_from_file_with_params'));

  static _WhisperInitFromFileD? _lookupInitFromFile(ffi.DynamicLibrary dylib) =>
      _safe(() => dylib.lookupFunction<_WhisperInitFromFileN, _WhisperInitFromFileD>(
          'whisper_init_from_file'));

  static T? _safe<T>(T Function() block) {
    try {
      return block();
    } catch (_) {
      return null;
    }
  }

  _WhisperLib(ffi.DynamicLibrary dylib)
      : whisperContextDefaultParams =
            _lookupContextDefaultParams(dylib),
        whisperInitFromFileWithParams =
            _lookupInitFromFileWithParams(dylib),
        whisperInitFromFile = _lookupInitFromFile(dylib),
        whisperFree = dylib.lookupFunction<_WhisperFreeN, _WhisperFreeD>(
          'whisper_free',
        ),
        whisperFullDefaultParams = dylib.lookupFunction<
            _WhisperFullDefaultParamsN, _WhisperFullDefaultParamsD>(
          'whisper_full_default_params',
        ),
        whisperFull =
            dylib.lookupFunction<_WhisperFullN, _WhisperFullD>('whisper_full'),
        whisperFullNSegments =
            dylib.lookupFunction<_WhisperFullNSegsN, _WhisperFullNSegsD>(
          'whisper_full_n_segments',
        ),
        whisperFullGetSegmentText =
            dylib.lookupFunction<_WhisperGetSegTextN, _WhisperGetSegTextD>(
          'whisper_full_get_segment_text',
        ),
        whisperFullGetSegmentT0 =
            dylib.lookupFunction<_WhisperGetSegT0N, _WhisperGetSegT0D>(
          'whisper_full_get_segment_t0',
        ),
        whisperFullGetSegmentT1 =
            dylib.lookupFunction<_WhisperGetSegT1N, _WhisperGetSegT1D>(
          'whisper_full_get_segment_t1',
        ),
        whisperFullNTokens =
            dylib.lookupFunction<_WhisperFullNTokensN, _WhisperFullNTokensD>(
          'whisper_full_n_tokens',
        ),
        whisperFullGetTokenData =
            dylib.lookupFunction<_WhisperGetTokenDataN, _WhisperGetTokenDataD>(
          'whisper_full_get_token_data',
        ),
        whisperFullGetTokenText =
            dylib.lookupFunction<_WhisperGetTokenTextN, _WhisperGetTokenTextD>(
          'whisper_full_get_token_text',
        );

  static _WhisperLib? tryCreate(ffi.DynamicLibrary dylib) {
    try {
      return _WhisperLib(dylib);
    } catch (_) {
      return null;
    }
  }
}

class SttEngineWhisper {
  Future<SttResult> transcribe(
    String audioPath, {
    required WhisperModelLevel level,
    required String language,
    required bool wordTimestamps,
    required String modelPath,
    String audioFingerprint = '',
  }) {
    return _transcribeCore(
      audioPath: audioPath,
      modelPath: modelPath,
      language: language,
      wordTimestamps: wordTimestamps,
      audioFingerprint: audioFingerprint,
    );
  }

  void dispose() {}

  static Future<SttIsolateResult> runInIsolate(
    SttIsolatePayload payload,
  ) async {
    final sw = Stopwatch()..start();
    try {
      final result = await _transcribeCore(
        audioPath: payload.audioPath,
        modelPath: payload.modelPath,
        language: payload.language,
        wordTimestamps: payload.wordTimestamps,
        audioFingerprint: payload.audioFingerprint,
      );
      sw.stop();
      return SttIsolateResult(
        success: true,
        fullText: result.fullText,
        engineUsed: result.engineUsed.name,
        language: result.language,
        processingTimeMs: sw.elapsedMilliseconds,
        hasWordTimestamps: result.hasWordTimestamps,
        audioFingerprint: result.audioFingerprint,
        segmentsJson: result.segments.map((s) => s.toJson()).toList(),
      );
    } catch (e) {
      return SttIsolateResult.failure('Lỗi: $e');
    }
  }

  static Future<SttResult> _transcribeCore({
    required String audioPath,
    required String modelPath,
    required String language,
    required bool wordTimestamps,
    required String audioFingerprint,
  }) async {
    final sw = Stopwatch()..start();
    final pcmSamples = await _loadAudioAsPcm(audioPath);
    final lib = _loadWhisperLib();
    final ctxPtr = _initWhisperContext(lib, modelPath);

    try {
      final returnCode = _buildAndRunWhisper(
        lib: lib,
        ctx: ctxPtr,
        language: language,
        wordTimestamps: wordTimestamps,
        pcmSamples: Float32List.fromList(pcmSamples),
      );
      if (returnCode != 0)
        throw Exception('whisper_full() thất bại: $returnCode');
      final segments = _parseWhisperSegments(
          lib: lib,
          ctx: ctxPtr,
          fingerprint: audioFingerprint,
          wordTimestamps: wordTimestamps);
      sw.stop();
      return SttResult(
        fullText: segments.map((s) => s.text).join(' ').trim(),
        segments: segments,
        engineUsed: SttEngineType.whisper,
        language: language,
        processingTime: sw.elapsed,
        audioFingerprint: audioFingerprint,
        hasWordTimestamps:
            wordTimestamps && segments.any((s) => s.words.isNotEmpty),
      );
    } finally {
      _freeWhisperContext(lib, ctxPtr);
    }
  }

  static int _buildAndRunWhisper({
    required _WhisperLib lib,
    required ffi.Pointer<WhisperContext> ctx,
    required String language,
    required bool wordTimestamps,
    required Float32List pcmSamples,
  }) {
    final paramsPtr = calloc<WhisperFullParams>();
    final langPinner = _LanguagePinner();
    try {
      final defaults = lib.whisperFullDefaultParams(0);
      // Copy TOÀN BỘ struct từ defaults (gồm cả các trường mới: callbacks,
      // grammar, VAD...) để layout ABI khớp 100% với C struct.
      paramsPtr.ref = defaults;

      paramsPtr.ref
        ..translate = false
        ..no_context = true
        ..no_timestamps = false
        ..single_segment = false
        ..token_timestamps = wordTimestamps;

      final langCode = language.split('-').first.toLowerCase();
      paramsPtr.ref.language = langPinner.pin(langCode);

      final nSamples = pcmSamples.length;
      final samplesPtr = calloc<ffi.Float>(nSamples);
      try {
        samplesPtr.asTypedList(nSamples).setAll(0, pcmSamples);
        return lib.whisperFull(ctx, paramsPtr.ref, samplesPtr, nSamples);
      } finally {
        calloc.free(samplesPtr);
      }
    } finally {
      calloc.free(paramsPtr);
      langPinner.dispose();
    }
  }

  static _WhisperLib _loadWhisperLib() {
    final dylib = Platform.isWindows
        ? ffi.DynamicLibrary.open('whisper.dll')
        : ffi.DynamicLibrary.open('libwhisper.so');
    try {
      return _WhisperLib(dylib);
    } on ArgumentError catch (e) {
      throw StateError(
        'Thư viện Whisper thiếu hàm cần thiết. Hãy đảm bảo whisper.dll '
        '(whisper.cpp mới nhất) nằm cạnh file .exe.\nChi tiết: $e',
      );
    }
  }

  static ffi.Pointer<WhisperContext> _initWhisperContext(
      _WhisperLib lib, String modelPath) {
    final modelPathC = modelPath.toNativeUtf8(allocator: calloc);
    try {
      final pathC = modelPathC.cast<ffi.Char>();

      // Ưu tiên API mới: whisper_init_from_file_with_params. Đây là entry
      // point chính thức trong whisper.h — tránh lỗi "undefined symbol:
      // whisper_init_from_file" khi build mới đã bỏ deprecated symbol.
      if (lib.whisperContextDefaultParams != null &&
          lib.whisperInitFromFileWithParams != null) {
        final cparams = lib.whisperContextDefaultParams!();
        return lib.whisperInitFromFileWithParams!(pathC, cparams);
      }

      // Fallback: API deprecated cho DLL cũ.
      if (lib.whisperInitFromFile != null) {
        return lib.whisperInitFromFile!(pathC);
      }

      throw StateError(
        'Whisper library không export được symbol khởi tạo model nào '
        '(cả whisper_init_from_file_with_params lẫn whisper_init_from_file). '
        'Hãy cập nhật whisper.dll.',
      );
    } finally {
      calloc.free(modelPathC);
    }
  }

  static void _freeWhisperContext(
          _WhisperLib lib, ffi.Pointer<WhisperContext> ctx) =>
      lib.whisperFree(ctx);

  static List<SttSegment> _parseWhisperSegments({
    required _WhisperLib lib,
    required ffi.Pointer<WhisperContext> ctx,
    required String fingerprint,
    required bool wordTimestamps,
  }) {
    final nSegments = lib.whisperFullNSegments(ctx);
    final segments = <SttSegment>[];
    for (var i = 0; i < nSegments; i++) {
      final textPtr = lib.whisperFullGetSegmentText(ctx, i);
      if (textPtr == ffi.nullptr) continue;
      final rawText = textPtr.cast<Utf8>().toDartString().trim();
      segments.add(SttSegment(
          id: i,
          uid: '',
          startSeconds: 0,
          endSeconds: 0,
          text: rawText,
          words: [],
          avgConfidence: 0.9));
    }
    return segments;
  }
}

// Dummy/Mock implementations needed to compile for this snippet
Future<List<double>> _loadAudioAsPcm(String path) async => [];
List<SttWord> _parseWordTokens(
        {required _WhisperLib lib,
        required ffi.Pointer<WhisperContext> ctx,
        required int segmentIndex}) =>
    [];
String _quickFingerprint(String path) => '';
Future<String> _writeLrcFile(
        {required SttResult result,
        required String audioPath,
        required String outputDirectory}) async =>
    '';
SttIsolateResult? _validatePaths(SttIsolatePayload p) => null;
