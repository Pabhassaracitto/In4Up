// lib/providers/shadowing_provider.dart

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_waveform/just_waveform.dart' as jw;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../models/learning_activity.dart';
import '../../../services/learning_activity_service.dart';
import '../models/shadowing_preset.dart';
import '../models/shadowing_result.dart';
import '../services/offline_stt_service.dart';
import '../services/phoneme_analyzer.dart';
import '../services/pronunciation_service.dart';
import '../services/lrc_ab_suggestions.dart';
import '../services/shadowing_sample_player.dart';
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
  static const List<ShadowingPreset> _builtInPresets = [
    ShadowingPreset(
      id: 'slow_mimic',
      name: 'Slow Mimic',
      repeatCount: 5,
      playbackSpeed: 0.75,
      description: 'Chậm và nhiều vòng để bắt chước kỹ từng âm.',
      isBuiltIn: true,
    ),
    ShadowingPreset(
      id: 'pronunciation_focus',
      name: 'Pronunciation',
      repeatCount: 4,
      playbackSpeed: 0.8,
      description: 'Tập trung vào độ rõ âm và độ chính xác phát âm.',
      isBuiltIn: true,
    ),
    ShadowingPreset(
      id: 'balanced_flow',
      name: 'Balanced',
      repeatCount: 3,
      playbackSpeed: 0.9,
      description: 'Cân bằng giữa phát âm, trí nhớ và nhịp phản xạ.',
      isBuiltIn: true,
    ),
    ShadowingPreset(
      id: 'fluency_boost',
      name: 'Fluency',
      repeatCount: 2,
      playbackSpeed: 1.0,
      description: 'Ưu tiên nhịp nói tự nhiên và giữ mạch câu.',
      isBuiltIn: true,
    ),
  ];

  // ==================== STATE ====================
  ShadowingState _state = ShadowingState.idle;
  ShadowingState get state => _state;

  // Settings
  int _repeatCount = 3;
  int get repeatCount => _repeatCount;

  double _playbackSpeed = 1.0;
  double get playbackSpeed => _playbackSpeed;

  String? _activePresetLabel;
  String get activePresetLabel => _activePresetLabel ?? 'Tùy chỉnh';
  bool get activePresetLabelIsGenerated => _activePresetLabel == null;

  final List<ShadowingPreset> _customPresets = [];
  List<ShadowingPreset> get customPresets => List.unmodifiable(_customPresets);
  List<ShadowingPreset> get builtInPresets => List.unmodifiable(_builtInPresets);

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

  /// SHADOW-FILE-001: luyện "toàn track" = không có đoạn A-B.
  bool get hasLoopRegion => _loopStart != null && _loopEnd != null;
  bool get isWholeTrack => !hasLoopRegion;

  /// Lỗi nguồn audio (path mất / ENOENT) để UI hiện hướng dẫn chọn lại file
  /// thay vì im lặng. Được set trong playOriginal, clear khi đổi nguồn.
  String? _sourceError;
  String? get sourceError => _sourceError;

  String? _analysisError;
  String? get analysisError => _analysisError;

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
  late final ShadowingSamplePlayer _samplePlayer;
  final AudioRecorder _recorder = AudioRecorder();
  final StorageService _storage = StorageService();
  Timer? _recordingTimer;
  Timer? _autoStopTimer; // Thêm biến quản lý auto-stop
  Timer? _countdownTimer;

  List<AbSuggestion> get sentenceSuggestions => _samplePlayer.sentences;
  int get selectedSentenceIndex => _samplePlayer.selectedIndex;
  AbSuggestion? get selectedSentence => _samplePlayer.selectedSentence;

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
    // SHADOW-FILE-001: hoạt động cả khi luyện toàn track (không có A-B) —
    // tiến độ tính theo số vòng nghe mẫu, không phụ thuộc loop region.
    if (_state != ShadowingState.playingOriginal || _repeatCount <= 0) {
      return 0.0;
    }
    return (_completedRepetitions / _repeatCount).clamp(0.0, 1.0);
  }

  int get countdownValue => _countdown;
  // ==================== INIT ====================
  ShadowingProvider() {
    _samplePlayer = ShadowingSamplePlayer(
      audio: _JustAudioSampleAdapter(_player),
      sourceExists: (path) => File(path).existsSync(),
    );
    _initServices();
  }

  Future<void> _initServices() async {
    await PhonemeAnalyzer.initialize();
    await OfflineSTTService.initialize();
    _restorePresetState();
    _loadSavedHistory();
    debugPrint('✅ Shadowing services initialized');
  }

  void _restorePresetState() {
    if (!_storage.isInitialized) return;
    try {
      _repeatCount = _storage.getShadowingRepeatCount().clamp(1, 10);
      _playbackSpeed =
          _storage.getShadowingPlaybackSpeed().clamp(0.5, 2.0).toDouble();
      _activePresetLabel = _storage.getShadowingPresetLabel();
      final rawPresets = _storage.getShadowingCustomPresets();
      _customPresets
        ..clear()
        ..addAll(rawPresets.map(ShadowingPreset.fromJson));
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ Error restoring shadowing presets: $e');
    }
  }

  Future<void> _persistPresetState() async {
    if (!_storage.isInitialized) return;
    await _storage.saveShadowingRepeatCount(_repeatCount);
    await _storage.saveShadowingPlaybackSpeed(_playbackSpeed);
    await _storage.saveShadowingPresetLabel(_activePresetLabel);
    await _storage.saveShadowingCustomPresets(
      _customPresets.map((e) => e.toJson()).toList(),
    );
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
    _samplePlayer.dispose();
    _player.dispose();
    _recorder.dispose();
    _recordingTimer?.cancel();
    _autoStopTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ==================== SETTINGS ====================
  void setRepeatCount(int count, {bool markCustom = true}) {
    final newCount = count.clamp(1, 10);
    if (_repeatCount == newCount) return;
    _repeatCount = newCount;
    if (markCustom) _activePresetLabel = null;
    notifyListeners();
    _persistPresetState();
  }

  void setPlaybackSpeed(double speed, {bool markCustom = true}) {
    final newSpeed = speed.clamp(0.5, 2.0);
    if (_playbackSpeed == newSpeed) return;
    _playbackSpeed = newSpeed;
    if (markCustom) _activePresetLabel = null;
    notifyListeners();
    _persistPresetState();
  }

  Future<void> applyPreset(ShadowingPreset preset) async {
    _repeatCount = preset.repeatCount.clamp(1, 10);
    _playbackSpeed = preset.playbackSpeed.clamp(0.5, 2.0).toDouble();
    _activePresetLabel = preset.name;
    notifyListeners();
    await _persistPresetState();
  }

  Future<void> saveCurrentAsPreset({
    required String name,
    String description = '',
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final preset = ShadowingPreset(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: trimmed,
      repeatCount: _repeatCount,
      playbackSpeed: _playbackSpeed,
      description: description.trim(),
    );

    _customPresets.insert(0, preset);
    _activePresetLabel = preset.name;
    notifyListeners();
    await _persistPresetState();
  }

  Future<void> deleteCustomPreset(String id) async {
    final removed = _customPresets.where((e) => e.id == id).toList();
    _customPresets.removeWhere((e) => e.id == id);
    if (removed.isNotEmpty && _activePresetLabel == removed.first.name) {
      _activePresetLabel = null;
    }
    notifyListeners();
    await _persistPresetState();
  }

  void setLoopRegion(Duration start, Duration end) {
    if (_loopStart == start && _loopEnd == end) return;
    _loopStart = start;
    _loopEnd = end;
    _sourceError = null;
    final selected = selectedSentence;
    if (selected == null || selected.start != start || selected.end != end) {
      _samplePlayer.clearSelection();
      _practiceText = '';
    }
    notifyListeners();
  }

  /// Bỏ A-B là luyện cả nguồn, không giữ nhầm câu chấm điểm cũ.
  void clearLoopRegion() {
    _samplePlayer.clearSelection();
    _practiceText = '';
    if (_loopStart == null && _loopEnd == null) return;
    _loopStart = null;
    _loopEnd = null;
    notifyListeners();
  }

  void setPracticeText(String text) {
    if (_practiceText == text) return;
    _practiceText = text;
    notifyListeners();
  }

  void setOriginalAudioPath(String path) {
    if (_originalAudioPath == path) return;
    _originalAudioPath = path;
    _sourceError = null;
    notifyListeners();
  }

  void setSegment({
    required Duration start,
    required Duration end,
    required String audioPath,
    List<double> waveform = const [],
  }) {
    if (_loopStart == start && _loopEnd == end &&
        _originalAudioPath == audioPath) return;
    _loopStart = start;
    _loopEnd = end;
    _originalAudioPath = audioPath;
    _sourceError = null;
    final selected = selectedSentence;
    if (selected == null || selected.start != start || selected.end != end) {
      _samplePlayer.clearSelection();
      _practiceText = '';
    }
    notifyListeners();
  }

  /// Dùng lại LRC đã có; không tạo lời/AI và không đổi nguồn audio ngầm.
  void setSentenceSuggestions({
    required String? audioPath,
    required List<AbSuggestion> suggestions,
  }) {
    final changed = _samplePlayer.configure(
      audioPath: audioPath,
      sentences: suggestions,
    );
    if (!changed) return;
    if (audioPath != null && audioPath.isNotEmpty) {
      _originalAudioPath = audioPath;
    }
    final selected = selectedSentence;
    if (selected != null) {
      _applySentence(selected);
    } else {
      _practiceText = '';
      _currentResult = null;
      _userRecordingPath = null;
      _similarityScore = 0;
    }
    notifyListeners();
  }

  void _applySentence(AbSuggestion sentence) {
    final changed = _practiceText != sentence.text ||
        _loopStart != sentence.start || _loopEnd != sentence.end;
    _loopStart = sentence.start;
    _loopEnd = sentence.end;
    _practiceText = sentence.text;
    _sourceError = null;
    if (changed) {
      _currentResult = null;
      _userRecordingPath = null;
      _similarityScore = 0;
      _analysisError = null;
    }
  }

  bool selectSentence(int index) {
    final sentence = _samplePlayer.sentenceAt(index);
    if (sentence == null || !_samplePlayer.selectSentence(index)) return false;
    _applySentence(sentence);
    notifyListeners();
    return true;
  }

  /// Every sentence-sample button uses this entry point. Selecting a sentence
  /// and pressing play cannot pick up a different line from the other tab.
  Future<void> speakSentence(int index) {
    if (!selectSentence(index)) return Future.value();
    return _samplePlayer.speakSentence(
      index,
      speed: _playbackSpeed,
      onStarted: _onSampleStarted,
      onRepeat: _onSampleRepeat,
      onFinished: _onSampleFinished,
      onError: _onSampleError,
    );
  }

  Future<void> playOriginal() => _samplePlayer.playOriginal(
        start: _loopStart,
        end: _loopEnd,
        speed: _playbackSpeed,
        repeatCount: _repeatCount,
        onStarted: _onSampleStarted,
        onRepeat: _onSampleRepeat,
        onFinished: _onSampleFinished,
        onError: _onSampleError,
      );

  void _onSampleStarted() {
    _sourceError = null;
    _analysisError = null;
    _completedRepetitions = 0;
    _setState(ShadowingState.playingOriginal);
  }

  void _onSampleRepeat(int repeat) {
    _completedRepetitions = repeat;
    notifyListeners();
  }

  void _onSampleFinished() {
    _setState(ShadowingState.idle);
  }

  void _onSampleError(String error) {
    _sourceError = error;
    _setState(ShadowingState.idle);
  }

  void stopPlayback() {
    unawaited(_samplePlayer.stop());
    _setState(ShadowingState.idle);
  }

  // ==================== RECORDING ====================

  Future<void> startShadowing(String text) async {
    stopPlayback();
    _analysisError = null;
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
    final textToAnalyze = _practiceText.trim();
    final recordingPath = _userRecordingPath;
    _analysisError = null;
    if (textToAnalyze.isEmpty) {
      _currentResult = null;
      _similarityScore = 0;
      _analysisError = 'no_reference';
      _setState(ShadowingState.idle);
      return;
    }
    if (recordingPath == null || recordingPath.isEmpty) {
      _currentResult = null;
      _similarityScore = 0;
      _analysisError = 'no_speech';
      _setState(ShadowingState.idle);
      return;
    }
    _setState(ShadowingState.analyzing);

    try {
      final recognizedText = await OfflineSTTService.transcribe(recordingPath);
      if (recognizedText == null || recognizedText.trim().isEmpty) {
        _currentResult = null;
        _similarityScore = 0;
        _analysisError = 'no_speech';
        _setState(ShadowingState.idle);
        return;
      }

      final originalWaveform = await _extractWaveform(_originalAudioPath);
      final userWaveform = await _extractWaveform(recordingPath);
      final result = PronunciationService.analyze(
        originalText: textToAnalyze,
        recognizedText: recognizedText,
        originalWaveform: originalWaveform,
        userWaveform: userWaveform,
        originalDuration: _loopEnd != null && _loopStart != null
            ? _loopEnd! - _loopStart!
            : Duration.zero,
        userDuration: _recordingDuration,
      );
      _currentResult = result;
      _similarityScore = result.overallScore;
      _history.add(result);
      await _storage.saveShadowingResult(result);
      final savedEntry = ShadowingHistoryEntry.fromJson(result.toJson());
      _savedHistory.removeWhere((e) => e.id == savedEntry.id);
      _savedHistory.insert(0, savedEntry);

      unawaited(LearningActivityService.instance.record(
        LearningActivityKind.shadowing,
        sourceKey: savedEntry.id,
      ));
      _setState(ShadowingState.showingResults);
    } catch (e) {
      debugPrint('❌ Error analyzing shadowing recording: $e');
      _currentResult = null;
      _similarityScore = 0;
      _analysisError = 'analysis_failed';
      _setState(ShadowingState.idle);
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
    stopPlayback();
    await _samplePlayer.stop();

    try {
      await _player.setFilePath(_userRecordingPath!);
      await _player.play();
    } catch (e) {
      debugPrint('Error playing user recording: $e');
    }
  }

  // ==================== RESET ====================

  void reset() {
    unawaited(_samplePlayer.stop());
    _recordingTimer?.cancel();
    _autoStopTimer?.cancel();
    _countdownTimer?.cancel();

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

  void _setState(ShadowingState newState) {
    debugPrint('🔄 State: $_state → $newState');
    _state = newState;
    notifyListeners();
  }
}

/// Dart interfaces are nominal: just_audio has the operations we need but does
/// not declare `implements ShadowingSampleAudio`. Adapt explicitly at the edge.
class _JustAudioSampleAdapter implements ShadowingSampleAudio {
  _JustAudioSampleAdapter(this._player);
  final AudioPlayer _player;

  @override
  Duration get position => _player.position;
  @override
  Duration? get duration => _player.duration;
  @override
  Future<Duration?> setFilePath(String path) => _player.setFilePath(path);
  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> stop() => _player.stop();
}
