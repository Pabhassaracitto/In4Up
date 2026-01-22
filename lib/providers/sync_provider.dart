import 'dart:async';
import 'package:flutter/material.dart';
import '../models/synced_line.dart';
import 'player_provider.dart';

enum SyncLayout {
  musicFull,    // Chỉ hiện Music
  textFull,     // Chỉ hiện Text
  split,        // Chia đôi màn hình
  miniPlayer,   // Mini player + Text lớn
}

class SyncProvider extends ChangeNotifier {
  // Sync data
  SyncedDocument? _document;
  List<SyncedLine> _lines = [];
  int _currentLineIndex = -1;

  // Layout
  SyncLayout _layout = SyncLayout.split;
  double _musicHeight = 0.4; // 40% cho music

  // Settings
  bool _autoScroll = true;
  bool _showTimestamps = true;
  bool _showTranslation = true;
  double _fontSize = 18.0;

  // Sync with player
  PlayerProvider? _playerProvider;
  StreamSubscription? _positionSubscription;

  // Getters
  SyncedDocument? get document => _document;
  List<SyncedLine> get lines => _lines;
  int get currentLineIndex => _currentLineIndex;
  SyncLayout get layout => _layout;
  double get musicHeight => _musicHeight;
  bool get autoScroll => _autoScroll;
  bool get showTimestamps => _showTimestamps;
  bool get showTranslation => _showTranslation;
  double get fontSize => _fontSize;
  bool get hasDocument => _document != null && _lines.isNotEmpty;

  // ==================== SYNC WITH PLAYER ====================

  void attachPlayer(PlayerProvider player) {
    _playerProvider = player;
    player.addListener(_onPlayerStateChanged);
  }

  void detachPlayer() {
    _playerProvider?.removeListener(_onPlayerStateChanged);
    _playerProvider = null;
  }

  void _onPlayerStateChanged() {
    if (_playerProvider == null || _lines.isEmpty) return;

    final position = _playerProvider!.state.position;
    _updateCurrentLine(position);
  }

  void _updateCurrentLine(Duration position) {
    int newIndex = -1;

    for (int i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      final nextLine = i + 1 < _lines.length ? _lines[i + 1] : null;

      final lineEnd = line.endTime ?? nextLine?.startTime ?? line.startTime + const Duration(seconds: 5);

      if (position >= line.startTime && position < lineEnd) {
        newIndex = i;
        break;
      }
    }

    if (newIndex != _currentLineIndex) {
      _currentLineIndex = newIndex;
      notifyListeners();
    }
  }

  // ==================== DOCUMENT MANAGEMENT ====================

  void loadLrcContent(String content, {String? title, String? audioPath}) {
    _document = SyncedDocument.fromLrcContent(
      content,
      title: title,
      audioPath: audioPath,
    );
    _lines = _document!.lines;
    _currentLineIndex = -1;
    notifyListeners();
  }

  void loadSrtContent(String content, {String? title, String? audioPath}) {
    _document = SyncedDocument.fromSrtContent(
      content,
      title: title,
      audioPath: audioPath,
    );
    _lines = _document!.lines;
    _currentLineIndex = -1;
    notifyListeners();
  }

  void loadPlainText(String content, {String? title}) {
    // Tạo synced lines với timestamp tự động (mỗi dòng 3 giây)
    final rawLines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();

    _lines = [];
    for (int i = 0; i < rawLines.length; i++) {
      _lines.add(SyncedLine(
        id: 'plain_$i',
        text: rawLines[i].trim(),
        startTime: Duration(seconds: i * 3),
        endTime: Duration(seconds: (i + 1) * 3),
      ));
    }

    _document = SyncedDocument(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title ?? 'Plain Text',
      lines: _lines,
      createdAt: DateTime.now(),
    );

    _currentLineIndex = -1;
    notifyListeners();
  }

  void clearDocument() {
    _document = null;
    _lines = [];
    _currentLineIndex = -1;
    notifyListeners();
  }

  // ==================== NAVIGATION ====================

  void goToLine(int index) {
    if (index >= 0 && index < _lines.length) {
      _currentLineIndex = index;

      // Seek audio to line start time
      if (_playerProvider != null) {
        _playerProvider!.seek(_lines[index].startTime);
      }

      notifyListeners();
    }
  }

  void goToNextLine() {
    if (_currentLineIndex < _lines.length - 1) {
      goToLine(_currentLineIndex + 1);
    }
  }

  void goToPreviousLine() {
    if (_currentLineIndex > 0) {
      goToLine(_currentLineIndex - 1);
    }
  }

  // ==================== TIMESTAMP EDITING ====================

  void setLineTimestamp(int index, Duration startTime, {Duration? endTime}) {
    if (index >= 0 && index < _lines.length) {
      _lines[index] = _lines[index].copyWith(
        startTime: startTime,
        endTime: endTime,
      );
      notifyListeners();
    }
  }

  void stampCurrentTime(int lineIndex) {
    if (_playerProvider != null && lineIndex >= 0 && lineIndex < _lines.length) {
      final currentPosition = _playerProvider!.state.position;
      setLineTimestamp(lineIndex, currentPosition);
    }
  }

  // ==================== LAYOUT SETTINGS ====================

  void setLayout(SyncLayout layout) {
    _layout = layout;
    notifyListeners();
  }

  void setMusicHeight(double height) {
    _musicHeight = height.clamp(0.2, 0.8);
    notifyListeners();
  }

  void toggleAutoScroll() {
    _autoScroll = !_autoScroll;
    notifyListeners();
  }

  void toggleTimestamps() {
    _showTimestamps = !_showTimestamps;
    notifyListeners();
  }

  void toggleTranslation() {
    _showTranslation = !_showTranslation;
    notifyListeners();
  }

  void setFontSize(double size) {
    _fontSize = size.clamp(12.0, 32.0);
    notifyListeners();
  }

  // ==================== EXPORT ====================

  String exportAsLrc() {
    final buffer = StringBuffer();
    buffer.writeln('[ti:${_document?.title ?? "Untitled"}]');
    buffer.writeln('[ar:VipSound]');
    buffer.writeln('');

    for (final line in _lines) {
      buffer.writeln(line.toLrc());
    }

    return buffer.toString();
  }

  @override
  void dispose() {
    detachPlayer();
    super.dispose();
  }
}