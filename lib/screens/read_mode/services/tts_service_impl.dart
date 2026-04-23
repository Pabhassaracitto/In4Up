import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'tts_service.dart';

class FlutterTtsServiceImpl implements TtsService {
  final FlutterTts _tts;
  Completer<void>? _completer;

  FlutterTtsServiceImpl() : _tts = FlutterTts() {
    _tts.setCompletionHandler(() {
      _completer?.complete();
      _completer = null;
    });
    _tts.setErrorHandler((msg) {
      _completer?.completeError(msg ?? 'TTS error');
      _completer = null;
    });
  }

  @override
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    _completer = Completer<void>();
    await _tts.speak(text);
    try {
      await _completer!.future;
    } catch (e) {
      // 'stopped' là expected khi user nhấn stop — không rethrow
      if (e.toString() != 'stopped') rethrow;
    }
  }

  @override
  void stop() {
    _tts.stop();
    _completer?.completeError('stopped');
    _completer = null;
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    // Map 0.5–2.0 → 0.0–1.0
    final mapped = ((rate - 0.5) / 1.5).clamp(0.0, 1.0);
    await _tts.setSpeechRate(mapped);
  }

  @override
  Future<void> setLanguage(String locale) async {
    await _tts.setLanguage(locale);
  }

  @override
  set onStart(VoidCallback? cb) {
    if (cb != null) _tts.setStartHandler(cb);
  }

  @override
  set onComplete(VoidCallback? cb) {
    if (cb != null) _tts.setCompletionHandler(cb);
  }

  @override
  set onError(void Function(String error)? cb) {
    if (cb != null) _tts.setErrorHandler((msg) => cb(msg ?? 'unknown'));
  }

  @override
  Future<void> dispose() async {
    stop();
    await _tts.stop();
  }
}
