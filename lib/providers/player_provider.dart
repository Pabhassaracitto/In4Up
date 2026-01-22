import 'dart:async';
import 'package:flutter/foundation.dart';
import '../audio/audio_player_service.dart';

class PlayerProvider extends ChangeNotifier {
  final AudioPlayerService _audioService = AudioPlayerService();

  PlaybackState _state = const PlaybackState();
  String? _currentSongTitle;
  String? _currentSongArtist;
  String? _currentSongPath;

  // === A-B LOOP VARIABLES ===
  Duration? _loopStart;
  Duration? _loopEnd;
  bool _isLooping = false;
  int _loopCount = 0;
  int _maxLoopCount = 0; // 0 = vô hạn
  StreamSubscription? _loopSubscription;

  // === SLEEP TIMER VARIABLES ===
  Timer? _sleepTimer;
  Duration? _sleepDuration;
  DateTime? _sleepEndTime;

  // === POSITION SAVER ===
  Timer? _positionSaverTimer;
  final Map<String, int> _savedPositions = {}; // path -> milliseconds

  // ========== GETTERS ==========

  // Basic getters
  PlaybackState get state => _state;
  String? get currentSongTitle => _currentSongTitle;
  String? get currentSongArtist => _currentSongArtist;
  String? get currentSongPath => _currentSongPath;
  bool get isPlaying => _state.status == PlaybackStatus.playing;
  bool get isPaused => _state.status == PlaybackStatus.paused;
  bool get isStopped => _state.status == PlaybackStatus.stopped;
  bool get isLoading => _state.status == PlaybackStatus.loading;

  // A-B Loop getters
  Duration? get loopStart => _loopStart;
  Duration? get loopEnd => _loopEnd;
  bool get isLooping => _isLooping;
  int get loopCount => _loopCount;
  int get maxLoopCount => _maxLoopCount;

  // Sleep timer getters
  Duration? get sleepDuration => _sleepDuration;
  DateTime? get sleepEndTime => _sleepEndTime;
  bool get hasSleepTimer => _sleepTimer != null && _sleepEndTime != null;

  Duration? get sleepRemaining {
    if (_sleepEndTime == null) return null;
    final remaining = _sleepEndTime!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  // Speed presets
  List<double> get speedPresets => AudioPlayerService.speedPresets;

  // ========== CONSTRUCTOR ==========

  PlayerProvider() {
    _initListeners();
  }

  void _initListeners() {
    // Listen to playback state
    _audioService.stateStream.listen((state) {
      _state = state;

      // Check A-B loop
      if (_isLooping && _loopEnd != null) {
        _checkLoopPosition(state.position);
      }

      notifyListeners();
    });

    // Start position saver
    _startPositionSaver();
  }

  // ========== BASIC PLAYBACK ==========

  /// Load and optionally play a song
  Future<void> loadSong({
    required String path,
    String? title,
    String? artist,
    bool autoPlay = false,
  }) async {
    _currentSongPath = path;
    _currentSongTitle = title ?? path.split('/').last;
    _currentSongArtist = artist;

    // Clear any existing loop
    clearLoop();

    notifyListeners();

    final success = await _audioService.loadFile(path);

    if (success) {
      // Restore saved position if exists
      await _restoreSavedPosition(path);

      if (autoPlay) {
        await play();
      }
    }
  }

  Future<void> play() async {
    await _audioService.play();
  }

  Future<void> pause() async {
    await _audioService.pause();
    // Save position when paused
    _saveCurrentPosition();
  }

  Future<void> togglePlayPause() async {
    if (isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> stop() async {
    await _audioService.stop();
    _saveCurrentPosition();
  }

  Future<void> seek(Duration position) async {
    await _audioService.seek(position);
  }

  Future<void> seekToPercent(double percent) async {
    final duration = _state.duration;
    if (duration == Duration.zero) return;

    final position = Duration(
      milliseconds: (duration.inMilliseconds * percent).round(),
    );
    await seek(position);
  }

  // ========== QUICK SEEK (TUA NHANH) ==========

  /// Seek relative to current position (seconds can be negative)
  Future<void> seekRelative(int seconds) async {
    final currentPosition = _state.position;
    final duration = _state.duration;

    var newPosition = currentPosition + Duration(seconds: seconds);

    // Clamp to valid range
    if (newPosition < Duration.zero) {
      newPosition = Duration.zero;
    } else if (duration != Duration.zero && newPosition > duration) {
      newPosition = duration;
    }

    await seek(newPosition);
  }

  /// Quick replay buttons
  Future<void> replay5() async => await seekRelative(-5);
  Future<void> replay10() async => await seekRelative(-10);
  Future<void> replay30() async => await seekRelative(-30);

  Future<void> forward5() async => await seekRelative(5);
  Future<void> forward10() async => await seekRelative(10);
  Future<void> forward30() async => await seekRelative(30);

  // ========== SPEED & PITCH ==========

  /// Set speed (0.05 - 10.0)
  Future<void> setSpeed(double speed) async {
    await _audioService.setSpeed(speed);
  }

  /// Set pitch in semitones (-24 to +24)
  Future<void> setPitch(double semitones) async {
    await _audioService.setPitch(semitones);
  }

  /// Set volume (0.0 - 1.0)
  Future<void> setVolume(double volume) async {
    await _audioService.setVolume(volume);
  }

  // ========== A-B LOOP ==========

  /// Set loop start point (A)
  void setLoopStart() {
    _loopStart = _state.position;
    notifyListeners();
  }

  /// Set loop end point (B) and start looping
  void setLoopEnd() {
    if (_loopStart == null) return;

    _loopEnd = _state.position;

    // Ensure A < B
    if (_loopEnd! <= _loopStart!) {
      final temp = _loopStart;
      _loopStart = _loopEnd;
      _loopEnd = temp;
    }

    _isLooping = true;
    _loopCount = 0;
    notifyListeners();
  }

  /// Set A-B loop with specific positions
  void setLoop(Duration start, Duration end, {int repeatCount = 0}) {
    _loopStart = start;
    _loopEnd = end;
    _maxLoopCount = repeatCount;
    _isLooping = true;
    _loopCount = 0;

    // Seek to start
    seek(start);
    notifyListeners();
  }

  /// Set maximum loop count (0 = infinite)
  void setMaxLoopCount(int count) {
    _maxLoopCount = count;
    notifyListeners();
  }

  /// Check if we need to loop back
  void _checkLoopPosition(Duration currentPosition) {
    if (!_isLooping || _loopEnd == null || _loopStart == null) return;

    if (currentPosition >= _loopEnd!) {
      _loopCount++;

      // Check if reached max loops
      if (_maxLoopCount > 0 && _loopCount >= _maxLoopCount) {
        clearLoop();
        return;
      }

      // Seek back to start
      seek(_loopStart!);
    }
  }

  /// Clear A-B loop
  void clearLoop() {
    _loopStart = null;
    _loopEnd = null;
    _isLooping = false;
    _loopCount = 0;
    _maxLoopCount = 0;
    notifyListeners();
  }

  /// Get loop duration
  Duration? get loopDuration {
    if (_loopStart == null || _loopEnd == null) return null;
    return _loopEnd! - _loopStart!;
  }

  // ========== SLEEP TIMER ==========

  /// Set sleep timer
  void setSleepTimer(Duration duration) {
    cancelSleepTimer();

    if (duration == Duration.zero) return;

    _sleepDuration = duration;
    _sleepEndTime = DateTime.now().add(duration);

    _sleepTimer = Timer(duration, () {
      pause();
      _sleepDuration = null;
      _sleepEndTime = null;
      _sleepTimer = null;
      notifyListeners();
    });

    notifyListeners();
  }

  /// Set sleep timer by minutes
  void setSleepTimerMinutes(int minutes) {
    setSleepTimer(Duration(minutes: minutes));
  }

  /// Cancel sleep timer
  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepDuration = null;
    _sleepEndTime = null;
    notifyListeners();
  }

  /// Sleep timer presets (in minutes)
  static const List<int> sleepTimerPresets = [15, 30, 45, 60, 90, 120];

  // ========== REMEMBER POSITION ==========

  void _startPositionSaver() {
    _positionSaverTimer?.cancel();
    _positionSaverTimer = Timer.periodic(
      const Duration(seconds: 10),
          (_) => _saveCurrentPosition(),
    );
  }

  void _saveCurrentPosition() {
    if (_currentSongPath != null && _state.position.inSeconds > 5) {
      _savedPositions[_currentSongPath!] = _state.position.inMilliseconds;
    }
  }

  Future<void> _restoreSavedPosition(String path) async {
    final savedMs = _savedPositions[path];
    if (savedMs != null && savedMs > 10000) { // > 10 seconds
      final savedPosition = Duration(milliseconds: savedMs);
      await seek(savedPosition);
    }
  }

  /// Get saved position for a path
  Duration? getSavedPosition(String path) {
    final savedMs = _savedPositions[path];
    if (savedMs == null) return null;
    return Duration(milliseconds: savedMs);
  }

  /// Clear saved position for a path
  void clearSavedPosition(String path) {
    _savedPositions.remove(path);
  }

  /// Clear all saved positions
  void clearAllSavedPositions() {
    _savedPositions.clear();
  }

  // ========== DISPOSE ==========

  @override
  void dispose() {
    _loopSubscription?.cancel();
    _sleepTimer?.cancel();
    _positionSaverTimer?.cancel();
    _audioService.dispose();
    super.dispose();
  }
}