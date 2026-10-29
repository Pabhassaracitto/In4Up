// lib/providers/player_provider.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in4up/audio/audio_player_service.dart';
import 'package:in4up/models/audio_queue_item.dart';
import 'package:in4up/models/playback_state.dart';
import 'package:in4up/models/segment.dart';
import 'package:in4up/screens/listen_mode/models/recent_audio.dart';
import 'package:in4up_core/vocab_level_difficulty.dart';
import '../screens/understand_mode/understand_mode.dart' hide LrcLine;
import '../services/audio_library_channel.dart';
import '../services/audio_library_service.dart';
import '../services/source_artifact_store.dart';
import '../services/storage_service.dart';
import '../utils/audio_source_identity.dart';
import 'text_provider.dart'; // Import TextProvider

// Mixins
import 'player/player_stt_mixin.dart';
import 'audio_library_provider.dart';
import 'player/playback_queue_controller.dart';
import 'player/player_loop_mixin.dart';
import 'player/player_stats_mixin.dart';

enum VipMode {
  music,
  buddhism,
  english,
}

/// SHADOW-FILE-001 — Kết quả nạp audio gần nhất, để UI quyết định hiện
/// hướng dẫn chọn lại file (thay vì crash im lặng khi ENOENT cache).
enum AudioLoadErrorKind {
  none,
  /// File không còn trên đĩa (cache file_picker bị dọn, file bị xóa...).
  missingFile,
  /// File tồn tại nhưng decode/load thất bại.
  loadFailed,
}

/// Path-keyed data from before URI-safe caching is retained, but its source
/// cannot be inferred from a filename alone.
class LegacyAudioDataOffer {
  final String source;
  final String legacyPath;
  final bool canLink;
  const LegacyAudioDataOffer({
    required this.source,
    required this.legacyPath,
    required this.canLink,
  });
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
  final AudioPlaybackPort _audioService;
  final StorageService _storage;
  final AudioLibraryProvider? _audioLibraryProvider;
  final Future<String> Function(String source) _resolvePlayablePath;
  final Future<AudioCacheResolution?> Function(String source)? _resolveAudioCache;
  final Future<void> Function(RecentAudio audio)? _recordRecentAudio;
  final bool _loadCachedLrc;
  late final PlaybackQueueController _queue;
  late final StreamSubscription<PlaybackState> _stateSubscription;
  bool _disposed = false;
  bool _wantsPlayback = false;
  bool _completionArmed = false;
  int _intentGeneration = 0;

  TextProvider? _textProvider; // Thêm tham chiếu đến TextProvider
  UnderstandProvider?
      _understandProvider; // NEW: Reference to UnderstandProvider

  // === PLAYBACK STATE ===
  PlaybackState _state = const PlaybackState();
  String? _currentSongTitle;
  String? _currentSongArtist;
  String? _currentSongPath;
  // Original URI/path for Recent; currentSongPath is the actual playable file.
  String? _currentSourcePath;
  LegacyAudioDataOffer? _legacyDataOffer;

  // === LOAD ERROR (SHADOW-FILE-001) ===
  AudioLoadErrorKind _lastLoadError = AudioLoadErrorKind.none;
  String? _lastLoadErrorPath;

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
  AudioPlaybackPort get audioService => _audioService;

  @override
  bool get wantsPlayback => _wantsPlayback;

  @override
  StorageService get storage => _storage;

  @override
  UnderstandProvider? get understandProvider => _understandProvider;

  // ==================== GETTERS ====================
  @override
  PlaybackState get state => _state;

  @override
  String? get currentSongPath => _currentSongPath;

  @override
  Duration get playbackDuration => _state.duration;

  String? get currentSongTitle => _currentSongTitle;
  String? get currentSongArtist => _currentSongArtist;
  LegacyAudioDataOffer? get legacyDataOffer => _legacyDataOffer;

  @override
  String? get currentRecentSource => _currentSourcePath;

  /// The current session's queue is independent of saved playlists.
  List<AudioQueueItem> get queueItems => _queue.items;
  int get queueIndex => _queue.activeIndex;
  int get queueCursor => _queue.cursor;
  bool get isQueueLoading => _queue.isLoading;
  Set<int> get queueFailedIndices => _queue.failedIndices;
  bool get canGoPreviousTrack => _queue.canGoPrevious;
  bool get canGoNextTrack => _queue.canGoNext;
  @visibleForTesting
  Future<void> get queueIdle => _queue.whenIdle;

  /// Lỗi nạp audio gần nhất (SHADOW-FILE-001). UI đọc getter này sau khi
  /// `loadSong` trả false để hiện hướng dẫn chọn lại file thay vì crash.
  AudioLoadErrorKind get lastLoadError => _lastLoadError;
  String? get lastLoadErrorPath => _lastLoadErrorPath;
  bool get currentAudioFileMissing =>
      _lastLoadError == AudioLoadErrorKind.missingFile;

  void clearLoadError() {
    if (_lastLoadError == AudioLoadErrorKind.none) return;
    _lastLoadError = AudioLoadErrorKind.none;
    _lastLoadErrorPath = null;
    notifyListeners();
  }

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
  PlayerProvider({
    UnderstandProvider? understandProvider,
    AudioLibraryProvider? audioLibraryProvider,
    @visibleForTesting AudioPlaybackPort? audioService,
    @visibleForTesting StorageService? storage,
    @visibleForTesting Future<String> Function(String source)? resolvePlayablePath,
    @visibleForTesting Future<void> Function(RecentAudio audio)? recordRecentAudio,
    @visibleForTesting bool initializeSttService = true,
    @visibleForTesting bool loadCachedLrc = true,
  })  : _understandProvider = understandProvider,
        _audioLibraryProvider = audioLibraryProvider,
        _audioService = audioService ?? AudioPlayerService(),
        _storage = storage ?? StorageService(),
        _resolvePlayablePath =
            resolvePlayablePath ?? AudioLibraryService().resolvePlayablePath,
        _resolveAudioCache = resolvePlayablePath == null
            ? AudioLibraryChannel.resolveContentToCache
            : null,
        _recordRecentAudio = recordRecentAudio,
        _loadCachedLrc = loadCachedLrc {
    _queue = PlaybackQueueController(
      loadTrack: _loadQueueTrack,
      onLoaded: _onQueueLoaded,
      onChanged: _notifyQueueChanged,
    );
    _stateSubscription = _audioService.stateStream.listen(_onStateChanged);

    _positionSaverTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(saveCurrentPosition()),
    );

    _restoreFromStorage();
    if (initializeSttService) initializeStt();
  }

  void _notifyQueueChanged() {
    if (!_disposed) notifyListeners();
  }

  // Setter để gán TextProvider
  void setTextProvider(TextProvider textProvider) {
    _textProvider = textProvider;
  }

  // NEW: Setter to assign UnderstandProvider
  void setUnderstandProvider(UnderstandProvider understandProvider) {
    _understandProvider = understandProvider;
    understandProvider.updatePosition(_state.position);
  }

  Future<void> _restoreFromStorage() async {
    if (!_storage.isInitialized) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!_storage.isInitialized) return;
    }
    if (_disposed) return;

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
    if (_disposed) return;
    final previousStatus = _state.status;
    final previousPosition = _state.position;
    var shouldNotify = state.status != _state.status ||
        state.speed != _state.speed ||
        (state.position.inMilliseconds - _state.position.inMilliseconds).abs() >
            16;
    _state = state;
    // One playback clock drives lyrics even when neither tab is mounted or
    // the user opens LRC while paused. The provider remembers this position.
    _understandProvider?.updatePosition(state.position);

    // Complete an A–B/segment loop before considering whole-track completion.
    if (_wantsPlayback && isLooping && loopEnd != null && !isWaitingGap &&
        (state.status == PlaybackStatus.playing ||
            state.status == PlaybackStatus.completed)) {
      checkLoopPosition(state.position, previousPosition);
      if (state.position < previousPosition) shouldNotify = true;
    }

    final newlyCompleted = state.status == PlaybackStatus.completed &&
        previousStatus != PlaybackStatus.completed;
    if (newlyCompleted &&
        !hasHandledCompletion &&
        !_queue.isLoading &&
        _wantsPlayback &&
        _completionArmed &&
        !isLooping) {
      _completionArmed = false;
      hasHandledCompletion = true;
      if (repeatTrack) {
        unawaited(_repeatOrAdvance(currentSongPath));
      } else if (_queue.canGoNext) {
        unawaited(_advanceAfterCompletion());
      } else {
        _wantsPlayback = false;
      }
    }

    if (state.status == PlaybackStatus.error &&
        previousStatus != PlaybackStatus.error &&
        !_queue.isLoading &&
        _wantsPlayback) {
      _lastLoadError = AudioLoadErrorKind.loadFailed;
      _lastLoadErrorPath = _currentSourcePath ?? _currentSongPath;
      unawaited(_advanceAfterPlaybackError());
    }

    if (state.status == PlaybackStatus.playing) {
      if (!_queue.isLoading && _currentSongPath != null && _wantsPlayback) {
        _completionArmed = true;
        hasHandledCompletion = false;
      }
      totalListeningTime += const Duration(milliseconds: 100);
      maybeUpdateRecentPosition(state.position);
    }

    if (shouldNotify || state.status == PlaybackStatus.playing) {
      notifyListeners();
    }
  }

  Future<void> _advanceAfterCompletion() async {
    final intent = _intentGeneration;
    final advanced = await _queue.advanceAfterCompletion();
    if (!_disposed && !advanced && intent == _intentGeneration &&
        !_queue.isLoading) {
      _wantsPlayback = false;
      notifyListeners();
    }
  }

  Future<void> _advanceAfterPlaybackError() async {
    final intent = _intentGeneration;
    final advanced = await _queue.advanceAfterPlaybackError();
    if (!_disposed && !advanced && intent == _intentGeneration &&
        !_queue.isLoading) {
      _wantsPlayback = false;
      notifyListeners();
    }
  }

  Future<void> _repeatOrAdvance(String? source) async {
    final result = await handleRepeatTrack();
    if (_disposed ||
        !_wantsPlayback ||
        source == null ||
        source != currentSongPath ||
        _queue.isLoading) {
      return;
    }
    if (result == TrackRepeatResult.completed) {
      if (_queue.canGoNext) {
        await _advanceAfterCompletion();
      } else {
        _wantsPlayback = false;
        notifyListeners();
      }
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

  /// Open a single source from any existing entry point. Opening another
  /// source detaches the old queue; reopening the current source keeps it.
  Future<bool> loadSong({
    required String path,
    String? title,
    String? artist,
    bool autoPlay = false,
    Duration? initialPosition,
  }) {
    if (_disposed) return Future<bool>.value(false);
    _intentGeneration++;
    _wantsPlayback = autoPlay;
    final current = _currentSongPath;
    final source = _currentSourcePath;
    final sameSource = (current != null && _sameAudioSource(current, path)) ||
        (source != null && _sameAudioSource(source, path));
    if (sameSource && _queue.activeIndex >= 0) {
      return _watchInitialLoad(
        _queue.select(_queue.activeIndex, initialPosition: initialPosition),
        _intentGeneration,
      );
    }
    return startQueue(
      [
        AudioQueueItem(
          source: path,
          title: title ?? path.replaceAll('\\', '/').split('/').last,
          artist: artist,
        ),
      ],
      autoPlay: autoPlay,
      initialPosition: initialPosition,
    );
  }

  /// Start a snapshot of a picker selection, playlist, or filtered library.
  Future<bool> startQueue(
    List<AudioQueueItem> items, {
    int startIndex = 0,
    bool autoPlay = true,
    bool resumePosition = true,
    Duration? initialPosition,
    bool skipFailures = false,
  }) {
    if (_disposed) return Future<bool>.value(false);
    if (items.isEmpty) return Future<bool>.value(false);
    _intentGeneration++;
    _wantsPlayback = autoPlay;
    return _watchInitialLoad(
      _queue.replace(
        items,
        startIndex: startIndex,
        resumePosition: resumePosition,
        initialPosition: initialPosition,
        skipFailures: skipFailures,
      ),
      _intentGeneration,
    );
  }

  Future<bool> _watchInitialLoad(Future<bool> pending, int intent) async {
    final loaded = await pending;
    if (!loaded && !_disposed && intent == _intentGeneration &&
        !_queue.isLoading && _currentSongPath == null) {
      _wantsPlayback = false;
      notifyListeners();
    }
    return loaded;
  }

  /// Direct selection resumes the saved position. The transport buttons and
  /// natural auto-advance instead start each selected track at zero.
  void clearUpcomingQueue() => _queue.keepCurrentOnly();

  Future<bool> selectQueueItem(int index) {
    if (index < 0 || index >= _queue.items.length) {
      return Future<bool>.value(false);
    }
    _intentGeneration++;
    return _queue.select(index);
  }

  Future<bool> nextTrack() {
    if (_queue.canGoNext) _intentGeneration++;
    return _queue.next();
  }

  Future<bool> previousTrack() {
    if (_queue.canGoPrevious) _intentGeneration++;
    return _queue.previous();
  }

  Future<bool> _loadQueueTrack(
    AudioQueueItem item,
    bool resumePosition,
    Duration? initialPosition,
    bool Function() isCurrent,
  ) async {
    if (!isCurrent()) return false;

    // Save before invalidating the old path. No old STT/cache callback can
    // publish while a new source is being materialized or loaded.
    final positionSaved = saveCurrentPosition();
    _completionArmed = false;
    _currentSongPath = null;
    _currentSourcePath = null;
    _legacyDataOffer = null;
    _currentSongTitle = null;
    _currentSongArtist = null;
    _lastLoadError = AudioLoadErrorKind.none;
    _lastLoadErrorPath = null;
    resetLrcStateForAudioChange();
    _understandProvider?.clear();
    clearLoop();
    _currentSegmentIndex = -1;
    notifyListeners();

    // Stop the old source before content:// materialization can overwrite a
    // cache file; loading never starts audio until the queue commits the item.
    await _audioService.pause();
    if (!isCurrent()) return false;
    await positionSaved;
    if (!isCurrent()) return false;
    if (item.isMissing) {
      _lastLoadError = AudioLoadErrorKind.missingFile;
      _lastLoadErrorPath = item.libraryId;
      notifyListeners();
      return false;
    }

    var normalizedPath = item.source.replaceAll('\\', '/');
    AudioCacheResolution? cacheResolution;
    try {
      if (normalizedPath.startsWith('content://')) {
        final cacheResolver = _resolveAudioCache;
        cacheResolution = cacheResolver == null
            ? AudioCacheResolution(path: await _resolvePlayablePath(normalizedPath))
            : await cacheResolver(normalizedPath);
        if (!isCurrent()) return false;
        final resolved = cacheResolution?.path ?? '';
        if (resolved.isEmpty || resolved.startsWith('content://')) {
          _lastLoadError = AudioLoadErrorKind.loadFailed;
          _lastLoadErrorPath = item.source;
          notifyListeners();
          return false;
        }
        normalizedPath = resolved.replaceAll('\\', '/');
      }

      final isLocalFilePath = !normalizedPath.startsWith('http');
      if (isLocalFilePath && !await File(normalizedPath).exists()) {
        if (!isCurrent()) return false;
        // A matching basename in audio_imports does not establish ownership:
        // two unrelated files can have the same name. Report the missing
        // source so the user can choose it again rather than play a wrong one.
        _lastLoadError = AudioLoadErrorKind.missingFile;
        _lastLoadErrorPath = normalizedPath;
        notifyListeners();
        return false;
      }
      if (!isCurrent()) return false;

      final legacyPath = cacheResolution?.legacyPath;
      if (legacyPath != null && cacheResolution?.legacyOwned == false &&
          await _hasLegacyAudioData(legacyPath)) {
        if (!isCurrent()) return false;
        _legacyDataOffer = LegacyAudioDataOffer(
          source: item.source,
          legacyPath: legacyPath,
          canLink: cacheResolution?.legacyClaimable == true,
        );
      }
      if (!isCurrent()) return false;

      final success = await _audioService.loadFile(normalizedPath);
      if (!isCurrent()) return false;
      if (!success) {
        _lastLoadError = AudioLoadErrorKind.loadFailed;
        _lastLoadErrorPath = normalizedPath;
        notifyListeners();
        return false;
      }

      if (initialPosition != null) {
        final duration = _audioService.currentState.duration;
        var target = initialPosition.isNegative ? Duration.zero : initialPosition;
        if (duration > Duration.zero && target > duration) target = duration;
        await _audioService.seek(target);
        if (!isCurrent()) return false;
      } else if (resumePosition) {
        final durationMs = _audioService.currentState.duration.inMilliseconds;
        var savedMs = _storage.getSavedPosition(normalizedPath);
        if (savedMs == null && item.source.startsWith('content://')) {
          final history = await recentAudio.getAll();
          if (!isCurrent()) return false;
          for (final entry in history) {
            if (entry.localPath == item.source) {
              savedMs = entry.lastPosition.inMilliseconds;
              break;
            }
          }
        }
        final isFinished = durationMs > 0 &&
            savedMs != null &&
            (savedMs > durationMs * 0.98 || savedMs > durationMs - 2000);
        if (savedMs != null && savedMs > 5000 && !isFinished) {
          await _audioService.seek(Duration(milliseconds: savedMs));
          if (!isCurrent()) return false;
        }
      }

      // Commit metadata only after the current request has successfully loaded.
      _currentSongPath = normalizedPath;
      _currentSourcePath = item.source;
      _currentSongTitle = item.title.isEmpty
          ? normalizedPath.split('/').last
          : item.title;
      _currentSongArtist = item.artist;
      _storage.saveLastAudioPath(normalizedPath);
      notifyListeners();
      return true;
    } catch (error, stack) {
      debugPrint('Error preparing queued audio: $error\n$stack');
      if (isCurrent()) {
        _lastLoadError = AudioLoadErrorKind.loadFailed;
        _lastLoadErrorPath = item.source;
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> _hasLegacyAudioData(String path) async {
    if (!_storage.isInitialized) return false;
    try {
      if (_storage.getSavedPosition(path) != null ||
          _storage.getAudioSegmentsForFile(path).isNotEmpty ||
          _storage.getSoundMarksForFile(path).isNotEmpty ||
          _storage.getSoundChaptersForFile(path).isNotEmpty ||
          _storage.getSoundTranscript(path) != null ||
          _storage.getAllSoundLoopStats().any((stat) => stat.audioPath == path)) {
        return true;
      }
      final artifacts = SourceArtifactStore.instance;
      return await artifacts.findLrc(path) != null ||
          await artifacts.hasUnverifiedLrc(path);
    } catch (error) {
      debugPrint('Could not inspect legacy audio metadata: $error');
      return false;
    }
  }

  /// Link legacy path-keyed data only after an explicit user confirmation.
  /// Native rechecks ownership and bytes to avoid overwriting another source.
  Future<bool> claimLegacyAudioData() async {
    final offer = _legacyDataOffer;
    if (_disposed || offer == null || !offer.canLink) return false;
    final intent = ++_intentGeneration;
    final ok = await AudioLibraryChannel.claimLegacyCache(offer.source);
    if (!ok) return false;
    // The user explicitly chose this legacy association. Do not guess if
    // several orphan LRC files could belong to the old path.
    await SourceArtifactStore.instance.bindSingleUnverifiedLrc(offer.legacyPath);
    if (_disposed || intent != _intentGeneration ||
        _currentSourcePath != offer.source || _queue.activeIndex < 0) {
      // The user navigated while the copy was in progress; the verified choice
      // is retained for a future opening, but must not change the new track.
      return true;
    }
    _legacyDataOffer = null;
    return _queue.select(_queue.activeIndex, initialPosition: _state.position);
  }

  void _onQueueLoaded(AudioQueueItem item) {
    if (_disposed || _currentSongPath == null) return;
    final path = _currentSongPath!;
    final source = _currentSourcePath ?? path;
    final loadedState = _audioService.currentState;
    final recentEntry = RecentAudio.fromLocalFile(
      path: source,
      title: _currentSongTitle,
      totalDuration: loadedState.duration,
    ).copyWith(lastPosition: loadedState.position);
    final recordRecent = _recordRecentAudio;
    unawaited(recordRecent == null
        ? recentAudio.addOrUpdate(recentEntry, preservePositionIfZero: true)
        : recordRecent(recentEntry));

    final library = _audioLibraryProvider;
    if (library != null && item.libraryId != null) {
      for (final entry in library.entries) {
        if (entry.libraryId == item.libraryId) {
          unawaited(library.markPlayed(entry));
          break;
        }
      }
    }
    if (_loadCachedLrc) unawaited(autoLoadCachedLrc(path));
    if (_wantsPlayback) unawaited(_audioService.play());
  }

  bool _sameAudioSource(String first, String second) {
    if (first.startsWith('content://') || second.startsWith('content://')) {
      // Content-provider URI path components can be case-sensitive.
      return first == second;
    }
    // Android/Linux paths are case-sensitive; only Windows folds case.
    return Platform.isWindows
        ? AudioSourceIdentity.matches(first, second)
        : first == second;
  }

  /// Close the current player and its session queue, never the saved files.
  Future<void> clearCurrentSong() async {
    if (_disposed) return;
    final intent = ++_intentGeneration;
    _wantsPlayback = false;
    _completionArmed = false;
    final positionSaved = saveCurrentPosition();
    _queue.clear();
    _currentSongPath = null;
    _currentSourcePath = null;
    _legacyDataOffer = null;
    _currentSongTitle = null;
    _currentSongArtist = null;
    _lastLoadError = AudioLoadErrorKind.none;
    _lastLoadErrorPath = null;
    resetLrcStateForAudioChange();
    _understandProvider?.clear();
    clearLoop();
    _currentSegmentIndex = -1;
    notifyListeners();

    // A pending source load and progress save must settle before stop.
    // A newer user action wins.
    await _queue.whenIdle;
    await positionSaved;
    if (_disposed || intent != _intentGeneration) return;
    await _audioService.stop();
  }

  Future<void> play() async {
    if (_disposed) return;
    final intent = ++_intentGeneration;
    _wantsPlayback = true;
    if (_queue.isLoading || _currentSongPath == null) {
      notifyListeners();
      return;
    }
    final loopRestart = isLooping && loopStart != null && loopEnd != null &&
        _state.position >= loopEnd!;
    if (loopRestart || isCompleted ||
        (_state.duration > Duration.zero &&
            _state.position >= _state.duration)) {
      await _audioService.seek(loopRestart ? loopStart! : Duration.zero);
      if (_disposed || intent != _intentGeneration || !_wantsPlayback) return;
    }
    await _audioService.play();
  }

  @override
  Future<void> pause() async {
    if (_disposed) return;
    final intent = ++_intentGeneration;
    _wantsPlayback = false;
    cancelRepeatWait();
    await _audioService.pause();
    if (!_disposed && intent == _intentGeneration) {
      await saveCurrentPosition();
    }
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
      // Playback intent remains meaningful while loading or waiting in a gap.
      if (_wantsPlayback) {
        await pause();
      } else {
        await play();
      }
    }
  }

  Future<void> stop() async {
    if (_disposed) return;
    final intent = ++_intentGeneration;
    _wantsPlayback = false;
    final positionSaved = saveCurrentPosition();
    cancelRepeatWait();
    _queue.cancelPending();
    await _queue.whenIdle;
    await positionSaved;
    if (_disposed || intent != _intentGeneration) return;
    await _audioService.stop();
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
      // SHADOW-FILE-001: file nguồn có thể đã bị dọn cache — loadSong trả
      // false thì dừng, UI đọc lastLoadError để hướng dẫn chọn lại file.
      final ok = await loadSong(path: segment.audioPath);
      if (!ok) return;
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
    unawaited(saveCurrentPosition());
    if (totalListeningTime.inSeconds > 0) {
      _storage.addListeningTime(totalListeningTime.inSeconds);
    }
    _disposed = true;
    _intentGeneration++;
    _wantsPlayback = false;
    final pending = _queue.whenIdle;
    _queue.dispose();
    unawaited(_stateSubscription.cancel());
    disposeStt();
    _sleepTimer?.cancel();
    _positionSaverTimer?.cancel();
    cancelGapTimer();
    // Do not dispose just_audio in the middle of setAudioSource.
    unawaited(pending.then((_) => _audioService.dispose()));
    super.dispose();
  }
}
