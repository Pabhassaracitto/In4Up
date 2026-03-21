import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../features/tts/tts_service.dart';
import '../../models/color_mode.dart';
import '../../models/word_analysis.dart';
import '../../providers/vocabulary_bridge.dart';
import '../../screens/memory_mode/memory_provider.dart';
import '../../services/syntax_highlighter_service.dart';

enum WebReaderState { idle, loading, ready, error }

/// Một trang đã lưu vào lịch sử
class WebHistoryEntry {
  final String url;
  final String title;
  final DateTime visitedAt;

  WebHistoryEntry({
    required this.url,
    required this.title,
    required this.visitedAt,
  });

  Map<String, dynamic> toJson() => {
        'url': url,
        'title': title,
        'visitedAt': visitedAt.toIso8601String(),
      };

  factory WebHistoryEntry.fromJson(Map<String, dynamic> j) => WebHistoryEntry(
        url: j['url'] ?? '',
        title: j['title'] ?? '',
        visitedAt: DateTime.tryParse(j['visitedAt'] ?? '') ?? DateTime.now(),
      );
}

class WebReaderController extends ChangeNotifier {
  // ─── State ────────────────────────────────────────────────
  WebReaderState _state = WebReaderState.idle;
  WebReaderState get state => _state;

  String _currentUrl = '';
  String get currentUrl => _currentUrl;

  String _pageTitle = '';
  String get pageTitle => _pageTitle;

  bool _canGoBack = false;
  bool get canGoBack => _canGoBack;

  bool _canGoForward = false;
  bool get canGoForward => _canGoForward;

  double _loadingProgress = 0;
  double get loadingProgress => _loadingProgress;

  // ─── Color Mode ───────────────────────────────────────────
  ColorMode _colorMode = ColorMode.none;
  ColorMode get colorMode => _colorMode;
  bool get isHighlightActive => _colorMode != ColorMode.none;

  // ─── Word tap ────────────────────────────────────────────
  AnalyzedWord? _tappedWord;
  AnalyzedWord? get tappedWord => _tappedWord;
  String? _tappedWordRaw;
  String? get tappedWordRaw => _tappedWordRaw;

  // ─── Selected text ───────────────────────────────────────
  String? _selectedText;
  String? get selectedText => _selectedText;

  // ─── TTS ────────────────────────────────────────────────
  final TtsService _tts = TtsService();
  bool _isSpeaking = false;
  bool get isSpeaking => _isSpeaking;
  double _ttsSpeed = 0.9;
  double get ttsSpeed => _ttsSpeed;

  // ─── History ─────────────────────────────────────────────
  static const _historyBoxName = 'web_reader_history';
  final List<WebHistoryEntry> _history = [];
  List<WebHistoryEntry> get history =>
      List.unmodifiable(_history.reversed.toList());

  // ─── Bookmarks ───────────────────────────────────────────
  final List<WebHistoryEntry> _bookmarks = [];
  List<WebHistoryEntry> get bookmarks => List.unmodifiable(_bookmarks);

  WebReaderController() {
    _loadHistory();
    _loadBookmarks();
  }

  // ─── URL Navigation ──────────────────────────────────────

  /// Normalize URL: thêm https:// nếu thiếu scheme
  static String normalizeUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    // Nếu trông như domain: example.com → https://example.com
    if (trimmed.contains('.') && !trimmed.contains(' ')) {
      return 'https://$trimmed';
    }
    // Nếu là search query → Google
    final encoded = Uri.encodeComponent(trimmed);
    return 'https://www.google.com/search?q=$encoded';
  }

  // ─── Page callbacks (gọi từ WebView) ─────────────────────

  void onPageStarted(String url) {
    _currentUrl = url;
    _state = WebReaderState.loading;
    _loadingProgress = 0.1;
    notifyListeners();
  }

  void onProgress(int progress) {
    _loadingProgress = progress / 100.0;
    notifyListeners();
  }

  void onPageFinished(String url, String title) {
    _currentUrl = url;
    _pageTitle = title.isNotEmpty ? title : Uri.parse(url).host;
    _state = WebReaderState.ready;
    _loadingProgress = 1.0;
    notifyListeners();

    // Lưu lịch sử
    _addToHistory(url, _pageTitle);
  }

  void onNavigationStateChange({
    required bool canGoBack,
    required bool canGoForward,
  }) {
    _canGoBack = canGoBack;
    _canGoForward = canGoForward;
    notifyListeners();
  }

  void onError(String message) {
    _state = WebReaderState.error;
    notifyListeners();
  }

  // ─── Color Mode ──────────────────────────────────────────

  void setColorMode(ColorMode mode) {
    _colorMode = mode;
    notifyListeners();
  }

  void cycleColorMode() {
    _colorMode = _colorMode.next;
    notifyListeners();
  }

  // ─── JavaScript data processing ──────────────────────────

  /// Nhận từ bị tap từ JS bridge
  void onWordTapped(String word) {
    _tappedWordRaw = word;
    final clean = word.toLowerCase().replaceAll(RegExp(r"[^\w']"), '');
    if (clean.isEmpty) return;

    final analyzed = SyntaxHighlighterService.instance.analyzeWord(clean);
    _tappedWord = analyzed;
    notifyListeners();
  }

  void clearTappedWord() {
    _tappedWord = null;
    _tappedWordRaw = null;
    notifyListeners();
  }

  void onTextSelected(String text) {
    _selectedText = text.trim();
    notifyListeners();
  }

  void clearSelection() {
    _selectedText = null;
    notifyListeners();
  }

  /// Build JSON dùng để inject vào JavaScript
  /// Chứa CEFR dictionary + color map theo ColorMode hiện tại
  String buildHighlightConfig() {
    // Serialize CEFR dictionary nhỏ
    final cefrMap = <String, String>{};
    for (final entry in SyntaxHighlighterService.cefrDictionary.entries) {
      cefrMap[entry.key] = entry.value.name; // 'a1', 'a2', ...
    }

    final config = {
      'mode': _colorMode.name, // 'none', 'wordType', 'cefrLevel'
      'cefrDictionary': cefrMap,
      'colors': {
        // CEFR colors
        'cefr': {
          'a1': '#78909C',
          'a2': '#42A5F5',
          'b1': '#66BB6A',
          'b2': '#FFCA28',
          'c1': '#FF7043',
          'c2': '#EF5350',
          'unknown': 'transparent',
        },
        // Word type colors
        'wordType': {
          'noun': '#42A5F5',
          'verb': '#EF5350',
          'adjective': '#66BB6A',
          'adverb': '#FFCA28',
          'preposition': '#AB47BC',
          'conjunction': '#26C6DA',
          'pronoun': '#FF7043',
          'determiner': '#78909C',
          'unknown': 'transparent',
        },
      },
      // Heuristic rules (suffix-based) cho từ không có trong dict
      'suffixes': {
        'verb': ['ing', 'ed', 'ify', 'ate', 'ize', 'ise'],
        'adverb': ['ly'],
        'adjective': ['ful', 'less', 'ous', 'able', 'ible', 'ive'],
        'noun': ['tion', 'ment', 'ness', 'ity', 'ance', 'ence'],
      },
    };

    return jsonEncode(config);
  }

  // ─── TTS ─────────────────────────────────────────────────

  Future<void> speakWord(String word) async {
    _tts.configure(speed: _ttsSpeed, language: 'en-US');
    _isSpeaking = true;
    notifyListeners();
    await _tts.speak(word);
    _isSpeaking = false;
    notifyListeners();
  }

  Future<void> speakText(String text) async {
    _tts.configure(speed: _ttsSpeed, language: 'en-US');
    _isSpeaking = true;
    notifyListeners();
    await _tts.speak(text);
    _isSpeaking = false;
    notifyListeners();
  }

  Future<void> stopTts() async {
    await _tts.stop();
    _isSpeaking = false;
    notifyListeners();
  }

  void setTtsSpeed(double speed) {
    _ttsSpeed = speed.clamp(0.25, 2.0);
    _tts.configure(speed: _ttsSpeed);
    notifyListeners();
  }

  // ─── Save to Memory ──────────────────────────────────────

  void saveWordToMemory(String word, {AnalyzedWord? analyzed}) {
    final clean = word.trim().toLowerCase();
    if (clean.isEmpty) return;

    // ★ Bridge → VocabularyProvider (hệ thống chung)
    VocabularyBridge.addFromAnalyzed(
      word: clean,
      meaning: analyzed?.meaning,
      phonetic: analyzed?.phonetic,
      wordTypeName: analyzed?.wordType.name,
      cefrLevelName: analyzed?.cefrLevel.name,
      sourceFile: Uri.parse(_currentUrl).host,
    );

    MemoryProvider.addWord(
      word: clean,
      wordType: analyzed?.wordType.name,
      cefrLevel: analyzed?.cefrLevel.name,
      meaning: analyzed?.meaning,
      sourceFile: Uri.parse(_currentUrl).host,
    );
  }

  // ─── History ─────────────────────────────────────────────

  Future<void> _loadHistory() async {
    try {
      if (!Hive.isBoxOpen(_historyBoxName)) return;
      final box = Hive.box<String>(_historyBoxName);
      final raw = box.get('history');
      if (raw == null) return;
      final list = jsonDecode(raw) as List;
      _history.addAll(
          list.map((e) => WebHistoryEntry.fromJson(e as Map<String, dynamic>)));
      notifyListeners();
    } catch (e) {
      debugPrint('WebReaderController: _loadHistory error: $e');
    }
  }

  Future<void> _addToHistory(String url, String title) async {
    // Skip google search results, about:blank, etc.
    if (url.startsWith('about:') ||
        url.contains('google.com/search') ||
        url.isEmpty) {
      return;
    }

    _history.removeWhere((h) => h.url == url);
    _history.add(
        WebHistoryEntry(url: url, title: title, visitedAt: DateTime.now()));

    // Keep max 100
    if (_history.length > 100) {
      _history.removeRange(0, _history.length - 100);
    }

    try {
      if (!Hive.isBoxOpen(_historyBoxName)) return;
      final box = Hive.box<String>(_historyBoxName);
      await box.put(
          'history', jsonEncode(_history.map((h) => h.toJson()).toList()));
    } catch (_) {}

    notifyListeners();
  }

  // ─── Bookmarks ────────────────────────────────────────────

  Future<void> _loadBookmarks() async {
    try {
      if (!Hive.isBoxOpen(_historyBoxName)) return;
      final box = Hive.box<String>(_historyBoxName);
      final raw = box.get('bookmarks');
      if (raw == null) return;
      final list = jsonDecode(raw) as List;
      _bookmarks.addAll(
          list.map((e) => WebHistoryEntry.fromJson(e as Map<String, dynamic>)));
      notifyListeners();
    } catch (_) {}
  }

  bool isBookmarked(String url) => _bookmarks.any((b) => b.url == url);

  Future<void> toggleBookmark() async {
    if (_currentUrl.isEmpty) return;
    if (isBookmarked(_currentUrl)) {
      _bookmarks.removeWhere((b) => b.url == _currentUrl);
    } else {
      _bookmarks.add(WebHistoryEntry(
          url: _currentUrl, title: _pageTitle, visitedAt: DateTime.now()));
    }
    try {
      if (!Hive.isBoxOpen(_historyBoxName)) return;
      final box = Hive.box<String>(_historyBoxName);
      await box.put(
          'bookmarks', jsonEncode(_bookmarks.map((b) => b.toJson()).toList()));
    } catch (_) {}
    notifyListeners();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}
