// lib/providers/shadowing_provider.dart
// ShadowingProvider - Quản lý state cho Shadowing với IPA Analysis
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/shadowing_result.dart';
import '../services/shadowing/offline_stt_service.dart';
import '../services/shadowing/phoneme_analyzer_v2.dart';
import '../services/shadowing/pronunciation_assessment.dart';

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

  // Text to practice
  String _practiceText = '';
  String get practiceText => _practiceText;

  // Results
  ShadowingResult? _currentResult;
  ShadowingResult? get currentResult => _currentResult;

  List<ShadowingResult> _history = [];
  List<ShadowingResult> get history => _history;

  // Scores
  double _similarityScore = 0.0;
  double get similarityScore => _similarityScore;

  // Audio players/recorders
  final AudioPlayer _player = AudioPlayer();
  final AudioRecorder _recorder = AudioRecorder();

  Timer? _recordingTimer;
  Timer? _countdownTimer;

  // === COMPATIBILITY GETTERS ===
  // Để tương thích với ShadowingWidget cũ
  Duration? get segmentStart => _loopStart;
  Duration? get segmentEnd => _loopEnd;
  ShadowingResult? get lastResult => _currentResult;
  int get countdownValue => _countdown;
  double get gapProgress => 0.0; // Chưa implement gap progress visual
  double get currentAmplitude => 0.0; // Chưa implement live amplitude
  List<double> get recordedWaveform => _currentResult?.userWaveform ?? [];
  ShadowingSettings get settings => ShadowingSettings(
        repeatCount: _repeatCount,
        playbackSpeed: _playbackSpeed,
      );
  Duration get recordedDuration =>
      _recordingDuration; // Alias cho recordedDuration
  List<ShadowingResult> get sessionResults => _history; // Alias cho history

  // ==================== GETTERS ====================
  bool get isRecording => _state == ShadowingState.recording;
  bool get isPlaying => _state == ShadowingState.playingOriginal;
  bool get hasResult => _currentResult != null;

  // ==================== INITIALIZATION ====================
  ShadowingProvider() {
    _initServices();
  }

  Future<void> _initServices() async {
    await PhonemeAnalyzer.initialize();
    await OfflineSTTService.initialize();
    debugPrint('✅ Services initialized');
  }

  @override
  void dispose() {
    _player.dispose();
    _recorder.dispose();
    _recordingTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ==================== SETTINGS ====================
  void setRepeatCount(int count) {
    _repeatCount = count.clamp(1, 10);
    notifyListeners();
  }

  void setPlaybackSpeed(double speed) {
    _playbackSpeed = speed.clamp(0.5, 2.0);
    notifyListeners();
  }

  void setLoopRegion(Duration start, Duration end) {
    _loopStart = start;
    _loopEnd = end;
    notifyListeners();
  }

  void setPracticeText(String text) {
    _practiceText = text;
    notifyListeners();
  }

  void setOriginalAudioPath(String path) {
    _originalAudioPath = path;
    notifyListeners();
  }

  void setSegment({
    required Duration start,
    required Duration end,
    required String audioPath,
    List<double> waveform = const [],
  }) {
    setLoopRegion(start, end);
    setOriginalAudioPath(audioPath);
    // Trigger state change to ready if needed
    if (_state == ShadowingState.idle) {
      _state = ShadowingState.idle; // Giữ idle để chờ user bấm start
      notifyListeners();
    }
  }

  // ==================== MAIN ACTIONS ====================

  /// Play original audio
  Future<void> playOriginal() async {
    if (_originalAudioPath == null) return;

    _setState(ShadowingState.playingOriginal);
    _completedRepetitions = 0;

    try {
      await _player.setFilePath(_originalAudioPath!);
      await _player.setSpeed(_playbackSpeed);

      if (_loopStart != null && _loopEnd != null) {
        await _player.setClip(start: _loopStart, end: _loopEnd);
      }

      for (int i = 0; i < _repeatCount; i++) {
        if (_state != ShadowingState.playingOriginal) break;

        await _player.seek(Duration.zero);
        await _player.play();

        // Wait for playback to complete
        await _player.playerStateStream.firstWhere(
          (state) => state.processingState == ProcessingState.completed,
        );

        _completedRepetitions = i + 1;
        notifyListeners();

        // Pause between repeats
        if (i < _repeatCount - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      if (_state == ShadowingState.playingOriginal) {
        _startCountdown();
      }
    } catch (e) {
      debugPrint('Error playing audio: $e');
      _setState(ShadowingState.idle);
    }
  }

  /// Start countdown before recording
  void _startCountdown() {
    _setState(ShadowingState.countdown);
    _countdown = 3;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _countdown--;
      notifyListeners();

      if (_countdown <= 0) {
        timer.cancel();
        _startRecording();
      }
    });
  }

  /// Start recording
  Future<void> _startRecording() async {
    _setState(ShadowingState.recording);
    _recordingDuration = Duration.zero;

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

        _recordingTimer =
            Timer.periodic(const Duration(milliseconds: 100), (timer) {
          _recordingDuration += const Duration(milliseconds: 100);
          notifyListeners();
        });
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
      _setState(ShadowingState.idle);
    }
  }

  /// Stop recording and analyze
  Future<void> stopRecording() async {
    if (_state != ShadowingState.recording) return;

    _recordingTimer?.cancel();

    try {
      final path = await _recorder.stop();
      if (path != null) {
        _userRecordingPath = path;
        await _analyzeRecording();
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      _setState(ShadowingState.idle);
    }
  }

  /// Start shadowing session
  Future<void> startShadowing() async {
    if (_state == ShadowingState.recording) {
      await stopRecording();
    } else {
      await _startRecording();
    }
  }

  /// Analyze the recording
  Future<void> _analyzeRecording() async {
    _setState(ShadowingState.analyzing);

    try {
      // Sử dụng STT service
      String recognizedText = await OfflineSTTService.transcribe(
        _userRecordingPath!,
        _practiceText,
      );

      // Extract waveforms
      final originalWaveform = await _extractWaveform(_originalAudioPath);
      final userWaveform = await _extractWaveform(_userRecordingPath);

      // Analyze pronunciation
      _currentResult = PronunciationService.analyze(
        originalText: _practiceText,
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

      _setState(ShadowingState.showingResults);
    } catch (e) {
      debugPrint('Error analyzing: $e');
      _setState(ShadowingState.idle);
    }
  }

  /// Extract waveform from audio file
  Future<List<double>> _extractWaveform(String? path) async {
    if (path == null) return [];

    try {
      final file = File(path);
      if (!await file.exists()) return [];

      final bytes = await file.readAsBytes();

      // Simple waveform extraction
      final samples = <double>[];
      for (int i = 0; i < bytes.length; i += 1000) {
        if (i < bytes.length) {
          samples.add(bytes[i] / 255.0);
        }
      }

      // Normalize to 100 samples
      while (samples.length > 100) {
        final newSamples = <double>[];
        for (int i = 0; i < samples.length - 1; i += 2) {
          newSamples.add((samples[i] + samples[i + 1]) / 2);
        }
        samples.clear();
        samples.addAll(newSamples);
      }

      return samples;
    } catch (e) {
      return [];
    }
  }

  /// Play user recording
  Future<void> playUserRecording() async {
    if (_userRecordingPath == null) return;

    try {
      await _player.setFilePath(_userRecordingPath!);
      await _player.play();
    } catch (e) {
      debugPrint('Error playing user recording: $e');
    }
  }

  void retry() {
    // Reset result but keep settings
    _currentResult = null;
    _state = ShadowingState.idle;
    notifyListeners();
  }

  /// Reset to idle state
  void reset() {
    _player.stop();
    _recordingTimer?.cancel();
    _countdownTimer?.cancel();

    _state = ShadowingState.idle;
    _completedRepetitions = 0;
    _countdown = 3;
    _recordingDuration = Duration.zero;
    _currentResult = null;
    _similarityScore = 0.0;

    notifyListeners();
  }

  void _setState(ShadowingState newState) {
    _state = newState;
    notifyListeners();
  }
}

/// Dummy settings class for compatibility
class ShadowingSettings {
  final int repeatCount;
  final double playbackSpeed;
  final bool autoStart;
  final double maxRecordDuration;
  const ShadowingSettings({
    this.repeatCount = 3,
    this.playbackSpeed = 1.0,
    this.autoStart = false,
    this.maxRecordDuration = 60.0,
  });
}
