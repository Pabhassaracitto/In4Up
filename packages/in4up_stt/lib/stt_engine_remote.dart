// packages/in4up_stt/lib/stt_engine_remote.dart
//
// SttEngineRemote — STT file qua API OpenAI-compatible (Groq whisper-
// large-v3, hoặc Speaches/whisper-server tự host) — WP2 (API-003).
//
// Kiến trúc (tiếp nối WP0/API-001 — "1 client OpenAI-compatible duy nhất,
// KHÔNG tạo client thứ 2"):
//   AiProviderStore (in4up_ai) — chọn provider cho AiRouteCapability.sttFile
//     theo routing (offlineFirst/onlineFirst/offlineOnly) đã cấu hình ở
//     màn "Server & API".
//   OpenAiCompatClient.transcribeAudio() (in4up_ai) — gọi HTTP multipart
//     thật, stream file từ đĩa.
//   SttEngineRemote (file này) — cắt file dài theo VAD, gọi client theo
//     từng chunk, offset timestamp, map JSON → SttSegment.
//
// Nguyên tắc đã chốt:
//  * Live mic GIỮ on-device (SttEngineNative) — remote CHỈ transcribe file
//    (capabilities.supportsLiveMic = false).
//  * File dài cắt theo VAD (SherpaVadCore có sẵn trong package) thành
//    chunk ~10-15 phút (giới hạn upload ~25MB); payload luôn là WAV 16k
//    mono qua AudioConverter — KHÔNG upload file gốc lossless. VAD lỗi
//    hoặc chưa có model → fallback lưới thời gian cố định (vẫn đúng, chỉ
//    không né được ranh giới câu).
//  * Stream file từ đĩa vào multipart (OpenAiCompatClient dùng
//    http.MultipartFile.fromPath) — KHÔNG load cả file vào RAM.
//  * Single-flight: 1 job remote tại 1 thời điểm (SttRemoteSlot, mẫu
//    HyMtSlot) — request kế tiếp nhận SttRemoteFailure(busy) ngay.
//  * KHÔNG fake word timestamps (nguyên tắc MeetilyAdapter).
//  * Mất mạng giữa chừng → dừng sạch, lỗi có mã cấu trúc — KHÔNG treo
//    progress; facade fallback whisper on-device được ngay (autoFallback).

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in4up_ai/in4up_ai.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'models/stt_result.dart';
import 'sherpa_model_manager.dart';
import 'stt_engine.dart';
import 'stt_remote_chunk_planner.dart';
import 'stt_remote_error_mapper.dart';
import 'stt_remote_errors.dart';
import 'stt_remote_response_parser.dart';
import 'stt_remote_slot.dart';
import 'utils/audio_converter.dart';
import 'vad/sherpa_vad_core.dart';

/// Tiến độ 1 chunk remote — truyền qua `options['onChunkProgress']` của
/// [SttEngineRemote.transcribeFile].
typedef SttRemoteChunkCallback = void Function(
  int chunkIndex,
  int chunkCount,
  SttResult partial,
);

class SttEngineRemote implements SttEngine {
  SttEngineRemote({
    AiProviderStore? providerStore,
    OpenAiCompatClient Function(AiProviderConfig)? clientFactory,
  })  : _providerStore = providerStore ?? AiProviderStore.instance,
        _clientFactory = clientFactory ?? _defaultClientFactory;

  static OpenAiCompatClient _defaultClientFactory(AiProviderConfig config) =>
      OpenAiCompatClient(baseUrl: config.baseUrl, apiKey: config.apiKey);

  /// Single-flight DÙNG CHUNG toàn app — chỉ 1 job STT API tại 1 thời điểm
  /// (giống HyMtSlot cho Hy-MT). Job STT có thể chạy nhiều phút nên
  /// maxWait ngắn: caller kế tiếp báo "busy" gần như ngay, không bị chặn
  /// chờ lâu.
  static final SttRemoteSlot _slot =
      SttRemoteSlot(maxWait: const Duration(seconds: 2));

  final AiProviderStore _providerStore;
  final OpenAiCompatClient Function(AiProviderConfig) _clientFactory;

  @override
  String get engineName => 'remote';

  @override
  SttEngineCapabilities get capabilities => const SttEngineCapabilities(
        supportsFileTranscription: true,
        supportsLiveMic: false, // quyết định đã chốt: live mic GIỮ on-device
        supportsWordTimestamps: false, // KHÔNG fake — xem stt_remote_response_parser
        supportsOffline: false,
        supportsChunking: true,
      );

  @override
  Future<void> initialize() async {
    await _providerStore.ensureLoaded();
  }

  /// Provider hiện tại có thể dùng cho STT file không (đã cấu hình + routing
  /// không phải offlineOnly). Facade dùng để quyết định có route sang
  /// remote hay không TRƯỚC khi chạy — tránh phải bắt exception cho luồng
  /// bình thường.
  Future<bool> get isAvailable async {
    await _providerStore.ensureLoaded();
    return _blockedReason() == null;
  }

  @override
  Future<SttResult> transcribeFile(
    String audioPath, {
    Map<String, dynamic>? options,
  }) async {
    await _providerStore.ensureLoaded();

    final blocked = _blockedReason();
    if (blocked != null) throw blocked;

    final provider =
        _providerStore.resolveProvider(AiRouteCapability.sttFile)!;
    final model = provider.sttModel!; // supports() đảm bảo != null/rỗng

    final language = options?['language'] as String?;
    final audioFingerprint = options?['audioFingerprint'] as String? ?? '';
    final onChunkProgress =
        options?['onChunkProgress'] as SttRemoteChunkCallback?;
    final shouldCancel = options?['shouldCancel'] as bool Function()?;

    final gotSlot = await _slot.acquire();
    if (!gotSlot) {
      throw const SttRemoteFailure(
        SttRemoteErrorCode.busy,
        'Đang có 1 job STT API khác chạy — thử lại sau ít phút.',
      );
    }

    final sw = Stopwatch()..start();
    final client = _clientFactory(provider);
    try {
      final windows = await _planWindows(audioPath);
      final allSegments = <SttSegment>[];

      for (var i = 0; i < windows.length; i++) {
        if (shouldCancel?.call() ?? false) {
          throw const SttRemoteFailure(
            SttRemoteErrorCode.cancelled,
            'Đã hủy transcribe API giữa chừng.',
          );
        }

        final window = windows[i];
        final chunkPath = await _cutChunk(audioPath, window, i);
        try {
          final json = await _requestTranscription(
            client,
            chunkPath: chunkPath,
            model: model,
            language: language,
          );
          final segments = SttRemoteResponseParser.parseSegments(
            json,
            offsetMs: window.startMs,
            audioFingerprint: audioFingerprint,
            idOffset: allSegments.length,
          );
          allSegments.addAll(segments);
        } finally {
          await _safeDelete(chunkPath);
        }

        onChunkProgress?.call(
          i,
          windows.length,
          _buildPartial(allSegments, language ?? 'auto', audioFingerprint),
        );
      }

      sw.stop();
      return SttResult(
        fullText: allSegments.map((s) => s.text).join(' ').trim(),
        segments: allSegments,
        engineUsed: SttEngineType.remote,
        language: language ?? 'auto',
        processingTime: sw.elapsed,
        audioFingerprint: audioFingerprint,
        hasWordTimestamps: false, // ★ KHÔNG fake — xem doc capabilities
      );
    } finally {
      _slot.release();
    }
  }

  // ── Guard ────────────────────────────────────────────────────────────

  SttRemoteFailure? _blockedReason() {
    if (_providerStore.routing.modeOf(AiRouteCapability.sttFile) ==
        AiRouteMode.offlineOnly) {
      return const SttRemoteFailure(
        SttRemoteErrorCode.offlineOnly,
        'Chế độ offline-only đang bật cho STT — không dùng API.',
      );
    }
    final provider =
        _providerStore.resolveProvider(AiRouteCapability.sttFile);
    if (provider == null) {
      return const SttRemoteFailure(
        SttRemoteErrorCode.notConfigured,
        'Chưa cấu hình provider STT API (Groq/Speaches...). '
        'Vào Cài đặt → Server & API để thêm, hoặc dùng Whisper offline.',
      );
    }
    return null;
  }

  // ── Chunk planning (VAD) ─────────────────────────────────────────────

  Future<List<SttChunkWindow>> _planWindows(String audioPath) async {
    final totalMs = await AudioConverter.probeDurationMs(audioPath);
    if (totalMs == null || totalMs <= 0) {
      throw const SttRemoteFailure(
        SttRemoteErrorCode.chunkingFailed,
        'Không xác định được thời lượng file — không thể chia chunk để gửi API.',
      );
    }
    if (totalMs <= SttRemoteChunkPlanner.maxChunkMs) {
      return <SttChunkWindow>[SttChunkWindow(0, totalMs)];
    }

    var speech = const <SttSpeechSpan>[];
    final vadModelPath = await _resolveVadModelPath();
    if (vadModelPath != null) {
      String? wavForVad;
      SherpaVadCore? core;
      try {
        wavForVad = await AudioConverter.convertToWhisperCompatible(audioPath);
        if (wavForVad != null) {
          core = SherpaVadCore(modelPath: vadModelPath);
          final segs = await core.detectAsync(wavForVad);
          speech = segs
              .map((s) => SttSpeechSpan(
                    (s.startTime * 1000).round(),
                    (s.endTime * 1000).round(),
                  ))
              .toList();
        }
      } catch (e) {
        debugPrint(
            '[SttEngineRemote] VAD detect lỗi, fallback lưới cố định: $e');
      } finally {
        core?.dispose();
        if (wavForVad != null) {
          await AudioConverter.cleanupConvertedFile(wavForVad);
        }
      }
    }

    return SttRemoteChunkPlanner.plan(totalMs: totalMs, speechSegments: speech);
  }

  /// Model Silero VAD đã tải sẵn cho các tính năng VAD khác trong app
  /// (auto-TOC...). Không có model → trả null, caller fallback lưới cố
  /// định (vẫn đúng — chỉ không né được ranh giới câu).
  Future<String?> _resolveVadModelPath() async {
    try {
      Directory base;
      try {
        base = await getApplicationDocumentsDirectory();
      } catch (_) {
        base = await getApplicationSupportDirectory();
      }
      final path = p.join(
        base.path,
        SherpaModelManager.vadFolderName,
        SherpaModelManager.vadFileName,
      );
      final file = File(path);
      if (file.existsSync() &&
          file.lengthSync() >= SherpaModelManager.vadMinBytes) {
        return path;
      }
    } catch (_) {}
    return null;
  }

  Future<String> _cutChunk(
    String audioPath,
    SttChunkWindow window,
    int index,
  ) async {
    final dir = Directory.systemTemp.path;
    final base =
        AudioConverter.sanitizeFileName(p.basenameWithoutExtension(audioPath));
    final outPath = p.join(
      dir,
      '${base}_remote_chunk_${index}_${DateTime.now().millisecondsSinceEpoch}.wav',
    );
    final ok = await AudioConverter.cutSegment(
      inputPath: audioPath,
      startSeconds: window.startMs / 1000.0,
      durationSeconds: (window.endMs - window.startMs) / 1000.0,
      outputPath: outPath,
    );
    if (!ok) {
      throw SttRemoteFailure(
        SttRemoteErrorCode.chunkingFailed,
        'Không cắt được đoạn ${window.startMs}-${window.endMs}ms từ file gốc.',
      );
    }
    return outPath;
  }

  Future<void> _safeDelete(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  // ── HTTP ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _requestTranscription(
    OpenAiCompatClient client, {
    required String chunkPath,
    required String model,
    String? language,
  }) async {
    try {
      return await client.transcribeAudio(
        audioFilePath: chunkPath,
        model: model,
        language: language,
      );
    } on AiApiException catch (e) {
      throw SttRemoteErrorMapper.fromApiException(e);
    }
  }

  SttResult _buildPartial(
    List<SttSegment> segments,
    String language,
    String audioFingerprint,
  ) {
    return SttResult(
      fullText: segments.map((s) => s.text).join(' ').trim(),
      segments: List<SttSegment>.from(segments),
      engineUsed: SttEngineType.remote,
      language: language,
      processingTime: Duration.zero,
      audioFingerprint: audioFingerprint,
      hasWordTimestamps: false,
    );
  }
}
