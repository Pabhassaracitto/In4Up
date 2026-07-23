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

  // ── Get