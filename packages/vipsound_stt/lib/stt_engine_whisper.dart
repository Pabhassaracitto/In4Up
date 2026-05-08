// packages/vipsound_stt/lib/stt_engine_whisper.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'models/stt_model_info.dart';
import 'models/stt_result.dart';
// ★ THÊM: Import platform files
import 'platform/wav_reader.dart';
import 'platform/whisper_cli_windows.dart'; // NEW: Import Whisper CLI for Windows
import 'platform/whisper_ffi_windows.dart';
// Conditional import for mobile implementation
import 'stt_engine_whisper_mobile.dart'
    if (dart.library.windows) 'stt_engine_whisper_mobile_stub.dart';
import 'stt_model_manager.dart';

/// Engine Whisper AI - chạy offline trên thiết bị
/// Ưu tiên dùng cho "Deep Learning" - tạo tài liệu học tập chuẩn xác
class SttEngineWhisper {
  final SttModelManager _modelManager;

  final _progressController = StreamController<double>.broadcast();
  Stream<double> get progressStream => _progressController.stream;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  SttEngineWhisper({SttModelManager? modelManager})
      : _modelManager = modelManager ?? SttModelManager();

  // ─── Public API ──────────────────────────────────────────────────────────

  Future<SttResult> transcribe(
    String audioPath, {
    WhisperModelLevel level = WhisperModelLevel.base,
    String? language,
    bool translateToEnglish = false,
    bool wordTimestamps = true,
  }) async {
    if (_isProcessing) {
      throw StateError('Whisper engine đang xử lý file khác.');
    }

    final audioFile = File(audioPath);
    if (!await audioFile.exists()) {
      throw FileSystemException('File audio không tồn tại', audioPath);
    }

    _isProcessing = true;
    _progressController.add(0.0);
    final stopwatch = Stopwatch()..start();

    try {
      // ── Windows: dùng direct FFI ──────────────────────────────────
      if (Platform.isWindows) {
        return await _transcribeWindows(
          audioPath,
          level: level,
          language: language ?? 'en',
          stopwatch: stopwatch,
        );
      }

      // ── Mobile/macOS: dùng whisper_flutter_new ────────────────────
      return await _transcribeMobile(
        audioPath,
        level: level,
        language: language,
        translateToEnglish: translateToEnglish,
        wordTimestamps: wordTimestamps,
        stopwatch: stopwatch,
      );
    } finally {
      _isProcessing = false;
    }
  }

  // ─── Windows Implementation ───────────────────────────────────────────────

  Future<SttResult> _transcribeWindows(
    String audioPath, {
    required WhisperModelLevel level,
    required String language,
    required Stopwatch stopwatch,
  }) async {
    _progressController.add(0.1);

    // 1. Convert to WAV
    final wavPath = await _ensureWavFormatWindows(audioPath);
    if (wavPath == null) {
      debugPrint('❌ WAV conversion failed');
      return SttResult.empty(SttEngineType.whisper,
          errorMessage: 'WAV conversion failed');
    }

    _progressController.add(0.3);

    // 2. Read PCM samples
    final samples = await WavReader.readPcmFloat32(wavPath);
    if (samples == null || samples.isEmpty) {
      debugPrint('❌ WAV read failed');
      return SttResult.empty(SttEngineType.whisper,
          errorMessage: 'WAV read failed or empty');
    }

    _progressController.add(0.4);

    // 3. Get model path
    final modelPath = _modelManager.getModelPath(level);
    if (modelPath == null) {
      debugPrint('❌ Model ${level.name} not ready');
      return SttResult.empty(SttEngineType.whisper,
          errorMessage: 'Model ${level.name} not ready');
    }

    debugPrint('🎯 Whisper FFI: model=$modelPath, samples=${samples.length}');

    // 4. Run Whisper CLI
    final cliResult = await WhisperCliWindows.transcribe(
      wavPath: wavPath,
      modelPath: modelPath,
      language: language,
    );

    _progressController.add(0.95);

    if (cliResult.hasError) {
      debugPrint('❌ Whisper error: ${cliResult.error}');
      return SttResult.empty(
        SttEngineType.whisper,
        errorMessage: cliResult.error,
      );
    }

    return _convertFfiResult(
      cliResult,
      language: language,
      processingTime: stopwatch.elapsed,
    );
  }

  /// Convert audio sang WAV 16kHz mono trên Windows bằng ffmpeg.exe
  Future<String?> _ensureWavFormatWindows(String audioPath) async {
    final tempDir = await getTemporaryDirectory();
    final outputPath = p.join(
      tempDir.path,
      'whisper_${DateTime.now().millisecondsSinceEpoch}.wav',
    );

    final ffmpegPath = await _findFfmpegWindows();
    if (ffmpegPath == null) {
      debugPrint('❌ ffmpeg.exe not found');
      return null;
    }

    try {
      debugPrint('🔄 Converting: $audioPath → WAV');

      final result = await Process.run(
        ffmpegPath,
        [
          '-y',
          '-i',
          audioPath,
          '-ar',
          '16000',
          '-ac',
          '1',
          '-c:a',
          'pcm_s16le',
          outputPath
        ],
      );

      if (result.exitCode == 0) return outputPath;
      debugPrint('❌ ffmpeg exit ${result.exitCode}: ${result.stderr}');
      return null;
    } catch (e) {
      debugPrint('❌ ffmpeg process error: $e');
      return null;
    }
  }

  static String? _cachedFfmpegPath;
  Future<String?> _findFfmpegWindows() async {
    if (_cachedFfmpegPath != null) return _cachedFfmpegPath;

    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = [
      '$exeDir/ffmpeg.exe',
      'ffmpeg',
      'C:/ffmpeg/bin/ffmpeg.exe',
    ];

    for (final path in candidates) {
      try {
        final result = await Process.run(path, ['-version'], runInShell: true);
        if (result.exitCode == 0) {
          _cachedFfmpegPath = path;
          debugPrint('✅ ffmpeg: $path');
          return path;
        }
      } catch (_) {}
    }
    return null;
  }

  SttResult _convertFfiResult(
    WhisperFfiResult ffiResult, {
    required String language,
    required Duration processingTime,
  }) {
    // Convert WhisperFfiResult → SttResult
    final segments = <SttSegment>[];

    for (int i = 0; i < ffiResult.segments.length; i++) {
      final seg = ffiResult.segments[i];
      final words = seg.text
          .split(' ')
          .map((w) => SttWord(
                word: w,
                startSeconds: seg.startMs / 1000.0,
                endSeconds: seg.endMs / 1000.0,
                confidence: 1.0,
              ))
          .toList();

      segments.add(SttSegment(
        id: i,
        startSeconds: seg.startMs / 1000.0,
        endSeconds: seg.endMs / 1000.0,
        text: seg.text,
        words: words,
        avgConfidence: 1.0,
      ));
    }

    return SttResult(
      fullText: ffiResult.fullText,
      segments: segments,
      engineUsed: SttEngineType.whisper,
      language: language,
      processingTime: processingTime,
      hasWordTimestamps: true,
    );
  }

  // ─── Mobile Implementation ────────────────────────────────────────────────

  Future<SttResult> _transcribeMobile(
    String audioPath, {
    required WhisperModelLevel level,
    String? language,
    bool translateToEnglish = false,
    bool wordTimestamps = true,
    required Stopwatch stopwatch,
  }) async {
    // Mobile implementation stub (giữ nguyên hoặc tách file)
    // Implement mobile logic here or import from separate file
    return SttResult.empty(SttEngineType.whisper);
    // Call the actual mobile implementation or its stub
    return transcribeMobileImpl(
      audioPath: audioPath,
      level: level,
      language: language,
      translateToEnglish: translateToEnglish,
      wordTimestamps: wordTimestamps,
      modelManager: _modelManager,
      progressController: _progressController,
      stopwatch: stopwatch,
    );
  }

  void dispose() {
    _progressController.close();
  }
}
