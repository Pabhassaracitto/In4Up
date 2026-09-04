import 'dart:async';
import 'package:in4up_stt/stt_service_facade.dart';
import 'voice_command_parser.dart';

/// One mic session at a time. The facade remains the single STT entry point.
class VoiceCommandService {
  final SttServiceFacade stt;
  StreamSubscription? _subscription;
  Timer? _silenceTimer;
  bool _running = false;
  bool get isListening => _running;

  VoiceCommandService({SttServiceFacade? stt}) : stt = stt ?? SttServiceFacade();

  Future<bool> start({String language = 'vi-VN', Duration maxDuration = const Duration(seconds: 6),
      Duration silence = const Duration(milliseconds: 1500),
      required void Function(VoiceCommand command) onCommand,
      void Function(String partial)? onPartial,
      void Function(Object error)? onError}) async {
    if (_running) return false;
    _running = await stt.startListening(language: language);
    if (!_running) return false;
    var fired = false;
    void finish() { if (_running) { _running = false; _silenceTimer?.cancel(); _subscription?.cancel(); stt.stopListening(); } }
    _subscription = stt.partialResultStream.listen((result) {
      final text = result.fullText.trim();
      if (text.isEmpty) return;
      onPartial?.call(text);
      _silenceTimer?.cancel();
      _silenceTimer = Timer(silence, finish);
      if (!fired) { final command = parseVoiceCommand(text); if (command != null) { fired = true; onCommand(command); } }
    }, onError: (Object e) { onError?.call(e); finish(); });
    Timer(maxDuration, finish);
    return true;
  }

  Future<void> stop() async { _running = false; _silenceTimer?.cancel(); await _subscription?.cancel(); _subscription = null; await stt.stopListening(); }
  Future<void> dispose() => stop();
}
