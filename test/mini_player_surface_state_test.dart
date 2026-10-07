import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/models/mini_player_surface_state.dart';

void main() {
  test('quick actions collapse visual player without pausing audio', () {
    const state = I4uMiniPlayerSurfaceState(
      visualMode: I4uMiniPlayerVisualMode.mini,
      playbackStatus: I4uPlaybackStatus.playing,
    );
    final next = state.forQuickActions(opened: true);
    expect(next.visualMode, I4uMiniPlayerVisualMode.collapsed);
    expect(next.playbackStatus, I4uPlaybackStatus.playing);
    expect(next.isAudioContinuingInBackground, isTrue);
  });

  test('large sheets hide foreground player but retain playback', () {
    const state = I4uMiniPlayerSurfaceState(
      visualMode: I4uMiniPlayerVisualMode.mini,
      playbackStatus: I4uPlaybackStatus.playing,
    );
    final next = state.forLargeSheet(opened: true);
    expect(next.visualMode, I4uMiniPlayerVisualMode.hidden);
    expect(next.playbackStatus, I4uPlaybackStatus.playing);
  });

  test('expanded player is a visual exception', () {
    const state = I4uMiniPlayerSurfaceState(
      visualMode: I4uMiniPlayerVisualMode.mini,
      playbackStatus: I4uPlaybackStatus.playing,
    );
    final next = state.forExpandedPlayer(opened: true);
    expect(next.visualMode, I4uMiniPlayerVisualMode.expanded);
    expect(next.isAudioContinuingInBackground, isFalse);
  });
}
