// lib/features/vad/pipeline/vad_pipeline_integration.dart
// Tích hợp VAD pipeline vào PlayerSttMixin / SttServiceFacade
// Cho phép file 1h giảm từ 20p xuống 8-10p nhờ loại bỏ silence

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in4up_stt/models/stt_model_info.dart';
import 'package:in4up_stt/models/stt_result.dart';
import 'package:in4up_stt/stt_service_facade.dart';

import '../models/speech_segment.dart';
import 'vad_whisper_pipeline.dart';

/// Wrapper để PlayerSttMixin có thể dùng VAD pipeline mà không cần đổi API lớn
class VadPipelineIntegration {
  final VadWhisperPipeline _pipeline;

  VadPipelineIntegration({VadWhisperPipeline? pipeline})
      : _pipeline = pipeline ?? VadWhisperPipeline.singleton();

  /// Chạy pipeline VAD + Whisper với progress callback
  /// Trả về SttTranscribeOutput để tương thích với code cũ
  Future<SttTranscribeOutput> transcribeWithVad({
    required String audioPath,
    WhisperModelLevel modelLevel = WhisperModelLevel.tiny,
    // 'auto' = Whisper tự nhận diện. Default cũ 'vi' làm caller quên truyền
    // language bị decode sai ngôn ngữ (ra chữ Latin cho audio Hindi).
    String language = 'auto',
    bool skipSilence = true,
    void Function(VadPipelineProgress progress)? onProgress,
    Future<void> Function(SttResult partial)? onPartialResult,
    // true = modelLevel do người dùng chọn → giữ nguyên, không tự hạ tiny.
    bool honorModelLevel = false,
  }) async {
    SttResult? finalResult;
    VadResult? vadResult;

    await for (final prog in _pipeline.run(
      audioPath: audioPath,
      modelLevel: modelLevel,
      language: language,
      skipSilence: skipSilence,
      deleteChunkImmediately: true,
      honorModelLevel: honorModelLevel,
    )) {
      onProgress?.call(prog);

      if (prog.partialResult != null) {
        await onPartialResult?.call(prog.partialResult!);
        finalResult = prog.partialResult;
      }

      if (prog.status == VadPipelineStatus.completed) {
        finalResult = prog.partialResult;
        break;
      }

      if (prog.status == VadPipelineStatus.error) {
        throw StateError(prog.message);
      }

      if (prog.status == VadPipelineStatus.cancelled) {
        throw StateError('Transcription cancelled');
      }
    }

    if (finalResult == null) {
      throw StateError('VAD pipeline không trả về kết quả');
    }

    // Tạo LRC file từ finalResult (dùng SttLrcConverter trong facade)
    // Để đơn giản, ta không tạo LRC ở đây mà trả về result để facade tạo sau
    return SttTranscribeOutput(
      result: finalResult,
      success: finalResult.segments.isNotEmpty,
    );
  }

  void cancel() => _pipeline.cancel();

  Future<void> dispose() async => await _pipeline.dispose();
}
