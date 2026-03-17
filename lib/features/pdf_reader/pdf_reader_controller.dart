import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../features/tts/tts_service.dart';
import '../../models/color_mode.dart';
import '../../screens/memory_mode/memory_provider.dart';
import 'models/pdf_annotation.dart';
import 'models/pdf_word_info.dart';
import 'services/pdf_annotation_storage.dart';
import 'services/pdf_text_extractor.dart';

enum PdfTtsState { idle, loading, playing, paused }

enum PdfViewMode { pdfView, textMode }

class PdfReaderController extends ChangeNotifier {
  final String pdfPath;
  final PdfAnnotationStorage _storage = PdfAnnotationStorage();
  final PdfTextExtractor _extractor = PdfTextExtractor();
  final TtsService _tts = TtsService();

  PdfReaderController({required this.pdfPath}) {
    _init();
  }

  // ─── Document ───────────────────────────────────────────
  PdfDocument? _document;
  PdfDocument? get document => _document;
  bool get isDocumentLoaded => _document != null;

  int _currentPage = 0;
  int get currentPage => _currentPage;
  int get totalPages => _document?.pages.length ?? 0;

  // ─── View Mode ───────────────────────────────────────────
  PdfViewMode _viewMode = PdfViewMode.pdfView;
  PdfViewMode get viewMode => _viewMode;

  // ─── Color Mode ─────────────────────────────────────────
  ColorMode _colorMode = ColorMode.none;
  ColorMode get colorMode => _colorMode;

  // ─── Words overlay ───────────────────────────────────────
  /// Cache: pageIndex → words với positions
  final Map<int, List<PdfWordInfo>> _pageWords = {};
  bool _isLoadingWords = false;
  bool get isLoadingWords => _isLoadingWords;

  List<PdfWordInfo> getWordsForPage(int pageIndex) =>
      _pageWords[pageIndex] ?? [];

  // ─── TTS ────────────────────────────────────────────────
  PdfTtsState _ttsState = PdfTtsState.idle;
  PdfTtsState get ttsState => _ttsState;
  String? _currentSpeakingWord;
  String? get currentSpeakingWord => _currentSpeakingWord;

  String _ttsLanguage = 'en-US'; // 'en-US' | 'vi-VN' | 'bilingual'
  String get ttsLanguage => _ttsLanguage;
  double _ttsSpeed = 0.9;
  double get ttsSpeed => _ttsSpeed;

  // ─── Annotations ────────────────────────────────────────
  List<PdfAnnotation> _annotations = [];
  List<PdfAnnotation> get annotations => _annotations;
  List<PdfAnnotation> annotationsForPage(int pageIndex) =>
      _annotations.where((a) => a.pageIndex == pageIndex).toList();

  // ─── Selected Text ───────────────────────────────────────
  String? _selectedText;
  String? get selectedText => _selectedText;
  Rect? _selectionRect;
  Rect? get selectionRect => _selectionRect;

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

  // ─── Init ────────────────────────────────────────────────
  Future<void> _init() async {
    await _storage.initialize();
    _annotations = _storage.loadAnnotations(pdfPath);
    _currentPage = _storage.loadLastPage(pdfPath);
    notifyListeners();
  }

  /// Gọi từ PdfViewer khi document load xong
  void onDocumentLoaded(PdfDocument doc) {
    _document = doc;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();

    // Preload words cho trang hiện tại
    _loadWordsForPage(_currentPage);
  }

  void onDocumentError(Object error) {
    _isLoading = false;
    _errorMessage = error.toString();
    notifyListeners();
  }

  // ─── Navigation ──────────────────────────────────────────
  void onPageChanged(int pageIndex) {
    _currentPage = pageIndex;
    _storage.saveLastPage(pdfPath, pageIndex);
    notifyListeners();

    // Preload words cho trang mới và trang kế tiếp
    _loadWordsForPage(pageIndex);
    if (pageIndex + 1 < totalPages) {
      _loadWordsForPage(pageIndex + 1);
    }
  }

  // ─── Color Mode ──────────────────────────────────────────
  void setColorMode(ColorMode mode) {
    if (_colorMode == mode) return;
    _colorMode = mode;

    // Clear cache để rebuild với mode mới
    _pageWords.clear();
    _extractor.clearCache();
    notifyListeners();

    // Reload words cho trang hiện tại
    _loadWordsForPage(_currentPage);
  }

  void cycleColorMode() {
    setColorMode(_colorMode.next);
  }

  // ─── Word Loading ────────────────────────────────────────
  Future<void> _loadWordsForPage(int pageIndex) async {
    if (_document == null) return;
    if (_pageWords.containsKey(pageIndex) && _colorMode == ColorMode.none) {
      return; // Already cached
    }
    if (pageIndex < 0 || pageIndex >= _document!.pages.length) return;

    _isLoadingWords = true;
    notifyListeners();

    try {
      final page = _document!.pages[pageIndex];
      final words = await _extractor.extractWordsWithPositions(
        page,
        pageIndex,
        _colorMode,
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

    if (_extractedFullText.isEmpty) {
      _isExtractingText = true;
      notifyListeners();
      _extractedFullText = await _extractor.extractFullText(_document!);
      _isExtractingText = false;
      notifyListeners();
    }
  }

  void switchToPdfMode() {
    _viewMode = PdfViewMode.pdfView;
    notifyListeners();
  }

  // ─── TTS ─────────────────────────────────────────────────
  Future<void> speakCurrentPage() async {
    if (_document == null) return;
    if (_ttsState == PdfTtsState.playing) {
      await stopTts();
      return;
    }

    _ttsState = PdfTtsState.loading;
    notifyListeners();

    try {
      final page = _document!.pages[_currentPage];
      final text = await _extractor.extractPageText(page, _currentPage);
      if (text.isEmpty) {
        _ttsState = PdfTtsState.idle;
        notifyListeners();
        return;
      }

      _tts.configure(speed: _ttsSpeed);

      if (_ttsLanguage == 'bilingual') {
        await _speakBilingual(text);
      } else {
        _ttsState = PdfTtsState.playing;
        _tts.configure(language: _ttsLanguage);
        notifyListeners();
        await _tts.speak(text);
      }
    } catch (e) {
      debugPrint('PdfReaderController: TTS error: $e');
    } finally {
      _ttsState = PdfTtsState.idle;
      _currentSpeakingWord = null;
      notifyListeners();
    }
  }

  Future<void> speakSelectedText() async {
    if (_selectedText == null || _selectedText!.isEmpty) return;
    _tts.configure(speed: _ttsSpeed);
    _tts.configure(
        language: _ttsLanguage == 'bilingual' ? 'en-US' : _ttsLanguage);
    await _tts.speak(_selectedText!);
  }

  Future<void> speakText(String text) async {
    _tts.configure(speed: _ttsSpeed);
    _ttsState = PdfTtsState.playing;
    _tts.configure(
        language: _ttsLanguage == 'bilingual' ? 'en-US' : _ttsLanguage);
    notifyListeners();
    await _tts.speak(text);
    _ttsState = PdfTtsState.idle;
    notifyListeners();
  }

  Future<void> _speakBilingual(String englishText) async {
    // Tách thành câu
    final sentences = englishText
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();

    _ttsState = PdfTtsState.playing;
    notifyListeners();

    for (final sentence in sentences) {
      if (_ttsState != PdfTtsState.playing) break;

      // Đọc tiếng Anh
      _tts.configure(language: 'en-US');
      await _tts.speak(sentence);

      if (_ttsState != PdfTtsState.playing) break;

      // Pause nhỏ
      await Future.delayed(const Duration(milliseconds: 400));

      // Note: Dịch thật sự cần API - ở đây bỏ qua phần dịch
      // Nếu có TranslationService thì gọi ở đây
    }
  }

  Future<void> stopTts() async {
    _ttsState = PdfTtsState.idle;
    _currentSpeakingWord = null;
    await _tts.stop();
    notifyListeners();
  }

  void setTtsLanguage(String lang) {
    _ttsLanguage = lang;
    notifyListeners();
  }

  void setTtsSpeed(double speed) {
    _ttsSpeed = speed.clamp(0.25, 2.0);
    _tts.configure(speed: _ttsSpeed);
    notifyListeners();
  }

  // ─── Text Selection ──────────────────────────────────────
  void setSelection(String text, Rect rect) {
    _selectedText = text;
    _selectionRect = rect;
    notifyListeners();
  }

  void clearSelection() {
    _selectedText = null;
    _selectionRect = null;
    notifyListeners();
  }

  // ─── Annotations ─────────────────────────────────────────
  Future<PdfAnnotation> addAnnotation({
    required int pageIndex,
    required Rect bounds,
    required String text,
    Color color = const Color(0xFFFFD54F),
    String? note,
  }) async {
    final annotation = PdfAnnotation(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      pageIndex: pageIndex,
      bounds: bounds,
      selectedText: text,
      note: note,
      color: color,
      createdAt: DateTime.now(),
    );
    _annotations.add(annotation);
    await _storage.addAnnotation(pdfPath, annotation);
    notifyListeners();
    return annotation;
  }

  Future<void> updateAnnotationNote(String id, String note) async {
    final idx = _annotations.indexWhere((a) => a.id == id);
    if (idx < 0) return;
    _annotations[idx] = _annotations[idx].copyWith(note: note);
    await _storage.updateAnnotation(pdfPath, _annotations[idx]);
    notifyListeners();
  }

  Future<void> deleteAnnotation(String id) async {
    _annotations.removeWhere((a) => a.id == id);
    await _storage.deleteAnnotation(pdfPath, id);
    notifyListeners();
  }

  // ─── Save to Memory Garden ───────────────────────────────
  void saveWordToMemory(PdfWordInfo wordInfo) {
    final word = wordInfo.text.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();
    if (word.isEmpty) return;

    MemoryProvider.addWord(
      word: word,
      wordType: wordInfo.analyzed?.wordType.name,
      cefrLevel: wordInfo.analyzed?.cefrLevel.name,
      meaning: wordInfo.analyzed?.meaning,
      phonetic: wordInfo.analyzed?.phonetic,
      sourceFile: pdfPath.split('/').last,
      sourceLine: wordInfo.pageIndex,
    );
  }

  void saveSelectedTextToMemory() {
    if (_selectedText == null || _selectedText!.isEmpty) return;
    MemoryProvider.addWord(
      word: _selectedText!.trim(),
      sourceFile: pdfPath.split('/').last,
      sourceLine: _currentPage,
    );
  }

  // ─── Dispose ─────────────────────────────────────────────
  @override
  void dispose() {
    _tts.stop();
    _extractor.clearCache();
    super.dispose();
  }
}
