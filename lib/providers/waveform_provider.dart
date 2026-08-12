// lib/providers/waveform_provider.dart
// ★ CHỈ SỬA 1 CHỖ: method loadWaveform()

import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_waveform/just_waveform.dart' as jw;

import '../models/audio_marker.dart';

class WaveformProvider extends ChangeNotifier {
  List<double> _waveformData = [];
  bool _isLoading = false;
  String? _currentFilePath;
  Duration _audioDuration = Duration.zero;

  double _zoomLevel = 1.0;
  double _scrollOffset = 0.0;
  static const double minZoom = 1.0;
  static const double maxZoom = 100.0;

  Duration? _selectionStart;
  Duration? _selectionEnd;
  bool _isSelecting = false;

  final List<AudioMarker> _markers = [];
  AudioMarker? _selectedMarker;
  AudioMarker? _draggingMarker;

  // Getters
  List<double> get waveformData => _waveformData;
  bool get isLoading => _isLoading;
  String? get currentFilePath => _currentFilePath;
  Duration get audioDuration => _audioDuration;
  double get zoomLevel => _zoomLevel;
  double get scrollOffset => _scrollOffset;
  Duration? get selectionStart => _selectionStart;
  Duration? get selectionEnd => _selectionEnd;
  bool get isSelecting => _isSelecting;
  bool get hasSelection => _selectionStart != null && _selectionEnd != null;
  List<AudioMarker> get markers => List.unmodifiable(_markers);
  AudioMarker? get selectedMarker => _selectedMarker;
  AudioMarker? get draggingMarker => _draggingMarker;

  List<double> get displayWaveform =>
      _waveformData.isNotEmpty ? _waveformData : _placeholderWaveform;

  static final List<double> _placeholderWaveform =
      _generateFakeWaveformStatic(500);

  // ==================== WAVEFORM LOADING ====================

  /// ★ FIX: Load waveform từ file audio — sửa guard condition
  Future<void> loadWaveform(String filePath, Duration duration) async {
    final normalizedPath = filePath.replaceAll('\', '/');

    // ★ FIX: Guard chặt hơn — chỉ skip khi CÓ data VÀ duration khớp VÀ path khớp
    final alreadyLoaded = _currentFilePath == normalizedPath &&
        _waveformData.isNotEmpty &&
        _audioDuration == duration &&
        duration > Duration.zero; // ★ THÊM: duration phải > 0 mới coi là loaded

    if (alreadyLoaded) {
      debugPrint('⏭️ Waveform already loaded for: $normalizedPath');
      return;
    }

    // ★ FIX: Nếu đang loading cùng file thì skip (tránh duplicate request)
    if (_isLoading && _currentFilePath == normalizedPath) {
      debugPrint('⏳ Waveform already loading for: $normalizedPath');
      return;
    }

    _isLoading = true;
    _currentFilePath = normalizedPath;
    _audioDuration = duration;
    notifyListeners();

    debugPrint('🔄 Loading waveform: $normalizedPath (duration: $duration)');

    try {
      final samples =
          await Isolate.run(() => _extractWaveformSamples(normalizedPath));
      // Guard: tránh race condition khi user đổi bài nhanh
      if (_currentFilePath == normalizedPath) {
        _waveformData = samples;
        debugPrint('✅ Waveform loaded: ${samples.length} samples');
      }
    } catch (e) {
      debugPrint('❌ Waveform load error: $e');
      if (_currentFilePath == normalizedPath) {
        _waveformData = _generateFakeWaveform(1000);
      }
    }

    if (_currentFilePath == normalizedPath) {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ═══════════════ PHẦN CÒN LẠI GIỮ NGUYÊN 100% ═══════════════

  static Future<List<double>> _extractWaveformSamples(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return _generateFakeWaveformStatic(1000);
      }

      final waveformFile = File('$filePath.waveform');
      jw.Waveform? waveform;

      final progressStream = jw.JustWaveform.extract(
        audioInFile: File(filePath),
        waveOutFile: waveformFile,
        zoom: const jw.WaveformZoom.pixelsPerSecond(100),
      );

      await for (final progress in progressStream) {
        if (progress.waveform != null) {
          waveform = progress.waveform;
        }
      }

      try {
        if (await waveformFile.exists()) await waveformFile.delete();
      } catch (_) {}

      if (waveform == null || waveform.data.isEmpty) {
        return _generateFakeWaveformStatic(1000);
      }

      const targetSamples = 2000;
      final data = waveform.data;
      int maxAmp = 1;
      for (final v in data) {
        final abs = v.abs();
        if (abs > maxAmp) maxAmp = abs;
      }

      final step = max(1, data.length ~/ targetSamples);
      final samples = <double>[];

      for (int i = 0; i < data.length; i += step) {
        double peak = 0.0;
        for (int j = i; j < min(i + step, data.length); j++) {
          final n = data[j].abs() / maxAmp;
          if (n > peak) peak = n;
        }
        samples.add(peak.clamp(0.02, 1.0));
      }

      for (int i = 1; i < samples.length - 1; i++) {
        samples[i] = (samples[i - 1] + samples[i] * 2 + samples[i + 1]) / 4;
      }

      return samples;
    } catch (e) {
      return _generateFakeWaveformStatic(1000);
    }
  }

  static List<double> _generateFakeWaveformStatic(int count) {
    final random = Random(42);
    final samples = <double>[];
    for (int i = 0; i < count; i++) {
      double v = sin(i * 0.1) * 0.3 +
          sin(i * 0.05) * 0.2 +
          (random.nextDouble() - 0.5) * 0.4;
      v = v.abs().clamp(0.05, 1.0);
      if (i % 100 > 80) v *= 0.3;
      samples.add(v);
    }
    return samples;
  }

  Future<List<double>?> _loadWithJustWaveform(String filePath) async {
    try {
      const targetSamples = 2000;
      final waveformFile = File('$filePath.waveform');

      final progressStream = jw.JustWaveform.extract(
        audioInFile: File(filePath),
        waveOutFile: waveformFile,
        zoom: const jw.WaveformZoom.pixelsPerSecond(100),
      );

      jw.Waveform? waveform;
      await for (final progress in progressStream) {
        if (progress.waveform != null) {
          waveform = progress.waveform;
        }
      }

      if (waveform == null) return null;

      final samples = <double>[];
      final data = waveform.data;

      if (data.isEmpty) return null;

      int maxAmp = 1;
      for (int i = 0; i < data.length; i++) {
        final absVal = data[i].abs();
        if (absVal > maxAmp) maxAmp = absVal;
      }

      final step = max(1, data.length ~/ targetSamples);

      for (int i = 0; i < data.length; i += step) {
        double maxInChunk = 0.0;
        for (int j = i; j < min(i + step, data.length); j++) {
          final normalized = data[j].abs() / maxAmp;
          if (normalized > maxInChunk) maxInChunk = normalized;
        }
        samples.add(maxInChunk.clamp(0.02, 1.0).toDouble());
      }

      if (samples.length > 2) {
        for (int i = 1; i < samples.length - 1; i++) {
          samples[i] = (samples[i - 1] + samples[i] * 2 + samples[i + 1]) / 4;
        }
      }

      try {
        if (await waveformFile.exists()) {
          await waveformFile.delete();
        }
      } catch (_) {}

      return samples;
    } catch (e) {
      debugPrint('just_waveform error: $e');
      return null;
    }
  }

  List<double> _generateWaveformFromBytes(Uint8List bytes, String filePath) {
    const targetSamples = 2000;
    final lower = filePath.toLowerCase();

    if (!lower.endsWith('.wav')) {
      debugPrint('Non-WAV file, using fake waveform for: $filePath');
      return _generateFakeWaveform(targetSamples);
    }

    int dataStart = 44;

    if (bytes.length > 44) {
      for (int i = 12; i < min(bytes.length - 8, 200); i++) {
        if (bytes[i] == 0x64 &&
            bytes[i + 1] == 0x61 &&
            bytes[i + 2] == 0x74 &&
            bytes[i + 3] == 0x61) {
          dataStart = i + 8;
          break;
        }
      }
    }

    if (bytes.length < dataStart + 100) {
      return _generateFakeWaveform(targetSamples);
    }

    int bitsPerSample = 16;
    if (bytes.length > 35) {
      bitsPerSample = bytes[34] | (bytes[35] << 8);
    }

    int channels = 1;
    if (bytes.length > 23) {
      channels = bytes[22] | (bytes[23] << 8);
    }

    final bytesPerSampleFrame = (bitsPerSample ~/ 8) * channels;
    final dataLength = bytes.length - dataStart;
    final totalFrames = dataLength ~/ bytesPerSampleFrame;
    final framesPerSample = max(1, totalFrames ~/ targetSamples);

    List<double> samples = [];

    for (int frame = 0;
        frame < totalFrames && samples.length < targetSamples;
        frame += framesPerSample) {
      double maxValue = 0.0;

      for (int f = frame; f < min(frame + framesPerSample, totalFrames); f++) {
        final offset = dataStart + f * bytesPerSampleFrame;
        if (offset + bytesPerSampleFrame > bytes.length) break;

        double sampleValue = 0.0;

        if (bitsPerSample == 16) {
          final lo = bytes[offset];
          final hi = bytes[offset + 1];
          int raw = lo | (hi << 8);
          if (raw >= 0x8000) raw -= 0x10000;
          sampleValue = raw.abs() / 32768.0;
        } else if (bitsPerSample == 24) {
          final lo = bytes[offset];
          final mid = bytes[offset + 1];
          final hi = bytes[offset + 2];
          int raw = lo | (mid << 8) | (hi << 16);
          if (raw >= 0x800000) raw -= 0x1000000;
          sampleValue = raw.abs() / 8388608.0;
        } else {
          sampleValue = (bytes[offset] - 128).abs() / 128.0;
        }

        if (sampleValue > maxValue) maxValue = sampleValue;
      }

      samples.add(maxValue.clamp(0.02, 1.0));
    }

    if (samples.length > 2) {
      for (int i = 1; i < samples.length - 1; i++) {
        samples[i] = (samples[i - 1] + samples[i] * 2 + samples[i + 1]) / 4;
      }
    }

    return samples.isEmpty ? _generateFakeWaveform(targetSamples) : samples;
  }

  List<double> _generateFakeWaveform(int count) {
    final random = Random(42);
    List<double> samples = [];

    for (int i = 0; i < count; i++) {
      double value = 0;
      value += sin(i * 0.1) * 0.3;
      value += sin(i * 0.05) * 0.2;
      value += sin(i * 0.02) * 0.1;
      value += (random.nextDouble() - 0.5) * 0.4;
      value = (value.abs()).clamp(0.05, 1.0);

      if (i % 100 > 80) {
        value *= 0.3;
      }

      samples.add(value);
    }

    return samples;
  }

  // ==================== ZOOM & SCROLL ====================

  void setZoom(double zoom) {
    _zoomLevel = zoom.clamp(minZoom, maxZoom);
    _clampScrollOffset();
    notifyListeners();
  }

  void zoomIn() {
    setZoom(_zoomLevel * 1.5);
  }

  void zoomOut() {
    setZoom(_zoomLevel / 1.5);
  }

  void zoomToFit() {
    _zoomLevel = 1.0;
    _scrollOffset = 0.0;
    notifyListeners();
  }

  void zoomToRegion(Duration start, Duration end) {
    if (_audioDuration.inMilliseconds == 0) return;
    final startRatio = start.inMilliseconds / _audioDuration.inMilliseconds;
    final endRatio = end.inMilliseconds / _audioDuration.inMilliseconds;
    final regionSize = endRatio - startRatio;
    if (regionSize > 0) {
      _zoomLevel = (1.0 / regionSize).clamp(minZoom, maxZoom);
      _scrollOffset = startRatio;
      _clampScrollOffset();
      notifyListeners();
    }
  }

  void setScrollOffset(double offset) {
    _scrollOffset = offset;
    _clampScrollOffset();
    notifyListeners();
  }

  void scrollBy(double delta) {
    _scrollOffset += delta;
    _clampScrollOffset();
    notifyListeners();
  }

  void _clampScrollOffset() {
    final maxOffset = 1.0 - (1.0 / _zoomLevel);
    _scrollOffset = _scrollOffset.clamp(0.0, max(0.0, maxOffset));
  }

  Duration positionToDuration(double position, double viewWidth) {
    if (_audioDuration.inMilliseconds == 0 || viewWidth == 0) {
      return Duration.zero;
    }
    final viewPosition = position / viewWidth;
    final visibleRange = 1.0 / _zoomLevel;
    final audioPosition = _scrollOffset + (viewPosition * visibleRange);
    final ms = (audioPosition * _audioDuration.inMilliseconds).round();
    return Duration(milliseconds: ms.clamp(0, _audioDuration.inMilliseconds));
  }

  double durationToPosition(Duration duration, double viewWidth) {
    if (_audioDuration.inMilliseconds == 0 || viewWidth == 0) {
      return 0;
    }
    final audioPosition =
        duration.inMilliseconds / _audioDuration.inMilliseconds;
    final visibleRange = 1.0 / _zoomLevel;
    final viewPosition = (audioPosition - _scrollOffset) / visibleRange;
    return viewPosition * viewWidth;
  }

  // ==================== SELECTION ====================
  void startSelection(Duration time) {
    _selectionStart = time;
    _selectionEnd = null;
    _isSelecting = true;
    notifyListeners();
  }

  void updateSelection(Duration time) {
    if (_isSelecting) {
      _selectionEnd = time;
      notifyListeners();
    }
  }

  void endSelection() {
    _isSelecting = false;
    if (_selectionStart != null && _selectionEnd != null) {
      if (_selectionEnd! < _selectionStart!) {
        final temp = _selectionStart;
        _selectionStart = _selectionEnd;
        _selectionEnd = temp;
      }
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectionStart = null;
    _selectionEnd = null;
    _isSelecting = false;
    notifyListeners();
  }

  AudioMarker? createMarkerFromSelection({
    required String label,
    MarkerType type = MarkerType.region,
    Color? color,
  }) {
    if (_selectionStart == null) return null;

    final marker = AudioMarker(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: _selectionStart!,
      endTime: _selectionEnd,
      label: label,
      type: _selectionEnd != null ? type : MarkerType.point,
      color: color ?? type.defaultColor,
    );

    _markers.add(marker);
    _markers.sort((a, b) => a.startTime.compareTo(b.startTime));
    clearSelection();
    notifyListeners();
    return marker;
  }

  // ==================== MARKERS ====================
  AudioMarker addMarker({
    required Duration startTime,
    Duration? endTime,
    String label = '',
    MarkerType type = MarkerType.point,
    Color? color,
  }) {
    final marker = AudioMarker(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: startTime,
      endTime: endTime,
      label: label,
      type: endTime != null ? MarkerType.region : type,
      color: color ?? type.defaultColor,
    );

    _markers.add(marker);
    _markers.sort((a, b) => a.startTime.compareTo(b.startTime));
    notifyListeners();
    return marker;
  }

  void removeMarker(String id) {
    _markers.removeWhere((m) => m.id == id);
    if (_selectedMarker?.id == id) {
      _selectedMarker = null;
    }
    notifyListeners();
  }

  void updateMarker(
    String id, {
    Duration? startTime,
    Duration? endTime,
    String? label,
    Color? color,
    MarkerType? type,
  }) {
    final index = _markers.indexWhere((m) => m.id == id);
    if (index == -1) return;

    _markers[index] = _markers[index].copyWith(
      startTime: startTime,
      endTime: endTime,
      label: label,
      color: color,
      type: type,
    );

    _markers.sort((a, b) => a.startTime.compareTo(b.startTime));
    notifyListeners();
  }

  void selectMarker(AudioMarker? marker) {
    _selectedMarker = marker;
    notifyListeners();
  }

  void startDraggingMarker(AudioMarker marker) {
    _draggingMarker = marker;
    notifyListeners();
  }

  void endDraggingMarker() {
    _draggingMarker = null;
    notifyListeners();
  }

  AudioMarker? findMarkerAtPosition(Duration time, {double tolerance = 50}) {
    final toleranceDuration = Duration(
      milliseconds:
          (_audioDuration.inMilliseconds / _waveformData.length * tolerance)
              .round(),
    );

    for (final marker in _markers) {
      if (marker.isRegion) {
        if (time >= marker.startTime && time <= marker.endTime!) {
          return marker;
        }
      } else {
        if ((time - marker.startTime).abs() < toleranceDuration) {
          return marker;
        }
      }
    }

    return null;
  }

  List<AudioMarker> getMarkersInRange(Duration start, Duration end) {
    return _markers.where((m) {
      if (m.isRegion) {
        return m.startTime < end && m.endTime! > start;
      } else {
        return m.startTime >= start && m.startTime <= end;
      }
    }).toList();
  }

  void clearMarkers() {
    _markers.clear();
    _selectedMarker = null;
    notifyListeners();
  }

  List<Map<String, dynamic>> exportMarkers() {
    return _markers.map((m) => m.toJson()).toList();
  }

  void importMarkers(List<dynamic> data) {
    _markers.clear();
    for (final item in data) {
      _markers.add(AudioMarker.fromJson(item));
    }
    _markers.sort((a, b) => a.startTime.compareTo(b.startTime));
    notifyListeners();
  }

  // ==================== CLEANUP ====================
  void reset() {
    _waveformData = [];
    _currentFilePath = null;
    _audioDuration = Duration.zero;
    _zoomLevel = 1.0;
    _scrollOffset = 0.0;
    clearSelection();
    clearMarkers();
    notifyListeners();
  }
}