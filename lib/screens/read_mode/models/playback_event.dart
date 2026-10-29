import 'playback_snapshot.dart';

enum PlaybackEventType { lineStart, languageSwitch, phase }

class PlaybackEvent {
  final PlaybackEventType type;
  final PlaybackSnapshot snapshot;

  const PlaybackEvent({
    required this.type,
    required this.snapshot,
  });
}
