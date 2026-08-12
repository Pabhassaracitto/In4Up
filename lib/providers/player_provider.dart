// lib/providers/player_provider.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in2up_core/vocab_level_difficulty.dart';
import '../screens/understand_mode/understand_mode.dart' hide LrcLine;
import '../services/storage_service.dart';
import 'text_provider.dart'; // Import TextProvider

// Mixins
import 'player/player_stt_mixin.dart';
import 'player/player_loop_mixin.dart';
import 'player/player_stats_mixin.dart';

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

class PlayerProvider extends ChangeNotifier
    with PlayerSttMixin, PlayerLoopMixin, PlayerStatsMixin {
  final AudioPlayerService _audioService = AudioPlayerService();
  final StorageService _storage = StorageService();

  TextProvider? _textProvider; // Thêm tham chiếu đến TextProvider
  UnderstandProvider?
      _understandProvider; // NEW: Reference to UnderstandProvider

  // === PLAYBACK STATE ===
  PlaybackState _state = const PlaybackState();
  String? _currentSongTitle;
  String? _currentSongArtist;
  String? _currentSongPath;

  // === VIP MODE ===
  VipMode _currentMode = VipMode.music;
  ModeSettings _modeSettings = ModeSettings.music;

  // === SLEEP TIMER ===
  Timer? _sleepTimer;
  Duration? _sleepDuration;
  DateTime? _sleepEndTime;

  // === SAVED POSITIONS ===
  Timer? _positionSaverTimer;

  // === SEGMENTS ===
  final List<Segment> _segments = [];
  int _currentSegmentIndex = -1;

  // ==================== MIXIN ABSTRACT OVERRIDES ====================
  @override
  AudioPlayerService get audioService => _audioService;

  @override
  StorageService get storage => _storage;

  @override
  UnderstandProvider? get understandProvider => _understandProvider;

  // ==================== GETTERS ====================
  @override
  PlaybackState get state => _state;

  @override
  String? get currentSongPath => _currentSongPath;

  String? get currentSongTitle => _currentSongTitle;
  String? get currentSongArtist => _currentSongArtist;
  bool get isPlaying => _state.status == PlaybackStatus.playing;
  bool get isPaused => _state.status == PlaybackStatus.paused;
  bool get isStopped => _state.status == PlaybackStatus.stopped;
  bool get isLoading => _state.status == PlaybackStatus.loading;
  bool get isCompleted => _state.status == PlaybackStatus.completed;

  VipMode get currentMode => _currentMode;
  @override
  ModeSettings get modeSettings => _modeSettings;
  bool get isBuddhismMode => _currentMode == VipMode.buddhism;
  bool get isEnglishMode => _currentMode == VipMode.english;
  bool get isMusicMode => _currentMode == VipMode.music;

  Duration? get sleepDuration => _sleepDuration;
  bool get hasSleepTimer => _sleepTimer != null;
  Duration? get sleepRemaining {
    if (_sleepEndTime == null) return null;
    final remaining = _sleepEndTime!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  @override
  List<Segment> get segments => List.unmodifiable(_segments);

  @override
  int get currentSegmentIndex => _currentSegmentIndex;
  Segment? get currentSegment =>
      _currentSegmentIndex >= 0 && _currentSegmentIndex < _segments.length
          ? _segments[_currentSegmentIndex]
          : null;

  List<double> get speedPresets => AudioPlayerService.speedPresets;

  // ==================== CONSTRUCTOR ====================
  PlayerProvider() {
    _audioService.stateStream.listen(_onStateChanged);

    _positionSaverTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => saveCurrentPosition(),
    );

    _restoreFromStorage();
    initializeStt();
  }

  // Setter để gán TextProvider
  void setTextProvider(TextProvider textProvider) {
    _textProvider = textProvider;
  }

  // NEW: Setter to assign UnderstandProvider
  void setUnderstandProvider(UnderstandProvider understandProvider) {
    _understandProvider = understandProvider;
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
      restoreLoopSettings(_storage.getGapDuration());

      final savedSegments = _storage.getAllAudioSegments();
      _segments.addAll(savedSegments);

      final todayStats = _storage.getDailyStats();
      totalLoopsToday = todayStats['loops'] as int;

      debugPrint(
        'PlayerProvider restored: Mode=$_currentMode, Segments=${_segments.length}',
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error restoring PlayerProvider: $e');
    }
  }

  void _onStateChanged(PlaybackState state) {
    final previousStatus = _state.status;
    final previousPosition = _state.position;

    // ── FIX 1: Hạ ngưỡng xuống 16ms (~60fps) để thanh chạy mượt ──
    bool shouldNotify = state.status != _state.status ||
        state.speed != _state.speed ||
        (state.position.inMilliseconds - _state.position.inMilliseconds).abs() >
            16;

    _state = state;

    // ── FIX 2: Xử lý completed KHÔNG dùng return sớm ──
    if (state.status == PlaybackStatus.completed &&
        previousStatus != PlaybackStatus.completed &&
        !hasHandledCompletion) {
      debugPrint('🏁 COMPLETED CAUGHT: repeatTrack=$repeatTrack');

      if (repeatTrack) {
        hasHandledCompletion = true;
        handleRepeatTrack(); // fire and forget
      }
    }

    // Reset flag khi playing bình thường
    if (state.status == PlaybackStatus.playing) {
      hasHandledCompletion = false;
    }

    // Pending recent update
    if (pendingRecentUpdate != null && state.duration > Duration.zero) {
      final entry = pendingRecentUpdate!;
      pendingRecentUpdate = null;
      recentAudio.updatePosition(
        entry.id,
        position: Duration.zero,
        totalDuration: state.duration,
      );
    }

    // AB Loop check
    if (isLooping && loopEnd != null && !isWaitingGap) {
      checkLoopPosition(state.position, previousPosition);
      if (state.position < previousPosition) shouldNotify = true;
    }

    // Stats
    if (state.status == PlaybackStatus.playing) {
      totalListeningTime += const Duration(milliseconds: 100);
      maybeUpdateRecentPosition(state.position);
    }

    // Luôn notify khi playing để UI (thanh progress, waveform) cập nhật mượt
    if (shouldNotify || state.status == PlaybackStatus.playing) {
      notifyListeners();
    }
  }

  // ==================== VIP MODE ====================
  void setMode(VipMode mode) {
    if (_currentMode == mode) return;
    _currentMode = mode;
    _modeSettings = ModeSettings.forMode(mode);

    updateLoopSettings(
      defaultGap: _modeSettings.defaultGapDuration,
      defaultLoop: _modeSettings.defaultLoopCount,
    );

    _storage.saveLastMode(mode.name);
    _storage.saveGapDuration(gapDuration);

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
    final normalizedPath = path.replaceAll('\', '/');

    // ★ TASK 5: Dọn dẹp dữ liệu LRC bài cũ ngay khi đổi sang bài mới
    // Chỉ clear nếu thực sự đổi bài (tránh clear khi load lại cùng bài)
    if (_currentSongPath != null &&
        _normalizePath(_currentSongPath!) != _normalizePath(normalizedPath)) {
      _understandProvider?.clear();
      // Hủy transcribe/LRC đang chạy của bài cũ để không "kẹt" hay ghi
      // kết quả bài cũ vào bài mới.
      cancelLrcGeneration();
      debugPrint('🧹 Cleared UnderstandProvider for new song: $normalizedPath');
    }

    _currentSongPath = normalizedPath;
    _currentSongTitle = title ?? normalizedPath.split('/').last;
    _currentSongArtist = artist;

    clearLoop();
    hasHandledCompletion = false; // Reset trạng thái kết thúc khi đổi bài
    _currentSegmentIndex = -1;
    _storage.saveLastAudioPath(normalizedPath);
    notifyListeners();

    // ★ THÊM: Lưu vào recent ngay khi load
    final recentEntry = RecentAudio.fromLocalFile(
      path: normalizedPath,
      title: _currentSongTitle!,
    );
    pendingRecentUpdate = recentEntry;
    // Fire-and-forget — không await để không block playback
    recentAudio.addOrUpdate(recentEntry);

    final success = await _audioService.loadFile(normalizedPath);
    if (success) {
      // Lấy duration thực tế từ service
      final durationMs = _audioService.currentState.duration.inMilliseconds;
      final savedMs = _storage.getSavedPosition(normalizedPath);

      // Kiểm tra xem vị trí đã lưu có quá gần cuối bài không (còn dưới 2 giây hoặc > 98%)
      bool isFinished = durationMs > 0 &&
          (savedMs != null &&
              (savedMs > durationMs * 0.98 || savedMs > durationMs - 2000));

      if (savedMs != null && savedMs > 5000 && !isFinished) {
        await seek(Duration(milliseconds: savedMs));
      }
      if (autoPlay) {
        await play();
      }

      // ★ THÊM: Cập nhật totalDuration sau khi load xong
      final duration = _state.duration;
      if (duration > Duration.zero) {
        recentAudio.updatePosition(
          recentEntry.id,
          position: Duration.zero,
          totalDuration: duration,
        );
      }

      // ★ TASK 2: Sau khi load file xong, scan cache LRC theo hash
      // Fire-and-forget để không block playback
      autoLoadCachedLrc(normalizedPath);
    }
  }

  /// Helper normalize path (dùng nội bộ trong provider)
  String _normalizePath(String path) {
    try {
      return Uri.decodeFull(path.replaceAll('\', '/').toLowerCase().trim());
    } catch (_) {
      // Fallback khi path chứa ký tự % không hợp lệ (ví dụ file .m4a có ’ hoặc %)
      return path.replaceAll('\', '/').toLowerCase().trim();
    }
  }

  // ★ THÊM: clearCurrentSong() — dùng cho "Xem tất cả" trong QuickAudioSheet
  Future<void> clearCurrentSong() async {
    // Lưu position trước khi clear
    saveCurrentPosition();

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
    saveCurrentPosition();
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
      if (isPlaying) {
        await pause();
      } else {
        await play();
      }
    }
  }

  Future<void> stop() async {
    await _audioService.stop();
    saveCurrentPosition();
  }

  @override
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

  // ==================== SEGMENTS MANAGEMENT ====================
  Segment? saveLoopAsSegment({
    required String title,
    SegmentType type = SegmentType.favorite,
    DifficultyLevel difficulty = DifficultyLevel.medium,
    String? note,
    List<String> tags = const [],
  }) {
    if (loopStart == null || loopEnd == null || _currentSongPath == null) {
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

    final repeatCount = switch (difficulty) {
      DifficultyLevel.easy => 2,
      DifficultyLevel.medium => 4,
      DifficultyLevel.hard => 7,
      DifficultyLevel.veryHard => 10, // ← THÊM
    };

    final segment = Segment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      audioPath: _currentSongPath!,
      title: title,
      startTime: loopStart!,
      endTime: loopEnd!,
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

  @override
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

  @override
  void playNextSegment() {
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
    saveCurrentPosition();
    if (totalListeningTime.inSeconds > 0) {
      _storage.addListeningTime(totalListeningTime.inSeconds);
    }
    disposeStt(); // ★ THÊM
    _sleepTimer?.cancel();
    _positionSaverTimer?.cancel();
    cancelGapTimer();
    _audioService.dispose();
    super.dispose();
  }
}
