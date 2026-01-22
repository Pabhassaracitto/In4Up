import 'dart:async';
import 'package:flutter/foundation.dart';
import '../audio/audio_player_service.dart';
import '../models/segment.dart';

class PlayerProvider extends ChangeNotifier {
  final AudioPlayerService _audioService = AudioPlayerService();

  PlaybackState _state = const PlaybackState();
  String? _currentSongTitle;
  String? _currentSongArtist;
  String? _currentSongPath;

  // === A-B LOOP ===
  Duration? _loopStart;
  Duration? _loopEnd;
  bool _isLooping = false;
  int _loopCount = 0;
  int _maxLoopCount = 0;

  // === SLEEP TIMER ===
  Timer? _sleepTimer;
  Duration? _sleepDuration;
  DateTime? _sleepEndTime;

  // === SAVED POSITIONS ===
  final Map<String, int> _savedPositions = {};
  Timer? _positionSaverTimer;

  // === SEGMENTS ===
  final List<Segment> _segments = [];

  // ==================== GETTERS ====================

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
  bool get hasSleepTimer => _sleepTimer != null;

  Duration? get sleepRemaining {
    if (_sleepEndTime == null) return null;
    final remaining = _sleepEndTime!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  // Segments
  List<Segment> get segments => List.unmodifiable(_segments);

  List<double> get speedPresets => AudioPlayerService.speedPresets;

  // ==================== CONSTRUCTOR ====================

  PlayerProvider() {
    _audioService.stateStream.listen((state) {
      _state = state;

      // Check A-B loop
      if (_isLooping && _loopEnd != null) {
        _checkLoopPosition(state.position);
      }

      notifyListeners();
    });

    // Auto save position every 10 seconds
    _positionSaverTimer = Timer.periodic(
      const Duration(seconds: 10),
          (_) => _saveCurrentPosition(),
    );
  }

  // ==================== BASIC PLAYBACK ====================

  Future<void> loadSong({
    required String path,
    String? title,
    String? artist,
    bool autoPlay = false,
  }) async {
    _currentSongPath = path;
    _currentSongTitle = title ?? path.split('/').last;
    _currentSongArtist = artist;

    clearLoop();
    notifyListeners();

    final success = await _audioService.loadFile(path);

    if (success) {
      // Restore saved position
      final savedMs = _savedPositions[path];
      if (savedMs != null && savedMs > 10000) {
        await seek(Duration(milliseconds: savedMs));
      }

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

  // ==================== QUICK SEEK ====================

  Future<void> seekRelative(int seconds) async {
    final currentPosition = _state.position;
    final duration = _state.duration;

    var newPosition = currentPosition + Duration(seconds: seconds);

    if (newPosition < Duration.zero) {
      newPosition = Duration.zero;
    } else if (duration != Duration.zero && newPosition > duration) {
      newPosition = duration;
    }

    await seek(newPosition);
  }

  Future<void> replay5() async => seekRelative(-5);
  Future<void> replay10() async => seekRelative(-10);
  Future<void> replay30() async => seekRelative(-30);

  Future<void> forward5() async => seekRelative(5);
  Future<void> forward10() async => seekRelative(10);
  Future<void> forward30() async => seekRelative(30);

  // ==================== SPEED & PITCH ====================

  Future<void> setSpeed(double speed) async {
    await _audioService.setSpeed(speed);
  }

  Future<void> setPitch(double semitones) async {
    await _audioService.setPitch(semitones);
  }

  Future<void> setVolume(double volume) async {
    await _audioService.setVolume(volume);
  }

  // ==================== A-B LOOP ====================

  void setLoopStart() {
    _loopStart = _state.position;
    notifyListeners();
  }

  void setLoopEnd() {
    if (_loopStart == null) return;

    _loopEnd = _state.position;

    if (_loopEnd! <= _loopStart!) {
      final temp = _loopStart;
      _loopStart = _loopEnd;
      _loopEnd = temp;
    }

    _isLooping = true;
    _loopCount = 0;
    notifyListeners();
  }

  void setLoop(Duration start, Duration end, {int repeatCount = 0}) {
    _loopStart = start;
    _loopEnd = end;
    _maxLoopCount = repeatCount;
    _isLooping = true;
    _loopCount = 0;
    seek(start);
    notifyListeners();
  }

  void setMaxLoopCount(int count) {
    _maxLoopCount = count;
    notifyListeners();
  }

  void _checkLoopPosition(Duration currentPosition) {
    if (!_isLooping || _loopEnd == null || _loopStart == null) return;

    if (currentPosition >= _loopEnd!) {
      _loopCount++;

      if (_maxLoopCount > 0 && _loopCount >= _maxLoopCount) {
        clearLoop();
        return;
      }

      seek(_loopStart!);
    }
  }

  void clearLoop() {
    _loopStart = null;
    _loopEnd = null;
    _isLooping = false;
    _loopCount = 0;
    _maxLoopCount = 0;
    notifyListeners();
  }

  Duration? get loopDuration {
    if (_loopStart == null || _loopEnd == null) return null;
    return _loopEnd! - _loopStart!;
  }

  // ==================== SAVE LOOP AS SEGMENT ====================

  Segment? saveLoopAsSegment({
    required String title,
    SegmentType type = SegmentType.favorite,
    DifficultyLevel difficulty = DifficultyLevel.medium,
    String? note,
    List<String> tags = const [],
  }) {
    if (_loopStart == null || _loopEnd == null || _currentSongPath == null) {
      return null;
    }

    final segment = Segment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      audioPath: _currentSongPath!,
      title: title,
      startTime: _loopStart!,
      endTime: _loopEnd!,
      type: type,
      difficulty: difficulty,
      repeatCount: difficulty == DifficultyLevel.hard
          ? 5
          : difficulty == DifficultyLevel.medium
          ? 3
          : 1,
      note: note,
      createdAt: DateTime.now(),
      tags: tags,
    );

    _segments.add(segment);
    notifyListeners();

    return segment;
  }

  void deleteSegment(String id) {
    _segments.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  List<Segment> getSegmentsForCurrentSong() {
    if (_currentSongPath == null) return [];
    return _segments.where((s) => s.audioPath == _currentSongPath).toList();
  }

  Future<void> playSegment(Segment segment) async {
    setLoop(
      segment.startTime,
      segment.endTime,
      repeatCount: segment.repeatCount,
    );
  }

  // ==================== SLEEP TIMER ====================

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

  void setSleepTimerMinutes(int minutes) {
    setSleepTimer(Duration(minutes: minutes));
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepDuration = null;
    _sleepEndTime = null;
    notifyListeners();
  }

  static const List<int> sleepTimerPresets = [15, 30, 45, 60, 90, 120];

  // ==================== POSITION SAVER ====================

  void _saveCurrentPosition() {
    if (_currentSongPath != null && _state.position.inSeconds > 5) {
      _savedPositions[_currentSongPath!] = _state.position.inMilliseconds;
    }
  }

  Duration? getSavedPosition(String path) {
    final savedMs = _savedPositions[path];
    if (savedMs == null) return null;
    return Duration(milliseconds: savedMs);
  }

  void clearSavedPosition(String path) {
    _savedPositions.remove(path);
  }

  void clearAllSavedPositions() {
    _savedPositions.clear();
  }

  // ==================== DISPOSE ====================

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _positionSaverTimer?.cancel();
    _audioService.dispose();
    super.dispose();
  }
}