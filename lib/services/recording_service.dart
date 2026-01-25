import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Service xử lý ghi âm với package record
class RecordingService {
  // Singleton
  static final RecordingService _instance = RecordingService._internal();
  factory RecordingService() => _instance;
  RecordingService._internal();

  // Record instance
  final AudioRecorder _recorder = AudioRecorder();

  // State
  bool _isRecording = false;
  bool _isPaused = false;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;

  // Streams
  final _stateController = StreamController<RecordingState>.broadcast();
  final _amplitudeController = StreamController<double>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();

  Timer? _durationTimer;
  StreamSubscription<Amplitude>? _amplitudeSubscription;

  // Waveform data được thu thập trong quá trình ghi
  final List<double> _recordingWaveform = [];

  // Getters
  bool get isRecording => _isRecording;
  bool get isPaused => _isPaused;
  String? get currentRecordingPath => _currentRecordingPath;
  List<double> get recordingWaveform => List.unmodifiable(_recordingWaveform);

  Stream<RecordingState> get stateStream => _stateController.stream;
  Stream<double> get amplitudeStream => _amplitudeController.stream;
  Stream<Duration> get durationStream => _durationController.stream;

  Duration get currentDuration {
    if (_recordingStartTime == null) return Duration.zero;
    return DateTime.now().difference(_recordingStartTime!);
  }

  /// Kiểm tra quyền microphone
  Future<bool> checkPermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;

    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  /// Kiểm tra recorder có sẵn sàng không
  Future<bool> isRecorderReady() async {
    return await _recorder.hasPermission();
  }

  /// Bắt đầu ghi âm
  Future<bool> startRecording({String? customPath}) async {
    if (_isRecording) {
      debugPrint('RecordingService: Already recording');
      return false;
    }

    // Check permission
    final hasPermission = await checkPermission();
    if (!hasPermission) {
      debugPrint('RecordingService: Microphone permission denied');
      _stateController.add(RecordingState.permissionDenied);
      return false;
    }

    try {
      // Generate file path
      if (customPath != null) {
        _currentRecordingPath = customPath;
      } else {
        final dir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        _currentRecordingPath = '${dir.path}/shadowing_$timestamp.m4a';
      }

      // Clear previous waveform data
      _recordingWaveform.clear();

      // Configure recording
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        bitRate: 128000,
        numChannels: 1,
      );

      // Start recording
      await _recorder.start(config, path: _currentRecordingPath!);

      _isRecording = true;
      _isPaused = false;
      _recordingStartTime = DateTime.now();

      _stateController.add(RecordingState.recording);

      // Start duration timer
      _startDurationTimer();

      // Start amplitude monitoring
      _startAmplitudeMonitoring();

      debugPrint('RecordingService: Started recording to $_currentRecordingPath');
      return true;

    } catch (e) {
      debugPrint('RecordingService: Error starting recording: $e');
      _stateController.add(RecordingState.error);
      return false;
    }
  }

  /// Dừng ghi âm
  Future<String?> stopRecording() async {
    if (!_isRecording) {
      debugPrint('RecordingService: Not recording');
      return null;
    }

    try {
      // Stop recording
      final path = await _recorder.stop();

      _stopTimers();

      _isRecording = false;
      _isPaused = false;

      _stateController.add(RecordingState.stopped);

      debugPrint('RecordingService: Stopped recording. Path: $path');

      return path ?? _currentRecordingPath;

    } catch (e) {
      debugPrint('RecordingService: Error stopping recording: $e');
      _stateController.add(RecordingState.error);
      return null;
    }
  }

  /// Pause recording
  Future<void> pauseRecording() async {
    if (!_isRecording || _isPaused) return;

    try {
      await _recorder.pause();
      _isPaused = true;
      _stateController.add(RecordingState.paused);
      debugPrint('RecordingService: Paused recording');
    } catch (e) {
      debugPrint('RecordingService: Error pausing recording: $e');
    }
  }

  /// Resume recording
  Future<void> resumeRecording() async {
    if (!_isRecording || !_isPaused) return;

    try {
      await _recorder.resume();
      _isPaused = false;
      _stateController.add(RecordingState.recording);
      debugPrint('RecordingService: Resumed recording');
    } catch (e) {
      debugPrint('RecordingService: Error resuming recording: $e');
    }
  }

  /// Toggle Pause/Resume
  Future<void> togglePause() async {
    if (_isPaused) {
      await resumeRecording();
    } else {
      await pauseRecording();
    }
  }

  /// Cancel recording and delete file
  Future<void> cancelRecording() async {
    await stopRecording();

    if (_currentRecordingPath != null) {
      try {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
          debugPrint('RecordingService: Deleted recording file');
        }
      } catch (e) {
        debugPrint('RecordingService: Error deleting file: $e');
      }
    }

    _currentRecordingPath = null;
    _recordingWaveform.clear();
    _stateController.add(RecordingState.idle);
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_isRecording && !_isPaused) {
        _durationController.add(currentDuration);
      }
    });
  }

  void _startAmplitudeMonitoring() {
    _amplitudeSubscription?.cancel();

    // Sử dụng amplitude stream từ recorder
    _amplitudeSubscription = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 50))
        .listen((amp) {
      if (_isRecording && !_isPaused) {
        // Chuyển đổi dBFS sang giá trị 0-1
        // amp.current thường từ -60 (im lặng) đến 0 (max)
        double normalizedAmp = 0.0;
        if (amp.current > -60) {
          normalizedAmp = (amp.current + 60) / 60; // Normalize to 0-1
        }
        normalizedAmp = normalizedAmp.clamp(0.0, 1.0);

        _amplitudeController.add(normalizedAmp);
        _recordingWaveform.add(normalizedAmp);
      }
    });
  }

  void _stopTimers() {
    _durationTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _durationTimer = null;
    _amplitudeSubscription = null;
  }

  /// Extract waveform từ file audio
  Future<List<double>> extractWaveform(String filePath, {int targetSamples = 500}) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('RecordingService: File not found: $filePath');
        return _generateSimulatedWaveform(targetSamples);
      }

      final bytes = await file.readAsBytes();
      return _processAudioBytes(bytes, targetSamples);

    } catch (e) {
      debugPrint('RecordingService: Error extracting waveform: $e');
      return _generateSimulatedWaveform(targetSamples);
    }
  }

  List<double> _processAudioBytes(Uint8List bytes, int targetSamples) {
    // Skip header (simplified - assumes WAV-like format)
    // M4A/AAC files có header phức tạp hơn, đây là xử lý đơn giản
    int dataStart = 44;
    if (bytes.length < dataStart + 100) {
      return _generateSimulatedWaveform(targetSamples);
    }

    final dataLength = bytes.length - dataStart;
    final bytesPerSample = math.max(1, dataLength ~/ targetSamples);

    List<double> samples = [];
    for (int i = dataStart; i < bytes.length && samples.length < targetSamples; i += bytesPerSample) {
      int sum = 0;
      int count = 0;

      for (int j = 0; j < bytesPerSample && i + j < bytes.length; j++) {
        sum += bytes[i + j];
        count++;
      }

      if (count > 0) {
        double value = ((sum / count) - 128).abs() / 128;
        samples.add(value.clamp(0.05, 1.0));
      }
    }

    // Smoothing
    if (samples.length > 2) {
      for (int i = 1; i < samples.length - 1; i++) {
        samples[i] = (samples[i - 1] + samples[i] * 2 + samples[i + 1]) / 4;
      }
    }

    return samples;
  }

  List<double> _generateSimulatedWaveform(int count) {
    final random = DateTime.now().millisecond;
    return List.generate(count, (i) {
      double base = 0.3 + (((i + random) * 7) % 100) / 200;
      double variation = math.sin(i * 0.1) * 0.15;
      return (base + variation).clamp(0.1, 0.9);
    });
  }

  /// Cleanup
  void dispose() {
    _stopTimers();
    _recorder.dispose();
    _stateController.close();
    _amplitudeController.close();
    _durationController.close();
  }
}

enum RecordingState {
  idle,
  recording,
  paused,
  stopped,
  permissionDenied,
  error,
}