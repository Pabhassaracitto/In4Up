// packages/vipsound_stt/lib/stt_engine_whisper_mobile.dart
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

/// Implementation cho mobile/macOS dùng whisper_flutter_new + ffmpeg_kit
Future<SttResult> transcribeMobileImpl({
  required String audioPath,
  required WhisperModelLevel level,
  String? language,
  bool translateToEnglish = false,
  bool wordTimestamps = true,
  required SttModelManager modelManager,
  required StreamController<double> progressController,
  required Stopwatch stopwatch,
}) async {
  try {
    final whisper = Whisper(
      model: _mapWhisperModel(level),
      modelDir: modelManager.modelDirectoryPath,
    );

    progressController.add(0.3);

    final wavPath = await _ensureWavFormatMobile(audioPath);
    debugPrint('🎙️ Whisper starting: $wavPath');

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

    progressController.add(0.75);

    var parsed = _parseWhisperResult(
      transcribeResult,
      processingTime: stopwatch.elapsed,
      language: language ?? 'en',
      hasWordTimestamps: wordTimestamps,
    );

    // tiny/base đôi khi trả rỗng khi bật splitOnWord.
    // Fallback sang segment-level để ưu tiên có transcript + LRC.
    final isEmpty = parsed.fullText.trim().isEmpty || parsed.segments.isEmpty;
    if (isEmpty && wordTimestamps) {
      debugPrint('⚠️ Whisper word-level empty -> retry segment-level');
      final retryResult = await whisper.transcribe(
        transcribeRequest: TranscribeRequest(
          audio: wavPath,
          isTranslate: translateToEnglish,
          isNoTimestamps: false,
          splitOnWord: false,
          diarize: false,
          language: language ?? 'en',
        ),
      );

      parsed = _parseWhisperResult(
        retryResult,
        processingTime: stopwatch.elapsed,
        language: language ?? 'en',
        hasWordTimestamps: false,
      );
    }

    progressController.add(0.9);
    return parsed;
  } catch (e) {
    debugPrint('❌ Mobile Whisper error: $e');
    return SttResult.empty(SttEngineType.whisper);
  }
}

Future<String> _ensureWavFormatMobile(String audioPath) async {
  final tempDir = await getTemporaryDirectory();
  final outputPath = p.join(
    tempDir.path,
    'whisper_input_${DateTime.now().millisecondsSinceEpoch}.wav',
  );

  try {
    final session = await FFmpegKit.execute(
      '-y -i "$audioPath" -ar 16000 -ac 1 -c:a pcm_s16le "$outputPath"',
    );
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      return outputPath;
    }
  } catch (e) {
    debugPrint('❌ FFmpeg mobile error: $e');
  }
  return audioPath;
}

WhisperModel _mapWhisperModel(WhisperModelLevel level) {
  switch (level) {
    case WhisperModelLevel.tiny:
      return WhisperModel.tiny;
    case WhisperModelLevel.base:
      return WhisperModel.base;
    case WhisperModelLevel.small:
      return WhisperModel.small;
    case WhisperModelLevel.medium:
      return WhisperModel.medium;
    case WhisperModelLevel.large:
      return WhisperModel.largeV2;
  }
}

SttResult _parseWhisperResult(
  dynamic whisperOutput, {
  required Duration processingTime,
  required String language,
  required bool hasWordTimestamps,
}) {
  try {
    if (whisperOutput == null) return SttResult.empty(SttEngineType.whisper);

    final WhisperTranscribeResponse response =
        whisperOutput as WhisperTranscribeResponse;
    final rawSegments = response.segments;

    if (rawSegments == null || rawSegments.isEmpty) {
      return SttResult.empty(SttEngineType.whisper);
    }

    final words = <SttWord>[];
    for (final seg in rawSegments) {
      final text = seg.text.trim();
      if (text.isEmpty) continue;

      final normalizedWord =
          text.toLowerCase().replaceAll(RegExp(r"[^\p{L}\p{N}'-]", unicode: true), '');
      if (normalizedWord.isEmpty) continue;

      words.add(SttWord(
        word: normalizedWord,
        startSeconds: seg.fromTs.inMilliseconds / 1000.0,
        endSeconds: seg.toTs.inMilliseconds / 1000.0,
        confidence: 1.0,
      ));
    }

    if (words.isEmpty) return SttResult.empty(SttEngineType.whisper);

    // Group thành segments
    final segments = _groupWords(words);
    final fullText = segments.map((s) => s.text).join(' ');

    return SttResult(
      fullText: fullText,
      segments: segments,
      engineUsed: SttEngineType.whisper,
      language: language,
      processingTime: processingTime,
      hasWordTimestamps: true,
    );
  } catch (e) {
    debugPrint('❌ Parse error: $e');
    return SttResult.empty(SttEngineType.whisper);
  }
}

List<SttSegment> _groupWords(List<SttWord> words) {
  final segments = <SttSegment>[];
  List<SttWord> current = [];

  for (int i = 0; i < words.length; i++) {
    current.add(words[i]);

    bool breakHere = i == words.length - 1;
    if (!breakHere && i < words.length - 1) {
      final gap = words[i + 1].startSeconds - words[i].endSeconds;
      if (gap > 0.7) breakHere = true;
    }

    if (breakHere) {
      segments.add(SttSegment(
        id: segments.length,
        startSeconds: current.first.startSeconds,
        endSeconds: current.last.endSeconds,
        text: current.map((w) => w.word).join(' '),
        words: List.from(current),
        avgConfidence: 1.0,
      ));
      current.clear();
    }
  }
  return segments;
}
