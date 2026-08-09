import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:in2up_core/vocab_level_difficulty.dart';

import '../../features/grammar/models/grammar_category.dart';
import '../../features/grammar/models/grammar_highlight_preset.dart';
import '../../features/grammar/models/grammar_highlight_settings.dart';
import '../../features/grammar/models/grammar_highlight_style.dart';
import '../../features/grammar/models/grammar_palette.dart';
import '../../features/grammar/services/grammar_preset_library_service.dart';
import '../../features/grammar/services/grammar_settings_service.dart';
import '../../features/tts/tts_service.dart';
import '../../models/color_mode.dart';
import '../../models/vocab_context.dart';
import '../../models/vocabulary_type.dart';
import '../../models/word_analysis.dart';
import '../../providers/vocabulary_bridge.dart';
import '../../screens/memory_mode/memory_provider.dart';
import '../../services/syntax_highlighter_service.dart';
import 'models/web_collection.dart';
import 'models/web_extraction_candidate.dart';

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
  static const _pinnedArticleUrlsKey = 'pinned_article_urls_v1';
  static const _articleNotesKey = 'article_notes_v1';
  static const _batchDraftsKey = 'web_batch_drafts_v1';
  static const _lastOpenedUrlKey = 'last_opened_url_v1';
  static final RegExp _wordRegex = RegExp(r"[A-Za-z][A-Za-z'-]{1,}");
  static const Set<String> _webBatchStopWords = {
    'about', 'above', 'after', 'again', 'against', 'almost', 'along', 'also',
    'among', 'amongst', 'because', 'before', 'below', 'beneath', 'between',
    'beyond', 'could', 'doing', 'during', 'every', 'first', 'from', 'have',
    'having', 'into', 'itself', 'just', 'might', 'must', 'other', 'ought',
    'ours', 'ourselves', 'over', 'quite', 'rather', 'should', 'since',
    'still', 'such', 'than', 'that', 'their', 'theirs', 'them', 'themselves',
    'there', 'these', 'they', 'this', 'those', 'through', 'toward', 'towards',
    'under', 'until', 'very', 'what', 'when', 'where', 'which', 'while',
    'with', 'within', 'without', 'would', 'your', 'yours', 'yourself',
    'yourselves', 'onto', 'upon', 'were', 'been', 'being', 'does',
    'did', 'done', 'then', 'here', 'therefore', 'however', 'across',
    'beforehand', 'cannot', 'couldn', 'didn', 'doesn', 'hadn', 'hasn', 'haven',
    'isn', 'aren', 'wasn', 'weren', 'won', 'wouldn', 'shan', 'shouldn', 'the',
    'and', 'for', 'are', 'you', 'our', 'but', 'not', 'can', 'all', 'any',
    'why', 'who', 'how', 'out', 'its', "it's", 'his', 'her', 'she', 'him',
    'was', 'has', 'had', 'let', 'may', 'use', 'used', 'using', 'many', 'much',
    'more', 'most', 'some', 'same', 'each', 'only', 'both', 'few', 'ever',
    'even', 'well', 'back', 'gets', 'get', 'got', 'make', 'made', 'take',
    'took', 'come', 'came', 'goes', 'went', 'go', 'said', 'says', 'say',
    'look', 'looks', 'looking', 'know', 'knows', 'known', 'like', 'liked',
    'whose', 'whom', 'mine', 'myself', 'himself', 'herself', 'it', 'a', 'an',
    'to', 'of', 'in', 'on', 'at', 'by', 'or', 'if', 'be', 'is', 'am', 'as',
    'we', 'he', 'do', 'my', 'me', 'i'
  };

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
  GrammarHighlightSettings _grammarSettings =
      GrammarHighlightSettings.defaults();
  List<GrammarHighlightPreset> _availableGrammarPresets =
      GrammarHighlightPresets.defaults();
  int _highlightVersion = 0;
  ColorMode get colorMode => _colorMode;
  bool get isHighlightActive => _colorMode != ColorMode.none;
  int get highlightVersion => _highlightVersion;
  GrammarHighlightSettings get grammarSettings => _grammarSettings;
  List<GrammarHighlightPreset> get availableGrammarPresets =>
      List.unmodifiable(_availableGrammarPresets);
  GrammarPalette get activeGrammarPalette =>
      GrammarPalettes.byId(_grammarSettings.paletteId);
  GrammarHighlightPreset get activeGrammarPreset =>
      _findGrammarPresetById(_grammarSettings.activePresetId);

  // ─── Word tap ────────────────────────────────────────────
  AnalyzedWord? _tappedWord;
  AnalyzedWord? get tappedWord => _tappedWord;
  String? _tappedWordRaw;
  String? get tappedWordRaw => _tappedWordRaw;

  // ─── Selected text ───────────────────────────────────────
  String? _selectedText;
  String? get selectedText => _selectedText;
  String? _selectedContextText;
  double? _selectedScrollProgress;
  String? _tappedWordContextText;
  double? _tappedWordScrollProgress;

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
  final Set<String> _pinnedArticleUrls = <String>{};
  final Map<String, String> _articleNotes = <String, String>{};
  final List<WebExtractionDraft> _batchDrafts = [];

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

  List<WebHistoryEntry> get completedEntries => List.unmodifiable(
        history.where((entry) => entry.progress >= 0.98).toList(),
      );

  List<WebHistoryEntry> get recentEntries => List.unmodifiable(
        history.where((entry) {
          final diff = DateTime.now().difference(entry.effectiveReadAt);
          return diff.inHours < 48;
        }).toList(),
      );

  List<WebHistoryEntry> get pinnedArticleEntries =>
      List.unmodifiable(_entriesForUrls(_pinnedArticleUrls));

  List<WebHistoryEntry> get notedEntries =>
      List.unmodifiable(_entriesForUrls(_articleNotes.keys));

  List<WebExtractionDraft> get batchDrafts => List.unmodifiable(
        List<WebExtractionDraft>.from(_batchDrafts)
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
      );

  int get articleNoteCount => _articleNotes.length;
  int get batchDraftCount => _batchDrafts.length;

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
    _loadPinnedArticleUrls();
    _loadArticleNotes();
    _loadBatchDrafts();
    _loadLastOpenedUrl();
    _loadGrammarPresetLibrary();
    _loadGrammarSettings();
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

  GrammarHighlightPreset _findGrammarPresetById(String? presetId) {
    for (final preset in _availableGrammarPresets) {
      if (preset.id == presetId) return preset;
    }
    return GrammarHighlightPresets.byId(presetId);
  }

  Future<void> _loadGrammarPresetLibrary() async {
    try {
      _availableGrammarPresets = await GrammarPresetLibraryService.loadAllPresets();
      _highlightVersion++;
      notifyListeners();
    } catch (e) {
      debugPrint('WebReaderController: _loadGrammarPresetLibrary error: $e');
    }
  }

  Future<void> _refreshGrammarPresetLibrary() async {
    _availableGrammarPresets = await GrammarPresetLibraryService.loadAllPresets();
    _highlightVersion++;
    notifyListeners();
  }

  Future<void> refreshGrammarPresetLibrary() {
    return _refreshGrammarPresetLibrary();
  }

  Future<void> _loadGrammarSettings() async {
    try {
      _grammarSettings = await GrammarSettingsService.load();
      _highlightVersion++;
      notifyListeners();
    } catch (e) {
      debugPrint('WebReaderController: _loadGrammarSettings error: $e');
    }
  }

  Future<void> _saveGrammarSettings() async {
    try {
      await GrammarSettingsService.save(_grammarSettings);
    } catch (e) {
      debugPrint('WebReaderController: _saveGrammarSettings error: $e');
    }
  }

  Future<void> setGrammarSettings(GrammarHighlightSettings settings) async {
    _grammarSettings = settings;
    _highlightVersion++;
    notifyListeners();
    await _saveGrammarSettings();
  }

  Future<void> setGrammarHighlightEnabled(bool enabled) {
    return setGrammarSettings(_grammarSettings.copyWith(enabled: enabled));
  }

  Future<void> applyGrammarPreset(String presetId) {
    final preset = _findGrammarPresetById(presetId);
    return setGrammarSettings(_grammarSettings.applyPreset(preset));
  }

  Future<void> restorePreviousGrammarPreset() {
    final preset = _findGrammarPresetById(_grammarSettings.lastNonCustomPresetId);
    return setGrammarSettings(_grammarSettings.applyPreset(preset));
  }

  Future<GrammarHighlightPreset> saveCurrentGrammarPreset({
    required String name,
    String description = '',
  }) async {
    final saved = await GrammarPresetLibraryService.savePreset(
      name: name,
      description: description,
      settings: _grammarSettings,
    );
    await _refreshGrammarPresetLibrary();
    await setGrammarSettings(_grammarSettings.applyPreset(saved));
    return saved;
  }

  Future<void> setGrammarAdvancedControls(bool value) {
    return setGrammarSettings(
      _grammarSettings.copyWith(showAdvancedControls: value),
    );
  }

  Future<void> setGrammarPalette(String paletteId) {
    return setGrammarSettings(_grammarSettings.copyWith(paletteId: paletteId));
  }

  Future<void> setGrammarHighlightStyle(GrammarHighlightStyle style) {
    return setGrammarSettings(_grammarSettings.copyWith(highlightStyle: style));
  }

  Future<void> toggleGrammarCategory(GrammarCategory category) {
    final next = Set<GrammarCategory>.from(_grammarSettings.visibleCategories);
    if (next.contains(category)) {
      next.remove(category);
    } else {
      next.add(category);
    }
    return setGrammarSettings(
      _grammarSettings.copyWith(activePresetId: 'custom', visibleCategories: next),
    );
  }

  Future<void> showAllGrammarCategories() {
    return setGrammarSettings(
      _grammarSettings.copyWith(
        activePresetId: 'custom',
        visibleCategories: Set<GrammarCategory>.from(GrammarCategory.values),
      ),
    );
  }

  Future<void> setGrammarLegendVisible(bool visible) {
    return setGrammarSettings(_grammarSettings.copyWith(showLegend: visible));
  }

  void setColorMode(ColorMode mode) {
    _colorMode = mode;
    _highlightVersion++;
    notifyListeners();
  }

  void cycleColorMode() {
    _colorMode = _colorMode.next;
    _highlightVersion++;
    notifyListeners();
  }

  // ─── JavaScript data processing ──────────────────────────

  /// Nhận từ bị tap từ JS bridge
  void onWordTapped(
    String word, {
    String? contextText,
    double? scrollProgress,
  }) {
    _tappedWordRaw = word;
    _tappedWordContextText = _normalizeOptionalStudyText(contextText);
    _tappedWordScrollProgress = scrollProgress?.clamp(0.0, 1.0).toDouble();
    final clean = word.toLowerCase().replaceAll(RegExp(r"[^\w']"), '');
    if (clean.isEmpty) return;

    final analyzed = SyntaxHighlighterService.instance.analyzeWord(clean);
    _tappedWord = analyzed;
    notifyListeners();
  }

  void clearTappedWord() {
    _tappedWord = null;
    _tappedWordRaw = null;
    _tappedWordContextText = null;
    _tappedWordScrollProgress = null;
    notifyListeners();
  }

  void onTextSelected(
    String text, {
    String? contextText,
    double? scrollProgress,
  }) {
    _selectedText = text.trim();
    _selectedContextText = _normalizeOptionalStudyText(contextText);
    _selectedScrollProgress = scrollProgress?.clamp(0.0, 1.0).toDouble();
    notifyListeners();
  }

  void clearSelection() {
    _selectedText = null;
    _selectedContextText = null;
    _selectedScrollProgress = null;
    notifyListeners();
  }

  /// Build JSON dùng để inject vào JavaScript
  /// Chứa CEFR dictionary + color map theo ColorMode hiện tại
  String buildHighlightConfig() {
    final cefrMap = <String, String>{};
    for (final entry in SyntaxHighlighterService.cefrDictionary.entries) {
      cefrMap[entry.key] = entry.value.name;
    }

    final palette = activeGrammarPalette;
    final wordTypeColors = {
      'noun': _cssColor(palette.styleFor(GrammarCategory.noun).color),
      'verb': _cssColor(palette.styleFor(GrammarCategory.verb).color),
      'adjective': _cssColor(palette.styleFor(GrammarCategory.adjective).color),
      'adverb': _cssColor(palette.styleFor(GrammarCategory.adverb).color),
      'preposition': _cssColor(palette.styleFor(GrammarCategory.preposition).color),
      'conjunction': _cssColor(palette.styleFor(GrammarCategory.conjunction).color),
      'pronoun': _cssColor(palette.styleFor(GrammarCategory.pronoun).color),
      'determiner': _cssColor(palette.styleFor(GrammarCategory.determiner).color),
      'unknown': 'transparent',
    };

    final visibleWordTypes = _grammarSettings.visibleCategories
        .map((category) => category.legacyWordType.name)
        .where((type) =>
            type == 'noun' ||
            type == 'verb' ||
            type == 'adjective' ||
            type == 'adverb' ||
            type == 'preposition' ||
            type == 'conjunction' ||
            type == 'pronoun' ||
            type == 'determiner')
        .toSet()
        .toList();

    final wordTypeBold = <String, bool>{
      'noun': palette.styleFor(GrammarCategory.noun).isBold,
      'verb': palette.styleFor(GrammarCategory.verb).isBold,
      'adjective': palette.styleFor(GrammarCategory.adjective).isBold,
      'adverb': palette.styleFor(GrammarCategory.adverb).isBold,
      'preposition': palette.styleFor(GrammarCategory.preposition).isBold,
      'conjunction': palette.styleFor(GrammarCategory.conjunction).isBold,
      'pronoun': palette.styleFor(GrammarCategory.pronoun).isBold,
      'determiner': palette.styleFor(GrammarCategory.determiner).isBold,
    };

    final config = {
      'mode': _colorMode.name,
      'cefrDictionary': cefrMap,
      'difficultyDictionary': VocabularyBridge.exportDifficultyMap(),
      'recallDictionary': VocabularyBridge.exportRecallMetadata(),
      'visibleWordTypes': visibleWordTypes,
      'hideAllWordTypes': _grammarSettings.visibleCategories.isEmpty,
      'wordTypeBold': wordTypeBold,
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
        'wordType': wordTypeColors,
        'difficulty': {
          'easy': '#4CAF50',
          'medium': '#FF9800',
          'hard': '#F44336',
          'veryHard': '#9C27B0',
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
    _highlightVersion++;
    notifyListeners();
  }

  bool markWordDifficulty(
    String word,
    DifficultyLevel difficulty, {
    AnalyzedWord? analyzed,
  }) {
    final clean = word.trim().toLowerCase();
    if (clean.isEmpty) return false;

    final anchorText = (_tappedWordRaw ?? clean).trim();
    final surroundingText = _resolveTappedContextText(clean);

    VocabularyBridge.upsertDifficulty(
      text: clean,
      difficulty: difficulty,
      meaning: analyzed?.meaning ?? '',
      phonetic: analyzed?.phonetic,
      forceType: clean.contains(' ') ? VocabularyType.phrase : VocabularyType.word,
      context: _buildCurrentWebContext(
        surroundingText,
        anchorText: anchorText,
        scrollProgressHint: _resolveTappedScrollProgress(),
      ),
      topic: _inferTopic('$_pageTitle $surroundingText'),
    );
    _highlightVersion++;
    notifyListeners();
    return true;
  }

  bool saveWordToWordList(
    String word, {
    AnalyzedWord? analyzed,
    String? surroundingText,
  }) {
    final clean = word.trim().toLowerCase();
    if (clean.isEmpty || clean.length < 2) return false;

    final existed = VocabularyBridge.hasWord(clean);
    final contextText = (surroundingText ?? '').trim().isNotEmpty
        ? surroundingText!.trim()
        : _resolveTappedContextText(clean);
    VocabularyBridge.addContextual(
      text: clean,
      meaning: analyzed?.meaning ?? '',
      phonetic: analyzed?.phonetic,
      example: contextText,
      context: _buildCurrentWebContext(
        contextText,
        anchorText: (_tappedWordRaw ?? clean).trim(),
        scrollProgressHint: _resolveTappedScrollProgress(),
      ),
    );
    _highlightVersion++;
    notifyListeners();
    return !existed;
  }

  bool saveSelectionToWordList(String selection) {
    final normalized = _normalizeStudyText(selection);
    if (normalized.isEmpty || normalized.length < 2) return false;

    final contextText = _resolveSelectionContextText(normalized);
    final existed = VocabularyBridge.hasWord(normalized);
    VocabularyBridge.addContextual(
      text: normalized,
      meaning: '',
      example: contextText,
      context: _buildCurrentWebContext(
        contextText,
        anchorText: selection.trim(),
        scrollProgressHint: _selectedScrollProgress,
      ),
    );
    _highlightVersion++;
    notifyListeners();
    return !existed;
  }

  bool saveSelectionToMemory(String selection) {
    final normalized = _normalizeStudyText(selection);
    if (normalized.isEmpty || normalized.length < 2) return false;

    final contextText = _resolveSelectionContextText(normalized);
    return MemoryProvider.addWord(
      word: normalized,
      meaning: '',
      example: contextText,
      context: contextText,
      sourceFile: _pageTitle.trim().isEmpty ? _safeHost(_currentUrl) : _pageTitle,
      tags: const ['web_reader'],
    );
  }

  List<WebExtractionCandidate> extractBatchCandidates(
    String sourceText, {
    int minLength = 4,
    int maxItems = 120,
    bool includePhrases = true,
    bool allowSingleMentionPhrases = false,
  }) {
    final cleanedSource = _normalizeSourceText(sourceText);
    if (cleanedSource.isEmpty) return const [];

    final titleNormalized = _normalizeStudyText(_pageTitle).toLowerCase();
    final wordFrequencies = <String, int>{};
    final phraseFrequencies = <String, int>{};
    final samples = <String, String>{};
    final phraseWordCounts = <String, int>{};

    final sentences = _splitIntoSentences(cleanedSource);
    for (final sentence in sentences) {
      final sample = _normalizeStudyText(sentence);
      if (sample.isEmpty) continue;

      final rawTokens = _wordRegex
          .allMatches(sample)
          .map((m) => _normalizeWordToken(m.group(0) ?? ''))
          .where((token) => token.isNotEmpty)
          .toList();

      for (final token in rawTokens) {
        if (!_isUsefulBatchWord(token, minLength: minLength)) continue;
        wordFrequencies[token] = (wordFrequencies[token] ?? 0) + 1;
        samples[token] ??= sample;
      }

      if (!includePhrases || rawTokens.length < 2) continue;

      for (final phrase in _extractSentencePhrases(
        rawTokens,
        minLength: minLength,
      )) {
        phraseFrequencies[phrase] = (phraseFrequencies[phrase] ?? 0) + 1;
        samples[phrase] ??= sample;
        phraseWordCounts[phrase] = phrase.split(' ').length;
      }
    }

    final candidates = <WebExtractionCandidate>[];

    for (final entry in wordFrequencies.entries) {
      final appearsInTitle = _containsAsTerm(titleNormalized, entry.key);
      final existed = VocabularyBridge.hasWord(entry.key);
      final isPriority = appearsInTitle ||
          entry.value >= 3 ||
          (entry.value >= 2 && entry.key.length >= minLength + 2);
      candidates.add(
        WebExtractionCandidate(
          text: entry.key,
          normalized: entry.key,
          sampleContext: samples[entry.key] ?? entry.key,
          frequency: entry.value,
          existed: existed,
          wordCount: 1,
          appearsInTitle: appearsInTitle,
          isPriority: isPriority,
          rankScore: _rankCandidate(
            text: entry.key,
            frequency: entry.value,
            existed: existed,
            isPhrase: false,
            wordCount: 1,
            appearsInTitle: appearsInTitle,
          ),
          selected: !existed,
        ),
      );
    }

    for (final entry in phraseFrequencies.entries) {
      final phrase = entry.key;
      final wordCount = phraseWordCounts[phrase] ?? phrase.split(' ').length;
      final appearsInTitle = _containsAsTerm(titleNormalized, phrase);
      if (!allowSingleMentionPhrases && !appearsInTitle && entry.value < 2) {
        continue;
      }
      final existed = VocabularyBridge.hasWord(phrase);
      final isPriority = appearsInTitle || entry.value >= 2 || wordCount >= 3;
      candidates.add(
        WebExtractionCandidate(
          text: phrase,
          normalized: phrase,
          sampleContext: samples[phrase] ?? phrase,
          frequency: entry.value,
          existed: existed,
          isPhrase: true,
          wordCount: wordCount,
          appearsInTitle: appearsInTitle,
          isPriority: isPriority,
          rankScore: _rankCandidate(
            text: phrase,
            frequency: entry.value,
            existed: existed,
            isPhrase: true,
            wordCount: wordCount,
            appearsInTitle: appearsInTitle,
          ),
          selected: !existed,
        ),
      );
    }

    candidates.sort(_compareCandidatesByPriority);

    if (candidates.length > maxItems) {
      return candidates.take(maxItems).toList();
    }
    return candidates;
  }

  WebBatchImportResult importBatchToWordList(
    Iterable<WebExtractionCandidate> candidates, {
    bool onlyReady = false,
  }) {
    int addedCount = 0;
    int updatedCount = 0;
    int skippedCount = 0;

    for (final candidate in candidates) {
      if (!candidate.selected) continue;
      if (onlyReady && !candidate.isImportReady) {
        skippedCount++;
        continue;
      }
      final normalized = _normalizeStudyText(candidate.normalized).toLowerCase();
      if (normalized.isEmpty || normalized.length < 2) {
        skippedCount++;
        continue;
      }

      final existed = VocabularyBridge.hasWord(normalized);
      final entry = VocabularyBridge.addContextual(
        text: normalized,
        meaning: candidate.meaning.trim(),
        phonetic: candidate.phonetic,
        example: (candidate.example ?? '').trim().isEmpty
            ? candidate.sampleContext
            : candidate.example,
        topic: candidate.topic,
        forceType: candidate.isPhrase ? VocabularyType.phrase : null,
        context: _buildCurrentWebContext(candidate.sampleContext),
      );

      if (entry == null) {
        skippedCount++;
      } else if (existed) {
        updatedCount++;
      } else {
        addedCount++;
      }
    }

    return WebBatchImportResult(
      addedCount: addedCount,
      updatedCount: updatedCount,
      skippedCount: skippedCount,
    );
  }

  Future<WebExtractionDraft> saveBatchDraft({
    String? draftId,
    required String sourceLabel,
    required String sourceText,
    required bool fromSelection,
    required List<WebExtractionCandidate> candidates,
  }) async {
    final now = DateTime.now();
    final existingIndex =
        draftId == null ? -1 : _batchDrafts.indexWhere((d) => d.id == draftId);
    final draft = WebExtractionDraft(
      id: existingIndex >= 0
          ? _batchDrafts[existingIndex].id
          : 'draft_${now.microsecondsSinceEpoch}',
      sourceLabel: sourceLabel.trim(),
      sourceText: sourceText,
      fromSelection: fromSelection,
      createdAt: existingIndex >= 0 ? _batchDrafts[existingIndex].createdAt : now,
      updatedAt: now,
      candidates: candidates
          .map((candidate) => WebExtractionCandidate.fromJson(candidate.toJson()))
          .toList(),
    );

    if (existingIndex >= 0) {
      _batchDrafts[existingIndex] = draft;
    } else {
      _batchDrafts.add(draft);
    }

    if (_batchDrafts.length > 20) {
      _batchDrafts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _batchDrafts.removeRange(20, _batchDrafts.length);
    }

    await _saveBatchDrafts();
    notifyListeners();
    return draft;
  }

  Future<void> deleteBatchDraft(String draftId) async {
    _batchDrafts.removeWhere((draft) => draft.id == draftId);
    await _saveBatchDrafts();
    notifyListeners();
  }

  void enrichCandidateLocally(WebExtractionCandidate candidate) {
    final topic = _inferTopic(
      '${_pageTitle.trim()} ${candidate.sampleContext} ${candidate.text}',
    );
    candidate.topic ??= topic;
    candidate.example ??= candidate.sampleContext;

    final direct = SyntaxHighlighterService.instance.analyzeWord(candidate.normalized);
    if ((candidate.meaning).trim().isEmpty) {
      candidate.meaning = (direct.meaning ?? '').trim();
    }
    candidate.phonetic ??= direct.phonetic;

    if (candidate.isPhrase && candidate.meaning.trim().isEmpty) {
      final partHints = candidate.normalized
          .split(' ')
          .map((part) => SyntaxHighlighterService.instance.analyzeWord(part))
          .map((analysis) => analysis.meaning?.trim() ?? '')
          .where((meaning) => meaning.isNotEmpty)
          .take(3)
          .toList();
      if (partHints.isNotEmpty) {
        candidate.meaning = partHints.join(' · ');
      }
    }

    candidate.enriched = true;
    candidate.enrichSource = direct.meaning != null || direct.phonetic != null
        ? 'local'
        : 'heuristic';
  }

  void applyAiAssistToCandidate(
    WebExtractionCandidate candidate, {
    String? meaning,
    String? phonetic,
    String? topic,
    String? example,
    required bool usedAi,
  }) {
    final aiMeaning = (meaning ?? '').trim();
    final aiPhonetic = (phonetic ?? '').trim();
    final aiTopic = (topic ?? '').trim();
    final aiExample = (example ?? '').trim();

    if (aiMeaning.isNotEmpty) candidate.meaning = aiMeaning;
    if (aiPhonetic.isNotEmpty) candidate.phonetic = aiPhonetic;
    if (aiTopic.isNotEmpty) candidate.topic = aiTopic;
    if (aiExample.isNotEmpty) candidate.example = aiExample;
    if ((candidate.topic ?? '').trim().isEmpty) {
      candidate.topic = _inferTopic(candidate.sampleContext);
    }
    if ((candidate.example ?? '').trim().isEmpty) {
      candidate.example = candidate.sampleContext;
    }
    candidate.enriched = true;
    candidate.enrichSource = usedAi ? 'ai+local' : candidate.enrichSource;
  }

  String _inferTopic(String source) {
    final haystack = source.toLowerCase();
    if (RegExp(r'\b(dharma|buddha|sutta|meditation|mindfulness|monk)\b')
        .hasMatch(haystack)) {
      return 'dharma';
    }
    if (RegExp(r'\b(learning english|voa|bbc learning|english|grammar|vocabulary)\b')
        .hasMatch(haystack)) {
      return 'english_learning';
    }
    if (RegExp(r'\b(news|reuters|guardian|bbc|cnn|report)\b')
        .hasMatch(haystack)) {
      return 'news';
    }
    final host = _safeHost(_currentUrl);
    return host.trim().isEmpty ? 'web_reader' : host;
  }

  String? _normalizeOptionalStudyText(String? text) {
    final normalized = _normalizeStudyText(text ?? '');
    return normalized.isEmpty ? null : normalized;
  }

  String _resolveTappedContextText(String fallback) {
    final tapped = (_tappedWordContextText ?? '').trim();
    if (tapped.isNotEmpty) return tapped;
    final selected = (_selectedContextText ?? '').trim();
    if (selected.isNotEmpty) return selected;
    return fallback;
  }

  String _resolveSelectionContextText(String fallback) {
    final selected = (_selectedContextText ?? '').trim();
    if (selected.isNotEmpty) return selected;
    return fallback;
  }

  double? _resolveTappedScrollProgress() =>
      _tappedWordScrollProgress ?? _selectedScrollProgress;

  VocabContext _buildCurrentWebContext(
    String surroundingText, {
    String? anchorText,
    double? scrollProgressHint,
  }) {
    return VocabContext.fromWeb(
      url: _currentUrl,
      pageTitle: _pageTitle,
      surroundingText: surroundingText,
      anchorText: anchorText,
      scrollProgressHint: scrollProgressHint,
    );
  }

  String _normalizeSourceText(String text) =>
      text.replaceAll(RegExp(r'\r\n?'), '\n').trim();

  String _normalizeStudyText(String text) =>
      text.replaceAll(RegExp(r'\s+'), ' ').trim();

  List<String> _splitIntoSentences(String source) {
    return source
        .split(RegExp(r'(?<=[\.!?\n])\s+'))
        .map(_normalizeStudyText)
        .where((s) => s.isNotEmpty)
        .toList();
  }

  String _normalizeWordToken(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r"^[^a-z]+|[^a-z']+$"), '')
        .trim();
  }

  Iterable<String> _extractSentencePhrases(
    List<String> tokens, {
    required int minLength,
  }) sync* {
    for (int start = 0; start < tokens.length; start++) {
      for (int size = 3; size >= 2; size--) {
        if (start + size > tokens.length) continue;
        final window = tokens.sublist(start, start + size);
        if (window.any((token) => !_isUsefulPhraseToken(token))) continue;
        final phrase = window.join(' ');
        if (!_isUsefulBatchPhrase(phrase, minLength: minLength)) continue;
        yield phrase;
      }
    }
  }

  bool _isUsefulPhraseToken(String token) {
    if (token.length < 2) return false;
    if (_webBatchStopWords.contains(token)) return false;
    if (!RegExp(r'[a-z]').hasMatch(token)) return false;
    return true;
  }

  bool _isUsefulBatchPhrase(String phrase, {required int minLength}) {
    final words = phrase.split(' ');
    if (words.length < 2) return false;
    final phraseLength = phrase.replaceAll(' ', '').length;
    if (phraseLength < minLength + 2) return false;
    if (words.every((word) => word.length < minLength)) return false;
    return true;
  }

  bool _isUsefulBatchWord(String token, {required int minLength}) {
    if (token.length < minLength) return false;
    if (_webBatchStopWords.contains(token)) return false;
    if (!RegExp(r"[a-z]").hasMatch(token)) return false;
    if (token.startsWith("'") || token.endsWith("'")) return false;
    return true;
  }

  bool _containsAsTerm(String haystack, String needle) {
    if (haystack.trim().isEmpty || needle.trim().isEmpty) return false;
    final escaped =
        RegExp.escape(needle.trim().toLowerCase()).replaceAll(' ', r'\s+');
    return RegExp('\b$escaped\b').hasMatch(haystack);
  }

  double _rankCandidate({
    required String text,
    required int frequency,
    required bool existed,
    required bool isPhrase,
    required int wordCount,
    required bool appearsInTitle,
  }) {
    final lengthScore = text.replaceAll(' ', '').length.toDouble();
    final frequencyScore = frequency * (isPhrase ? 11.0 : 9.0);
    final phraseBonus = isPhrase ? (wordCount * 5.5) : 0.0;
    final titleBonus = appearsInTitle ? (isPhrase ? 26.0 : 18.0) : 0.0;
    final noveltyBonus = existed ? -4.0 : 6.0;
    final repeatBonus = frequency > 1 ? frequency * 2.5 : 0.0;
    return frequencyScore + phraseBonus + titleBonus + noveltyBonus + repeatBonus + (lengthScore * 0.35);
  }

  int _compareCandidatesByPriority(
    WebExtractionCandidate a,
    WebExtractionCandidate b,
  ) {
    final scoreCompare = b.rankScore.compareTo(a.rankScore);
    if (scoreCompare != 0) return scoreCompare;
    if (a.isPriority != b.isPriority) return a.isPriority ? -1 : 1;
    if (a.existed != b.existed) return a.existed ? 1 : -1;
    if (a.isPhrase != b.isPhrase) return a.isPhrase ? -1 : 1;
    final frequencyCompare = b.frequency.compareTo(a.frequency);
    if (frequencyCompare != 0) return frequencyCompare;
    final lengthCompare = b.normalized.length.compareTo(a.normalized.length);
    if (lengthCompare != 0) return lengthCompare;
    return a.normalized.compareTo(b.normalized);
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

    final bookmarkIndex =
        _bookmarks.indexWhere((entry) => entry.url == normalizedUrl);
    if (bookmarkIndex >= 0) {
      final existing = _bookmarks.removeAt(bookmarkIndex);
      _bookmarks.add(
        existing.copyWith(
          title: (title ?? '').trim().isEmpty ? existing.title : title!.trim(),
          lastReadAt: DateTime.now(),
          progress: clampedProgress,
          preview: (preview ?? '').trim().isEmpty
              ? existing.preview
              : preview!.trim(),
        ),
      );
      await _persistBookmarks();
    }

    notifyListeners();
  }

  bool isArticlePinned(String url) => _pinnedArticleUrls.contains(url.trim());

  bool isArticleCompleted(String url) => progressForUrl(url) >= 0.98;

  Future<void> toggleArticlePin(
    String url, {
    String? title,
    String? preview,
  }) async {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty ||
        normalizedUrl.startsWith('about:') ||
        normalizedUrl.contains('google.com/search')) {
      return;
    }

    if (_pinnedArticleUrls.contains(normalizedUrl)) {
      _pinnedArticleUrls.remove(normalizedUrl);
    } else {
      _pinnedArticleUrls.add(normalizedUrl);
      if (_findHistoryEntry(normalizedUrl) == null) {
        _upsertHistoryEntry(
          url: normalizedUrl,
          title: (title ?? '').trim(),
          preview: preview,
          touchReadTime: false,
        );
        await _persistHistory();
      }
    }
    await _savePinnedArticleUrls();
    notifyListeners();
  }

  Future<void> markArticleCompleted(
    String url, {
    String? title,
    String? preview,
  }) async {
    await updateReadingProgress(
      url: url,
      title: title,
      preview: preview,
      progress: 1.0,
    );
  }

  Future<void> resetArticleProgress(
    String url, {
    String? title,
    String? preview,
  }) async {
    await updateReadingProgress(
      url: url,
      title: title,
      preview: preview,
      progress: 0.0,
    );
  }

  String articleNote(String url) => _articleNotes[url.trim()] ?? '';

  bool hasArticleNote(String url) => articleNote(url).trim().isNotEmpty;

  String articleNotePreview(String url, {int maxLength = 120}) {
    final text = articleNote(url).replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}…';
  }

  Future<void> saveArticleNote(
    String url,
    String note, {
    String? title,
    String? preview,
  }) async {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty ||
        normalizedUrl.startsWith('about:') ||
        normalizedUrl.contains('google.com/search')) {
      return;
    }

    final normalizedNote = note.trim();
    if (normalizedNote.isEmpty) {
      _articleNotes.remove(normalizedUrl);
    } else {
      _articleNotes[normalizedUrl] = normalizedNote;
      if (_findHistoryEntry(normalizedUrl) == null) {
        _upsertHistoryEntry(
          url: normalizedUrl,
          title: (title ?? '').trim(),
          preview: preview,
          touchReadTime: false,
        );
        await _persistHistory();
      }
    }
    await _saveArticleNotes();
    notifyListeners();
  }

  Future<void> appendSelectionToArticleNote(
    String url,
    String selection, {
    String? title,
    String? preview,
  }) async {
    final snippet = selection.trim();
    if (snippet.isEmpty) return;
    final existing = articleNote(url);
    final next = existing.trim().isEmpty
        ? snippet
        : '$existing\n\n— $snippet';
    await saveArticleNote(
      url,
      next,
      title: title,
      preview: preview,
    );
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

  List<WebHistoryEntry> _entriesForUrls(Iterable<String> urls) {
    final results = <WebHistoryEntry>[];
    final seen = <String>{};
    for (final rawUrl in urls) {
      final url = rawUrl.trim();
      if (url.isEmpty || !seen.add(url)) continue;
      final historyEntry = _findHistoryEntry(url);
      if (historyEntry != null) {
        results.add(historyEntry);
        continue;
      }
      final bookmarkEntry = _findBookmarkEntry(url);
      if (bookmarkEntry != null) {
        results.add(bookmarkEntry);
        continue;
      }
      results.add(
        WebHistoryEntry(
          url: url,
          title: _safeHost(url),
          visitedAt: DateTime.now(),
          progress: 0,
          preview: '',
        ),
      );
    }
    results.sort((a, b) => b.effectiveReadAt.compareTo(a.effectiveReadAt));
    return results;
  }

  WebHistoryEntry? _findHistoryEntry(String url) {
    try {
      return _history.lastWhere((entry) => entry.url == url);
    } catch (_) {
      return null;
    }
  }

  WebHistoryEntry? _findBookmarkEntry(String url) {
    try {
      return _bookmarks.lastWhere((entry) => entry.url == url);
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

  Future<void> _loadPinnedArticleUrls() async {
    try {
      final box = await _getStorageBox();
      final raw = box?.get(_pinnedArticleUrlsKey);
      if (raw == null) return;
      final list = jsonDecode(raw) as List;
      _pinnedArticleUrls
        ..clear()
        ..addAll(list.map((e) => e.toString()).where((e) => e.trim().isNotEmpty));
      notifyListeners();
    } catch (e) {
      debugPrint('WebReaderController: _loadPinnedArticleUrls error: $e');
    }
  }

  Future<void> _savePinnedArticleUrls() async {
    try {
      final box = await _getStorageBox();
      await box?.put(
        _pinnedArticleUrlsKey,
        jsonEncode(_pinnedArticleUrls.toList()),
      );
    } catch (e) {
      debugPrint('WebReaderController: _savePinnedArticleUrls error: $e');
    }
  }

  Future<void> _loadArticleNotes() async {
    try {
      final box = await _getStorageBox();
      final raw = box?.get(_articleNotesKey);
      if (raw == null) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _articleNotes
        ..clear()
        ..addAll(map.map((key, value) => MapEntry(key, value.toString())));
      notifyListeners();
    } catch (e) {
      debugPrint('WebReaderController: _loadArticleNotes error: $e');
    }
  }

  Future<void> _saveArticleNotes() async {
    try {
      final box = await _getStorageBox();
      await box?.put(_articleNotesKey, jsonEncode(_articleNotes));
    } catch (e) {
      debugPrint('WebReaderController: _saveArticleNotes error: $e');
    }
  }

  Future<void> _loadBatchDrafts() async {
    try {
      final box = await _getStorageBox();
      final raw = box?.get(_batchDraftsKey);
      if (raw == null) return;
      final list = jsonDecode(raw) as List;
      _batchDrafts
        ..clear()
        ..addAll(list.map((e) =>
            WebExtractionDraft.fromJson(Map<String, dynamic>.from(e as Map))));
      notifyListeners();
    } catch (e) {
      debugPrint('WebReaderController: _loadBatchDrafts error: $e');
    }
  }

  Future<void> _saveBatchDrafts() async {
    try {
      final box = await _getStorageBox();
      await box?.put(
        _batchDraftsKey,
        jsonEncode(_batchDrafts.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('WebReaderController: _saveBatchDrafts error: $e');
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

  String _cssColor(Color color) {
    final value = color.toARGB32() & 0x00FFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

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
