import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

import 'ultra_engine_ffi.dart';

/// Playback state enum
enum PlaybackStatus {
  stopped,
  loading,
  playing,
  paused,
  buffering,
  error,
}

/// Current playback state
class PlaybackState {
  final PlaybackStatus status;
  final Duration position;
  final Duration duration;
  final double speed;
  final double pitch;
  final double volume;
  final String? errorMessage;

  const PlaybackState({
    this.status = PlaybackStatus.stopped,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.speed = 1.0,
    this.pitch = 0.0,
    this.volume = 1.0,
    this.errorMessage,
  });

  PlaybackState copyWith({
    PlaybackStatus? status,
    Duration? position,
    Duration? duration,
    double? speed,
    double? pitch,
    double? volume,
    String? errorMessage,
  }) {
    return PlaybackState(
      status: status ?? this.status,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      speed: speed ?? this.speed,
      pitch: pitch ?? this.pitch,
      volume: volume ?? this.volume,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Audio Player Service with UltraTimeStretch Engine
class AudioPlayerService {
  static AudioPlayerService? _instance;

  late final UltraTimeStretchFFI _engine;
  late final AudioPlayer _audioPlayer;

  final _stateController = BehaviorSubject<PlaybackState>.seeded(
    const PlaybackState(),
  );

  bool _engineInitialized = false;

  // Speed range
  static const double minSpeed = 0.05;
  static const double maxSpeed = 10.0;
  static const List<double> speedPresets = [
    0.1, 0.15, 0.2, 0.25, 0.3, 0.4, 0.5, 0.6, 0.7, 0.75, 0.8, 0.9,
    1.0, 1.1, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0, 4.0, 5.0
  ];

  AudioPlayerService._internal() {
    _engine = UltraTimeStretchFFI();
    _audioPlayer = AudioPlayer();
    _initializeEngine();
    _setupListeners();
  }

  factory AudioPlayerService() {
    _instance ??= AudioPlayerService._internal();
    return _instance!;
  }

  /// Initialize UltraTimeStretch Engine
  Future<void> _initializeEngine() async {
    try {
      final loaded = _engine.load();
      if (!loaded) {
        debugPrint('Failed to load UltraTimeStretch library');
        return;
      }

      _engineInitialized = _engine.initialize(
        sampleRate: 44100,
        channels: 2,
        quality: UltraQuality.highQuality,
      );

      if (_engineInitialized) {
        debugPrint('UltraTimeStretch Engine initialized: ${_engine.getVersion()}');
      }
    } catch (e) {
      debugPrint('Error initializing engine: $e');
    }
  }

  void _setupListeners() {
    // Listen to AudioPlayer state changes
    _audioPlayer.playerStateStream.listen((state) {
      PlaybackStatus status;
      if (state.processingState == ProcessingState.loading) {
        status = PlaybackStatus.loading;
      } else if (state.processingState == ProcessingState.buffering) {
        status = PlaybackStatus.buffering;
      } else if (state.playing) {
        status = PlaybackStatus.playing;
      } else if (state.processingState == ProcessingState.completed) {
        status = PlaybackStatus.stopped;
      } else {
        status = PlaybackStatus.paused;
      }

      _updateState(status: status);
    });

    // Listen to position changes
    _audioPlayer.positionStream.listen((position) {
      _updateState(position: position);
    });

    // Listen to duration changes
    _audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        _updateState(duration: duration);
      }
    });
  }

  /// Get current playback state stream
  Stream<PlaybackState> get stateStream => _stateController.stream;

  /// Get current state
  PlaybackState get currentState => _stateController.value;

  /// Load audio file
  Future<bool> loadFile(String filePath) async {
    try {
      _updateState(status: PlaybackStatus.loading);

      // Use just_audio for file loading and basic playback
      await _audioPlayer.setFilePath(filePath);

      // Get duration
      final duration = _audioPlayer.duration;
      if (duration != null) {
        _updateState(duration: duration);
      }

      _updateState(status: PlaybackStatus.paused);

      debugPrint('Loaded file: $filePath');
      return true;

    } catch (e) {
      debugPrint('Error loading file: $e');
      _updateState(
        status: PlaybackStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// Play audio
  Future<void> play() async {
    try {
      await _audioPlayer.play();
      _updateState(status: PlaybackStatus.playing);
    } catch (e) {
      debugPrint('Error playing: $e');
    }
  }

  /// Pause audio
  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
      _updateState(status: PlaybackStatus.paused);
    } catch (e) {
      debugPrint('Error pausing: $e');
    }
  }

  /// Stop audio
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.seek(Duration.zero);
      _updateState(
        status: PlaybackStatus.stopped,
        position: Duration.zero,
      );
    } catch (e) {
      debugPrint('Error stopping: $e');
    }
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    try {
      await _audioPlayer.seek(position);
      _updateState(position: position);
    } catch (e) {
      debugPrint('Error seeking: $e');
    }
  }

  /// Set playback speed (0.05 - 10.0)
  Future<void> setSpeed(double speed) async {
    final clampedSpeed = speed.clamp(minSpeed, maxSpeed);

    try {
      // For extreme speeds, use UltraTimeStretch Engine
      if (_engineInitialized && (clampedSpeed < 0.5 || clampedSpeed > 2.0)) {
        _engine.setSpeed(clampedSpeed);
        debugPrint('Using UltraTimeStretch Engine at ${clampedSpeed}x');
      }

      // AudioPlayer supports 0.5 - 2.0
      final audioPlayerSpeed = clampedSpeed.clamp(0.25, 2.0);
      await _audioPlayer.setSpeed(audioPlayerSpeed);

      _updateState(speed: clampedSpeed);

    } catch (e) {
      debugPrint('Error setting speed: $e');
    }
  }

  /// Set pitch shift in semitones (-24 to +24)
  Future<void> setPitch(double semitones) async {
    final clampedPitch = semitones.clamp(-24.0, 24.0);
    _updateState(pitch: clampedPitch);
  }

  /// Set volume (0.0 - 1.0)
  Future<void> setVolume(double volume) async {
    try {
      await _audioPlayer.setVolume(volume.clamp(0.0, 1.0));
      _updateState(volume: volume);
    } catch (e) {
      debugPrint('Error setting volume: $e');
    }
  }

  void _updateState({
    PlaybackStatus? status,
    Duration? position,
    Duration? duration,
    double? speed,
    double? pitch,
    double? volume,
    String? errorMessage,
  }) {
    _stateController.add(
      _stateController.value.copyWith(
        status: status,
        position: position,
        duration: duration,
        speed: speed,
        pitch: pitch,
        volume: volume,
        errorMessage: errorMessage,
      ),
    );
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _audioPlayer.dispose();
    _engine.dispose();
    await _stateController.close();
    _instance = null;
  }
}