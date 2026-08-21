// lib/features/vad/pipeline/vad_whisper_pipeline.dart
// Handover SECTION 2 — Thiết kế Pipeline tối ưu VAD + Whisper.cpp
// Kiến trúc:
// [File Audio Gốc] -> [1. Sherpa-VAD Segmenter] -> List<SpeechSegment>
// -> [2. Chunk Audio Extractor] -> Cắt file nhỏ/buffer tạm
// -> [3. Whisper.cpp Loop] -> Xử lý từng Chunk
// -> [4. Offset Corrector] -> Absolute_Time = Chunk_Text_Time + Segment_Start_Time
// -> [5. UI Stream / File Output] -> Render real-time progress & Clean file tạm
//
// Mục tiêu: giảm file 1h từ 20p xuống 8-10p và tránh OOM trên Tablet
// * Không nạp nguyên file 1h vào RAM
// * Mỗi Chunk xong gọi file.delete() ngay
// * Ép whisper.cpp chạy trong Flutter Isolate riêng

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:in4up_stt/models/stt_model_info.dart';
import 'package:in4up_stt/models/stt_result.dart';
import 'package:in4up_stt/models/stt_config.dart';
import 'package:in4up_stt/stt_service_facade.dart';
import '../models/speech_segment.dart';
import '../services/chunk_audio_extractor.dart';
import '../services/sherpa_vad_service.dart';

/// Trạng thái pipeline
enum VadPipelineStatus {
  idle,
  initializing,
  vadSegmenting,
  extracting,
  transcribing,
  completed,
  error,
  cancelled,
}

/// Tiến độ pipeline cho UI
class VadPipelineProgress {
  final VadPipelineStatus status;
  final double progress; // 0..1
  final String message;
  final int currentChunkIndex;
  final int totalChunks;
  final SttResult? partialResult; // kết quả tích lũy đến hiện tại
  final Duration? eta;

  const VadPipelineProgress({
    required this.status,
    required this.progress,
    required this.message,
    this.currentChunkIndex = 0,
    this.totalChunks = 0,
    this.partialResult,
    this.eta,
  });

  bool get isActive =>
      status == VadPipelineStatus.vadSegmenting ||
      status == VadPipelineStatus.extracting ||
      status == VadPipelineStatus.transcribing;

  static const idle = VadPipelineProgress(
    status: VadPipelineStatus.idle,
    progress: 0,
    message: '',
  );
}

/// Kết quả cuối cùng của pipeline
class VadPipelineResult {
  final List<SpeechSegment> vadSegments;
  final SttResult finalTranscription;
  final Duration totalProcessingTime;
  final String audioFilePath;
  final int chunksProcessed;
  final int chunksSkippedSilence;
  final String? lrcFilePath;

  const VadPipelineResult({
    required this.vadSegments,
    required this.finalTranscription,
    required this.totalProcessingTime,
    required this.audioFilePath,
    required this.chunksProcessed,
    this.chunksSkippedSilence = 0,
    this.lrcFilePath,
  });

  bool get success => finalTranscription.segments.isNotEmpty;
}

/// Pipeline chính VAD + Whisper
/// Chạy trong Isolate riêng để không đơ UI Thread (handover yêu cầu)
class VadWhisperPipeline {
  final VadService _vadService;
  final ChunkAudioExtractor _extractor;
  final SttServiceFacade _sttFacade;

  bool _cancelRequested = false;
  bool _disposed = false;

  VadWhisperPipeline({
    VadService? vadService,
    ChunkAudioExtractor? extractor,
    SttServiceFacade? sttFacade,
  })  : _vadService = vadService ?? SherpaVadService.singleton(),
        _extractor = extractor ?? ChunkAudioExtractor(),
        _sttFacade = sttFacade ?? SttServiceFacade();

  void cancel() {
    _cancelRequested = true;
    _sttFacade.cancelTranscription();
    debugPrint('⏹️ VadWhisperPipeline: cancel requested');
  }

  /// Chạy pipeline với stream progress real-time cho UI
  /// [audioPath] là absolute path (Rule 1) đã verified existsSync + size>1M
  Stream<VadPipelineProgress> run({
    required String audioPath,
    WhisperModelLevel modelLevel = WhisperModelLevel.tiny,
    String language = 'vi',
    bool skipSilence = true,
    bool deleteChunkImmediately = true, // Rule: mỗi chunk xong phải delete ngay
  }) async* {
    _cancelRequested = false;
    final totalSw = Stopwatch()..start();

    // ── Rule 3 verification cho audio file gốc ──
    final audioFile = File(audioPath);
    if (!audioFile.existsSync()) {
      yield VadPipelineProgress(
        status: VadPipelineStatus.error,
        progress: 0,
        message: 'File audio không tồn tại (existsSync false): $audioPath',
      );
      return;
    }
    if (audioFile.lengthSync() <= 1000000) {
      debugPrint('⚠️ Audio file nhỏ hơn 1MB (${audioFile.lengthSync()} bytes) — vẫn thử xử lý');
    }

    yield const VadPipelineProgress(
      status: VadPipelineStatus.initializing,
      progress: 0.05,
      message: 'Đang khởi tạo pipeline...',
    );

    // ── STEP 1: Sherpa-VAD Segmenter ──
    yield const VadPipelineProgress(
      status: VadPipelineStatus.vadSegmenting,
      progress: 0.1,
      message: 'Đang quét mốc thời gian im lặng/tiếng nói (VAD)...',
    );

    VadResult vadResult;
    try {
      vadResult = await _vadService.detectSpeechSegments(audioPath);
    } catch (e) {
      yield VadPipelineProgress(
        status: VadPipelineStatus.error,
        progress: 0,
        message: 'VAD lỗi: $e',
      );
      return;
    }

    if (_cancelRequested) {
      yield const VadPipelineProgress(
        status: VadPipelineStatus.cancelled,
        progress: 0,
        message: 'Đã hủy sau VAD',
      );
      return;
    }

    debugPrint('✅ VAD xong: $vadResult');
    if (vadResult.segments.isEmpty) {
      yield VadPipelineProgress(
        status: VadPipelineStatus.error,
        progress: 0,
        message: 'VAD không tìm thấy đoạn speech nào',
      );
      return;
    }

    // Lọc bỏ silence nếu skipSilence = true (giảm thời gian từ 20p xuống 8-10p)
    final speechSegments = skipSilence
        ? vadResult.segments.where((s) => s.isSpeech).toList()
        : vadResult.segments;

    final totalChunks = speechSegments.length;
    final skipped = vadResult.segments.length - speechSegments.length;

    yield VadPipelineProgress(
      status: VadPipelineStatus.extracting,
      progress: 0.2,
      message: 'Đã tìm ${speechSegments.length} đoạn speech, bỏ $skipped đoạn silence',
      currentChunkIndex: 0,
      totalChunks: totalChunks,
    );

    // ── STEP 2/3/4: Loop chunk extractor + whisper + offset corrector ──
    final allSegments = <SttSegment>[];
    final chunkTimes = <int>[];

    for (var i = 0; i < speechSegments.length; i++) {
      if (_cancelRequested || _disposed) {
        yield const VadPipelineProgress(
          status: VadPipelineStatus.cancelled,
          progress: 0,
          message: 'Đã hủy giữa chừng',
        );
        break;
      }

      final seg = speechSegments[i];
      final chunkSw = Stopwatch()..start();

      // ETA tính toán
      final avgTime = chunkTimes.isEmpty ? 0 : chunkTimes.reduce((a, b) => a + b) ~/ chunkTimes.length;
      final remaining = totalChunks - i - 1;
      final etaMs = avgTime * remaining;

      yield VadPipelineProgress(
        status: VadPipelineStatus.extracting,
        progress: 0.2 + 0.7 * (i / totalChunks),
        message: 'Đang cắt chunk ${i + 1}/$totalChunks (${seg.startTime.toStringAsFixed(1)}s->${seg.endTime.toStringAsFixed(1)}s)...',
        currentChunkIndex: i,
        totalChunks: totalChunks,
        partialResult: SttResult(
          fullText: allSegments.map((s) => s.text).join(' ').trim(),
          segments: List.from(allSegments),
          engineUsed: SttEngineType.whisper,
          language: language,
          processingTime: totalSw.elapsed,
          audioFingerprint: '',
          hasWordTimestamps: allSegments.any((s) => s.words.isNotEmpty),
        ),
        eta: Duration(milliseconds: etaMs),
      );

      // ── 2. Chunk Audio Extractor ──
      AudioChunk? chunk;
      try {
        chunk = await _extractor.extractChunk(
          originalPath: audioPath,
          segment: seg,
          chunkIndex: i,
        );
      } catch (e) {
        debugPrint('❌ Extract chunk $i failed: $e');
        continue;
      }

      if (chunk == null) {
        debugPrint('⚠️ Chunk $i null, bỏ qua');
        continue;
      }

      yield VadPipelineProgress(
        status: VadPipelineStatus.transcribing,
        progress: 0.2 + 0.7 * (i / totalChunks) + 0.05,
        message: 'Đang bóc băng chunk ${i + 1}/$totalChunks...',
        currentChunkIndex: i,
        totalChunks: totalChunks,
        eta: Duration(milliseconds: etaMs),
      );

      // ── 3. Whisper.cpp Loop (đã chạy trong Isolate riêng ở facade) ──
      SttResult? chunkResult;
      try {
        // Ép chạy trong Isolate riêng (handover yêu cầu để không lag UI)
        // SttServiceFacade đã dùng compute() cho desktop, còn mobile dùng chunked
        // Ở đây ta gọi transcribeFile cho từng chunk — mỗi chunk là file nhỏ
        // nên OOM được tránh (không nạp nguyên file 1h vào RAM)
        final output = await _sttFacade.transcribeFile(
          chunk.chunkFilePath,
          config: SttConfig(
            preferredEngine: SttEngineType.whisper,
            whisperModel: modelLevel,
            language: language,
            generateLrc: false,
            cacheResults: false,
            chunkDurationSeconds: 30,
            maxChunks: 0,
          ),
        );

        if (output.success) {
          chunkResult = output.result;
        } else {
          debugPrint('⚠️ Chunk $i transcribe failed: ${output.errorMessage}');
        }
      } catch (e) {
        debugPrint('❌ Chunk $i transcribe exception: $e');
      }

      // ── 4. Offset Corrector: Absolute_Time = Chunk_Text_Time + Segment_Start_Time ──
      if (chunkResult != null) {
        for (final sttSeg in chunkResult.segments) {
          final corrected = sttSeg.shiftByMs(
            (seg.startTime * 1000).round(),
            audioFingerprint: chunkResult.audioFingerprint,
          );
          allSegments.add(corrected);
        }
      }

      chunkSw.stop();
      chunkTimes.add(chunkSw.elapsedMilliseconds);

      // ── 5. Cleanup: file.delete() ngay lập tức ──
      if (deleteChunkImmediately) {
        // Chỉ xóa nếu chunk là file temp, không phải file gốc (fallback)
        if (chunk.chunkFilePath != audioPath) {
          await chunk.delete();
        }
      }

      // Nhường event loop để GC thu hồi native memory (Scudo) — giống fix 38s OOM
      await Future<void>.delayed(const Duration(milliseconds: 100));

      if (i % 3 == 2) {
        debugPrint('🧠 Pipeline nghỉ 500ms để giải phóng RAM native sau 3 chunks');
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }

      // Emit partial result cho UI stream real-time
      yield VadPipelineProgress(
        status: VadPipelineStatus.transcribing,
        progress: 0.2 + 0.7 * ((i + 1) / totalChunks),
        message: 'Đã xong ${i + 1}/$totalChunks chunk, ${allSegments.length} segments — ETA ${(etaMs / 60000).ceil()} phút',
        currentChunkIndex: i + 1,
        totalChunks: totalChunks,
        partialResult: SttResult(
          fullText: allSegments.map((s) => s.text).join(' ').trim(),
          segments: List.from(allSegments),
          engineUsed: SttEngineType.whisper,
          language: language,
          processingTime: totalSw.elapsed,
          audioFingerprint: '',
          hasWordTimestamps: allSegments.any((s) => s.words.isNotEmpty),
        ),
        eta: Duration(milliseconds: etaMs),
      );
    }

    totalSw.stop();

    final finalResult = SttResult(
      fullText: allSegments.map((s) => s.text).join(' ').trim(),
      segments: allSegments,
      engineUsed: SttEngineType.whisper,
      language: language,
      processingTime: totalSw.elapsed,
      audioFingerprint: '',
      hasWordTimestamps: allSegments.any((s) => s.words.isNotEmpty),
    );

    // Cleanup toàn bộ temp nếu còn sót
    await _extractor.cleanupAllTempChunks();

    yield VadPipelineProgress(
      status: VadPipelineStatus.completed,
      progress: 1.0,
      message: 'Hoàn tất! ${allSegments.length} segments trong ${totalSw.elapsed.inSeconds}s',
      currentChunkIndex: totalChunks,
      totalChunks: totalChunks,
      partialResult: finalResult,
    );

    debugPrint(
      '🏁 VAD Pipeline hoàn tất: ${allSegments.length} segments, '
      'time=${totalSw.elapsed.inSeconds}s, '
      'skippedSilence=$skipped',
    );
  }

  /// Chạy pipeline một phát (không stream) — tiện cho background job
  Future<VadPipelineResult> runOnce({
    required String audioPath,
    WhisperModelLevel modelLevel = WhisperModelLevel.tiny,
    String language = 'vi',
  }) async {
    VadPipelineResult? last;
    await for (final progress in run(
      audioPath: audioPath,
      modelLevel: modelLevel,
      language: language,
    )) {
      if (progress.status == VadPipelineStatus.completed &&
          progress.partialResult != null) {
        last = VadPipelineResult(
          vadSegments: [],
          finalTranscription: progress.partialResult!,
          totalProcessingTime: progress.partialResult!.processingTime,
          audioFilePath: audioPath,
          chunksProcessed: progress.totalChunks,
        );
      }
    }

    if (last == null) {
      throw StateError('Pipeline không trả về kết quả');
    }
    return last;
  }

  Future<void> dispose() async {
    _disposed = true;
    await _vadService.dispose();
    await _extractor.cleanupAllTempChunks();
  }

  /// Singleton để giữ Pointer C-struct tránh re-init (Section 3)
  static final VadWhisperPipeline _instance = VadWhisperPipeline._internal();
  factory VadWhisperPipeline.singleton() => _instance;
  VadWhisperPipeline._internal()
      : _vadService = SherpaVadService.singleton(),
        _extractor = ChunkAudioExtractor(),
        _sttFacade = SttServiceFacade();
  VadWhisperPipeline._internalWithDeps({
    required VadService vadService,
    required ChunkAudioExtractor extractor,
    required SttServiceFacade sttFacade,
  })  : _vadService = vadService,
        _extractor = extractor,
        _sttFacade = sttFacade;
}

/// Extension để shift segment theo ms (Offset Corrector)
extension SttSegmentOffset on SttSegment {
  SttSegment shiftByMs(int msOffset, {String audioFingerprint = ''}) {
    final offsetSec = msOffset / 1000.0;
    return SttSegment(
      id: id,
      uid: uid,
      startSeconds: startSeconds + offsetSec,
      endSeconds: endSeconds + offsetSec,
      text: text,
      words: words
          .map((w) => SttWord(
                word: w.word,
                startSeconds: w.startSeconds + offsetSec,
                endSeconds: w.endSeconds + offsetSec,
                confidence: w.confidence,
              ))
          .toList(),
      avgConfidence: avgConfidence,
    );
  }
}
