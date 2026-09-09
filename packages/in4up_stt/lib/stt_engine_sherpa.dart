// packages/in4up_stt/lib/stt_engine_sherpa.dart
//
// SherpaSttEngine — Tích hợp Sherpa-ONNX (next-gen Kaldi / Zipformer)
// theo interface SttEngine (Strategy Pattern).
//
// WP4 (SHERPA-WP4-01 / PLAN-023):
// - VI profile (asr-vi-30M-int8): Simulated streaming via OfflineRecognizer + Silero VAD.
// - EN profile (asr-en-20M-streaming-int8): True live streaming via OnlineRecognizer.
// - File transcription: OfflineRecognizer.
// - Nhận luồng PCM 16kHz mono (16-bit little endian) trực tiếp từ App / AudioRecorder.
// - KHÔNG phụ thuộc trực tiếp vào package `record` trong `in4up_stt` (giữ package độc lập).

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'models/content_id.dart';
import 'models/stt_config.dart';
import 'models/stt_result.dart';
import 'sherpa_bindings.dart';
import 'sherpa_model_manager.dart';
import 'stt_engine.dart';
import 'vad/sherpa_vad_core.dart';

/// Tham số model cần cung cấp khi gọi [transcribeFile] / [startListening] / [startLive].
class SherpaModelPaths {
  final String encoder;
  final String decoder;
  final String joiner;
  final String tokens;
  final int numThreads;
  final bool isStreaming;

  const SherpaModelPaths({
    required this.encoder,
    required this.decoder,
    required this.joiner,
    required this.tokens,
    this.numThreads = 2,
    this.isStreaming = false,
  });

  /// Tạo từ Map (truyền trong options['sherpaModels'] hoặc options).
  static SherpaModelPaths? fromOptions(Map<String, dynamic>? options) {
    if (options == null) return null;
    final map = options['sherpaModels'] is Map<String, dynamic>
        ? options['sherpaModels'] as Map<String, dynamic>
        : options;

    final encoder = map['encoder'] as String?;
    final decoder = map['decoder'] as String?;
    final joiner = map['joiner'] as String?;
    final tokens = map['tokens'] as String?;
    if (encoder == null || decoder == null || joiner == null || tokens == null) {
      return null;
    }
    return SherpaModelPaths(
      encoder: encoder,
      decoder: decoder,
      joiner: joiner,
      tokens: tokens,
      numThreads: (map['numThreads'] as int?) ?? 2,
      isStreaming: (map['isStreaming'] as bool?) ?? false,
    );
  }
}

/// Helper chuyển đổi PCM 16-bit little-endian thành Float32List [-1.0, 1.0].
Float32List pcm16ToFloat32(List<int> bytes) {
  final uint8List = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  final sampleCount = uint8List.length ~/ 2;
  if (sampleCount == 0) return Float32List(0);
  final byteData = ByteData.sublistView(uint8List);
  final floats = Float32List(sampleCount);
  for (var i = 0; i < sampleCount; i++) {
    final int16 = byteData.getInt16(i * 2, Endian.little);
    floats[i] = int16 / 32768.0;
  }
  return floats;
}

class SherpaSttEngine implements SttEngine {
  sherpa.OfflineRecognizer? _offline;
  sherpa.OnlineRecognizer? _online;
  sherpa.OnlineStream? _onlineStream;
  sherpa.VoiceActivityDetector? _vad;

  final _liveController = StreamController<SttResult>.broadcast();
  StreamSubscription? _pcmSubscription;

  bool _isListening = false;
  String _currentLanguage = 'en';
  String? _lastError;
  String _lastEnPartialText = '';

  // Dùng cho VI simulated streaming
  final List<double> _viSpeechSamples = [];
  final List<double> _vadRemainderSamples = [];
  int _lastViPartialSamplesCount = 0;

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

  bool get isListening => _isListening;
  String? get lastError => _lastError;

  @override
  Future<void> initialize() async {
    ensureSherpaBindings();
  }

  /// Khởi tạo offline recognizer từ model paths.
  Future<void> _initOffline(SherpaModelPaths paths) async {
    if (_offline != null) return;
    ensureSherpaBindings();
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
    ensureSherpaBindings();
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

  /// Khởi tạo Silero VAD detector.
  Future<void> _initVad(String vadPath) async {
    if (_vad != null) return;
    ensureSherpaBindings();
    final config = sherpa.VadModelConfig(
      sileroVad: sherpa.SileroVadModelConfig(
        model: vadPath,
        threshold: 0.5,
        minSilenceDuration: 0.6,
        minSpeechDuration: 0.25,
        maxSpeechDuration: 15.0,
        windowSize: SherpaVadCore.windowSize,
      ),
      sampleRate: SherpaVadCore.sampleRate,
      numThreads: 2,
      debug: kDebugMode,
    );
    _vad = sherpa.VoiceActivityDetector(
      config: config,
      bufferSizeInSeconds: 24,
    );
  }

  @override
  Future<SttResult> transcribeFile(
    String audioPath, {
    Map<String, dynamic>? options,
  }) async {
    var models = SherpaModelPaths.fromOptions(options);
    final lang = (options?['language'] as String?) ?? 'en';

    if (models == null) {
      models = SherpaModelManager().getAsrModelPaths(lang);
    }

    if (models == null) {
      return SttFileResult.failure(
        'Sherpa cần model Zipformer ONNX (encoder/decoder/joiner/tokens). '
        'Hãy mở Quản lý Model AI để tải/import model.',
      ).result;
    }

    await _initOffline(models);
    if (_offline == null) {
      return SttFileResult.failure('Sherpa offline recognizer init thất bại.')
          .result;
    }

    // Đọc WAV (sherpa hỗ trợ đọc file wav 16kHz trực tiếp).
    final wave = sherpa.readWave(audioPath);
    if (wave == null || wave.samples.isEmpty) {
      return SttFileResult.failure('Không đọc được WAV: $audioPath').result;
    }

    final stream = _offline!.createStream();
    try {
      stream.acceptWaveform(samples: wave.samples, sampleRate: wave.sampleRate);
      _offline!.decode(stream);
      final result = _offline!.getResult(stream);

      final text = (result.text ?? '').trim();
      final fingerprint =
          (options?['audioFingerprint'] as String?) ?? _hashPath(audioPath);

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
        language: lang,
        processingTime: Duration.zero,
        audioFingerprint: fingerprint,
        hasWordTimestamps: segments.any((s) => s.words.isNotEmpty),
        isFinal: true,
      );
    } finally {
      stream.free();
    }
  }

  /// Bắt đầu phiên live STT nhận trực tiếp luồng PCM bytes (16-bit 16kHz mono).
  Future<bool> startLive({
    required String language,
    required Stream<List<int>> pcmStream,
    SherpaModelPaths? modelPaths,
    String? vadModelPath,
  }) async {
    await stopListening();
    _currentLanguage = language;
    _lastError = null;

    final isVi = language.toLowerCase().startsWith('vi');
    final isEn = language.toLowerCase().startsWith('en');

    var paths = modelPaths ?? SherpaModelManager().getAsrModelPaths(language);
    if (paths == null) {
      _lastError =
          'Chưa có model Zipformer cho $language. Hãy mở Quản lý Model AI để tải/import model.';
      debugPrint('⚠️ SherpaSttEngine: $_lastError');
      return false;
    }

    if (isVi) {
      // VI: OfflineRecognizer + Silero VAD simulated streaming
      final vadPath = vadModelPath ??
          SherpaModelManager().vadInfo.localPath ??
          (await _resolveDefaultVadPath());

      if (vadPath == null || !File(vadPath).existsSync()) {
        _lastError =
            'Chưa có model Silero VAD (cần cho live STT tiếng Việt). Mở Quản lý Model AI để tải VAD.';
        debugPrint('⚠️ SherpaSttEngine: $_lastError');
        return false;
      }

      try {
        await _initOffline(paths);
        await _initVad(vadPath);
        _viSpeechSamples.clear();
        _vadRemainderSamples.clear();
        _lastViPartialSamplesCount = 0;
        _vad?.clear();
      } catch (e) {
        _lastError = 'Khởi tạo Sherpa VI STT thất bại: $e';
        debugPrint('❌ SherpaSttEngine VI init error: $e');
        return false;
      }
    } else if (isEn || paths.isStreaming) {
      // EN / Streaming: OnlineRecognizer
      try {
        await _initOnline(paths);
        _onlineStream?.free();
        _onlineStream = _online!.createStream();
        _lastEnPartialText = '';
      } catch (e) {
        _lastError = 'Khởi tạo Sherpa EN STT thất bại: $e';
        debugPrint('❌ SherpaSttEngine EN init error: $e');
        return false;
      }
    } else {
      // Các ngôn ngữ khác chưa có model
      _lastError =
          'Ngôn ngữ $language chưa hỗ trợ STT offline. Hãy chuyển sang Engine Hệ thống.';
      return false;
    }

    _isListening = true;

    // Lắng nghe luồng PCM
    _pcmSubscription = pcmStream.listen(
      (bytes) {
        if (!_isListening) return;
        acceptPcmBytes(bytes);
      },
      onError: (e) {
        debugPrint('❌ SherpaSttEngine PCM stream error: $e');
        _lastError = '$e';
        stopListening();
      },
      onDone: () {
        debugPrint('ℹ️ SherpaSttEngine PCM stream done');
        stopListening();
      },
      cancelOnError: true,
    );

    debugPrint('🎙️ SherpaSttEngine started live listening ($language)');
    return true;
  }

  /// Nạp các byte PCM 16-bit mono 16kHz vào engine.
  void acceptPcmBytes(List<int> bytes) {
    if (!_isListening) return;
    final floats = pcm16ToFloat32(bytes);
    if (floats.isEmpty) return;
    acceptPcmSamples(floats);
  }

  /// Nạp các mẫu Float32List [-1.0, 1.0] vào engine.
  void acceptPcmSamples(Float32List samples) {
    if (!_isListening) return;

    final isVi = _currentLanguage.toLowerCase().startsWith('vi');
    if (isVi) {
      _processViSamples(samples);
    } else {
      _processEnSamples(samples);
    }
  }

  void _processViSamples(Float32List samples) {
    final vad = _vad;
    final offline = _offline;
    if (vad == null || offline == null) return;

    // Gom mẫu theo frame 512 mẫu (32ms @ 16kHz) cho Silero VAD
    _vadRemainderSamples.addAll(samples);

    while (_vadRemainderSamples.length >= SherpaVadCore.windowSize) {
      final frameList = _vadRemainderSamples.sublist(0, SherpaVadCore.windowSize);
      _vadRemainderSamples.removeRange(0, SherpaVadCore.windowSize);
      final frame = Float32List.fromList(frameList);

      vad.acceptWaveform(frame);

      final isDetected = vad.isDetected();
      if (isDetected) {
        _viSpeechSamples.addAll(frame);

        // Nhận diện từng phần định kỳ khi buffer speech tăng thêm >= 0.5s (8000 mẫu)
        if (_viSpeechSamples.length - _lastViPartialSamplesCount >= 8000) {
          _lastViPartialSamplesCount = _viSpeechSamples.length;
          _runViPartialDecode(offline);
        }
      }

      // Xử lý các segment câu đã hoàn tất từ VAD
      while (!vad.isEmpty()) {
        final seg = vad.front();
        vad.pop();
        _runViSegmentDecode(offline, seg.samples);
      }
    }
  }

  void _runViPartialDecode(sherpa.OfflineRecognizer offline) {
    if (_viSpeechSamples.length < 4800) return; // < 0.3s -> bỏ qua
    try {
      final stream = offline.createStream();
      try {
        final samples = Float32List.fromList(_viSpeechSamples);
        stream.acceptWaveform(samples: samples, sampleRate: SherpaVadCore.sampleRate);
        offline.decode(stream);
        final res = offline.getResult(stream);
        final text = (res.text ?? '').trim();
        if (text.isNotEmpty) {
          _liveController.add(SttResult(
            fullText: text,
            segments: const [],
            engineUsed: SttEngineType.sherpa,
            language: _currentLanguage,
            processingTime: Duration.zero,
            audioFingerprint: '',
            isFinal: false,
          ));
        }
      } finally {
        stream.free();
      }
    } catch (e) {
      debugPrint('⚠️ Sherpa VI partial decode error: $e');
    }
  }

  void _runViSegmentDecode(sherpa.OfflineRecognizer offline, Float32List segSamples) {
    if (segSamples.length < 3200) return; // Quá ngắn (<0.2s)
    try {
      final stream = offline.createStream();
      try {
        stream.acceptWaveform(
          samples: segSamples,
          sampleRate: SherpaVadCore.sampleRate,
        );
        offline.decode(stream);
        final res = offline.getResult(stream);
        final text = (res.text ?? '').trim();
        if (text.isNotEmpty) {
          final segments = _buildSegments(
            text: text,
            timestamps: res.timestamps,
            tokens: res.tokens,
            audioFingerprint: '',
          );
          _liveController.add(SttResult(
            fullText: text,
            segments: segments,
            engineUsed: SttEngineType.sherpa,
            language: _currentLanguage,
            processingTime: Duration.zero,
            audioFingerprint: '',
            hasWordTimestamps: segments.any((s) => s.words.isNotEmpty),
            isFinal: true,
          ));
        }
      } finally {
        stream.free();
      }
      _viSpeechSamples.clear();
      _lastViPartialSamplesCount = 0;
    } catch (e) {
      debugPrint('⚠️ Sherpa VI segment decode error: $e');
    }
  }

  void _processEnSamples(Float32List samples) {
    final online = _online;
    final stream = _onlineStream;
    if (online == null || stream == null) return;

    try {
      stream.acceptWaveform(samples: samples, sampleRate: 16000);
      while (online.isReady(stream)) {
        online.decode(stream);
      }

      final res = online.getResult(stream);
      final currentText = (res.text ?? '').trim();

      if (currentText.isNotEmpty && currentText != _lastEnPartialText) {
        _lastEnPartialText = currentText;
        _liveController.add(SttResult(
          fullText: currentText,
          segments: const [],
          engineUsed: SttEngineType.sherpa,
          language: _currentLanguage,
          processingTime: Duration.zero,
          audioFingerprint: '',
          isFinal: false,
        ));
      }

      if (online.isEndpoint(stream)) {
        final finalRes = online.getResult(stream);
        final finalText = (finalRes.text ?? '').trim();
        if (finalText.isNotEmpty) {
          final segments = _buildSegments(
            text: finalText,
            timestamps: finalRes.timestamps,
            tokens: finalRes.tokens,
            audioFingerprint: '',
          );
          _liveController.add(SttResult(
            fullText: finalText,
            segments: segments,
            engineUsed: SttEngineType.sherpa,
            language: _currentLanguage,
            processingTime: Duration.zero,
            audioFingerprint: '',
            hasWordTimestamps: segments.any((s) => s.words.isNotEmpty),
            isFinal: true,
          ));
        }
        online.reset(stream);
        _lastEnPartialText = '';
      }
    } catch (e) {
      debugPrint('⚠️ Sherpa EN streaming decode error: $e');
    }
  }

  @override
  Stream<SttResult> get liveResultStream => _liveController.stream;

  @override
  Future<bool> startListening({
    String language = 'en-US',
    Map<String, dynamic>? options,
  }) async {
    final pcmStream = options?['pcmStream'] as Stream<List<int>>?;
    if (pcmStream != null) {
      return startLive(
        language: language,
        pcmStream: pcmStream,
        modelPaths: SherpaModelPaths.fromOptions(options),
      );
    }
    // Nếu không truyền pcmStream, chỉ khởi tạo recognizer
    final models = SherpaModelPaths.fromOptions(options) ??
        SherpaModelManager().getAsrModelPaths(language);
    if (models == null) return false;
    if (language.toLowerCase().startsWith('vi')) {
      await _initOffline(models);
      return _offline != null;
    } else {
      await _initOnline(models);
      return _online != null;
    }
  }

  @override
  Future<void> stopListening() async {
    await _pcmSubscription?.cancel();
    _pcmSubscription = null;

    if (_isListening) {
      final isVi = _currentLanguage.toLowerCase().startsWith('vi');
      if (isVi && _offline != null) {
        if (_vad != null) {
          _vad!.flush();
          while (!_vad!.isEmpty()) {
            final seg = _vad!.front();
            _vad!.pop();
            _runViSegmentDecode(_offline!, seg.samples);
          }
        }
        if (_viSpeechSamples.length >= 4800) {
          _runViSegmentDecode(_offline!, Float32List.fromList(_viSpeechSamples));
        }
        _viSpeechSamples.clear();
        _vadRemainderSamples.clear();
        _lastViPartialSamplesCount = 0;
        _vad?.clear();
      } else if (!isVi && _online != null && _onlineStream != null) {
        final res = _online!.getResult(_onlineStream!);
        final finalText = (res.text ?? '').trim();
        if (finalText.isNotEmpty) {
          final segments = _buildSegments(
            text: finalText,
            timestamps: res.timestamps,
            tokens: res.tokens,
            audioFingerprint: '',
          );
          _liveController.add(SttResult(
            fullText: finalText,
            segments: segments,
            engineUsed: SttEngineType.sherpa,
            language: _currentLanguage,
            processingTime: Duration.zero,
            audioFingerprint: '',
            hasWordTimestamps: segments.any((s) => s.words.isNotEmpty),
            isFinal: true,
          ));
        }
        _onlineStream?.free();
        _onlineStream = null;
        _lastEnPartialText = '';
      }
    }

    _isListening = false;
  }

  @override
  Future<void> dispose() async {
    await stopListening();
    try {
      _onlineStream?.free();
    } catch (_) {}
    _onlineStream = null;

    try {
      _offline?.free();
    } catch (_) {}
    _offline = null;

    try {
      _online?.free();
    } catch (_) {}
    _online = null;

    try {
      _vad?.free();
    } catch (_) {}
    _vad = null;

    if (!_liveController.isClosed) await _liveController.close();
  }

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

  Future<String?> _resolveDefaultVadPath() async {
    final vadInfo = SherpaModelManager().vadInfo;
    if (vadInfo.isReady && vadInfo.localPath != null) {
      return vadInfo.localPath;
    }
    return null;
  }

  String _hashPath(String path) =>
      'fp_${path.hashCode.abs().toRadixString(16)}';
}
