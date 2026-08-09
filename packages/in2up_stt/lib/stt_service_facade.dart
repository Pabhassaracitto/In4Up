// packages/in2up_stt/lib/stt_service_facade.dart
//
// in2up v11.0 — STT Service Facade (Isolate-safe Architecture)
//
// LUỒNG HOÀN CHỈNH:
//
//   Main Thread                          Isolate
//   ─────────────────────────────        ──────────────────────────────────
//   transcribeFile()
//     ↓ (cache miss)
//   _runWhisperViaIsolate()
//     ├─ A. resolve modelPath            (không thể làm trong Isolate)
//     ├─ B. resolve lrcDirectory         (path_provider = platform channel)
//     ├─ C. compute fingerprint          (AudioFingerprintUtil)
//     ├─ D. build SttIsolatePayload
//     └─ compute(_isolateEntryPoint) ──▶ SttEngineWhisper.runInIsolate()
//                                          ├─ validate paths
//                                          ├─ load PCM (thuần Dart)
//                                          ├─ load Whisper FFI
//                                          ├─ init context
//                                          ├─ whisper_full()
//                                          ├─ parse segments + UID
//                                          └─ write LRC (optional)
//   receive SttIsolateResult ◀──────────
//     ├─ E. toSttResult()
//     ├─ F. cache result
//     └─ G. _generateLrcAndDiarization()
//              ├─ DiarizationService
//              └─ SpeakerSidecar.save()

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';

import 'diarization/diarization_service.dart';
import 'diarization/speaker_annotation.dart';
import 'diarization/speaker_sidecar.dart';
import 'models/stt_config.dart';
import 'models/stt_isolate_payload.dart';
import 'models/stt_model_info.dart';
import 'models/stt_result.dart';
import 'stt_engine_native.dart';
import 'stt_engine_whisper.dart';
import 'stt_lrc_converter.dart';
import 'stt_model_manager.dart';
import 'utils/audio_converter.dart';

// ═══════════════════════════════════════════════════════════════════════════
// PHẦN 1: PROGRESS & OUTPUT TYPES
// ═══════════════════════════════════════════════════════════════════════════

enum SttFacadeStatus {
  idle,
  initializing,
  ready,
  processingNative,
  processingWhisper,
  generatingLrc,
  error,
}

class SttProgress {
  final SttFacadeStatus status;
  final double progress; // [0.0, 1.0]
  final String message;
  final SttEngineType? activeEngine;

  /// Tiến độ chunk (nếu có bật chunking).
  final int chunkIndex; // 0-based, chunk đang xử lý
  final int chunkCount; // tổng số chunk

  const SttProgress({
    required this.status,
    required this.progress,
    required this.message,
    this.activeEngine,
    this.chunkIndex = 0,
    this.chunkCount = 0,
  });

  /// Tạo bản sao với thông tin chunk mới (giữ nguyên các trường khác).
  SttProgress withChunk({required int index, required int count}) {
    return SttProgress(
      status: status,
      progress: progress,
      message: message,
      activeEngine: activeEngine,
      chunkIndex: index,
      chunkCount: count,
    );
  }

  static const idle = SttProgress(
    status: SttFacadeStatus.idle,
    progress: 0.0,
    message: '',
  );

  bool get isActive => switch (status) {
        SttFacadeStatus.initializing ||
        SttFacadeStatus.processingNative ||
        SttFacadeStatus.processingWhisper ||
        SttFacadeStatus.generatingLrc =>
          true,
        _ => false,
      };
}

class SttTranscribeOutput {
  final SttResult result;
  final List<SpeakerAnnotation> speakers;
  final String? lrcFilePath;
  final String? spkFilePath;
  final bool wasLrcGenerated;
  final String? errorMessage;
  final bool success;

  const SttTranscribeOutput({
    required this.result,
    this.speakers = const [],
    this.lrcFilePath,
    this.spkFilePath,
    this.wasLrcGenerated = false,
    this.errorMessage,
    required this.success,
  });

  factory SttTranscribeOutput.failure(String error) => SttTranscribeOutput(
        result: SttResult.empty(SttEngineType.native),
        errorMessage: error,
        success: false,
      );

  bool get hasDiarization => speakers.any((s) => s.speakerId > 0);
}

// ═══════════════════════════════════════════════════════════════════════════
// PHẦN 2: FACADE CLASS
// ═══════════════════════════════════════════════════════════════════════════

class SttServiceFacade extends ChangeNotifier {
  static SttServiceFacade? _instance;

  factory SttServiceFacade() => _instance ??= SttServiceFacade._internal();

  SttServiceFacade._internal();

  // ── Fields ────────────────────────────────────────────────────────────────
  late final SttEngineNative _nativeEngine;
  late final SttModelManager _modelManager;
  late final SttLrcConverter _lrcConverter;
  late final DiarizationService _diarizationService;

  bool _initialized = false;
  bool _disposed = false;
  SttConfig _config = const SttConfig();
  Future<void>? _initFuture;

  // Cờ hủy: người dùng có thể dừng transcribe giữa chừng (giữa các chunk).
  bool _cancelRequested = false;

  final _progressSubject =
      BehaviorSubject<SttProgress>.seeded(SttProgress.idle);

  Stream<SttProgress> get progressStream => _progressSubject.stream;
  SttProgress get currentProgress => _progressSubject.value;

  // Stream kết quả từng phần khi transcribe theo chunk — UI có thể hiện
  // dần lời thoại thay vì đợi hết file.
  final _partialSubject = BehaviorSubject<SttResult>.seeded(
    SttResult.empty(SttEngineType.whisper),
  );
  Stream<SttResult> get partialResultStream => _partialSubject.stream;

  /// Yêu cầu hủy transcribe đang chạy (dừng giữa các chunk, giữ kết quả
  /// đã hoàn thành). Cờ được reset khi bắt đầu transcribe mới.
  void cancelTranscription() {
    _cancelRequested = true;
    debugPrint('⏹️ SttServiceFacade: cancelTranscription() được gọi');
  }

  /// Đặt lại trạng thái cho lần transcribe mới: bỏ cờ hủy + làm rỗng
  /// partial (tránh giữ nội dung bài cũ).
  void resetForNewTranscription() {
    _cancelRequested = false;
    if (!_disposed) {
      _partialSubject.add(SttResult.empty(SttEngineType.whisper));
    }
    debugPrint('🔄 SttServiceFacade: resetForNewTranscription()');
  }

  // Cache key: "${audioPath}_${engine}_${modelLevel}_${language}"
  final _resultCache = <String, SttResult>{};

  // ── Initialization ────────────────────────────────────────────────────────

  Future<void> initialize({
    SttConfig? config,
    Map<WhisperModelLevel, List<String>>? modelUrls,
    Map<WhisperModelLevel, List<String>>? acceptedModelNames,
  }) {
    if (_initialized) return Future.value();
    return _initFuture ??= _initializeInternal(
      config: config,
      modelUrls: modelUrls,
      acceptedModelNames: acceptedModelNames,
    );
  }

  Future<void> _initializeInternal({
    SttConfig? config,
    Map<WhisperModelLevel, List<String>>? modelUrls,
    Map<WhisperModelLevel, List<String>>? acceptedModelNames,
  }) async {
    try {
      _emitProgress(SttFacadeStatus.initializing, 0.0, 'Đang khởi tạo...');

      _config = config ?? const SttConfig();
      _nativeEngine = SttEngineNative();
      _modelManager = SttModelManager();
      _lrcConverter = SttLrcConverter();
      _diarizationService = const HeuristicDiarizationService();

      _modelManager.configureSources(
        urls: modelUrls,
        acceptedFileNames: acceptedModelNames,
      );

      await _modelManager.initialize();
      _emitProgress(SttFacadeStatus.initializing, 0.5, 'Kiểm tra model...');

      // Native STT init is non-fatal: nếu thất bại, app vẫn chạy và fallback
      // sang Whisper. Dùng try/catch thay vì .catchError để tránh lỗi type
      // (onError phải trả về giá trị assignable cho kiểu Future).
      try {
        await _nativeEngine.initialize();
      } catch (e) {
        debugPrint('⚠️ Native STT init failed (non-fatal): $e');
      }

      _initialized = true;
      _emitProgress(SttFacadeStatus.ready, 1.0, 'Sẵn sàng');
      debugPrint('✅ SttServiceFacade initialized');

      if (!_disposed) notifyListeners();
    } finally {
      _initFuture = null;
    }
  }

  // ── Public API (signature không thay đổi) ─────────────────────────────────

  /// Transcribe với Isolate thực thụ — UI thread KHÔNG bị block.
  ///
  /// **Luồng xử lý:**
  /// 1. Check cache
  /// 2. Resolve platform-dependent resources (Main Thread)
  /// 3. Spawn Isolate qua [compute()]
  /// 4. Nhận kết quả, chạy Diarization (Main Thread)
  Future<SttTranscribeOutput> transcribeFile(
    String audioPath, {
    SttConfig? config,
    String? lrcOutputPath,
    bool generateLrc = false,
    String audioFingerprint = '',
  }) async {
    _ensureInitialized();

    // Reset cờ hủy + partial từ lần trước khi bắt đầu lần mới.
    resetForNewTranscription();

    final cfg = config ?? _config;
    final shouldGenerateLrc = generateLrc || cfg.generateLrc;
    final cacheKey = _buildCacheKey(audioPath, cfg);

    // ── Cache check ───────────────────────────────────────────────────────
    if (cfg.cacheResults && _resultCache.containsKey(cacheKey)) {
      debugPrint('💾 STT cache hit: $cacheKey');
      final cached = _resultCache[cacheKey]!;

      if (shouldGenerateLrc && cached.segments.isNotEmpty) {
        final gen = await _generateLrcAndDiarization(
          cached,
          audioPath,
          lrcOutputPath,
        );
        return SttTranscribeOutput(
          result: cached,
          speakers: gen.speakers,
          lrcFilePath: gen.lrcPath,
          spkFilePath: gen.spkPath,
          wasLrcGenerated: gen.lrcPath != null,
          success: true,
        );
      }
      return SttTranscribeOutput(result: cached, success: true);
    }

    // ── Route theo engine ─────────────────────────────────────────────────
    try {
      final SttResult result;

      if (cfg.preferredEngine == SttEngineType.whisper) {
        result = await _runWhisperViaIsolate(
          audioPath: audioPath,
          config: cfg,
          lrcOutputPath: lrcOutputPath,
          shouldGenerateLrc: shouldGenerateLrc,
          audioFingerprint: audioFingerprint,
        );
      } else {
        // Native engine: nhanh, chạy trực tiếp trên Main (không cần Isolate)
        var nativeResult = await _runNativeEngine(audioPath, cfg);

        if (cfg.autoFallback && nativeResult.fullText.isEmpty) {
          debugPrint('⚠️ Native STT empty → fallback Whisper Isolate');
          nativeResult = await _runWhisperViaIsolate(
            audioPath: audioPath,
            config: cfg,
            lrcOutputPath: lrcOutputPath,
            shouldGenerateLrc: shouldGenerateLrc,
            audioFingerprint: audioFingerprint,
          );
        }
        result = nativeResult;
      }

      // ── Đảm bảo fingerprint được gán ─────────────────────────────────
      final finalResult =
          (audioFingerprint.isNotEmpty && result.audioFingerprint.isEmpty)
              ? _withFingerprint(result, audioFingerprint)
              : result;

      // ── Cache ─────────────────────────────────────────────────────────
      if (cfg.cacheResults) _resultCache[cacheKey] = finalResult;

      // ── LRC + Diarization pipeline ────────────────────────────────────
      if (shouldGenerateLrc && finalResult.segments.isNotEmpty) {
        final gen = await _generateLrcAndDiarization(
          finalResult,
          audioPath,
          lrcOutputPath,
        );
        _emitProgress(SttFacadeStatus.ready, 1.0, 'Hoàn tất!');
        return SttTranscribeOutput(
          result: finalResult,
          speakers: gen.speakers,
          lrcFilePath: gen.lrcPath,
          spkFilePath: gen.spkPath,
          wasLrcGenerated: gen.lrcPath != null,
          success: true,
        );
      }

      _emitProgress(SttFacadeStatus.ready, 1.0, 'Hoàn tất!');
      return SttTranscribeOutput(result: finalResult, success: true);
    } catch (e, stack) {
      debugPrint('❌ transcribeFile error: $e\n$stack');
      _emitProgress(SttFacadeStatus.error, 0.0, 'Lỗi: $e');
      return SttTranscribeOutput.failure(e.toString());
    }
  }

  /// Deep transcribe — Whisper Small, có LRC.
  /// API không đổi — PlayerSttMixin không cần chỉnh sửa.
  Future<SttTranscribeOutput> transcribeDeep(
    String audioPath, {
    String? lrcSavePath,
    WhisperModelLevel level = WhisperModelLevel.small,
    String language = 'en',
    String audioFingerprint = '',
  }) =>
      transcribeFile(
        audioPath,
        config: SttConfig.deepLearning.copyWith(
          whisperModel: level,
          language: language,
          generateLrc: true,
        ),
        lrcOutputPath: lrcSavePath,
        generateLrc: true,
        audioFingerprint: audioFingerprint,
      );

  /// Quick transcribe — Native engine, không cần LRC.
  /// API không đổi.
  Future<SttTranscribeOutput> transcribeQuick(
    String audioPath, {
    String language = 'en-US',
  }) =>
      transcribeFile(
        audioPath,
        config: SttConfig.quickNote,
        generateLrc: false,
      );

  /// Auto transcribe — chọn model tốt nhất đang có offline.
  Future<SttTranscribeOutput> transcribeAuto(
    String audioPath, {
    String language = 'en',
    String? lrcOutputPath,
    bool generateLrc = true,
    String audioFingerprint = '',
    SttSegmentGrouping grouping = SttSegmentGrouping.sentence,
  }) async {
    _ensureInitialized();

    final localLevel = _modelManager.getBestAvailableLocalModel(
      preferredOrder: const [
        WhisperModelLevel.base,
        WhisperModelLevel.tiny,
        WhisperModelLevel.small,
        WhisperModelLevel.medium,
        WhisperModelLevel.large,
      ],
    );

    if (localLevel == null) {
      _emitProgress(SttFacadeStatus.ready, 0.0, 'Không có model offline.');
      return SttTranscribeOutput.failure(
        'Không có model Whisper nào được tải về. '
        'Vào Settings → AI Model để tải model.',
      );
    }

    return transcribeFile(
      audioPath,
      config: _config.copyWith(
        preferredEngine: SttEngineType.whisper,
        whisperModel: localLevel,
        language: language,
        generateLrc: generateLrc,
        grouping: grouping,
      ),
      lrcOutputPath: lrcOutputPath,
      generateLrc: generateLrc,
      audioFingerprint: audioFingerprint,
    );
  }

  // ── Isolate Orchestrator ──────────────────────────────────────────────────
  //
  // Tất cả platform-dependent operations phải hoàn thành TẠI ĐÂY,
  // trước khi spawn Isolate. Isolate chỉ nhận plain data.

  Future<SttResult> _runWhisperViaIsolate({
    required String audioPath,
    required SttConfig config,
    required String? lrcOutputPath,
    required bool shouldGenerateLrc,
    required String audioFingerprint,
  }) async {
    _emitProgress(
      SttFacadeStatus.processingWhisper,
      0.05,
      'Đang chuẩn bị...',
      engine: SttEngineType.whisper,
    );

    // ── A1. Pre-convert audio if needed (Main Thread) ─────────────────────
    final convertedPath =
        await AudioConverter.convertToWhisperCompatible(audioPath);

    // ── A2. Resolve modelPath (cần SttModelManager Singleton — Main only) ──
    final modelPath = _modelManager.getModelPath(config.whisperModel);

    if (modelPath == null || modelPath.isEmpty) {
      throw StateError(
        'Model "${config.whisperModel.name}" chưa được tải về. '
        'Vào Settings → AI Model để tải.',
      );
    }

    // Verify file tồn tại trước khi spawn Isolate
    if (!File(modelPath).existsSync()) {
      throw StateError(
        'File model không tồn tại trên đĩa: $modelPath. '
        'Thử download lại trong Settings → AI Model.',
      );
    }

    // ── B. Resolve LRC directory (cần path_provider — Main only) ──────────
    final lrcDirectory = await _resolveLrcDirectory(lrcOutputPath);

    // ── C. Compute audio fingerprint ───────────────────────────────────────
    //
    // Tính sẵn trên Main Thread để Isolate không cần File stat.
    // Dùng AudioFingerprintUtil nếu caller không cung cấp fingerprint.
    final fingerprint = audioFingerprint.isNotEmpty
        ? audioFingerprint
        : await _computeAudioFingerprint(audioPath);

    // ── C2. Mobile (Android/iOS) → chạy plugin trên Main Thread ────────────
    //
    // whisper_flutter_new dùng MethodChannel + native lib bundle riêng cho
    // mobile, PHẢI chạy trên Main Thread (không được đưa vào Isolate).
    // Đây là "known-good path" trước refactor v11. FFI-in-isolate chỉ hợp
    // cho desktop.
    if (SttEngineWhisper.isMobilePluginSupported) {
      try {
        return await SttEngineWhisper.transcribeMobileChunked(
          audioPath: convertedPath ?? audioPath,
          modelDir: _modelManager.modelDirectoryPath,
          level: config.whisperModel,
          language: config.language,
          wordTimestamps: true,
          audioFingerprint: fingerprint,
          chunkDurationSeconds: config.chunkDurationSeconds,
          maxChunks: config.maxChunks,
          grouping: config.grouping,
          onChunkDone: (chunk, count, partial) {
            _emitProgress(
              SttFacadeStatus.processingWhisper,
              0.10 + 0.85 * ((chunk + 1) / count),
              'Đang nhận diện chunk ${chunk + 1}/$count…',
              engine: SttEngineType.whisper,
              chunkIndex: chunk,
              chunkCount: count,
            );
            if (!_disposed) _partialSubject.add(partial);
          },
          shouldCancel: () => _disposed || _cancelRequested,
        );
      } finally {
        // Dọn file tạm của converter (đường mobile không qua isolate).
        if (convertedPath != null) {
          await AudioConverter.cleanupConvertedFile(convertedPath);
        }
      }
    }

    // ── D. Build SttIsolatePayload — CHỈ plain data ────────────────────────
    final payload = SttIsolatePayload(
      audioPath: convertedPath ?? audioPath,
      modelPath: modelPath, // ← đã resolved
      language: config.language,
      wordTimestamps: true,
      modelLevelName: config.whisperModel.name,
      audioFingerprint: fingerprint, // ← đã computed
      generateLrc: shouldGenerateLrc,
      lrcOutputDirectory: shouldGenerateLrc ? lrcDirectory : null,
    );

    _emitProgress(
      SttFacadeStatus.processingWhisper,
      0.10,
      'Transcribing với Whisper ${config.whisperModel.name}...',
      engine: SttEngineType.whisper,
    );

    // ── E. Spawn Isolate — UI thread hoàn toàn tự do ──────────────────────
    //
    // compute() tự động:
    //   1. Spawn Isolate mới
    //   2. Serialize payload qua SendPort
    //   3. Gọi _isolateEntryPoint(payload) trong Isolate
    //   4. Serialize kết quả về Main
    //   5. Đóng Isolate
    final isolateResult = await compute(
      _isolateEntryPoint, // static method — serialize được
      payload,
    );

    // ── E2. Cleanup converted file (Main Thread) ─────────────────────────
    if (convertedPath != null) {
      await AudioConverter.cleanupConvertedFile(convertedPath);
    }

    _emitProgress(
      SttFacadeStatus.processingWhisper,
      0.90,
      'Whisper hoàn tất!',
      engine: SttEngineType.whisper,
    );

    // ── F. Xử lý kết quả từ Isolate ──────────────────────────────────────
    if (!isolateResult.success) {
      final err = isolateResult.errorMessage ?? 'Lỗi không xác định từ Isolate';
      debugPrint('❌ Isolate returned failure: $err');
      throw Exception(err);
    }

    debugPrint(
      '✅ Whisper hoàn tất: ${isolateResult.segmentsJson.length} segments, '
      '${isolateResult.processingTimeMs}ms',
    );

    // ── G. Reconstruct SttResult trên Main Thread ─────────────────────────
    //
    // isolateResult.toSttResult() gọi SttSegment.fromJson() cho từng segment.
    // UID trong JSON đã được tính đúng bởi Isolate (ContentId.segmentUid).
    return isolateResult.toSttResult();
  }

  // ── Isolate Entry Point ───────────────────────────────────────────────────
  //
  // ★ PHẢI là static method hoặc top-level function.
  // ★ Lambda / closure KHÔNG hoạt động với compute() — Dart serialize
  //   function reference, không serialize closure state.
  // ★ KHÔNG được truy cập bất kỳ instance nào của Main Thread:
  //   - Không: SttServiceFacade._instance
  //   - Không: SttModelManager._instance
  //   - Không: Platform channels (path_provider, etc.)

  static Future<SttIsolateResult> _isolateEntryPoint(
    SttIsolatePayload payload,
  ) {
    // 100% delegate cho stateless engine — không có gì khác ở đây.
    // SttEngineWhisper.runInIsolate() không truy cập bất kỳ Singleton nào.
    return SttEngineWhisper.runInIsolate(payload);
  }

  // ── LRC + Diarization Pipeline (Main Thread) ──────────────────────────────
  //
  // Chạy trên Main Thread vì:
  // - DiarizationService có thể cần các service của Main Thread
  // - SpeakerSidecar cần path resolved từ path_provider
  // - Đây là bước nhẹ (heuristic) — không cần Isolate

  Future<
      ({
        String? lrcPath,
        String? spkPath,
        List<SpeakerAnnotation> speakers,
      })> _generateLrcAndDiarization(
    SttResult result,
    String audioPath,
    String? outputPath,
  ) async {
    const empty = (
      lrcPath: null,
      spkPath: null,
      speakers: <SpeakerAnnotation>[],
    );

    if (result.segments.isEmpty) return empty;

    try {
      _emitProgress(
        SttFacadeStatus.generatingLrc,
        0.88,
        'Đang tạo file LRC...',
      );

      final lrcDir = await _resolveLrcDirectory(outputPath);

      // ── 1. Tạo LRC file (Main Thread) ─────────────────────────────────
      final lrcPath = await _lrcConverter.saveLrcFile(
        result,
        audioPath,
        outputDirectory: lrcDir,
      );

      if (lrcPath == null) {
        debugPrint('⚠️ LrcConverter.saveLrcFile() trả về null');
        return empty;
      }

      _emitProgress(
        SttFacadeStatus.generatingLrc,
        0.93,
        'Phân tách người nói...',
      );

      // ── 2. Diarization (phân tách người nói) ──────────────────────────
      final speakers = await _diarizationService.diarize(result);

      // ── 3. Speaker sidecar .spk.json ───────────────────────────────────
      String? spkPath;
      if (speakers.isNotEmpty) {
        await SpeakerSidecar.save(
          lrcPath: lrcPath,
          audioFingerprint: result.audioFingerprint,
          annotations: speakers,
        );
        spkPath = SpeakerSidecar.getSidecarPath(lrcPath);
        debugPrint('💾 Speaker sidecar: $spkPath');
      }

      _emitProgress(SttFacadeStatus.generatingLrc, 0.98, 'Hoàn tất!');

      return (lrcPath: lrcPath, spkPath: spkPath, speakers: speakers);
    } catch (e, stack) {
      debugPrint('❌ _generateLrcAndDiarization error: $e\n$stack');
      return empty;
    }
  }

  // ── Native Engine Runner ──────────────────────────────────────────────────

  Future<SttResult> _runNativeEngine(
    String audioPath,
    SttConfig config,
  ) async {
    _emitProgress(
      SttFacadeStatus.processingNative,
      0.10,
      'Đang nhận diện giọng nói...',
      engine: SttEngineType.native,
    );

    final result = await _nativeEngine.transcribeFile(
      audioPath,
      language: config.language,
    );

    _emitProgress(
      SttFacadeStatus.processingNative,
      0.90,
      'Native STT hoàn tất',
    );

    return result;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<String> _resolveLrcDirectory(String? override) async {
    if (override != null && override.isNotEmpty) return override;
    final appDir = await getApplicationDocumentsDirectory();
    return p.join(appDir.path, '.in2up_lrc');
  }

  /// Tính audio fingerprint đúng chuẩn ContentId.
  ///
  /// Dùng file size + duration + basename → MD5[:16].
  /// Khớp với [AudioFingerprintUtil.compute()] nếu durationMs đã biết.
  ///
  /// Vì Facade không có durationMs (cần audio player cung cấp),
  /// ta dùng file size + basename làm fingerprint nhanh.
  /// Caller (PlayerSttMixin) nên truyền audioFingerprint đúng chuẩn.
  Future<String> _computeAudioFingerprint(String audioPath) async {
    try {
      final file = File(audioPath);
      if (!await file.exists()) {
        return _hashPath(audioPath);
      }

      // Đọc 64KB đầu để tạo content-based fingerprint nhanh
      const sampleSize = 64 * 1024; // 64KB
      final raf = await file.open();
      final bytes = await raf.read(sampleSize);
      await raf.close();

      // FNV-1a hash — nhanh, phân tán tốt
      var hash = 0xcbf29ce484222325;
      for (final byte in bytes) {
        hash ^= byte;
        // Dart int là 64-bit signed — dùng & để giữ trong phạm vi
        hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
      }

      return 'fp_${hash.toRadixString(16).substring(0, 16)}';
    } catch (e) {
      debugPrint('⚠️ _computeAudioFingerprint fallback: $e');
      return _hashPath(audioPath);
    }
  }

  String _hashPath(String audioPath) =>
      'fp_${audioPath.hashCode.abs().toRadixString(16)}';

  /// Tạo SttResult mới với fingerprint được gán — immutable pattern.
  SttResult _withFingerprint(SttResult result, String fingerprint) {
    return SttResult(
      fullText: result.fullText,
      segments: result.segments,
      engineUsed: result.engineUsed,
      language: result.language,
      processingTime: result.processingTime,
      audioFingerprint: fingerprint,
      hasWordTimestamps: result.hasWordTimestamps,
    );
  }

  String _buildCacheKey(String audioPath, SttConfig config) =>
      '${audioPath}_${config.preferredEngine.name}_'
      '${config.whisperModel.name}_${config.language}';

  void _emitProgress(
    SttFacadeStatus status,
    double progress,
    String message, {
    SttEngineType? engine,
    int chunkIndex = 0,
    int chunkCount = 0,
  }) {
    if (_disposed) return;
    _progressSubject.add(SttProgress(
      status: status,
      progress: progress.clamp(0.0, 1.0),
      message: message,
      activeEngine: engine,
      chunkIndex: chunkIndex,
      chunkCount: chunkCount,
    ));
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'SttServiceFacade chưa được khởi tạo. '
        'Gọi await sttService.initialize() trước.',
      );
    }
  }

  // ── Model Management API (không thay đổi) ────────────────────────────────

  SttModelInfo getModelInfo(WhisperModelLevel level) =>
      _modelManager.getModelInfo(level);

  Stream<SttModelInfo> watchModel(WhisperModelLevel level) =>
      _modelManager.watchModel(level);

  Future<void> deleteModel(WhisperModelLevel level) =>
      _modelManager.deleteModel(level);

  Future<bool> importModelFromPath(
    String sourcePath, {
    WhisperModelLevel? level,
  }) {
    _ensureInitialized();
    return _modelManager.importModelFromPath(sourcePath, level: level);
  }

  bool get hasAnyModel => _modelManager.hasAnyLocalModel;

  // ── Live STT ──────────────────────────────────────────────────────────────

  Future<bool> startListening({String language = 'en-US'}) async {
    _ensureInitialized();
    return _nativeEngine.startListening(language: language);
  }

  Future<void> stopListening() async => _nativeEngine.stopListening();

  Stream<SttResult> get liveResultStream => _nativeEngine.resultStream;

  // ── Config & Cache ────────────────────────────────────────────────────────

  void updateConfig(SttConfig config) {
    _config = config;
    if (!_disposed) notifyListeners();
  }

  void clearCache() {
    _resultCache.clear();
    debugPrint('🗑️ STT result cache cleared');
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _nativeEngine.dispose();
    _modelManager.dispose();
    _progressSubject.close();
    _partialSubject.close();
    _instance = null;
    super.dispose();
  }
}
