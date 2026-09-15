// lib/screens/home/quick_capture/quick_capture_stt_sources.dart
//
// HOME-QUICK-001 — hai nguồn STT live cho "Nạp tri thức nhanh".
//
// TÁI SỬ DỤNG hạ tầng STT hiện có của app, không tạo engine/singleton mới:
//  * [SherpaQuickCaptureSource] → `SherpaSttEngine` (packages/in4up_stt) +
//    `AudioRecorder` PCM 16kHz — giống đường live STT của Cabin (WP4),
//    chỉ khác là KHÔNG dịch/không dubbing.
//  * [SystemQuickCaptureSource] → `SttServiceFacade` (singleton có sẵn)
//    ở chế độ hội thoại (`startConversation`, ListenMode.dictation).
//
// [buildQuickCaptureSources] xếp Sherpa offline TRƯỚC system STT để đúng
// yêu cầu "ưu tiên Sherpa offline khi khả dụng".

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in4up_stt/models/stt_result.dart';
import 'package:in4up_stt/sherpa_model_manager.dart';
import 'package:in4up_stt/stt_engine_sherpa.dart';
import 'package:in4up_stt/stt_service_facade.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'quick_capture_controller.dart';

/// Chọn ngôn ngữ nhận diện cho phiên quick capture (pure — test được).
///
/// Luật (không hardcode EN như cabin cũ — xem CABIN-ASR-002):
///  1. Ngôn ngữ app đã có model Sherpa → dùng luôn.
///  2. Chưa có nhưng máy đã import model [fallbackLearningLanguage] (vi —
///     ngôn ngữ học chính của app) → dùng nó.
///  3. Máy chỉ có model ngôn ngữ khác → dùng model đó (đã cài thì dùng).
///  4. Không có model Sherpa nào → dùng ngôn ngữ app cho system STT.
class QuickCaptureLanguagePolicy {
  QuickCaptureLanguagePolicy._();

  /// Ngôn ngữ học mặc định của app khi chưa biết chọn gì.
  static const String fallbackLearningLanguage = 'vi';

  static String resolve({
    required String appLanguage,
    required Iterable<String> sherpaLanguages,
  }) {
    final installed = sherpaLanguages
        .map((l) => l.trim().toLowerCase())
        .where((l) => l.isNotEmpty)
        .toSet();
    final app = appLanguage.trim().toLowerCase();

    if (app.isNotEmpty && installed.contains(app)) return app;
    if (installed.contains(fallbackLearningLanguage)) {
      return fallbackLearningLanguage;
    }
    if (installed.isNotEmpty) {
      final sorted = installed.toList()..sort();
      return sorted.first;
    }
    return app.isEmpty ? fallbackLearningLanguage : app;
  }

  /// Map mã ngôn ngữ → locale BCP-47 cho speech service hệ thống.
  static String toSystemLocale(String language) {
    switch (language.toLowerCase().trim()) {
      case 'vi':
        return 'vi-VN';
      case 'en':
        return 'en-US';
      case 'zh':
        return 'zh-CN';
      case 'fr':
        return 'fr-FR';
      case 'de':
        return 'de-DE';
      case 'ja':
        return 'ja-JP';
      case 'ko':
        return 'ko-KR';
      case 'th':
        return 'th-TH';
      case 'hi':
        return 'hi-IN';
      case 'si':
        return 'si-LK';
      case 'my':
        return 'my-MM';
      default:
        final code = language.trim();
        return code.isEmpty ? 'en-US' : '$code-${code.toUpperCase()}';
    }
  }
}

/// Xin quyền microphone (giữ hành vi giống Cabin: máy không có API quyền
/// thì coi như đã cấp để engine tự báo lỗi thật).
Future<bool> requestQuickCaptureMicPermission() async {
  try {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    final result = await Permission.microphone.request();
    return result.isGranted;
  } catch (e) {
    debugPrint('⚠️ QuickCapture mic permission check error: $e');
    return true;
  }
}

/// Live STT offline qua Zipformer (sherpa-onnx) — VI: OfflineRecognizer +
/// Silero VAD (simulated streaming), EN: OnlineRecognizer (streaming thật).
class SherpaQuickCaptureSource implements QuickCaptureSttSource {
  SherpaQuickCaptureSource({
    required this.language,
    SherpaModelManager? modelManager,
    SherpaSttEngine? engine,
  })  : _modelManager = modelManager ?? SherpaModelManager(),
        _engine = engine ?? SherpaSttEngine();

  @override
  final String language;

  final SherpaModelManager _modelManager;
  final SherpaSttEngine _engine;
  AudioRecorder? _recorder;
  bool _engineDisposed = false;

  @override
  QuickCaptureEngineKind get kind => QuickCaptureEngineKind.sherpaOffline;

  @override
  bool get isReady => _modelManager.hasAsrModel(language);

  @override
  String? get unavailableReason =>
      'Sherpa ${language.toUpperCase()}: chưa import model Zipformer';

  @override
  Stream<SttResult> get results => _engine.liveResultStream;

  @override
  String? get lastError => _engine.lastError;

  @override
  Future<bool> start() async {
    await stop();
    if (_engineDisposed) return false;

    final recorder = AudioRecorder();
    _recorder = recorder;
    try {
      final pcmStream = await recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );
      final ok = await _engine.startLive(
        language: language,
        pcmStream: pcmStream,
      );
      if (!ok) {
        await _releaseRecorder();
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('❌ SherpaQuickCaptureSource start error: $e');
      await _releaseRecorder();
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _engine.stopListening();
    } catch (e) {
      debugPrint('⚠️ SherpaQuickCaptureSource stop error: $e');
    }
    await _releaseRecorder();
  }

  /// Giải phóng recognizer của phiên — engine thuộc về phiên này, không
  /// dùng lại (không giữ singleton STT thứ hai).
  @override
  Future<void> release() async {
    await stop();
    if (_engineDisposed) return;
    _engineDisposed = true;
    try {
      await _engine.dispose();
    } catch (e) {
      debugPrint('⚠️ SherpaQuickCaptureSource release error: $e');
    }
  }

  Future<void> _releaseRecorder() async {
    final recorder = _recorder;
    _recorder = null;
    if (recorder == null) return;
    try {
      if (await recorder.isRecording()) {
        await recorder.stop();
      }
    } catch (_) {}
    try {
      await recorder.dispose();
    } catch (_) {}
  }
}

/// Live STT bằng speech service của hệ thống (qua `SttServiceFacade` —
/// singleton sẵn có, không tạo bản thứ hai).
class SystemQuickCaptureSource implements QuickCaptureSttSource {
  SystemQuickCaptureSource({
    required this.language,
    SttServiceFacade? facade,
  }) : _facade = facade ?? SttServiceFacade();

  @override
  final String language;

  final SttServiceFacade _facade;
  String? _lastError;

  @override
  QuickCaptureEngineKind get kind => QuickCaptureEngineKind.system;

  /// Không kiểm tra trước được (máy có service hay không chỉ biết khi start).
  @override
  bool get isReady => true;

  @override
  Stream<SttResult> get results => _facade.liveResultStream;

  @override
  String? get lastError => _lastError ?? _facade.liveLastError;

  @override
  Future<bool> start() async {
    _lastError = null;
    final locale = QuickCaptureLanguagePolicy.toSystemLocale(language);

    try {
      await _facade.initialize();
    } catch (e) {
      debugPrint('⚠️ SystemQuickCaptureSource init warning: $e');
    }

    var started = await _tryStart(locale);
    if (!started) {
      // Session cũ có thể còn treo — dọn rồi thử lại MỘT lần (như Cabin).
      try {
        await _facade.stopListening();
      } catch (_) {}
      started = await _tryStart(locale);
    }
    if (!started) {
      _lastError ??= _facade.liveLastError ??
          'Speech recognition của hệ thống không khả dụng';
      debugPrint('❌ SystemQuickCaptureSource start failed: $_lastError');
    }
    return started;
  }

  Future<bool> _tryStart(String locale) async {
    try {
      return await _facade.startConversation(language: locale);
    } catch (e) {
      _lastError = '$e';
      debugPrint('❌ SystemQuickCaptureSource startConversation error: $e');
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _facade.stopListening();
    } catch (e) {
      debugPrint('⚠️ SystemQuickCaptureSource stop error: $e');
    }
  }
}

/// Dựng danh sách nguồn STT theo thứ tự ưu tiên cho một phiên.
///
/// Sherpa offline đứng trước khi máy đã có model cho ngôn ngữ đã chọn;
/// system STT luôn đứng cuối làm fallback.
List<QuickCaptureSttSource> buildQuickCaptureSources({
  required String appLanguage,
  SherpaModelManager? modelManager,
  SttServiceFacade? facade,
}) {
  final models = modelManager ?? SherpaModelManager();

  final installed = <String>[];
  for (final profile in SherpaModelManager.predefinedAsrProfiles) {
    if (installed.contains(profile.language)) continue;
    try {
      if (models.hasAsrModel(profile.id)) installed.add(profile.language);
    } catch (e) {
      debugPrint('⚠️ buildQuickCaptureSources: hasAsrModel error: $e');
    }
  }

  final language = QuickCaptureLanguagePolicy.resolve(
    appLanguage: appLanguage,
    sherpaLanguages: installed,
  );

  return <QuickCaptureSttSource>[
    if (installed.contains(language))
      SherpaQuickCaptureSource(language: language, modelManager: models),
    SystemQuickCaptureSource(language: language, facade: facade),
  ];
}
