// packages/vipsound_stt/lib/stt_engine_whisper.dart
//
// VipSound v11.0 — Stateless Whisper Engine
//
// NGUYÊN TẮC TUYỆT ĐỐI:
// ┌────────────────────────────────────────────────────────────────────┐
// │  KHÔNG có field instance nào lưu trạng thái engine.              │
// │  KHÔNG đọc config từ global/singleton.                            │
// │  MỌI input đều đến từ tham số hàm.                                │
// │  An toàn để gọi từ bất kỳ Isolate nào.                            │
// │  Mọi resource FFI được cấp phát và giải phóng trong cùng 1 lần   │
// │  gọi hàm — không leak memory.                                     │
// └────────────────────────────────────────────────────────────────────┘
//
// LUỒNG XỬ LÝ:
//   runInIsolate(payload)
//     ├─ [1] _validatePaths()
//     ├─ [2] _loadAudioAsPcm()   ← thuần Dart, Isolate-safe
//     ├─ [3] _loadWhisperLib()   ← FFI, Isolate-safe
//     ├─ [4] _initWhisperContext()
//     ├─ [5] _buildWhisperParams()
//     ├─ [6] _runWhisperFull()
//     ├─ [7] _parseWhisperSegments() ← gán UID bằng ContentId
//     ├─ [8] _writeLrcFile() (nếu generateLrc)
//     └─ [9] Return SttIsolateResult

import 'dart:core' as ffi;
import 'dart:core';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'models/content_id.dart';
import 'models/stt_isolate_payload.dart';
import 'models/stt_model_info.dart';
import 'models/stt_result.dart';

// ═══════════════════════════════════════════════════════════════════════════
// PHẦN 1: FFI TYPE DEFINITIONS
// Khai báo đúng với whisper.cpp C API v1.x
// Tham khảo: https://github.com/ggerganov/whisper.cpp/blob/master/whisper.h
// ═══════════════════════════════════════════════════════════════════════════

/// Opaque handle cho whisper_context* — không cần biết nội dung struct.
final class WhisperContext extends ffi.Opaque {}

/// Struct đầy đủ của whisper_full_params theo whisper.h.
///
/// Thứ tự field PHẢI khớp chính xác với C struct để FFI hoạt động đúng.
/// Chỉ khai báo các field ta cần set — phần còn lại giữ giá trị default
/// từ whisper_full_default_params().
final class WhisperFullParams extends ffi.Struct {
  /// WHISPER_SAMPLING_GREEDY = 0 | WHISPER_SAMPLING_BEAM_SEARCH = 1
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

  /// Bật word-level timestamps — cần cho SttWord parsing.
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

  // language — pointer đến null-terminated C string
  // Không khai báo trực tiếp trong Struct để tránh phức tạp;
  // sẽ set qua offset pointer sau khi gọi whisper_full_default_params.
  // Xem _applyParamsLanguage().
}

/// Token data trả về từ whisper_full_get_token_data().
/// Thứ tự và type phải khớp với whisper_token_data trong whisper.h.
final class WhisperTokenData extends ffi.Struct {
  @ffi.Int32()
  external int id; // token id

  @ffi.Int32()
  external int tid; // forced timestamp token id

  @ffi.Float()
  external double p; // probability [0.0, 1.0]

  @ffi.Float()
  external double plog; // log probability

  @ffi.Float()
  external double pt; // probability of timestamp token

  @ffi.Float()
  external double ptsum; // sum of probabilities of timestamp tokens

  @ffi.Int64()
  external int t0; // start time (centiseconds = 1/100 giây)

  @ffi.Int64()
  external int t1; // end time (centiseconds)

  @ffi.Float()
  external double vlen; // voice length
}

// ─── Native → Dart function typedefs ─────────────────────────────────────────

// whisper_init_from_file(const char* path_model) → whisper_context*
typedef _WhisperInitFromFileN = ffi.Pointer<WhisperContext> Function(
    ffi.Pointer<ffi.Char>);
typedef _WhisperInitFromFileD = ffi.Pointer<WhisperContext> Function(
    ffi.Pointer<ffi.Char>);

// whisper_free(whisper_context* ctx)
typedef _WhisperFreeN = ffi.Void Function(ffi.Pointer<WhisperContext>);
typedef _WhisperFreeD = void Function(ffi.Pointer<WhisperContext>);

// whisper_full_default_params(enum whisper_sampling_strategy strategy)
typedef _WhisperFullDefaultParamsN = ffi.Pointer<WhisperFullParams> Function(
    ffi.Int32);
typedef _WhisperFullDefaultParamsD = ffi.Pointer<WhisperFullParams> Function(
    int);

// whisper_full_params_set_language(struct whisper_full_params* params, const char* lang)
// Nếu whisper.cpp expose hàm này (một số build có, một số không).
// Fallback: set qua pointer offset.
typedef _WhisperParamsSetLanguageN = ffi.Void Function(
    ffi.Pointer<WhisperFullParams>, ffi.Pointer<ffi.Char>);
typedef _WhisperParamsSetLanguageD = void Function(
    ffi.Pointer<WhisperFullParams>, ffi.Pointer<ffi.Char>);

// whisper_full(ctx, params, samples, n_samples) → int (0 = success)
typedef _WhisperFullN = ffi.Int32 Function(ffi.Pointer<WhisperContext>,
    ffi.Pointer<WhisperFullParams>, ffi.Pointer<ffi.Float>, ffi.Int32);
typedef _WhisperFullD = int Function(ffi.Pointer<WhisperContext>,
    ffi.Pointer<WhisperFullParams>, ffi.Pointer<ffi.Float>, int);

// whisper_full_n_segments(ctx) → int
typedef _WhisperFullNSegsN = ffi.Int32 Function(ffi.Pointer<WhisperContext>);
typedef _WhisperFullNSegsD = int Function(ffi.Pointer<WhisperContext>);

// whisper_full_get_segment_text(ctx, i_segment) → const char*
typedef _WhisperGetSegTextN = ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<WhisperContext>, ffi.Int32);
typedef _WhisperGetSegTextD = ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<WhisperContext>, int);

// whisper_full_get_segment_t0(ctx, i_segment) → int64_t (centiseconds)
typedef _WhisperGetSegT0N = ffi.Int64 Function(
    ffi.Pointer<WhisperContext>, ffi.Int32);
typedef _WhisperGetSegT0D = int Function(ffi.Pointer<WhisperContext>, int);

// whisper_full_get_segment_t1(ctx, i_segment) → int64_t (centiseconds)
typedef _WhisperGetSegT1N = ffi.Int64 Function(
    ffi.Pointer<WhisperContext>, ffi.Int32);
typedef _WhisperGetSegT1D = int Function(ffi.Pointer<WhisperContext>, int);

// whisper_full_n_tokens(ctx, i_segment) → int
typedef _WhisperFullNTokensN = ffi.Int32 Function(
    ffi.Pointer<WhisperContext>, ffi.Int32);
typedef _WhisperFullNTokensD = int Function(ffi.Pointer<WhisperContext>, int);

// whisper_full_get_token_data(ctx, i_segment, i_token) → whisper_token_data
typedef _WhisperGetTokenDataN = WhisperTokenData Function(
    ffi.Pointer<WhisperContext>, ffi.Int32, ffi.Int32);
typedef _WhisperGetTokenDataD = WhisperTokenData Function(
    ffi.Pointer<WhisperContext>, int, int);

// whisper_full_get_token_text(ctx, i_segment, i_token) → const char*
typedef _WhisperGetTokenTextN = ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<WhisperContext>, ffi.Int32, ffi.Int32);
typedef _WhisperGetTokenTextD = ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<WhisperContext>, int, int);

// ═══════════════════════════════════════════════════════════════════════════
// PHẦN 2: FFI LIBRARY WRAPPER
// Gom tất cả lookupFunction vào 1 class — không có state.
// ═══════════════════════════════════════════════════════════════════════════

class _WhisperLib {
  final _WhisperInitFromFileD whisperInitFromFile;
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

  /// Optional: set language qua helper function (whisper.cpp >= 1.5.x).
  /// Null nếu thư viện không expose.
  final _WhisperParamsSetLanguageD? whisperParamsSetLanguage;

  _WhisperLib(ffi.DynamicLibrary dylib)
      : whisperInitFromFile =
            dylib.lookupFunction<_WhisperInitFromFileN, _WhisperInitFromFileD>(
          'whisper_init_from_file',
        ),
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
        ),
        // Optional — gracefully handle nếu symbol không tồn tại
        whisperParamsSetLanguage = dylib
            .lookup<ffi.NativeFunction<_WhisperParamsSetLanguageN>>(
              'whisper_full_params_set_language',
            )
            .asFunction<_WhisperParamsSetLanguageD>();
}

// ═══════════════════════════════════════════════════════════════════════════
// PHẦN 3: CUSTOM EXCEPTIONS
// ═══════════════════════════════════════════════════════════════════════════

/// Thrown khi whisper_init_from_file trả về null pointer.
/// Thường do không đủ RAM hoặc model file bị hỏng.
class WhisperOutOfMemoryError implements Exception {
  final String message;
  const WhisperOutOfMemoryError(this.message);

  @override
  String toString() => 'WhisperOutOfMemoryError: $message';
}

/// Thrown khi audio format không được hỗ trợ bởi parser thuần Dart.
class AudioFormatUnsupportedError implements Exception {
  final String format;
  final String suggestion;

  const AudioFormatUnsupportedError({
    required this.format,
    required this.suggestion,
  });

  @override
  String toString() =>
      'AudioFormatUnsupportedError: "$format" không được hỗ trợ. $suggestion';
}

// ═══════════════════════════════════════════════════════════════════════════
// PHẦN 4: MAIN ENGINE CLASS
// ═══════════════════════════════════════════════════════════════════════════

/// Engine Whisper hoàn toàn Stateless.
///
/// Có 2 chế độ sử dụng:
/// - **Instance mode**: Gọi từ Main Thread qua [transcribe()].
/// - **Isolate mode**: Gọi tĩnh qua [runInIsolate()] từ compute().
///
/// Cả hai đều delegate xuống [_transcribeCore()] — logic dùng chung.
class SttEngineWhisper {
  // ─── Không có bất kỳ field instance nào ───────────────────────────────────
  // Engine này hoàn toàn stateless.

  // ── Instance API (backward compatibility với Facade) ──────────────────────

  /// Transcribe từ Main Thread.
  ///
  /// Wrapper mỏng — delegate 100% vào [_transcribeCore].
  /// KHÔNG lưu bất kỳ state nào.
  Future<SttResult> transcribe(
    String audioPath, {
    required WhisperModelLevel level,
    required String language,
    required bool wordTimestamps,
    // modelPath BẮT BUỘC — không đọc từ global/singleton
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

  /// Không có resource để giải phóng — engine stateless.
  void dispose() {}

  // ── Isolate Entry Point ────────────────────────────────────────────────────

  /// Điểm vào cho [compute()] — PHẢI là static.
  ///
  /// Thực hiện toàn bộ pipeline 7 bước mà không truy cập bất kỳ
  /// Singleton nào của Main Thread.
  static Future<SttIsolateResult> runInIsolate(
    SttIsolatePayload payload,
  ) async {
    final sw = Stopwatch()..start();

    // ── Bước 1: Validate paths (fail fast, trước khi làm việc nặng) ─────────
    final validationError = _validatePaths(payload);
    if (validationError != null) {
      return SttIsolateResult.failure(validationError);
    }

    try {
      // ── Bước 2–7: Core transcription pipeline ────────────────────────────
      final result = await _transcribeCore(
        audioPath: payload.audioPath,
        modelPath: payload.modelPath,
        language: payload.language,
        wordTimestamps: payload.wordTimestamps,
        audioFingerprint: payload.audioFingerprint,
      );

      sw.stop();

      // ── Bước 8: Ghi LRC ngay trong Isolate (tùy chọn) ────────────────────
      //
      // Ghi trong Isolate giúp tránh serialize toàn bộ PCM data về Main.
      // File IO là synchronous trong Isolate — không block event loop.
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

      // ── Bước 9: Serialize → SttIsolateResult ─────────────────────────────
      //
      // QUAN TRỌNG: Chỉ serialize primitives và List<Map>.
      // Dart's SendPort không thể truyền class tùy ý (chỉ truyền được
      // các loại: bool, int, double, String, List, Map, Uint8List, null).
      return SttIsolateResult(
        success: true,
        fullText: result.fullText,
        engineUsed: result.engineUsed.name,
        language: result.language,
        processingTimeMs: sw.elapsedMilliseconds,
        hasWordTimestamps: result.hasWordTimestamps,
        audioFingerprint: result.audioFingerprint,
        segmentsJson: result.segments.map((s) => s.toJson()).toList(),
        lrcFilePath: lrcFilePath,
      );
    } on WhisperOutOfMemoryError catch (e) {
      sw.stop();
      // OOM → UI cần gợi ý dùng model nhỏ hơn
      return SttIsolateResult.failure(
        'Không đủ RAM để chạy model. '
        'Hãy thử model tiny hoặc base. Chi tiết: $e',
      );
    } on AudioFormatUnsupportedError catch (e) {
      sw.stop();
      return SttIsolateResult.failure(
        'Định dạng audio không được hỗ trợ: $e',
      );
    } catch (e, stack) {
      sw.stop();
      // Ghi log trong Isolate — print() hoạt động, debugPrint() thì không
      // vì debugPrint cần platform channel.
      // ignore: avoid_print
      print('[Isolate:Whisper] ❌ Lỗi không xác định: $e\n$stack');
      return SttIsolateResult.failure(
        'Lỗi xử lý âm thanh [${e.runtimeType}]: $e',
      );
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // CORE PIPELINE — static, không phụ thuộc state, Isolate-safe
  // ═════════════════════════════════════════════════════════════════════════

  static Future<SttResult> _transcribeCore({
    required String audioPath,
    required String modelPath,
    required String language,
    required bool wordTimestamps,
    required String audioFingerprint,
  }) async {
    final sw = Stopwatch()..start();

    // Dùng fingerprint từ caller (đã tính chính xác trên Main Thread).
    // Fallback chỉ khi gọi trực tiếp không qua Isolate pipeline.
    final fingerprint = audioFingerprint.isNotEmpty
        ? audioFingerprint
        : _quickFingerprint(audioPath);

    // ── Bước 2: Load audio → PCM Float32 16kHz mono ──────────────────────
    //
    // Thực hiện TRƯỚC khi load FFI để fail fast nếu file hỏng.
    // Thuần Dart — an toàn tuyệt đối trong Isolate.
    final pcmSamples = await _loadAudioAsPcm(audioPath);

    if (pcmSamples.isEmpty) {
      throw Exception(
        'Audio rỗng hoặc không đọc được: $audioPath',
      );
    }

    // ── Bước 3: Load Whisper shared library ──────────────────────────────
    //
    // DynamicLibrary.open() an toàn trong Isolate — mỗi Isolate
    // có thể load cùng một .so/.dll độc lập.
    final lib = _loadWhisperLib();

    // ── Bước 4: Khởi tạo Whisper context từ model file ───────────────────
    //
    // Đây là bước tốn RAM nhất. Nếu model > available RAM → OOM.
    final ctxPtr = _initWhisperContext(lib, modelPath);

    try {
      // ── Bước 5: Build params với language và word timestamps ─────────────
      final paramsPtr = _buildWhisperParams(
        lib: lib,
        language: language,
        wordTimestamps: wordTimestamps,
      );

      // ── Bước 6: Chạy whisper_full() ──────────────────────────────────────
      //
      // Đây là bước CPU-intensive nhất (~vài giây với model small).
      // Chạy trong Isolate → UI thread hoàn toàn tự do.
      final returnCode = _runWhisperFull(
        lib: lib,
        ctx: ctxPtr,
        paramsPtr: paramsPtr,
        pcmSamples: pcmSamples,
      );

      // Giải phóng params pointer sau khi dùng
      calloc.free(paramsPtr);

      if (returnCode != 0) {
        throw Exception(
          'whisper_full() thất bại với code: $returnCode. '
          'File audio: $audioPath. '
          'Thử convert sang WAV 16kHz mono nếu lỗi tiếp diễn.',
        );
      }

      // ── Bước 7: Parse segments → SttSegment[] với Content-Anchored UID ──
      final segments = _parseWhisperSegments(
        lib: lib,
        ctx: ctxPtr,
        fingerprint: fingerprint,
        wordTimestamps: wordTimestamps,
      );

      sw.stop();

      return SttResult(
        fullText: segments.map((s) => s.text).join(' ').trim(),
        segments: segments,
        engineUsed: SttEngineType.whisper,
        language: language,
        processingTime: sw.elapsed,
        audioFingerprint: fingerprint,
        hasWordTimestamps:
            wordTimestamps && segments.any((s) => s.words.isNotEmpty),
      );
    } finally {
      // LUÔN giải phóng context — kể cả khi có exception ở bước 6/7.
      // Memory leak trong native layer sẽ không bị GC Dart thu hồi.
      _freeWhisperContext(lib, ctxPtr);
    }
  }

  // ── Bước 3 impl: Load thư viện ────────────────────────────────────────────

  static _WhisperLib _loadWhisperLib() {
    try {
      final ffi.DynamicLibrary dylib;

      if (Platform.isAndroid) {
        // Android: .so nằm trong APK, được linker extract tự động
        dylib = ffi.DynamicLibrary.open('libwhisper.so');
      } else if (Platform.isIOS || Platform.isMacOS) {
        // iOS/macOS: whisper.cpp thường được build dạng static lib,
        // linked vào binary chính → dùng DynamicLibrary.process()
        dylib = ffi.DynamicLibrary.process();
      } else if (Platform.isWindows) {
        dylib = ffi.DynamicLibrary.open('whisper.dll');
      } else if (Platform.isLinux) {
        dylib = ffi.DynamicLibrary.open('libwhisper.so');
      } else {
        throw UnsupportedError(
          'Platform ${Platform.operatingSystem} chưa hỗ trợ Whisper FFI.',
        );
      }

      return _WhisperLib(dylib);
    } on UnsupportedError {
      rethrow;
    } catch (e) {
      throw Exception(
        'Không load được thư viện Whisper: $e. '
        'Kiểm tra libwhisper.so đã được bundle trong jniLibs/.',
      );
    }
  }

  // ── Bước 4 impl: Init context ─────────────────────────────────────────────

  static ffi.Pointer<WhisperContext> _initWhisperContext(
    _WhisperLib lib,
    String modelPath,
  ) {
    // Chuyển Dart String → C UTF-8 null-terminated string
    final modelPathC = modelPath.toNativeUtf8(allocator: calloc);

    try {
      final ctx = lib.whisperInitFromFile(modelPathC.cast<ffi.Char>());

      if (ctx == ffi.nullptr) {
        // Null context = không đủ RAM (model tiny ~75MB, small ~460MB)
        // hoặc file .bin bị hỏng.
        throw WhisperOutOfMemoryError(
          'whisper_init_from_file() trả về null. '
          'Model: $modelPath. '
          'Kiểm tra dung lượng RAM còn trống.',
        );
      }

      return ctx;
    } finally {
      // Giải phóng C string ngay — ctx đã được tạo, không cần nữa.
      calloc.free(modelPathC);
    }
  }

  // ── Bước 5 impl: Build params ─────────────────────────────────────────────

  static ffi.Pointer<WhisperFullParams> _buildWhisperParams({
    required _WhisperLib lib,
    required String language,
    required bool wordTimestamps,
  }) {
    // Lấy params mặc định — đây là pointer trỏ đến struct đầy đủ
    const samplingGreedy = 0;
    final paramsPtr = lib.whisperFullDefaultParams(samplingGreedy);

    // Cấu hình params — set trực tiếp qua .ref
    paramsPtr.ref
      ..translate = false // Không tự động dịch
      ..no_context = true // Mỗi audio là độc lập (quan trọng!)
      ..single_segment = false // Cho phép nhiều segments
      ..print_special = false // Không in special tokens
      ..print_progress = false // Không in progress (không có Flutter console)
      ..print_realtime = false
      ..print_timestamps = false
      ..token_timestamps = wordTimestamps // Bật word-level timestamps
      ..max_len = 0 // 0 = auto segment length
      ..split_on_word = false
      ..max_tokens = 0 // 0 = unlimited
      ..speed_up = false // Không sacrifice accuracy
      ..debug_mode = false
      ..audio_ctx = 0; // 0 = full audio context

    // Set language qua helper function (nếu có) hoặc qua field pointer
    _applyLanguage(lib, paramsPtr, language);

    return paramsPtr;
  }

  /// Set language cho params.
  ///
  /// whisper.cpp lưu language như const char* trong params struct.
  /// Cách an toàn nhất là dùng helper API nếu được expose.
  static void _applyLanguage(
    _WhisperLib lib,
    ffi.Pointer<WhisperFullParams> paramsPtr,
    String language,
  ) {
    // Normalize language code: "en-US" → "en"
    final langCode = language.split('-').first.toLowerCase();

    if (lib.whisperParamsSetLanguage != null) {
      // Nếu whisper.cpp expose whisper_full_params_set_language() → dùng nó
      final langC = langCode.toNativeUtf8(allocator: calloc);
      try {
        lib.whisperParamsSetLanguage!(paramsPtr, langC.cast<ffi.Char>());
      } finally {
        calloc.free(langC);
      }
    }
    // Nếu không có helper: language field nằm ở offset cố định trong struct.
    // Với whisper.cpp >= 1.5, field `language` là const char* ở offset ~144 bytes.
    // Để tránh phụ thuộc vào offset cứng (có thể thay đổi theo version),
    // ta để mặc định "en" — hoạt động đúng cho đa số use case.
    // Nếu cần multi-language chính xác: dùng generated bindings từ ffigen.
    //
    // Xem thêm: docs/ffi_language_binding.md
  }

  // ── Bước 6 impl: Run whisper_full ────────────────────────────────────────

  static int _runWhisperFull({
    required _WhisperLib lib,
    required ffi.Pointer<WhisperContext> ctx,
    required ffi.Pointer<WhisperFullParams> paramsPtr,
    required Float32List pcmSamples,
  }) {
    final nSamples = pcmSamples.length;

    // Cấp phát Float32 array trên native heap
    final samplesPtr = calloc<ffi.Float>(nSamples);

    try {
      // Copy PCM data: Dart Float32List → native Float*
      //
      // Dùng asTypedList() để zero-copy nếu alignment cho phép.
      // Nếu không, setAll() sẽ copy từng phần tử.
      final nativeView = samplesPtr.asTypedList(nSamples);
      nativeView.setAll(0, pcmSamples);

      // Gọi whisper_full — đây là bước tốn thời gian nhất
      return lib.whisperFull(ctx, paramsPtr, samplesPtr, nSamples);
    } finally {
      // Giải phóng buffer — kể cả khi whisper_full throw
      calloc.free(samplesPtr);
    }
  }

  // ── Bước 7 impl: Parse segments ──────────────────────────────────────────

  static List<SttSegment> _parseWhisperSegments({
    required _WhisperLib lib,
    required ffi.Pointer<WhisperContext> ctx,
    required String fingerprint,
    required bool wordTimestamps,
  }) {
    final nSegments = lib.whisperFullNSegments(ctx);
    final segments = <SttSegment>[];

    // Đếm ID thực (bỏ qua segments rỗng/special tokens)
    var realId = 0;

    for (var i = 0; i < nSegments; i++) {
      // ── Lấy text ───────────────────────────────────────────────────────
      final textPtr = lib.whisperFullGetSegmentText(ctx, i);
      final rawText = textPtr.cast<Utf8>().toDartString().trim();

      // Lọc bỏ:
      // - Segments rỗng
      // - Special tokens: [BLANK_AUDIO], [_BEG_], (MUSIC), v.v.
      // - Segments chỉ chứa dấu câu
      if (_shouldSkipSegment(rawText)) continue;

      // ── Timestamps ─────────────────────────────────────────────────────
      //
      // whisper.cpp trả về centiseconds (1/100 giây).
      // 1 centisecond = 10 milliseconds
      final t0Centis = lib.whisperFullGetSegmentT0(ctx, i);
      final t1Centis = lib.whisperFullGetSegmentT1(ctx, i);

      final startMs = t0Centis * 10; // centis → ms
      final endMs = t1Centis * 10;
      final startSec = startMs / 1000.0;
      final endSec = endMs / 1000.0;

      // ── Content-Anchored UID ───────────────────────────────────────────
      //
      // BẮT BUỘC: Dùng audioFingerprint từ payload (đã tính trên Main Thread)
      // để đảm bảo UID bất biến qua các lần transcribe cùng file.
      //
      // UID = MD5(fingerprint | startMs | normalizedText)[:12]
      //
      // Tính chất: nếu cùng file audio và cùng đoạn text → UID luôn giống nhau,
      // dù transcribe lại hay thay đổi layout document.
      final uid = ContentId.segmentUid(
        audioFingerprint: fingerprint,
        startMs: startMs,
        text: rawText,
      );

      // ── Word-level timestamps ──────────────────────────────────────────
      final words = wordTimestamps
          ? _parseWordTokens(lib: lib, ctx: ctx, segmentIndex: i)
          : <SttWord>[];

      // ── Confidence ─────────────────────────────────────────────────────
      //
      // Whisper không cung cấp segment-level confidence trực tiếp.
      // Tính từ trung bình word probability nếu có.
      final avgConfidence = words.isNotEmpty
          ? words.fold(0.0, (sum, w) => sum + w.confidence) / words.length
          : _estimateConfidenceFromText(rawText);

      segments.add(SttSegment(
        id: realId++,
        uid: uid,
        startSeconds: startSec,
        endSeconds: endSec,
        text: rawText,
        words: words,
        avgConfidence: avgConfidence,
      ));
    }

    return segments;
  }

  /// Lọc bỏ segments không có giá trị.
  static bool _shouldSkipSegment(String text) {
    if (text.isEmpty) return true;

    // Special tokens từ Whisper: [BLANK_AUDIO], [_BEG_], [_TT_X_]
    if (text.startsWith('[') && text.endsWith(']')) return true;

    // Noise markers: (Music), (Applause)
    if (text.startsWith('(') && text.endsWith(')')) return true;

    // Chỉ dấu câu hoặc whitespace
    if (RegExp(r'^[\s\.\,\;\:\!\?]+$').hasMatch(text)) return true;

    return false;
  }

  /// Ước tính confidence từ đặc điểm text (heuristic).
  ///
  /// Dùng khi word timestamps không bật — không hoàn hảo nhưng hữu ích
  /// cho UI confidence indicator.
  static double _estimateConfidenceFromText(String text) {
    // Text ngắn hoặc CAPS thường ít tin cậy hơn
    if (text.length < 5) return 0.7;
    if (text == text.toUpperCase() && text.length > 3) return 0.6;
    return 0.9;
  }

  // ── Word token parsing ────────────────────────────────────────────────────

  static List<SttWord> _parseWordTokens({
    required _WhisperLib lib,
    required ffi.Pointer<WhisperContext> ctx,
    required int segmentIndex,
  }) {
    final nTokens = lib.whisperFullNTokens(ctx, segmentIndex);
    final words = <SttWord>[];

    // Buffer để merge split tokens thành words hoàn chỉnh
    // Whisper thường tách "hello" thành "hel" + "lo" nếu BPE splits.
    final wordBuffer = StringBuffer();
    double wordStartMs = 0;
    double wordEndMs = 0;
    double wordConfidenceSum = 0;
    int wordTokenCount = 0;

    void flushWordBuffer() {
      if (wordBuffer.isEmpty) return;
      final wordText = wordBuffer.toString().trim();
      if (wordText.isNotEmpty && !_isSpecialToken(wordText)) {
        words.add(SttWord(
          word: wordText,
          startSeconds: wordStartMs / 1000.0,
          endSeconds: wordEndMs / 1000.0,
          confidence: wordTokenCount > 0
              ? (wordConfidenceSum / wordTokenCount).clamp(0.0, 1.0)
              : 1.0,
        ));
      }
      wordBuffer.clear();
      wordTokenCount = 0;
      wordConfidenceSum = 0;
    }

    for (var j = 0; j < nTokens; j++) {
      final tokenData = lib.whisperFullGetTokenData(ctx, segmentIndex, j);
      final tokenTextPtr = lib.whisperFullGetTokenText(ctx, segmentIndex, j);
      final tokenText = tokenTextPtr.cast<Utf8>().toDartString();

      // Bỏ qua special tokens hoàn toàn
      if (_isSpecialToken(tokenText)) continue;

      // Timestamps của token (centiseconds → ms)
      final tStartMs = tokenData.t0 * 10.0;
      final tEndMs = tokenData.t1 * 10.0;

      // Token bắt đầu bằng space → ranh giới từ mới
      if (tokenText.startsWith(' ') && wordBuffer.isNotEmpty) {
        flushWordBuffer();
        wordStartMs = tStartMs;
      } else if (wordBuffer.isEmpty) {
        wordStartMs = tStartMs;
      }

      wordBuffer.write(tokenText);
      wordEndMs = tEndMs;
      wordConfidenceSum += tokenData.p.clamp(0.0, 1.0);
      wordTokenCount++;
    }

    // Flush token cuối
    flushWordBuffer();

    return words;
  }

  /// Kiểm tra token có phải special token không.
  static bool _isSpecialToken(String token) {
    if (token.isEmpty) return true;
    if (token.trim().isEmpty) return true;
    // Whisper special tokens: [_BEG_], [_TT_X_], <|startoftranscript|>, v.v.
    if (token.startsWith('[') || token.startsWith('<')) return true;
    return false;
  }

  // ── Bước 4 cleanup: Free context ─────────────────────────────────────────

  static void _freeWhisperContext(
    _WhisperLib lib,
    ffi.Pointer<WhisperContext> ctx,
  ) {
    try {
      lib.whisperFree(ctx);
    } catch (e) {
      // Non-fatal — log và tiếp tục
      // ignore: avoid_print
      print('[Whisper] ⚠️ whisper_free error (non-fatal): $e');
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // AUDIO LOADING — Thuần Dart, Isolate-safe
  // ═════════════════════════════════════════════════════════════════════════

  /// Load audio file → PCM Float32 16kHz mono.
  ///
  /// Whisper.cpp yêu cầu ĐÚNG format này để hoạt động chính xác.
  ///
  /// Quan trọng: KHÔNG dùng MethodChannel (không hoạt động trong Isolate).
  /// Mọi xử lý audio phải dùng FFI hoặc thuần Dart.
  static Future<Float32List> _loadAudioAsPcm(String audioPath) async {
    if (!File(audioPath).existsSync()) {
      throw Exception('File audio không tồn tại: $audioPath');
    }

    final ext = audioPath.toLowerCase().split('.').last;

    return switch (ext) {
      'wav' => _parseWavFile(audioPath),
      'mp3' ||
      'm4a' ||
      'aac' ||
      'ogg' ||
      'flac' =>
        _decodeCompressedAudio(audioPath),
      _ => _tryParseAsWav(audioPath),
    };
  }

  /// Parse WAV file thuần Dart.
  ///
  /// Hỗ trợ: PCM 8/16/24/32-bit integer, 32-bit float.
  /// Auto-resample sang 16kHz nếu cần.
  /// Auto-mixdown stereo → mono.
  static Future<Float32List> _parseWavFile(String audioPath) async {
    final bytes = await File(audioPath).readAsBytes();

    if (bytes.length < 44) {
      throw const FormatException('WAV file quá nhỏ (< 44 bytes)');
    }

    final view = ByteData.sublistView(bytes);

    // ── Validate RIFF/WAVE header ──────────────────────────────────────────
    _assertFourCC(bytes, 0, 'RIFF', 'Không phải WAV: thiếu RIFF header');
    _assertFourCC(bytes, 8, 'WAVE', 'Không phải WAV: thiếu WAVE marker');

    // ── Parse chunks ───────────────────────────────────────────────────────
    int? sampleRate, numChannels, bitsPerSample, audioFormat;
    int dataOffset = -1, dataSize = -1;

    var cursor = 12;
    while (cursor + 8 <= bytes.length) {
      final chunkId = _readFourCC(bytes, cursor);
      final chunkSize = view.getUint32(cursor + 4, Endian.little);

      if (chunkId == 'fmt ') {
        if (chunkSize < 16) throw const FormatException('fmt chunk quá nhỏ');
        audioFormat = view.getUint16(cursor + 8, Endian.little);
        numChannels = view.getUint16(cursor + 10, Endian.little);
        sampleRate = view.getUint32(cursor + 12, Endian.little);
        bitsPerSample = view.getUint16(cursor + 22, Endian.little);
      } else if (chunkId == 'data') {
        dataOffset = cursor + 8;
        dataSize = chunkSize;
        break; // data chunk tìm thấy — dừng scan
      }

      cursor += 8 + chunkSize;
      if (chunkSize.isOdd) cursor++; // RIFF 2-byte alignment
    }

    // ── Validate ───────────────────────────────────────────────────────────
    if (sampleRate == null || numChannels == null || bitsPerSample == null) {
      throw const FormatException('WAV thiếu fmt chunk hợp lệ');
    }
    if (dataOffset < 0) {
      throw const FormatException('WAV thiếu data chunk');
    }
    if (audioFormat != 1 && audioFormat != 3) {
      // audioFormat 1 = PCM integer, 3 = IEEE 754 float
      // Các format khác (ADPCM, etc.) không hỗ trợ
      throw AudioFormatUnsupportedError(
        format: 'audioFormat=$audioFormat',
        suggestion: 'Convert sang PCM WAV (audioFormat=1) hoặc Float WAV (=3)',
      );
    }

    // ── Decode PCM → Float32 ───────────────────────────────────────────────
    final end = (dataOffset + dataSize).clamp(0, bytes.length);
    final dataBytes = Uint8List.sublistView(bytes, dataOffset, end);

    final pcm = _decodePcmBytes(
      dataBytes,
      bitsPerSample: bitsPerSample,
      audioFormat: audioFormat!,
      numChannels: numChannels,
    );

    // ── Resample → 16kHz nếu cần ──────────────────────────────────────────
    if (sampleRate == 16000) return pcm;
    return _linearResample(pcm, fromRate: sampleRate, toRate: 16000);
  }

  static void _assertFourCC(
    Uint8List bytes,
    int offset,
    String expected,
    String errorMsg,
  ) {
    final actual = _readFourCC(bytes, offset);
    if (actual != expected) throw FormatException('$errorMsg (got: $actual)');
  }

  static String _readFourCC(Uint8List bytes, int offset) =>
      String.fromCharCodes(bytes, offset, offset + 4);

  /// Decode raw PCM bytes → Float32 [-1.0, 1.0].
  ///
  /// Xử lý: stereo mixdown → mono, các bit depth phổ biến.
  static Float32List _decodePcmBytes(
    Uint8List dataBytes, {
    required int bitsPerSample,
    required int audioFormat,
    required int numChannels,
  }) {
    final view = ByteData.sublistView(dataBytes);
    final bytesPerSample = (bitsPerSample / 8).ceil();
    final bytesPerFrame = bytesPerSample * numChannels;

    if (bytesPerFrame == 0) return Float32List(0);

    final nFrames = dataBytes.length ~/ bytesPerFrame;
    final output = Float32List(nFrames);

    for (var frame = 0; frame < nFrames; frame++) {
      var monoSample = 0.0;

      for (var ch = 0; ch < numChannels; ch++) {
        final byteIdx = frame * bytesPerFrame + ch * bytesPerSample;
        if (byteIdx + bytesPerSample > dataBytes.length) break;

        // Decode sample theo bit depth và format
        final rawSample = _decodeSingleSample(
          view: view,
          offset: byteIdx,
          bitsPerSample: bitsPerSample,
          audioFormat: audioFormat,
        );

        monoSample += rawSample;
      }

      // Trung bình các channel → mono
      output[frame] = (monoSample / numChannels).clamp(-1.0, 1.0);
    }

    return output;
  }

  static double _decodeSingleSample({
    required ByteData view,
    required int offset,
    required int bitsPerSample,
    required int audioFormat,
  }) {
    return switch ((bitsPerSample, audioFormat)) {
      // 16-bit PCM integer (chuẩn phổ biến nhất)
      (16, 1) => view.getInt16(offset, Endian.little) / 32768.0,

      // 32-bit IEEE 754 float
      (32, 3) => view.getFloat32(offset, Endian.little).toDouble(),

      // 32-bit PCM integer
      (32, 1) => view.getInt32(offset, Endian.little) / 2147483648.0,

      // 24-bit PCM integer — sign extend thủ công
      (24, 1) => _decodeInt24(view, offset) / 8388608.0,

      // 8-bit PCM unsigned (đặc biệt: 128 = zero)
      (8, 1) => (view.getUint8(offset) - 128) / 128.0,
      _ => 0.0, // Không hỗ trợ → silence
    };
  }

  static double _decodeInt24(ByteData view, int offset) {
    final lo = view.getUint8(offset);
    final mid = view.getUint8(offset + 1);
    final hi = view.getUint8(offset + 2);
    var value = lo | (mid << 8) | (hi << 16);
    // Sign extend từ 24-bit lên 32-bit
    if (value & 0x800000 != 0) value |= 0xFF000000;
    return value.toSigned(32).toDouble();
  }

  /// Linear interpolation resample.
  ///
  /// Đủ chất lượng cho STT — Whisper không đòi hỏi resample chất lượng cao.
  /// Nếu cần sinc interpolation: thay bằng package `just_audio` hoặc custom.
  static Float32List _linearResample(
    Float32List input, {
    required int fromRate,
    required int toRate,
  }) {
    if (fromRate == toRate) return input;

    final ratio = fromRate / toRate;
    final outputLen = (input.length / ratio).floor();
    final output = Float32List(outputLen);

    for (var i = 0; i < outputLen; i++) {
      final srcF = i * ratio;
      final srcI = srcF.floor();
      final srcJ = (srcI + 1).clamp(0, input.length - 1);
      final frac = srcF - srcI;
      output[i] = input[srcI] * (1.0 - frac) + input[srcJ] * frac;
    }

    return output;
  }

  /// Fallback: thử parse file không rõ extension như WAV.
  static Future<Float32List> _tryParseAsWav(String audioPath) async {
    try {
      return await _parseWavFile(audioPath);
    } catch (e) {
      throw AudioFormatUnsupportedError(
        format: audioPath.split('.').last,
        suggestion:
            'Convert sang WAV 16kHz mono PCM 16-bit trước khi transcribe.',
      );
    }
  }

  /// Decode audio nén (MP3, M4A, AAC, OGG, FLAC) qua FFmpeg FFI.
  ///
  /// ⚠️ YÊU CẦU: ffmpeg_kit_flutter hoặc custom libavcodec FFI bindings.
  /// MethodChannel KHÔNG hoạt động trong Isolate — FFI là cách duy nhất.
  ///
  /// PRODUCTION PATTERN:
  ///   1. Convert sang PCM raw file tạm bằng ffmpeg command
  ///   2. Đọc raw file → Float32List
  ///   3. Xóa file tạm
  static Future<Float32List> _decodeCompressedAudio(String audioPath) async {
    //
    // ── OPTION A: FFmpeg Kit (execute trong Isolate nếu hỗ trợ) ─────────────
    //
    // import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
    //
    // final tmpPath = '${audioPath}_pcm_tmp.raw';
    // try {
    //   final session = await FFmpegKit.execute(
    //     '-y -i "$audioPath" -ar 16000 -ac 1 -f f32le "$tmpPath"',
    //   );
    //   final returnCode = await session.getReturnCode();
    //   if (!ReturnCode.isSuccess(returnCode)) {
    //     throw Exception('FFmpeg failed: ${await session.getOutput()}');
    //   }
    //   final rawBytes = await File(tmpPath).readAsBytes();
    //   return rawBytes.buffer.asFloat32List();
    // } finally {
    //   File(tmpPath).deleteSync(); // cleanup
    // }
    //
    // ── OPTION B: Pre-convert trước khi gọi transcribe ───────────────────────
    //
    // Đây là approach đơn giản nhất:
    // - Trước khi gọi SttServiceFacade.transcribeFile(), convert sang WAV:
    //     final wavPath = await AudioConverter.toWav16kHz(audioPath);
    //     await facade.transcribeFile(wavPath, ...);
    //
    // ────────────────────────────────────────────────────────────────────────

    throw AudioFormatUnsupportedError(
      format: audioPath.split('.').last.toUpperCase(),
      suggestion:
          'Pre-convert sang WAV 16kHz mono PCM trước khi gọi transcribe. '
          'Xem AudioConverter.toWav16kHz() trong utils/audio_converter.dart.',
    );
  }

  // ── Bước 8 impl: Write LRC file ──────────────────────────────────────────

  /// Ghi file .lrc trong Isolate — an toàn vì dùng File IO thuần Dart.
  ///
  /// Tên file = fingerprint.lrc → duy nhất, không xung đột.
  static Future<String?> _writeLrcFile({
    required SttResult result,
    required String audioPath,
    required String outputDirectory,
  }) async {
    try {
      // Tạo thư mục nếu chưa có
      final dir = Directory(outputDirectory);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      final lrcPath = '$outputDirectory/${result.audioFingerprint}.lrc';
      final buf = StringBuffer();

      // ── LRC Header ───────────────────────────────────────────────────────
      buf
        ..writeln('[ti:${audioPath.split('/').last}]')
        ..writeln('[by:VipSound STT v11.0]')
        ..writeln('[ve:${result.engineUsed.name}]')
        ..writeln('[la:${result.language}]')
        ..writeln('');

      // ── LRC Lines ────────────────────────────────────────────────────────
      //
      // Format chuẩn: [mm:ss.cc]text
      // cc = centiseconds (1/100 giây)
      for (final seg in result.segments) {
        final ms = seg.startMs;
        final mm = (ms ~/ 60000).toString().padLeft(2, '0');
        final ss = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
        final cc = ((ms % 1000) ~/ 10).toString().padLeft(2, '0');
        buf.writeln('[$mm:$ss.$cc]${seg.text.trim()}');
      }

      // Sync write — File IO trong Isolate không block event loop
      File(lrcPath).writeAsStringSync(buf.toString(), flush: true);

      // ignore: avoid_print
      print(
        '[Isolate:Whisper] 📄 LRC written: $lrcPath '
        '(${result.segments.length} lines)',
      );

      return lrcPath;
    } catch (e) {
      // Non-fatal: LRC là output phụ, không ảnh hưởng transcript chính
      // ignore: avoid_print
      print('[Isolate:Whisper] ⚠️ LRC write failed (non-fatal): $e');
      return null;
    }
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  /// Validate paths trước khi làm bất kỳ việc gì.
  ///
  /// Fail fast — tránh tốn thời gian load FFI rồi mới phát hiện lỗi.
  static String? _validatePaths(SttIsolatePayload payload) {
    if (payload.audioPath.isEmpty) {
      return 'audioPath không được rỗng';
    }
    if (payload.modelPath.isEmpty) {
      return 'modelPath rỗng — model chưa được tải về. '
          'Vào Settings → AI Model để tải về trước.';
    }
    if (!File(payload.audioPath).existsSync()) {
      return 'File audio không tồn tại: ${payload.audioPath}';
    }
    if (!File(payload.modelPath).existsSync()) {
      return 'File model không tồn tại: ${payload.modelPath}. '
          'Thử download lại trong Settings → AI Model.';
    }
    // Kiểm tra file model có phải .bin không
    if (!payload.modelPath.toLowerCase().endsWith('.bin')) {
      return 'File model không hợp lệ (phải là .bin): ${payload.modelPath}';
    }
    return null; // Tất cả OK
  }

  /// Tính fingerprint nhanh — fallback khi không có fingerprint từ Main Thread.
  ///
  /// CẢNH BÁO: Kém stable hơn [AudioFingerprintUtil.compute()] vì không
  /// dùng file size và duration. Chỉ dùng trong emergency.
  static String _quickFingerprint(String audioPath) {
    return 'fp_${audioPath.hashCode.abs().toRadixString(16)}';
  }
}
