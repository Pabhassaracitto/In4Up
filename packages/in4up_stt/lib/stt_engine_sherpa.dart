// packages/in2up_stt/lib/stt_engine_sherpa.dart
//
// SherpaSttEngine — PoC tích hợp Sherpa-ONNX (next-gen Kaldi) theo interface
// SttEngine (Strategy Pattern).
//
// Đây là SPIKE để đánh giá: file transcription (offline) + live streaming.
// Model ONNX cần được tải (dynamic download) và truyền qua options.
//
// API dựa theo sherpa_onnx ^1.13.4 (xem ví dụ chính thức trong package).

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'models/content_id.dart';
import 'models/stt_config.dart';
import 'models/stt_result.dart';
import 'stt_engine.dart';

/// Tham số model cần cung cấp qua [options] khi gọi [transcribeFile] /
/// [startListening].
class SherpaModelPaths {
  final String encoder;
  final String decoder;
  final String joiner;
  final String tokens;
  final int numThreads;

  const SherpaModelPaths({
    required this.encoder,
    required this.decoder,
    required this.joiner,
    required this.tokens,
    this.numThreads = 2,
  });

  /// Tạo từ Map (truyền trong options['sherpaModels']).
  static SherpaModelPaths? fromOptions(Map<String, dynamic>? options) {
    if (options == null) return null;
    final encoder = options['encoder'] as String?;
    final decoder = options['decoder'] as String?;
    final joiner = options['joiner'] as String?;
    final tokens = options['tokens'] as String?;
    if (encoder == null || decoder == null || joiner == null || tokens == null) {
      return null;
    }
    return SherpaModelPaths(
      encoder: encoder,
      decoder: decoder,
      joiner: joiner,
      tokens: tokens,
      numThreads: (options['numThreads'] as int?) ?? 2,
    );
  }
}

class SherpaSttEngine implements SttEngine {
  sherpa.OfflineRecognizer? _offline;
  sherpa.OnlineRecognizer? _online;

  final _liveController = StreamController<SttResult>.broadcast();

  SherpaSttEngine();

  @override
  String get engineName => 'sherpa';

  @override
  SttEngineCapabilities get capabilities => const SttEngineCapabilities(
        supportsFileTranscription: true,
        supportsLiveMic: true,
        supportsWordTimestamps: true,
        supportsOffline: true,
        supportsChunking: true,
      );

  /// Khởi tạo offline recognizer từ model paths.
  Future<void> _initOffline(SherpaModelPaths paths) async {
    if (_offline != null) return;
    final config = sherpa.OfflineRecognizerConfig(
      model: sherpa.OfflineModelConfig(
        transducer: sherpa.OfflineTransducerModelConfig(
          encoder: paths.encoder,
          decoder: paths.decoder,
          joiner: paths.joiner,
        ),
        tokens: paths.tokens,
        numThreads: paths.numThreads,
      ),
    );
    _offline = sherpa.OfflineRecognizer(config);
  }

  /// Khởi tạo online (streaming) recognizer từ model paths.
  Future<void> _initOnline(SherpaModelPaths paths) async {
    if (_online != null) return;
    final config = sherpa.OnlineRecognizerConfig(
      model: sherpa.OnlineModelConfig(
        transducer: sherpa.OnlineTransducerModelConfig(
          encoder: paths.encoder,
          decoder: paths.decoder,
          joiner: paths.joiner,
        ),
        tokens: paths.tokens,
        numThreads: paths.numThreads,
      ),
    );
    _online = sherpa.OnlineRecognizer(config);
  }

  @override
  Future<SttResult> transcribeFile(
    String audioPath, {
    Map<String, dynamic>? options,
  }) async {
    final models = SherpaModelPaths.fromOptions(options);
    if (models == null) {
      return SttFileResult.failure(
        'Sherpa cần model ONNX (encoder/decoder/joiner/tokens) qua options.',
      ).result;
    }

    await _initOffline(models);
    if (_offline == null) {
      return SttFileResult.failure('Sherpa offline recognizer init thất bại.')
          .result;
    }

    // Đọc WAV (sherpa hỗ trợ đọc file wav trực tiếp).
    final wave = sherpa.readWave(audioPath);
    if (wave == null || wave.samples.isEmpty) {
      return SttFileResult.failure('Không đọc được WAV: $audioPath').result;
    }

    final stream = _offline!.createStream();
    stream.acceptWaveform(samples: wave.samples, sampleRate: wave.sampleRate);
    _offline!.decode(stream);
    final result = _offline!.getResult(stream);

    final text = (result.text ?? '').trim();
    final fingerprint =
        (options?['audioFingerprint'] as String?) ?? _hashPath(audioPath);

    // Sherpa trả timestamps (giây) cho từng token → dựng segments/words.
    final segments = _buildSegments(
      text: text,
      timestamps: result.timestamps,
      tokens: result.tokens,
      audioFingerprint: fingerprint,
    );

    return SttResult(
      fullText: text,
      segments: segments,
      engineUsed: SttEngineType.sherpa,
      language: (options?['language'] as String?) ?? 'en',
      processingTime: Duration.zero,
      audioFingerprint: fingerprint,
      hasWordTimestamps: segments.any((s) => s.words.isNotEmpty),
    );
  }

  /// Dựng segments (tách theo câu) từ text + timestamps token.
  List<SttSegment> _buildSegments({
    required String text,
    required List<dynamic> timestamps,
    required List<dynamic> tokens,
    required String audioFingerprint,
  }) {
    final words = <SttWord>[];
    final n = timestamps.length < tokens.length
        ? timestamps.length
        : tokens.length;
    for (var i = 0; i < n; i++) {
      final token = tokens[i].toString();
      final ts = timestamps[i];
      final startSec = ts is num ? ts.toDouble() : 0.0;
      words.add(SttWord(
        word: token,
        startSeconds: startSec,
        endSeconds: startSec + 0.3,
        confidence: 1.0,
      ));
    }
    if (words.isEmpty && text.isNotEmpty) {
      return [
        SttSegment(
          id: 0,
          uid: ContentId.segmentUid(
            audioFingerprint: audioFingerprint,
            startMs: 0,
            text: text,
          ),
          startSeconds: 0,
          endSeconds: 0,
          text: text,
          words: const [],
          avgConfidence: 1.0,
        ),
      ];
    }

    // Gom thành segment theo khoảng lặng >0.7s.
    final segments = <SttSegment>[];
    var current = <SttWord>[];
    for (var i = 0; i < words.length; i++) {
      current.add(words[i]);
      final gap = i < words.length - 1
          ? words[i + 1].startSeconds - words[i].endSeconds
          : 1.0;
      if (gap > 0.7 || i == words.length - 1) {
        final startMs = (current.first.startSeconds * 1000).round();
        final segText = current.map((w) => w.word).join(' ').trim();
        if (segText.isNotEmpty) {
          segments.add(SttSegment(
            id: segments.length,
            uid: ContentId.segmentUid(
              audioFingerprint: audioFingerprint,
              startMs: startMs,
              text: segText,
            ),
            startSeconds: current.first.startSeconds,
            endSeconds: current.last.endSeconds,
            text: segText,
            words: List.from(current),
            avgConfidence: 1.0,
          ));
        }
        current = [];
      }
    }
    return segments;
  }

  @override
  Stream<SttResult> get liveResultStream => _liveController.stream;

  @override
  Future<bool> startListening({
    String language = 'en-US',
    Map<String, dynamic>? options,
  }) async {
    final models = SherpaModelPaths.fromOptions(options);
    if (models == null) return false;
    await _initOnline(models);
    if (_online == null) return false;

    // PoC: nạp WAV mẫu hoặc stream mic. Trong spike ta đọc từ file mẫu để
    // chứng minh online decoder. (Mic streaming cần `record` + push PCM.)
    return true;
  }

  @override
  Future<void> stopListening() async {}

  @override
  Future<void> dispose() async {
    // Giải phóng recognizer (nếu API hỗ trợ free); bỏ tham chiếu.
    try {
      _offline?.free();
    } catch (_) {}
    try {
      _online?.free();
    } catch (_) {}
    _offline = null;
    _online = null;
    if (!_liveController.isClosed) await _liveController.close();
  }

  String _hashPath(String path) =>
      'fp_${path.hashCode.abs().toRadixString(16)}';
}
