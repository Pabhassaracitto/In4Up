// lib/features/learn_by_heart/services/multilingual_audio_service.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../../tts/tts_service.dart';
import '../models/chunk.dart';
import '../models/learn_by_heart_item.dart';
import '../models/line_timestamp.dart';

enum PlaybackLanguageMode {
  vietnamese,
  pali,
  bilingual,
}

/// Service điều phối âm thanh đa ngữ (Audio Stream & Multilingual TTS)
class MultilingualAudioService extends ChangeNotifier {
  final TtsService _tts = TtsService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isPlaying = false;
  double _speed = 1.0;
  int? _currentLineIndex; // 1-based line index
  bool _isLoopingChunk = false;
  PlaybackLanguageMode _langMode = PlaybackLanguageMode.bilingual;
  bool _stopRequested = false;

  bool get isPlaying => _isPlaying;
  double get speed => _speed;
  int? get currentLineIndex => _currentLineIndex;
  bool get isLoopingChunk => _isLoopingChunk;
  PlaybackLanguageMode get langMode => _langMode;

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

  void toggleLoopChunk() {
    _isLoopingChunk = !_isLoopingChunk;
    notifyListeners();
  }

  /// Phát toàn bộ bài theo từng dòng có highlight đồng bộ
  Future<void> playFullItem(LearnByHeartItem item, {void Function(int line)? onLineChanged}) async {
    await stop();
    _stopRequested = false;
    _isPlaying = true;
    notifyListeners();

    try {
      final timestamps = item.lineTimestamps.isNotEmpty
          ? item.lineTimestamps
          : _generateEstimatedTimestamps(item);

      for (int i = 0; i < timestamps.length; i++) {
        if (_stopRequested) break;
        final ts = timestamps[i];
        _currentLineIndex = ts.line;
        onLineChanged?.call(ts.line);
        notifyListeners();

        await _speakLineContent(ts, item);
        if (_stopRequested) break;

        // Nghỉ nhẹ giữa các dòng
        await Future.delayed(const Duration(milliseconds: 400));
      }
    } finally {
      if (!_isLoopingChunk) {
        _isPlaying = false;
        _currentLineIndex = null;
        notifyListeners();
      }
    }
  }

  /// Phát một chunk cụ thể (hoặc lặp lại chunk đó)
  Future<void> playChunk(
    LearnByHeartItem item,
    Chunk chunk, {
    void Function(int line)? onLineChanged,
  }) async {
    await stop();
    _stopRequested = false;
    _isPlaying = true;
    notifyListeners();

    do {
      final timestamps = item.lineTimestamps.isNotEmpty
          ? item.lineTimestamps
          : _generateEstimatedTimestamps(item);

      final chunkTimestamps = timestamps.where((t) => chunk.lineRange.contains(t.line)).toList();

      for (final ts in chunkTimestamps) {
        if (_stopRequested) break;
        _currentLineIndex = ts.line;
        onLineChanged?.call(ts.line);
        notifyListeners();

        await _speakLineContent(ts, item);
        if (_stopRequested) break;

        await Future.delayed(const Duration(milliseconds: 350));
      }

      if (_isLoopingChunk && !_stopRequested) {
        await Future.delayed(const Duration(milliseconds: 800));
      }
    } while (_isLoopingChunk && !_stopRequested);

    _isPlaying = false;
    _currentLineIndex = null;
    notifyListeners();
  }

  /// Phát dòng đơn lẻ
  Future<void> playSingleLine(LineTimestamp ts, LearnByHeartItem item) async {
    await stop();
    _stopRequested = false;
    _isPlaying = true;
    _currentLineIndex = ts.line;
    notifyListeners();

    try {
      await _speakLineContent(ts, item);
    } finally {
      _isPlaying = false;
      notifyListeners();
    }
  }

  /// Phát nội dung dòng theo chế độ ngôn ngữ đã chọn
  Future<void> _speakLineContent(LineTimestamp ts, LearnByHeartItem item) async {
    final viText = ts.text ?? _getLineFromText(item.vietnameseText, ts.line);
    final paliText = ts.paliText ?? _getLineFromText(item.paliText, ts.line);

    switch (_langMode) {
      case PlaybackLanguageMode.vietnamese:
        if (viText.isNotEmpty) {
          _tts.configure(language: 'vi-VN', speed: _speed);
          await _tts.speak(viText);
          await _waitForTts();
        }
        break;

      case PlaybackLanguageMode.pali:
        if (paliText.isNotEmpty) {
          _tts.configure(language: 'pi', speed: _speed);
          await _tts.speak(paliText);
          await _waitForTts();
        }
        break;

      case PlaybackLanguageMode.bilingual:
        if (paliText.isNotEmpty) {
          _tts.configure(language: 'pi', speed: _speed);
          await _tts.speak(paliText);
          await _waitForTts();
          await Future.delayed(const Duration(milliseconds: 250));
        }
        if (viText.isNotEmpty && !_stopRequested) {
          _tts.configure(language: 'vi-VN', speed: _speed);
          await _tts.speak(viText);
          await _waitForTts();
        }
        break;
    }
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
