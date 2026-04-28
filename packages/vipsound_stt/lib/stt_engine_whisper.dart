// packages/vipsound_stt/lib/stt_engine_whisper.dart

import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

import 'models/stt_model_info.dart';
import 'models/stt_result.dart';
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
      throw StateError('Whisper engine đang xử lý file khác. Vui lòng đợi.');
    }

    final audioFile = File(audioPath);
    if (!await audioFile.exists()) {
      throw FileSystemException('File audio không tồn tại', audioPath);
    }

    final modelPath = _modelManager.getModelPath(level);
    if (modelPath == null) {
      throw StateError('Model ${level.name} chưa được tải về. '
          'Gọi SttModelManager().downloadModel() trước.');
    }

    _isProcessing = true;
    _progressController.add(0.0);
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('🎙️ Whisper transcribing: $audioPath');
      debugPrint('   Model: ${level.name} ($modelPath)');
      debugPrint('   Language: ${language ?? 'auto'}');

      final wavPath = await _ensureWavFormat(audioPath);
      _progressController.add(0.1);

      // Kiểm tra file wav sau khi convert có hợp lệ không
      if (!await File(wavPath).exists() || await File(wavPath).length() < 100) {
        throw Exception('File audio chuẩn hóa không hợp lệ hoặc quá nhỏ.');
      }

      // ── FIX 1: Dùng WhisperModel.base thay vì WhisperModel.custom ────
      // whisper_flutter_new không có constant 'custom'
      // Model path được truyền qua modelPath field của TranscribeRequest
      final whisper = Whisper(model: WhisperModel.base);

      _progressController.add(0.15);

      // ── FIX 2: language là String? → dùng ?? '' để tránh null ────────
      final transcribeResult = await whisper.transcribe(
        transcribeRequest: TranscribeRequest(
          audio: wavPath,
          isTranslate: translateToEnglish,
          isNoTimestamps: false,
          splitOnWord: wordTimestamps,
          diarize: false,
          language: language ?? 'en',
        ),
      );

      _progressController.add(0.85);

      final result = _parseWhisperResult(
        transcribeResult,
        engineType: SttEngineType.whisper,
        processingTime: stopwatch.elapsed,
        language: language ?? 'en',
        hasWordTimestamps: wordTimestamps,
      );

      if (wavPath != audioPath) {
        await File(wavPath).delete().catchError((_) => File(wavPath));
      }

      _progressController.add(1.0);
      stopwatch.stop();

      debugPrint('✅ Whisper done: ${result.segments.length} segments, '
          '${result.allWords.length} words, ${stopwatch.elapsed.inSeconds}s');

      return result;
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ Whisper transcribe error: $e');
      rethrow;
    } finally {
      _isProcessing = false;
    }
  }

  // ─── Private helpers ──────────────────────────────────────────────────────

  /// Đảm bảo audio đúng định dạng Whisper yêu cầu: WAV PCM 16-bit, 16kHz, Mono.
  /// Nếu không đúng, sử dụng lệnh shell hoặc thư viện để convert.
  Future<String> _ensureWavFormat(String audioPath) async {
    final extension = p.extension(audioPath).toLowerCase();
    final tempDir = await getTemporaryDirectory();
    final outputPath = p.join(
      tempDir.path,
      'whisper_input_${DateTime.now().millisecondsSinceEpoch}.wav',
    );

    debugPrint('🔄 Chuẩn hóa audio cho Whisper: $extension -> 16kHz WAV Mono');

    try {
      // Lệnh FFmpeg ép file về: wav, pcm 16bit, 16000Hz, mono (1 channel)
      final session = await FFmpegKit.execute(
        '-y -i "$audioPath" -ar 16000 -ac 1 -c:a pcm_s16le "$outputPath"',
      );
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        debugPrint('✅ Chuẩn hóa audio thành công: $outputPath');
        return outputPath;
      } else {
        final logs = await session.getLogs();
        debugPrint('❌ FFmpeg lỗi: ${logs.lastOrNull?.getMessage()}');
        return audioPath;
      }
    } catch (e) {
      debugPrint('❌ Lỗi xử lý FFmpeg: $e');
      return audioPath;
    }
  }

  SttResult _parseWhisperResult(
    dynamic whisperOutput, {
    required SttEngineType engineType,
    required Duration processingTime,
    required String language,
    required bool hasWordTimestamps,
  }) {
    try {
      if (whisperOutput == null) {
        return SttResult.empty(engineType);
      }

      final segments = <SttSegment>[];
      final fullTextBuffer = StringBuffer();
      final rawSegments = _extractSegments(whisperOutput);

      for (int i = 0; i < rawSegments.length; i++) {
        final rawSeg = rawSegments[i];
        final segText = _extractField<String>(rawSeg, ['text', 'content'], '');
        final startSec =
            _extractField<double>(rawSeg, ['start', 'startTime', 't0'], 0.0);
        final endSec =
            _extractField<double>(rawSeg, ['end', 'endTime', 't1'], 0.0);

        final words = <SttWord>[];
        if (hasWordTimestamps) {
          final rawWords = _extractWordTimestamps(rawSeg, segText, startSec);
          words.addAll(rawWords);
        }

        final confidence = _calculateSegmentConfidence(rawSeg, words);

        segments.add(SttSegment(
          id: i,
          startSeconds: startSec,
          endSeconds: endSec,
          text: segText.trim(),
          words: words,
          avgConfidence: confidence,
        ));

        if (fullTextBuffer.isNotEmpty) fullTextBuffer.write(' ');
        fullTextBuffer.write(segText.trim());
      }

      return SttResult(
        fullText: fullTextBuffer.toString(),
        segments: segments,
        engineUsed: engineType,
        language: language,
        processingTime: processingTime,
        hasWordTimestamps: hasWordTimestamps,
      );
    } catch (e) {
      debugPrint('❌ Error parsing Whisper result: $e');
      final rawText = whisperOutput?.toString() ?? '';
      return SttResult(
        fullText: _cleanRawWhisperText(rawText),
        segments: [],
        engineUsed: engineType,
        language: language,
        processingTime: processingTime,
        hasWordTimestamps: false,
      );
    }
  }

  List<dynamic> _extractSegments(dynamic output) {
    if (output is List) return output;
    if (output is Map) {
      return output['segments'] as List? ?? output['results'] as List? ?? [];
    }
    if (output is String) {
      return [
        {'text': output, 'start': 0.0, 'end': 0.0}
      ];
    }
    return [];
  }

  List<SttWord> _extractWordTimestamps(
    dynamic segment,
    String fallbackText,
    double segStartSec,
  ) {
    final words = <SttWord>[];
    final rawWords = (segment is Map)
        ? (segment['words'] as List? ?? segment['tokens'] as List?)
        : null;

    if (rawWords != null && rawWords.isNotEmpty) {
      for (final rawWord in rawWords) {
        if (rawWord is Map) {
          final word = rawWord['word']?.toString().trim() ?? '';
          if (word.isEmpty || word.startsWith('[')) continue;

          final start =
              _toDouble(rawWord['start'] ?? rawWord['t0']) ?? segStartSec;
          final end =
              _toDouble(rawWord['end'] ?? rawWord['t1']) ?? (start + 0.3);
          final confidence =
              _toDouble(rawWord['probability'] ?? rawWord['confidence']) ?? 0.9;

          words.add(SttWord(
            word: _cleanWord(word),
            startSeconds: start,
            endSeconds: end,
            confidence: confidence,
          ));
        }
      }
    }

    if (words.isEmpty && fallbackText.isNotEmpty) {
      return _estimateWordTimestamps(
        fallbackText,
        segStartSec,
        segStartSec + _estimateDuration(fallbackText),
      );
    }

    return words;
  }

  List<SttWord> _estimateWordTimestamps(
    String text,
    double startSec,
    double endSec,
  ) {
    final rawWords = text.trim().split(RegExp(r'\s+'));
    if (rawWords.isEmpty) return [];

    final totalDuration = endSec - startSec;
    final totalChars = text.replaceAll(' ', '').length;
    final words = <SttWord>[];
    double cursor = startSec;

    for (final word in rawWords) {
      if (word.isEmpty) continue;
      final fraction = totalChars > 0 ? word.length / totalChars : 0.0;
      final wordDuration = totalDuration * fraction;

      words.add(SttWord(
        word: _cleanWord(word),
        startSeconds: cursor,
        endSeconds: cursor + wordDuration,
        confidence: 0.7,
      ));
      cursor += wordDuration;
    }

    return words;
  }

  double _estimateDuration(String text) {
    final wordCount = text.split(RegExp(r'\s+')).length;
    return wordCount / 150.0 * 60.0;
  }

  double _calculateSegmentConfidence(dynamic segment, List<SttWord> words) {
    if (words.isNotEmpty) {
      return words.map((w) => w.confidence).reduce((a, b) => a + b) /
          words.length;
    }
    if (segment is Map) {
      return _toDouble(segment['confidence'] ?? segment['avg_logprob']) ?? 0.8;
    }
    return 0.8;
  }

  T _extractField<T>(dynamic obj, List<String> keys, T defaultVal) {
    if (obj is! Map) return defaultVal;
    for (final key in keys) {
      if (obj.containsKey(key) && obj[key] != null) {
        try {
          if (T == double) {
            return (_toDouble(obj[key]) ?? defaultVal as double) as T;
          }
          return obj[key] as T;
        } catch (_) {}
      }
    }
    return defaultVal;
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String _cleanWord(String word) {
    return word.replaceAll(RegExp(r"[^\w\'-]"), '').toLowerCase();
  }

  String _cleanRawWhisperText(String raw) {
    return raw
        .replaceAll(
            RegExp(r'\[\d{2}:\d{2}\.\d{3} --> \d{2}:\d{2}\.\d{3}\]\s*'), '')
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .trim();
  }

  void dispose() {
    _progressController.close();
  }
}
