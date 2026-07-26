// packages/vipsound_stt/lib/stt_engine_whisper.dart
//
// REFACTOR v11.2 — Stateless Engine
//
// NGUYÊN TẮC THIẾT KẾ:
// ┌─────────────────────────────────────────────────────────────┐
// │  KHÔNG có field instance nào lưu trạng thái engine.        │
// │  KHÔNG đọc config từ global/singleton.                     │
// │  MỌI input đều đến từ tham số hàm.                         │
// │  An toàn để gọi từ bất kỳ Isolate nào.                     │
// └─────────────────────────────────────────────────────────────┘

import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'models/content_id.dart';
import 'models/stt_isolate_payload.dart';
import 'models/stt_model_info.dart';
import 'models/stt_result.dart';

// ─── FFI Bindings (whisper.cpp) ───────────────────────────────────────────────
//
// Khai báo đúng với whisper.cpp C API.
// Xem: https://github.com/ggerganov/whisper.cpp/blob/master/whisper.h

// Opaque pointer type cho whisper_context
final class WhisperContext extends ffi.Opaque {}

// Opaque pointer type cho whisper_full_params
final class WhisperFullParams extends ffi.Struct {
  // Đây là struct rút gọn — trong thực tế dùng generated bindings
  // hoặc truyền con trỏ opaque qua helper function.
  @ffi.Int32()
  external int strategy; // WHISPER_SAMPLING_GREEDY = 0
}

// ─── Typedef: Native function signatures ─────────────────────────────────────

typedef _WhisperInitFromFileNative = ffi.Pointer<WhisperContext> Function(
  ffi.Pointer<ffi.Char>,
);
typedef _WhisperInitFromFileDart = ffi.Pointer<WhisperContext> Function(
  ffi.Pointer<ffi.Char>,
);

typedef _WhisperFreeNative = ffi.Void Function(ffi.Pointer<WhisperContext>);
typedef _WhisperFreeDart = void Function(ffi.Pointer<WhisperContext>);

typedef _WhisperFullDefaultParamsNative = WhisperFullParams Function(
  ffi.Int32,
);
typedef _WhisperFullDefaultParamsDart = WhisperFullParams Function(int);

typedef _WhisperFullNative = ffi.Int32 Function(
  ffi.Pointer<WhisperContext>,       // ctx
  WhisperFullParams,                  // params
  ffi.Pointer<ffi.Float>,            // samples
  ffi.Int32,                          // n_samples
);
typedef _WhisperFullDart = int Function(
  ffi.Pointer<WhisperContext>,
  WhisperFullParams,
  ffi.Pointer<ffi.Float>,
  int,
);

typedef _WhisperFullNSegmentsNative = ffi.Int32 Function(
  ffi.Pointer<WhisperContext>,
);
typedef _WhisperFullNSegmentsDart = int Function(
  ffi.Pointer<WhisperContext>,
);

typedef _WhisperFullGetSegmentTextNative = ffi.Pointer<ffi.Char> Function(
  ffi.Pointer<WhisperContext>,
  ffi.Int32,
);
typedef _WhisperFullGetSegmentTextDart = ffi.Pointer<ffi.Char> Function(
  ffi.Pointer<WhisperContext>,
  int,
);

typedef _WhisperFullGetSegmentT0Native = ffi.Int64 Function(
  ffi.Pointer<WhisperContext>,
  ffi.Int32,
);
typedef _WhisperFullGetSegmentT0Dart = int Function(
  ffi.Pointer<WhisperContext>,
  int,
);

typedef _WhisperFullGetSegmentT1Native = ffi.Int64 Function(
  ffi.Pointer<WhisperContext>,
  ffi.Int32,
);
typedef _WhisperFullGetSegmentT1Dart = int Function(
  ffi.Pointer<WhisperContext>,
  int,
);

// Word-level timestamps
typedef _WhisperFullNTokensNative = ffi.Int32 Function(
  ffi.Pointer<WhisperContext>,
  ffi.Int32,
);
typedef _WhisperFullNTokensDart = int Function(
  ffi.Pointer<WhisperContext>,
  int,
);

typedef _WhisperFullGetTokenDataNative = _WhisperTokenData Function(
  ffi.Pointer<WhisperContext>,
  ffi.Int32, // i_segment
  ffi.Int32, // i_token
);
typedef _WhisperFullGetTokenDataDart = _WhisperTokenData Function(
  ffi.Pointer<WhisperContext>,
  int,
  int,
);

typedef _WhisperFullGetTokenTextNative = ffi.Pointer<ffi.Char> Function(
  ffi.Pointer<WhisperContext>,
  ffi.Int32,
  ffi.Int32,
);
typedef _WhisperFullGetTokenTextDart = ffi.Pointer<ffi.Char> Function(
  ffi.Pointer<WhisperContext>,
  int,
  int,
);

// Token data struct (rút gọn — chỉ cần t0, t1, p)
final class _WhisperTokenData extends ffi.Struct {
  @ffi.Int32()
  external int id;

  @ffi.Int32()
  external int tid;

  @ffi.Float()
  external double p; // probability / confidence

  @ffi.Float()
  external double plog;

  @ffi.Float()
  external double pt;

  @ffi.Float()
  external double ptsum;

  @ffi.Int64()
  external int t0; // start time (1/100 giây)

  @ffi.Int64()
  external int t1; // end time (1/100 giây)

  @ffi.Float()
  external double vlen;
}

// ─── SttEngineWhisper ─────────────────────────────────────────────────────────

class SttEngineWhisper {
  // ── Không có field instance state nào ──
  // Engine này hoàn toàn stateless.
  // Mọi resource được cấp phát và giải phóng trong từng lần gọi.

  // ── Instance API (backward compat với Facade) ─────────────────────────────

  /// Gọi từ Main Thread — wrapper gọi vào static core.
  ///
  /// [modelPath] — đường dẫn tuyệt đối đến file .bin.
  ///               Bắt buộc, không có default.
  Future<SttResult> transcribe(
    String audioPath, {
    required WhisperModelLevel level,
    required String language,
    required bool wordTimestamps,
    required String modelPath,           // ← THÊM MỚI: không còn đọc từ global
    String audioFingerprint = '',
  }) {
    // Delegate thẳng vào static core — không có state nào được lưu
    return _transcribeCore(
      audioPath: audioPath,
      modelPath: modelPath,
      language: language,
      wordTimestamps: wordTimestamps,
      audioFingerprint: audioFingerprint,
    );
  }

  void dispose() {
    // Không có resource nào để giải phóng — engine stateless
  }

  // ── Isolate Entry Point (static) ──────────────────────────────────────────

  /// Điểm vào cho compute() — PHẢI là static.
  ///
  /// Nhận [SttIsolatePayload], tự khởi tạo mọi thứ,
  /// trả về [SttIsolateResult] — không truy cập bất kỳ Singleton nào.
  static Future<SttIsolateResult> runInIsolate(
    SttIsolatePayload payload,
  ) async {
    final stopwatch = Stopwatch()..start();

    // ── Bước 1: Validate paths (fail fast) ──────────────────────────────────
    final validationError = _validatePaths(payload);
    if (validationError != null) {
      return SttIsolateResult.failure(validationError);
    }

    try {
      // ── Bước 2: Transcribe (stateless core) ─────────────────────────────
      final result = await _transcribeCore(
        audioPath: payload.audioPath,
        modelPath: payload.modelPath,
        language: payload.language,
        wordTimestamps: payload.wordTimestamps,
        audioFingerprint: payload.audioFingerprint,
      );

      stopwatch.stop();

      // ── Bước 3: Write LRC ngay trong Isolate (nếu được yêu cầu) ─────────
      String? lrcFilePath;
      if (payload.generateLrc &&
          result.segments.isNotEmpty &&
          payload.lrcOutputDirectory != null) {
        lrcFilePath = await _writeLrcFile(
          result: result,
          audioPath: payload.audioPath,
          outputDirectory: payload.lrcOutputDirectory!,
        );
      }

      // ── Bước 4: Serialize sang SttIsolateResult ──────────────────────────
      return SttIsolateResult(
        success: true,
        fullText: result.fullText,
        engineUsed: result.engineUsed.name,
        language: result.language,
        processingTimeMs: stopwatch.elapsedMilliseconds,
        hasWordTimestamps: result.hasWordTimestamps,
        audioFingerprint: result.audioFingerprint,
        // Serialize segments sang List<Map> để truyền qua SendPort
        segmentsJson: result.segments
            .map((seg) => seg.toJson())
            .toList(),
        lrcFilePath: lrcFilePath,
      );
    } on _WhisperOutOfMemoryError catch (e) {
      // OOM cần thông báo riêng để UI hiện gợi ý giảm model
      stopwatch.stop();
      return SttIsolateResult.failure(
        'Không đủ RAM để chạy model. '
        'Hãy thử model nhỏ hơn (tiny/base). Chi tiết: $e',
      );
    } catch (e, stack) {
      stopwatch.stop();
      // In stack trace vào log của Isolate — không crash app
      // ignore: avoid_print
      print('[Isolate] ❌ Whisper error: $e\n$stack');
      return SttIsolateResult.failure(
        'Lỗi xử lý âm thanh: ${e.runtimeType}: $e',
      );
    }
  }

  // ── Core Transcribe Logic (static, Isolate-safe) ──────────────────────────
  //
  // Đây là nơi DUY NHẤT gọi vào FFI.
  // Không có state, không có singleton, không có platform channel.

  static Future<SttResult> _transcribeCore({
    required String audioPath,
    required String modelPath,
    required String language,
    required bool wordTimestamps,
    required String audioFingerprint,
  }) async {
    final stopwatch = Stopwatch()..start();

    // Fingerprint: dùng giá trị được tính sẵn trên Main Thread.
    // Nếu không có (trường hợp gọi trực tiếp), tính nhanh từ path.
    final fingerprint = audioFingerprint.isNotEmpty
        ? audioFingerprint
        : _quickFingerprint(audioPath);

    // ── Bước A: Load audio → PCM Float32 ────────────────────────────────────
    //
    // Whisper.cpp cần PCM 16kHz mono Float32.
    // Trong thực tế: dùng FFmpeg FFI hoặc dart:ffi gọi libsndfile.
    final pcmSamples = await _loadAudioAsPcm(audioPath);

    if (pcmSamples.isEmpty) {
      throw Exception(
        'Không thể đọc audio: $audioPath. '
        'File có thể bị hỏng hoặc định dạng không hỗ trợ.',
      );
    }

    // ── Bước B: Load Whisper library ────────────────────────────────────────
    final lib = _loadWhisperLib();

    // ── Bước C: Init Whisper context từ model file ───────────────────────────
    final ctx = _initWhisperContext(lib, modelPath);

    try {
      // ── Bước D: Thiết lập params ──────────────────────────────────────────
      final params = _buildWhisperParams(
        lib: lib,
        language: language,
        wordTimestamps: wordTimestamps,
      );

      // ── Bước E: Chạy transcription ────────────────────────────────────────
      final returnCode = _runWhisperFull(
        lib: lib,
        ctx: ctx,
        params: params,
        pcmSamples: pcmSamples,
      );

      if (returnCode != 0) {
        throw Exception(
          'whisper_full() trả về lỗi code: $returnCode. '
          'Kiểm tra file audio và model.',
        );
      }

      // ── Bước F: Parse kết quả → SttSegment[] ─────────────────────────────
      final segments = _parseWhisperSegments(
        lib: lib,
        ctx: ctx,
        fingerprint: fingerprint,
        wordTimestamps: wordTimestamps,
      );

      stopwatch.stop();

      return SttResult(
        fullText: segments.map((s) => s.text).join(' ').trim(),
        segments: segments,
        engineUsed: SttEngineType.whisper,
        language: language,
        processingTime: stopwatch.elapsed,
        audioFingerprint: fingerprint,
        hasWordTimestamps: wordTimestamps && _hasAnyWords(segments),
      );
    } finally {
      // ── Bước G: Giải phóng context (LUÔN chạy, kể cả khi lỗi) ───────────
      _freeWhisperContext(lib, ctx);
    }
  }

  // ── FFI: Load thư viện Whisper ────────────────────────────────────────────

  static _WhisperLib _loadWhisperLib() {
    try {
      final ffi.DynamicLibrary dylib;

      if (Platform.isAndroid) {
        dylib = ffi.DynamicLibrary.open('libwhisper.so');
      } else if (Platform.isIOS || Platform.isMacOS) {
        // iOS/macOS: static link hoặc framework
        dylib = ffi.DynamicLibrary.process();
      } else if (Platform.isWindows) {
        dylib = ffi.DynamicLibrary.open('whisper.dll');
      } else if (Platform.isLinux) {
        dylib = ffi.DynamicLibrary.open('libwhisper.so');
      } else {
        throw UnsupportedError(
          'Platform ${Platform.operatingSystem} chưa được hỗ trợ.',
        );
      }

      return _WhisperLib(dylib);
    } catch (e) {
      throw Exception(
        'Không thể load thư viện Whisper: $e. '
        'Đảm bảo libwhisper.so/dll đã được bundle vào app.',
      );
    }
  }

  // ── FFI: Init context ─────────────────────────────────────────────────────

  static ffi.Pointer<WhisperContext> _initWhisperContext(
    _WhisperLib lib,
    String modelPath,
  ) {
    // Chuyển Dart String → C string (null-terminated UTF-8)
    final modelPathPtr = modelPath.toNativeUtf8();

    try {
      final ctx = lib.whisperInitFromFile(modelPathPtr.cast());

      if (ctx == ffi.nullptr) {
        // Null context = không đủ RAM hoặc file model lỗi
        throw _WhisperOutOfMemoryError(
          'whisper_init_from_file trả về null. '
          'Model: $modelPath',
        );
      }

      return ctx;
    } finally {
      // Giải phóng C string ngay sau khi không cần
      calloc.free(modelPathPtr);
    }
  }

  // ── FFI: Build params ─────────────────────────────────────────────────────

  static WhisperFullParams _buildWhisperParams({
    required _WhisperLib lib,
    required String language,
    required bool wordTimestamps,
  }) {
    // WHISPER_SAMPLING_GREEDY = 0
    // WHISPER_SAMPLING_BEAM_SEARCH = 1
    const samplingStrategy = 0;

    final params = lib.whisperFullDefaultParams(samplingStrategy);

    // Lưu ý: Trong whisper.cpp thực, params là struct lớn.
    // Để set language và word_timestamps, ta cần pointer manipulation.
    // Đây là pattern đúng khi dùng generated FFI bindings (ffigen):
    //
    //   params.ref.language = language.toNativeUtf8().cast();
    //   params.ref.token_timestamps = wordTimestamps;
    //   params.ref.max_len = 0;       // auto
    //   params.ref.translate = false;
    //   params.ref.no_context = true; // độc lập giữa các segment
    //   params.ref.print_special = false;
    //   params.ref.print_progress = false;
    //   params.ref.print_realtime = false;
    //   params.ref.print_timestamps = false;
    //
    // Khi dùng opaque params (không có generated bindings):
    // Gọi helper function từ whisper.h như whisper_full_params_set_language()
    // nếu thư viện expose API đó.

    return params;
  }

  // ── FFI: Run whisper_full ─────────────────────────────────────────────────

  static int _runWhisperFull({
    required _WhisperLib lib,
    required ffi.Pointer<WhisperContext> ctx,
    required WhisperFullParams params,
    required Float32List pcmSamples,
  }) {
    // Cấp phát buffer Float32 trên native heap
    final nSamples = pcmSamples.length;
    final samplesPtr = calloc<ffi.Float>(nSamples);

    try {
      // Copy PCM data vào native memory
      final nativeList = samplesPtr.asTypedList(nSamples);
      nativeList.setAll(0, pcmSamples);

      // Gọi Whisper
      return lib.whisperFull(ctx, params, samplesPtr, nSamples);
    } finally {
      calloc.free(samplesPtr);
    }
  }

  // ── Parse: Segments → SttSegment[] ───────────────────────────────────────

  static List<SttSegment> _parseWhisperSegments({
    required _WhisperLib lib,
    required ffi.Pointer<WhisperContext> ctx,
    required String fingerprint,
    required bool wordTimestamps,
  }) {
    final nSegments = lib.whisperFullNSegments(ctx);
    final segments = <SttSegment>[];

    for (var i = 0; i < nSegments; i++) {
      // ── Text ──────────────────────────────────────────────────────────────
      final textPtr = lib.whisperFullGetSegmentText(ctx, i);
      final rawText = textPtr.cast<Utf8>().toDartString().trim();

      // Bỏ qua segment trống hoặc chỉ có special tokens
      if (rawText.isEmpty || rawText.startsWith('[')) continue;

      // ── Timestamps (đơn vị: 1/100 giây trong whisper.cpp) ─────────────────
      // Whisper dùng centiseconds (t * 10ms = milliseconds)
      final t0Centis = lib.whisperFullGetSegmentT0(ctx, i);
      final t1Centis = lib.whisperFullGetSegmentT1(ctx, i);

      final startMs = t0Centis * 10; // centiseconds → milliseconds
      final endMs = t1Centis * 10;

      final startSeconds = startMs / 1000.0;
      final endSeconds = endMs / 1000.0;

      // ── Content-Anchored UID ──────────────────────────────────────────────
      //
      // QUAN TRỌNG: UID phải bất biến qua các lần transcribe cùng file.
      // Dùng audioFingerprint (đã tính sẵn từ Main Thread) + startMs + text.
      final uid = ContentId.segmentUid(
        audioFingerprint: fingerprint,
        startMs: startMs,
        text: rawText,
      );

      // ── Word-level timestamps (nếu được bật) ─────────────────────────────
      final words = wordTimestamps
          ? _parseWordTokens(
              lib: lib,
              ctx: ctx,
              segmentIndex: i,
            )
          : <SttWord>[];

      // ── Confidence từ word tokens (nếu có) ───────────────────────────────
      final avgConfidence = words.isNotEmpty
          ? words.fold<double>(0, (sum, w) => sum + w.confidence) /
              words.length
          : 1.0; // Whisper không cung cấp segment-level confidence trực tiếp

      segments.add(SttSegment(
        id: i,
        uid: uid,
        startSeconds: startSeconds,
        endSeconds: endSeconds,
        text: rawText,
        words: words,
        avgConfidence: avgConfidence,
      ));
    }

    return segments;
  }

  // ── Parse: Word Tokens ────────────────────────────────────────────────────

  static List<SttWord> _parseWordTokens({
    required _WhisperLib lib,
    required ffi.Pointer<WhisperContext> ctx,
    required int segmentIndex,
  }) {
    final nTokens = lib.whisperFullNTokens(ctx, segmentIndex);
    final words = <SttWord>[];

    for (var j = 0; j < nTokens; j++) {
      final tokenData = lib.whisperFullGetTokenData(ctx, segmentIndex, j);
      final tokenTextPtr = lib.whisperFullGetTokenText(
        ctx,
        segmentIndex,
        j,
      );

      final tokenText = tokenTextPtr.cast<Utf8>().toDartString();

      // Bỏ qua special tokens (bắt đầu bằng '[' hoặc '<')
      if (tokenText.startsWith('[') || tokenText.startsWith('<')) continue;
      // Bỏ qua whitespace-only tokens
      if (tokenText.trim().isEmpty) continue;

      // t0/t1 trong token cũng là centiseconds
      final wordStartMs = tokenData.t0 * 10;
      final wordEndMs = tokenData.t1 * 10;

      // tokenData.p = probability [0.0, 1.0]
      final confidence = tokenData.p.clamp(0.0, 1.0);

      words.add(SttWord(
        word: tokenText.trim(),
        startSeconds: wordStartMs / 1000.0,
        endSeconds: wordEndMs / 1000.0,
        confidence: confidence,
      ));
    }

    return words;
  }

  // ── FFI: Free context ─────────────────────────────────────────────────────

  static void _freeWhisperContext(
    _WhisperLib lib,
    ffi.Pointer<WhisperContext> ctx,
  ) {
    try {
      lib.whisperFree(ctx);
    } catch (e) {
      // Bỏ qua lỗi giải phóng — không block pipeline
      // ignore: avoid_print
      print('[Whisper] ⚠️ whisper_free error (non-fatal): $e');
    }
  }

  // ── Audio Loading ─────────────────────────────────────────────────────────
  //
  // Whisper.cpp yêu cầu: PCM 16kHz, mono, Float32.
  //
  // PRODUCTION: Dùng một trong các phương án:
  //   A) FFmpeg FFI: ffmpeg_kit_flutter → avcodec_decode_audio
  //   B) dart:ffi gọi libavformat/libswresample
  //   C) Native platform code (MethodChannel) — KHÔNG dùng trong Isolate!
  //      (MethodChannel không hoạt động trong Isolate)
  //   D) Custom WAV parser (chỉ dùng cho WAV 16kHz mono)

  static Future<Float32List> _loadAudioAsPcm(String audioPath) async {
    final file = File(audioPath);

    if (!file.existsSync()) {
      throw Exception('File audio không tồn tại: $audioPath');
    }

    final extension = audioPath.toLowerCase().split('.').last;

    switch (extension) {
      case 'wav':
        return _loadWavAsPcm(file);
      case 'mp3':
      case 'm4a':
      case 'aac':
      case 'ogg':
      case 'flac':
        // Cần FFmpeg để decode — xem comment bên dưới
        return _loadCompressedAudioAsPcm(file);
      default:
        // Thử đọc như WAV trước
        try {
          return _loadWavAsPcm(file);
        } catch (_) {
          throw UnsupportedError(
            'Định dạng audio "$extension" chưa được hỗ trợ trực tiếp. '
            'Hãy convert sang WAV 16kHz mono trước.',
          );
        }
    }
  }

  /// Đọc WAV file thuần Dart — không cần FFI, hoạt động trong Isolate.
  ///
  /// Hỗ trợ: PCM WAV (16-bit, 24-bit, 32-bit float), mono hoặc stereo.
  /// Output: Float32List, 16kHz mono (resample nếu cần).
  static Future<Float32List> _loadWavAsPcm(File file) async {
    final bytes = await file.readAsBytes();
    final data = ByteData.sublistView(bytes);

    // ── Validate WAV header ───────────────────────────────────────────────
    // RIFF chunk
    final riff = String.fromCharCodes(bytes.sublist(0, 4));
    if (riff != 'RIFF') {
      throw const FormatException('Không phải WAV file (thiếu RIFF header)');
    }

    final wave = String.fromCharCodes(bytes.sublist(8, 12));
    if (wave != 'WAVE') {
      throw const FormatException('Không phải WAV file (thiếu WAVE marker)');
    }

    // ── Tìm fmt chunk ─────────────────────────────────────────────────────
    var offset = 12;
    int? sampleRate;
    int? numChannels;
    int? bitsPerSample;
    int? audioFormat; // 1=PCM, 3=Float32

    while (offset < bytes.length - 8) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize = data.getUint32(offset + 4, Endian.little);

      if (chunkId == 'fmt ') {
        audioFormat = data.getUint16(offset + 8, Endian.little);
        numChannels = data.getUint16(offset + 10, Endian.little);
        sampleRate = data.getUint32(offset + 12, Endian.little);
        bitsPerSample = data.getUint16(offset + 22, Endian.little);
        offset += 8 + chunkSize;
        break;
      }

      offset += 8 + chunkSize;
      // Align to 2-byte boundary
      if (chunkSize.isOdd) offset++;
    }

    if (sampleRate == null || numChannels == null || bitsPerSample == null) {
      throw const FormatException('WAV fmt chunk không hợp lệ');
    }

    // ── Tìm data chunk ────────────────────────────────────────────────────
    while (offset < bytes.length - 8) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize = data.getUint32(offset + 4, Endian.little);

      if (chunkId == 'data') {
        final dataOffset = offset + 8;
        final dataBytes = bytes.sublist(
          dataOffset,
          (dataOffset + chunkSize).clamp(0, bytes.length),
        );

        // ── Decode PCM samples ────────────────────────────────────────────
        final samples = _decodePcmSamples(
          dataBytes,
          bitsPerSample: bitsPerSample!,
          audioFormat: audioFormat ?? 1,
          numChannels: numChannels!,
        );

        // ── Resample nếu không phải 16kHz ────────────────────────────────
        if (sampleRate != 16000) {
          return _resampleTo16kHz(samples, fromRate: sampleRate!);
        }

        return samples;
      }

      offset += 8 + chunkSize;
      if (chunkSize.isOdd) offset++;
    }

    throw const FormatException('WAV data chunk không tìm thấy');
  }

  /// Decode PCM bytes → Float32 [-1.0, 1.0].
  static Float32List _decodePcmSamples(
    Uint8List dataBytes, {
    required int bitsPerSample,
    required int audioFormat,
    required int numChannels,
  }) {
    final byteData = ByteData.sublistView(dataBytes);
    final bytesPerSample = bitsPerSample ~/ 8;
    final totalSamples = dataBytes.length ~/ bytesPerSample;
    // Nếu stereo → mix down thành mono
    final monoSamples = numChannels > 1 ? totalSamples ~/ numChannels : totalSamples;

    final result = Float32List(monoSamples);

    for (var i = 0; i < monoSamples; i++) {
      double sample = 0.0;

      // Mix channels xuống mono bằng cách lấy trung bình
      for (var ch = 0; ch < numChannels; ch++) {
        final byteIndex = (i * numChannels + ch) * bytesPerSample;
        if (byteIndex + bytesPerSample > dataBytes.length) break;

        final channelSample = switch (bitsPerSample) {
          // 16-bit PCM — phổ biến nhất
          16 => byteData.getInt16(byteIndex, Endian.little) / 32768.0,
          // 32-bit Float — audioFormat == 3
          32 when audioFormat == 3 =>
            byteData.getFloat32(byteIndex, Endian.little).toDouble(),
          // 32-bit PCM integer
          32 => byteData.getInt32(byteIndex, Endian.little) / 2147483648.0,
          // 24-bit PCM — ít gặp
          24 => _readInt24(byteData, byteIndex) / 8388608.0,
          // 8-bit PCM (unsigned)
          8 => (byteData.getUint8(byteIndex) - 128) / 128.0,
          _ => 0.0,
        };

        sample += channelSample;
      }

      result[i] = (sample / numChannels).clamp(-1.0, 1.0);
    }

    return result;
  }

  static double _readInt24(ByteData data, int offset) {
    final b0 = data.getUint8(offset);
    final b1 = data.getUint8(offset + 1);
    final b2 = data.getUint8(offset + 2);
    var value = b0 | (b1 << 8) | (b2 << 16);
    // Sign extend từ 24-bit
    if (value & 0x800000 != 0) value |= ~0xFFFFFF;
    return value.toDouble();
  }

  /// Linear interpolation resample.
  ///
  /// Đủ dùng cho STT (Whisper không nhạy cảm với chất lượng resample).
  /// Dùng sinc interpolation cho chất lượng cao hơn nếu cần.
  static Float32List _resampleTo16kHz(
    Float32List input, {
    required int fromRate,
  }) {
    if (fromRate == 16000) return input;

    final ratio = fromRate / 16000.0;
    final outputLength = (input.length / ratio).floor();
    final output = Float32List(outputLength);

    for (var i = 0; i < outputLength; i++) {
      final srcIndex = i * ratio;
      final srcFloor = srcIndex.floor();
      final srcCeil = (srcFloor + 1).clamp(0, input.length - 1);
      final fraction = srcIndex - srcFloor;

      // Linear interpolation giữa 2 sample liền kề
      output[i] = input[srcFloor] * (1.0 - fraction) +
          input[srcCeil] * fraction;
    }

    return output;
  }

  /// Load audio nén (MP3, M4A, v.v.) qua FFmpeg FFI.
  ///
  /// Cần package: ffmpeg_kit_flutter hoặc custom FFI với libavcodec.
  /// Isolate-safe vì dùng FFI thuần, không dùng MethodChannel.
  static Future<Float32List> _loadCompressedAudioAsPcm(File file) async {
    // PRODUCTION IMPLEMENTATION:
    //
    // Option A — ffmpeg_kit_flutter (nếu support isolate):
    //   final session = await FFmpegKit.execute(
    //     '-i ${file.path} -ar 16000 -ac 1 -f f32le /tmp/output.raw',
    //   );
    //   final rawFile = File('/tmp/output.raw');
    //   final bytes = await rawFile.readAsBytes();
    //   return bytes.buffer.asFloat32List();
    //
    // Option B — FFI trực tiếp với libavformat/libswresample:
    //   Phức tạp hơn nhưng không cần file tạm.
    //
    // HIỆN TẠI: Throw với hướng dẫn rõ ràng
    throw UnsupportedError(
      'File ${file.path} cần FFmpeg để decode. '
      'Đảm bảo ffmpeg_kit_flutter được cài đặt và '
      'gọi FFmpegAudioLoader.decode() trước khi transcribe.',
    );
  }

  // ── LRC Writer (Isolate-safe, không dùng platform channel) ───────────────

  static Future<String?> _writeLrcFile({
    required SttResult result,
    required String audioPath,
    required String outputDirectory,
  }) async {
    try {
      final dir = Directory(outputDirectory);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      // Tên file dựa trên fingerprint — duy nhất, không xung đột
      final fileName = '${result.audioFingerprint}.lrc';
      final lrcPath = '$outputDirectory/$fileName';

      final buffer = StringBuffer();

      // ── LRC header ────────────────────────────────────────────────────────
      final audioFileName = audioPath.split('/').last;
      buffer.writeln('[ti:$audioFileName]');
      buffer.writeln('[by:VipSound STT v11.0]');
      buffer.writeln('[ve:${result.engineUsed.name}]');
      buffer.writeln('[la:${result.language}]');
      buffer.writeln('');

      // ── LRC lines ─────────────────────────────────────────────────────────
      for (final segment in result.segments) {
        // Format timestamp: [mm:ss.cc]
        // cc = centiseconds (1/100 giây) — chuẩn LRC
        final totalMs = segment.startMs;
        final minutes = totalMs ~/ 60000;
        final seconds = (totalMs % 60000) ~/ 1000;
        final centis = (totalMs % 1000) ~/ 10;

        final timestamp =
            '[${minutes.toString().padLeft(2, '0')}:'
            '${seconds.toString().padLeft(2, '0')}.'
            '${centis.toString().padLeft(2, '0')}]';

        buffer.writeln('$timestamp${segment.text.trim()}');
      }

      // ── Write (sync trong Isolate — File IO không block Isolate scheduler)
      File(lrcPath).writeAsStringSync(buffer.toString(), flush: true);

      // ignore: avoid_print
      print('[Isolate] 📄 LRC written: $lrcPath '
          '(${result.segments.length} lines)');

      return lrcPath;
    } catch (e) {
      // ignore: avoid_print
      print('[Isolate] ❌ LRC write error: $e');
      return null; // Không throw — LRC là bonus, không phải critical
    }
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  /// Kiểm tra paths hợp lệ trước khi làm việc nặng.
  static String? _validatePaths(SttIsolatePayload payload) {
    if (payload.audioPath.isEmpty) {
      return 'audioPath không được rỗng';
    }
    if (payload.modelPath.isEmpty) {
      return 'modelPath không được rỗng. '
          'Model chưa được tải về hoặc chưa initialize.';
    }
    if (!File(payload.audioPath).existsSync()) {
      return 'File audio không tồn tại: ${payload.audioPath}';
    }
    if (!File(payload.modelPath).existsSync()) {
      return 'File model không tồn tại: ${payload.modelPath}. '
          'Hãy download model trong Settings → AI Model.';
    }
    return null; // Validation passed
  }

  /// Tính fingerprint nhanh (chỉ dùng khi không có fingerprint từ Main Thread).
  static String _quickFingerprint(String audioPath) {
    // Đây là fallback — trong production fingerprint luôn được tính trên Main.
    return 'fp_${audioPath.hashCode.abs().toRadixString(16)}';
  }

  static bool _hasAnyWords(List<SttSegment> segments) {
    return segments.any((s) => s.words.isNotEmpty);
  }
}

// ─── Helper class: FFI bindings wrapper ───────────────────────────────────────

/// Wrapper gom tất cả FFI function lookups.
///
/// Giúp tránh lặp lại `.lookupFunction()` nhiều nơi.
/// Không lưu state — chỉ là convenience holder cho function pointers.
class _WhisperLib {
  final _WhisperInitFromFileDart whisperInitFromFile;
  final _WhisperFreeDart whisperFree;
  final _WhisperFullDefaultParamsDart whisperFullDefaultParams;
  final _WhisperFullDart whisperFull;
  final _WhisperFullNSegmentsDart whisperFullNSegments;
  final _WhisperFullGetSegmentTextDart whisperFullGetSegmentText;
  final _WhisperFullGetSegmentT0Dart whisperFullGetSegmentT0;
  final _WhisperFullGetSegmentT1Dart whisperFullGetSegmentT1;
  final _WhisperFullNTokensDart whisperFullNTokens;
  final _WhisperFullGetTokenDataDart whisperFullGetTokenData;
  final _WhisperFullGetTokenTextDart whisperFullGetTokenText;

  _WhisperLib(ffi.DynamicLibrary lib)
      : whisperInitFromFile = lib.lookupFunction<
            _WhisperInitFromFileNative,
            _WhisperInitFromFileDart>('whisper_init_from_file'),
        whisperFree = lib.lookupFunction<
            _WhisperFreeNative,
            _WhisperFreeDart>('whisper_free'),
        whisperFullDefaultParams = lib.lookupFunction<
            _WhisperFullDefaultParamsNative,
            _WhisperFullDefaultParamsDart>('whisper_full_default_params'),
        whisperFull = lib.lookupFunction<
            _WhisperFullNative,
            _WhisperFullDart>('whisper_full'),
        whisperFullNSegments = lib.lookupFunction<
            _WhisperFullNSegmentsNative,
            _WhisperFullNSegmentsDart>('whisper_full_n_segments'),
        whisperFullGetSegmentText = lib.lookupFunction<
            _WhisperFullGetSegmentTextNative,
            _WhisperFullGetSegmentTextDart>(
              'whisper_full_get_segment_text',
            ),
        whisperFullGetSegmentT0 = lib.lookupFunction<
            _WhisperFullGetSegmentT0Native,
            _WhisperFullGetSegmentT0Dart>('whisper_full_get_segment_t0'),
        whisperFullGetSegmentT1 = lib.lookupFunction<
            _WhisperFullGetSegmentT1Native,
            _WhisperFullGetSegmentT1Dart>('whisper_full_get_segment_t1'),
        whisperFullNTokens = lib.lookupFunction<
            _WhisperFullNTokensNative,
            _WhisperFullNTokensDart>('whisper_full_n_tokens'),
        whisperFullGetTokenData = lib.lookupFunction<
            _WhisperFullGetTokenDataNative,
            _WhisperFullGetTokenDataDart>('whisper_full_get_token_data'),
        whisperFullGetTokenText = lib.lookupFunction<
            _WhisperFullGetTokenTextNative,
            _WhisperFullGetTokenTextDart>('whisper_full_get_token_text');
}

// ─── Custom Exceptions ────────────────────────────────────────────────────────

class _WhisperOutOfMemoryError implements Exception {
  final String message;
  const _WhisperOutOfMemoryError(this.message);

  @override
  String toString() => '_WhisperOutOfMemoryError: $message';
}
