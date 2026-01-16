import 'package:flutter/foundation.dart';
import '../audio/audio_player_service.dart';

class PlayerProvider extends ChangeNotifier {
  final AudioPlayerService _audioService = AudioPlayerService();

  PlaybackState _state = const PlaybackState();
  String? _currentSongTitle;
  String? _currentSongArtist;
  String? _currentSongPath;

  // Getters
  PlaybackState get state => _state;
  String? get currentSongTitle => _currentSongTitle;
  String? get currentSongArtist => _currentSongArtist;
  String? get currentSongPath => _currentSongPath;
  bool get isPlaying => _state.status == PlaybackStatus.playing;
  bool get isPaused => _state.status == PlaybackStatus.paused;
  bool get isStopped => _state.status == PlaybackStatus.stopped;
  bool get isLoading => _state.status == PlaybackStatus.loading;

  PlayerProvider() {
    _audioService.stateStream.listen((state) {
      _state = state;
      notifyListeners();
    });
  }

  /// Load and optionally play a song
  Future<void> loadSong({
    required String path,
    String? title,
    String? artist,
    bool autoPlay = false,
  }) async {
    _currentSongPath = path;
    _currentSongTitle = title ?? path.split('/').last;
    _currentSongArtist = artist;
    notifyListeners();

    final success = await _audioService.loadFile(path);
    if (success && autoPlay) {
      await play();
    }
  }

  Future<void> play() async {
    await _audioService.play();
  }

  Future<void> pause() async {
    await _audioService.pause();
  }

  Future<void> togglePlayPause() async {
    if (isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> stop() async {
    await _audioService.stop();
  }

  Future<void> seek(Duration position) async {
    await _audioService.seek(position);
  }

  Future<void> seekToPercent(double percent) async {
    final duration = _state.duration;
    if (duration == Duration.zero) return;

    final position = Duration(
      milliseconds: (duration.inMilliseconds * percent).round(),
    );
    await seek(position);
  }

  /// Set speed (0.05 - 10.0)
  Future<void> setSpeed(double speed) async {
    await _audioService.setSpeed(speed);
  }

  /// Set pitch in semitones (-24 to +24)
  Future<void> setPitch(double semitones) async {
    await _audioService.setPitch(semitones);
  }

  /// Set volume (0.0 - 1.0)
  Future<void> setVolume(double volume) async {
    await _audioService.setVolume(volume);
  }

  /// Get speed presets
  List<double> get speedPresets => AudioPlayerService.speedPresets;

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }
}