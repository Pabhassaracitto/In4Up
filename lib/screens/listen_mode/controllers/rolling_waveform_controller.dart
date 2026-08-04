// in2up v11.0 — Controller với _disposed guard toàn bộ mutators

import 'package:flutter/foundation.dart';

import '../../../models/waveform_data.dart';

class RollingWaveformController extends ChangeNotifier {
  // ── Dispose Guard ──────────────────────────────────────────
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  // ── State ──────────────────────────────────────────────────
  WaveformData? _waveformData;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _zoom = 1.0;
  final List<LoopRegion> _loopRegions = [];

  // ── Throttle repaint ──
  DateTime _lastNotify = DateTime.now();
  static const _kMinRepaintInterval = Duration(milliseconds: 32); // ~30fps

  // ── Getters ────────────────────────────────────────────────
  WaveformData? get waveformData => _waveformData;
  Duration get position => _position;
  Duration get duration => _duration;
  double get zoom => _zoom;
  List<LoopRegion> get loopRegions => List.unmodifiable(_loopRegions);

  // Visible window duration (dựa vào zoom)
  Duration get visibleDuration {
    final baseDuration = const Duration(seconds: 10); // 10s mặc định
    return Duration(
      milliseconds: (baseDuration.inMilliseconds / _zoom).round(),
    );
  }

  // ── Setters ────────────────────────────────────────────────
  void setWaveformData(WaveformData? data) {
    _waveformData = data;
    _duration = data?.duration ?? Duration.zero;
    notifyListeners();
  }

  void updatePosition(Duration position) {
    _position = position;

    // Throttle: chỉ notify tối đa 30fps để tránh tràn buffer queue
    final now = DateTime.now();
    if (now.difference(_lastNotify) >= _kMinRepaintInterval) {
      _lastNotify = now;
      notifyListeners();
    }
  }

  void setZoom(double zoom) {
    _zoom = zoom.clamp(0.5, 10.0); // 0.5x đến 10x
    notifyListeners();
  }

  void addLoopRegion(LoopRegion region) {
    _loopRegions.add(region);
    notifyListeners();
  }

  void removeLoopRegion(LoopRegion region) {
    _loopRegions.remove(region);
    notifyListeners();
  }

  void clearLoopRegions() {
    _loopRegions.clear();
    notifyListeners();
  }

  // ── Helpers ────────────────────────────────────────────────

  // Tính offset để render (waveform chạy)
  double getOffsetForPosition() {
    if (_waveformData == null || _duration.inMilliseconds == 0) return 0.0;

    final progress = _position.inMilliseconds / _duration.inMilliseconds;
    return progress * _waveformData!.samples.length;
  }

  // Convert screen X coordinate to Duration
  Duration screenXToPosition(double screenX, double screenWidth) {
    // Playhead ở giữa màn hình (0.5)
    final playheadX = screenWidth * 0.5;
    final deltaX = screenX - playheadX;

    // Tính thời gian dựa vào khoảng cách từ playhead
    final visibleDurationMs = visibleDuration.inMilliseconds;
    final msPerPixel = visibleDurationMs / screenWidth;
    final deltaMs = deltaX * msPerPixel;

    final targetMs = _position.inMilliseconds + deltaMs.round();
    return Duration(milliseconds: targetMs.clamp(0, _duration.inMilliseconds));
  }
}
