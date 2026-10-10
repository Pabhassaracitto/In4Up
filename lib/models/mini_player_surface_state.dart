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
    this.suspendedMode,
  });

  final I4uMiniPlayerVisualMode visualMode;
  final I4uPlaybackStatus playbackStatus;
  final bool isAudioContinuingInBackground;

  /// Chế độ hiển thị bị một lớp phủ tạm thời (Quick Actions / sheet lớn) ẩn đi.
  ///
  /// C-31 (playback continuity): contract `docs/ux/36-pre-freeze-review.vi.md`
  /// mục 2 yêu cầu `largeSheetClosed → restore previous mini state`. Không nhớ
  /// chế độ trước đó thì đóng sheet xong Mini Player biến mất vĩnh viễn dù
  /// audio vẫn đang phát. Đây là bộ nhớ của đúng một bước ẩn/hiện.
  final I4uMiniPlayerVisualMode? suspendedMode;

  bool get isPlaying => playbackStatus == I4uPlaybackStatus.playing;

  /// Trạng thái khôi phục sau khi lớp phủ đóng — giữ nguyên playback.
  I4uMiniPlayerSurfaceState _restored() {
    final restore = suspendedMode;
    if (restore == null) return this;
    return I4uMiniPlayerSurfaceState(
      visualMode: restore,
      playbackStatus: playbackStatus,
      isAudioContinuingInBackground: isPlaying,
    );
  }

  I4uMiniPlayerSurfaceState forQuickActions({required bool opened}) {
    if (!opened) return _restored();
    if (visualMode == I4uMiniPlayerVisualMode.hidden) return this;
    return I4uMiniPlayerSurfaceState(
      visualMode: I4uMiniPlayerVisualMode.collapsed,
      playbackStatus: playbackStatus,
      isAudioContinuingInBackground: isPlaying,
      suspendedMode: visualMode,
    );
  }

  I4uMiniPlayerSurfaceState forLargeSheet({required bool opened}) {
    if (!opened) return _restored();
    if (visualMode == I4uMiniPlayerVisualMode.hidden) return this;
    return I4uMiniPlayerSurfaceState(
      visualMode: I4uMiniPlayerVisualMode.hidden,
      playbackStatus: playbackStatus,
      isAudioContinuingInBackground: isPlaying,
      suspendedMode: visualMode,
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
