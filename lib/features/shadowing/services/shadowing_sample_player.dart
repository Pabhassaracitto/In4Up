import 'dart:async';

import 'lrc_ab_suggestions.dart';

/// The small part of just_audio needed for a bounded shadowing sample.
/// Keeping this boundary narrow makes load/play/cancel races runnable on the
/// Flutter host, without an audio device or platform plugin.
abstract interface class ShadowingSampleAudio {
  Duration get position;
  Duration? get duration;
  Future<Duration?> setFilePath(String path);
  Future<void> setSpeed(double speed);
  Future<void> seek(Duration position);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
}

/// One transport owner for both speaking-studio tabs. A sample is played once;
/// whole-track/A-B practice can still request repetitions explicitly.
class ShadowingSamplePlayer {
  ShadowingSamplePlayer({
    required ShadowingSampleAudio audio,
    required bool Function(String path) sourceExists,
  })  : _audio = audio,
        _sourceExists = sourceExists;

  final ShadowingSampleAudio _audio;
  final bool Function(String path) _sourceExists;
  String? _audioPath;
  List<AbSuggestion> _sentences = const [];
  int _selectedIndex = -1;
  int _generation = 0;
  bool _disposed = false;

  List<AbSuggestion> get sentences => _sentences;
  int get selectedIndex => _selectedIndex;
  AbSuggestion? get selectedSentence => sentenceAt(_selectedIndex);

  AbSuggestion? sentenceAt(int index) =>
      index >= 0 && index < _sentences.length ? _sentences[index] : null;

  /// Called post-frame with existing lyrics, never with newly generated AI text.
  bool configure({
    required String? audioPath,
    required List<AbSuggestion> sentences,
  }) {
    final unchanged = audioPath == _audioPath &&
        sentences.length == _sentences.length &&
        Iterable<int>.generate(sentences.length).every((i) =>
            sentences[i].start == _sentences[i].start &&
            sentences[i].end == _sentences[i].end &&
            sentences[i].text == _sentences[i].text);
    if (unchanged) return false;
    final previous = selectedSentence;
    _audioPath = audioPath;
    _sentences = List.unmodifiable(sentences);
    _selectedIndex = previous == null
        ? -1
        : sentences.indexWhere((s) =>
            s.start == previous.start &&
            s.end == previous.end &&
            s.text == previous.text);
    // A pending load from the old source must not publish playback state.
    unawaited(stop());
    return true;
  }

  bool selectSentence(int index) {
    if (sentenceAt(index) == null) return false;
    if (_selectedIndex != index) {
      _selectedIndex = index;
      unawaited(stop());
    }
    return true;
  }

  void clearSelection() {
    if (_selectedIndex == -1) return;
    _selectedIndex = -1;
    unawaited(stop());
  }

  Future<void> speakSentence(
    int index, {
    double speed = 1.0,
    void Function()? onStarted,
    void Function(int repeat)? onRepeat,
    void Function()? onFinished,
    void Function(String error)? onError,
  }) {
    final sentence = sentenceAt(index);
    if (sentence == null || !selectSentence(index)) return Future.value();
    return _play(
      start: sentence.start,
      end: sentence.end,
      speed: speed,
      repeatCount: 1,
      onStarted: onStarted,
      onRepeat: onRepeat,
      onFinished: onFinished,
      onError: onError,
    );
  }

  Future<void> playOriginal({
    Duration? start,
    Duration? end,
    double speed = 1.0,
    int repeatCount = 1,
    void Function()? onStarted,
    void Function(int repeat)? onRepeat,
    void Function()? onFinished,
    void Function(String error)? onError,
  }) =>
      _play(
        start: start,
        end: end,
        speed: speed,
        repeatCount: repeatCount,
        onStarted: onStarted,
        onRepeat: onRepeat,
        onFinished: onFinished,
        onError: onError,
      );

  Future<void> _play({
    required Duration? start,
    required Duration? end,
    required double speed,
    required int repeatCount,
    required void Function()? onStarted,
    required void Function(int repeat)? onRepeat,
    required void Function()? onFinished,
    required void Function(String error)? onError,
  }) async {
    // Invalidate BEFORE the first await. Ten rapid taps may overlap transport
    // futures, but only the newest generation may load, play or publish state.
    final generation = ++_generation;
    bool current() => !_disposed && generation == _generation;
    await _audio.stop();
    if (!current()) return;

    final path = _audioPath;
    if (path == null || path.isEmpty) {
      onError?.call('no_source');
      return;
    }
    if (!path.startsWith('content://') && !_sourceExists(path)) {
      onError?.call('file_missing');
      return;
    }

    onStarted?.call();
    try {
      final loadedDuration = await _audio.setFilePath(path);
      if (!current()) return;
      await _audio.setSpeed(speed);
      if (!current()) return;

      final duration = loadedDuration ?? _audio.duration;
      final startPos = start ?? Duration.zero;
      var endPos = end ?? duration ?? const Duration(seconds: 10);
      if (end != null && duration != null && endPos > duration) {
        endPos = duration;
      }
      if (startPos < Duration.zero || endPos <= startPos) {
        onError?.call('invalid_range');
        return;
      }

      final span = endPos - startPos;
      final maxWait = Duration(
        milliseconds: (span.inMilliseconds / speed).ceil() + 600,
      );
      for (var i = 0; i < repeatCount; i++) {
        await _audio.seek(startPos);
        if (!current()) return;
        final elapsed = Stopwatch()..start();
        await _audio.play();
        if (!current()) return;
        // The deadline also works when a platform stops delivering position
        // ticks. Never fall back to playing the remainder of the file.
        while (current() &&
            _audio.position < endPos &&
            elapsed.elapsed < maxWait) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        if (!current()) return;
        await _audio.pause();
        if (!current()) return;
        await _audio.seek(endPos);
        if (!current()) return;
        onRepeat?.call(i + 1);
        if (i + 1 < repeatCount) {
          await Future<void>.delayed(const Duration(milliseconds: 350));
          if (!current()) return;
        }
      }
      onFinished?.call();
    } catch (_) {
      if (!current()) return;
      // A stale failure must not overwrite the state/error of a newer sample.
      await _audio.stop();
      if (current()) {
        onError?.call('play_failed');
      }
    }
  }

  Future<void> stop() {
    _generation++;
    return _audio.stop();
  }

  void dispose() {
    _disposed = true;
    _generation++;
  }
}
