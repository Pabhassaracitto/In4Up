// lib/providers/player_provider.dart
// Chỉ thay đổi 3 chỗ — giữ nguyên toàn bộ code cũ

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../audio/audio_player_service.dart';
import '../models/playback_state.dart';
import '../models/segment.dart';
import '../screens/listen_mode/models/recent_audio.dart';
// ★ THÊM import
import '../screens/listen_mode/services/recent_audio_service.dart';
import '../services/storage_service.dart';
import 'text_provider.dart'; // Import TextProvider

// ... giữ nguyên enum VipMode, ModeSettings ...

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
  // ★ THÊM
  TextProvider? _textProvider; // Thêm tham chiếu đến TextProvider
  final RecentAudioService _recentAudio = RecentAudioService();

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

  // Setter để gán TextProvider
  void setTextProvider(TextProvider textProvider) {
    _textProvider = textProvider;
  }

  Future<void> _restoreFromStorage() async {
    if (!_storage.isInitialized) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!_storage.isInitialized) return;
    }

    try {
      final savedMode = _storage.getLastMode();
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
      _gapDuration = _storage.getGapDuration();

      final savedSegments = _storage.getAllAudioSegments();
      _segments.addAll(savedSegments);

      final todayStats = _storage.getDailyStats();
      _totalLoopsToday = todayStats['loops'] as int;

      debugPrint(
          'PlayerProvider restored: Mode=$_currentMode, Segments=${_segments.length}');
      notifyListeners();
    } catch (e) {
      debugPrint('Error restoring PlayerProvider: $e');
    }
  }

  // ★ THÊM: Throttle update recent position (mỗi 30 giây 1 lần)
  DateTime _lastRecentUpdate = DateTime.now();

  void _maybeUpdateRecentPosition(Duration position) {
    if (_currentSongPath == null) return;
    final now = DateTime.now();
    if (now.difference(_lastRecentUpdate).inSeconds < 30) return;
    _lastRecentUpdate = now;

    final audioId = 'local_${_currentSongPath.hashCode}';
    _recentAudio.updatePosition(
      audioId,
      position: position,
      totalDuration: _state.duration,
    );
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

    _storage.saveLastMode(mode.name);
    _storage.saveGapDuration(_gapDuration);

    notifyListeners();
  }

  Future<void> applyModeDefaultSpeed() async {
    await setSpeed(_modeSettings.defaultSpeed);
  }

  // ==================== BASIC PLAYBACK ====================

  // ★ THAY THẾ loadSong() — thêm lưu recent
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

    // Lưu vào recent ngay
    final recentEntry = RecentAudio.fromLocalFile(
      path: path,
      title: title ?? path.split('/').last.split('\\').last,
    );
    _recentAudio.addOrUpdate(recentEntry);

    final success = await _audioService.loadFile(path);
    if (success) {
      final savedMs = _storage.getSavedPosition(path);
      if (savedMs != null && savedMs > 5000) {
        await seek(Duration(milliseconds: savedMs));
      }
      if (autoPlay) await play();

      // ★ THAY: Không update duration ngay
      // Thay bằng: chờ duration sẵn sàng qua _onStateChanged
      _pendingRecentUpdate = recentEntry;
    }
  }

// ★ THÊM field:
  RecentAudio? _pendingRecentUpdate;

  void _onStateChanged(PlaybackState state) {
    final previousPosition = _state.position;

    // ★ TỐI ƯU: Nâng ngưỡng lên 250ms thay vì 200ms để ổn định EGL trên Windows
    bool shouldNotify = state.status != _state.status ||
        state.speed != _state.speed ||
        (state.position.inMilliseconds - _state.position.inMilliseconds).abs() >
            250;

    _state = state;

    // ★ THÊM: Cập nhật duration khi đã có (Xử lý resume bài mới load)
    if (_pendingRecentUpdate != null && state.duration > Duration.zero) {
      final entry = _pendingRecentUpdate!;
      _pendingRecentUpdate = null;

      final savedMs = _storage.getSavedPosition(entry.localPath ?? '');
      final savedPos = savedMs != null && savedMs > 5000
          ? Duration(milliseconds: savedMs)
          : Duration.zero;

      _recentAudio.updatePosition(
        entry.id,
        position: savedPos,
        totalDuration: state.duration,
      );
    }

    if (_isLooping && _loopEnd != null && !_isWaitingGap) {
      _checkLoopPosition(state.position, previousPosition);
      if (state.position < previousPosition) shouldNotify = true;
    }

    if (state.status == PlaybackStatus.playing) {
      _totalListeningTime += const Duration(milliseconds: 100);
      _maybeUpdateRecentPosition(state.position);
    }

    if (shouldNotify) {
      notifyListeners();
    }
  }

  // ★ THÊM: clearCurrentSong() — dùng cho "Xem tất cả" trong QuickAudioSheet
  Future<void> clearCurrentSong() async {
    // Lưu position trước khi clear
    _saveCurrentPosition();

    // Dừng audio
    await _audioService.stop();

    // Clear state
    _currentSongPath = null;
    _currentSongTitle = null;
    _currentSongArtist = null;
    clearLoop();
    _currentSegmentIndex = -1;

    notifyListeners();
  }

  Future<void> play() async {
    await _audioService.play();
  }

  Future<void> pause() async {
    await _audioService.pause();
    _saveCurrentPosition();
  }

  Future<void> togglePlayPause() async {
    // Nếu đang ở chế độ đọc (English hoặc Buddhism) và có TextProvider
    if ((_currentMode == VipMode.english || _currentMode == VipMode.buddhism) &&
        _textProvider != null) {
      if (_textProvider!.isSpeaking) {
        await _textProvider!.stopSpeaking();
        // Cập nhật trạng thái isPlaying của PlayerProvider
        // (dù không phát audio, nhưng UI có thể lắng nghe trạng thái này)
        await pause();
      } else {
        // Bắt đầu đọc từ dòng hiện tại, hoặc từ đầu nếu chưa đọc gì
        int startIndex = _textProvider!.currentLineIndex;
        if (startIndex == -1) startIndex = 0; // Bắt đầu từ dòng đầu tiên
        await _textProvider!.speakAllLines(startIndex: startIndex);
        // Cập nhật trạng thái isPlaying của PlayerProvider
        await play();
      }
    } else {
      // Logic cũ cho chế độ nghe nhạc
      if (isPlaying)
        await pause();
      else
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
    _storage.saveLastPlaybackSpeed(safeSpeed);
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

    if (startImmediately) seek(start);
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
    _storage.saveAudioSegment(segment);
    notifyListeners();
    return segment;
  }

  void deleteSegment(String id) {
    _segments.removeWhere((s) => s.id == id);
    _storage.deleteAudioSegment(id);
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
    setLoop(segment.startTime, segment.endTime,
        repeatCount: segment.repeatCount);
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
    playSegment(currentSongSegments[nextIndex], index: nextIndex);
  }

  Future<void> playPreviousSegment() async {
    final currentSongSegments = getSegmentsForCurrentSong();
    if (_currentSegmentIndex <= 0) return;
    final prevIndex = _currentSegmentIndex - 1;
    await playSegment(currentSongSegments[prevIndex], index: prevIndex);
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

  void clearAllSavedPositions() {}

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
