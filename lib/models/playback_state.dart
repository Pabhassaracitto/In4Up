import 'package:flutter/foundation.dart';

/// Playback status enum - More detailed than simple bool
enum PlaybackStatus {
  stopped, // Not playing, position at zero
  loading, // Loading audio file
  playing, // Currently playing
  paused, // Paused
  buffering, // Buffering (for streaming)
  error, // Error occurred
}

/// Immutable playback state model
@immutable
class PlaybackState {
  // Playback status
  final PlaybackStatus status;

  // Position & Duration
  final Duration position;
  final Duration duration;

  // Audio controls
  final double speed; // 0.05 - 10.0 (V2 range)
  final double pitch; // -24 to +24 semitones (V2 feature)
  final double volume; // 0.0 - 1.0

  // Additional features
  final bool isLooping; // Loop playback
  final Duration? sleepTimerRemaining; // Sleep timer

  // Error handling
  final String? errorMessage;

  const PlaybackState({
    this.status = PlaybackStatus.stopped,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.speed = 1.0,
    this.pitch = 0.0,
    this.volume = 1.0,
    this.isLooping = false,
    this.sleepTimerRemaining,
    this.errorMessage,
  });

  /// Convenience getter for backward compatibility
  bool get isPlaying => status == PlaybackStatus.playing;

  /// Check if audio is loaded
  bool get isLoaded => duration > Duration.zero;

  /// Check if playback is stopped
  bool get isStopped => status == PlaybackStatus.stopped;

  /// Check if playback is paused
  bool get isPaused => status == PlaybackStatus.paused;

  /// Check if loading
  bool get isLoading => status == PlaybackStatus.loading;

  /// Check if buffering
  bool get isBuffering => status == PlaybackStatus.buffering;

  /// Check if error
  bool get hasError => status == PlaybackStatus.error;

  /// Get progress percentage (0.0 - 1.0)
  double get progress {
    if (duration.inMilliseconds <= 0) return 0.0;
    return position.inMilliseconds / duration.inMilliseconds;
  }

  /// Get remaining time
  Duration get remaining => duration - position;

  PlaybackState copyWith({
    PlaybackStatus? status,
    Duration? position,
    Duration? duration,
    double? speed,
    double? pitch,
    double? volume,
    bool? isLooping,
    Duration? sleepTimerRemaining,
    String? errorMessage,
  }) {
    return PlaybackState(
      status: status ?? this.status,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      speed: speed ?? this.speed,
      pitch: pitch ?? this.pitch,
      volume: volume ?? this.volume,
      isLooping: isLooping ?? this.isLooping,
      sleepTimerRemaining: sleepTimerRemaining ?? this.sleepTimerRemaining,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PlaybackState &&
        other.status == status &&
        other.position == position &&
        other.duration == duration &&
        other.speed == speed &&
        other.pitch == pitch &&
        other.volume == volume &&
        other.isLooping == isLooping &&
        other.sleepTimerRemaining == sleepTimerRemaining &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode {
    return Object.hash(
      status,
      position,
      duration,
      speed,
      pitch,
      volume,
      isLooping,
      sleepTimerRemaining,
      errorMessage,
    );
  }

  @override
  String toString() {
    return 'PlaybackState('
        'status: $status, '
        'position: ${position.inSeconds}s, '
        'duration: ${duration.inSeconds}s, '
        'speed: ${speed}x, '
        'pitch: $pitch semitones, '
        'volume: $volume, '
        'isLooping: $isLooping'
        ')';
  }
}
