import 'dart:async';

import '../../models/audio_queue_item.dart';

/// The loader must check [isCurrent] after every asynchronous boundary before
/// publishing state or starting playback. Only one loader runs at a time.
typedef QueueTrackLoader = Future<bool> Function(
  AudioQueueItem item,
  bool resumePosition,
  Duration? initialPosition,
  bool Function() isCurrent,
);

/// A session queue. Saved [AudioPlaylist]s remain a separate, persistent model.
///
/// The controller owns ordering and serializes loads, but knows nothing about
/// Flutter widgets or the audio plugin. Rapid requests supersede older ones;
/// a stale loader may finish, but cannot commit an index or start playback.
class PlaybackQueueController {
  final QueueTrackLoader _loadTrack;
  final void Function(AudioQueueItem item) _onLoaded;
  final void Function() _onChanged;

  PlaybackQueueController({
    required QueueTrackLoader loadTrack,
    required void Function(AudioQueueItem item) onLoaded,
    required void Function() onChanged,
  })  : _loadTrack = loadTrack,
        _onLoaded = onLoaded,
        _onChanged = onChanged;

  List<AudioQueueItem> _items = const [];
  final Set<int> _failedIndices = <int>{};
  int _activeIndex = -1;
  int _cursor = -1;
  int _generation = 0;
  bool _loading = false;
  bool _disposed = false;
  Object? _lastError;
  Future<void> _tail = Future<void>.value();

  List<AudioQueueItem> get items => _items;
  Set<int> get failedIndices => Set<int>.unmodifiable(_failedIndices);
  int get activeIndex => _activeIndex;
  int get cursor => _cursor;
  bool get isLoading => _loading;
  Object? get lastError => _lastError;
  bool get canGoPrevious => _cursor > 0 && _cursor < _items.length;
  bool get canGoNext => _cursor >= 0 && _cursor < _items.length - 1;
  Future<void> get whenIdle => _tail;

  /// Replace the session queue with a snapshot. An empty selection clears it.
  Future<bool> replace(
    List<AudioQueueItem> items, {
    int startIndex = 0,
    bool resumePosition = true,
    Duration? initialPosition,
    bool skipFailures = false,
  }) {
    if (items.isEmpty) {
      clear();
      return Future<bool>.value(false);
    }
    if (startIndex < 0 || startIndex >= items.length) {
      throw RangeError.index(startIndex, items, 'startIndex');
    }
    _items = List<AudioQueueItem>.unmodifiable(items);
    _failedIndices.clear();
    _activeIndex = -1;
    return _schedule(startIndex,
        resumePosition: resumePosition,
        initialPosition: initialPosition,
        skipFailures: skipFailures);
  }

  /// A deliberate selection reports an error for that item; it does not
  /// silently choose a different one.
  Future<bool> select(int index, {
    bool resumePosition = true,
    Duration? initialPosition,
  }) {
    if (index < 0 || index >= _items.length) return Future<bool>.value(false);
    return _schedule(index,
        resumePosition: resumePosition, initialPosition: initialPosition);
  }

  Future<bool> next() {
    if (!canGoNext) return Future<bool>.value(false);
    return _schedule(_cursor + 1, resumePosition: false);
  }

  Future<bool> previous() {
    if (!canGoPrevious) return Future<bool>.value(false);
    return _schedule(_cursor - 1, resumePosition: false);
  }

  /// Natural completion skips unavailable items at most once, never wraps.
  Future<bool> advanceAfterCompletion() {
    if (_loading || _activeIndex < 0 || _activeIndex >= _items.length - 1) {
      return Future<bool>.value(false);
    }
    return _schedule(_activeIndex + 1,
        resumePosition: false, skipFailures: true);
  }

  /// A decoder can fail after loading succeeded. Mark that occurrence and try
  /// the remaining items only once, just as for an unavailable file.
  Future<bool> advanceAfterPlaybackError() {
    if (_loading || _activeIndex < 0) return Future<bool>.value(false);
    final failed = _activeIndex;
    _failedIndices.add(failed);
    _notify();
    if (failed >= _items.length - 1) return Future<bool>.value(false);
    return _schedule(failed + 1, resumePosition: false, skipFailures: true);
  }

  Future<bool> _schedule(
    int index, {
    required bool resumePosition,
    Duration? initialPosition,
    bool skipFailures = false,
  }) {
    if (_disposed) return Future<bool>.value(false);
    final generation = ++_generation;
    final previous = _tail;
    final finished = Completer<void>();
    _tail = finished.future;
    _cursor = index;
    _loading = true;
    _lastError = null;
    _notify();

    bool isCurrent() => !_disposed && generation == _generation;

    Future<bool> run() async {
      try {
        // A superseded load is allowed to finish before touching the player
        // again. This avoids overlapping setAudioSource calls in just_audio.
        await previous;
        if (!isCurrent()) return false;
        for (var candidate = index; candidate < _items.length; candidate++) {
          if (!isCurrent()) return false;
          _cursor = candidate;
          _notify();
          final item = _items[candidate];
          var loaded = false;
          try {
            // The loader also handles missing placeholders so it can stop and
            // invalidate the outgoing track before reporting the failure.
            loaded = await _loadTrack(
              item,
              candidate == index && resumePosition,
              candidate == index ? initialPosition : null,
              isCurrent,
            );
          } catch (error) {
            if (isCurrent()) _lastError = error;
          }
          if (!isCurrent()) return false;
          if (loaded) {
            _failedIndices.remove(candidate);
            _activeIndex = candidate;
            _cursor = candidate;
            _loading = false;
            _notify();
            if (isCurrent()) _onLoaded(item);
            return isCurrent();
          }

          _activeIndex = -1;
          _failedIndices.add(candidate);
          _notify();
          if (!skipFailures) break;
        }
        if (isCurrent()) {
          _loading = false;
          _notify();
        }
        return false;
      } finally {
        finished.complete();
      }
    }

    return run();
  }

  /// Drop upcoming session items without stopping or reloading the current one.
  void keepCurrentOnly() {
    if (_disposed || _loading || _activeIndex < 0 ||
        _activeIndex >= _items.length) return;
    final current = _items[_activeIndex];
    _generation++;
    _items = List<AudioQueueItem>.unmodifiable([current]);
    _activeIndex = 0;
    _cursor = 0;
    _failedIndices.clear();
    _notify();
  }

  /// Cancel late load/completion callbacks without deleting the queue. The
  /// caller can await [whenIdle] before stopping or disposing the audio engine.
  void cancelPending() {
    if (_disposed) return;
    _generation++;
    _loading = false;
    if (_activeIndex >= 0) _cursor = _activeIndex;
    _notify();
  }

  void clear() {
    if (_disposed) return;
    _generation++;
    _items = const [];
    _failedIndices.clear();
    _activeIndex = -1;
    _cursor = -1;
    _loading = false;
    _lastError = null;
    _notify();
  }

  void dispose() {
    _generation++;
    _disposed = true;
  }

  void _notify() {
    if (!_disposed) _onChanged();
  }
}
