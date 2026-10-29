import 'voice_command_parser.dart';

/// Keeps command handling independent from widgets and concrete providers.
class VoiceCommandExecutor {
  final Future<void> Function() onPlay;
  final Future<void> Function() onPause;
  final Future<void> Function() onNext;
  final Future<void> Function() onPrevious;
  final Future<void> Function(double delta) onRateDelta;
  final Future<void> Function() onToggleLyrics;
  final Future<void> Function() onTranslate;

  const VoiceCommandExecutor({required this.onPlay, required this.onPause,
    required this.onNext, required this.onPrevious, required this.onRateDelta,
    required this.onToggleLyrics, required this.onTranslate});

  Future<void> execute(VoiceCommand command) {
    switch (command.type) {
      case VoiceCommandType.play: return onPlay();
      case VoiceCommandType.pause: return onPause();
      case VoiceCommandType.next: return onNext();
      case VoiceCommandType.previous: return onPrevious();
      case VoiceCommandType.faster: return onRateDelta(0.25);
      case VoiceCommandType.slower: return onRateDelta(-0.25);
      case VoiceCommandType.toggleLyrics: return onToggleLyrics();
      case VoiceCommandType.translate: return onTranslate();
    }
  }
}
