// lib/providers/player/player_stats_mixin.dart

import 'package:flutter/foundation.dart';
import '../../models/playback_state.dart';
import '../../models/segment.dart';
import '../../screens/listen_mode/models/recent_audio.dart';
import '../../screens/listen_mode/services/recent_audio_service.dart';
import '../../services/storage_service.dart';

mixin PlayerStatsMixin on ChangeNotifier {
  // Dependencies required from PlayerProvider
  String? get currentSongPath;
  String? get currentRecentSource;
  PlaybackState get state;
  StorageService get storage;
  List<Segment> get segments;
  List<Segment> getSegmentsByType(SegmentType type);

  final RecentAudioService _recentAudio = RecentAudioService();

  int _totalLoopsToday = 0;
  Duration _totalListeningTime = Duration.zero;
  DateTime _lastRecentUpdate = DateTime.now();
  RecentAudio? _pendingRecentUpdate;
  Future<void> _positionWriteTail = Future<void>.value();

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

    final source = currentRecentSource ?? currentSongPath!;
    // RecentAudio uses the stable MD5 ID, not String.hashCode.
    final audioId = RecentAudio.fromLocalFile(path: source).id;
    _recentAudio.updatePosition(
      audioId,
      position: position,
      totalDuration: state.duration,
    );
  }

  Future<void> saveCurrentPosition() {
    final path = currentSongPath;
    if (path == null || state.position.inSeconds <= 5) return _positionWriteTail;
    final position = state.position;
    final duration = state.duration;
    final source = currentRecentSource ?? path;
    final audioId = RecentAudio.fromLocalFile(path: source).id;
    // Capture source and position immediately, then serialize writes so a
    // slower old save cannot overwrite newer progress for the same source.
    _positionWriteTail = _positionWriteTail.then((_) async {
      try {
        await storage.savePosition(path, position.inMilliseconds);
        await _recentAudio.updatePosition(
          audioId,
          position: position,
          totalDuration: duration,
        );
      } catch (error) {
        debugPrint('Could not save playback progress: $error');
      }
    });
    return _positionWriteTail;
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