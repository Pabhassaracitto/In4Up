//
// Facade chính - điểm vào duy nhất cho toàn bộ module STT
// Được gọi từ PlayerProvider và thay thế OfflineSTTService

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';

import 'models/stt_config.dart';
import 'models/stt_model_info.dart';
import 'models/stt_result.dart';
import 'stt_engine_native.dart';
import 'stt_engine_whisper.dart';
import 'stt_lrc_converter.dart';
import 'stt_model_manager.dart';

/// Trạng thái tổng thể của Facade
enum SttFacadeStatus {
  idle,
  initializing,
  ready,
  processingNative,
  processingWhisper,
  generatingLrc,
  error,
}

/// Sự kiện progress cho UI (dùng trong LinearProgressIndicator)
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

  // ★ FIX: error không còn tính là active
  bool get isActive {
    switch (status) {
      case SttFacadeStatus.initializing:
      case SttFacadeStatus.processingNative:
      case SttFacadeStatus.processingWhisper:
      case SttFacadeStatus.generatingLrc:
        return true;
      case SttFacadeStatus.idle:
      case SttFacadeStatus.ready:
      case SttFacadeStatus.error:
        return false;
    }
  }
}

/// Kết quả đầy đủ bao gồm cả đường dẫn LRC (nếu được tạo)
class SttTranscribeOutput {
  final SttResult result;
  final String? lrcFilePath;
  final bool wasLrcGenerated;
  final String? errorMessage;
  final bool success;

  const SttTranscribeOutput({
    required this.result,
    this.lrcFilePath,
    this.wasLrcGenerated = false,
    this.errorMessage,
    required this.success,
  });

  factory SttTranscribeOutput.failure(String error) => SttTranscribeOutput(
        result: SttResult.empty(SttEngineType.native),
        errorMessage: error,
        success: false,
      );
}

/// Facade chính của module vipsound_stt
///
/// Sử dụng:
/// ```dart
/// final stt = SttServiceFacade();
/// await stt.initialize();
///
/// // Ghi chú nhanh (Native)
/// final result = await stt.transcribeQuick(audioPath);
///
/// // Tạo tài liệu học (Whisper + LRC)
/// final output = await stt.transcribeDeep(audioPath, audioPath);
/// ```
class SttServiceFacade extends ChangeNotifier {
  static SttServiceFacade? _instance;
  factory SttServiceFacade() => _instance ??= SttServiceFacade._internal();
  SttServiceFacade._internal();

  late final SttEngineNative _nativeEngine;
  late final SttEngineWhisper _whisperEngine;
  late final SttModelManager _modelManager;
  late final SttLrcConverter _lrcConverter;

  bool _initialized = false;
  SttConfig _config = const SttConfig();

  // ★ THÊM: mutex tránh init đúp
  Future<void>? _initFuture;

  final _progressSubject =
      BehaviorSubject<SttProgress>.seeded(SttProgress.idle);
  Stream<SttProgress> get progressStream => _progressSubject.stream;
  SttProgress get currentProgress => _progressSubject.value;

  final _resultCache = <String, SttResult>{};

  // ★ FIX: bọc bằng _initFuture để không chạy 2 lần song song
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
      notifyListeners();
    } finally {
      // Reset để nếu cần re-init sau này vẫn được
      _initFuture = null;
    }
  }

  // ─── Quick Transcribe (Native) ────────────────────────────────────────────

  /// Ghi chú nhanh - dùng Native STT
  /// Không cần tải model, phản hồi tức thì
  /// Thay thế hoàn toàn OfflineSTTService.transcribe()
  Future<SttTranscribeOutput> transcribeQuick(
    String audioPath, {
    String language = 'en-US',
  }) async {
    _ensureInitialized();

    // Native STT không transcribe file trực tiếp.
    // Trả về thông báo để UI biết cần dùng microphone.
    // Tương thích ngược với OfflineSTTService (không crash)
    debugPrint('⚡ Quick transcribe (Native): Native STT cần microphone, '
        'dùng Whisper cho file: $audioPath');

    // Fallback sang Whisper Base nếu file cần transcribe
    return transcribeFile(
      audioPath,
      config: SttConfig.balanced,
      generateLrc: false,
    );
  }

  // ─── Deep Transcribe (Whisper + LRC) ─────────────────────────────────────

  /// Tạo tài liệu học tập - dùng Whisper AI + tạo LRC
  ///
  /// [audioPath]: Đường dẫn file audio
  /// [lrcSavePath]: Nơi lưu file .lrc (mặc định: cùng thư mục với audio)
  /// [level]: Cấp model Whisper
  ///
  /// Emit progress để UI hiển thị LinearProgressIndicator
  Future<SttTranscribeOutput> transcribeDeep(
    String audioPath, {
    String? lrcSavePath,
    WhisperModelLevel level = WhisperModelLevel.small,
    String language = 'en',
  }) async {
    return transcribeFile(
      audioPath,
      config: SttConfig.deepLearning.copyWith(
        whisperModel: level,
        language: language,
        generateLrc: true,
      ),
      lrcOutputPath: lrcSavePath,
    );
  }

  // ─── Core Transcribe ──────────────────────────────────────────────────────

  /// Transcribe file audio theo config
  ///
  /// Đây là method cốt lõi - xử lý toàn bộ pipeline:
  /// 1. Kiểm tra cache
  /// 2. Kiểm tra model có sẵn
  /// 3. Tải model nếu cần
  /// 4. Transcribe bằng engine phù hợp
  /// 5. Tạo LRC nếu được yêu cầu
  /// 6. Cache kết quả
  Future<SttTranscribeOutput> transcribeFile(
    String audioPath, {
    SttConfig? config,
    String? lrcOutputPath,
    bool generateLrc = false,
  }) async {
    _ensureInitialized();

    final cfg = config ?? _config;
    final shouldGenerateLrc = generateLrc || cfg.generateLrc;

    // ── Kiểm tra cache ────────────────────────────────────────────────
    final cacheKey = _buildCacheKey(audioPath, cfg);
    if (cfg.cacheResults && _resultCache.containsKey(cacheKey)) {
      debugPrint('💾 Cache hit: $cacheKey');

      final cached = _resultCache[cacheKey]!;
      String? lrcPath;
      bool lrcGenerated = false;

      if (shouldGenerateLrc && cached.segments.isNotEmpty) {
        lrcPath = await _generateAndSaveLrc(
          cached,
          audioPath,
          lrcOutputPath,
        );
        lrcGenerated = lrcPath != null;
      }

      return SttTranscribeOutput(
        result: cached,
        lrcFilePath: lrcPath,
        wasLrcGenerated: lrcGenerated,
        success: true,
      );
    }

    try {
      SttResult? result;
      String? engine = cfg.preferredEngine.name.toUpperCase();

      // ── Engine Selection ───────────────────────────────────────────
      if (cfg.preferredEngine == SttEngineType.whisper) {
        result = await _runWhisperEngine(audioPath, cfg);
      } else {
        result = await _runNativeEngine(audioPath, cfg);

        // Fallback sang Whisper nếu Native không hỗ trợ file
        if (cfg.autoFallback && (result.fullText.isEmpty)) {
          debugPrint('⚠️ Native failed/empty → fallback to Whisper');
          engine = 'WHISPER (fallback)';
          result = await _runWhisperEngine(audioPath, cfg);
        }
      }

      debugPrint('✅ Transcribe done via $engine: '
          '${result.fullText.length} chars');

      // ── Cache kết quả ─────────────────────────────────────────────
      if (cfg.cacheResults) {
        _resultCache[cacheKey] = result;
      }

      // ── Tạo LRC file ──────────────────────────────────────────────
      String? lrcPath;
      bool lrcGenerated = false;

      if (shouldGenerateLrc && result.segments.isNotEmpty) {
        lrcPath = await _generateAndSaveLrc(
          result,
          audioPath,
          lrcOutputPath,
        );
        lrcGenerated = lrcPath != null;
      }

      _emitProgress(SttFacadeStatus.ready, 1.0, 'Hoàn tất!');

      return SttTranscribeOutput(
        result: result,
        lrcFilePath: lrcPath,
        wasLrcGenerated: lrcGenerated,
        success: true,
      );
    } catch (e, stack) {
      debugPrint('❌ SttServiceFacade.transcribeFile error: $e');
      debugPrint(stack.toString());

      _emitProgress(SttFacadeStatus.error, 0.0, 'Lỗi: $e');
      return SttTranscribeOutput.failure(e.toString());
    }
  }

  // ─── Engine Runners ───────────────────────────────────────────────────────

  Future<SttResult> _runNativeEngine(
    String audioPath,
    SttConfig config,
  ) async {
    _emitProgress(
      SttFacadeStatus.processingNative,
      0.1,
      'Đang nhận diện giọng nói...',
      engine: SttEngineType.native,
    );

    final result = await _nativeEngine.transcribeFile(
      audioPath,
      language: config.language,
    );

    _emitProgress(
      SttFacadeStatus.processingNative,
      0.9,
      'Hoàn tất nhận diện',
    );
    return result;
  }

  Future<SttResult> _runWhisperEngine(
    String audioPath,
    SttConfig config,
  ) async {
    final level = config.whisperModel;
    final info = _modelManager.getModelInfo(level);

    // ★ GUARD: không cho Whisper tự download
    if (!info.isReady) {
      throw StateError(
        'Model ${level.name} chưa sẵn sàng offline. '
        'Hãy đảm bảo file model đã được copy vào assets/whisper_models/ '
        'hoặc tải xuống trước.',
      );
    }

    _emitProgress(
      SttFacadeStatus.processingWhisper,
      0.2,
      'Đang xử lý bằng Whisper (${level.name})...',
      engine: SttEngineType.whisper,
    );

    final result = await _whisperEngine.transcribe(
      audioPath,
      level: level,
      language: config.language,
      wordTimestamps: true,
    );

    _emitProgress(
      SttFacadeStatus.processingWhisper,
      0.9,
      'Whisper hoàn tất!',
    );

    return result;
  }

  /// Xoá model
  Future<void> deleteModel(WhisperModelLevel level) =>
      _modelManager.deleteModel(level);

  // ─── LRC Generation ──────────────────────────────────────────────────────

  Future<String?> _generateAndSaveLrc(
    SttResult result,
    String audioPath,
    String? outputPath,
  ) async {
    try {
      _emitProgress(
        SttFacadeStatus.generatingLrc,
        0.92,
        'Đang tạo file LRC...',
      );

      // Lưu vào thư mục ẩn của App (cùng tên với audio file)
      final appDir = await getApplicationDocumentsDirectory();
      final lrcDir = '${appDir.path}/.vipsound_lrc';

      final savedPath = await _lrcConverter.saveLrcFile(
        result,
        audioPath,
        outputDirectory: outputPath ?? lrcDir,
      );

      debugPrint('✅ LRC saved: $savedPath');
      _emitProgress(SttFacadeStatus.generatingLrc, 0.98, 'LRC đã lưu!');
      return savedPath;
    } catch (e) {
      debugPrint('❌ LRC generation failed: $e');
      return null;
    }
  }

  // ─── Model Management (thông qua Facade) ─────────────────────────────────

  /// Lấy trạng thái của model
  SttModelInfo getModelInfo(WhisperModelLevel level) =>
      _modelManager.getModelInfo(level);

  // ─── Live Listening ───────────────────────────────────────────────────────

  /// Bắt đầu lắng nghe real-time (Native)
  Future<bool> startListening({String language = 'en-US'}) async {
    _ensureInitialized();
    return _nativeEngine.startListening(language: language);
  }

  /// Dừng lắng nghe real-time
  Future<void> stopListening() async {
    await _nativeEngine.stopListening();
  }

  /// Stream kết quả live (dùng cho Shadowing mode)
  Stream<SttResult> get liveResultStream => _nativeEngine.resultStream;

  // ─── Configuration ────────────────────────────────────────────────────────

  /// Cập nhật cấu hình
  void updateConfig(SttConfig config) {
    _config = config;
    notifyListeners();
  }

  /// Xoá cache
  void clearCache() {
    _resultCache.clear();
    debugPrint('🗑️ STT result cache cleared');
  }

  // ─── Utility ─────────────────────────────────────────────────────────────

  String _buildCacheKey(String audioPath, SttConfig config) {
    return '${audioPath}_${config.preferredEngine.name}_'
        '${config.whisperModel.name}_${config.language}';
  }

  void _emitProgress(
    SttFacadeStatus status,
    double progress,
    String message, {
    SttEngineType? engine,
  }) {
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

  /// Import model từ đường dẫn ngoài
  Future<bool> importModelFromPath(
    String sourcePath, {
    WhisperModelLevel? level,
  }) {
    _ensureInitialized();
    return _modelManager.importModelFromPath(sourcePath, level: level);
  }

  /// Tự động tìm model tốt nhất hiện có để transcribe
  Future<SttTranscribeOutput> transcribeAuto(
    String audioPath, {
    String language = 'en',
    String? lrcOutputPath,
    bool generateLrc = true,
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
      _emitProgress(SttFacadeStatus.ready, 0.0, 'Không có model offline sẵn.');
      return SttTranscribeOutput.failure('Không có model offline sẵn.');
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
    );
  }

  @override
  void dispose() {
    _nativeEngine.dispose();
    _whisperEngine.dispose();
    _modelManager.dispose();
    _progressSubject.close();
    _instance = null;
    super.dispose();
  }
}

// ─── Custom Exceptions ────────────────────────────────────────────────────────

class InsufficientStorageException implements Exception {
  final int required; // MB
  final int available; // MB
  final WhisperModelLevel modelLevel;

  const InsufficientStorageException({
    required this.required,
    required this.available,
    required this.modelLevel,
  });

  @override
  String toString() =>
      'InsufficientStorageException: Cần ${required}MB để tải model '
      '${modelLevel.name}, nhưng chỉ còn ${available}MB. '
      'Hãy giải phóng bộ nhớ hoặc chọn model nhỏ hơn (Tiny/Base).';
}

class ModelDownloadException implements Exception {
  final String message;
  const ModelDownloadException(this.message);

  @override
  String toString() => 'ModelDownloadException: $message';
}
