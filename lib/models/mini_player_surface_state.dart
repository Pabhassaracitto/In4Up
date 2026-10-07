import 'package:flutter/foundation.dart';

/// Visual state is separate from playback state: hiding a player must not
/// pause audio.
enum I4uMiniPlayerVisualMode { hidden, mini, collapsed, expanded }

enum I4uPlaybackStatus { idle, loading, playing, paused, failed }

@immutable
class I4uMiniPlayerSurfaceState {
  const I4uMiniPlayerSurfaceState({
    this.visualMode = I4uMiniPlayerVisualMode.hidden,
    this.playbackStatus = I4uPlaybackStatus.idle,
    this.isAudioContinuingInBackground = false,
  });

  final I4uMiniPlayerVisualMode visualMode;
  final I4uPlaybackStatus playbackStatus;
  final bool isAudioContinuingInBackground;

  bool get isPlaying => playbackStatus == I4uPlaybackStatus.playing;

  I4uMiniPlayerSurfaceState forQuickActions({required bool opened}) {
    if (!opened || visualMode == I4uMiniPlayerVisualMode.hidden) return this;
    return I4uMiniPlayerSurfaceState(
      visualMode: I4uMiniPlayerVisualMode.collapsed,
      playbackStatus: playbackStatus,
      isAudioContinuingInBackground: isPlaying,
    );
  }

  I4uMiniPlayerSurfaceState forLargeSheet({required bool opened}) {
    if (!opened || visualMode == I4uMiniPlayerVisualMode.hidden) return this;
    return I4uMiniPlayerSurfaceState(
      visualMode: I4uMiniPlayerVisualMode.hidden,
      playbackStatus: playbackStatus,
      isAudioContinuingInBackground: isPlaying,
    );
  }

  I4uMiniPlayerSurfaceState forExpandedPlayer({required bool opened}) {
    return I4uMiniPlayerSurfaceState(
      visualMode: opened
          ? I4uMiniPlayerVisualMode.expanded
          : I4uMiniPlayerVisualMode.mini,
      playbackStatus: playbackStatus,
      isAudioContinuingInBackground: false,
    );
  }
}
