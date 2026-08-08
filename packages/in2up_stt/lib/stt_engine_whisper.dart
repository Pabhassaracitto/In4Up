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
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:path/path.dart' as path;
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

import 'models/content_id.dart';
import 'models/stt_isolate_payload.dart';
import 'models/stt_model_info.dart';
import 'models/stt_result.dart';
import 'utils/audio_converter.dart';

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
  // Tất cả field đều nullable vì một file .dll bất kỳ có thể KHÔNG export
  // các symbol whisper_* (vd: build thiếu -DWHISPER_SHARED). Loader sẽ kiểm
  // tra các hàm cốt lõi và ném lỗi có chẩn đoán rõ ràng thay vì crash ngầm.
  final _WhisperContextDefaultParamsD? whisperContextDefaultParams;
  final _WhisperInitFromFileWithParamsD? whisperInitFromFileWithParams;
  final _WhisperInitFromFileD? whisperInitFromFile;

  final _WhisperFreeD? whisperFree;
  final _WhisperFullDefaultParamsD? whisperFullDefaultParams;
  final _WhisperFullD? whisperFull;
  final _WhisperFullNSegsD? whisperFullNSegments;
  final _WhisperGetSegTextD? whisperFullGetSegmentText;
  final _WhisperGetSegT0D? whisperFullGetSegmentT0;
  final _WhisperGetSegT1D? whisperFullGetSegmentT1;
  final _WhisperFullNTokensD? whisperFullNTokens;
  final _WhisperGetTokenDataD? whisperFullGetTokenData;
  final _WhisperGetTokenTextD? whisperFullGetTokenText;

  /// Lookup một symbol nhưng KHÔNG ném lỗi nếu thiếu → trả về null.
  /// Dùng try/catch quanh [ffi.DynamicLibrary.lookupFunction] (giống cách
  /// [ffi.DynamicLibrary.open] có thể ném lỗi khi symbol không tồn tại).
  static T? _safe<T>(T Function() block) {
    try {
      return block();
    } catch (_) {
      return null;
    }
  }

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

  static _WhisperFreeD? _lookupFree(ffi.DynamicLibrary dylib) =>
      _safe(() => dylib.lookupFunction<_WhisperFreeN, _WhisperFreeD>(
          'whisper_free'));

  static _WhisperFullDefaultParamsD? _lookupFullDefaultParams(
          ffi.DynamicLibrary dylib) =>
      _safe(() => dylib.lookupFunction<_WhisperFullDefaultParamsN,
          _WhisperFullDefaultParamsD>('whisper_full_default_params'));

  static _WhisperFullD? _lookupFull(ffi.DynamicLibrary dylib) =>
      _safe(() => dylib.lookupFunction<_WhisperFullN, _WhisperFullD>(
          'whisper_full'));

  static _WhisperFullNSegsD? _lookupFullNSegments(ffi.DynamicLibrary dylib) =>
      _safe(() => dylib.lookupFunction<_WhisperFullNSegsN, _WhisperFullNSegsD>(
          'whisper_full_n_segments'));

  static _WhisperGetSegTextD? _lookupGetSegText(ffi.DynamicLibrary dylib) =>
      _safe(() => dylib.lookupFunction<_WhisperGetSegTextN, _WhisperGetSegTextD>(
          'whisper_full_get_segment_text'));

  static _WhisperGetSegT0D? _lookupGetSegT0(ffi.DynamicLibrary dylib) =>
      _safe(() => dylib.lookupFunction<_WhisperGetSegT0N, _WhisperGetSegT0D>(
          'whisper_full_get_segment_t0'));

  static _WhisperGetSegT1D? _lookupGetSegT1(ffi.DynamicLibrary dylib) =>
      _safe(() => dylib.lookupFunction<_WhisperGetSegT1N, _WhisperGetSegT1D>(
          'whisper_full_get_segment_t1'));

  static _WhisperFullNTokensD? _lookupFullNTokens(ffi.DynamicLibrary dylib) =>
      _safe(() => dylib.lookupFunction<_WhisperFullNTokensN, _WhisperFullNTokensD>(
          'whisper_full_n_tokens'));

  static _WhisperGetTokenDataD? _lookupGetTokenData(ffi.DynamicLibrary dylib) =>
      _safe(() => dylib.lookupFunction<_WhisperGetTokenDataN, _WhisperGetTokenDataD>(
          'whisper_full_get_token_data'));

  static _WhisperGetTokenTextD? _lookupGetTokenText(ffi.DynamicLibrary dylib) =>
      _safe(() => dylib.lookupFunction<_WhisperGetTokenTextN, _WhisperGetTokenTextD>(
          'whisper_full_get_token_text'));

  _WhisperLib(ffi.DynamicLibrary dylib)
      : whisperContextDefaultParams = _lookupContextDefaultParams(dylib),
        whisperInitFromFileWithParams = _lookupInitFromFileWithParams(dylib),
        whisperInitFromFile = _lookupInitFromFile(dylib),
        whisperFree = _lookupFree(dylib),
        whisperFullDefaultParams = _lookupFullDefaultParams(dylib),
        whisperFull = _lookupFull(dylib),
        whisperFullNSegments = _lookupFullNSegments(dylib),
        whisperFullGetSegmentText = _lookupGetSegText(dylib),
        whisperFullGetSegmentT0 = _lookupGetSegT0(dylib),
        whisperFullGetSegmentT1 = _lookupGetSegT1(dylib),
        whisperFullNTokens = _lookupFullNTokens(dylib),
        whisperFullGetTokenData = _lookupGetTokenData(dylib),
        whisperFullGetTokenText = _lookupGetTokenText(dylib);

  static _WhisperLib? tryCreate(ffi.DynamicLibrary dylib) {
    try {
      return _WhisperLib(dylib);
    } catch (_) {
      return null;
    }
  }
}

class SttEngineWhisper {
  /// Đường chạy Whisper cho Mobile (Android/iOS) qua plugin
  /// [whisper_flutter_new]. Plugin này bundle sẵn native lib cho mobile và
  /// PHẢI chạy trên Main Thread (dùng MethodChannel) — không nằm trong Isolate.
  ///
  /// Đây là "known-good path" đã từng hoạt động trên Android trước refactor
  /// v11 (xem commit gốc trong packages/vipsound_stt). Refactor đã thay nó
  /// bằng FFI-in-isolate chỉ chạy trên desktop, làm Android mất đường
  /// transcription từ file. Path này khôi phục lại cho mobile.
  static bool get isMobilePluginSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  /// Transcribe file trên Mobile (Main Thread) bằng plugin whisper_flutter_new.
  static Future<SttResult> transcribeMobile({
    required String audioPath,
    required String modelDir,
    required WhisperModelLevel level,
    required String language,
    required bool wordTimestamps,
    required String audioFingerprint,
  }) async {
    final sw = Stopwatch()..start();

    // Plugin yêu cầu WAV 16kHz mono.
    final wavPath =
        await AudioConverter.convertToWhisperCompatible(audioPath) ?? audioPath;

    final whisper = Whisper(
      model: _mapToPluginModel(level),
      modelDir: modelDir,
    );

    debugPrint('🎙️ Whisper (mobile plugin) đang transcribe: $wavPath');
    final transcribeResult = await whisper.transcribe(
      transcribeRequest: TranscribeRequest(
        audio: wavPath,
        isTranslate: false,
        isNoTimestamps: false,
        splitOnWord: wordTimestamps,
        diarize: false,
        language: language,
      ),
    );

    if (wavPath != audioPath) {
      await AudioConverter.cleanupConvertedFile(wavPath);
    }

    final result = _parsePluginResult(
      transcribeResult,
      audioFingerprint: audioFingerprint,
      language: language,
      processingTime: sw.elapsed,
    );
    sw.stop();
    return result;
  }

  /// Parse kết quả plugin → SttResult (bất biến, gán UID Content-Anchored).
  static SttResult _parsePluginResult(
    dynamic output, {
    required String audioFingerprint,
    required String language,
    required Duration processingTime,
  }) {
    try {
      if (output == null) {
        return SttResult.empty(SttEngineType.whisper);
      }
      final response = output as WhisperTranscribeResponse;
      final rawSegments = response.segments ?? const [];

      if (rawSegments.isEmpty) {
        return SttResult.empty(SttEngineType.whisper);
      }

      final segments = <SttSegment>[];
      var id = 0;
      for (final seg in rawSegments) {
        final text = (seg.text ?? '').trim();
        if (text.isEmpty) continue;
        if (_isNoise(text)) continue;

        final startMs = seg.fromTs.inMilliseconds;
        final endMs = seg.toTs.inMilliseconds;
        final startSec = startMs / 1000.0;
        final endSec = endMs / 1000.0;

        segments.add(SttSegment(
          id: id++,
          uid: ContentId.segmentUid(
            audioFingerprint: audioFingerprint,
            startMs: startMs,
            text: text,
          ),
          startSeconds: startSec,
          endSeconds: endSec,
          text: text,
          words: const [],
          avgConfidence: 1.0,
        ));
      }

      return SttResult(
        fullText: segments.map((s) => s.text).join(' ').trim(),
        segments: segments,
        engineUsed: SttEngineType.whisper,
        language: language,
        processingTime: processingTime,
        audioFingerprint: audioFingerprint,
        hasWordTimestamps: false,
      );
    } catch (e) {
      debugPrint('❌ Whisper mobile parse error: $e');
      return SttResult.empty(SttEngineType.whisper);
    }
  }

  static bool _isNoise(String text) {
    final upper = text.toUpperCase();
    return upper.contains('[MUSIC]') ||
        upper.contains('[NOISE]') ||
        upper.contains('[LAUGHTER]');
  }

  static WhisperModel _mapToPluginModel(WhisperModelLevel level) {
    switch (level) {
      case WhisperModelLevel.tiny:
        return WhisperModel.tiny;
      case WhisperModelLevel.base:
        return WhisperModel.base;
      case WhisperModelLevel.small:
        return WhisperModel.small;
      case WhisperModelLevel.medium:
        return WhisperModel.medium;
      case WhisperModelLevel.large:
        return WhisperModel.largeV2;
    }
  }

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

    // ── Đường 1: FFI trực tiếp (cần whisper.dll build với WHISPER_SHARED) ──
    final lib = _tryLoadWhisperLib();
    if (lib != null) {
      try {
        final pcmSamples = await _loadAudioAsPcm(audioPath);
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
      } catch (e) {
        debugPrint('⚠️ Whisper FFI thất bại, chuyển sang CLI: $e');
      }
    }

    // ── Đường 2: CLI whisper.exe (whisper.cpp release — có sẵn ggml DLLs) ──
    return _transcribeViaCli(
      audioPath: audioPath,
      modelPath: modelPath,
      language: language,
      wordTimestamps: wordTimestamps,
      audioFingerprint: audioFingerprint,
    );
  }

  /// Chạy whisper.cpp CLI (whisper.exe) qua Process rồi parse kết quả SRT.
  ///
  /// Hoạt động với bộ file release chuẩn của whisper.cpp:
  /// whisper.exe + ggml-base.dll + ggml-cpu.dll + SDL2.dll (+ ffmpeg.exe).
  /// Đây là fallback khi whisper.dll không export C API (không phải bản
  /// WHISPER_SHARED) — lỗi "undefined symbol: whisper_free" thường gặp đó.
  static Future<SttResult> _transcribeViaCli({
    required String audioPath,
    required String modelPath,
    required String language,
    required bool wordTimestamps,
    required String audioFingerprint,
  }) async {
    final cli = _findCliBinary();

    // whisper.cpp CLI yêu cầu file audio 16kHz mono WAV → convert trước.
    final wavPath =
        await AudioConverter.convertToWhisperCompatible(audioPath) ?? audioPath;

    // Đầu ra SRT vào thư mục temp để parse segment + timestamp.
    final outBase = path.join(
      Directory.systemTemp.path,
      'in2up_whisper_${DateTime.now().millisecondsSinceEpoch}',
    );
    final srtPath = '$outBase.srt';

    final langCode = language.split('-').first.toLowerCase();
    final args = <String>[
      '-m',
      modelPath,
      '-f',
      wavPath,
      '-l',
      langCode,
      '-osrt',
      '-of',
      outBase,
    ];

    final result = await Process.run(cli, args);
    if (result.exitCode != 0) {
      throw StateError(
        'whisper.exe thất bại (exit ${result.exitCode}): ${result.stderr}',
      );
    }

    final srtFile = File(srtPath);
    if (!await srtFile.exists()) {
      throw StateError('whisper.exe không tạo file SRT: $srtPath');
    }

    final segments = _parseSrt(await srtFile.readAsString(),
        audioFingerprint: audioFingerprint);
    await srtFile.delete();

    // Dọn file tạm của converter.
    if (wavPath != audioPath) {
      await AudioConverter.cleanupConvertedFile(wavPath);
    }

    return SttResult(
      fullText: segments.map((s) => s.text).join(' ').trim(),
      segments: segments,
      engineUsed: SttEngineType.whisper,
      language: language,
      processingTime: Duration.zero,
      audioFingerprint: audioFingerprint,
      hasWordTimestamps: false,
    );
  }

  /// Tìm whisper.exe: ưu tiên cạnh file thực thi, rồi PATH.
  ///
  /// whisper.cpp release thường đặt whisper.exe + ggml DLLs cạnh nhau trong
  /// thư mục app. Nếu không thấy file, vẫn trả về tên 'whisper.exe' để
  /// [Process.run] tự tìm trong PATH (đúng hành vi command-line).
  static String _findCliBinary() {
    const name = 'whisper.exe';
    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final near = path.join(exeDir, name);
      if (File(near).existsSync()) return near;
    } catch (_) {}

    // Nếu PATH không có, Process.run sẽ ném lỗi rõ ràng "not found".
    return name;
  }

  /// Parse nội dung SRT → List<SttSegment>.
  static List<SttSegment> _parseSrt(
    String srt, {
    required String audioFingerprint,
  }) {
    final segments = <SttSegment>[];
    final blocks = srt.trim().split(RegExp(r'\n\s*\n'));

    var id = 0;
    for (final block in blocks) {
      final lines = block
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lines.length < 2) continue;

      // Dòng [HH:MM:SS,mmm --> HH:MM:SS,mmm]
      final timeMatch = RegExp(
              r'(\d+):(\d{2}):(\d{2}),(\d{3})\s*-->\s*'
              r'(\d+):(\d{2}):(\d{2}),(\d{3})')
          .firstMatch(lines[1]);
      if (timeMatch == null) continue;

      final text = lines.sublist(2).join(' ').trim();
      if (text.isEmpty) continue;

      final startSec = _srtTimeToSeconds(timeMatch, offset: 1);
      final endSec = _srtTimeToSeconds(timeMatch, offset: 5);
      final startMs = (startSec * 1000).round();

      segments.add(SttSegment(
        id: id++,
        uid: ContentId.segmentUid(
          audioFingerprint: audioFingerprint,
          startMs: startMs,
          text: text,
        ),
        startSeconds: startSec,
        endSeconds: endSec,
        text: text,
        words: const [],
        avgConfidence: 1.0,
      ));
    }
    return segments;
  }

  static double _srtTimeToSeconds(RegExpMatch m, {required int offset}) {
    final h = int.parse(m.group(offset)!);
    final mi = int.parse(m.group(offset + 1)!);
    final s = int.parse(m.group(offset + 2)!);
    final ms = int.parse(m.group(offset + 3)!);
    return (h * 3600) + (mi * 60) + s + (ms / 1000.0);
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
      final defaults = lib.whisperFullDefaultParams!(0);
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
        return lib.whisperFull!(ctx, paramsPtr.ref, samplesPtr, nSamples);
      } finally {
        calloc.free(samplesPtr);
      }
    } finally {
      calloc.free(paramsPtr);
      langPinner.dispose();
    }
  }

  /// Cố gắng nạp thư viện Whisper cho FFI. Trả về null nếu không nạp được
  /// hoặc file DLL không export C API (chuyển sang CLI fallback).
  ///
  /// Tên thư viện thực tế phụ thuộc bản build của whisper.cpp:
  ///   - Linux/macOS : libwhisper.so / libwhisper.dylib
  ///   - Windows     : whisper.cpp CMake tạo "libwhisper.dll"
  ///                   (kèm ggml-base.dll, ggml-cpu.dll, SDL2.dll).
  ///                   Một số người đặt tên lại thành "whisper.dll".
  /// Thử nhiều tên để tương thích cả hai trường hợp.
  static _WhisperLib? _tryLoadWhisperLib() {
    final candidates = Platform.isWindows
        ? const <String>['libwhisper.dll', 'whisper.dll']
        : const <String>['libwhisper.so', 'libwhisper.dylib'];

    Object? lastError;
    _WhisperLib? lib;
    String? openedName;
    for (final name in candidates) {
      try {
        final dylib = ffi.DynamicLibrary.open(name);
        lib = _WhisperLib(dylib);
        openedName = name;
        break;
      } catch (e) {
        lastError = e;
      }
    }

    if (lib == null) {
      debugPrint(
        'ℹ️ Whisper FFI không nạp được thư viện (${candidates.join(', ')}): '
        '$lastError → chuyển sang CLI fallback.',
      );
      return null;
    }

    // DLL mở được nhưng thiếu symbol cần thiết (vd: whisper_free) → tức là
    // file .dll được build KHÔNG export C API. Whisper chỉ export các hàm
    // "whisper_*" khi được build với cờ -DWHISPER_SHARED=ON (WHISPER_API =
    // __declspec(dllexport) trong whisper.h). Nếu không, DLL chỉ chứa logic
    // bên trong mà không lộ hàm nào → mọi lookup đều fail "undefined symbol".
    if (lib.whisperFree == null || lib.whisperFull == null) {
      debugPrint(
        'ℹ️ ${openedName ?? 'whisper DLL'} không export C API whisper_* '
        '(undefined symbol: whisper_free/whisper_full) → chuyển sang CLI.',
      );
      return null;
    }

    return lib;
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
      lib.whisperFree!(ctx);

  static List<SttSegment> _parseWhisperSegments({
    required _WhisperLib lib,
    required ffi.Pointer<WhisperContext> ctx,
    required String fingerprint,
    required bool wordTimestamps,
  }) {
    final nSegments = lib.whisperFullNSegments!(ctx);
    final segments = <SttSegment>[];
    for (var i = 0; i < nSegments; i++) {
      final textPtr = lib.whisperFullGetSegmentText!(ctx, i);
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
