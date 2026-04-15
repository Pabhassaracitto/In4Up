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
  final double progress; // 0.0 - 1.0
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

  bool get isActive =>
      status != SttFacadeStatus.idle && status != SttFacadeStatus.ready;
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
  // ─── Singleton ──────────────────────────────────────────────────────────
  static SttServiceFacade? _instance;
  factory SttServiceFacade() => _instance ??= SttServiceFacade._internal();
  SttServiceFacade._internal();

  // ─── Dependencies ────────────────────────────────────────────────────────
  late final SttEngineNative _nativeEngine;
  late final SttEngineWhisper _whisperEngine;
  late final SttModelManager _modelManager;
  late final SttLrcConverter _lrcConverter;

  // ─── State ───────────────────────────────────────────────────────────────
  bool _initialized = false;
  SttConfig _config = const SttConfig();

  final _progressSubject =
      BehaviorSubject<SttProgress>.seeded(SttProgress.idle);
  Stream<SttProgress> get progressStream => _progressSubject.stream;
  SttProgress get currentProgress => _progressSubject.value;

  /// Cache kết quả transcribe (path → SttResult)
  final _resultCache = <String, SttResult>{};

  // ─── Initialization ───────────────────────────────────────────────────────

  Future<void> initialize({SttConfig? config}) async {
    if (_initialized) return;

    _emitProgress(SttFacadeStatus.initializing, 0.0, 'Đang khởi tạo...');

    _config = config ?? const SttConfig();
    _nativeEngine = SttEngineNative();
    _whisperEngine = SttEngineWhisper();
    _modelManager = SttModelManager();
    _lrcConverter = SttLrcConverter();

    // Khởi tạo model manager
    await _modelManager.initialize();
    _emitProgress(SttFacadeStatus.initializing, 0.5, 'Kiểm tra model...');

    // Khởi tạo native engine (không throw nếu thất bại)
    await _nativeEngine.initialize().catchError((e) {
      debugPrint('⚠️ Native STT init failed (non-fatal): $e');
    });

    _initialized = true;
    _emitProgress(SttFacadeStatus.ready, 1.0, 'Sẵn sàng');
    debugPrint('✅ SttServiceFacade initialized');
    notifyListeners();
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
      return SttTranscribeOutput(
        result: _resultCache[cacheKey]!,
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

    // ── Kiểm tra & tải model ──────────────────────────────────────
    if (!_modelManager.isModelReady(level)) {
      _emitProgress(
        SttFacadeStatus.processingWhisper,
        0.0,
        'Đang kiểm tra model ${level.name}...',
      );

      // Kiểm tra dung lượng đặc biệt cho model Small
      if (level == WhisperModelLevel.small) {
        final freeMB = await _modelManager.getFreeSpaceMB();
        if (freeMB < level.requiredFreeSpaceMB) {
          throw InsufficientStorageException(
            required: level.requiredFreeSpaceMB,
            available: freeMB,
            modelLevel: level,
          );
        }
      }

      _emitProgress(
        SttFacadeStatus.processingWhisper,
        0.05,
        'Đang tải model ${level.name} (${level.sizeInMB}MB)...',
      );

      // Theo dõi progress download
      final downloadSub = _modelManager.watchModel(level).listen((info) {
        if (info.isDownloading) {
          _emitProgress(
            SttFacadeStatus.processingWhisper,
            info.downloadProgress * 0.4, // 0-40% cho download
            'Đang tải model: '
            '${(info.downloadProgress * 100).toStringAsFixed(0)}%',
          );
        }
      });

      final downloaded = await _modelManager.downloadModel(level);
      await downloadSub.cancel();

      if (!downloaded) {
        throw ModelDownloadException('Không thể tải model ${level.name}');
      }
    }

    _emitProgress(
      SttFacadeStatus.processingWhisper,
      0.45,
      'Model đã sẵn sàng, đang phân tích...',
      engine: SttEngineType.whisper,
    );

    // ── Theo dõi progress Whisper transcribe ─────────────────────
    final whisperSub = _whisperEngine.progressStream.listen((p) {
      // Map 0.45 → 0.90 cho giai đoạn transcribe
      final mappedProgress = 0.45 + p * 0.45;
      _emitProgress(
        SttFacadeStatus.processingWhisper,
        mappedProgress,
        p < 0.5 ? 'Đang phân tích âm thanh...' : 'Đang tạo văn bản...',
        engine: SttEngineType.whisper,
      );
    });

    final result = await _whisperEngine.transcribe(
      audioPath,
      level: level,
      language: config.language == 'en-US' ? 'en' : config.language,
      wordTimestamps: true,
    );

    await whisperSub.cancel();

    _emitProgress(
      SttFacadeStatus.processingWhisper,
      0.9,
      'Whisper hoàn tất!',
    );

    return result;
  }

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
      final appDir = await getApplicationSupportDirectory();
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

  /// Lắng nghe trạng thái model
  Stream<SttModelInfo> watchModel(WhisperModelLevel level) =>
      _modelManager.watchModel(level);

  /// Tải model thủ công (dùng cho settings screen)
  Future<bool> downloadModel(WhisperModelLevel level) =>
      _modelManager.downloadModel(level);

  /// Xoá model
  Future<void> deleteModel(WhisperModelLevel level) =>
      _modelManager.deleteModel(level);

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
      throw StateError('SttServiceFacade chưa được khởi tạo. '
          'Gọi initialize() trong main() hoặc trước khi dùng.');
    }
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
