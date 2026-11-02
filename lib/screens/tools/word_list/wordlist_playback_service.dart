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

  // PLAN-041 mục 2 — cài đặt đọc "từ + nghĩa" (thứ tự/số lần từng phía,
  // khoảng lặng, ngôn ngữ phía nghĩa). Persist SharedPreferences; mặc định
  // Từ ×2 → Nghĩa ×1 (chốt owner 2026-11-02). Thứ tự bước do hàm thuần
  // `buildWordlistReadStepsForLine` dựng — service chỉ phát + truyền
  // `language:` từng bước xuống TtsService.
  static const String _kReadSettingsKey = 'wordlist_read_settings_v1';
  WordlistReadSettings _readSettings = const WordlistReadSettings();
  WordlistReadSettings get readSettings => _readSettings;
  bool _readSettingsLoaded = false;

  /// Phía đang đọc của bước hiện tại (UI/bubble hiện "đang đọc nghĩa").
  bool _currentIsMeaning = false;
  bool get currentIsMeaning => _currentIsMeaning;

  /// Nội dung bước đang đọc (từ hoặc nghĩa) — bubble hiện đúng thứ đang nghe.
  String? _currentStepText;
  String? get currentStepText => _currentStepText;

  Future<void> ensureReadSettingsLoaded() async {
    if (_readSettingsLoaded) return;
    _readSettingsLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kReadSettingsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _readSettings = WordlistReadSettings.fromJson(decoded);
        }
      }
    } catch (e) {
      debugPrint('[WordlistPlayback] load read settings lỗi: $e');
    }
  }

  Future<void> updateReadSettings(WordlistReadSettings next) async {
    _readSettings = next;
    _readSettingsLoaded = true;
    _safeNotify();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kReadSettingsKey, jsonEncode(next.toJson()));
    } catch (e) {
      debugPrint('[WordlistPlayback] save read settings lỗi: $e');
    }
  }

  /// Nghỉ có thể ngắt bằng Stop (khoảng lặng gợi nhớ có thể dài vài giây —
  /// không bắt người dùng chờ hết mới dừng được).
  Future<void> _delayInterruptible(int ms) async {
    var remaining = ms;
    while (remaining > 0 && !_stopRequested && !_isDisposed) {
      final slice = remaining > 100 ? 100 : remaining;
      await Future.delayed(Duration(milliseconds: slice));
      remaining -= slice;
    }
  }

  String? _languageForStep(WordEntry entry, WordlistReadStep step) {
    if (!step.isMeaning) {
      final lang = entry.language.trim();
      return lang.isEmpty ? null : lang;
    }
    final lang = _readSettings.meaningLanguage.trim();
    return (lang.isEmpty || lang == 'auto') ? null : lang;
  }

  /// Phát toàn bộ bước của MỘT entry, lặp [rounds] vòng pattern
  /// (vòng = số lần phát theo từng từ như cơ chế cũ — mặc định 1).
  Future<void> _speakEntrySteps(
    WordEntry entry,
    List<WordlistReadStep> steps,
    int rounds,
  ) async {
    for (var round = 0; round < rounds; round++) {
      if (_stopRequested || _isDisposed) return;
      _playingRepeatCurrent = round + 1;
      if (round > 0) {
        await _delayInterruptible(_readSettings.gapBetweenRepeatsMs);
      }
      for (final step in steps) {
        if (_stopRequested || _isDisposed) return;
        if (step.pauseBeforeMs > 0) {
          await _delayInterruptible(step.pauseBeforeMs);
          if (_stopRequested || _isDisposed) return;
        }
        _currentIsMeaning = step.isMeaning;
        _currentStepText = step.text;
        _safeNotify();
        await _tts.speak(step.text, language: _languageForStep(entry, step));
      }
    }
  }

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

    await ensureReadSettingsLoaded();
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
        _currentIsMeaning = false;
        _currentStepText = null;
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
      _currentIsMeaning = false;
      _currentStepText = null;
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
    _currentIsMeaning = false;
    _currentStepText = null;
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
