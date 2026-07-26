// VipSound v11.0 — Facade hoàn chỉnh với Diarization pipeline

import 'dart:async';

import 'package:flutter/foundation.dart';
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

// ─── Progress ─────────────────────────────────────────────────────────────────

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
  final double progress;
  final String message;
  final SttEngineType? activeEngine;

  const SttProgress({
    required this.status,
    required this.progress,
    required this.message,
    this.activeEngine,
  });

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

// ─── Output ───────────────────────────────────────────────────────────────────

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

// ─── Facade ───────────────────────────────────────────────────────────────────

class SttServiceFacade extends ChangeNotifier {
  static SttServiceFacade? _instance;
  factory SttServiceFacade() => _instance ??= SttServiceFacade._internal();
  SttServiceFacade._internal();

  // ── Fields ────────────────────────────────────────────────
  late final SttEngineNative _nativeEngine;
  late final SttEngineWhisper _whisperEngine;
  late final SttModelManager _modelManager;
  late final SttLrcConverter _lrcConverter;
  late final DiarizationService _diarizationService;

  bool _initialized = false;
  bool _disposed = false;
  SttConfig _config = const SttConfig();
  Future<void>? _initFuture;

  final _progressSubject =
      BehaviorSubject<SttProgress>.seeded(SttProgress.idle);
  Stream<SttProgress> get progressStream => _progressSubject.stream;
  SttProgress get currentProgress => _progressSubject.value;

  final _resultCache = <String, SttResult>{};

  // ── Init ──────────────────────────────────────────────────

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
      _whisperEngine = SttEngineWhisper();
      _modelManager = SttModelManager();
      _lrcConverter = SttLrcConverter();
      _diarizationService = const HeuristicDiarizationService();

      _modelManager.configureSources(
        urls: modelUrls,
        acceptedFileNames: acceptedModelNames,
      );

      await _modelManager.initialize();
      _emitProgress(SttFacadeStatus.initializing, 0.5, 'Kiểm tra model...');

      await _nativeEngine.initialize().catchError((e) {
        debugPrint('⚠️ Native STT init failed (non-fatal): $e');
      });

      _initialized = true;
      _emitProgress(SttFacadeStatus.ready, 1.0, 'Sẵn sàng');
      debugPrint('✅ SttServiceFacade initialized');

      if (!_disposed) notifyListeners();
    } finally {
      _initFuture = null;
    }
  }

  // ── Core Transcribe ───────────────────────────────────────

  Future<SttTranscribeOutput> transcribeFile(
    String audioPath, {
    SttConfig? config,
    String? lrcOutputPath,
    bool generateLrc = false,
    String audioFingerprint = '',
  }) async {
    final cfg = config ?? _config;
    final modelInfo = _modelManager.getModelInfo(cfg.whisperModel);

    // Resolve model path trước khi truyền vào Isolate
    final modelPath = modelInfo.localPath ?? '';

    final payload = SttIsolatePayload(
      audioPath: audioPath,
      modelPath: modelPath,
      language: cfg.language,
      wordTimestamps: true,
      modelLevelName: cfg.whisperModel.name,
      audioFingerprint: audioFingerprint,
      generateLrc: generateLrc,
      lrcOutputDirectory: lrcOutputPath,
    );

    // Chuyển sang Isolate để không treo UI
    // Lưu ý: Đang sử dụng logic placeholder vì cần logic engine mới bên trong Isolate
    return compute(_transcribeFileIsolate, payload);
  }

  // Helper cho isolate (cần static hoặc top-level)
  static Future<SttTranscribeOutput> _transcribeFileIsolate(
      SttIsolatePayload payload) async {
    debugPrint(
        'DEBUG [STT]: Transcribe requested (Isolate: ${payload.modelPath})');
    // TODO: Khởi tạo engine Whisper cục bộ trong phạm vi isolate (không dùng instance facade)
    return SttTranscribeOutput.failure(
        'Isolate integration: Pending engine setup inside isolate');
  }

  Future<SttTranscribeOutput> _transcribeFileInternal(
    String audioPath, {
    SttConfig? config,
    String? lrcOutputPath,
    bool generateLrc = false,
    String audioFingerprint = '',
  }) async {
    _ensureInitialized();
    final cfg = config ?? _config;
    final shouldGenerateLrc = generateLrc || cfg.generateLrc;
    final cacheKey = _buildCacheKey(audioPath, cfg);

    // ── Cache check ────────────────────────────────────────
    if (cfg.cacheResults && _resultCache.containsKey(cacheKey)) {
      debugPrint('💾 Cache hit: $cacheKey');
      final cached = _resultCache[cacheKey]!;

      if (shouldGenerateLrc && cached.segments.isNotEmpty) {
        final gen =
            await _generateLrcAndDiarization(cached, audioPath, lrcOutputPath);
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

    // ── Transcribe ─────────────────────────────────────────
    try {
      SttResult result;

      if (cfg.preferredEngine == SttEngineType.whisper) {
        debugPrint('DEBUG [STT]: Using Whisper engine');
        result = await _runWhisperEngine(audioPath, cfg);
      } else {
        debugPrint('DEBUG [STT]: Using Native engine');
        result = await _runNativeEngine(audioPath, cfg);
        if (cfg.autoFallback && result.fullText.isEmpty) {
          debugPrint('⚠️ Native empty → fallback Whisper');
          result = await _runWhisperEngine(audioPath, cfg);
        }
      }

      // Gán fingerprint nếu caller cung cấp
      if (audioFingerprint.isNotEmpty && result.audioFingerprint.isEmpty) {
        result = SttResult(
          fullText: result.fullText,
          segments: result.segments,
          engineUsed: result.engineUsed,
          language: result.language,
          processingTime: result.processingTime,
          audioFingerprint: audioFingerprint,
          hasWordTimestamps: result.hasWordTimestamps,
        );
      }

      if (cfg.cacheResults) _resultCache[cacheKey] = result;

      // ── LRC + Diarization ──────────────────────────────
      if (shouldGenerateLrc && result.segments.isNotEmpty) {
        final gen =
            await _generateLrcAndDiarization(result, audioPath, lrcOutputPath);

        _emitProgress(SttFacadeStatus.ready, 1.0, 'Hoàn tất!');
        return SttTranscribeOutput(
          result: result,
          speakers: gen.speakers,
          lrcFilePath: gen.lrcPath,
          spkFilePath: gen.spkPath,
          wasLrcGenerated: gen.lrcPath != null,
          success: true,
        );
      }

      _emitProgress(SttFacadeStatus.ready, 1.0, 'Hoàn tất!');
      return SttTranscribeOutput(result: result, success: true);
    } catch (e, stack) {
      debugPrint('❌ transcribeFile error: $e\n$stack');
      _emitProgress(SttFacadeStatus.error, 0.0, 'Lỗi: $e');
      return SttTranscribeOutput.failure(e.toString());
    }
  }

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

  Future<SttTranscribeOutput> transcribeQuick(
    String audioPath, {
    String language = 'en-US',
  }) =>
      transcribeFile(
        audioPath,
        config: SttConfig.balanced,
        generateLrc: false,
      );

  Future<SttTranscribeOutput> transcribeAuto(
    String audioPath, {
    String language = 'en',
    String? lrcOutputPath,
    bool generateLrc = true,
    String audioFingerprint = '',
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
      return SttTranscribeOutput.failure('Không có model offline.');
    }

    return transcribeFile(
      audioPath,
      config: _config.copyWith(
        preferredEngine: SttEngineType.whisper,
        whisperModel: localLevel,
        language: language,
        generateLrc: generateLrc,
      ),
      lrcOutputPath: lrcOutputPath,
      generateLrc: generateLrc,
      audioFingerprint: audioFingerprint,
    );
  }

  // ── LRC + Diarization pipeline ────────────────────────────

  Future<({String? lrcPath, String? spkPath, List<SpeakerAnnotation> speakers})>
      _generateLrcAndDiarization(
    SttResult result,
    String audioPath,
    String? outputPath,
  ) async {
    const empty =
        (lrcPath: null, spkPath: null, speakers: <SpeakerAnnotation>[]);

    try {
      _emitProgress(SttFacadeStatus.generatingLrc, 0.88, 'Đang tạo LRC...');

      final appDir = await getApplicationDocumentsDirectory();
      final lrcDir = outputPath ?? '${appDir.path}/.vipsound_lrc';

      // 1. LRC chuẩn
      final lrcPath = await _lrcConverter.saveLrcFile(
        result,
        audioPath,
        outputDirectory: lrcDir,
      );
      if (lrcPath == null) return empty;

      _emitProgress(
          SttFacadeStatus.generatingLrc, 0.92, 'Phân tách người nói...');

      // 2. Diarization overlay
      final speakers = await _diarizationService.diarize(result);

      // 3. Sidecar JSON (cache render)
      String? spkPath;
      if (speakers.isNotEmpty) {
        await SpeakerSidecar.save(
          lrcPath: lrcPath,
          audioFingerprint: result.audioFingerprint,
          annotations: speakers,
        );
        spkPath = SpeakerSidecar.getSidecarPath(lrcPath);
      }

      _emitProgress(SttFacadeStatus.generatingLrc, 0.98, 'Hoàn tất!');
      return (lrcPath: lrcPath, spkPath: spkPath, speakers: speakers);
    } catch (e) {
      debugPrint('❌ _generateLrcAndDiarization: $e');
      return empty;
    }
  }

  // ── Engine runners ────────────────────────────────────────

  Future<SttResult> _runNativeEngine(String audioPath, SttConfig config) async {
    _emitProgress(
        SttFacadeStatus.processingNative, 0.1, 'Đang nhận diện giọng nói...',
        engine: SttEngineType.native);
    final result = await _nativeEngine.transcribeFile(
      audioPath,
      language: config.language,
    );
    _emitProgress(SttFacadeStatus.processingNative, 0.9, 'Hoàn tất nhận diện');
    return result;
  }

  Future<SttResult> _runWhisperEngine(
      String audioPath, SttConfig config) async {
    final level = config.whisperModel;
    final info = _modelManager.getModelInfo(level);

    if (!info.isReady) {
      throw StateError(
        'Model ${level.name} chưa sẵn sàng offline.',
      );
    }

    _emitProgress(
      SttFacadeStatus.processingWhisper,
      0.2,
      'Whisper (${level.name})...',
      engine: SttEngineType.whisper,
    );

    final result = await _whisperEngine.transcribe(
      audioPath,
      level: level,
      language: config.language,
      wordTimestamps: true,
    );

    _emitProgress(SttFacadeStatus.processingWhisper, 0.9, 'Whisper hoàn tất!');
    return result;
  }

  // ── Model management ──────────────────────────────────────

  SttModelInfo getModelInfo(WhisperModelLevel level) =>
      _modelManager.getModelInfo(level);

  Future<void> deleteModel(WhisperModelLevel level) =>
      _modelManager.deleteModel(level);

  Future<bool> importModelFromPath(
    String sourcePath, {
    WhisperModelLevel? level,
  }) {
    _ensureInitialized();
    return _modelManager.importModelFromPath(sourcePath, level: level);
  }

  // ── Live STT ──────────────────────────────────────────────

  Future<bool> startListening({String language = 'en-US'}) async {
    _ensureInitialized();
    return _nativeEngine.startListening(language: language);
  }

  Future<void> stopListening() async => _nativeEngine.stopListening();

  Stream<SttResult> get liveResultStream => _nativeEngine.resultStream;

  // ── Config ────────────────────────────────────────────────

  void updateConfig(SttConfig config) {
    _config = config;
    if (!_disposed) notifyListeners();
  }

  void clearCache() {
    _resultCache.clear();
    debugPrint('🗑️ STT cache cleared');
  }

  // ── Helpers ───────────────────────────────────────────────

  String _buildCacheKey(String audioPath, SttConfig config) =>
      '${audioPath}_${config.preferredEngine.name}_'
      '${config.whisperModel.name}_${config.language}';

  void _emitProgress(
    SttFacadeStatus status,
    double progress,
    String message, {
    SttEngineType? engine,
  }) {
    if (_disposed) return;
    _progressSubject.add(SttProgress(
      status: status,
      progress: progress.clamp(0.0, 1.0),
      message: message,
      activeEngine: engine,
    ));
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('SttServiceFacade chưa được khởi tạo.');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _nativeEngine.dispose();
    _whisperEngine.dispose();
    _modelManager.dispose();
    _progressSubject.close();
    _instance = null;
    super.dispose();
  }
}
