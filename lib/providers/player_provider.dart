// lib/providers/player_provider.dart

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../audio/audio_player_service.dart';
import '../models/playback_state.dart';
import '../models/segment.dart';
import '../services/storage_service.dart';

enum VipMode {
  music,
  buddhism,
  english,
}

class ModeSettings {
  final double defaultSpeed;
  final double defaultGapDuration;
  final int defaultLoopCount;
  final bool autoAdvanceSegments;
  final bool showTranscript;

  const ModeSettings({
    required this.defaultSpeed,
    required this.defaultGapDuration,
    required this.defaultLoopCount,
    required this.autoAdvanceSegments,
    required this.showTranscript,
  });

  static const music = ModeSettings(
    defaultSpeed: 1.0,
    defaultGapDuration: 0.0,
    defaultLoopCount: 0,
    autoAdvanceSegments: false,
    showTranscript: false,
  );

  static const buddhism = ModeSettings(
    defaultSpeed: 0.9,
    defaultGapDuration: 3.0,
    defaultLoopCount: 3,
    autoAdvanceSegments: false,
    showTranscript: true,
  );

  static const english = ModeSettings(
    defaultSpeed: 0.75,
    defaultGapDuration: 2.0,
    defaultLoopCount: 5,
    autoAdvanceSegments: true,
    showTranscript: true,
  );

  static ModeSettings forMode(VipMode mode) {
    switch (mode) {
      case VipMode.music:
        return music;
      case VipMode.buddhism:
        return buddhism;
      case VipMode.english:
        return english;
    }
  }
}

class PlayerProvider extends ChangeNotifier {
  final AudioPlayerService _audioService = AudioPlayerService();
  final StorageService _storage = StorageService();

  // === PLAYBACK STATE ===
  PlaybackState _state = const PlaybackState();
  String? _currentSongTitle;
  String? _currentSongArtist;
  String? _currentSongPath;

  // === VIP MODE ===
  VipMode _currentMode = VipMode.music;
  ModeSettings _modeSettings = ModeSettings.music;

  // === A-B LOOP ===
  Duration? _loopStart;
  Duration? _loopEnd;
  bool _isLooping = false;
  int _loopCount = 0;
  int _maxLoopCount = 0;

  double _gapDuration = 0.0;
  bool _isWaitingGap = false;
  Timer? _gapTimer;

  // === SLEEP TIMER ===
  Timer? _sleepTimer;
  Duration? _sleepDuration;
  DateTime? _sleepEndTime;

  // === SAVED POSITIONS ===
  Timer? _positionSaverTimer;

  // === SEGMENTS ===
  final List<Segment> _segments = [];
  int _currentSegmentIndex = -1;

  // === LEARNING STATS ===
  int _totalLoopsToday = 0;
  Duration _totalListeningTime = Duration.zero;
  DateTime? _sessionStartTime;

  // ==================== GETTERS ====================
  PlaybackState get state => _state;
  String? get currentSongTitle => _currentSongTitle;
  String? get currentSongArtist => _currentSongArtist;
  String? get currentSongPath => _currentSongPath;
  bool get isPlaying => _state.status == PlaybackStatus.playing;
  bool get isPaused => _state.status == PlaybackStatus.paused;
  bool get isStopped => _state.status == PlaybackStatus.stopped;
  bool get isLoading => _state.status == PlaybackStatus.loading;

  VipMode get currentMode => _currentMode;
  ModeSettings get modeSettings => _modeSettings;
  bool get isBuddhismMode => _currentMode == VipMode.buddhism;
  bool get isEnglishMode => _currentMode == VipMode.english;
  bool get isMusicMode => _currentMode == VipMode.music;

  Duration? get loopStart => _loopStart;
  Duration? get loopEnd => _loopEnd;
  bool get isLooping => _isLooping;
  int get loopCount => _loopCount;
  int get maxLoopCount => _maxLoopCount;
  double get gapDuration => _gapDuration;
  bool get isWaitingGap => _isWaitingGap;
  bool get hasLoop => _loopStart != null && _loopEnd != null;

  Duration? get loopDuration {
    if (_loopStart == null || _loopEnd == null) return null;
    return _loopEnd! - _loopStart!;
  }

  double get loopProgress {
    if (_maxLoopCount == 0) return 0.0;
    return (_loopCount / _maxLoopCount).clamp(0.0, 1.0);
  }

  Duration? get sleepDuration => _sleepDuration;
  bool get hasSleepTimer => _sleepTimer != null;
  Duration? get sleepRemaining {
    if (_sleepEndTime == null) return null;
    final remaining = _sleepEndTime!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  List<Segment> get segments => List.unmodifiable(_segments);
  int get currentSegmentIndex => _currentSegmentIndex;
  Segment? get currentSegment =>
      _currentSegmentIndex >= 0 && _currentSegmentIndex < _segments.length
          ? _segments[_currentSegmentIndex]
          : null;

  int get totalLoopsToday => _totalLoopsToday;
  Duration get totalListeningTime => _totalListeningTime;

  List<double> get speedPresets => AudioPlayerService.speedPresets;

  // ==================== CONSTRUCTOR ====================
  PlayerProvider() {
    _audioService.stateStream.listen(_onStateChanged);

    _positionSaverTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _saveCurrentPosition(),
    );

    _sessionStartTime = DateTime.now();

    _restoreFromStorage();
  }

  Future<void> _restoreFromStorage() async {
    if (!_storage.isInitialized) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!_storage.isInitialized) return;
    }

    try {
      // Restore Mode
      final savedMode = _storage.getLastMode(); // Corrected method name
      switch (savedMode) {
        case 'buddhism':
          _currentMode = VipMode.buddhism;
          break;
        case 'english':
          _currentMode = VipMode.english;
          break;
        default:
          _currentMode = VipMode.music;
      }
      _modeSettings = ModeSettings.forMode(_currentMode);

      // Restore settings
      _gapDuration = _storage.getGapDuration();

      // Restore segments
      final savedSegments =
          _storage.getAllAudioSegments(); // Corrected method name
      _segments.addAll(savedSegments);

      // Restore stats
      final todayStats = _storage.getDailyStats();
      _totalLoopsToday = todayStats['loops'] as int;

      debugPrint(
          'PlayerProvider restored: Mode=$_currentMode, Segments=${_segments.length}');
      notifyListeners();
    } catch (e) {
      debugPrint('Error restoring PlayerProvider: $e');
    }
  }

  void _onStateChanged(PlaybackState state) {
    final previousPosition = _state.position;

    // ✅ Tối ưu: Chỉ notify khi có thay đổi đáng kể (Status, Speed hoặc Position > 200ms)
    bool shouldNotify = state.status != _state.status ||
        state.speed != _state.speed ||
        (state.position.inMilliseconds - _state.position.inMilliseconds).abs() >
            200;

    _state = state;

    if (_isLooping && _loopEnd != null && !_isWaitingGap) {
      _checkLoopPosition(state.position, previousPosition);
      // Nếu vừa lặp lại (về vạch xuất phát), cần notify ngay để cập nhật thanh tiến trình
      if (state.position < previousPosition) shouldNotify = true;
    }

    if (state.status == PlaybackStatus.playing && _sessionStartTime != null) {
      // Vẫn cộng dồn thời gian chính xác cho stats dựa trên tần suất thực tế của stream
      _totalListeningTime += const Duration(milliseconds: 100);
    }

    if (shouldNotify) {
      notifyListeners();
    }
  }

  // ==================== VIP MODE ====================
  void setMode(VipMode mode) {
    if (_currentMode == mode) return;
    _currentMode = mode;
    _modeSettings = ModeSettings.forMode(mode);

    if (!_isLooping) {
      _gapDuration = _modeSettings.defaultGapDuration;
      _maxLoopCount = _modeSettings.defaultLoopCount;
    }

    _storage.saveLastMode(mode.name); // Corrected method name
    _storage.saveGapDuration(_gapDuration);

    debugPrint('VipMode changed to: ${mode.name}');
    notifyListeners();
  }

  Future<void> applyModeDefaultSpeed() async {
    await setSpeed(_modeSettings.defaultSpeed);
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
    _currentSegmentIndex = -1;

    _storage.saveLastAudioPath(path);

    notifyListeners();

    final success = await _audioService.loadFile(path);
    if (success) {
      final savedMs = _storage.getSavedPosition(path);
      if (savedMs != null && savedMs > 5000) {
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
    final safeSpeed = (speed.isNaN ? 1.0 : speed)
        .clamp(AudioPlayerService.minSpeed, AudioPlayerService.maxSpeed);
    await _audioService.setSpeed(safeSpeed);

    _storage.saveLastPlaybackSpeed(safeSpeed); // Corrected method name
  }

  Future<void> setPitch(double semitones) async {
    final safePitch = (semitones.isNaN ? 0.0 : semitones).clamp(-24.0, 24.0);
    await _audioService.setPitch(safePitch);
  }

  Future<void> setVolume(double volume) async {
    await _audioService.setVolume(volume);
  }

  Future<void> increaseSpeed([double step = 0.1]) async {
    final newSpeed = (_state.speed + step).clamp(
      AudioPlayerService.minSpeed,
      AudioPlayerService.maxSpeed,
    );
    await setSpeed(newSpeed);
  }

  Future<void> decreaseSpeed([double step = 0.1]) async {
    final newSpeed = (_state.speed - step).clamp(
      AudioPlayerService.minSpeed,
      AudioPlayerService.maxSpeed,
    );
    await setSpeed(newSpeed);
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

    if (_gapDuration == 0) {
      _gapDuration = _modeSettings.defaultGapDuration;
    }

    if (_maxLoopCount == 0) {
      _maxLoopCount = _modeSettings.defaultLoopCount;
    }

    notifyListeners();
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
        repeatCount > 0 ? repeatCount : _modeSettings.defaultLoopCount;
    _gapDuration = gapSeconds ?? _modeSettings.defaultGapDuration;
    _isLooping = true;
    _loopCount = 0;

    if (startImmediately) {
      seek(start);
    }

    notifyListeners();
  }

  void setMaxLoopCount(int count) {
    _maxLoopCount = count;
    notifyListeners();
  }

  void setGapDuration(double seconds) {
    _gapDuration = (seconds.isNaN ? 0.0 : seconds).clamp(0.0, 30.0);
    _storage.saveGapDuration(_gapDuration);
    notifyListeners();
  }

  void _checkLoopPosition(Duration currentPosition, Duration previousPosition) {
    if (!_isLooping || _loopEnd == null || _loopStart == null) return;

    if (currentPosition >= _loopEnd!) {
      _loopCount++;
      _totalLoopsToday++;

      _storage.incrementLoopCount();

      if (_maxLoopCount > 0 && _loopCount >= _maxLoopCount) {
        _onLoopCompleted();
        return;
      }

      if (_gapDuration > 0) {
        _startGapWait();
      } else {
        seek(_loopStart!);
      }
    }
  }

  void _startGapWait() {
    _isWaitingGap = true;
    _audioService.pause();
    notifyListeners();

    _gapTimer?.cancel();
    _gapTimer = Timer(
      Duration(milliseconds: (_gapDuration * 1000).round()),
      _onGapEnded,
    );
  }

  void _onGapEnded() {
    if (!_isLooping) return;
    _isWaitingGap = false;
    seek(_loopStart!);
    _audioService.play();
    notifyListeners();
  }

  void _onLoopCompleted() {
    debugPrint('Loop completed: $_loopCount times');
    if (_modeSettings.autoAdvanceSegments && _currentSegmentIndex >= 0) {
      _playNextSegment();
    } else {
      clearLoop();
    }
  }

  void clearLoop() {
    _gapTimer?.cancel();
    _gapTimer = null;
    _loopStart = null;
    _loopEnd = null;
    _isLooping = false;
    _loopCount = 0;
    _maxLoopCount = 0;
    _isWaitingGap = false;
    notifyListeners();
  }

  void toggleLoopPause() {
    if (_isWaitingGap) {
      _gapTimer?.cancel();
      _onGapEnded();
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

  // ==================== SEGMENTS MANAGEMENT ====================
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

    SegmentType autoType = type;
    if (type == SegmentType.favorite) {
      switch (_currentMode) {
        case VipMode.buddhism:
          autoType = SegmentType.dharma;
          break;
        case VipMode.english:
          autoType = SegmentType.english;
          break;
        default:
          autoType = SegmentType.favorite;
      }
    }

    int repeatCount;
    switch (difficulty) {
      case DifficultyLevel.easy:
        repeatCount = 2;
        break;
      case DifficultyLevel.medium:
        repeatCount = 4;
        break;
      case DifficultyLevel.hard:
        repeatCount = 7;
        break;
    }

    final segment = Segment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      audioPath: _currentSongPath!,
      title: title,
      startTime: _loopStart!,
      endTime: _loopEnd!,
      type: autoType,
      difficulty: difficulty,
      repeatCount: repeatCount,
      note: note,
      createdAt: DateTime.now(),
      tags: tags,
    );

    _segments.add(segment);

    _storage.saveAudioSegment(segment); // Corrected method name

    notifyListeners();
    return segment;
  }

  void deleteSegment(String id) {
    _segments.removeWhere((s) => s.id == id);

    _storage.deleteAudioSegment(id); // Corrected method name

    notifyListeners();
  }

  List<Segment> getSegmentsForCurrentSong() {
    if (_currentSongPath == null) return [];
    return _segments.where((s) => s.audioPath == _currentSongPath).toList();
  }

  List<Segment> getSegmentsByType(SegmentType type) {
    return _segments.where((s) => s.type == type).toList();
  }

  Future<void> playSegment(Segment segment, {int? index}) async {
    if (_currentSongPath != segment.audioPath) {
      await loadSong(path: segment.audioPath);
    }

    _currentSegmentIndex = index ?? _segments.indexOf(segment);
    setLoop(
      segment.startTime,
      segment.endTime,
      repeatCount: segment.repeatCount,
    );
    await play();
  }

  void _playNextSegment() {
    final currentSongSegments = getSegmentsForCurrentSong();
    if (_currentSegmentIndex < 0 ||
        _currentSegmentIndex >= currentSongSegments.length - 1) {
      clearLoop();
      return;
    }

    final nextIndex = _currentSegmentIndex + 1;
    final nextSegment = currentSongSegments[nextIndex];
    playSegment(nextSegment, index: nextIndex);
  }

  Future<void> playPreviousSegment() async {
    final currentSongSegments = getSegmentsForCurrentSong();
    if (_currentSegmentIndex <= 0) return;
    final prevIndex = _currentSegmentIndex - 1;
    final prevSegment = currentSongSegments[prevIndex];
    await playSegment(prevSegment, index: prevIndex);
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
      _storage.savePosition(_currentSongPath!, _state.position.inMilliseconds);
    }
  }

  Duration? getSavedPosition(String path) {
    final savedMs = _storage.getSavedPosition(path);
    if (savedMs == null) return null;
    return Duration(milliseconds: savedMs);
  }

  void clearSavedPosition(String path) {
    _storage.clearPosition(path);
  }

  void clearAllSavedPositions() {
    // _storage.clearAllPositions(); // Not implemented in provided StorageService
  }

  // ==================== LEARNING STATS ====================
  void resetDailyStats() {
    _totalLoopsToday = 0;
    _totalListeningTime = Duration.zero;
    _sessionStartTime = DateTime.now();
    notifyListeners();
  }

  Map<String, dynamic> getStats() {
    return {
      'totalLoopsToday': _totalLoopsToday,
      'totalListeningTimeMinutes': _totalListeningTime.inMinutes,
      'segmentsCount': _segments.length,
      'dharmaSegments': getSegmentsByType(SegmentType.dharma).length,
      'englishSegments': getSegmentsByType(SegmentType.english).length,
    };
  }

  // ==================== UTILITY ====================
  void setupForBuddhism() {
    setMode(VipMode.buddhism);
    setSpeed(0.9);
    setGapDuration(3.0);
  }

  void setupForEnglish() {
    setMode(VipMode.english);
    setSpeed(0.75);
    setGapDuration(2.0);
  }

  // ==================== DISPOSE ====================
  @override
  void dispose() {
    _saveCurrentPosition();
    if (_totalListeningTime.inSeconds > 0) {
      _storage.addListeningTime(_totalListeningTime.inSeconds);
    }

    _sleepTimer?.cancel();
    _positionSaverTimer?.cancel();
    _gapTimer?.cancel();
    _audioService.dispose();
    super.dispose();
  }
}
