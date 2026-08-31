import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/language/app_language.dart';
import '../../../features/tts/engines/piper_tts_engine.dart';
import 'tts_service.dart';
import 'tts_service_impl.dart';

/// Read-tab TTS: Piper neural first (imported voices), then device flutter_tts.
class StudioTtsService implements TtsService {
  final FlutterTtsServiceImpl _system = FlutterTtsServiceImpl();
  final AudioPlayer _player = AudioPlayer();

  String _locale = AppLanguageCatalog.english.ttsLocale;
  double _rate = 1.0;
  bool _stopped = false;
  Completer<void>? _piperDone;

  @override
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    _stopped = false;
    if (await _tryPiper(text)) return;
    if (_stopped) return;
    await _system.setLanguage(_locale);
    await _system.setSpeechRate(_rate);
    await _system.speak(text);
  }

  Future<bool> _tryPiper(String text) async {
    try {
      final piper = PiperTtsEngine.instance;
      if (!await piper.isAvailable()) return false;
      final result = await piper.synthesize(
        text: text,
        language: _locale,
        speed: _rate,
      );
      if (!result.isSuccess ||
          result.audioData == null ||
          result.audioData!.isEmpty) {
        debugPrint('StudioTts Piper skip: ${result.error}');
        return false;
      }
      if (_stopped) return true;

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/in4up_piper_${DateTime.now().microsecondsSinceEpoch}.wav',
      );
      await file.writeAsBytes(result.audioData!, flush: true);

      _piperDone = Completer<void>();
      await _player.stop();
      await _player.setFilePath(file.path);
      await _player.setSpeed(_rate.clamp(0.5, 2.0));
      final sub = _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed ||
            state.processingState == ProcessingState.idle) {
          final done = _piperDone;
          if (done != null && !done.isCompleted) done.complete();
        }
      });
      await _player.play();
      try {
        await (_piperDone?.future ?? Future<void>.value())
            .timeout(const Duration(minutes: 3));
      } on TimeoutException {
        // still count as spoken
      } finally {
        await sub.cancel();
        _piperDone = null;
        try {
          await file.delete();
        } catch (_) {}
      }
      return true;
    } catch (e) {
      debugPrint('StudioTts Piper error: $e');
      return false;
    }
  }

  @override
  void stop() {
    _stopped = true;
    try {
      _player.stop();
    } catch (_) {}
    final done = _piperDone;
    if (done != null && !done.isCompleted) done.complete();
    _piperDone = null;
    _system.stop();
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    _rate = rate.clamp(0.25, 2.0);
    await _system.setSpeechRate(_rate);
    try {
      await _player.setSpeed(_rate.clamp(0.5, 2.0));
    } catch (_) {}
  }

  @override
  Future<void> setLanguage(String locale) async {
    _locale = AppLanguageCatalog.fromCode(locale).ttsLocale;
    try {
      await _system.setLanguage(_locale);
    } catch (e) {
      // Piper may still speak this locale even if the device has no voice.
      debugPrint('StudioTts system language skip: $e');
    }
  }

  @override
  set onStart(VoidCallback? callback) {
    _system.onStart = callback;
  }

  @override
  set onComplete(VoidCallback? callback) {
    _system.onComplete = callback;
  }

  @override
  set onError(void Function(String error)? callback) {
    _system.onError = callback;
  }

  @override
  Future<void> dispose() async {
    stop();
    await _player.dispose();
    await _system.dispose();
  }
}
