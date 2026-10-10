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

  // C-31 — playback continuity: đóng lớp phủ phải trả Mini Player về đúng
  // trạng thái trước đó (docs/ux/36 §2: largeSheetClosed → restore mini).
  test('đóng sheet lớn khôi phục Mini Player mà không đổi trạng thái phát', () {
    const state = I4uMiniPlayerSurfaceState(
      visualMode: I4uMiniPlayerVisualMode.mini,
      playbackStatus: I4uPlaybackStatus.playing,
    );
    final restored = state.forLargeSheet(opened: true).forLargeSheet(opened: false);
    expect(restored.visualMode, I4uMiniPlayerVisualMode.mini);
    expect(restored.playbackStatus, I4uPlaybackStatus.playing);
    expect(restored.isAudioContinuingInBackground, isTrue);
  });

  test('đóng Quick Actions trả Mini Player về trạng thái trước đó', () {
    const state = I4uMiniPlayerSurfaceState(
      visualMode: I4uMiniPlayerVisualMode.mini,
      playbackStatus: I4uPlaybackStatus.paused,
    );
    final restored = state.forQuickActions(opened: true).forQuickActions(opened: false);
    expect(restored.visualMode, I4uMiniPlayerVisualMode.mini);
    expect(restored.playbackStatus, I4uPlaybackStatus.paused);
    expect(restored.isAudioContinuingInBackground, isFalse);
  });

  test('đóng lớp phủ khi chưa từng mở không đổi gì (idle ở Home)', () {
    const state = I4uMiniPlayerSurfaceState();
    expect(state.forLargeSheet(opened: false).visualMode, I4uMiniPlayerVisualMode.hidden);
    expect(state.forQuickActions(opened: false).visualMode, I4uMiniPlayerVisualMode.hidden);
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
