// packages/vipsound_stt/lib/stt_engine_whisper.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'models/stt_model_info.dart';
import 'models/stt_result.dart';
import 'stt_model_manager.dart';

// ★ IMPORT TRỰC TIẾP (không dùng conditional)
import 'platform/wav_reader.dart';
import 'platform/whisper_ffi_windows.dart';

// Mobile packages - CHỈ import khi cần (trong _transcribeMobile)
// KHÔNG import ở đây để tránh lỗi Windows build

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

      // Mobile - throw error hoặc implement riêng
      throw UnimplementedError(
        'Mobile Whisper chưa được implement. '
        'Sử dụng whisper_flutter_new trực tiếp.',
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
      return SttResult.empty(SttEngineType.whisper);
    }

    _progressController.add(0.3);

    // 2. Read PCM samples
    final samples = await WavReader.readPcmFloat32(wavPath);
    if (samples == null || samples.isEmpty) {
      debugPrint('❌ WAV read failed');
      return SttResult.empty(SttEngineType.whisper);
    }

    _progressController.add(0.4);

    // 3. Get model path
    final modelPath = _modelManager.getModelPath(level);
    if (modelPath == null) {
      throw StateError('Model ${level.name} not ready');
    }

    debugPrint('🎯 Whisper FFI: model=$modelPath, samples=${samples.length}');

    // 4. Run Whisper
    final whisper = WhisperFfiWindows();
    if (!whisper.load()) {
      debugPrint('❌ Failed to load whisper.dll');
      return SttResult.empty(SttEngineType.whisper);
    }

    final ffiResult = await whisper.transcribe(
      modelPath: modelPath,
      pcmSamples: samples,
      language: language,
    );

    _progressController.add(0.95);

    if (ffiResult.hasError) {
      debugPrint('❌ Whisper error: ${ffiResult.error}');
      return SttResult.empty(SttEngineType.whisper);
    }

    return _convertFfiResult(
      ffiResult,
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
        runInShell: false,
      );

      if (result.exitCode == 0) {
        debugPrint('✅ WAV: $outputPath');
        return outputPath;
      } else {
        debugPrint('❌ ffmpeg error: ${result.stderr}');
        return null;
      }
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
    final segments = <SttSegment>[];

    for (int i = 0; i < ffiResult.segments.length; i++) {
      final seg = ffiResult.segments[i];
      final words = seg.text
          .split(' ')
          .map((w) {
            final cleaned = w.trim().toLowerCase();
            if (cleaned.isEmpty) return null;
            return SttWord(
              word: cleaned,
              startSeconds: seg.startMs / 1000.0,
              endSeconds: seg.endMs / 1000.0,
              confidence: 1.0,
            );
          })
          .whereType<SttWord>()
          .toList();

      if (words.isEmpty) continue;

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

  void dispose() {
    _progressController.close();
  }
}
