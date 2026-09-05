import 'dart:async';
import 'dart:ui' show Rect;

import 'package:flutter/material.dart';
import 'package:in4up_core/vocab_level_difficulty.dart';
import 'package:pdfrx/pdfrx.dart' hide PdfAnnotation;
import 'package:uuid/uuid.dart';

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
import '../../providers/vocabulary_bridge.dart';
import '../../screens/memory_mode/memory_provider.dart';
import '../../services/reader_display_settings.dart';
import 'models/pdf_annotation.dart';
import 'models/pdf_sentence_cue.dart';
import 'models/pdf_word_info.dart';
import 'services/pdf_annotation_storage.dart';
import 'services/pdf_file_identity.dart';
import 'services/pdf_text_extractor.dart';

enum PdfTtsState { idle, loading, playing, paused }

enum PdfViewMode { pdfView, textMode }

/// Loại nguồn của vùng chữ đang chọn — quyết định cách tạo annotation sao cho
/// reopen đúng chỗ (quy tắc vàng #3).
enum PdfSelectionSource { none, viewer, textMode }

/// Mảnh chọn trên một trang cụ thể (offset trong `fullText` thô + rect PDF).
class PdfSelectionFragment {
  const PdfSelectionFragment({
    required this.pageIndex,
    required this.startOffset,
    required this.endOffset,
    required this.bounds,
  });

  final int pageIndex;
  final int startOffset;
  final int endOffset;

  /// Rect trong không gian trang PDF (gốc dưới-trái) — cùng hệ với
  /// `PdfWordInfo.bounds` và `PdfAnnotation.bounds`.
  final Rect bounds;
}

/// Những gì controller cần ở PdfViewer nhưng không được import pdfrx vào UI
/// tree của logic. Màn hình gán các callback này một lần khi build.
class PdfReaderViewerCommands {
  /// Cuộn tới trang (0-based).
  void Function(int pageIndex)? goToPage;

  /// Cuộn để nhìn thấy một rect trên trang (0-based).
  void Function(int pageIndex, Rect rect)? revealRect;
}

class PdfReaderController extends ChangeNotifier {
  final String pdfPath;
  final PdfAnnotationStorage _storage = PdfAnnotationStorage();
  final PdfTextExtractor _extractor = PdfTextExtractor();
  final TtsService _tts = TtsService();

  static final Uuid _uuid = Uuid();

  // ─── Document ───────────────────────────────────────────
  PdfDocument? _document;
  PdfDocument? get document => _document;
  bool get isDocumentLoaded => _document != null;

  int _currentPage = 0;
  int get currentPage => _currentPage;
  int get totalPages => _document?.pages.length ?? 0;

  /// Tên file (basename, chấp nhận cả `\` của Windows) — dùng làm
  /// `VocabContext.fileName`/`sourceFile` để panel "từ đã lưu của file này"
  /// khớp được với annotation của mọi nền tảng.
  late final String fileName = pdfBaseName(pdfPath);

  /// Tên ngắn cho title/snackbar.
  String get displayTitle => pdfDisplayName(pdfPath);

  /// Định danh bền của file (xem PdfFileIdentity).
  PdfFileIdentity? _identity;
  PdfFileIdentity? get identity => _identity;

  final Completer<void> _storageReady = Completer<void>();

  /// Hoàn tất khi đã đọc xong annotation + trang đọc cuối (để PdfViewer không
  /// nhảy trang trước khi biết nơi cần trở lại).
  Future<void> get storageReady => _storageReady.future;

  /// Trang mà phiên đọc trước để lại (0 nếu chưa có dữ liệu).
  int get restoredPageIndex => _restoredPageIndex;
  int _restoredPageIndex = 0;

  /// Có true nếu dữ liệu đọc vừa được dời từ khoá cũ sang khoá mới.
  bool get didMigrateStorage => _didMigrateStorage;
  bool _didMigrateStorage = false;

  // ─── View Mode ───────────────────────────────────────────
  PdfViewMode _viewMode = PdfViewMode.pdfView;
  PdfViewMode get viewMode => _viewMode;

  // ─── Color Mode ─────────────────────────────────────────
  ColorMode _colorMode = ColorMode.none;
  GrammarHighlightSettings _grammarSettings = GrammarHighlightSettings.defaults();
  List<GrammarHighlightPreset> _availableGrammarPresets =
      GrammarHighlightPresets.defaults();
  ColorMode get colorMode => _colorMode;
  GrammarHighlightSettings get grammarSettings => _grammarSettings;
  List<GrammarHighlightPreset> get availableGrammarPresets =>
      List.unmodifiable(_availableGrammarPresets);
  GrammarPalette get activeGrammarPalette =>
      GrammarPalettes.byId(_grammarSettings.paletteId);
  GrammarHighlightPreset get activeGrammarPreset =>
      _findGrammarPresetById(_grammarSettings.activePresetId);

  // ─── Words overlay ───────────────────────────────────────
  /// Cache: pageIndex → words với positions
  final Map<int, List<PdfWordInfo>> _pageWords = {};
  bool _isLoadingWords = false;
  bool get isLoadingWords => _isLoadingWords;

  List<PdfWordInfo> getWordsForPage(int pageIndex) =>
      _pageWords[pageIndex] ?? const [];

  // ─── Recall markers (READ-630-03) ────────────────────────
  /// Marker bao quanh từ đã lưu (green/amber/red). MẶC ĐỊNH TẮT —
  /// chỉ hiện khi người dùng bật (đọc sạch khi không cần).
  bool _showRecallMarkers = ReaderDisplaySettings().showRecallMarkers;
  bool get showRecallMarkers => _showRecallMarkers;

  PdfReaderController({required this.pdfPath}) {
    _init();
    ReaderDisplaySettings().addListener(_onDisplaySettingsChanged);
  }

  void _onDisplaySettingsChanged() {
    final next = ReaderDisplaySettings().showRecallMarkers;
    if (next == _showRecallMarkers) return;
    _showRecallMarkers = next;
    // Recall marker đọc `analyzed`, nên bật/tắt nó phải làm mới phân tích của
    // những trang đang thấy (cache key trong extractor đã tính tới việc này).
    _reloadVisiblePages();
    notifyListeners();
  }

  void toggleRecallMarkers() {
    ReaderDisplaySettings().setShowRecallMarkers(!_showRecallMarkers);
  }

  // ─── TTS ────────────────────────────────────────────────
  PdfTtsState _ttsState = PdfTtsState.idle;
  PdfTtsState get ttsState => _ttsState;
  String? _currentSpeakingWord;
  String? get currentSpeakingWord => _currentSpeakingWord;

  /// Cue đang được đọc — overlay tô theo TỪNG DÒNG nên câu dài 3 dòng nhìn
  /// vẫn "sạch".
  List<PdfSentenceCue> _readingCues = const [];
  int _readingCueIndex = -1;
  bool _readingActive = false;
  int _readingPageIndex = 0;
  bool _ttsAutoAdvance = true;

  /// `true` khi lần đọc gần nhất dừng vì trang không có lớp chữ (PDF scan).
  bool get pageHasNoTextLayer => _pageHasNoTextLayer;
  bool _pageHasNoTextLayer = false;

  List<PdfSentenceCue> get readingCues => _readingCues;
  int get readingCueIndex => _readingCueIndex;
  bool get isReadingActive => _readingActive;
  bool get ttsAutoAdvance => _ttsAutoAdvance;
  int get totalCues => _readingCues.length;
  bool get hasReadingContent => _readingCues.isNotEmpty;

  PdfSentenceCue? get currentCue {
    if (_readingCueIndex < 0 || _readingCueIndex >= _readingCues.length) {
      return null;
    }
    return _readingCues[_readingCueIndex];
  }

  /// Rect đang được đọc cho overlay (null khi không đọc).
  List<Rect> get ttsCueRects => currentCue?.lineRects ?? const [];
  int? get ttsCuePageIndex => _readingActive ? _readingPageIndex : null;

  /// "câu 3/12 · trang 5" cho thanh TTS.
  /// '0.9x · EN' cho nhãn phụ ở thanh TTS.
  String get ttsSpeedLabel =>
      '${_ttsSpeed.toStringAsFixed(1)}x · ${_ttsLanguage == 'vi-VN' ? 'VI' : 'EN'}';

  String get readingProgressLabel {
    if (_readingCues.isEmpty) return '';
    final n = (_readingCueIndex + 1).clamp(1, _readingCues.length);
    return '$n/${_readingCues.length}';
  }

  void setTtsAutoAdvance(bool value) {
    if (_ttsAutoAdvance == value) return;
    _ttsAutoAdvance = value;
    notifyListeners();
  }

  /// Cho phép controller điều khiển PdfViewer (lật trang khi đọc, cua tới vùng).
  final PdfReaderViewerCommands viewerCommands = PdfReaderViewerCommands();

  String? _focusWordCue;
  String? get focusWordCue => _focusWordCue;
  Rect? _focusRectCue;
  Rect? get focusRectCue => _focusRectCue;
  int? _focusPageIndexCue;
  int? get focusPageIndexCue => _focusPageIndexCue;
  int? _focusTextStartOffsetCue;
  int? get focusTextStartOffsetCue => _focusTextStartOffsetCue;
  int? _focusTextEndOffsetCue;
  int? get focusTextEndOffsetCue => _focusTextEndOffsetCue;
  int _focusCueVersion = 0;
  int get focusCueVersion => _focusCueVersion;

  String _ttsLanguage = 'en-US'; // 'en-US' | 'vi-VN' (bilingual chưa khả dụng)
  String get ttsLanguage => _ttsLanguage;

  /// Bản dịch từng câu cho chế độ song ngữ chưa được nối trong reader, nên
  /// không mời người dùng chọn nó (xem docs/pdf_reader_readera_upgrade.md P0-4).
  bool get isBilingualTtsAvailable => false;

  double _ttsSpeed = 0.9;
  double get ttsSpeed => _ttsSpeed;

  // ─── Annotations ────────────────────────────────────────
  List<PdfAnnotation> _annotations = [];
  List<PdfAnnotation> get annotations => List.unmodifiable(_annotations);
  List<PdfAnnotation> annotationsForPage(int pageIndex) =>
      _annotations.where((a) => a.pageIndex == pageIndex).toList();
  bool hasBookmarkOnPage(int pageIndex) => _annotations.any(
        (a) => a.pageIndex == pageIndex && a.type == AnnotationType.bookmark,
      );

  // ─── Selected Text ───────────────────────────────────────
  String? _selectedText;
  String? get selectedText => _selectedText;
  Rect? _selectionRect;
  Rect? get selectionRect => _selectionRect;
  List<PdfSelectionFragment> _selectionFragments = const [];
  List<PdfSelectionFragment> get selectionFragments => _selectionFragments;
  PdfSelectionSource _selectionSource = PdfSelectionSource.none;
  PdfSelectionSource get selectionSource => _selectionSource;
  bool get hasSelection => (_selectedText?.trim().isNotEmpty ?? false);

  /// Số trang mà vùng chọn phủ tới (để hiện "3 trang" trong selection bar).
  int get selectionPageCount =>
      _selectionFragments.map((f) => f.pageIndex).toSet().length;

  // ─── Loading ─────────────────────────────────────────────
  bool _isLoading = true;
  bool get isLoading => _isLoading;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ─── Text Mode ───────────────────────────────────────────
  String _extractedFullText = '';
  String get extractedFullText => _extractedFullText;
  bool _isExtractingText = false;
  bool get isExtractingText => _isExtractingText;

  /// 0..1 — cho phép Text Mode hiện "trang 40/312" thay vì spinner vô hồn.
  double _extractProgress = 0;
  double get extractProgress => _extractProgress;
  String _extractProgressLabel = '';
  String get extractProgressLabel => _extractProgressLabel;

  // ─── Init ────────────────────────────────────────────────
  GrammarHighlightPreset _findGrammarPresetById(String? presetId) {
    for (final preset in _availableGrammarPresets) {
      if (preset.id == presetId) return preset;
    }
    return GrammarHighlightPresets.byId(presetId);
  }

  Future<void> _init() async {
    try {
      await _storage.initialize();
      final identity = await PdfFileIdentity.resolve(pdfPath);
      _identity = identity;
      final bundle = await _storage.load(identity);
      _annotations = bundle.annotations;
      _restoredPageIndex = bundle.lastPageIndex;
      _didMigrateStorage = bundle.migrated;
      _currentPage = _restoredPageIndex;
    } catch (e) {
      debugPrint('PdfReaderController: storage init error: $e');
    }
    try {
      _availableGrammarPresets =
          await GrammarPresetLibraryService.loadAllPresets();
      _grammarSettings = await GrammarSettingsService.load();
    } catch (e) {
      debugPrint('PdfReaderController: grammar settings load error: $e');
    }
    if (!_storageReady.isCompleted) _storageReady.complete();
    notifyListeners();
  }

  /// Gọi từ PdfViewer khi document load xong. Đây là `Future` để màn hình chờ
  /// `_storageReady` trước khi quyết định nhảy trang — tránh cuộc đua
  /// "viewer vẽ trang 1 trong khi dữ liệu cũ nói phải về trang 87".
  Future<void> onDocumentLoaded(PdfDocument doc) async {
    _document = doc;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();

    await _storageReady.future;
    _clampRestoredPage();
    _loadWordsForPage(_currentPage);
  }

  void _clampRestoredPage() {
    final doc = _document;
    if (doc == null) return;
    if (_restoredPageIndex > 0 && _restoredPageIndex < doc.pages.length) {
      _currentPage = _restoredPageIndex;
    } else {
      _currentPage = 0;
    }
  }

  /// Trang cần viewer nhảy tới ngay khi mở (null = ở nguyên trang 0).
  int? get initialPageToRestore {
    final doc = _document;
    if (_restoredPageIndex <= 0) return null;
    if (doc != null && _restoredPageIndex >= doc.pages.length) return null;
    return _restoredPageIndex;
  }

  void onDocumentError(Object error) {
    _isLoading = false;
    _errorMessage = error.toString();
    notifyListeners();
  }

  // ─── Navigation ──────────────────────────────────────────
  void onPageChanged(int pageIndex) {
    if (pageIndex == _currentPage) return;
    _currentPage = pageIndex;
    final identity = _identity;
    if (identity != null) {
      unawaited(_storage.persistLastPage(identity, pageIndex));
    }
    notifyListeners();

    _loadWordsForPage(pageIndex);
    if (pageIndex + 1 < totalPages) _loadWordsForPage(pageIndex + 1);
  }

  /// Điều khiển bằng nút ngoài (TTS bar, phím tắt).
  void goToPage(int pageIndex) {
    if (pageIndex < 0 || pageIndex >= totalPages) return;
    viewerCommands.goToPage?.call(pageIndex);
    onPageChanged(pageIndex);
  }

  void nextPage() => goToPage(_currentPage + 1);
  void previousPage() => goToPage(_currentPage - 1);

  void _clearFocusCueData() {
    _focusWordCue = null;
    _focusRectCue = null;
    _focusPageIndexCue = null;
    _focusTextStartOffsetCue = null;
    _focusTextEndOffsetCue = null;
  }

  void showFocusCueForWord(String word,
      {Duration duration = const Duration(seconds: 3)}) {
    final normalized = word.trim().toLowerCase();
    if (normalized.isEmpty) return;
    _clearFocusCueData();
    _focusWordCue = normalized;
    _focusCueVersion++;
    notifyListeners();

    final version = _focusCueVersion;
    Future.delayed(duration, () {
      if (_focusCueVersion != version) return;
      _clearFocusCueData();
      notifyListeners();
    });
  }

  void showFocusCueForContext(
    VocabContext context, {
    String? fallbackWord,
    Duration duration = const Duration(seconds: 4),
  }) {
    _clearFocusCueData();
    final anchor =
        (context.anchorText ?? fallbackWord ?? '').trim().toLowerCase();
    _focusWordCue = anchor.isEmpty ? null : anchor;
    _focusRectCue = context.rectHint;
    _focusPageIndexCue = context.pageIndexHint;
    _focusTextStartOffsetCue = context.textStartOffset;
    _focusTextEndOffsetCue = context.textEndOffset;
    _focusCueVersion++;
    notifyListeners();

    final version = _focusCueVersion;
    Future.delayed(duration, () {
      if (_focusCueVersion != version) return;
      _clearFocusCueData();
      notifyListeners();
    });
  }

  void revealAnnotation(PdfAnnotation annotation) {
    goToPage(annotation.pageIndex);
    if (annotation.hasValidBounds) {
      viewerCommands.revealRect?.call(annotation.pageIndex, annotation.bounds);
    }
  }

  /// Đưa người đọc về đúng chỗ một annotation/word đã lưu.
  void revealContext(VocabContext context) {
    final page = context.pageIndexHint;
    final rect = context.rectHint;
    if (page == null) return;
    goToPage(page);
    if (rect != null && rect != Rect.zero) {
      viewerCommands.revealRect?.call(page, rect);
    }
  }

  // ─── Color Mode ──────────────────────────────────────────
  Future<void> _saveGrammarSettings() async {
    try {
      await GrammarSettingsService.save(_grammarSettings);
    } catch (e) {
      debugPrint('PdfReaderController: grammar settings save error: $e');
    }
  }

  Future<void> refreshGrammarPresetLibrary() async {
    _availableGrammarPresets =
        await GrammarPresetLibraryService.loadAllPresets();
    notifyListeners();
  }

  Future<void> setGrammarSettings(GrammarHighlightSettings settings) async {
    _grammarSettings = settings;
    refreshVocabularySignals();
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
    final preset =
        _findGrammarPresetById(_grammarSettings.lastNonCustomPresetId);
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
    _availableGrammarPresets =
        await GrammarPresetLibraryService.loadAllPresets();
    notifyListeners();
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
    return setGrammarSettings(
        _grammarSettings.copyWith(highlightStyle: style));
  }

  Future<void> toggleGrammarCategory(GrammarCategory category) {
    final next = Set<GrammarCategory>.from(_grammarSettings.visibleCategories);
    if (next.contains(category)) {
      next.remove(category);
    } else {
      next.add(category);
    }
    return setGrammarSettings(_grammarSettings.copyWith(
      activePresetId: 'custom',
      visibleCategories: next,
    ));
  }

  Future<void> showAllGrammarCategories() {
    return setGrammarSettings(_grammarSettings.copyWith(
      activePresetId: 'custom',
      visibleCategories: Set<GrammarCategory>.from(GrammarCategory.values),
    ));
  }

  Future<void> setGrammarLegendVisible(bool visible) {
    return setGrammarSettings(_grammarSettings.copyWith(showLegend: visible));
  }

  void setColorMode(ColorMode mode) {
    if (_colorMode == mode) return;
    _colorMode = mode;
    // Cache đã mang key theo colorMode → chỉ cần nạp lại trang đang thấy.
    _reloadVisiblePages();
  }

  void cycleColorMode() => setColorMode(_colorMode.next);

  void _reloadVisiblePages() {
    final pages = <int>{
      _currentPage,
      if (_currentPage + 1 < totalPages) _currentPage + 1,
    };
    _extractor.invalidatePages(pages);
    for (final p in pages) {
      _pageWords.remove(p);
    }
    for (final p in pages) {
      _loadWordsForPage(p);
    }
    notifyListeners();
  }

  // ─── Word Loading ────────────────────────────────────────
  Future<void> _loadWordsForPage(int pageIndex) async {
    final doc = _document;
    if (doc == null) return;
    if (pageIndex < 0 || pageIndex >= doc.pages.length) return;
    final needsAnalysis = _colorMode != ColorMode.none || _showRecallMarkers;
    if (_pageWords.containsKey(pageIndex)) return;

    _isLoadingWords = true;
    notifyListeners();

    try {
      final page = doc.pages[pageIndex];
      final words = await _extractor.extractWordsWithPositions(
        page,
        pageIndex,
        _colorMode,
        needsAnalysis: needsAnalysis,
      );
      _pageWords[pageIndex] = words;
    } catch (e) {
      debugPrint('PdfReaderController: _loadWordsForPage error: $e');
    } finally {
      _isLoadingWords = false;
      notifyListeners();
    }
  }

  // ─── View Mode ───────────────────────────────────────────
  Future<void> switchToTextMode() async {
    if (_document == null) return;
    _viewMode = PdfViewMode.textMode;
    notifyListeners();

    if (_extractedFullText.isEmpty && !_isExtractingText) {
      _isExtractingText = true;
      _extractProgress = 0;
      _extractProgressLabel = '';
      notifyListeners();
      _extractedFullText = await _extractor.extractFullText(
        _document!,
        onProgress: (i, total) {
          _extractProgress = total == 0 ? 1 : (i + 1) / total;
          _extractProgressLabel = '${i + 1}';
          notifyListeners();
        },
      );
      _isExtractingText = false;
      notifyListeners();
    }
  }

  void switchToPdfMode() {
    _viewMode = PdfViewMode.pdfView;
    notifyListeners();
  }

  // ─── TTS: đọc theo trang, highlight theo câu ────────────
  /// Nút Play trên thanh TTS: đang đọc thì dừng, đang dừng thì tiếp tục.
  Future<void> speakCurrentPage() async {
    if (_readingActive) {
      if (_ttsState == PdfTtsState.playing) {
        await pauseReading();
      } else if (_ttsState == PdfTtsState.paused) {
        await _tts.resume();
        _ttsState = PdfTtsState.playing;
        notifyListeners();
      } else {
        await stopReading();
      }
      return;
    }
    await startReading(fromPage: _currentPage);
  }

  Future<void> startReading({int? fromPage, int? fromCue}) async {
    final doc = _document;
    if (doc == null) return;
    final startPage = (fromPage ?? _currentPage).clamp(0, doc.pages.length - 1);

    _readingActive = true;
    _readingPageIndex = startPage;
    _ttsState = PdfTtsState.loading;
    _readingCues = const [];
    _readingCueIndex = -1;
    notifyListeners();

    try {
      var pageIndex = startPage;
      var cueIndex = fromCue ?? 0;

      while (_readingActive && pageIndex < doc.pages.length) {
        _pageHasNoTextLayer = false;
        final cues =
            await _extractor.extractSentences(doc.pages[pageIndex], pageIndex);
        if (!_readingActive) break;
        _readingCues = cues;
        _readingPageIndex = pageIndex;

        if (cues.isEmpty) {
          // Trang không có lớp chữ (scan) → dừng ở đây thay vì im lặng đọc
          // xuyên sang trang khác; UI sẽ hiện gợi ý OCR/Text Mode.
          _pageHasNoTextLayer = true;
          _readingActive = false;
          _ttsState = PdfTtsState.idle;
          _currentSpeakingWord = null;
          notifyListeners();
          return;
        }

        if (cueIndex >= cues.length) {
          cueIndex = 0;
          pageIndex += 1;
          continue;
        }

        _tts.configure(
          speed: _ttsSpeed,
          language: _ttsLanguage == 'bilingual' ? 'en-US' : _ttsLanguage,
        );
        _ttsState = PdfTtsState.playing;
        notifyListeners();

        // `speakLines` không có tham số "bắt đầu từ dòng n" -> cắt danh sách,
        // và giữ `cueOffset` để chỉ số báo ra UI vẫn là chỉ số của CẢ TRANG
        // (overlay tô sáng theo `_readingCueIndex`).
        final allTexts = cues.map((c) => c.speakText).toList(growable: false);
        final cueOffset = (cueIndex > 0 && cueIndex < allTexts.length)
            ? cueIndex
            : 0;
        final texts =
            cueOffset == 0 ? allTexts : allTexts.sublist(cueOffset);
        await _tts.speakLines(
          texts,
          pauseBetween: const Duration(milliseconds: 140),
          onLineChanged: (i) {
            final index = cueOffset + i;
            _readingCueIndex = index;
            _currentSpeakingWord = _firstWordOf(cues[index].speakText);
            if (i > 0 &&
                cues[index].pageIndex != cues[index - 1].pageIndex) {
              _maybeJumpToCue(cues[index]);
            }
            notifyListeners();
          },
        );
        _readingCueIndex = cues.length - 1;
        notifyListeners();

        if (!_readingActive) break;

        // Auto-advance trang (đặc trưng reader chuyên nghiệp: nghe liên tục).
        if (_ttsAutoAdvance && pageIndex + 1 < doc.pages.length) {
          pageIndex += 1;
          cueIndex = 0;
          goToPage(pageIndex);
          continue;
        }
        break;
      }
    } catch (e) {
      debugPrint('PdfReaderController: TTS error: $e');
    } finally {
      _readingActive = false;
      _ttsState = PdfTtsState.idle;
      _currentSpeakingWord = null;
      notifyListeners();
    }
  }

  Future<void> pauseReading() async {
    if (!_readingActive) return;
    await _tts.pause();
    _ttsState = PdfTtsState.paused;
    notifyListeners();
  }

  Future<void> stopReading() async {
    _readingActive = false;
    _ttsState = PdfTtsState.idle;
    _currentSpeakingWord = null;
    _readingCueIndex = -1;
    await _tts.stop();
    notifyListeners();
  }

  /// Lùi/tới một câu. Đang dừng thì giữ nguyên trạng thái dừng.
  Future<void> stepSentence(int delta) async {
    if (_readingCues.isEmpty) return;
    final target = (_readingCueIndex + delta).clamp(0, _readingCues.length - 1);
    if (target == _readingCueIndex && _ttsState == PdfTtsState.playing) return;
    _readingCueIndex = target;
    final cue = _readingCues[target];
    _currentSpeakingWord = _firstWordOf(cue.speakText);
    _maybeJumpToCue(cue);
    notifyListeners();
    if (_readingActive) {
      await stopReading();
      await startReading(fromPage: cue.pageIndex, fromCue: target);
    }
  }

  void _maybeJumpToCue(PdfSentenceCue cue) {
    if (cue.pageIndex == _currentPage) return;
    goToPage(cue.pageIndex);
  }

  static String? _firstWordOf(String text) {
    final match = RegExp(r'[\p{L}\p{N}]+').firstMatch(text);
    return match?.group(0)?.toLowerCase();
  }

  Future<void> speakSelectedText() async {
    final text = _selectedText?.trim() ?? '';
    if (text.isEmpty) return;
    await speakText(text);
  }

  Future<void> speakText(String text) async {
    if (text.trim().isEmpty) return;
    _tts.configure(
      speed: _ttsSpeed,
      language: _ttsLanguage == 'bilingual' ? 'en-US' : _ttsLanguage,
    );
    _ttsState = PdfTtsState.playing;
    notifyListeners();
    await _tts.speak(text);
    _ttsState = PdfTtsState.idle;
    notifyListeners();
  }

  Future<void> stopTts() => stopReading();

  void setTtsLanguage(String lang) {
    _ttsLanguage = lang;
    notifyListeners();
  }

  void setTtsSpeed(double speed) {
    _ttsSpeed = speed.clamp(0.25, 2.0);
    _tts.configure(speed: _ttsSpeed);
    notifyListeners();
  }

  /// Trích text trang hiện tại (dùng cho TTS + lưu hàng loạt).
  Future<String> extractCurrentPageText() async {
    final doc = _document;
    if (doc == null) return '';
    final page = doc.pages[_currentPage];
    try {
      return await _extractor.extractPageText(page, _currentPage);
    } catch (e) {
      debugPrint('PdfReaderController: extractCurrentPageText error: $e');
      return '';
    }
  }

  // ─── Text Selection ──────────────────────────────────────
  /// Vùng chọn ĐÃ được viewer xác nhận: nối từ `textSelectionParams.onTextSelectionChange`.
  /// Đây là chỗ code cũ bị hở — `_SelectionBar` chờ `setSelection` mà chẳng ai
  /// gọi ở chế độ PDF, nên 6 hành động học tập không bao giờ hiện.
  void applyViewerSelection({
    required String text,
    required List<PdfSelectionFragment> fragments,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || fragments.isEmpty) {
      clearSelection(notify: true);
      return;
    }
    _selectedText = trimmed;
    _selectionFragments = fragments;
    _selectionSource = PdfSelectionSource.viewer;
    _selectionRect = _unionOf(fragments.map((f) => f.bounds));
    notifyListeners();
  }

  /// Vùng chọn từ Text Mode (`SelectableText`) — chỉ có offset toàn văn bản,
  /// nên ta tự quy về trang + rect để annotation vẫn reopen được.
  void applyTextModeSelection({required String text, int? startOffset, int? endOffset}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      clearSelection(notify: true);
      return;
    }
    _selectedText = trimmed;
    _selectionSource = PdfSelectionSource.textMode;
    _selectionFragments = [
      PdfSelectionFragment(
        pageIndex: _currentPage,
        startOffset: startOffset ?? 0,
        endOffset: endOffset ?? (text.length),
        bounds: Rect.zero,
      ),
    ];
    _selectionRect = null;
    notifyListeners();
  }

  static Rect? _unionOf(Iterable<Rect> rects) {
    Rect? out;
    for (final r in rects) {
      if (r == Rect.zero) continue;
      out = out == null ? r : out.expandToInclude(r);
    }
    return out;
  }

  /// `viewerSelectionCleared` để màn hình biết cần gọi
  /// `textSelectionDelegate.clearTextSelection()`.
  bool viewerSelectionShouldBeCleared = false;

  void clearSelection({bool notify = true, bool alsoClearViewer = true}) {
    if (_selectedText == null && _selectionRect == null) return;
    _selectedText = null;
    _selectionRect = null;
    _selectionFragments = const [];
    _selectionSource = PdfSelectionSource.none;
    viewerSelectionShouldBeCleared = alsoClearViewer;
    if (notify) notifyListeners();
  }

  void setSelection(String text, Rect rect) => applyTextModeSelection(
        text: text,
        startOffset: null,
        endOffset: null,
      );

  // ─── Annotations ────────────────────────────────────────
  Future<PdfAnnotation> addAnnotation({
    required int pageIndex,
    required Rect bounds,
    required String text,
    Color color = const Color(0xFFFFD54F),
    String? note,
    AnnotationType type = AnnotationType.highlight,
    List<Rect> lineRects = const [],
    int? textStartOffset,
    int? textEndOffset,
  }) async {
    final annotation = PdfAnnotation(
      // uuid: id theo millisecond từng va chạm khi lưu nhanh hai cái một lúc,
      // và `indexWhere((a) => a.id == id)` thì sửa/xoá nhầm sang cái kia.
      id: _uuid.v4(),
      pageIndex: pageIndex,
      bounds: bounds,
      lineRects: lineRects,
      selectedText: text,
      note: note,
      color: color,
      type: type,
      textStartOffset: textStartOffset,
      textEndOffset: textEndOffset,
      createdAt: DateTime.now(),
    );
    _annotations.add(annotation);
    await _persistAnnotations();
    notifyListeners();
    return annotation;
  }

  /// Bookmark trang hiện tại — một chạm, đúng kiểu ReadEra.
  Future<PdfAnnotation> toggleBookmark([int? pageIndex]) async {
    final page = pageIndex ?? _currentPage;
    final existing = _annotations
        .where((a) => a.pageIndex == page && a.type == AnnotationType.bookmark)
        .toList();
    if (existing.isNotEmpty) {
      _annotations.removeWhere(
          (a) => a.pageIndex == page && a.type == AnnotationType.bookmark);
      await _persistAnnotations();
      notifyListeners();
      return existing.first;
    }
    return addAnnotation(
      pageIndex: page,
      bounds: Rect.zero,
      text: '',
      type: AnnotationType.bookmark,
      color: const Color(0xFF64B5F6),
    );
  }

  Future<void> _persistAnnotations() async {
    final identity = _identity;
    if (identity == null) return;
    await _storage.persist(identity, _annotations);
  }

  Future<void> updateAnnotationNote(String id, String note) async {
    final idx = _annotations.indexWhere((a) => a.id == id);
    if (idx < 0) return;
    _annotations[idx] = _annotations[idx].copyWith(note: note);
    await _persistAnnotations();
    notifyListeners();
  }

  Future<void> updateAnnotationColor(String id, Color color) async {
    final idx = _annotations.indexWhere((a) => a.id == id);
    if (idx < 0) return;
    _annotations[idx] = _annotations[idx].copyWith(color: color);
    await _persistAnnotations();
    notifyListeners();
  }

  Future<void> deleteAnnotation(String id) async {
    _annotations.removeWhere((a) => a.id == id);
    await _persistAnnotations();
    notifyListeners();
  }

  Future<void> clearAnnotations() async {
    _annotations = <PdfAnnotation>[];
    final identity = _identity;
    if (identity != null) await _storage.clear(identity);
    notifyListeners();
  }

  // ─── Save to Memory Garden ───────────────────────────────
  VocabContext buildWordContext(
    PdfWordInfo wordInfo, {
    String? surroundingText,
    String? anchorText,
  }) {
    final displayText = wordInfo.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final snippet = ((surroundingText ?? '').trim().isNotEmpty
            ? surroundingText!.trim()
            : (wordInfo.contextSnippet ?? '').trim().isNotEmpty
                ? wordInfo.contextSnippet!.trim()
                : displayText)
        .trim();

    return VocabContext.fromPdf(
      fileName: fileName,
      page: wordInfo.pageIndex + 1,
      pageIndexHint: wordInfo.pageIndex,
      surroundingText: snippet,
      pdfPath: pdfPath,
      anchorText: (anchorText ?? displayText).trim(),
      textStartOffset: wordInfo.startOffset,
      textEndOffset: wordInfo.endOffset,
      rectHint: wordInfo.bounds,
    );
  }

  VocabContext buildSelectionContext(String selectedText) {
    final text = selectedText.trim();
    final first = _selectionFragments.isNotEmpty ? _selectionFragments.first : null;
    final page = first?.pageIndex ?? _currentPage;
    return VocabContext.fromPdf(
      fileName: fileName,
      page: page + 1,
      pageIndexHint: page,
      surroundingText: text,
      pdfPath: pdfPath,
      anchorText: text,
      textStartOffset: first?.startOffset,
      textEndOffset: first?.endOffset,
      rectHint: first?.bounds != null && first!.bounds != Rect.zero
          ? first.bounds
          : _selectionRect,
    );
  }

  void saveWordToMemory(PdfWordInfo wordInfo) {
    final word = wordInfo.text.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();
    if (word.isEmpty) return;

    VocabularyBridge.addFromAnalyzed(
      word: word,
      meaning: wordInfo.analyzed?.meaning,
      phonetic: wordInfo.analyzed?.phonetic,
      wordTypeName: wordInfo.analyzed?.wordType.name,
      cefrLevelName: wordInfo.analyzed?.cefrLevel.name,
      sourceFile: fileName,
    );

    final memoryContext = (wordInfo.contextSnippet ?? '').trim().isNotEmpty
        ? wordInfo.contextSnippet!.trim()
        : word;
    MemoryProvider.addWord(
      word: word,
      wordType: wordInfo.analyzed?.wordType.name,
      cefrLevel: wordInfo.analyzed?.cefrLevel.name,
      meaning: wordInfo.analyzed?.meaning,
      phonetic: wordInfo.analyzed?.phonetic,
      sourceFile: fileName,
      sourceLine: wordInfo.pageIndex,
      context: memoryContext,
      example: memoryContext,
    );

    refreshVocabularySignals(invalidate: [wordInfo.pageIndex]);
  }

  bool saveSelectedTextToWordList() {
    final text = _selectedText?.trim() ?? '';
    if (text.isEmpty) return false;

    final context = buildSelectionContext(text);

    final existed = VocabularyBridge.hasWord(text);
    VocabularyBridge.addContextual(
      text: text,
      meaning: '',
      example: text,
      context: context,
      forceType: text.contains(' ')
          ? VocabularyType.phrase
          : VocabularyType.word,
    );
    refreshVocabularySignals();
    return !existed;
  }

  void saveSelectedTextToMemory() {
    if (_selectedText == null || _selectedText!.isEmpty) return;
    MemoryProvider.addWord(
      word: _selectedText!.trim(),
      sourceFile: fileName,
      sourceLine: _currentPage,
      context: _selectedText!.trim(),
      example: _selectedText!.trim(),
      tags: const ['pdf_reader'],
    );
  }

  /// Tạo highlight/ghi chú từ vùng chọn, giữ ĐỦ ngữ cảnh reopen:
  ///  • viewer selection → rect PDF thật + offset trong trang;
  ///  • text-mode selection → rect suy lại từ charRects của trang chứa nó.
  Future<PdfAnnotation?> addAnnotationFromSelection({
    required String note,
    Color color = const Color(0xFFFFD54F),
    AnnotationType type = AnnotationType.highlight,
  }) async {
    final text = _selectedText?.trim() ?? '';
    if (text.isEmpty) return null;

    if (_selectionSource == PdfSelectionSource.viewer &&
        _selectionFragments.isNotEmpty) {
      final first = _selectionFragments.first;
      return addAnnotation(
        pageIndex: first.pageIndex,
        bounds: _unionOf(_selectionFragments.map((f) => f.bounds)) ?? Rect.zero,
        lineRects: _selectionFragments
            .map((f) => f.bounds)
            .where((r) => r != Rect.zero)
            .toList(growable: false),
        text: text,
        color: color,
        type: type,
        note: note.trim().isEmpty ? null : note.trim(),
        textStartOffset: first.startOffset,
        textEndOffset: _selectionFragments.last.endOffset,
      );
    }

    final resolved = await resolveTextModeSelectionToPage(text);
    return addAnnotation(
      pageIndex: resolved.pageIndex,
      bounds: resolved.rect ?? Rect.zero,
      text: text,
      color: color,
      type: type,
      note: note.trim().isEmpty ? null : note.trim(),
      textStartOffset: resolved.startOffset,
      textEndOffset: resolved.endOffset,
    );
  }

  /// Text Mode chọn trên một chuỗi gộp cả tài liệu → phải tìm lại xem đoạn đó
  /// rơi vào trang nào và rect ra sao, nếu không highlight sẽ mở về Rect.zero
  /// và mất tác dụng reopen.
  Future<({int pageIndex, int? startOffset, int? endOffset, Rect? rect})>
      resolveTextModeSelectionToPage(String text) async {
    final needle = _normalizeForSearch(text);
    final doc = _document;
    if (doc == null || needle.isEmpty) {
      return (pageIndex: _currentPage, startOffset: null, endOffset: null, rect: null);
    }
    for (int i = 0; i < doc.pages.length; i++) {
      final pageText = await _extractor.extractPageText(doc.pages[i], i);
      if (pageText.isEmpty) continue;
      final hay = _normalizeForSearch(pageText);
      final at = hay.indexOf(needle);
      if (at < 0) continue;
      return (
        pageIndex: i,
        startOffset: at,
        endOffset: at + needle.length,
        rect: null,
      );
    }
    return (
      pageIndex: _currentPage,
      startOffset: null,
      endOffset: null,
      rect: null
    );
  }

  static String _normalizeForSearch(String s) =>
      s.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();

  bool markWordDifficulty(PdfWordInfo wordInfo, DifficultyLevel difficulty) {
    final word =
        wordInfo.text.replaceAll(RegExp(r'[^\w\s]'), '').trim().toLowerCase();
    if (word.isEmpty) return false;

    final context = buildWordContext(
      wordInfo,
      surroundingText: (wordInfo.contextSnippet ?? '').trim().isNotEmpty
          ? wordInfo.contextSnippet!.trim()
          : (wordInfo.analyzed?.example?.trim().isNotEmpty ?? false)
              ? wordInfo.analyzed!.example!.trim()
              : word,
      anchorText: word,
    );

    VocabularyBridge.upsertDifficulty(
      text: word,
      difficulty: difficulty,
      meaning: wordInfo.analyzed?.meaning ?? '',
      phonetic: wordInfo.analyzed?.phonetic,
      forceType:
          word.contains(' ') ? VocabularyType.phrase : VocabularyType.word,
      context: context,
    );

    refreshVocabularySignals();
    return true;
  }

  /// Làm mới các tín hiệu "từ đã lưu". Mặc định chỉ huỷ cache những trang đang
  /// thấy — `clear()` toàn bộ từng khiến mỗi lần lưu 1 từ phải re-extract cả
  /// tài liệu (giật khi đang bật tô màu).
  void refreshVocabularySignals({List<int>? invalidate}) {
    final pages = invalidate ??
        <int>{
          _currentPage,
          if (_currentPage + 1 < totalPages) _currentPage + 1,
        }.toList();
    _extractor.invalidatePages(pages);
    for (final p in pages) {
      _pageWords.remove(p);
    }
    for (final p in pages) {
      _loadWordsForPage(p);
    }
    notifyListeners();
  }

  // ─── Dispose ─────────────────────────────────────────────
  @override
  void dispose() {
    _readingActive = false;
    ReaderDisplaySettings().removeListener(_onDisplaySettingsChanged);
    _tts.stop();
    _extractor.clearCache();
    super.dispose();
  }
}
