// lib/features/tts/engines/offline_tts_engine.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'tts_engine.dart';

/// Offline TTS sử dụng flutter_tts (Android/iOS built-in TTS)
///
/// Luôn sẵn sàng, không cần internet
/// Chất lượng tùy thuộc device (Samsung/Xiaomi/Google thường tốt)
///
/// Tiếng Việt:
///   - Samsung: có giọng Việt khá tốt
///   - Google TTS engine trên device: khá tự nhiên
///   - Xiaomi: phụ thuộc model
class OfflineTtsEngine extends TtsEngine {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  String? _lastText;
  String _lastLanguage = 'en-US';
  double _lastSpeed = 1.0;
  double _lastPitch = 1.0;
  String? _lastVoiceId;
  bool _paused = false;
  int _playGeneration = 0;

  @override
  String get name => 'Offline TTS';

  @override
  String get id => 'offline_tts';

  @override
  int get maxCharsPerRequest => 4000;

  @override
  List<String> get supportedLanguages => [
        'vi-VN',
        'en-US',
        'en-GB',
        'ja-JP',
        'ko-KR',
        'zh-CN',
        'fr-FR',
        'de-DE',
        'es-ES',
      ];

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    try {
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(true);
      _initialized = true;
    } catch (e) {
      debugPrint('OfflineTTS init error: $e');
    }
  }

  @override
  Future<bool> isAvailable() async {
    try {
      await _ensureInitialized();
      final languages = await _tts.getLanguages;
      return languages != null && (languages as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<TtsResult> synthesize({
    required String text,
    required String language,
    double speed = 1.0,
    double pitch = 1.0,
    String? voiceId,
  }) async {
    // Offline TTS không trả về bytes, nó phát trực tiếp
    // Ta sẽ xử lý đặc biệt trong TtsService
    return TtsResult(
      isSuccess: true,
      engineName: name,
      source: TtsAudioSource.offline,
    );
  }

  /// Phát trực tiếp (không qua bytes)
  Future<void> speakDirect({
    required String text,
    required String language,
    double speed = 1.0,
    double pitch = 1.0,
    String? voiceId,
  }) async {
    _lastText = text;
    _lastLanguage = language;
    _lastSpeed = speed;
    _lastPitch = pitch;
    _lastVoiceId = voiceId;
    _paused = false;
    final generation = ++_playGeneration;
    await _ensureInitialized();
    if (generation != _playGeneration) return;

    try {
      // Set language
      final result = await _tts.setLanguage(language);
      if (result == 0) {
        // Thử format khác
        final shortLang = language.split('-').first;
        await _tts.setLanguage(shortLang);
      }

      // Set speed (flutter_tts: 0.0 - 1.0, default 0.5)
      final rate = (speed / 2.0).clamp(0.1, 1.0);
      await _tts.setSpeechRate(rate);

      // Set pitch
      await _tts.setPitch(pitch.clamp(0.5, 2.0));

      // Set voice nếu có
      if (voiceId != null) {
        await _tts.setVoice({'name': voiceId, 'locale': language});
      }

      // Stop/restart may have been requested while plugin settings were applied.
      if (generation != _playGeneration) return;
      await _tts.speak(text);
    } catch (e) {
      debugPrint('OfflineTTS speak error: $e');
      rethrow;
    }
  }

  /// Dừng phát và xóa câu có thể dùng để khôi phục.
  Future<void> stop() async {
    _playGeneration++;
    _paused = false;
    _lastText = null;
    await _tts.stop();
  }

  /// Tạm dừng giọng máy (I4U18-PDF-OCR-TTS-001 F3).
  ///
  /// FlutterTts không cung cấp resume native nhất quán giữa nền tảng; giữ lại
  /// câu hiện tại để có thể phát lại từ đầu khi tiếp tục nếu cần.
  Future<void> pause() async {
    if (_lastText == null) return;
    _paused = true;
    try {
      await _tts.pause();
    } catch (e) {
      debugPrint('OfflineTTS pause không hỗ trợ ($e) — dừng hẳn thay thế');
      await _tts.stop();
    }
  }

  /// FlutterTts exposes pause but no portable resume operation. Restart the
  /// interrupted sentence; the caller keeps the current PDF cue active until
  /// this future completes, so playback never skips ahead while paused.
  Future<void> restartPausedSpeech() async {
    final text = _lastText;
    if (!_paused || text == null) return;
    final language = _lastLanguage;
    final speed = _lastSpeed;
    final pitch = _lastPitch;
    final voiceId = _lastVoiceId;
    _paused = false;
    final generation = ++_playGeneration;
    await _tts.stop();
    if (generation != _playGeneration || _lastText == null) return;
    await speakDirect(
      text: text,
      language: language,
      speed: speed,
      pitch: pitch,
      voiceId: voiceId,
    );
  }

  @override
  Future<List<TtsVoice>> getAvailableVoices(String language) async {
    await _ensureInitialized();

    try {
      final voices = await _tts.getVoices;
      if (voices == null) return [];

      final langPrefix = language.split('-').first.toLowerCase();

      return (voices as List)
          .where((v) {
            final locale = (v['locale'] as String? ?? '').toLowerCase();
            return locale.startsWith(langPrefix);
          })
          .map((v) => TtsVoice(
                id: v['name'] as String? ?? 'unknown',
                name: v['name'] as String? ?? 'Default',
                language: v['locale'] as String? ?? language,
                gender: 'unknown',
                engine: name,
                isNeural: false,
              ))
          .toList();
    } catch (e) {
      debugPrint('getAvailableVoices error: $e');
      return [];
    }
  }

  void dispose() {
    _tts.stop();
  }
}
