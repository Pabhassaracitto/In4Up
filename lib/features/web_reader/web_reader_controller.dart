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
  final DateTime? lastReadAt;
  final double progress;
  final String preview;

  WebHistoryEntry({
    required this.url,
    required this.title,
    required this.visitedAt,
    this.lastReadAt,
    this.progress = 0,
    this.preview = '',
  });

  DateTime get effectiveReadAt => lastReadAt ?? visitedAt;
  int get progressPercent => (progress.clamp(0.0, 1.0) * 100).round();
  bool get hasMeaningfulProgress => progress >= 0.02 && progress < 0.995;

  WebHistoryEntry copyWith({
    String? url,
    String? title,
    DateTime? visitedAt,
    DateTime? lastReadAt,
    double? progress,
    String? preview,
  }) {
    return WebHistoryEntry(
      url: url ?? this.url,
      title: title ?? this.title,
      visitedAt: visitedAt ?? this.visitedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      progress: progress ?? this.progress,
      preview: preview ?? this.preview,
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'title': title,
        'visitedAt': visitedAt.toIso8601String(),
        'lastReadAt': lastReadAt?.toIso8601String(),
        'progress': progress,
        'preview': preview,
      };

  factory WebHistoryEntry.fromJson(Map<String, dynamic> j) => WebHistoryEntry(
        url: j['url'] ?? '',
        title: j['title'] ?? '',
        visitedAt: DateTime.tryParse(j['visitedAt'] ?? '') ?? DateTime.now(),
        lastReadAt: DateTime.tryParse((j['lastReadAt'] ?? '').toString()),
        progress:
            (((j['progress'] as num?) ?? 0).toDouble()).clamp(0.0, 1.0).toDouble(),
        preview: (j['preview'] ?? '').toString(),
      );
}

class WebReaderController extends ChangeNotifier {
  static const _storageBoxName = 'web_reader_history';
  static const _historyKey = 'history';
  static const _bookmarksKey = 'bookmarks';
  static const _userCollectionsKey = 'user_collections_v1';
  static const _pinnedCollectionIdsKey = 'pinned_collection_ids_v1';
  static const _lastOpenedUrlKey = 'last_opened_url_v1';

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

  String _lastOpenedUrl = '';
  String get lastOpenedUrl => _lastOpenedUrl;

  // ─── Collections ─────────────────────────────────────────
  late final List<WebCollection> _presetCollections = _buildPresetCollections();
  final List<WebCollection> _userCollections = [];
  final Set<String> _pinnedCollectionIds = <String>{};

  List<WebCollection> get presetCollections =>
      List.unmodifiable(_presetCollections);
  List<WebCollection> get userCollections =>
      List.unmodifiable(List<WebCollection>.from(_userCollections)
        ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase())));
  List<WebCollection> get allCollections =>
      List.unmodifiable([...presetCollections, ...userCollections]);
  List<WebCollection> get pinnedCollections => List.unmodifiable(
        allCollections.where((c) => _pinnedCollectionIds.contains(c.id)).toList()
          ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase())),
      );
  bool get hasUserCollections => _userCollections.isNotEmpty;

  WebHistoryEntry? get lastOpenedEntry {
    if (_lastOpenedUrl.trim().isNotEmpty) {
      for (final entry in history) {
        if (entry.url == _lastOpenedUrl) return entry;
      }
    }
    return history.isEmpty ? null : history.first;
  }

  List<WebHistoryEntry> get continueReadingEntries => List.unmodifiable(
        history.where((entry) => entry.hasMeaningfulProgress).toList(),
      );

  List<WebHistoryEntry> get resumeEntries {
    final items = <WebHistoryEntry>[];
    final seen = <String>{};
    final last = lastOpenedEntry;
    if (last != null && seen.add(last.url)) {
      items.add(last);
    }
    for (final entry in continueReadingEntries) {
      if (seen.add(entry.url)) {
        items.add(entry);
      }
    }
    return List.unmodifiable(items);
  }

  WebReaderController() {
    _loadHistory();
    _loadBookmarks();
    _loadUserCollections();
    _loadPinnedCollectionIds();
    _loadLastOpenedUrl();
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

    _rememberLastOpenedUrl(url);
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
    _ttsSpeed = speed.clamp(0.25, 2.0).toDouble();
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

  Future<String?> createOrUpdateUserCollection({
    String? id,
    required String title,
    String description = '',
    String emoji = '📁',
    List<WebCollectionLink> links = const [],
  }) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) return null;

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
    return collection.id;
  }

  Future<void> deleteUserCollection(String collectionId) async {
    _userCollections.removeWhere((c) => c.id == collectionId);
    final removedPinned = _pinnedCollectionIds.remove(collectionId);
    await _saveUserCollections();
    if (removedPinned) {
      await _savePinnedCollectionIds();
    }
    notifyListeners();
  }

  Future<bool> addLinkToUserCollection({
    required String collectionId,
    required String title,
    required String url,
    String note = '',
  }) async {
    final index = _userCollections.indexWhere((c) => c.id == collectionId);
    if (index < 0) return false;

    final normalizedUrl = normalizeUrl(url);
    if (normalizedUrl.isEmpty) return false;

    final existingLinks = List<WebCollectionLink>.from(_userCollections[index].links);
    if (existingLinks.any((link) => normalizeUrl(link.url) == normalizedUrl)) {
      return false;
    }

    final links = existingLinks
      ..add(WebCollectionLink(
        id: _newId('link'),
        title: title.trim().isEmpty ? _safeHost(normalizedUrl) : title.trim(),
        url: normalizedUrl,
        note: note.trim(),
      ));

    _userCollections[index] = _userCollections[index].copyWith(links: links);
    await _saveUserCollections();
    notifyListeners();
    return true;
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

  Future<bool> addCurrentPageToUserCollection(String collectionId) async {
    if (_currentUrl.isEmpty) return false;
    return addLinkToUserCollection(
      collectionId: collectionId,
      title: _pageTitle.isEmpty ? _safeHost(_currentUrl) : _pageTitle,
      url: _currentUrl,
    );
  }

  double progressForUrl(String url) {
    for (final entry in _history.reversed) {
      if (entry.url == url) {
        return entry.progress.clamp(0.0, 1.0).toDouble();
      }
    }
    return 0;
  }

  Future<void> updateReadingProgress({
    required String url,
    required double progress,
    String? title,
    String? preview,
  }) async {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty ||
        normalizedUrl.startsWith('about:') ||
        normalizedUrl.contains('google.com/search')) {
      return;
    }

    final clampedProgress = progress.clamp(0.0, 1.0).toDouble();
    _upsertHistoryEntry(
      url: normalizedUrl,
      title: (title ?? '').trim(),
      progress: clampedProgress,
      preview: preview,
      touchReadTime: true,
      keepHighestProgress: false,
    );
    await _persistHistory();

    final bookmarkIndex = _bookmarks.indexWhere((entry) => entry.url == normalizedUrl);
    if (bookmarkIndex >= 0) {
      final existing = _bookmarks.removeAt(bookmarkIndex);
      _bookmarks.add(
        existing.copyWith(
          title: (title ?? '').trim().isEmpty ? existing.title : title!.trim(),
          lastReadAt: DateTime.now(),
          progress: clampedProgress,
          preview: (preview ?? '').trim().isEmpty ? existing.preview : preview!.trim(),
        ),
      );
      await _persistBookmarks();
    }

    notifyListeners();
  }

  bool isCollectionPinned(String collectionId) =>
      _pinnedCollectionIds.contains(collectionId);

  Future<void> toggleCollectionPin(String collectionId) async {
    if (_pinnedCollectionIds.contains(collectionId)) {
      _pinnedCollectionIds.remove(collectionId);
    } else {
      _pinnedCollectionIds.add(collectionId);
    }
    await _savePinnedCollectionIds();
    notifyListeners();
  }

  // ─── History ─────────────────────────────────────────────

  Future<void> clearHistory() async {
    _history.clear();
    _lastOpenedUrl = '';
    await _persistHistory();
    await _saveLastOpenedUrl();
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

    _upsertHistoryEntry(
      url: url,
      title: title,
      touchReadTime: true,
      keepHighestProgress: true,
    );
    await _persistHistory();
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
      final existingHistory = _findHistoryEntry(_currentUrl);
      _bookmarks.add(
        WebHistoryEntry(
          url: _currentUrl,
          title: _pageTitle,
          visitedAt: existingHistory?.visitedAt ?? DateTime.now(),
          lastReadAt: existingHistory?.effectiveReadAt,
          progress: existingHistory?.progress ?? 0,
          preview: existingHistory?.preview ?? '',
        ),
      );
    }
    await _persistBookmarks();
    notifyListeners();
  }

  WebHistoryEntry? _findHistoryEntry(String url) {
    try {
      return _history.lastWhere((entry) => entry.url == url);
    } catch (_) {
      return null;
    }
  }

  void _upsertHistoryEntry({
    required String url,
    required String title,
    bool touchReadTime = false,
    bool keepHighestProgress = false,
    double? progress,
    String? preview,
  }) {
    final index = _history.indexWhere((entry) => entry.url == url);
    final existing = index >= 0 ? _history.removeAt(index) : null;
    final resolvedTitle = title.trim().isEmpty
        ? (existing?.title ?? _safeHost(url))
        : title.trim();
    final existingProgress = existing?.progress ?? 0;
    final nextProgress = progress == null
        ? existingProgress
        : keepHighestProgress
            ? (existingProgress > progress ? existingProgress : progress)
            : progress;
    final nextPreview = (preview ?? '').trim().isEmpty
        ? (existing?.preview ?? '')
        : preview!.trim();

    _history.add(
      WebHistoryEntry(
        url: url,
        title: resolvedTitle,
        visitedAt: existing?.visitedAt ?? DateTime.now(),
        lastReadAt: touchReadTime ? DateTime.now() : existing?.lastReadAt,
        progress: nextProgress.clamp(0.0, 1.0).toDouble(),
        preview: nextPreview,
      ),
    );

    if (_history.length > 100) {
      _history.removeRange(0, _history.length - 100);
    }
  }

  Future<void> _persistHistory() async {
    try {
      final box = await _getStorageBox();
      await box?.put(
        _historyKey,
        jsonEncode(_history.map((h) => h.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> _persistBookmarks() async {
    try {
      final box = await _getStorageBox();
      await box?.put(
        _bookmarksKey,
        jsonEncode(_bookmarks.map((b) => b.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> _rememberLastOpenedUrl(String url) async {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty ||
        normalizedUrl.startsWith('about:') ||
        normalizedUrl.contains('google.com/search')) {
      return;
    }
    _lastOpenedUrl = normalizedUrl;
    await _saveLastOpenedUrl();
  }

  // ─── Persistence helpers ─────────────────────────────────

  Future<void> _loadPinnedCollectionIds() async {
    try {
      final box = await _getStorageBox();
      final raw = box?.get(_pinnedCollectionIdsKey);
      if (raw == null) return;
      final list = jsonDecode(raw) as List;
      _pinnedCollectionIds
        ..clear()
        ..addAll(list.map((e) => e.toString()).where((e) => e.trim().isNotEmpty));
      notifyListeners();
    } catch (e) {
      debugPrint('WebReaderController: _loadPinnedCollectionIds error: $e');
    }
  }

  Future<void> _savePinnedCollectionIds() async {
    try {
      final box = await _getStorageBox();
      await box?.put(
        _pinnedCollectionIdsKey,
        jsonEncode(_pinnedCollectionIds.toList()),
      );
    } catch (e) {
      debugPrint('WebReaderController: _savePinnedCollectionIds error: $e');
    }
  }

  Future<void> _loadLastOpenedUrl() async {
    try {
      final box = await _getStorageBox();
      _lastOpenedUrl = (box?.get(_lastOpenedUrlKey) ?? '').toString();
      notifyListeners();
    } catch (e) {
      debugPrint('WebReaderController: _loadLastOpenedUrl error: $e');
    }
  }

  Future<void> _saveLastOpenedUrl() async {
    try {
      final box = await _getStorageBox();
      if (_lastOpenedUrl.trim().isEmpty) {
        await box?.delete(_lastOpenedUrlKey);
      } else {
        await box?.put(_lastOpenedUrlKey, _lastOpenedUrl.trim());
      }
    } catch (e) {
      debugPrint('WebReaderController: _saveLastOpenedUrl error: $e');
    }
  }

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
