import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/language/app_language.dart';
import '../../../features/tts/tts_service.dart' as app_tts;
import 'tts_service.dart';

/// Triển khai TtsService cho PlaybackEngine dựa trên TtsService hợp nhất
/// (Tự động ưu tiên Sherpa Piper neural TTS offline, fallback linh hoạt sang Offline máy / Online).
class FlutterTtsServiceImpl implements TtsService {
  final app_tts.TtsService _appTts;
  String _activeLocale = 'en-US';
  double _activeSpeed = 1.0;
  bool _stopped = false;

  VoidCallback? _onStart;
  VoidCallback? _onComplete;
  void Function(String error)? _onError;

  FlutterTtsServiceImpl({app_tts.TtsService? appTts})
      : _appTts = appTts ?? app_tts.TtsService();

  @override
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    _stopped = false;
    _onStart?.call();

    try {
      _appTts.configure(
        language: _activeLocale,
        autoDetect: false,
        speed: _activeSpeed,
      );

      await _appTts.speak(text);

      // Chờ cho đến khi phát xong hoặc bị dừng
      int waitLimit = 0;
      while (_appTts.isSpeaking && !_stopped && waitLimit < 600) {
        await Future.delayed(const Duration(milliseconds: 50));
        waitLimit++;
      }

      if (_appTts.error != null && _appTts.error!.isNotEmpty) {
        _onError?.call(_appTts.error!);
      } else {
        _onComplete?.call();
      }
    } catch (error) {
      if (!_stopped) {
        _onError?.call(error.toString());
        rethrow;
      }
    }
  }

  @override
  void stop() {
    _stopped = true;
    _appTts.stop();
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    _activeSpeed = rate.clamp(0.25, 2.0);
    _appTts.configure(speed: _activeSpeed);
  }

  @override
  Future<void> setLanguage(String locale) async {
    final requested = AppLanguageCatalog.fromCode(locale).ttsLocale;
    _activeLocale = requested;
    _appTts.configure(language: requested, autoDetect: false);
    debugPrint('[ReadTTS] Language set to $requested');
  }

  @override
  set onStart(VoidCallback? callback) {
    _onStart = callback;
  }

  @override
  set onComplete(VoidCallback? callback) {
    _onComplete = callback;
  }

  @override
  set onError(void Function(String error)? callback) {
    _onError = callback;
  }

  @override
  Future<void> dispose() async {
    stop();
  }
}
