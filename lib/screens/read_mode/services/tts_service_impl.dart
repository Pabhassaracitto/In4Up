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
      // Truyền ngôn ngữ trực tiếp theo từng câu qua `speak(language: ...)` thay
      // vì ghi đè `_language`/`autoDetect = false` toàn cục của TtsService —
      // tránh làm các nơi khác (TextProvider, từ điển, PDF…) bị kẹt ở `en-US`
      // rồi đọc câu tiếng Việt bằng giọng nữ tiếng Anh.
      _appTts.configure(speed: _activeSpeed);

      // PSRC-230 — `matchVoiceLanguage: true` buộc TtsService chọn giọng
      // THEO NGÔN NGỮ của câu (`_activeLocale` do PlaybackEngine đặt trước
      // mỗi pha), không dùng `_selectedVoiceId` chung. Thiếu cờ này thì giọng
      // người dùng chọn cho tiếng Việt sẽ đọc luôn câu tiếng Anh.
      await _appTts.speak(
        text,
        language: _activeLocale,
        matchVoiceLanguage: true,
      );

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

  static final RegExp _bcp47RegionPattern =
      RegExp(r'^[a-zA-Z]{2,3}[-_][a-zA-Z]{2}$');

  @override
  Future<void> setLanguage(String locale) async {
    final trimmed = locale.trim();
    final String requested;
    if (_bcp47RegionPattern.hasMatch(trimmed)) {
      final parts = trimmed.replaceAll('_', '-').split('-');
      requested = '${parts[0].toLowerCase()}-${parts[1].toUpperCase()}';
    } else {
      requested = AppLanguageCatalog.fromCode(trimmed).ttsLocale;
    }
    _activeLocale = requested;
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
