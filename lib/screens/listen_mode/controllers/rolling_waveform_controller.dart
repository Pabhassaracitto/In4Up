// VipSound v11.0 — Controller với _disposed guard toàn bộ mutators

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

  // ── Getters ────────────────────────────────────────────────
  WaveformData? get waveformData => _waveformData;
  Duration get position => _position;
  Duration get duration => _duration;
  double get zoom => _zoom;
  List<LoopRegion> get loopRegions => List.unmodifiable(_loopRegions);

  Duration get visibleDuration {
    const baseMs = 8000;
    return Duration(
      milliseconds: (baseMs / _zoom).round().clamp(500, 60000),
    );
  }

  // ── Mutators (đều có _disposed guard) ─────────────────────

  void setWaveformData(WaveformData? data) {
    if (_disposed) return;
    _waveformData = data;
    if (data != null) _duration = data.duration;
    notifyListeners();
  }

  void updatePosition(Duration position) {
    if (_disposed) return;
    _position = position;
    notifyListeners();
  }

  void setZoom(double zoom) {
    if (_disposed) return;
    _zoom = zoom.clamp(0.5, 10.0);
    notifyListeners();
  }

  void addLoopRegion(LoopRegion region) {
    if (_disposed) return;
    _loopRegions.add(region);
    notifyListeners();
  }

  void clearLoopRegions() {
    if (_disposed) return;
    _loopRegions.clear();
    notifyListeners();
  }
}

class LoopRegion {
  final Duration start;
  final Duration end;
  const LoopRegion({required this.start, required this.end});
}
