// lib/providers/waveform_provider.dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/audio_marker.dart';

class WaveformProvider extends ChangeNotifier {
  // Waveform data
  List<double> _waveformData = [];
  bool _isLoading = false;
  String? _currentFilePath;
  Duration _audioDuration = Duration.zero;

  // Zoom & Scroll
  double _zoomLevel = 1.0; // 1.0 = fit all, higher = more zoom
  double _scrollOffset = 0.0; // 0.0 - 1.0 position
  static const double minZoom = 1.0;
  static const double maxZoom = 100.0; // Zoom tối đa 100x

  // Selection
  Duration? _selectionStart;
  Duration? _selectionEnd;
  bool _isSelecting = false;

  // Markers
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

  // ==================== WAVEFORM LOADING ====================

  /// Load waveform từ file audio
  Future<void> loadWaveform(String filePath, Duration duration) async {
    _isLoading = true;
    _currentFilePath = filePath;
    _audioDuration = duration;
    notifyListeners();

    try {
      // Đọc file và tạo waveform data
      final file = File(filePath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        _waveformData = _generateWaveformFromBytes(bytes);
      } else {
        // Fallback: tạo waveform giả
        _waveformData = _generateFakeWaveform(1000);
      }
    } catch (e) {
      // Fallback nếu không đọc được
      _waveformData = _generateFakeWaveform(1000);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Tạo waveform data từ bytes của file audio
  List<double> _generateWaveformFromBytes(Uint8List bytes) {
    // Số lượng samples muốn hiển thị
    const targetSamples = 2000;

    // Bỏ qua header (thường 44 bytes cho WAV)
    int dataStart = 44;
    if (bytes.length < dataStart + 100) {
      return _generateFakeWaveform(targetSamples);
    }

    // Tính số bytes per sample
    final dataLength = bytes.length - dataStart;
    final bytesPerSample = max(1, dataLength ~/ targetSamples);

    List<double> samples = [];
    for (int i = dataStart; i < bytes.length; i += bytesPerSample) {
      // Lấy giá trị byte và normalize về 0-1
      int sum = 0;
      int count = 0;
      for (int j = 0; j < bytesPerSample && i + j < bytes.length; j++) {
        sum += bytes[i + j];
        count++;
      }

      if (count > 0) {
        double value = (sum / count - 128).abs() / 128;
        samples.add(value.clamp(0.0, 1.0));
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

  /// Tạo waveform giả cho demo/fallback
  List<double> _generateFakeWaveform(int count) {
    final random = Random(42); // Fixed seed for consistency
    List<double> samples = [];

    for (int i = 0; i < count; i++) {
      // Tạo pattern tự nhiên hơn với nhiều tần số
      double value = 0;
      value += sin(i * 0.1) * 0.3;
      value += sin(i * 0.05) * 0.2;
      value += sin(i * 0.02) * 0.1;
      value += (random.nextDouble() - 0.5) * 0.4;
      value = (value.abs()).clamp(0.05, 1.0);

      // Thêm silence periodically
      if (i % 100 > 80) {
        value *= 0.3;
      }

      samples.add(value);
    }

    return samples;
  }

  // ==================== ZOOM & SCROLL ====================

  /// Set zoom level (1.0 = fit all)
  void setZoom(double zoom) {
    _zoomLevel = zoom.clamp(minZoom, maxZoom);

    // Đảm bảo scroll offset vẫn hợp lệ
    _clampScrollOffset();
    notifyListeners();
  }

  /// Zoom in
  void zoomIn() {
    setZoom(_zoomLevel * 1.5);
  }

  /// Zoom out
  void zoomOut() {
    setZoom(_zoomLevel / 1.5);
  }

  /// Zoom to fit all
  void zoomToFit() {
    _zoomLevel = 1.0;
    _scrollOffset = 0.0;
    notifyListeners();
  }

  /// Zoom vào một vùng cụ thể
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

  /// Set scroll offset (0.0 - 1.0)
  void setScrollOffset(double offset) {
    _scrollOffset = offset;
    _clampScrollOffset();
    notifyListeners();
  }

  /// Scroll by delta
  void scrollBy(double delta) {
    _scrollOffset += delta;
    _clampScrollOffset();
    notifyListeners();
  }

  void _clampScrollOffset() {
    final maxOffset = 1.0 - (1.0 / _zoomLevel);
    _scrollOffset = _scrollOffset.clamp(0.0, max(0.0, maxOffset));
  }

  /// Chuyển từ pixel position sang Duration
  Duration positionToDuration(double position, double viewWidth) {
    if (_audioDuration.inMilliseconds == 0 || viewWidth == 0) {
      return Duration.zero;
    }

    // Vị trí trong view (0-1)
    final viewPosition = position / viewWidth;

    // Phạm vi hiển thị hiện tại
    final visibleRange = 1.0 / _zoomLevel;

    // Vị trí thực trong toàn bộ audio (0-1)
    final audioPosition = _scrollOffset + (viewPosition * visibleRange);

    // Chuyển sang Duration
    final ms = (audioPosition * _audioDuration.inMilliseconds).round();
    return Duration(milliseconds: ms.clamp(0, _audioDuration.inMilliseconds));
  }

  /// Chuyển từ Duration sang pixel position
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

    // Đảm bảo start < end
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

  /// Tạo marker từ selection hiện tại
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

  /// Thêm marker tại vị trí
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

  /// Xóa marker
  void removeMarker(String id) {
    _markers.removeWhere((m) => m.id == id);
    if (_selectedMarker?.id == id) {
      _selectedMarker = null;
    }
    notifyListeners();
  }

  /// Cập nhật marker
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

  /// Chọn marker
  void selectMarker(AudioMarker? marker) {
    _selectedMarker = marker;
    notifyListeners();
  }

  /// Bắt đầu kéo marker
  void startDraggingMarker(AudioMarker marker) {
    _draggingMarker = marker;
    notifyListeners();
  }

  /// Kết thúc kéo marker
  void endDraggingMarker() {
    _draggingMarker = null;
    notifyListeners();
  }

  /// Tìm marker tại vị trí
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

  /// Lấy markers trong khoảng thời gian
  List<AudioMarker> getMarkersInRange(Duration start, Duration end) {
    return _markers.where((m) {
      if (m.isRegion) {
        return m.startTime < end && m.endTime! > start;
      } else {
        return m.startTime >= start && m.startTime <= end;
      }
    }).toList();
  }

  /// Xóa tất cả markers
  void clearMarkers() {
    _markers.clear();
    _selectedMarker = null;
    notifyListeners();
  }

  /// Export markers as JSON
  List<Map<String, dynamic>> exportMarkers() {
    return _markers.map((m) => m.toJson()).toList();
  }

  /// Import markers from JSON
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
