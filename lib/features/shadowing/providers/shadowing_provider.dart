// lib/providers/shadowing_provider.dart

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_waveform/just_waveform.dart' as jw;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/shadowing_result.dart';
import '../services/offline_stt_service.dart';
import '../services/phoneme_analyzer.dart';
import '../services/pronunciation_service.dart';
import '../../../services/storage_service.dart';

class ShadowingSettings {
  final int repeatCount;
  final double playbackSpeed;
  final bool autoStart;
  final Duration maxRecordDuration; // ⬅️ THÊM

  const ShadowingSettings({
    this.repeatCount = 3,
    this.playbackSpeed = 1.0,
    this.autoStart = false,
    this.maxRecordDuration = const Duration(seconds: 30), // ⬅ THÊM DÒNG NÀY
  });
}

class ShadowingProvider extends ChangeNotifier {
  // ==================== STATE ====================
  ShadowingState _state = ShadowingState.idle;
  ShadowingState get state => _state;

  // Settings
  int _repeatCount = 3;
  int get repeatCount => _repeatCount;

  double _playbackSpeed = 1.0;
  double get playbackSpeed => _playbackSpeed;

  // Progress
  int _completedRepetitions = 0;
  int get completedRepetitions => _completedRepetitions;

  int _countdown = 3;
  int get countdown => _countdown;

  Duration _recordingDuration = Duration.zero;
  Duration get recordingDuration => _recordingDuration;

  // Audio paths
  String? _originalAudioPath;
  String? _userRecordingPath;
  String? get userRecordingPath => _userRecordingPath;

  // Loop region
  Duration? _loopStart;
  Duration? _loopEnd;
  Duration? get loopStart => _loopStart;
  Duration? get loopEnd => _loopEnd;

  // Segment (for compatibility)
  Duration? get segmentStart => _loopStart;
  Duration? get segmentEnd => _loopEnd;

  // Text
  String _practiceText = '';
  String get practiceText => _practiceText;

  // Results
  ShadowingResult? _currentResult;
  ShadowingResult? get currentResult => _currentResult;

  final List<ShadowingResult> _history = [];
  List<ShadowingResult> get history => _history;
  final List<ShadowingHistoryEntry> _savedHistory = [];
  List<ShadowingHistoryEntry> get savedHistory => List.unmodifiable(_savedHistory);

  // Scores
  double _similarityScore = 0.0;
  double get similarityScore => _similarityScore;

  // Audio services
  final AudioPlayer _player = AudioPlayer();
  final AudioRecorder _recorder = AudioRecorder();
  final StorageService _storage = StorageService();
  Timer? _recordingTimer;
  Timer? _autoStopTimer; // Thêm biến quản lý auto-stop
  Timer? _countdownTimer;
  Timer? _positionTimer;

  // Compatibility getters
  double get currentAmplitude => 0.0;
  List<double> get recordedWaveform => _currentResult?.userWaveform ?? [];
  ShadowingSettings get settings => const ShadowingSettings();
  Duration get recordedDuration => _recordingDuration;
  List<ShadowingResult> get sessionResults => _history;
  int get totalPracticeCount => _savedHistory.length;
  int? get lastScorePercent =>
      _savedHistory.isEmpty ? null : _savedHistory.first.overallScorePercent;
  int? get bestScorePercent => _savedHistory.isEmpty
      ? null
      : _savedHistory
          .map((e) => e.overallScorePercent)
          .reduce(math.max);
  double get averageScorePercent => _savedHistory.isEmpty
      ? 0.0
      : _savedHistory
              .map((e) => e.overallScorePercent)
              .reduce((a, b) => a + b) /
          _savedHistory.length;
  bool get isRecording => _state == ShadowingState.recording;
  bool get isPlaying => _state == ShadowingState.playingOriginal;
  bool get hasResult => _currentResult != null;

// ⬇️ THÊM CÁC GETTERS NÀY
  double get gapProgress {
    if (_loopStart == null ||
        _loopEnd == null ||
        _state != ShadowingState.playingOriginal) {
      return 0.0;
    }
    final duration = _loopEnd! - _loopStart!;
    if (duration.inMilliseconds == 0) return 0.0;
    return _completedRepetitions / _repeatCount;
  }

  int get countdownValue => _countdown;
  // ==================== INIT ====================
  ShadowingProvider() {
    _initServices();
  }

  Future<void> _initServices() async {
    await PhonemeAnalyzer.initialize();
    await OfflineSTTService.initialize();
    _loadSavedHistory();
    debugPrint('✅ Shadowing services initialized');
  }

  void _loadSavedHistory() {
    if (!_storage.isInitialized) return;
    try {
      final raw = _storage.getAllShadowingResults();
      final parsed = raw.map(ShadowingHistoryEntry.fromJson).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _savedHistory
        ..clear()
        ..addAll(parsed);
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ Error loading shadowing history: $e');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _recorder.dispose();
    _recordingTimer?.cancel();
    _autoStopTimer?.cancel();
    _countdownTimer?.cancel();
    _positionTimer?.cancel();
    super.dispose();
  }

  // ==================== SETTINGS ====================
  void setRepeatCount(int count) {
    final newCount = count.clamp(1, 10);
    if (_repeatCount == newCount) return; // ← THÊM
    _repeatCount = newCount;
    notifyListeners();
  }

  void setPlaybackSpeed(double speed) {
    final newSpeed = speed.clamp(0.5, 2.0);
    if (_playbackSpeed == newSpeed) return; // ← THÊM
    _playbackSpeed = newSpeed;
    notifyListeners();
  }

  void setLoopRegion(Duration start, Duration end) {
    if (_loopStart == start && _loopEnd == end) return; // ← THÊM
    _loopStart = start;
    _loopEnd = end;
    debugPrint('🔁 Loop region set: $start → $end');
    notifyListeners();
  }

  void setPracticeText(String text) {
    if (_practiceText == text) return; // ← THÊM
    _practiceText = text;
    debugPrint('📝 Practice text: $text');
    notifyListeners();
  }

  void setOriginalAudioPath(String path) {
    if (_originalAudioPath == path) return; // ← THÊM
    _originalAudioPath = path;
    debugPrint('🎵 Audio path: $path');
    notifyListeners();
  }

  void setSegment({
    required Duration start,
    required Duration end,
    required String audioPath,
    List<double> waveform = const [],
  }) {
    if (_loopStart == start &&
        _loopEnd == end &&
        _originalAudioPath == audioPath) {
      return; // ← THÊM
    }
    _loopStart = start;
    _loopEnd = end;
    _originalAudioPath = audioPath;
    notifyListeners();
  }

  // ==================== PLAY ORIGINAL (SỬA LỖI) ====================

  Future<void> playOriginal() async {
    if (_originalAudioPath == null || _originalAudioPath!.isEmpty) {
      debugPrint('❌ ERROR: _originalAudioPath is null or empty');
      return;
    }

    debugPrint('🎵 === PLAY ORIGINAL ===');
    debugPrint('🎵 Path: $_originalAudioPath');
    debugPrint('🎵 Loop: $_loopStart → $_loopEnd');
    debugPrint('🎵 Repeats: $_repeatCount, Speed: $_playbackSpeed');

    _setState(ShadowingState.playingOriginal);
    _completedRepetitions = 0;

    try {
      // Load audio file
      await _player.setFilePath(_originalAudioPath!);
      await _player.setSpeed(_playbackSpeed);

      final startPos = _loopStart ?? Duration.zero;
      final endPos =
          _loopEnd ?? _player.duration ?? const Duration(seconds: 10);

      debugPrint('🎵 Will play from $startPos to $endPos');

      // Play N times
      for (int i = 0; i < _repeatCount; i++) {
        if (_state != ShadowingState.playingOriginal) {
          debugPrint('🎵 Playback interrupted at repeat ${i + 1}');
          break;
        }

        _completedRepetitions = i + 1;
        notifyListeners();

        debugPrint('🎵 Playing repeat ${i + 1}/$_repeatCount');

        // Seek to start of loop
        await _player.seek(startPos);
        await _player.play();

        // Monitor position and stop at endPos
        await _waitUntilPosition(endPos);

        // Pause player
        await _player.pause();

        debugPrint('🎵 Repeat ${i + 1} complete');

        // Pause between repeats
        if (i < _repeatCount - 1) {
          await Future.delayed(const Duration(milliseconds: 800));
        }
      }

      debugPrint('🎵 All repeats complete, returning to idle');

      // ✅ QUAN TRỌNG: Quay về idle để nút hoạt động lại
      if (_state == ShadowingState.playingOriginal) {
        _setState(ShadowingState.idle);
      }
    } catch (e) {
      debugPrint('❌ Error playing audio: $e');
      _setState(ShadowingState.idle);
    }
  }

  /// Đợi cho đến khi player đến vị trí target
  Future<void> _waitUntilPosition(Duration targetPosition) async {
    final completer = Completer<void>();

    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      final currentPos = _player.position;

      // Kiểm tra đã đến vị trí target chưa
      if (currentPos >= targetPosition) {
        timer.cancel();
        if (!completer.isCompleted) completer.complete();
        return;
      }

      // Kiểm tra player đã dừng chưa
      if (!_player.playing) {
        timer.cancel();
        if (!completer.isCompleted) completer.complete();
        return;
      }

      // Kiểm tra state đã thay đổi chưa (user cancel)
      if (_state != ShadowingState.playingOriginal) {
        timer.cancel();
        if (!completer.isCompleted) completer.complete();
        return;
      }
    });

    // Timeout safety (max 60 seconds)
    return completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        _positionTimer?.cancel();
        debugPrint('⚠️ Playback timeout');
      },
    );
  }

  // ==================== RECORDING ====================

  Future<void> startShadowing(String text) async {
    if (text.trim().isNotEmpty) {
      setPracticeText(text);
    }
    if (_state == ShadowingState.recording) {
      await stopRecording();
    } else {
      _startCountdown();
    }
  }

  void _startCountdown() {
    _setState(ShadowingState.countdown);
    _countdown = 3;
    notifyListeners();

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _countdown--;
      notifyListeners();

      debugPrint('⏱️ Countdown: $_countdown');

      if (_countdown <= 0) {
        timer.cancel();
        _startRecording();
      }
    });
  }

  Future<void> _startRecording() async {
    _setState(ShadowingState.recording);
    _recordingDuration = Duration.zero;

    debugPrint('🎤 Starting recording...');

    try {
      if (await _recorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/shadowing_${DateTime.now().millisecondsSinceEpoch}.wav';

        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 44100,
            numChannels: 1,
          ),
          path: path,
        );

        _userRecordingPath = path;
        debugPrint('🎤 Recording to: $path');

        _recordingTimer?.cancel();
        _recordingTimer =
            Timer.periodic(const Duration(milliseconds: 200), (timer) {
          _recordingDuration += const Duration(milliseconds: 200);
          notifyListeners();
        });

        // Auto-stop after 30 seconds
        _autoStopTimer?.cancel();
        _autoStopTimer = Timer(const Duration(seconds: 30), () {
          if (_state == ShadowingState.recording) {
            debugPrint('🎤 Auto-stopping recording (30s limit)');
            stopRecording();
          }
        });
      } else {
        debugPrint('❌ No recording permission');
        _setState(ShadowingState.idle);
      }
    } catch (e) {
      debugPrint('❌ Error starting recording: $e');
      _setState(ShadowingState.idle);
    }
  }

  Future<void> stopRecording() async {
    if (_state != ShadowingState.recording) return;
    _autoStopTimer?.cancel(); // Hủy timer ngay khi dừng

    debugPrint('🎤 Stopping recording...');
    _recordingTimer?.cancel();

    try {
      final path = await _recorder.stop();
      if (path != null) {
        _userRecordingPath = path;
        debugPrint('🎤 Recording saved: $path');
        debugPrint('🎤 Duration: $_recordingDuration');
        await _analyzeRecording();
      } else {
        debugPrint('❌ Recording path is null');
        _setState(ShadowingState.idle);
      }
    } catch (e) {
      debugPrint('❌ Error stopping recording: $e');
      _setState(ShadowingState.idle);
    }
  }

  // ==================== ANALYSIS (SỬA LỖI ĐIỂM) ====================

  Future<void> _analyzeRecording() async {
    _setState(ShadowingState.analyzing);

    debugPrint('🔍 === ANALYZING ===');
    debugPrint('🔍 Practice text: "$_practiceText"');
    debugPrint('🔍 Recording path: $_userRecordingPath');

    try {
      // ✅ Nếu text rỗng, dùng fallback
      String textToAnalyze = _practiceText;
      if (textToAnalyze.trim().isEmpty) {
        textToAnalyze = 'hello world'; // Fallback text
        debugPrint('⚠️ Practice text empty, using fallback: "$textToAnalyze"');
      }

      String recognizedText = await OfflineSTTService.transcribe(
        _userRecordingPath!,
        textToAnalyze,
      );

      debugPrint('📝 Original:   "$textToAnalyze"');
      debugPrint('🎤 Recognized: "$recognizedText"');

      final originalWaveform = await _extractWaveform(_originalAudioPath);
      final userWaveform = await _extractWaveform(_userRecordingPath);

      _currentResult = PronunciationService.analyze(
        originalText: textToAnalyze,
        recognizedText: recognizedText,
        originalWaveform: originalWaveform,
        userWaveform: userWaveform,
        originalDuration: _loopEnd != null && _loopStart != null
            ? _loopEnd! - _loopStart!
            : Duration.zero,
        userDuration: _recordingDuration,
      );

      _similarityScore = _currentResult!.overallScore;
      _history.add(_currentResult!);
      await _storage.saveShadowingResult(_currentResult!);
      final savedEntry = ShadowingHistoryEntry.fromJson(_currentResult!.toJson());
      _savedHistory.removeWhere((e) => e.id == savedEntry.id);
      _savedHistory.insert(0, savedEntry);

      debugPrint('📊 === RESULTS ===');
      debugPrint(
          '📊 Overall Score: ${(_currentResult!.overallScore * 100).toStringAsFixed(1)}%');
      debugPrint('📊 Grade: ${_currentResult!.overallGrade}');

      for (final wr in _currentResult!.wordResults) {
        debugPrint(
            '   📖 "${wr.expectedWord}" → "${wr.recognizedWord}" = ${wr.scorePercent}%');
        for (final ps in wr.phonemeScores) {
          debugPrint(
              '      /${ps.phoneme}/ = ${ps.scorePercent}% [${ps.grade}]');
        }
      }
    } catch (e) {
      debugPrint('❌ Error analyzing: $e');
      _setState(ShadowingState.idle);
    } finally {
      if (_state == ShadowingState.analyzing) {
        _setState(ShadowingState.showingResults);
      }
    }
  }

  Future<List<double>> _extractWaveform(String? path) async {
    if (path == null) return [];
    final file = File(path);
    if (!await file.exists()) return [];

    try {
      final waveformFile = File('$path.waveform');
      final progressStream = jw.JustWaveform.extract(
        audioInFile: file,
        waveOutFile: waveformFile,
        zoom: const jw.WaveformZoom.pixelsPerSecond(100),
      );

      jw.Waveform? waveform;
      await for (final progress in progressStream) {
        if (progress.waveform != null) {
          waveform = progress.waveform;
        }
      }

      if (waveform != null) {
        final data = waveform.data;
        final samples = <double>[];
        int maxAmp = 1;
        for (var s in data) {
          if (s.abs() > maxAmp) maxAmp = s.abs();
        }

        // Downsample to ~500 points for display/storage
        final step = math.max(1, data.length ~/ 500);
        for (int i = 0; i < data.length; i += step) {
          int chunkMax = 0;
          for (int j = i; j < math.min(i + step, data.length); j++) {
            if (data[j].abs() > chunkMax) chunkMax = data[j].abs();
          }
          samples.add(chunkMax / maxAmp);
        }

        try {
          await waveformFile.delete();
        } catch (_) {}

        return samples;
      }
    } catch (e) {
      debugPrint('Waveform extraction error: $e');
      return [];
    }
    return [];
  }

  // ==================== PLAYBACK ====================

  Future<void> playUserRecording() async {
    if (_userRecordingPath == null) return;

    try {
      await _player.setFilePath(_userRecordingPath!);
      await _player.play();
    } catch (e) {
      debugPrint('Error playing user recording: $e');
    }
  }

  // ==================== RESET ====================

  void reset() {
    _player.stop();
    _recordingTimer?.cancel();
    _countdownTimer?.cancel();
    _positionTimer?.cancel();

    _state = ShadowingState.idle;
    _completedRepetitions = 0;
    _countdown = 3;
    _recordingDuration = Duration.zero;
    _currentResult = null;
    _similarityScore = 0.0;

    notifyListeners();
  }

  /// Retry (alias for reset)
  void retry() {
    reset();
  }

  Future<void> clearSavedHistory() async {
    _savedHistory.clear();
    await _storage.clearShadowingHistory();
    notifyListeners();
  }

  void stopPlayback() {
    _player.stop();
    _positionTimer?.cancel();
    _setState(ShadowingState.idle);
  }

  void _setState(ShadowingState newState) {
    debugPrint('🔄 State: $_state → $newState');
    _state = newState;
    notifyListeners();
  }
}
