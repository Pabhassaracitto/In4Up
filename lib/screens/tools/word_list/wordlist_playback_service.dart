// lib/screens/tools/word_list/wordlist_playback_service.dart
// Persistent TTS playback for Wordlist – continues across tabs
// Singleton ChangeNotifier + floating bubble support

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../features/tts/tts_service.dart';
import '../../../models/word_entry.dart';
import 'wordlist_read_sequence.dart';

class WordlistPlaybackService extends ChangeNotifier {
  static final WordlistPlaybackService _instance =
      WordlistPlaybackService._internal();
  factory WordlistPlaybackService() => _instance;
  WordlistPlaybackService._internal()
      : _tts = TtsService(), _speakOverride = null, _stopOverride = null;

  @visibleForTesting
  WordlistPlaybackService.test({
    required Future<void> Function(String text, String? language) speak,
    required Future<void> Function() stop,
  }) : _tts = null, _speakOverride = speak, _stopOverride = stop;

  final TtsService? _tts;
  final Future<void> Function(String, String?)? _speakOverride;
  final Future<void> Function()? _stopOverride;
  Future<void> _speak(String text, String? language) => _speakOverride != null
      ? _speakOverride!(text, language)
      : _tts!.speak(text, language: language, matchVoiceLanguage: true);
  Future<void> _stopAudio() => _stopOverride?.call() ?? _tts!.stop();
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

  // PLAN-043 mục 2 — cài đặt đọc "từ + nghĩa" (thứ tự/số lần từng phía,
  // khoảng lặng, ngôn ngữ phía nghĩa). Persist SharedPreferences; mặc định
  // Từ ×2 → Nghĩa ×1 (chốt owner 2026-11-02). Thứ tự bước do hàm thuần
  // `buildWordlistReadStepsForLine` dựng — service chỉ phát + truyền
  // `language:` từng bước xuống TtsService.
  static const String _kReadSettingsKey = 'wordlist_read_settings_v1';
  WordlistReadSettings _readSettings = const WordlistReadSettings();
  WordlistReadSettings get readSettings => _readSettings;
  bool _readSettingsLoaded = false;
  Future<void>? _settingsLoading;

  /// Phía đang đọc của bước hiện tại (UI/bubble hiện "đang đọc nghĩa").
  bool _currentIsMeaning = false;
  bool get currentIsMeaning => _currentIsMeaning;

  /// Nội dung bước đang đọc (từ hoặc nghĩa) — bubble hiện đúng thứ đang nghe.
  String? _currentStepText;
  String? get currentStepText => _currentStepText;

  Future<void> ensureReadSettingsLoaded() {
    if (_readSettingsLoaded) return Future.value();
    return _settingsLoading ??= _loadReadSettings();
  }

  Future<void> _loadReadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kReadSettingsKey);
      if (!_readSettingsLoaded && raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _readSettings = WordlistReadSettings.fromJson(decoded);
        }
      }
    } catch (e) {
      debugPrint('[WordlistPlayback] load read settings lỗi: $e');
    } finally {
      _readSettingsLoaded = true;
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
  Future<void> _delayInterruptible(int ms, int session) async {
    var remaining = ms;
    while (remaining > 0 && _isCurrent(session)) {
      final slice = remaining > 100 ? 100 : remaining;
      await Future.delayed(Duration(milliseconds: slice));
      remaining -= slice;
    }
  }

  String? _languageForStep(WordEntry entry, WordlistReadStep step, WordlistReadSettings settings) {
    if (!step.isMeaning) {
      final lang = entry.language.trim();
      return lang.isEmpty ? 'auto' : lang;
    }
    final lang = settings.meaningLanguage.trim();
    return lang.isEmpty ? 'auto' : lang;
  }

  /// Phát toàn bộ bước của MỘT entry, lặp [rounds] vòng pattern
  /// (vòng = số lần phát theo từng từ như cơ chế cũ — mặc định 1).
  Future<void> _speakEntrySteps(
    WordEntry entry,
    List<WordlistReadStep> steps,
    int rounds,
    int session,
    WordlistReadSettings settings,
  ) async {
    for (var round = 0; round < rounds; round++) {
      if (!_isCurrent(session)) return;
      _playingRepeatCurrent = round + 1;
      if (round > 0) {
        await _delayInterruptible(settings.gapBetweenRepeatsMs, session);
      }
      for (final step in steps) {
        if (!_isCurrent(session)) return;
        if (step.pauseBeforeMs > 0) {
          await _delayInterruptible(step.pauseBeforeMs, session);
          if (!_isCurrent(session)) return;
        }
        _currentIsMeaning = step.isMeaning;
        _currentStepText = step.text;
        _safeNotify();
        await _speak(step.text, _languageForStep(entry, step, settings));
      }
    }
  }

  List<WordEntry> _queue = [];
  List<WordEntry> get queue => List.unmodifiable(_queue);

  WordEntry? get currentWord =>
      (_playingIndex >= 0 && _playingIndex < _queue.length)
          ? _queue[_playingIndex]
          : null;

  int _session = 0;
  Future<void> _transition = Future.value();
  Future<void>? _activeRun;
  bool _isCurrent(int session) => !_isDisposed && session == _session;

  // Commands are serialized, but invalidate the old loop immediately. A new
  // run starts only after the previous speak and stop have both settled.
  Future<void> _start(List<WordEntry> items, {required bool single}) {
    final session = ++_session;
    final completion = Completer<void>();
    _transition = _transition.then((_) async {
      await _stopAudio();
      final active = _activeRun;
      if (active != null) {
        try {
          await active;
        } catch (_) {
          // The run reports its own error; it must not block later commands.
        }
      }
      if (!_isCurrent(session)) {
        completion.complete();
        return;
      }
      final run = _run(items, session, single: single);
      _activeRun = run;
      run.then((_) {
        if (identical(_activeRun, run)) _activeRun = null;
        completion.complete();
      }, onError: (Object error, StackTrace stack) {
        if (identical(_activeRun, run)) _activeRun = null;
        completion.completeError(error, stack);
      });
    }).catchError((Object error, StackTrace stack) {
      if (!completion.isCompleted) completion.completeError(error, stack);
    });
    return completion.future;
  }

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
  }) {
    if (_isDisposed || items.isEmpty) return Future.value();
    _listRepeatCount = listRepeatCount;
    if (overrides != null) {
      _repeatOverrides
        ..clear()
        ..addAll(overrides);
    }
    HapticFeedback.mediumImpact();
    return _start(List.of(items), single: false);
  }

  Future<void> playSingle(WordEntry entry) {
    if (_isDisposed) return Future.value();
    HapticFeedback.lightImpact();
    return _start([entry], single: true);
  }

  Future<void> _run(List<WordEntry> items, int session,
      {required bool single}) async {
    await ensureReadSettingsLoaded();
    if (!_isCurrent(session)) return;
    final settings = _readSettings;
    _queue = items;
    _listRepeatCurrent = 0;
    _playingIndex = -1;
    _playingRepeatCurrent = 0;
    _isPlaying = true;
    _safeNotify();
    final previousSpeed = _tts?.speed;
    _tts?.configure(speed: _kSpeakSpeed);
    try {
      var listPass = 0;
      while (_isCurrent(session)) {
        _listRepeatCurrent = ++listPass;
        _safeNotify();
        for (var i = 0; i < items.length && _isCurrent(session); i++) {
          _playingIndex = i;
          final entry = items[i];
          final steps = buildWordlistReadStepsForLine(
            lineIndex: i,
            line: WordlistReadLine(word: entry.word, meaning: entry.meaning),
            settings: settings,
          );
          await _speakEntrySteps(entry, steps, getRepeatCount(entry.id), session, settings);
          if (i < items.length - 1 && _isCurrent(session)) {
            await _delayInterruptible(settings.gapBetweenWordsMs, session);
          }
        }
        if (single || !_isCurrent(session) ||
            (_listRepeatCount != 0 && listPass >= _listRepeatCount)) break;
        await _delayInterruptible(1200, session);
      }
    } finally {
      if (previousSpeed != null) _tts?.configure(speed: previousSpeed);
      if (_isCurrent(session)) _resetState();
    }
  }

  void _resetState() {
    _isPlaying = false;
    _playingIndex = -1;
    _playingRepeatCurrent = 0;
    _listRepeatCurrent = 0;
    _currentIsMeaning = false;
    _currentStepText = null;
    _safeNotify();
  }

  Future<void> stopPlayback() {
    ++_session;
    _resetState();
    _transition = _transition.then((_) async {
      await _stopAudio();
      final active = _activeRun;
      if (active != null) {
        try {
          await active;
        } catch (_) {
          // The run reports its own error; it must not block later commands.
        }
      }
    });
    return _transition;
  }

  // For bubble: should show when playing and wordlist screen NOT active
  bool get shouldShowBubble => _isPlaying && !_isWordlistScreenActive;

  @override
  void dispose() {
    _disposed = true;
    ++_session;
    _stopAudio();
    super.dispose();
  }
}
