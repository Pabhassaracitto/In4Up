// lib/providers/player_provider.dart
// Chỉ thay đổi 3 chỗ — giữ nguyên toàn bộ code cũ

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:vipsound_core/vocab_level_difficulty.dart';
import 'package:vipsound_stt/vipsound_stt.dart';

import '../audio/audio_player_service.dart';
import '../models/playback_state.dart';
import '../models/segment.dart';
import '../screens/listen_mode/models/recent_audio.dart';
// ★ THÊM import
import '../screens/listen_mode/services/recent_audio_service.dart';
import '../screens/understand_mode/understand_mode.dart' hide LrcLine;
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
  UnderstandProvider?
      _understandProvider; // NEW: Reference to UnderstandProvider
  final RecentAudioService _recentAudio = RecentAudioService();

  // ★ THÊM: STT Facade
  final SttServiceFacade _sttService = SttServiceFacade();

  // ★ THÊM: Trạng thái STT
  SttTranscribeOutput? _lastTranscribeOutput;
  SttTranscribeOutput? get lastTranscribeOutput => _lastTranscribeOutput;

  // ★ TASK 4: Flag để UI biết khi nào LRC vừa được tạo xong
  bool _lrcJustGenerated = false;
  bool get lrcJustGenerated => _lrcJustGenerated;

  /// UI gọi method này sau khi đã xử lý sự kiện lrcJustGenerated
  void consumeLrcJustGenerated() {
    if (_lrcJustGenerated) {
      _lrcJustGenerated = false;
      // Không cần notifyListeners() — tránh vòng lặp
    }
  }

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
  Duration? _pendingLoopA;
  bool _isLooping = false;
  int _loopCount = 0;
  int _maxLoopCount = 0;
  bool _repeatTrack = false;
  bool _hasHandledCompletion = false; // Chống double-trigger khi kết thúc bài

  double _gapDuration = 0.0;
  bool _isWaitingGap = false;
  Timer? _gapTimer;
  Duration _silenceDuration = Duration.zero;

  // === SLEEP TIMER ===
  Timer? _sleepTimer;
  Duration? _sleepDuration;
  DateTime? _sleepEndTime;

  // === SAVED POSITIONS ===
  Timer? _positionSaverTimer;
  RecentAudio? _pendingRecentUpdate;

  // === SEGMENTS ===
  final List<Segment> _segments = [];
  int _currentSegmentIndex = -1;

  // === LEARNING STATS ===
  int _totalLoopsToday = 0;
  Duration _totalListeningTime = Duration.zero;

  // ==================== GETTERS ====================
  PlaybackState get state => _state;
  String? get currentSongTitle => _currentSongTitle;
  String? get currentSongArtist => _currentSongArtist;
  String? get currentSongPath => _currentSongPath;
  bool get isPlaying => _state.status == PlaybackStatus.playing;
  bool get isPaused => _state.status == PlaybackStatus.paused;
  bool get isStopped => _state.status == PlaybackStatus.stopped;
  bool get isLoading => _state.status == PlaybackStatus.loading;
  bool get isCompleted => _state.status == PlaybackStatus.completed;

  VipMode get currentMode => _currentMode;
  ModeSettings get modeSettings => _modeSettings;
  bool get isBuddhismMode => _currentMode == VipMode.buddhism;
  bool get isEnglishMode => _currentMode == VipMode.english;
  bool get isMusicMode => _currentMode == VipMode.music;

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

    _restoreFromStorage();
    _initializeStt();
  }

  // Setter để gán TextProvider
  void setTextProvider(TextProvider textProvider) {
    _textProvider = textProvider;
  }

  // NEW: Setter to assign UnderstandProvider
  void setUnderstandProvider(UnderstandProvider understandProvider) {
    _understandProvider = understandProvider;
  }

  // ─── THÊM METHODS STT ───────────────────────────────────────────────────

  /// Khởi tạo STT (gọi trong constructor)
  Future<void> _initializeStt() async {
    try {
      await _sttService.initialize();
      debugPrint('✅ PlayerProvider: STT initialized');
    } catch (e) {
      debugPrint('⚠️ PlayerProvider: STT init failed (non-fatal): $e');
    }
  }

  Stream<SttProgress> get sttProgressStream => _sttService.progressStream;
  SttProgress get sttProgress => _sttService.currentProgress;

  /// ★ TASK 2: Tính hash đơn giản từ file path để làm cache key LRC
  String _computeFileHash(String normalizedPath) {
    // Dùng hashCode của path làm ID nhẹ (không cần đọc file)
    // Nếu dự án có crypto package → dùng MD5 của bytes sẽ chính xác hơn
    return normalizedPath.hashCode.toRadixString(16);
  }

  /// ★ TASK 2: Tìm file LRC trong cache dựa trên hash của path
  Future<String?> _findCachedLrcPath(String normalizedPath) async {
    try {
      final hash = _computeFileHash(normalizedPath);

      // Thư mục cache STT mặc định (cùng nơi SttServiceFacade lưu LRC)
      // Thử các vị trí phổ biến theo thứ tự ưu tiên
      final candidates = <String>[
        // 1. LRC đặt cùng thư mục với file audio
        '${normalizedPath.substring(0, normalizedPath.lastIndexOf('/'))}'
            '/${hash}.lrc',
        // 2. Cache app (SttServiceFacade thường lưu theo pattern này)
        '/data/user/0/com.vipsound.app/cache/lrc/$hash.lrc',
        // 3. LRC cùng tên với file audio (thay extension)
        _replaceExtension(normalizedPath, '.lrc'),
      ];

      for (final candidate in candidates) {
        final file = File(candidate);
        if (await file.exists()) {
          debugPrint('✅ Found cached LRC: $candidate');
          return candidate;
        }
      }

      // 4. Scan thư mục cache thông qua SttServiceFacade nếu có API
      final outputFromStt = _lastSttOutput;
      if (outputFromStt?.lrcFilePath != null) {
        final lrcFile = File(outputFromStt!.lrcFilePath!);
        if (await lrcFile.exists()) {
          return outputFromStt.lrcFilePath;
        }
      }

      return null;
    } catch (e) {
      debugPrint('⚠️ _findCachedLrcPath error: $e');
      return null;
    }
  }

  /// Helper: thay extension của file path
  String _replaceExtension(String path, String newExt) {
    final lastDot = path.lastIndexOf('.');
    final lastSlash = path.lastIndexOf('/');
    if (lastDot > lastSlash && lastDot >= 0) {
      return '${path.substring(0, lastDot)}$newExt';
    }
    return '$path$newExt';
  }

  /// ★ TASK 2: Parse file LRC thành danh sách LrcLine
  Future<List<LrcLine>> _parseLrcFile(String lrcPath) async {
    try {
      final file = File(lrcPath);
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      final lines = <LrcLine>[];

      for (final rawLine in content.split('\n')) {
        final trimmed = rawLine.trim();
        if (trimmed.isEmpty) continue;

        // Parse LRC format: [mm:ss.xx] text hoặc [mm:ss.xxx]
        final match = RegExp(
          r'^\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)$',
        ).firstMatch(trimmed);

        if (match != null) {
          final minutes = int.parse(match.group(1)!);
          final seconds = int.parse(match.group(2)!);
          final centisStr = match.group(3)!;
          // Normalise 2 hoặc 3 chữ số về milliseconds
          final millis = centisStr.length == 2
              ? int.parse(centisStr) * 10
              : int.parse(centisStr);

          final timestamp = Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: millis,
          );
          final text = match.group(4)?.trim() ?? '';

          if (text.isNotEmpty) {
            lines.add(
                LrcLine(timestamp: timestamp, text: text, rawText: trimmed));
          }
        }
      }

      debugPrint('📄 Parsed ${lines.length} LRC lines from $lrcPath');
      return lines;
    } catch (e) {
      debugPrint('⚠️ _parseLrcFile error: $e');
      return [];
    }
  }

  /// Tạo LRC từ bài audio hiện tại (Deep Learning mode)
  Future<SttTranscribeOutput?> generateLrcForCurrentAudio({
    WhisperModelLevel? level,
  }) async {
    final path = currentSongPath;
    if (path == null) {
      _lastSttError = 'Chưa có file audio đang phát';
      notifyListeners();
      return null;
    }

    _isGeneratingLrc = true;
    _lastSttError = null;
    notifyListeners();

    try {
      final stt = SttServiceFacade();

      SttTranscribeOutput output;
      if (level == null) {
        // AUTO MODE
        output = await stt.transcribeAuto(
          path,
          language: 'en',
          generateLrc: true,
        );
      } else {
        // USER-SELECTED MODEL
        output = await stt.transcribeFile(
          path,
          config: SttConfig.deepLearning.copyWith(
            preferredEngine: SttEngineType.whisper,
            whisperModel: level,
            language: 'en',
            generateLrc: true,
          ),
          generateLrc: true,
        );
      }

      _lastSttOutput = output;
      _lastSttError = output.success ? null : output.errorMessage;

      // ★ THÊM: Lưu lrcPath riêng
      if (output.lrcFilePath != null) {
        _lastGeneratedLrcPath = output.lrcFilePath;
      }

      // ★ TASK 4: Nếu tạo LRC thành công → parse và đẩy vào UnderstandProvider
      // + bật flag để UI mở _AIPanel và LrcEditorPanel ở chế độ edit
      if (output.success &&
          output.lrcFilePath != null &&
          _understandProvider != null) {
        final lrcLines = await _parseLrcFile(output.lrcFilePath!);
        if (lrcLines.isNotEmpty) {
          _understandProvider!.loadLrcLines(lrcLines);
          debugPrint(
              '✅ Auto-loaded ${lrcLines.length} LRC lines after generate');
        }
        // Bật flag → UI sẽ bắt và mở panel + editor mode
        _lrcJustGenerated = true;
      }

      return output;
    } catch (e) {
      _lastSttError = e.toString();
      return null;
    } finally {
      _isGeneratingLrc = false;
      notifyListeners();
    }
  }

  /// Transcribe nhanh (Native) - dùng cho Shadowing
  Future<String> transcribeForShadowing(String audioPath) async {
    try {
      final output = await _sttService.transcribeQuick(audioPath);
      return output.success ? output.result.fullText : '';
    } catch (_) {
      return '';
    }
  }

  // Lấy trạng thái model Whisper
  SttModelInfo getSttModelInfo(WhisperModelLevel level) =>
      _sttService.getModelInfo(level);

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

    final normalizedPath = _currentSongPath!; // Đã được chuẩn hóa ở loadSong
    final audioId = 'local_${normalizedPath.toLowerCase().hashCode}';
    _recentAudio.updatePosition(
      audioId,
      position: position,
      totalDuration: _state.duration,
    );
  }

  void _onStateChanged(PlaybackState state) {
    final previousStatus = _state.status;
    final previousPosition = _state.position;

    // ── LOG mọi status change ──
    if (state.status != _state.status) {}

    // ── FIX 1: Hạ ngưỡng xuống 16ms (~60fps) để thanh chạy mượt ──
    bool shouldNotify = state.status != _state.status ||
        state.speed != _state.speed ||
        (state.position.inMilliseconds - _state.position.inMilliseconds).abs() >
            16;

    _state = state;

    // ── FIX 2: Xử lý completed KHÔNG dùng return sớm ──
    if (state.status == PlaybackStatus.completed &&
        previousStatus != PlaybackStatus.completed &&
        !_hasHandledCompletion) {
      debugPrint('🏁 COMPLETED CAUGHT: repeatTrack=$_repeatTrack');

      if (_repeatTrack) {
        _hasHandledCompletion = true;
        _handleRepeatTrack(); // fire and forget
      }
    }

    // Reset flag khi playing bình thường
    if (state.status == PlaybackStatus.playing) {
      _hasHandledCompletion = false;
    }

    // Pending recent update
    if (_pendingRecentUpdate != null && state.duration > Duration.zero) {
      final entry = _pendingRecentUpdate!;
      _pendingRecentUpdate = null;
      _recentAudio.updatePosition(
        entry.id,
        position: Duration.zero,
        totalDuration: state.duration,
      );
    }

    // AB Loop check
    if (_isLooping && _loopEnd != null && !_isWaitingGap) {
      _checkLoopPosition(state.position, previousPosition);
      if (state.position < previousPosition) shouldNotify = true;
    }

    // Stats
    if (state.status == PlaybackStatus.playing) {
      _totalListeningTime += const Duration(milliseconds: 100);
      _maybeUpdateRecentPosition(state.position);
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
    final normalizedPath = path.replaceAll('\\', '/');

    // ★ TASK 5: Dọn dẹp dữ liệu LRC bài cũ ngay khi đổi sang bài mới
    // Chỉ clear nếu thực sự đổi bài (tránh clear khi load lại cùng bài)
    if (_currentSongPath != null &&
        _normalizePath(_currentSongPath!) != _normalizePath(normalizedPath)) {
      _understandProvider?.clear();
      debugPrint('🧹 Cleared UnderstandProvider for new song: $normalizedPath');
    }

    _currentSongPath = normalizedPath;
    _currentSongTitle = title ?? normalizedPath.split('/').last;
    _currentSongArtist = artist;

    clearLoop();
    _hasHandledCompletion = false; // Reset trạng thái kết thúc khi đổi bài
    _currentSegmentIndex = -1;
    _storage.saveLastAudioPath(normalizedPath);
    notifyListeners();

    // ★ THÊM: Lưu vào recent ngay khi load
    final recentEntry = RecentAudio.fromLocalFile(
      path: normalizedPath,
      title: _currentSongTitle!,
    );
    _pendingRecentUpdate = recentEntry;
    // Fire-and-forget — không await để không block playback
    _recentAudio.addOrUpdate(recentEntry);

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
        _recentAudio.updatePosition(
          recentEntry.id,
          position: Duration.zero,
          totalDuration: duration,
        );
      }

      // ★ TASK 2: Sau khi load file xong, scan cache LRC theo hash
      // Fire-and-forget để không block playback
      _autoLoadCachedLrc(normalizedPath);
    }
  }

  /// ★ TASK 2: Tự động tìm và nạp LRC cache khi load bài mới
  Future<void> _autoLoadCachedLrc(String normalizedPath) async {
    try {
      final cachedLrcPath = await _findCachedLrcPath(normalizedPath);

      if (cachedLrcPath != null) {
        final lrcLines = await _parseLrcFile(cachedLrcPath);
        if (lrcLines.isNotEmpty && _understandProvider != null) {
          _understandProvider!.loadLrcLines(lrcLines);
          _lastGeneratedLrcPath = cachedLrcPath;
          debugPrint(
            '✅ Auto-loaded cached LRC (${lrcLines.length} lines): $cachedLrcPath',
          );
          notifyListeners();
        }
        // Nếu có LRC → không cần mở _AIPanel (UI sẽ xử lý trong _onUnderstandChange)
      } else {
        // Không có LRC cache → UI nên mở _AIPanel mặc định
        // Bật flag để ListenModeScreen biết cần mở _AIPanel
        _shouldOpenAiPanel = true;
        notifyListeners();
        debugPrint(
            'ℹ️ No cached LRC found for: $normalizedPath → open AI panel');
      }
    } catch (e) {
      debugPrint('⚠️ _autoLoadCachedLrc error: $e');
    }
  }

  /// ★ TASK 2: Flag để UI mở _AIPanel khi không có LRC cache
  bool _shouldOpenAiPanel = false;
  bool get shouldOpenAiPanel => _shouldOpenAiPanel;

  /// UI gọi method này sau khi đã xử lý sự kiện shouldOpenAiPanel
  void consumeShouldOpenAiPanel() {
    if (_shouldOpenAiPanel) {
      _shouldOpenAiPanel = false;
      // Không gọi notifyListeners() — tránh vòng lặp render
    }
  }

  /// Helper normalize path (dùng nội bộ trong provider)
  String _normalizePath(String path) {
    return Uri.decodeFull(path.replaceAll('\\', '/').toLowerCase().trim());
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
      if (isPlaying) {
        await pause();
      } else {
        await play();
      }
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

    // Nếu không có vùng lặp AB -> kích hoạt lặp toàn bài (Repeat Track)
    if (_loopStart == null) {
      _repeatTrack = (count != 0);
    }
    debugPrint('🔁 setLoopCount: max=$_maxLoopCount '
        'repeatTrack=$_repeatTrack loopStart=$_loopStart');
    notifyListeners();

    notifyListeners();
  }

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

  Future<void> _handleRepeatTrack() async {
    if (_currentSongPath == null) return;

    _totalLoopsToday++;
    _storage.incrementLoopCount();

    // 1. Kiểm tra số lần lặp nếu không phải vô tận (-1)
    if (_maxLoopCount > 0) {
      _loopCount++;
      if (_loopCount >= _maxLoopCount) {
        // Đã đủ số lần lặp -> Dừng lặp
        _repeatTrack = false;
        _loopCount = 0;
        _maxLoopCount = 0;
        _hasHandledCompletion = false;
        notifyListeners();
        return;
      }
    }

    // 2. Xử lý khoảng lặng (Gap) nếu có
    if (_gapDuration > 0 &&
        !_gapDuration.isNaN && // ← THÊM guard
        !_gapDuration.isInfinite) {
      // ← THÊM guard
      _isWaitingGap = true;
      notifyListeners();

      await _audioService.pause();

      final gapMs = (_gapDuration * 1000).clamp(0.0, 30000.0).toInt();
      await Future.delayed(Duration(milliseconds: gapMs));

      if (!_repeatTrack) return; // Guard: người dùng tắt lặp trong khi chờ
      _isWaitingGap = false;
    }

    // 3. Thực hiện quay lại đầu bài và phát
    await _audioService.seek(Duration.zero);
    // Một delay nhỏ giúp engine ổn định hơn trên một số thiết bị
    await Future.delayed(const Duration(milliseconds: 150));
    await _audioService.play();

    _hasHandledCompletion = false;
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

  /// Khoảng lặng giữa các lần lặp AB (0 = tắt)
  void setSilenceDuration(Duration duration) {
    if (_silenceDuration == duration) return;
    _silenceDuration = duration;
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
    _repeatTrack = false;
    _hasHandledCompletion = false;
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
    _sttService.dispose(); // ★ THÊM
    _sleepTimer?.cancel();
    _positionSaverTimer?.cancel();
    _gapTimer?.cancel();
    _audioService.dispose();
    super.dispose();
  }

  SttTranscribeOutput? _lastSttOutput;
  SttTranscribeOutput? get lastSttOutput => _lastSttOutput;

  String? _lastSttError;
  String? get lastSttError => _lastSttError;

  bool _isGeneratingLrc = false;
  bool get isGeneratingLrc => _isGeneratingLrc;

  String get lastTranscriptText => _lastSttOutput?.result.fullText ?? '';

  String? _lastGeneratedLrcPath;
  String? get lastGeneratedLrcPath => _lastGeneratedLrcPath;
}
