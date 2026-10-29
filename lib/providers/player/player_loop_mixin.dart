// lib/providers/player/player_loop_mixin.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../audio/audio_player_service.dart';
import '../../models/playback_state.dart';
import '../../services/storage_service.dart';
import '../player_provider.dart'; // For ModeSettings

enum TrackRepeatResult { repeated, completed, cancelled }

mixin PlayerLoopMixin on ChangeNotifier {
  // Dependencies required from PlayerProvider
  AudioPlaybackPort get audioService;
  StorageService get storage;
  String? get currentSongPath;
  bool get wantsPlayback;
  ModeSettings get modeSettings;
  int get currentSegmentIndex;
  PlaybackState get state;

  int get totalLoopsToday;
  set totalLoopsToday(int value);

  void playNextSegment();
  Future<void> seek(Duration position);

  // State variables
  Duration? _loopStart;
  Duration? _loopEnd;
  Duration? _pendingLoopA;
  bool _isLooping = false;
  int _loopCount = 0;
  int _maxLoopCount = 0;
  bool _repeatTrack = false;
  bool _hasHandledCompletion = false;
  int _repeatGeneration = 0;

  double _gapDuration = 0.0;
  bool _isWaitingGap = false;
  Timer? _gapTimer;
  bool _loopTransitioning = false;
  Duration _silenceDuration = Duration.zero;

  // Getters
  Duration? get loopStart => _loopStart;
  Duration? get loopEnd => _loopEnd;
  Duration? get pendingLoopA => _pendingLoopA;
  bool get hasCompletedLoop => _loopStart != null && _loopEnd != null;
  bool get isLooping => _isLooping;
  int get loopCount => _loopCount;
  int get maxLoopCount => _maxLoopCount;
  bool get repeatTrack => _repeatTrack;
  double get gapDuration => _gapDuration;
  bool get isWaitingGap => _isWaitingGap;
  bool get hasLoop => _loopStart != null && _loopEnd != null;
  Duration get silenceDuration => _silenceDuration;

  Duration? get loopDuration {
    if (_loopStart == null || _loopEnd == null) return null;
    return _loopEnd! - _loopStart!;
  }

  double get loopProgress {
    if (_maxLoopCount <= 0) return 0.0;
    if (_loopCount.isNaN || _maxLoopCount.isNaN) return 0.0;
    return (_loopCount / _maxLoopCount).clamp(0.0, 1.0);
  }

  bool get hasHandledCompletion => _hasHandledCompletion;
  set hasHandledCompletion(bool value) {
    _hasHandledCompletion = value;
  }

  void restoreLoopSettings(double savedGapDuration) {
    _gapDuration = savedGapDuration;
  }

  void updateLoopSettings({required double defaultGap, required int defaultLoop}) {
    if (!_isLooping) {
      _gapDuration = defaultGap;
      _maxLoopCount = defaultLoop;
      notifyListeners();
    }
  }

  void setLoopPointA(Duration position) {
    _pendingLoopA = position;
    _loopStart = position;
    _loopEnd = null;
    notifyListeners();
  }

  void setLoopPointB(Duration position) {
    if (_pendingLoopA == null) {
      setLoopPointA(position);
      return;
    }
    final a = _pendingLoopA!;
    if (position <= a) {
      _loopStart = position;
      _loopEnd = a;
    } else {
      _loopStart = a;
      _loopEnd = position;
    }
    _pendingLoopA = null;
    _isLooping = true;
    notifyListeners();
  }

  void clearLoopPoints() {
    _pendingLoopA = null;
    _repeatTrack = false;
    clearLoop();
  }

  void setLoopCount(int count) {
    _maxLoopCount = count;

    if (_loopStart == null) {
      _repeatTrack = (count != 0);
      if (!_repeatTrack) cancelRepeatWait();
    }
    debugPrint('🔁 setLoopCount: max=$_maxLoopCount '
        'repeatTrack=$_repeatTrack loopStart=$_loopStart');
    notifyListeners();
  }

  void setLoopStart() {
    _loopStart = state.position;
    notifyListeners();
  }

  void setLoopEnd() {
    if (_loopStart == null) return;
    _loopEnd = state.position;

    if (_loopEnd! <= _loopStart!) {
      final temp = _loopStart;
      _loopStart = _loopEnd;
      _loopEnd = temp;
    }

    _isLooping = true;
    _loopCount = 0;

    if (_gapDuration == 0) {
      _gapDuration = modeSettings.defaultGapDuration;
    }
    if (_maxLoopCount == 0) {
      _maxLoopCount = modeSettings.defaultLoopCount;
    }

    notifyListeners();
  }

  /// Returns whether to repeat, advance the queue, or ignore a cancelled
  /// callback. A delayed gap must never restart a different song or undo pause.
  Future<TrackRepeatResult> handleRepeatTrack() async {
    final source = currentSongPath;
    final generation = _repeatGeneration;
    bool stillCurrent() => source != null &&
        source == currentSongPath &&
        generation == _repeatGeneration &&
        _repeatTrack &&
        wantsPlayback;

    if (!stillCurrent()) return TrackRepeatResult.cancelled;

    totalLoopsToday++;
    storage.incrementLoopCount();

    if (_maxLoopCount > 0) {
      _loopCount++;
      if (_loopCount >= _maxLoopCount) {
        _repeatTrack = false;
        _loopCount = 0;
        _maxLoopCount = 0;
        notifyListeners();
        return TrackRepeatResult.completed;
      }
    }

    if (_gapDuration > 0 &&
        !_gapDuration.isNaN &&
        !_gapDuration.isInfinite) {
      _isWaitingGap = true;
      notifyListeners();
      await audioService.pause();
      if (!stillCurrent()) return TrackRepeatResult.cancelled;

      final gapMs = (_gapDuration * 1000).clamp(0.0, 30000.0).toInt();
      await Future.delayed(Duration(milliseconds: gapMs));
      if (!stillCurrent()) return TrackRepeatResult.cancelled;
      _isWaitingGap = false;
    }

    await audioService.seek(Duration.zero);
    if (!stillCurrent()) return TrackRepeatResult.cancelled;
    await Future.delayed(const Duration(milliseconds: 150));
    if (!stillCurrent()) return TrackRepeatResult.cancelled;
    await audioService.play();
    if (!stillCurrent()) return TrackRepeatResult.cancelled;

    _hasHandledCompletion = false;
    notifyListeners();
    return TrackRepeatResult.repeated;
  }

  void setLoop(
    Duration start,
    Duration end, {
    int repeatCount = 0,
    double? gapSeconds,
    bool startImmediately = true,
  }) {
    if (end <= start) {
      _loopStart = end;
      _loopEnd = start;
    } else {
      _loopStart = start;
      _loopEnd = end;
    }

    _maxLoopCount =
        repeatCount > 0 ? repeatCount : modeSettings.defaultLoopCount;
    _gapDuration = gapSeconds ?? modeSettings.defaultGapDuration;
    _isLooping = true;
    _loopCount = 0;

    if (startImmediately) seek(start);
    notifyListeners();
  }

  void setMaxLoopCount(int count) {
    _maxLoopCount = count;
    notifyListeners();
  }

  void setGapDuration(double seconds) {
    _gapDuration = (seconds.isNaN ? 0.0 : seconds).clamp(0.0, 30.0);
    storage.saveGapDuration(_gapDuration);
    notifyListeners();
  }

  void setSilenceDuration(Duration duration) {
    if (_silenceDuration == duration) return;
    _silenceDuration = duration;
    notifyListeners();
  }

  void checkLoopPosition(Duration currentPosition, Duration previousPosition) {
    if (!_isLooping || _loopEnd == null || _loopStart == null ||
        _loopTransitioning) return;

    if (currentPosition >= _loopEnd!) {
      _loopCount++;
      totalLoopsToday++;
      storage.incrementLoopCount();

      if (_maxLoopCount > 0 && _loopCount >= _maxLoopCount) {
        _onLoopCompleted();
        return;
      }

      if (_gapDuration > 0) {
        _startGapWait();
      } else {
        final source = currentSongPath;
        final generation = _repeatGeneration;
        final start = _loopStart!;
        _loopTransitioning = true;
        unawaited(seek(start).whenComplete(() {
          if (generation == _repeatGeneration && source == currentSongPath) {
            _loopTransitioning = false;
          }
        }));
      }
    }
  }

  void _startGapWait() {
    _isWaitingGap = true;
    unawaited(audioService.pause());
    notifyListeners();

    _gapTimer?.cancel();
    final generation = _repeatGeneration;
    final source = currentSongPath;
    _gapTimer = Timer(
      Duration(milliseconds: (_gapDuration * 1000).round()),
      () => unawaited(_onGapEnded(generation, source)),
    );
  }

  Future<void> _onGapEnded(int generation, String? source) async {
    bool stillCurrent() => _isLooping && wantsPlayback && source != null &&
        source == currentSongPath && generation == _repeatGeneration;
    if (!stillCurrent() || _loopStart == null) return;
    _gapTimer = null;
    _isWaitingGap = false;
    _loopTransitioning = true;
    await seek(_loopStart!);
    if (!stillCurrent()) return;
    _loopTransitioning = false;
    await audioService.play();
    if (stillCurrent()) notifyListeners();
  }

  void _onLoopCompleted() {
    if (modeSettings.autoAdvanceSegments && currentSegmentIndex >= 0) {
      playNextSegment();
    } else {
      clearLoop();
    }
  }

  void clearLoop() {
    _gapTimer?.cancel();
    _gapTimer = null;
    cancelRepeatWait();
    _pendingLoopA = null;
    _loopStart = null;
    _loopEnd = null;
    _isLooping = false;
    _loopCount = 0;
    _maxLoopCount = 0;
    _isWaitingGap = false;
    _repeatTrack = false;
    _hasHandledCompletion = false;
    notifyListeners();
  }

  void toggleLoopPause() {
    if (_isWaitingGap) {
      _gapTimer?.cancel();
      unawaited(_onGapEnded(_repeatGeneration, currentSongPath));
    }
  }

  void skipToNextLoop() {
    if (!_isLooping || _loopStart == null) return;
    _gapTimer?.cancel();
    _isWaitingGap = false;
    _loopCount++;
    if (_maxLoopCount > 0 && _loopCount >= _maxLoopCount) {
      _onLoopCompleted();
    } else {
      seek(_loopStart!);
    }
  }

  /// Invalidate the asynchronous whole-track repeat delay without clearing
  /// the user's repeat setting (for example, when they press Pause).
  void cancelRepeatWait() {
    _repeatGeneration++;
    _gapTimer?.cancel();
    _gapTimer = null;
    _loopTransitioning = false;
    _isWaitingGap = false;
  }

  void cancelGapTimer() {
    _gapTimer?.cancel();
    _gapTimer = null;
    cancelRepeatWait();
  }
}