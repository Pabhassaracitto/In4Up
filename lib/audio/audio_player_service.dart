import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

import '../ffi/ultra_engine_ffi_v2.dart';
import '../models/playback_state.dart';

/// Audio Player Service with UltraTimeStretch V2 Engine
class AudioPlayerService {
  static AudioPlayerService? _instance;

  late final UltraEngineFFIV2 _engineV2; // ← V2 Engine
  late final AudioPlayer _audioPlayer;

  final _stateController = BehaviorSubject<PlaybackState>.seeded(
    const PlaybackState(),
  );

  bool _engineInitialized = false;

  // Speed range (V2 hỗ trợ extreme speeds)
  static const double minSpeed = 0.05; // V2: 0.05x minimum
  static const double maxSpeed = 10.0; // V2: 10x maximum

  // V2 Enhanced speed presets
  static const List<double> speedPresets = [
    // Extreme slow (V2 optimized)
    0.05, 0.1, 0.15, 0.2, 0.25, 0.3, 0.4, 0.5,
    // Normal range
    0.6, 0.7, 0.75, 0.8, 0.9, 1.0, 1.1, 1.25, 1.5, 1.75, 2.0,
    // Fast range (V2 optimized)
    2.5, 3.0, 4.0, 5.0, 6.0, 8.0, 10.0
  ];

  AudioPlayerService._internal() {
    _engineV2 = UltraEngineFFIV2();
    _audioPlayer = AudioPlayer();
    _initializeEngine();
    _setupListeners();
  }

  factory AudioPlayerService() {
    _instance ??= AudioPlayerService._internal();
    return _instance!;
  }

  /// Initialize UltraTimeStretch V2 Engine
  Future<void> _initializeEngine() async {
    try {
      final loaded = _engineV2.load();
      if (!loaded) {
        debugPrint('Failed to load UltraTimeStretch V2 library');
        return;
      }

      // V2 initialization with enhanced options
      _engineInitialized = _engineV2.initialize(
        sampleRate: 44100,
        channels: 2,
        quality: UltraQuality.highQuality, // High for mobile, not Ultra
        preserveTransients: true, // V2 feature
        preserveFormants: true, // V2 feature
      );

      if (_engineInitialized) {
        debugPrint('UltraTimeStretch V2 Engine initialized');
        debugPrint('Version: ${_engineV2.getVersion()}');
        debugPrint('Features: ${_engineV2.getSupportedFeatures()}');
      }
    } catch (e) {
      debugPrint('Error initializing V2 engine: $e');
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
        status = PlaybackStatus.completed;
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

      await _audioPlayer.setFilePath(filePath);

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

  /// Set playback speed (0.05 - 10.0) with V2 Engine
  Future<void> setSpeed(double speed) async {
    final clampedSpeed = speed.clamp(minSpeed, maxSpeed);

    try {
      // V2 Engine handles ALL speeds (0.05 - 10.0)
      if (_engineInitialized) {
        _engineV2.setSpeed(clampedSpeed);

        // Log which engine mode is used
        if (clampedSpeed < 0.15) {
          debugPrint(
              'V2: Multi-Resolution PV at ${clampedSpeed}x (extreme slow)');
        } else if (clampedSpeed < 0.5) {
          debugPrint('V2: Enhanced Phase Vocoder at ${clampedSpeed}x');
        } else if (clampedSpeed > 2.0) {
          debugPrint('V2: Fast WSOLA at ${clampedSpeed}x');
        } else {
          debugPrint('V2: Hybrid mode at ${clampedSpeed}x');
        }
      }

      // AudioPlayer for basic speeds (0.25 - 2.0)
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

    if (_engineInitialized) {
      _engineV2.setPitch(clampedPitch);
    }

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

  /// Get engine info
  Map<String, dynamic> getEngineInfo() {
    if (!_engineInitialized) {
      return {'initialized': false};
    }

    return {
      'initialized': true,
      'version': _engineV2.getVersion(),
      'features': _engineV2.getSupportedFeatures(),
      'latency': _engineV2.getLatency(),
      'currentSpeed': _engineV2.getSpeed(),
    };
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
    _engineV2.dispose();
    await _stateController.close();
    _instance = null;
  }
}
