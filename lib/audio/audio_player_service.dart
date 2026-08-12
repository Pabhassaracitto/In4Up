import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:path/path.dart' as path;

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
    _audioPlayer.playerStateStream.listen((state) {
      PlaybackStatus status;

      // ── FIX: Check completed TRƯỚC khi check playing ──
      if (state.processingState == ProcessingState.completed) {
        status = PlaybackStatus.completed;
      } else if (state.processingState == ProcessingState.loading) {
        status = PlaybackStatus.loading;
      } else if (state.processingState == ProcessingState.buffering) {
        status = PlaybackStatus.buffering;
      } else if (state.playing) {
        status = PlaybackStatus.playing;
      } else {
        status = PlaybackStatus.paused;
      }

      _updateState(status: status);
    });

    _audioPlayer.positionStream.listen((position) {
      _updateState(position: position);
    });

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

  // Lưu đường dẫn tạm đã sanitize để dọn khi dispose/load mới
  String? _tempSanitizedPath;

  bool _needsSanitize(String path) {
    // Ký tự đặc biệt gây lỗi trên Windows Media Foundation / Uri.decodeFull
    // - % : gây Illegal percent encoding
    // - ’ ‘ “ ” … và các non-ascii >127
    if (path.contains('%')) return true;
    if (path.contains('’') || path.contains('‘') || path.contains('“') || path.contains('”')) return true;
    for (final c in path.runes) {
      if (c > 127) return true;
    }
    return false;
  }

  Future<String> _getSafeFilePath(String original) async {
    // Nếu không cần sanitize, trả về gốc
    if (!_needsSanitize(original)) return original;
    try {
      final srcFile = File(original);
      // Tạo tên an toàn: chỉ giữ ascii alnum + _ -
      final ext = original.split('.').last;
      final safeName = 'in2up_play_${DateTime.now().millisecondsSinceEpoch}_${original.hashCode.abs()}.$ext'
          .replaceAll(RegExp(r'[^A-Za-z0-9_\-.]'), '_');
      final tempDir = Directory.systemTemp;
      final destPath = path.join(tempDir.path, safeName);
      if (File(destPath).existsSync()) {
        try { File(destPath).deleteSync(); } catch (_) {}
      }
      // Copy file để tránh lỗi ký tự đặc biệt trên Windows
      if (srcFile.existsSync()) {
        await srcFile.copy(destPath);
        _tempSanitizedPath = destPath;
        debugPrint('🔧 Sanitized playback path: $original -> $destPath');
        return destPath;
      }
    } catch (e) {
      debugPrint('⚠️ Sanitize failed, fallback to original: $e');
    }
    return original;
  }

  /// Load audio file - có fallback cho đường dẫn chứa ký tự đặc biệt
  Future<bool> loadFile(String filePath) async {
    String safePath = filePath;
    try {
      _updateState(status: PlaybackStatus.loading);

      // Thử sanitize nếu cần
      safePath = await _getSafeFilePath(filePath);

      // Cố gắng load với nhiều cách
      try {
        // C1: setFilePath trực tiếp (khuyến nghị)
        await _audioPlayer.setFilePath(safePath);
      } catch (e) {
        debugPrint('⚠️ setFilePath failed ($e), trying AudioSource.uri');
        try {
          // C2: Dùng Uri.file - xử lý đúng ký tự đặc biệt & space
          final uri = Uri.file(safePath);
          debugPrint('Trying Uri.file: $uri');
          await _audioPlayer.setAudioSource(AudioSource.uri(uri));
        } catch (e2) {
          debugPrint('⚠️ AudioSource.uri failed ($e2), trying original path');
          // C3: Fallback về file gốc nếu safePath khác gốc
          if (safePath != filePath) {
            try {
              await _audioPlayer.setFilePath(filePath);
              safePath = filePath;
            } catch (e3) {
              debugPrint('❌ All load methods failed: $e3');
              rethrow;
            }
          } else {
            rethrow;
          }
        }
      }

      // Đợi duration khả dụng (just_audio có thể cần tí thời gian)
      Duration? duration = _audioPlayer.duration;
      if (duration == null) {
        // Đợi tối đa 1.5s cho durationStream
        try {
          duration = await _audioPlayer.durationStream
              .firstWhere((d) => d != null)
              .timeout(const Duration(milliseconds: 1500));
        } catch (_) {
          duration = _audioPlayer.duration;
        }
      }

      if (duration != null) {
        _updateState(duration: duration);
        debugPrint('✅ Loaded duration: $duration');
      } else {
        debugPrint('⚠️ Duration still null after load, file may be unreadable but continuing');
        // Vẫn cho phép play, progress sẽ update sau
      }

      _updateState(status: PlaybackStatus.paused);

      debugPrint('Loaded file: $filePath (safe: $safePath)');
      return true;
    } catch (e, st) {
      debugPrint('Error loading file: $e');
      debugPrint('Stack: $st');
      debugPrint('Original path: $filePath');
      debugPrint('Safe path: $safePath');
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
