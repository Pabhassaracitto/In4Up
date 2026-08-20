// lib/providers/player/player_stats_mixin.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/playback_state.dart';
import '../../models/segment.dart';
import '../../screens/listen_mode/models/recent_audio.dart';
import '../../screens/listen_mode/services/recent_audio_service.dart';
import '../../services/storage_service.dart';

mixin PlayerStatsMixin on ChangeNotifier {
  // Dependencies required from PlayerProvider
  String? get currentSongPath;
  PlaybackState get state;
  StorageService get storage;
  List<Segment> get segments;
  List<Segment> getSegmentsByType(SegmentType type);

  final RecentAudioService _recentAudio = RecentAudioService();

  int _totalLoopsToday = 0;
  Duration _totalListeningTime = Duration.zero;
  DateTime _lastRecentUpdate = DateTime.now();
  RecentAudio? _pendingRecentUpdate;

  // Getters & Setters
  int get totalLoopsToday => _totalLoopsToday;
  set totalLoopsToday(int value) {
    _totalLoopsToday = value;
  }

  Duration get totalListeningTime => _totalListeningTime;
  set totalListeningTime(Duration value) {
    _totalListeningTime = value;
  }

  RecentAudio? get pendingRecentUpdate => _pendingRecentUpdate;
  set pendingRecentUpdate(RecentAudio? value) {
    _pendingRecentUpdate = value;
  }

  RecentAudioService get recentAudio => _recentAudio;

  void maybeUpdateRecentPosition(Duration position) {
    if (currentSongPath == null) return;
    final now = DateTime.now();
    if (now.difference(_lastRecentUpdate).inSeconds < 30) return;
    _lastRecentUpdate = now;

    final normalizedPath = currentSongPath!;
    final audioId = 'local_${normalizedPath.toLowerCase().hashCode}';
    _recentAudio.updatePosition(
      audioId,
      position: position,
      totalDuration: state.duration,
    );
  }

  void saveCurrentPosition() {
    if (currentSongPath != null && state.position.inSeconds > 5) {
      storage.savePosition(currentSongPath!, state.position.inMilliseconds);
    }
  }

  Duration? getSavedPosition(String path) {
    final savedMs = storage.getSavedPosition(path);
    if (savedMs == null) return null;
    return Duration(milliseconds: savedMs);
  }

  void clearSavedPosition(String path) {
    storage.clearPosition(path);
  }

  void clearAllSavedPositions() {}

  void resetDailyStats() {
    _totalLoopsToday = 0;
    _totalListeningTime = Duration.zero;
    notifyListeners();
  }

  Map<String, dynamic> getStats() {
    return {
      'totalLoopsToday': _totalLoopsToday,
      'totalListeningTimeMinutes': _totalListeningTime.inMinutes,
      'segmentsCount': segments.length,
      'dharmaSegments': getSegmentsByType(SegmentType.dharma).length,
      'englishSegments': getSegmentsByType(SegmentType.english).length,
    };
  }
}
