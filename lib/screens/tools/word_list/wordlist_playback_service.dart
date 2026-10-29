// lib/screens/tools/word_list/wordlist_playback_service.dart
// Persistent TTS playback for Wordlist – continues across tabs
// Singleton ChangeNotifier + floating bubble support

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../features/tts/tts_service.dart';
import '../../../models/word_entry.dart';

class WordlistPlaybackService extends ChangeNotifier {
  static final WordlistPlaybackService _instance =
      WordlistPlaybackService._internal();
  factory WordlistPlaybackService() => _instance;
  WordlistPlaybackService._internal();

  final _tts = TtsService();
  static const double _kSpeakSpeed = 0.82;

  bool _disposed = false;
  bool get _isDisposed => _disposed;

  // Playback state
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  int _playingIndex = -1;
  int get playingIndex => _playingIndex;

  int _playingRepeatCurrent = 0;
  int get playingRepeatCurrent => _playingRepeatCurrent;

  int _listRepeatCount = 1;
  int get listRepeatCount => _listRepeatCount;

  int _listRepeatCurrent = 0;
  int get listRepeatCurrent => _listRepeatCurrent;

  final Map<String, int> _repeatOverrides = {};
  Map<String, int> get repeatOverrides => Map.unmodifiable(_repeatOverrides);

  List<WordEntry> _queue = [];
  List<WordEntry> get queue => List.unmodifiable(_queue);

  WordEntry? get currentWord =>
      (_playingIndex >= 0 && _playingIndex < _queue.length)
          ? _queue[_playingIndex]
          : null;

  bool _stopRequested = false;

  // Wordlist screen active flag – for bubble auto-hide
  bool _isWordlistScreenActive = false;
  bool get isWordlistScreenActive => _isWordlistScreenActive;

  void setWordlistScreenActive(bool active) {
    if (_isWordlistScreenActive == active) return;
    _isWordlistScreenActive = active;
    _safeNotify();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  int getRepeatCount(String id) => (_repeatOverrides[id] ?? 1).clamp(1, 999);

  void setRepeatCount(String id, int count) {
    _repeatOverrides[id] = count.clamp(1, 999);
    _safeNotify();
  }

  void setListRepeatCount(int count) {
    _listRepeatCount = count < 0 ? 0 : count;
    _safeNotify();
  }

  void setRepeatOverrides(Map<String, int> overrides) {
    _repeatOverrides
      ..clear()
      ..addAll(overrides);
    _safeNotify();
  }

  Future<void> playAll(
    List<WordEntry> items, {
    int listRepeatCount = 1,
    Map<String, int>? overrides,
  }) async {
    if (_isDisposed) return;
    if (items.isEmpty) return;

    if (_isPlaying) {
      await stopPlayback();
      return;
    }

    HapticFeedback.mediumImpact();
    _stopRequested = false;
    _queue = List.from(items);
    _listRepeatCount = listRepeatCount;
    if (overrides != null) {
      _repeatOverrides
        ..clear()
        ..addAll(overrides);
    }
    _listRepeatCurrent = 0;
    _playingIndex = -1;
    _playingRepeatCurrent = 0;
    _isPlaying = true;
    _safeNotify();

    final previousSpeed = _tts.speed;
    _tts.configure(speed: _kSpeakSpeed);

    try {
      int listPass = 0;
      while (!_stopRequested && !_isDisposed) {
        listPass++;
        _listRepeatCurrent = listPass;
        _safeNotify();

        for (int i = 0; i < _queue.length; i++) {
          if (_stopRequested || _isDisposed) break;
          _playingIndex = i;
          _safeNotify();

          final entry = _queue[i];
          final repeat = getRepeatCount(entry.id);

          for (int r = 0; r < repeat; r++) {
            if (_stopRequested || _isDisposed) break;
            _playingRepeatCurrent = r + 1;
            _safeNotify();
            await _tts.speak(entry.word);
            if (r < repeat - 1 && !_stopRequested && !_isDisposed) {
              await Future.delayed(const Duration(milliseconds: 700));
            }
          }

          if (!_stopRequested && !_isDisposed && i < _queue.length - 1) {
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }

        if (_stopRequested || _isDisposed) break;
        if (_listRepeatCount != 0 && listPass >= _listRepeatCount) break;
        if (!_stopRequested && !_isDisposed) {
          await Future.delayed(const Duration(milliseconds: 1200));
        }
      }
    } finally {
      _tts.configure(speed: previousSpeed);
      if (!_isDisposed) {
        _isPlaying = false;
        _playingIndex = -1;
        _playingRepeatCurrent = 0;
        _listRepeatCurrent = 0;
        _stopRequested = false;
        _safeNotify();
      }
    }
  }

  Future<void> playSingle(WordEntry entry) async {
    if (_isDisposed) return;
    HapticFeedback.lightImpact();
    final repeat = getRepeatCount(entry.id);
    final previousSpeed = _tts.speed;
    _tts.configure(speed: _kSpeakSpeed);
    _isPlaying = true;
    _playingIndex = _queue.indexWhere((e) => e.id == entry.id);
    // if not in queue, set temporary
    if (_playingIndex == -1) {
      _queue = [entry];
      _playingIndex = 0;
    }
    _safeNotify();
    try {
      for (int i = 0; i < repeat; i++) {
        if (_stopRequested || _isDisposed) break;
        _playingRepeatCurrent = i + 1;
        _safeNotify();
        await _tts.speak(entry.word);
        if (i < repeat - 1) {
          await Future.delayed(const Duration(milliseconds: 600));
        }
      }
    } finally {
      _tts.configure(speed: previousSpeed);
      _isPlaying = false;
      _playingIndex = -1;
      _playingRepeatCurrent = 0;
      _safeNotify();
    }
  }

  Future<void> stopPlayback() async {
    _stopRequested = true;
    await _tts.stop();
    _isPlaying = false;
    _playingIndex = -1;
    _playingRepeatCurrent = 0;
    _listRepeatCurrent = 0;
    _safeNotify();
  }

  // For bubble: should show when playing and wordlist screen NOT active
  bool get shouldShowBubble => _isPlaying && !_isWordlistScreenActive;

  @override
  void dispose() {
    _disposed = true;
    _stopRequested = true;
    _tts.stop();
    super.dispose();
  }
}
