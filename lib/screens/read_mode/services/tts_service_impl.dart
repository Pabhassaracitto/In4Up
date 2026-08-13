import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../core/language/app_language.dart';
import 'tts_service.dart';

class FlutterTtsServiceImpl implements TtsService {
  final FlutterTts _tts;
  Completer<void>? _completer;
  Set<String>? _availableLanguages;
  String? _activeLocale;

  FlutterTtsServiceImpl() : _tts = FlutterTts() {
    _tts.setCompletionHandler(() {
      if (!(_completer?.isCompleted ?? true)) _completer?.complete();
      _completer = null;
    });
    _tts.setErrorHandler((message) {
      if (!(_completer?.isCompleted ?? true)) {
        _completer?.completeError(message ?? 'TTS error');
      }
      _completer = null;
    });
  }

  @override
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    final previous = _completer;
    if (previous != null && !previous.isCompleted) {
      previous.completeError('stopped');
    }

    final completer = Completer<void>();
    _completer = completer;
    final result = await _tts.speak(text);
    if ((result == 0 || result == false) && !completer.isCompleted) {
      completer.completeError('TTS không thể phát văn bản');
    }
    try {
      await completer.future;
    } catch (error) {
      if (error.toString() != 'stopped') rethrow;
    } finally {
      if (identical(_completer, completer)) _completer = null;
    }
  }

  @override
  void stop() {
    _tts.stop();
    final completer = _completer;
    if (completer != null && !completer.isCompleted) {
      completer.completeError('stopped');
    }
    _completer = null;
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    final mapped = ((rate - 0.5) / 1.5).clamp(0.0, 1.0);
    await _tts.setSpeechRate(mapped);
  }

  @override
  Future<void> setLanguage(String locale) async {
    final requested = AppLanguageCatalog.fromCode(locale).ttsLocale;
    final resolved = await _resolveSupportedLocale(requested);

    if (_activeLocale == resolved) return;
    final result = await _tts.setLanguage(resolved);
    if (result == 0 || result == false) {
      throw StateError('Thiết bị không có giọng đọc cho $requested');
    }
    _activeLocale = resolved;
    debugPrint('[ReadTTS] language=$resolved (requested=$requested)');
  }

  Future<String> _resolveSupportedLocale(String requested) async {
    final normalizedRequested = _normalizeLocale(requested);
    try {
      _availableLanguages ??= await _loadAvailableLanguages();
      final available = _availableLanguages!;
      if (available.isEmpty || available.contains(normalizedRequested)) {
        return requested;
      }

      final base = normalizedRequested.split('-').first;
      final sameLanguage = available.where(
        (candidate) => candidate.split('-').first == base,
      );
      if (sameLanguage.isNotEmpty) return sameLanguage.first;

      throw StateError(
        'Thiết bị chưa cài giọng ${AppLanguageCatalog.fromCode(requested).nativeName}',
      );
    } catch (error) {
      if (error is StateError) rethrow;
      // Some platforms do not expose getLanguages reliably. In that case we
      // still call setLanguage and validate its return value.
      return requested;
    }
  }

  Future<Set<String>> _loadAvailableLanguages() async {
    final raw = await _tts.getLanguages;
    if (raw is! List) return <String>{};
    return raw
        .whereType<Object>()
        .map((value) => _normalizeLocale(value.toString()))
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  String _normalizeLocale(String value) =>
      value.trim().replaceAll('_', '-').toLowerCase();

  @override
  set onStart(VoidCallback? callback) {
    if (callback != null) _tts.setStartHandler(callback);
  }

  @override
  set onComplete(VoidCallback? callback) {
    if (callback != null) _tts.setCompletionHandler(callback);
  }

  @override
  set onError(void Function(String error)? callback) {
    if (callback != null) {
      _tts.setErrorHandler((message) => callback(message ?? 'unknown'));
    }
  }

  @override
  Future<void> dispose() async {
    stop();
    await _tts.stop();
  }
}
