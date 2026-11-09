import 'dart:async';

import 'package:in4up/audio/audio_player_service.dart';
import 'package:in4up/models/playback_state.dart';
import 'package:in4up/models/segment.dart';
import 'package:in4up/services/storage_service.dart';

class FakeQueueStorage implements StorageService {
  final positions = <String, int>{};
  String? lastAudioPath;
  int loopCount = 0;
  Completer<void>? savePositionGate;
  Completer<void>? savePositionEntered;

  @override
  bool get isInitialized => true;
  @override
  String getLastMode() => 'music';
  @override
  double getGapDuration() => 0;
  @override
  List<Segment> getAllAudioSegments() => [];
  @override
  Map<String, dynamic> getDailyStats({String? date}) => {'loops': 0};
  @override
  Future<void> saveLastAudioPath(String path) async {
    lastAudioPath = path;
  }
  @override
  Future<void> savePosition(String path, int positionMs) async {
    final entered = savePositionEntered;
    if (entered != null && !entered.isCompleted) entered.complete();
    final gate = savePositionGate;
    if (gate != null) await gate.future;
    positions[path] = positionMs;
  }
  @override
  int? getSavedPosition(String path) => positions[path];
  @override
  Future<void> incrementLoopCount() async {
    loopCount++;
  }
  @override
  Future<void> addListeningTime(int seconds) async {}
  @override
  Future<void> saveGapDuration(double gap) async {}
  @override
  Future<void> saveLastPlaybackSpeed(double speed) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeQueueAudio implements AudioPlaybackPort {
  // AudioPlayerService's BehaviorSubject delivers asynchronously; a sync
  // controller incorrectly rejects pause/seek events emitted from listeners.
  final _stream = StreamController<PlaybackState>.broadcast();
  PlaybackState _state = const PlaybackState();
  final loads = <String>[];
  final plays = <String?>[];
  final seeks = <Duration>[];
  final failures = <String>{};
  final waits = <String, Completer<void>>{};
  final entered = <String, Completer<void>>{};
  String? currentPath;
  bool disposed = false;
  int stops = 0;

  @override
  Stream<PlaybackState> get stateStream => _stream.stream;
  @override
  PlaybackState get currentState => _state;

  void emit(PlaybackState state) {
    _state = state;
    if (!disposed) _stream.add(state);
  }

  void position(Duration position) => emit(_state.copyWith(position: position));
  void complete() => emit(_state.copyWith(
      status: PlaybackStatus.completed, position: _state.duration));
  void playbackError() => emit(_state.copyWith(status: PlaybackStatus.error));

  @override
  Future<bool> loadFile(String path) async {
    loads.add(path);
    emit(_state.copyWith(
      status: PlaybackStatus.loading,
      position: Duration.zero,
      duration: Duration.zero,
    ));
    final gate = waits[path];
    if (gate != null) {
      entered[path]?.complete();
      await gate.future;
    }
    if (failures.contains(path)) {
      emit(_state.copyWith(status: PlaybackStatus.error));
      return false;
    }
    currentPath = path;
    emit(_state.copyWith(
      status: PlaybackStatus.paused,
      duration: const Duration(minutes: 2),
      position: Duration.zero,
    ));
    return true;
  }

  @override
  Future<void> play() async {
    plays.add(currentPath);
    emit(_state.copyWith(status: PlaybackStatus.playing));
  }
  @override
  Future<void> pause() async => emit(_state.copyWith(status: PlaybackStatus.paused));
  @override
  Future<void> stop() async {
    stops++;
    emit(_state.copyWith(status: PlaybackStatus.stopped, position: Duration.zero));
  }
  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
    emit(_state.copyWith(position: position));
  }
  @override
  Future<void> setSpeed(double speed) async => emit(_state.copyWith(speed: speed));
  @override
  Future<void> setPitch(double semitones) async => emit(_state.copyWith(pitch: semitones));
  @override
  Future<void> setVolume(double volume) async => emit(_state.copyWith(volume: volume));
  @override
  Future<void> dispose() async {
    disposed = true;
    await _stream.close();
  }
}
