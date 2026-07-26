// packages/vipsound_stt/lib/stt_engine_whisper.dart
//
// VipSound v11.0 — Stateless Whisper Engine
//

import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'models/stt_isolate_payload.dart';

// ═════════════════════════════════════════════════════════════════════════════
// FFI Definitions
// ═════════════════════════════════════════════════════════════════════════════

final class WhisperContext extends ffi.Opaque {}

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
  external bool speed_up;
  @ffi.Bool()
  external bool debug_mode;
  @ffi.Int32()
  external int audio_ctx;
}

// ═════════════════════════════════════════════════════════════════════════════
// Engine Logic
// ═════════════════════════════════════════════════════════════════════════════

class SttEngineWhisper {
  static Future<SttIsolateResult> runInIsolate(
      SttIsolatePayload payload) async {
    final dylib = Platform.isAndroid
        ? ffi.DynamicLibrary.open('libwhisper.so')
        : ffi.DynamicLibrary.process();

    final whisperInit = dylib.lookupFunction<
        ffi.Pointer<WhisperContext> Function(ffi.Pointer<ffi.Char>),
        ffi.Pointer<WhisperContext> Function(
            ffi.Pointer<ffi.Char>)>('whisper_init_from_file');
    final whisperFree = dylib.lookupFunction<
        ffi.Void Function(ffi.Pointer<WhisperContext>),
        void Function(ffi.Pointer<WhisperContext>)>('whisper_free');
    final whisperDefaultParams = dylib.lookupFunction<
        ffi.Pointer<WhisperFullParams> Function(ffi.Int32),
        ffi.Pointer<WhisperFullParams> Function(
            int)>('whisper_full_default_params');
    final whisperFull = dylib.lookupFunction<
        ffi.Int32 Function(ffi.Pointer<WhisperContext>,
            ffi.Pointer<WhisperFullParams>, ffi.Pointer<ffi.Float>, ffi.Int32),
        int Function(
            ffi.Pointer<WhisperContext>,
            ffi.Pointer<WhisperFullParams>,
            ffi.Pointer<ffi.Float>,
            int)>('whisper_full');
    final whisperNSegments = dylib.lookupFunction<
        ffi.Int32 Function(ffi.Pointer<WhisperContext>),
        int Function(ffi.Pointer<WhisperContext>)>('whisper_full_n_segments');
    final whisperGetText = dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<WhisperContext>, ffi.Int32),
        ffi.Pointer<ffi.Char> Function(
            ffi.Pointer<WhisperContext>, int)>('whisper_full_get_segment_text');
    final whisperGetT0 = dylib.lookupFunction<
        ffi.Int64 Function(ffi.Pointer<WhisperContext>, ffi.Int32),
        int Function(
            ffi.Pointer<WhisperContext>, int)>('whisper_full_get_segment_t0');
    final whisperGetT1 = dylib.lookupFunction<
        ffi.Int64 Function(ffi.Pointer<WhisperContext>, ffi.Int32),
        int Function(
            ffi.Pointer<WhisperContext>, int)>('whisper_full_get_segment_t1');

    final modelPathC = payload.modelPath.toNativeUtf8();
    final ctx = whisperInit(modelPathC.cast<ffi.Char>());
    if (ctx == ffi.nullptr)
      return SttIsolateResult.failure('Failed to init whisper');

    try {
      final pcm = await File(payload.audioPath).readAsBytes();
      final floatPcm = pcm.buffer.asFloat32List();
      final samplesPtr = calloc<ffi.Float>(floatPcm.length);
      samplesPtr.asTypedList(floatPcm.length).setAll(0, floatPcm);

      final params = whisperDefaultParams(0);
      params.ref.token_timestamps = payload.generateLrc;

      final ret = whisperFull(ctx, params, samplesPtr, floatPcm.length);

      final segments = <Map<String, dynamic>>[];
      if (ret == 0) {
        final n = whisperNSegments(ctx);
        for (var i = 0; i < n; i++) {
          segments.add({
            'text': whisperGetText(ctx, i).cast<Utf8>().toDartString(),
            'startMs': whisperGetT0(ctx, i) * 10,
            'endMs': whisperGetT1(ctx, i) * 10,
            'uid': 'seg_${i}_${payload.audioFingerprint}',
          });
        }
      }
      
      calloc.free(samplesPtr);
      return SttIsolateResult(
        success: true,
        fullText: segments.map((s) => s['text']).join(' '),
        engineUsed: 'whisper', // hardcoded for now
        language: payload.language,
        processingTimeMs: 0,
        hasWordTimestamps: false,
        audioFingerprint: payload.audioFingerprint,
        segmentsJson: segments,
      );
    } finally {
      whisperFree(ctx);
      calloc.free(modelPathC);
    }
  }
}
