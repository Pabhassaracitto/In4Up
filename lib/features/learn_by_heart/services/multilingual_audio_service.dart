// lib/features/learn_by_heart/services/multilingual_audio_service.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../../tts/tts_service.dart';
import '../models/chunk.dart';
import '../models/learn_by_heart_item.dart';
import '../models/line_timestamp.dart';
import '../models/recitation_language.dart';
import '../models/recitation_repeat.dart';

enum PlaybackLanguageMode {
  source,
  target,
  bilingual,
}

/// Service điều phối âm thanh đa ngữ (Audio Stream & Multilingual TTS)
class MultilingualAudioService extends ChangeNotifier {
  final TtsService _tts = TtsService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isPlaying = false;
  double _speed = 1.0;
  int? _currentLineIndex; // 1-based line index
  PlaybackLanguageMode _langMode = PlaybackLanguageMode.bilingual;
  bool _stopRequested = false;

  /// `0` = loop the current range forever (whole verse or selected chunk).
  int _itemRepeatCount = 1;
  int _itemRepeatCurrent = 0;
  int _lineRepeatCount = 1;
  int _lineRepeatCurrent = 0;
  final Map<int, int> _lineRepeatOverrides = {};

  bool get isPlaying => _isPlaying;
  double get speed => _speed;
  int? get currentLineIndex => _currentLineIndex;
  PlaybackLanguageMode get langMode => _langMode;
  int get itemRepeatCount => _itemRepeatCount;
  int get itemRepeatCurrent => _itemRepeatCurrent;
  int get lineRepeatCount => _lineRepeatCount;
  int get lineRepeatCurrent => _lineRepeatCurrent;

  int lineRepeatFor(int line) => RecitationRepeat.forLine(
        line,
        defaultCount: _lineRepeatCount,
        overrides: _lineRepeatOverrides,
      );

  void setSpeed(double s) {
    _speed = s.clamp(0.5, 2.0);
    _tts.configure(speed: _speed);
    _audioPlayer.setSpeed(_speed).catchError((_) {});
    notifyListeners();
  }

  void setLanguageMode(PlaybackLanguageMode mode) {
    _langMode = mode;
    notifyListeners();
  }

  void setItemRepeatCount(int count) {
    _itemRepeatCount = RecitationRepeat.clampItem(count);
    notifyListeners();
  }

  void setLineRepeatCount(int count) {
    _lineRepeatCount = RecitationRepeat.clampLine(count);
    notifyListeners();
  }

  void setLineRepeatOverride(int line, int count) {
    _lineRepeatOverrides[line] = RecitationRepeat.clampLine(count);
    notifyListeners();
  }

  /// Phát toàn bộ bài theo từng dòng có highlight đồng bộ
  Future<void> playFullItem(LearnByHeartItem item, {void Function(int line)? onLineChanged}) async {
    final timestamps = item.lineTimestamps.isNotEmpty
        ? item.lineTimestamps
        : _generateEstimatedTimestamps(item);
    await _playRange(item, timestamps, onLineChanged: onLineChanged);
  }

  /// Phát một chunk cụ thể (lặp theo [itemRepeatCount], ∞ nếu = 0)
  Future<void> playChunk(
    LearnByHeartItem item,
    Chunk chunk, {
    void Function(int line)? onLineChanged,
  }) async {
    final timestamps = item.lineTimestamps.isNotEmpty
        ? item.lineTimestamps
        : _generateEstimatedTimestamps(item);
    final chunkTimestamps =
        timestamps.where((t) => chunk.lineRange.contains(t.line)).toList();
    await _playRange(item, chunkTimestamps, onLineChanged: onLineChanged);
  }

  /// Phát dòng đơn lẻ — vẫn tôn trọng số lần lặp của đúng câu đó
  Future<void> playSingleLine(LineTimestamp ts, LearnByHeartItem item) async {
    await _playRange(
      item,
      [ts],
      onLineChanged: null,
      applyItemRepeat: false,
    );
  }

  Future<void> _playRange(
    LearnByHeartItem item,
    List<LineTimestamp> timestamps, {
    void Function(int line)? onLineChanged,
    bool applyItemRepeat = true,
  }) async {
    if (timestamps.isEmpty) return;
    await stop();
    _stopRequested = false;
    _isPlaying = true;
    _itemRepeatCurrent = 0;
    _lineRepeatCurrent = 0;
    notifyListeners();

    try {
      int pass = 0;
      while (!_stopRequested) {
        pass++;
        _itemRepeatCurrent = pass;
        notifyListeners();

        for (int i = 0; i < timestamps.length; i++) {
          if (_stopRequested) break;
          final ts = timestamps[i];
          final repeats = lineRepeatFor(ts.line);
          _currentLineIndex = ts.line;
          onLineChanged?.call(ts.line);
          notifyListeners();

          for (int r = 1; r <= repeats; r++) {
            if (_stopRequested) break;
            _lineRepeatCurrent = r;
            notifyListeners();
            await _speakLineContent(ts, item);
            if (_stopRequested) break;
            if (r < repeats) {
              await Future.delayed(const Duration(milliseconds: 280));
            }
          }

          if (_stopRequested) break;
          if (i < timestamps.length - 1) {
            await Future.delayed(const Duration(milliseconds: 400));
          }
        }

        if (_stopRequested) break;
        final itemCount = applyItemRepeat ? _itemRepeatCount : 1;
        if (!RecitationRepeat.anotherItemPass(pass, itemCount)) break;
        await Future.delayed(const Duration(milliseconds: 800));
      }
    } finally {
      _isPlaying = false;
      _currentLineIndex = null;
      _itemRepeatCurrent = 0;
      _lineRepeatCurrent = 0;
      notifyListeners();
    }
  }

  /// Phát nội dung dòng theo chế độ ngôn ngữ đã chọn
  Future<void> _speakLineContent(LineTimestamp ts, LearnByHeartItem item) async {
    final targetText = ts.text ?? _getLineFromText(item.targetText, ts.line);
    final sourceText = ts.paliText ?? _getLineFromText(item.sourceText, ts.line);

    switch (_langMode) {
      case PlaybackLanguageMode.target:
        await _speakText(targetText, item.targetLang);
        break;

      case PlaybackLanguageMode.source:
        await _speakText(sourceText, item.sourceLang);
        break;

      case PlaybackLanguageMode.bilingual:
        await _speakText(sourceText, item.sourceLang);
        if (sourceText.isNotEmpty && targetText.isNotEmpty && !_stopRequested) {
          await Future.delayed(const Duration(milliseconds: 250));
        }
        if (!_stopRequested) {
          await _speakText(targetText, item.targetLang);
        }
        break;
    }
  }

  Future<void> _speakText(String text, String declaredLang) async {
    if (text.trim().isEmpty || _stopRequested) return;
    final locale = RecitationLanguage.speakLocale(
      declaredCode: declaredLang,
      text: text,
    );
    _tts.configure(language: locale, autoDetect: false, speed: _speed);
    await _tts.speak(text);
    await _waitForTts();
  }

  Future<void> _waitForTts() async {
    // Chờ cho đến khi TTS đọc xong dòng
    int guard = 0;
    while (_tts.isSpeaking && !_stopRequested && guard < 100) {
      await Future.delayed(const Duration(milliseconds: 100));
      guard++;
    }
  }

  String _getLineFromText(String fullText, int lineIndex) {
    final lines = fullText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lineIndex - 1 >= 0 && lineIndex - 1 < lines.length) {
      return lines[lineIndex - 1];
    }
    return '';
  }

  List<LineTimestamp> _generateEstimatedTimestamps(LearnByHeartItem item) {
    final viLines = item.vietnameseLines;
    final paliLines = item.paliLines;
    final count = math.max(viLines.length, paliLines.length);

    final list = <LineTimestamp>[];
    double currentSec = 0.0;
    for (int i = 1; i <= count; i++) {
      final vi = i - 1 < viLines.length ? viLines[i - 1] : '';
      final pi = i - 1 < paliLines.length ? paliLines[i - 1] : '';
      final durationSec = math.max(3.0, (vi.length + pi.length) * 0.08);
      list.add(LineTimestamp(
        line: i,
        start: currentSec,
        end: currentSec + durationSec,
        text: vi,
        paliText: pi,
      ));
      currentSec += durationSec;
    }
    return list;
  }

  Future<void> stop() async {
    _stopRequested = true;
    _isPlaying = false;
    _currentLineIndex = null;
    await _tts.stop();
    await _audioPlayer.stop();
    notifyListeners();
  }

  @override
  void dispose() {
    _stopRequested = true;
    _audioPlayer.dispose();
    super.dispose();
  }
}
