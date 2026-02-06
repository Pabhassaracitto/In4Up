// lib/providers/player_provider.dart
// VipSound - Enhanced Player Provider
// Version 2.0 - Optimized for Buddhism & English Learning

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../audio/audio_player_service.dart';
import '../models/playback_state.dart';
import '../models/segment.dart';

/// Chế độ sử dụng app
enum VipMode {
  music, // Nghe nhạc thông thường
  buddhism, // Nghe Pháp thoại
  english, // Học tiếng Anh
}

/// Cấu hình mặc định cho từng chế độ
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
    defaultGapDuration: 3.0, // 3 giây suy ngẫm
    defaultLoopCount: 3,
    autoAdvanceSegments: false,
    showTranscript: true,
  );

  static const english = ModeSettings(
    defaultSpeed: 0.75,
    defaultGapDuration: 2.0, // 2 giây để lặp lại
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

  // === PLAYBACK STATE ===
  PlaybackState _state = const PlaybackState();
  String? _currentSongTitle;
  String? _currentSongArtist;
  String? _currentSongPath;

  // === VIP MODE ===
  VipMode _currentMode = VipMode.music;
  ModeSettings _modeSettings = ModeSettings.music;

  // === A-B LOOP (Enhanced) ===
  Duration? _loopStart;
  Duration? _loopEnd;
  bool _isLooping = false;
  int _loopCount = 0;
  int _maxLoopCount = 0;

  // Gap Loop - Khoảng lặng giữa các lần loop
  double _gapDuration = 0.0; // Giây
  bool _isWaitingGap = false;
  Timer? _gapTimer;

  // === SLEEP TIMER ===
  Timer? _sleepTimer;
  Duration? _sleepDuration;
  DateTime? _sleepEndTime;

  // === SAVED POSITIONS ===
  final Map<String, int> _savedPositions = {};
  Timer? _positionSaverTimer;

  // === SEGMENTS ===
  final List<Segment> _segments = [];
  int _currentSegmentIndex = -1;

  // === LEARNING STATS ===
  int _totalLoopsToday = 0;
  Duration _totalListeningTime = Duration.zero;
  DateTime? _sessionStartTime;

  // ==================== GETTERS ====================

  // Basic
  PlaybackState get state => _state;
  String? get currentSongTitle => _currentSongTitle;
  String? get currentSongArtist => _currentSongArtist;
  String? get currentSongPath => _currentSongPath;
  bool get isPlaying => _state.status == PlaybackStatus.playing;
  bool get isPaused => _state.status == PlaybackStatus.paused;
  bool get isStopped => _state.status == PlaybackStatus.stopped;
  bool get isLoading => _state.status == PlaybackStatus.loading;

  // VipMode
  VipMode get currentMode => _currentMode;
  ModeSettings get modeSettings => _modeSettings;
  bool get isBuddhismMode => _currentMode == VipMode.buddhism;
  bool get isEnglishMode => _currentMode == VipMode.english;
  bool get isMusicMode => _currentMode == VipMode.music;

  // A-B Loop
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

  /// Phần trăm hoàn thành loop (cho progress indicator)
  double get loopProgress {
    if (_maxLoopCount == 0) return 0.0;
    return (_loopCount / _maxLoopCount).clamp(0.0, 1.0);
  }

  // Sleep timer
  Duration? get sleepDuration => _sleepDuration;
  bool get hasSleepTimer => _sleepTimer != null;

  Duration? get sleepRemaining {
    if (_sleepEndTime == null) return null;
    final remaining = _sleepEndTime!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  // Segments
  List<Segment> get segments => List.unmodifiable(_segments);
  int get currentSegmentIndex => _currentSegmentIndex;
  Segment? get currentSegment =>
      _currentSegmentIndex >= 0 && _currentSegmentIndex < _segments.length
          ? _segments[_currentSegmentIndex]
          : null;

  // Learning Stats
  int get totalLoopsToday => _totalLoopsToday;
  Duration get totalListeningTime => _totalListeningTime;

  // Speed presets
  List<double> get speedPresets => AudioPlayerService.speedPresets;

  // ==================== CONSTRUCTOR ====================

  PlayerProvider() {
    _audioService.stateStream.listen(_onStateChanged);

    // Auto save position every 10 seconds
    _positionSaverTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _saveCurrentPosition(),
    );

    // Track listening time
    _sessionStartTime = DateTime.now();
  }

  void _onStateChanged(PlaybackState state) {
    final previousPosition = _state.position;
    _state = state;

    // Check A-B loop
    if (_isLooping && _loopEnd != null && !_isWaitingGap) {
      _checkLoopPosition(state.position, previousPosition);
    }

    // Update listening time
    if (state.status == PlaybackStatus.playing && _sessionStartTime != null) {
      // Approximate tracking
      _totalListeningTime += const Duration(milliseconds: 100);
    }

    notifyListeners();
  }

  // ==================== VIP MODE ====================

  /// Chuyển chế độ sử dụng
  void setMode(VipMode mode) {
    if (_currentMode == mode) return;

    _currentMode = mode;
    _modeSettings = ModeSettings.forMode(mode);

    // Áp dụng cấu hình mặc định của mode (nếu chưa có loop)
    if (!_isLooping) {
      _gapDuration = _modeSettings.defaultGapDuration;
      _maxLoopCount = _modeSettings.defaultLoopCount;
    }

    debugPrint('VipMode changed to: ${mode.name}');
    notifyListeners();
  }

  /// Áp dụng speed mặc định của mode hiện tại
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
    final safeSpeed = (speed.isNaN ? 1.0 : speed)
        .clamp(AudioPlayerService.minSpeed, AudioPlayerService.maxSpeed);
    await _audioService.setSpeed(safeSpeed);
  }

  Future<void> setPitch(double semitones) async {
    final safePitch = (semitones.isNaN ? 0.0 : semitones).clamp(-24.0, 24.0);
    await _audioService.setPitch(safePitch);
  }

  Future<void> setVolume(double volume) async {
    await _audioService.setVolume(volume);
  }

  /// Tăng/giảm speed theo bước
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

  // ==================== A-B LOOP (Enhanced) ====================

  void setLoopStart() {
    _loopStart = _state.position;
    notifyListeners();
  }

  void setLoopEnd() {
    if (_loopStart == null) return;

    _loopEnd = _state.position;

    // Đảm bảo start < end
    if (_loopEnd! <= _loopStart!) {
      final temp = _loopStart;
      _loopStart = _loopEnd;
      _loopEnd = temp;
    }

    _isLooping = true;
    _loopCount = 0;

    // Áp dụng cấu hình mặc định từ mode nếu chưa set
    if (_gapDuration == 0) {
      _gapDuration = _modeSettings.defaultGapDuration;
    }
    if (_maxLoopCount == 0) {
      _maxLoopCount = _modeSettings.defaultLoopCount;
    }

    notifyListeners();
  }

  /// Set loop với đầy đủ tham số
  void setLoop(
    Duration start,
    Duration end, {
    int repeatCount = 0,
    double? gapSeconds,
    bool startImmediately = true,
  }) {
    // Đảm bảo start < end
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

  /// Set số lần lặp tối đa (0 = vô hạn)
  void setMaxLoopCount(int count) {
    _maxLoopCount = count;
    notifyListeners();
  }

  /// Set khoảng lặng giữa các lần loop (giây)
  void setGapDuration(double seconds) {
    _gapDuration = (seconds.isNaN ? 0.0 : seconds).clamp(0.0, 30.0);
    notifyListeners();
  }

  /// Logic kiểm tra và xử lý loop
  void _checkLoopPosition(Duration currentPosition, Duration previousPosition) {
    if (!_isLooping || _loopEnd == null || _loopStart == null) return;

    // Kiểm tra đã vượt qua điểm B chưa
    if (currentPosition >= _loopEnd!) {
      _loopCount++;
      _totalLoopsToday++;

      // Kiểm tra đã đủ số lần lặp chưa
      if (_maxLoopCount > 0 && _loopCount >= _maxLoopCount) {
        _onLoopCompleted();
        return;
      }

      // Xử lý gap (khoảng lặng)
      if (_gapDuration > 0) {
        _startGapWait();
      } else {
        // Quay lại điểm A ngay lập tức
        seek(_loopStart!);
      }
    }
  }

  /// Bắt đầu chờ gap
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

  /// Khi hết thời gian gap
  void _onGapEnded() {
    if (!_isLooping) return;

    _isWaitingGap = false;
    seek(_loopStart!);
    _audioService.play();
    notifyListeners();
  }

  /// Khi hoàn thành tất cả các lần loop
  void _onLoopCompleted() {
    debugPrint('Loop completed: $_loopCount times');

    // Auto advance to next segment (nếu mode cho phép)
    if (_modeSettings.autoAdvanceSegments && _currentSegmentIndex >= 0) {
      _playNextSegment();
    } else {
      clearLoop();
    }
  }

  /// Xóa loop
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

  /// Tạm dừng/tiếp tục loop
  void toggleLoopPause() {
    if (_isWaitingGap) {
      // Skip gap, quay lại loop ngay
      _gapTimer?.cancel();
      _onGapEnded();
    }
  }

  /// Bỏ qua loop hiện tại, đến loop tiếp theo
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

  /// Lưu loop hiện tại thành segment
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

    // Tự động chọn type dựa trên mode
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

    // Tự động set repeatCount dựa trên difficulty
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
    notifyListeners();

    return segment;
  }

  /// Xóa segment
  void deleteSegment(String id) {
    _segments.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  /// Lấy segments của bài hiện tại
  List<Segment> getSegmentsForCurrentSong() {
    if (_currentSongPath == null) return [];
    return _segments.where((s) => s.audioPath == _currentSongPath).toList();
  }

  /// Lấy segments theo type
  List<Segment> getSegmentsByType(SegmentType type) {
    return _segments.where((s) => s.type == type).toList();
  }

  /// Play một segment
  Future<void> playSegment(Segment segment, {int? index}) async {
    // Load file nếu khác file hiện tại
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

  /// Play segment tiếp theo
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

  /// Play segment trước đó
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

  // ==================== LEARNING STATS ====================

  /// Reset thống kê hàng ngày
  void resetDailyStats() {
    _totalLoopsToday = 0;
    _totalListeningTime = Duration.zero;
    _sessionStartTime = DateTime.now();
    notifyListeners();
  }

  /// Lấy thống kê dạng Map
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

  /// Quick setup cho Phật Pháp
  void setupForBuddhism() {
    setMode(VipMode.buddhism);
    setSpeed(0.9);
    setGapDuration(3.0);
  }

  /// Quick setup cho học tiếng Anh
  void setupForEnglish() {
    setMode(VipMode.english);
    setSpeed(0.75);
    setGapDuration(2.0);
  }

  // ==================== DISPOSE ====================

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _positionSaverTimer?.cancel();
    _gapTimer?.cancel();
    _audioService.dispose();
    super.dispose();
  }
}
