/// Pure state and boundary rules for a local-video A–B loop.
///
/// The platform player remains the playback clock. This model only describes
/// the selected interval and answers whether the playhead crossed its end.
class VideoAbLoopState {
  const VideoAbLoopState({this.a, this.b, this.enabled = false});

  static const Duration minRange = Duration(milliseconds: 300);
  static const VideoAbLoopState empty = VideoAbLoopState();

  final Duration? a;
  final Duration? b;
  final bool enabled;

  bool get hasA => a != null;
  bool get isActive => enabled &&
      a != null &&
      b != null &&
      b! - a! >= minRange;

  /// Set a new start marker and clear any previous end marker.
  VideoAbLoopState markA(Duration position, Duration duration) {
    final clamped = _clamp(position, duration);
    return VideoAbLoopState(a: clamped, enabled: false);
  }

  /// Set B and enable looping. Invalid or too-short intervals are rejected.
  VideoAbLoopState? markB(Duration position, Duration duration) {
    final start = a;
    if (start == null || duration <= Duration.zero) return null;
    final end = _clamp(position, duration);
    if (end - start < minRange) return null;
    return VideoAbLoopState(a: start, b: end, enabled: true);
  }

  VideoAbLoopState clear() => empty;

  /// Returns A only when the active playhead has reached/passed B.
  Duration? wrapTarget(Duration position) {
    final start = a;
    final end = b;
    if (!isActive || start == null || end == null || position < end) {
      return null;
    }
    return start;
  }

  static Duration _clamp(Duration position, Duration duration) {
    if (position < Duration.zero) return Duration.zero;
    if (duration > Duration.zero && position > duration) return duration;
    return position;
  }
}
