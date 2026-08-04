import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../features/tts/tts_service.dart';
import '../../models/color_mode.dart';
import '../../models/word_analysis.dart';
import '../../providers/vocabulary_bridge.dart';
import '../../screens/memory_mode/memory_provider.dart';
import '../../services/syntax_highlighter_service.dart';
import 'models/web_collection.dart';

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
  static const _storageBoxName = 'web_reader_history';
  static const _historyKey = 'history';
  static const _bookmarksKey = 'bookmarks';
  static const _userCollectionsKey = 'user_collections_v1';

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

  // ─── History / Bookmarks ─────────────────────────────────
  final List<WebHistoryEntry> _history = [];
  List<WebHistoryEntry> get history =>
      List.unmodifiable(_history.reversed.toList());

  final List<WebHistoryEntry> _bookmarks = [];
  List<WebHistoryEntry> get bookmarks =>
      List.unmodifiable(_bookmarks.reversed.toList());

  // ─── Collections ─────────────────────────────────────────
  late final List<WebCollection> _presetCollections = _buildPresetCollections();
  final List<WebCollection> _userCollections = [];

  List<WebCollection> get presetCollections =>
      List.unmodifiable(_presetCollections);
  List<WebCollection> get userCollections =>
      List.unmodifiable(List<WebCollection>.from(_userCollections)
        ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase())));
  List<WebCollection> get allCollections =>
      List.unmodifiable([...presetCollections, ...userCollections]);

  WebReaderController() {
    _loadHistory();
    _loadBookmarks();
    _loadUserCollections();
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
    _pageTitle = title.isNotEmpty ? title : _safeHost(url);
    _state = WebReaderState.ready;
    _loadingProgress = 1.0;
    notifyListeners();

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
    final cefrMap = <String, String>{};
    for (final entry in SyntaxHighlighterService.cefrDictionary.entries) {
      cefrMap[entry.key] = entry.value.name;
    }

    final config = {
      'mode': _colorMode.name,
      'cefrDictionary': cefrMap,
      'colors': {
        'cefr': {
          'a1': '#78909C',
          'a2': '#42A5F5',
          'b1': '#66BB6A',
          'b2': '#FFCA28',
          'c1': '#FF7043',
          'c2': '#EF5350',
          'unknown': 'transparent',
        },
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

    VocabularyBridge.addFromAnalyzed(
      word: clean,
      meaning: analyzed?.meaning,
      phonetic: analyzed?.phonetic,
      wordTypeName: analyzed?.wordType.name,
      cefrLevelName: analyzed?.cefrLevel.name,
      sourceFile: _safeHost(_currentUrl),
    );

    MemoryProvider.addWord(
      word: clean,
      wordType: analyzed?.wordType.name,
      cefrLevel: analyzed?.cefrLevel.name,
      meaning: analyzed?.meaning,
      sourceFile: _safeHost(_currentUrl),
    );
  }

  // ─── Collections ─────────────────────────────────────────

  Future<void> createOrUpdateUserCollection({
    String? id,
    required String title,
    String description = '',
    String emoji = '📁',
    List<WebCollectionLink> links = const [],
  }) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) return;

    final normalizedDescription = description.trim();
    final normalizedEmoji = emoji.trim().isEmpty ? '📁' : emoji.trim();
    final normalizedLinks = _normalizeLinks(links);
    final existingIndex =
        id == null ? -1 : _userCollections.indexWhere((c) => c.id == id);

    final collection = WebCollection(
      id: existingIndex >= 0 ? _userCollections[existingIndex].id : _newId('col'),
      title: normalizedTitle,
      description: normalizedDescription,
      emoji: normalizedEmoji,
      isPreset: false,
      links: normalizedLinks,
    );

    if (existingIndex >= 0) {
      _userCollections[existingIndex] = collection;
    } else {
      _userCollections.add(collection);
    }

    await _saveUserCollections();
    notifyListeners();
  }

  Future<void> deleteUserCollection(String collectionId) async {
    _userCollections.removeWhere((c) => c.id == collectionId);
    await _saveUserCollections();
    notifyListeners();
  }

  Future<void> addLinkToUserCollection({
    required String collectionId,
    required String title,
    required String url,
    String note = '',
  }) async {
    final index = _userCollections.indexWhere((c) => c.id == collectionId);
    if (index < 0) return;

    final normalizedUrl = normalizeUrl(url);
    if (normalizedUrl.isEmpty) return;

    final links = List<WebCollectionLink>.from(_userCollections[index].links)
      ..add(WebCollectionLink(
        id: _newId('link'),
        title: title.trim().isEmpty ? _safeHost(normalizedUrl) : title.trim(),
        url: normalizedUrl,
        note: note.trim(),
      ));

    _userCollections[index] = _userCollections[index].copyWith(links: links);
    await _saveUserCollections();
    notifyListeners();
  }

  Future<void> removeLinkFromUserCollection({
    required String collectionId,
    required String linkId,
  }) async {
    final index = _userCollections.indexWhere((c) => c.id == collectionId);
    if (index < 0) return;

    final links = List<WebCollectionLink>.from(_userCollections[index].links)
      ..removeWhere((link) => link.id == linkId);

    _userCollections[index] = _userCollections[index].copyWith(links: links);
    await _saveUserCollections();
    notifyListeners();
  }

  Future<void> addCurrentPageToUserCollection(String collectionId) async {
    if (_currentUrl.isEmpty) return;
    await addLinkToUserCollection(
      collectionId: collectionId,
      title: _pageTitle.isEmpty ? _safeHost(_currentUrl) : _pageTitle,
      url: _currentUrl,
    );
  }

  // ─── History ─────────────────────────────────────────────

  Future<void> clearHistory() async {
    _history.clear();
    final box = await _getStorageBox();
    await box?.put(_historyKey, jsonEncode(const []));
    notifyListeners();
  }

  Future<void> _loadHistory() async {
    try {
      final box = await _getStorageBox();
      final raw = box?.get(_historyKey);
      if (raw == null) return;
      final list = jsonDecode(raw) as List;
      _history
        ..clear()
        ..addAll(list.map((e) =>
            WebHistoryEntry.fromJson(Map<String, dynamic>.from(e as Map))));
      notifyListeners();
    } catch (e) {
      debugPrint('WebReaderController: _loadHistory error: $e');
    }
  }

  Future<void> _addToHistory(String url, String title) async {
    if (url.startsWith('about:') ||
        url.contains('google.com/search') ||
        url.isEmpty) {
      return;
    }

    _history.removeWhere((h) => h.url == url);
    _history.add(
      WebHistoryEntry(url: url, title: title, visitedAt: DateTime.now()),
    );

    if (_history.length > 100) {
      _history.removeRange(0, _history.length - 100);
    }

    try {
      final box = await _getStorageBox();
      await box?.put(
        _historyKey,
        jsonEncode(_history.map((h) => h.toJson()).toList()),
      );
    } catch (_) {}

    notifyListeners();
  }

  // ─── Bookmarks ────────────────────────────────────────────

  Future<void> _loadBookmarks() async {
    try {
      final box = await _getStorageBox();
      final raw = box?.get(_bookmarksKey);
      if (raw == null) return;
      final list = jsonDecode(raw) as List;
      _bookmarks
        ..clear()
        ..addAll(list.map((e) =>
            WebHistoryEntry.fromJson(Map<String, dynamic>.from(e as Map))));
      notifyListeners();
    } catch (_) {}
  }

  bool isBookmarked(String url) => _bookmarks.any((b) => b.url == url);

  Future<void> toggleBookmark() async {
    if (_currentUrl.isEmpty) return;
    if (isBookmarked(_currentUrl)) {
      _bookmarks.removeWhere((b) => b.url == _currentUrl);
    } else {
      _bookmarks.add(
        WebHistoryEntry(
          url: _currentUrl,
          title: _pageTitle,
          visitedAt: DateTime.now(),
        ),
      );
    }
    try {
      final box = await _getStorageBox();
      await box?.put(
        _bookmarksKey,
        jsonEncode(_bookmarks.map((b) => b.toJson()).toList()),
      );
    } catch (_) {}
    notifyListeners();
  }

  // ─── Persistence helpers ─────────────────────────────────

  Future<void> _loadUserCollections() async {
    try {
      final box = await _getStorageBox();
      final raw = box?.get(_userCollectionsKey);
      if (raw == null) return;
      final list = jsonDecode(raw) as List;
      _userCollections
        ..clear()
        ..addAll(list.map((e) =>
            WebCollection.fromJson(Map<String, dynamic>.from(e as Map))));
      notifyListeners();
    } catch (e) {
      debugPrint('WebReaderController: _loadUserCollections error: $e');
    }
  }

  Future<void> _saveUserCollections() async {
    try {
      final box = await _getStorageBox();
      await box?.put(
        _userCollectionsKey,
        jsonEncode(_userCollections.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('WebReaderController: _saveUserCollections error: $e');
    }
  }

  Future<Box<String>?> _getStorageBox() async {
    try {
      if (Hive.isBoxOpen(_storageBoxName)) {
        return Hive.box<String>(_storageBoxName);
      }
      return await Hive.openBox<String>(_storageBoxName);
    } catch (e) {
      debugPrint('WebReaderController: open box error: $e');
      return null;
    }
  }

  List<WebCollection> _buildPresetCollections() {
    return const [
      WebCollection(
        id: 'preset-dharma',
        title: 'Pháp thoại & Dharma',
        description:
            'Nguồn đọc cố định cho Phật học, thiền và pháp thoại tiếng Anh.',
        emoji: '🪷',
        isPreset: true,
        links: [
          WebCollectionLink(
            id: 'dharma-1',
            title: 'SuttaCentral',
            url: 'https://suttacentral.net/',
            note: 'Kinh tạng và bản dịch đa ngôn ngữ.',
          ),
          WebCollectionLink(
            id: 'dharma-2',
            title: 'Dhammatalks',
            url: 'https://www.dhammatalks.org/',
            note: 'Bài đọc và pháp thoại của Thanissaro Bhikkhu.',
          ),
          WebCollectionLink(
            id: 'dharma-3',
            title: 'Access to Insight',
            url: 'https://www.accesstoinsight.org/',
            note: 'Kho bài đọc Phật pháp tiếng Anh lâu năm.',
          ),
          WebCollectionLink(
            id: 'dharma-4',
            title: 'Tricycle',
            url: 'https://tricycle.org/',
            note: 'Tạp chí Phật học và thực hành hiện đại.',
          ),
        ],
      ),
      WebCollection(
        id: 'preset-english',
        title: 'English Learning',
        description:
            'Nguồn đọc chậm, rõ, phù hợp để luyện từ vựng và đọc hiểu.',
        emoji: '🇬🇧',
        isPreset: true,
        links: [
          WebCollectionLink(
            id: 'english-1',
            title: 'BBC Learning English',
            url: 'https://www.bbc.co.uk/learningenglish/',
            note: 'Bài học và tin tức dành cho người học tiếng Anh.',
          ),
          WebCollectionLink(
            id: 'english-2',
            title: 'VOA Learning English',
            url: 'https://learningenglish.voanews.com/',
            note: 'Tin tức tốc độ chậm, dễ học.',
          ),
          WebCollectionLink(
            id: 'english-3',
            title: 'British Council',
            url: 'https://learnenglish.britishcouncil.org/',
            note: 'Bài đọc và hoạt động ngôn ngữ theo cấp độ.',
          ),
          WebCollectionLink(
            id: 'english-4',
            title: 'Simple English Wikipedia',
            url: 'https://simple.wikipedia.org/',
            note: 'Kiến thức phổ thông với từ vựng đơn giản hơn.',
          ),
        ],
      ),
      WebCollection(
        id: 'preset-news-knowledge',
        title: 'Tin tức & Kiến thức',
        description:
            'Giữ lại các nguồn preset cũ và mở rộng thêm nơi đọc chung.',
        emoji: '📰',
        isPreset: true,
        links: [
          WebCollectionLink(
            id: 'news-1',
            title: 'BBC News',
            url: 'https://www.bbc.com/news',
          ),
          WebCollectionLink(
            id: 'news-2',
            title: 'Wikipedia',
            url: 'https://en.wikipedia.org',
          ),
          WebCollectionLink(
            id: 'news-3',
            title: 'CNN',
            url: 'https://edition.cnn.com',
          ),
          WebCollectionLink(
            id: 'news-4',
            title: 'Medium',
            url: 'https://medium.com',
          ),
          WebCollectionLink(
            id: 'news-5',
            title: 'The Guardian',
            url: 'https://www.theguardian.com',
          ),
          WebCollectionLink(
            id: 'news-6',
            title: 'Reuters',
            url: 'https://www.reuters.com',
          ),
        ],
      ),
    ];
  }

  List<WebCollectionLink> _normalizeLinks(List<WebCollectionLink> links) {
    final result = <WebCollectionLink>[];
    final seenUrls = <String>{};
    for (final link in links) {
      final url = normalizeUrl(link.url);
      if (url.isEmpty || !seenUrls.add(url)) continue;
      result.add(
        link.copyWith(
          id: link.id.trim().isEmpty ? _newId('link') : link.id,
          title: link.title.trim().isEmpty ? _safeHost(url) : link.title.trim(),
          url: url,
          note: link.note.trim(),
        ),
      );
    }
    return result;
  }

  String _newId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  String _safeHost(String url) {
    try {
      final host = Uri.parse(url).host.trim();
      return host.isEmpty ? url : host;
    } catch (_) {
      return url;
    }
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}
