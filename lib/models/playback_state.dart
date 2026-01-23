import 'package:flutter/foundation.dart';

@immutable
class PlaybackState {
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final double speed;
  final double volume;
  final bool isLooping;  // THÊM
  final Duration? sleepTimerRemaining;  // THÊM

  const PlaybackState({
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.speed = 1.0,
    this.volume = 1.0,
    this.isLooping = false,  // THÊM
    this.sleepTimerRemaining,  // THÊM
  });

  PlaybackState copyWith({
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    double? speed,
    double? volume,
    bool? isLooping,  // THÊM
    Duration? sleepTimerRemaining,  // THÊM
  }) {
    return PlaybackState(
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      speed: speed ?? this.speed,
      volume: volume ?? this.volume,
      isLooping: isLooping ?? this.isLooping,  // THÊM
      sleepTimerRemaining: sleepTimerRemaining ?? this.sleepTimerRemaining,  // THÊM
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PlaybackState &&
        other.isPlaying == isPlaying &&
        other.position == position &&
        other.duration == duration &&
        other.speed == speed &&
        other.volume == volume &&
        other.isLooping == isLooping &&  // THÊM
        other.sleepTimerRemaining == sleepTimerRemaining;  // THÊM
  }

  @override
  int get hashCode {
    return Object.hash(
      isPlaying,
      position,
      duration,
      speed,
      volume,
      isLooping,  // THÊM
      sleepTimerRemaining,  // THÊM
    );
  }
}