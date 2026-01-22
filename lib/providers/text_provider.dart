import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/text_item.dart';

class TextProvider extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();

  // Text data
  TextDocument? _currentDocument;
  List<TextItem> _lines = [];
  int _currentLineIndex = -1;
  String? _selectedText;

  // TTS settings
  double _ttsSpeed = 1.0;
  double _ttsPitch = 1.0;
  String _ttsLanguage = 'en-US';
  bool _isSpeaking = false;

  // Display settings
  double _fontSize = 18.0;
  bool _showTranslation = true;
  bool _showWordTypes = false;

  // Getters
  TextDocument? get currentDocument => _currentDocument;
  List<TextItem> get lines => _lines;
  int get currentLineIndex => _currentLineIndex;
  String? get selectedText => _selectedText;
  double get ttsSpeed => _ttsSpeed;
  double get ttsPitch => _ttsPitch;
  String get ttsLanguage => _ttsLanguage;
  bool get isSpeaking => _isSpeaking;
  double get fontSize => _fontSize;
  bool get showTranslation => _showTranslation;
  bool get showWordTypes => _showWordTypes;

  TextProvider() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage(_ttsLanguage);
    await _tts.setSpeechRate(_ttsSpeed);
    await _tts.setPitch(_ttsPitch);
    await _tts.setVolume(1.0);

    _tts.setStartHandler(() {
      _isSpeaking = true;
      notifyListeners();
    });

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      notifyListeners();
    });

    _tts.setCancelHandler(() {
      _isSpeaking = false;
      notifyListeners();
    });

    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
      notifyListeners();
    });
  }

  // ==================== TEXT MANAGEMENT ====================

  void loadText(String content, {String? title}) {
    final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();

    _lines = lines.asMap().entries.map((entry) {
      return TextItem(
        id: 'line_${entry.key}',
        content: entry.value.trim(),
      );
    }).toList();

    _currentDocument = TextDocument(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title ?? 'Untitled',
      lines: _lines,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _currentLineIndex = -1;
    notifyListeners();
  }

  void clearText() {
    _lines = [];
    _currentDocument = null;
    _currentLineIndex = -1;
    _selectedText = null;
    notifyListeners();
  }

  void setCurrentLine(int index) {
    if (index >= 0 && index < _lines.length) {
      _currentLineIndex = index;
      notifyListeners();
    }
  }

  void selectText(String text) {
    _selectedText = text;
    notifyListeners();
  }

  void clearSelection() {
    _selectedText = null;
    notifyListeners();
  }

  // ==================== TTS FUNCTIONS ====================

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> speakCurrentLine() async {
    if (_currentLineIndex >= 0 && _currentLineIndex < _lines.length) {
      await speak(_lines[_currentLineIndex].content);
    }
  }

  Future<void> speakAllLines() async {
    for (int i = 0; i < _lines.length; i++) {
      _currentLineIndex = i;
      notifyListeners();
      await speak(_lines[i].content);
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> speakSelected() async {
    if (_selectedText != null && _selectedText!.isNotEmpty) {
      await speak(_selectedText!);
    }
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    _isSpeaking = false;
    notifyListeners();
  }

  Future<void> setTtsSpeed(double speed) async {
    _ttsSpeed = speed.clamp(0.1, 2.0);
    await _tts.setSpeechRate(_ttsSpeed);
    notifyListeners();
  }

  Future<void> setTtsPitch(double pitch) async {
    _ttsPitch = pitch.clamp(0.5, 2.0);
    await _tts.setPitch(_ttsPitch);
    notifyListeners();
  }

  Future<void> setTtsLanguage(String language) async {
    _ttsLanguage = language;
    await _tts.setLanguage(language);
    notifyListeners();
  }

  // ==================== DISPLAY SETTINGS ====================

  void setFontSize(double size) {
    _fontSize = size.clamp(12.0, 32.0);
    notifyListeners();
  }

  void toggleTranslation() {
    _showTranslation = !_showTranslation;
    notifyListeners();
  }

  void toggleWordTypes() {
    _showWordTypes = !_showWordTypes;
    notifyListeners();
  }

  // ==================== DIFFICULTY MARKING ====================

  void markLineDifficulty(int lineIndex, DifficultyMark difficulty) {
    if (lineIndex >= 0 && lineIndex < _lines.length) {
      // Tạo line mới với các words được đánh dấu
      final line = _lines[lineIndex];
      final words = line.content.split(' ').map((word) {
        return WordItem(word: word, difficulty: difficulty);
      }).toList();

      _lines[lineIndex] = line.copyWith(words: words);
      notifyListeners();
    }
  }

  void markSelectedDifficulty(DifficultyMark difficulty) {
    if (_selectedText == null) return;
    // Lưu vào danh sách điểm mù để ôn tập sau
    notifyListeners();
  }

  // ==================== SYNC WITH AUDIO ====================

  void syncWithAudioPosition(Duration position) {
    // Tìm line tương ứng với vị trí audio
    for (int i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      if (line.startTime != null && line.endTime != null) {
        if (position >= line.startTime! && position <= line.endTime!) {
          if (_currentLineIndex != i) {
            _currentLineIndex = i;
            notifyListeners();
          }
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}