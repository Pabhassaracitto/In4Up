// lib/providers/text_provider.dart
// Chỉ thêm các phần thay đổi - giữ nguyên toàn bộ code cũ

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:in4up_stt/models/stt_result.dart';

import '../features/grammar/models/grammar_category.dart';
import '../features/grammar/models/grammar_highlight_preset.dart';
import '../features/grammar/models/grammar_highlight_settings.dart';
import '../features/grammar/models/grammar_highlight_style.dart';
import '../features/grammar/models/grammar_palette.dart';
import '../features/grammar/services/grammar_preset_library_service.dart';
import '../features/grammar/services/grammar_settings_service.dart';
import '../features/writing/models/writing_source_request.dart';
import '../features/translation/text_provider_translation.dart';
import '../features/translation/translation_display_mode.dart';
import '../features/tts/tts_service.dart';
import '../models/color_mode.dart';
import '../models/text_item.dart';
import '../models/text_segment.dart';
import '../models/vocab_context.dart';
import '../models/vocabulary_type.dart';
import '../models/word_analysis.dart';
import '../screens/memory_mode/memory_provider.dart';
import '../services/storage_service.dart'; // ★ THÊM
import '../services/syntax_highlighter_service.dart';
import '../services/text_splitter_service.dart';
import 'vocabulary_bridge.dart';
import 'package:in4up_core/vocab_level_difficulty.dart';

enum ReadSubMode { reading, listening, translation, driving }

enum TtsPlaybackOwner {
  none,
  allLines, // Play toàn bộ / song ngữ tuần tự
  preview, // Icon loa / swipe phát âm 1 dòng
  segment, // Segment playback
  vocabReview, // Đọc từ khó
}

enum TextSourceType {
  manual,
  localFile,
  cloud,
  generated,
}

class TextProvider extends ChangeNotifier with TranslationMixin {
  final TtsService _ttsService = TtsService();
  final StorageService _storage = StorageService();
  Future<int> _startExclusiveTtsSession(
    TtsPlaybackOwner owner, {
    bool clearSegmentState = true,
  }) async {
    _ttsSessionId++;
    final sessionId = _ttsSessionId;

    // Dừng mọi âm thanh TTS cũ trước khi bắt đầu cái mới
    await _ttsService.stop();

    _ttsOwner = owner;
    _isSpeaking = owner == TtsPlaybackOwner.allLines;
    _isPlayingSegment = owner == TtsPlaybackOwner.segment ||
        owner == TtsPlaybackOwner.vocabReview;

    if (clearSegmentState &&
        owner != TtsPlaybackOwner.segment &&
        owner != TtsPlaybackOwner.vocabReview) {
      _currentPlayingSegment = null;
      _currentRepeatIndex = 0;
    }

    notifyListeners();
    return sessionId;
  }

  bool _isActiveSession(int sessionId, TtsPlaybackOwner owner) {
    return _ttsSessionId == sessionId && _ttsOwner == owner;
  }

  void _finishTtsSession(
    int sessionId,
    TtsPlaybackOwner owner, {
    bool clearReadingCursor = false,
  }) {
    if (!_isActiveSession(sessionId, owner)) return;

    _ttsOwner = TtsPlaybackOwner.none;

    if (owner == TtsPlaybackOwner.allLines) {
      _isSpeaking = false;
      if (clearReadingCursor) {
        _currentLineIndex = -1;
      }
    }

    if (owner == TtsPlaybackOwner.segment ||
        owner == TtsPlaybackOwner.vocabReview) {
      _isPlayingSegment = false;
      _currentPlayingSegment = null;
      _currentRepeatIndex = 0;
    }

    notifyListeners();
  }

//take over broadcasting rights
  Future<void> _stopAllTts({
    bool clearReadingCursor = true,
  }) async {
    _ttsSessionId++; // invalidate mọi session cũ

    _ttsOwner = TtsPlaybackOwner.none;
    _isSpeaking = false;
    _isPlayingSegment = false;
    _currentPlayingSegment = null;
    _currentRepeatIndex = 0;

    if (clearReadingCursor) {
      _currentLineIndex = -1;
    }

    await _ttsService.stop();
    notifyListeners();
  }

  // ====================  TEXT DATA ====================
  TextDocument? _currentDocument;
  List<TextItem> _lines = [];
  int _currentLineIndex = -1;
  int? _focusCueLineIndex;
  int _focusCueVersion = 0;
  String? _selectedText;
  String _fullText = '';
  String? _currentTextPath;
  TextSourceType _currentSourceType = TextSourceType.manual;
  String? _currentCloudId;
  String? _currentTextCategory;

  // ==================== WRITING HANDOFF ====================
  WritingSourceRequest? _writingSourceRequest;
  int _writingSourceVersion = 0;

  // ==================== WORD ANALYSIS ====================
  List<List<AnalyzedWord>> _analyzedLines = [];
  ColorMode _colorMode = ColorMode.none;
  GrammarHighlightSettings _grammarSettings =
      GrammarHighlightSettings.defaults();
  List<GrammarHighlightPreset> _availableGrammarPresets =
      GrammarHighlightPresets.defaults();

  // ==================== TEXT SEGMENTS ====================
  final List<TextSegment> _segments = [];
  SelectedTextInfo? _selectedTextInfo;

  // ==================== TTS SETTINGS ====================
  double _ttsSpeed = 1.0;
  double _ttsPitch = 1.0;
  String _ttsLanguage = 'auto';
  bool _isSpeaking = false;
  //TTS session management
  TtsPlaybackOwner _ttsOwner = TtsPlaybackOwner.none;
  int _ttsSessionId = 0;

  TtsPlaybackOwner get ttsOwner => _ttsOwner;
  bool get isPreviewSpeaking => _ttsOwner == TtsPlaybackOwner.preview;
  bool get isAnyTtsActive => _ttsOwner != TtsPlaybackOwner.none;
  // ==================== SEGMENT PLAYBACK ====================
  bool _isPlayingSegment = false;
  TextSegment? _currentPlayingSegment;
  int _currentRepeatIndex = 0;

  // ==================== DISPLAY SETTINGS ====================
  double _fontSize = 18.0;
  // bool _showTranslation = true; // REMOVED
  bool _showWordTypes = false;
  bool _showLineNumbers = true;
  bool _useAutoSplit = true; // Mặc định bật tách dòng thông minh
  ReadSubMode _subMode = ReadSubMode.reading;
  TextAlign _textAlign = TextAlign.left; // Mặc định căn lề trái

  // ==================== GETTERS ====================
  TextDocument? get currentDocument => _currentDocument;
  @override
  List<TextItem> get lines => _lines;
  int get currentLineIndex => _currentLineIndex;
  int? get focusCueLineIndex => _focusCueLineIndex;
  int get focusCueVersion => _focusCueVersion;
  String? get selectedText => _selectedText;
  String get fullText => _fullText;
  bool get hasLyrics => _lines.isNotEmpty;
  String? get currentTextPath => _currentTextPath;
  TextSourceType get currentSourceType => _currentSourceType;
  String? get currentCloudId => _currentCloudId;
  String? get currentTextCategory => _currentTextCategory;
  WritingSourceRequest? get writingSourceRequest => _writingSourceRequest;
  int get writingSourceVersion => _writingSourceVersion;
  bool get isCurrentTextFromCloud =>
      _currentSourceType == TextSourceType.cloud && _currentCloudId != null;
  String? get currentContextSourceRef {
    if (isCurrentTextFromCloud && _currentCloudId != null) return _currentCloudId;
    if (_currentTextPath != null && _currentTextPath!.trim().isNotEmpty) {
      return _currentTextPath;
    }
    return null;
  }

  String? get currentContextSourceRefType {
    if (isCurrentTextFromCloud && _currentCloudId != null) return 'cloudText';
    if (_currentTextPath != null && _currentTextPath!.trim().isNotEmpty) {
      return 'localText';
    }
    return null;
  }

  List<List<AnalyzedWord>> get analyzedLines => _analyzedLines;
  ColorMode get colorMode => _colorMode;
  GrammarHighlightSettings get grammarSettings => _grammarSettings;
  List<GrammarHighlightPreset> get availableGrammarPresets =>
      List.unmodifiable(_availableGrammarPresets);
  GrammarPalette get activeGrammarPalette =>
      GrammarPalettes.byId(_grammarSettings.paletteId);
  GrammarHighlightPreset get activeGrammarPreset =>
      _findGrammarPresetById(_grammarSettings.activePresetId);
  List<TextSegment> get segments => List.unmodifiable(_segments);
  SelectedTextInfo? get selectedTextInfo => _selectedTextInfo;
  double get ttsSpeed => _ttsSpeed;
  double get ttsPitch => _ttsPitch;
  String get ttsLanguage => _ttsLanguage;
  bool get isSpeaking => _isSpeaking;
  bool get isPlayingSegment => _isPlayingSegment;
  TextSegment? get currentPlayingSegment => _currentPlayingSegment;
  int get currentRepeatIndex => _currentRepeatIndex;
  double get fontSize => _fontSize;
  bool get showTranslation =>
      translationDisplayMode != TranslationDisplayMode.hidden; // CHANGED
  bool get showWordTypes => _showWordTypes;
  bool get showLineNumbers => _showLineNumbers;
  bool get useAutoSplit => _useAutoSplit;
  ReadSubMode get subMode => _subMode;
  TextAlign get textAlign => _textAlign;

  // ==================== CONSTRUCTOR ====================

  TextProvider() {
    _restoreFromStorage();
    unawaited(_restoreGrammarPresetLibrary());
    unawaited(_restoreGrammarSettings());
  }

  // ★ THÊM: Restore settings
  void _restoreFromStorage() {
    if (!_storage.isInitialized) return;

    try {
      _fontSize = _storage.getFontSize();

      // Đảm bảo tốc độ mặc định là 1.0 nếu chưa có cấu hình hoặc cấu hình cũ là 1.75
      final savedSpeed = _storage.getTtsSpeed();
      _ttsSpeed = (savedSpeed == 1.75 || savedSpeed == 0.0) ? 1.0 : savedSpeed;
      _ttsService.configure(
        speed: _ttsSpeed,
        language: 'auto',
        autoDetect: true,
      );

      restoreTranslationTargetLanguage(
        _storage.getTranslationTargetLanguage(),
      );

      if (_storage.getShowTranslation()) {
        setTranslationDisplayMode(TranslationDisplayMode.stackedBelow);
      } else {
        setTranslationDisplayMode(TranslationDisplayMode.hidden);
      }

      // Restore color mode
      final savedColorMode = _storage.getColorMode();
      _colorMode = ColorMode.values.firstWhere(
        (m) => m.name == savedColorMode,
        orElse: () => ColorMode.none,
      );

      // Restore alignment
      // final savedAlign = _storage.getTextAlign(); // Tạm thời bỏ qua nếu StorageService chưa có
      // _textAlign = savedAlign == 'center' ? TextAlign.center : TextAlign.left;

      // Restore text segments
      final savedSegments = _storage.getAllTextSegments();
      _segments.addAll(savedSegments);

      // Restore saved words
      // (savedWords sẽ được load lazy khi cần)

      debugPrint('✅ TextProvider restored: '
          'fontSize=$_fontSize, '
          'colorMode=${_colorMode.name}, '
          'segments=${_segments.length}');
    } catch (e) {
      debugPrint('⚠️ Error restoring TextProvider: $e');
    }
  }

  GrammarHighlightPreset _findGrammarPresetById(String? presetId) {
    for (final preset in _availableGrammarPresets) {
      if (preset.id == presetId) return preset;
    }
    return GrammarHighlightPresets.byId(presetId);
  }

  Future<void> _restoreGrammarPresetLibrary() async {
    try {
      _availableGrammarPresets =
          await GrammarPresetLibraryService.loadAllPresets();
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ Error restoring grammar preset library: $e');
    }
  }

  Future<void> _refreshGrammarPresetLibrary() async {
    _availableGrammarPresets = await GrammarPresetLibraryService.loadAllPresets();
    notifyListeners();
  }

  Future<void> refreshGrammarPresetLibrary() {
    return _refreshGrammarPresetLibrary();
  }

  Future<void> _restoreGrammarSettings() async {
    try {
      _grammarSettings = await GrammarSettingsService.load();
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ Error restoring grammar settings: $e');
    }
  }

  Future<void> _saveGrammarSettings() async {
    try {
      await GrammarSettingsService.save(_grammarSettings);
    } catch (e) {
      debugPrint('⚠️ Error saving grammar settings: $e');
    }
  }

  Future<void> setGrammarSettings(GrammarHighlightSettings settings) async {
    _grammarSettings = settings;
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
    return setGrammarSettings(_grammarSettings.copyWith(
      activePresetId: 'custom',
      visibleCategories: next,
    ));
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

  Future<void> setGrammarLegendCollapsed(bool collapsed) {
    return setGrammarSettings(_grammarSettings.copyWith(legendCollapsed: collapsed));
  }

  // ==================== TEXT MANAGEMENT ====================

  void loadText(String content, {String? title}) {
    _writingSourceRequest = null;
    _parsePlainText(content, title: title);
    _setSourceMeta(sourceType: TextSourceType.manual);
  }

  void loadFromString(
    String content, {
    String? title,
    TextSourceType sourceType = TextSourceType.manual,
    String? localPath,
    String? cloudId,
    String? category,
  }) {
    _writingSourceRequest = null;
    _parsePlainText(content, title: title);
    _setSourceMeta(
      sourceType: sourceType,
      localPath: localPath,
      cloudId: cloudId,
      category: category,
    );
  }

  /// Chuyển nội dung từ Web/PDF Reader thẳng sang một nhiệm vụ trong tab Viết.
  ///
  /// Reader chỉ chuẩn bị nguồn và ý định. Writing Studio vẫn cho phép người học
  /// đổi sang bất kỳ dạng bài nào sau khi quay lại.
  void loadWritingSource(
    String content, {
    required String title,
    required WritingTaskType task,
    required WritingSourceKind kind,
    required String sourceLabel,
    bool isExcerpt = false,
  }) {
    loadFromString(
      content,
      title: title,
      sourceType: TextSourceType.generated,
    );
    _writingSourceRequest = WritingSourceRequest(
      task: task,
      kind: kind,
      sourceLabel: sourceLabel,
      isExcerpt: isExcerpt,
    );
    _writingSourceVersion++;
    notifyListeners();
  }

  Future<void> loadTextFile(String path, {String? title}) async {
    try {
      _writingSourceRequest = null;
      final file = File(path);
      if (!await file.exists()) {
        debugPrint('TextProvider.loadTextFile: File not found: $path');
        return;
      }

      final content = await file.readAsString();
      final lower = path.toLowerCase();
      final docTitle = title ?? _extractFileName(path);

      if (lower.endsWith('.lrc')) {
        _parseLrc(content, title: docTitle);
      } else if (lower.endsWith('.srt')) {
        _parseSrt(content, title: docTitle);
      } else {
        _parsePlainText(content, title: docTitle);
      }

      _setSourceMeta(
        sourceType: TextSourceType.localFile,
        localPath: path,
      );

      // ★ THÊM: Save last text path
      _storage.saveLastTextPath(path);
    } catch (e) {
      debugPrint('TextProvider.loadTextFile error: $e');
    }
  }

  void updateFullText(String newText) {
    _parsePlainText(newText, title: _currentDocument?.title);
  }

  void _setSourceMeta({
    required TextSourceType sourceType,
    String? localPath,
    String? cloudId,
    String? category,
  }) {
    _currentSourceType = sourceType;
    _currentTextPath = localPath;
    _currentCloudId = cloudId;
    _currentTextCategory = category;
  }

  void clearText() {
    _lines = [];
    _analyzedLines = [];
    _currentDocument = null;
    _currentLineIndex = -1;
    _focusCueLineIndex = null;
    _selectedText = null;
    _selectedTextInfo = null;
    _fullText = '';
    _segments.clear();
    _currentTextPath = null;
    _currentCloudId = null;
    _currentTextCategory = null;
    _currentSourceType = TextSourceType.manual;
    _writingSourceRequest = null;
    notifyListeners();
  }

  void clearSelection() {
    _selectedText = null;
    _selectedTextInfo = null;
    notifyListeners();
  }

  void selectText(String text) {
    _selectedText = text;
    notifyListeners();
  }

  void setCurrentLine(int index) {
    if (index >= 0 && index < _lines.length) {
      _currentLineIndex = index;
      notifyListeners();
    }
  }

  void focusLineCue(int index, {Duration duration = const Duration(seconds: 2)}) {
    if (index < 0 || index >= _lines.length) return;
    _currentLineIndex = index;
    _focusCueLineIndex = index;
    _focusCueVersion++;
    final version = _focusCueVersion;
    notifyListeners();

    Future.delayed(duration, () {
      if (_focusCueVersion != version) return;
      if (_focusCueLineIndex == index) {
        _focusCueLineIndex = null;
        notifyListeners();
      }
    });
  }

  String _extractFileName(String path) {
    return path.split(Platform.pathSeparator).last;
  }

  void _parsePlainText(String content, {String? title}) {
    _fullText = content;

    List<String> lineStrings;
    if (_useAutoSplit) {
      // Mặc định tách dòng thông minh
      lineStrings = TextSplitterService.split(content, mode: SplitMode.smart);
    } else {
      // Hiển thị nguyên bản (theo dòng trong file)
      lineStrings =
          content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    }

    _lines = lineStrings.asMap().entries.map((entry) {
      return TextItem(
        id: 'line_${entry.key}',
        content: entry.value.trim(),
      );
    }).toList();

    _analyzedLines = SyntaxHighlighterService.analyzeLines(
      _lines.map((l) => l.content).toList(),
    );

    _currentDocument = TextDocument(
      id: _currentDocument?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: title ?? _currentDocument?.title ?? 'Untitled',
      lines: _lines,
      createdAt: _currentDocument?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _currentLineIndex = -1;
    _focusCueLineIndex = null;
    _selectedTextInfo = null;
    _selectedText = null;
    notifyListeners();
  }

  // ★ THÊM: Phương thức để load kết quả từ STT
  void loadFromSttResult(SttResult result) {
    _writingSourceRequest = null;
    _fullText = result.fullText;
    _lines = result.segments.map((seg) {
      return TextItem(
        id: seg.uid,
        content: seg.text,
        startTime: seg.startDuration,
        endTime: seg.endDuration,
      );
    }).toList();

    _analyzedLines = SyntaxHighlighterService.analyzeLines(
      _lines.map((l) => l.content).toList(),
    );

    _currentDocument = TextDocument(
      id: result.audioFingerprint.isNotEmpty
          ? result.audioFingerprint
          : DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'STT Result',
      lines: _lines,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _currentLineIndex = -1;
    _selectedTextInfo = null;
    _selectedText = null;
    _setSourceMeta(sourceType: TextSourceType.generated);
    notifyListeners();
  }

  void _parseLrc(String content, {String? title}) {
    _fullText = content;
    _lines = [];
    final regex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');
    final rawLines = content.split('\n');

    for (final raw in rawLines) {
      final match = regex.firstMatch(raw);
      if (match == null) continue;

      final minutes = int.tryParse(match.group(1) ?? '') ?? 0;
      final seconds = int.tryParse(match.group(2) ?? '') ?? 0;
      final fraction = match.group(3) ?? '00';
      // Bỏ inline word timestamps `<mm:ss.cs>` để không lộ ra chữ hiển thị.
      var text = (match.group(4) ?? '').trim();
      text = text.replaceAll(RegExp(r'<\d{2}:\d{2}\.\d{2,3}>'), '').trim();
      if (text.isEmpty) continue;

      final ms =
          fraction.length == 2 ? int.parse(fraction) * 10 : int.parse(fraction);
      final start = Duration(
        minutes: minutes,
        seconds: seconds,
        milliseconds: ms,
      );

      _lines.add(TextItem(
        id: 'line_${_lines.length}',
        content: text,
        startTime: start,
      ));
    }

    for (int i = 0; i < _lines.length - 1; i++) {
      final nextStart = _lines[i + 1].startTime;
      if (nextStart != null) {
        _lines[i] = _lines[i].copyWith(endTime: nextStart);
      }
    }

    _analyzedLines = SyntaxHighlighterService.analyzeLines(
      _lines.map((l) => l.content).toList(),
    );

    _currentDocument = TextDocument(
      id: _currentDocument?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: title ?? _currentDocument?.title ?? 'Untitled',
      lines: _lines,
      createdAt: _currentDocument?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _currentLineIndex = -1;
    _focusCueLineIndex = null;
    _selectedTextInfo = null;
    _selectedText = null;
    notifyListeners();
  }

  void _parseSrt(String content, {String? title}) {
    _fullText = content;
    _lines = [];
    final blocks = content.split(RegExp(r'\r?\n\r?\n+'));
    final timeRegex = RegExp(
      r'(\d{2}):(\d{2}):(\d{2}),(\d{3})\s*-->\s*'
      r'(\d{2}):(\d{2}):(\d{2}),(\d{3})',
    );

    Duration parseTime(int h, int m, int s, int ms) => Duration(
          hours: h,
          minutes: m,
          seconds: s,
          milliseconds: ms,
        );

    for (int i = 0; i < blocks.length; i++) {
      final block = blocks[i].trim();
      if (block.isEmpty) continue;
      final linesBlock = block.split('\n');
      if (linesBlock.length < 2) continue;

      final timeMatch = timeRegex.firstMatch(linesBlock[1]);
      if (timeMatch == null) continue;

      final start = parseTime(
        int.parse(timeMatch.group(1)!),
        int.parse(timeMatch.group(2)!),
        int.parse(timeMatch.group(3)!),
        int.parse(timeMatch.group(4)!),
      );

      final end = parseTime(
        int.parse(timeMatch.group(5)!),
        int.parse(timeMatch.group(6)!),
        int.parse(timeMatch.group(7)!),
        int.parse(timeMatch.group(8)!),
      );

      final text = linesBlock.skip(2).join('\n').trim();
      if (text.isEmpty) continue;

      _lines.add(TextItem(
        id: 'line_${_lines.length}',
        content: text,
        startTime: start,
        endTime: end,
      ));
    }

    _analyzedLines = SyntaxHighlighterService.analyzeLines(
      _lines.map((l) => l.content).toList(),
    );

    _currentDocument = TextDocument(
      id: _currentDocument?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: title ?? _currentDocument?.title ?? 'Untitled',
      lines: _lines,
      createdAt: _currentDocument?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _currentLineIndex = -1;
    _focusCueLineIndex = null;
    _selectedTextInfo = null;
    _selectedText = null;
    notifyListeners();
  }

  // ==================== COLOR MODE ====================

  void setColorMode(ColorMode mode) {
    _colorMode = mode;

    if (_lines.isNotEmpty) {
      _analyzedLines = SyntaxHighlighterService.analyzeLines(
        _lines.map((l) => l.content).toList(),
      );
    }

    // ★ THÊM: Persist
    _storage.saveColorMode(mode.name);

    notifyListeners();
  }

  void cycleColorMode() {
    final modes = ColorMode.values;
    final currentIndex = modes.indexOf(_colorMode);
    _colorMode = modes[(currentIndex + 1) % modes.length];

    if (_lines.isNotEmpty) {
      _analyzedLines = SyntaxHighlighterService.analyzeLines(
        _lines.map((l) => l.content).toList(),
      );
    }

    // ★ THÊM: Persist
    _storage.saveColorMode(_colorMode.name);

    notifyListeners();
  }

  // ==================== TEXT SELECTION ====================

  void selectTextWithOffsets({
    required String text,
    required int startOffset,
    required int endOffset,
    required int lineIndex,
  }) {
    _selectedTextInfo = SelectedTextInfo(
      text: text,
      startOffset: startOffset,
      endOffset: endOffset,
      lineIndex: lineIndex,
    );
    _selectedText = text;
    notifyListeners();
  }

  int calculateGlobalOffset(int lineIndex, int localOffset) {
    int globalOffset = 0;
    for (int i = 0; i < lineIndex && i < _lines.length; i++) {
      globalOffset += _lines[i].content.length + 1;
    }
    return globalOffset + localOffset;
  }

  // ==================== TEXT LINE EDITING ====================

  /// Sửa nội dung + bản dịch của 1 dòng
  void editLine({
    required int index,
    required String content,
    String? translation,
  }) {
    if (index < 0 || index >= _lines.length) return;

    _lines[index] = _lines[index].copyWith(
      content: content.trim(),
      translation: (translation == null || translation.trim().isEmpty)
          ? null
          : translation.trim(),
      translationLanguageCode: translation == null || translation.trim().isEmpty
          ? null
          : translationTargetLanguage.translationCode,
      clearTranslation: translation == null || translation.trim().isEmpty,
      clearSourceLanguage: true,
    );

    // Re-analyze từ loại
    final analyzed = SyntaxHighlighterService.analyzeLine(content);
    if (index < _analyzedLines.length) {
      _analyzedLines[index] = analyzed;
    } else {
      while (_analyzedLines.length <= index) {
        _analyzedLines.add([]);
      }
      _analyzedLines[index] = analyzed;
    }

    notifyListeners();
    debugPrint('✏️ editLine($index): "$content"');
  }

  /// Xoá 1 dòng
  void deleteLine(int index) {
    if (index < 0 || index >= _lines.length) return;

    _lines.removeAt(index);
    if (index < _analyzedLines.length) _analyzedLines.removeAt(index);

    if (_currentLineIndex >= _lines.length) {
      _currentLineIndex = _lines.length - 1;
    }
    if (_currentLineIndex == index) _currentLineIndex = -1;

    notifyListeners();
    debugPrint('🗑️ deleteLine($index)');
  }

  /// Tách 1 dòng thành nhiều dòng (khi user nhấn Enter trong LineEditSheet)
  void splitLine({
    required int index,
    required List<String> contentLines,
    List<String> translationLines = const [],
  }) {
    if (index < 0 || index >= _lines.length) return;
    if (contentLines.isEmpty) {
      deleteLine(index);
      return;
    }

    final original = _lines[index];

    final newItems = contentLines.asMap().entries.map((e) {
      final i = e.key;
      final text = e.value.trim();
      final trans = i < translationLines.length
          ? (translationLines[i].trim().isEmpty
              ? null
              : translationLines[i].trim())
          : null;
      return TextItem(
        id: '${original.id}_s$i',
        content: text,
        translation: trans,
        sourceLanguageCode: original.sourceLanguageCode,
        translationLanguageCode: trans == null
            ? null
            : original.translationLanguageCode ??
                translationTargetLanguage.translationCode,
        startTime: i == 0 ? original.startTime : null,
        endTime: i == 0 ? original.endTime : null,
      );
    }).toList();

    final newAnalyzed = contentLines
        .map((c) => SyntaxHighlighterService.analyzeLine(c))
        .toList();

    _lines
      ..removeAt(index)
      ..insertAll(index, newItems);

    if (index < _analyzedLines.length) {
      _analyzedLines.removeAt(index);
    } else {
      while (_analyzedLines.length <= index) {
        _analyzedLines.add([]);
      }
    }
    _analyzedLines.insertAll(index, newAnalyzed);

    if (_currentLineIndex >= index) _currentLineIndex = index;

    notifyListeners();
    debugPrint('✂️ splitLine($index) → ${contentLines.length} lines');
  }

  // ==================== SEGMENT MANAGEMENT ====================

  TextSegment? createSegmentFromSelection({
    TextSegmentDifficulty difficulty = TextSegmentDifficulty.medium,
    TextSegmentType type = TextSegmentType.phrase,
    int? repeatCountOverride,
    double? ttsSpeedOverride,
    String? note,
    String? translation,
    List<String> tags = const [],
  }) {
    if (_selectedTextInfo == null) return null;

    final info = _selectedTextInfo!;

    final repeatCount = repeatCountOverride ??
        (difficulty == TextSegmentDifficulty.hard
            ? 5
            : difficulty == TextSegmentDifficulty.medium
                ? 3
                : 1);

    final speed = ttsSpeedOverride ??
        (difficulty == TextSegmentDifficulty.hard
            ? 0.7
            : difficulty == TextSegmentDifficulty.medium
                ? 0.85
                : 1.0);

    final segment = TextSegment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: info.text,
      startOffset: info.startOffset,
      endOffset: info.endOffset,
      difficulty: difficulty,
      type: type,
      repeatCount: repeatCount,
      ttsSpeed: speed,
      note: note,
      translation: translation,
      tags: tags,
    );

    _segments.add(segment);
    _selectedTextInfo = null;
    _selectedText = null;

    // ★ THÊM: Persist
    _storage.saveTextSegment(segment);

    notifyListeners();
    return segment;
  }

  void deleteSegment(String id) {
    _segments.removeWhere((s) => s.id == id);

    // ★ THÊM: Persist
    _storage.deleteTextSegment(id);

    notifyListeners();
  }

  void updateSegment(TextSegment updated) {
    final index = _segments.indexWhere((s) => s.id == updated.id);
    if (index >= 0) {
      _segments[index] = updated;

      // ★ THÊM: Persist
      _storage.saveTextSegment(updated);

      notifyListeners();
    }
  }

  List<TextSegment> getSegmentsByDifficulty(TextSegmentDifficulty difficulty) {
    return _segments.where((s) => s.difficulty == difficulty).toList();
  }

  List<TextSegment> getSegmentsForReview() {
    return _segments.where((s) => s.needsReview).toList();
  }

  List<TextSegment> getSegmentsByType(TextSegmentType type) {
    return _segments.where((s) => s.type == type).toList();
  }

  void addTextSegment(TextSegment segment) {
    _segments.add(segment);
    notifyListeners();
  }

  // ==================== TTS FUNCTIONS ====================

  Future<void> speakSelected() async {
    if (_selectedText == null || _selectedText!.trim().isEmpty) return;
    await speak(_selectedText!);
  }

  Future<void> speakAllLines({int startIndex = 0}) async {
    if (_lines.isEmpty) return;

    final sessionId =
        await _startExclusiveTtsSession(TtsPlaybackOwner.allLines);

    for (int i = startIndex; i < _lines.length; i++) {
      if (!_isActiveSession(sessionId, TtsPlaybackOwner.allLines)) break;

      _currentLineIndex = i;
      notifyListeners();

      await _ttsService.speak(_lines[i].content);

      // Nếu user vừa bấm icon loa / swipe preview thì session này bị vô hiệu hóa
      if (!_isActiveSession(sessionId, TtsPlaybackOwner.allLines)) break;
    }

    _finishTtsSession(
      sessionId,
      TtsPlaybackOwner.allLines,
      clearReadingCursor: true,
    );
  }

  Future<void> speakCurrentLine() async {
    if (_lines.isEmpty) return;

    final index = (_currentLineIndex >= 0 && _currentLineIndex < _lines.length)
        ? _currentLineIndex
        : 0;

    await speak(_lines[index].content);
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;

    final sessionId = await _startExclusiveTtsSession(TtsPlaybackOwner.preview);

    // QUAN TRỌNG:
    // preview KHÔNG thay _currentLineIndex
    // để tab đếm câu / highlight không bị nhảy lung tung
    await _ttsService.speak(text);

    _finishTtsSession(sessionId, TtsPlaybackOwner.preview);
  }

  Future<void> stopSpeaking() async {
    await _stopAllTts(clearReadingCursor: true);
  }

  Future<void> setTtsSpeed(double speed) async {
    _ttsSpeed = speed.clamp(0.25, 2.0);
    _ttsService.configure(speed: _ttsSpeed);
    _storage.saveTtsSpeed(_ttsSpeed);
    notifyListeners();
  }

  Future<void> setTtsPitch(double pitch) async {
    _ttsPitch = pitch.clamp(0.5, 2.0);
    _ttsService.configure(pitch: _ttsPitch);
    notifyListeners();
  }

  Future<void> setTtsLanguage(String language) async {
    _ttsLanguage = language;
    final isAuto = language.toLowerCase() == 'auto';
    _ttsService.configure(
      language: isAuto ? 'auto' : language,
      autoDetect: isAuto,
    );
    notifyListeners();
  }

  // ==================== SEGMENT TTS ====================

  Future<void> speakSegment(TextSegment segment) async {
    final sessionId = await _startExclusiveTtsSession(TtsPlaybackOwner.segment);

    _currentPlayingSegment = segment;
    _currentRepeatIndex = 0;
    notifyListeners();

    final originalSpeed = _ttsSpeed;
    _ttsService.configure(speed: segment.ttsSpeed);

    for (int i = 0; i < segment.repeatCount; i++) {
      if (!_isActiveSession(sessionId, TtsPlaybackOwner.segment)) break;

      _currentRepeatIndex = i + 1;
      notifyListeners();

      await _ttsService.speak(segment.content);

      if (!_isActiveSession(sessionId, TtsPlaybackOwner.segment)) break;

      await Future.delayed(Duration(
        milliseconds:
            segment.difficulty == TextSegmentDifficulty.hard ? 1500 : 800,
      ));
    }

    _ttsService.configure(speed: originalSpeed);

    if (_isActiveSession(sessionId, TtsPlaybackOwner.segment)) {
      final updated = segment.copyWith(
        lastPracticed: DateTime.now(),
        practiceCount: segment.practiceCount + 1,
        masteryLevel: _calculateNewMastery(segment),
      );
      updateSegment(updated);
    }

    _finishTtsSession(sessionId, TtsPlaybackOwner.segment);
  }

  Future<void> stopSegmentPlayback() async {
    await _stopAllTts(clearReadingCursor: false);
  }

  double _calculateNewMastery(TextSegment segment) {
    final increment = 0.1 / (segment.difficulty.index + 1);
    return (segment.masteryLevel + increment).clamp(0.0, 1.0);
  }

  Future<void> startReviewSession() async {
    final toReview = getSegmentsForReview();
    _isPlayingSegment = true;
    notifyListeners();

    for (final segment in toReview) {
      if (!_isPlayingSegment) break;
      await speakSegment(segment);
      if (_isPlayingSegment) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    _isPlayingSegment = false;
    notifyListeners();
  }

  // ==================== WORD DIFFICULTY ====================

  void markWordDifficulty(
      int lineIndex, int wordIndex, DifficultyLevel difficulty) {
    if (lineIndex < 0 || lineIndex >= _analyzedLines.length) return;
    if (wordIndex < 0 || wordIndex >= _analyzedLines[lineIndex].length) return;

    final target = _analyzedLines[lineIndex][wordIndex];
    final normalized =
        target.word.toLowerCase().replaceAll(RegExp(r"[^\w']"), '').trim();
    if (normalized.isEmpty) return;

    for (int i = 0; i < _analyzedLines.length; i++) {
      for (int j = 0; j < _analyzedLines[i].length; j++) {
        final current = _analyzedLines[i][j];
        final currentNormalized = current.word
            .toLowerCase()
            .replaceAll(RegExp(r"[^\w']"), '')
            .trim();
        if (currentNormalized == normalized) {
          _analyzedLines[i][j] = current.copyWith(userDifficulty: difficulty);
        }
      }
    }

    final lineText =
        (lineIndex >= 0 && lineIndex < _lines.length) ? _lines[lineIndex].content : normalized;
    final selectedInfo = _selectedTextInfo;
    final selectedNormalized = (selectedInfo?.text ?? '')
        .toLowerCase()
        .replaceAll(RegExp(r"[^\w']"), '')
        .trim();
    final useSelectionAnchor =
        selectedInfo != null && selectedInfo.lineIndex == lineIndex && selectedNormalized == normalized;

    VocabularyBridge.upsertDifficulty(
      text: normalized,
      difficulty: difficulty,
      meaning: target.meaning ?? '',
      phonetic: target.phonetic,
      forceType: normalized.contains(' ')
          ? VocabularyType.phrase
          : VocabularyType.word,
      context: VocabContext.fromStory(
        storyTitle: _currentDocument?.title ?? 'Read Mode',
        lineIndex: lineIndex,
        surroundingText: lineText,
        sourceRef: currentContextSourceRef,
        sourceRefType: currentContextSourceRefType,
        anchorText: target.word,
        textStartOffset: useSelectionAnchor ? selectedInfo.startOffset : null,
        textEndOffset: useSelectionAnchor ? selectedInfo.endOffset : null,
      ),
      topic: _currentTextCategory,
    );

    notifyListeners();
  }

  Future<void> speakDifficultWordsFirst() async {
    final difficultWords = <AnalyzedWord>[];
    for (final line in _analyzedLines) {
      for (final word in line) {
        if (word.userDifficulty != null) {
          difficultWords.add(word);
        }
      }
    }

    if (difficultWords.isEmpty) return;

    difficultWords.sort((a, b) {
      final aLevel = a.userDifficulty?.index ?? 0;
      final bLevel = b.userDifficulty?.index ?? 0;
      return bLevel.compareTo(aLevel);
    });

    final sessionId =
        await _startExclusiveTtsSession(TtsPlaybackOwner.vocabReview);

    for (final word in difficultWords) {
      if (!_isActiveSession(sessionId, TtsPlaybackOwner.vocabReview)) break;

      final repeatCount = word.userDifficulty?.repeatCount ?? 1;
      final speed = word.userDifficulty?.ttsSpeed ?? 1.0;

      await setTtsSpeed(speed);

      for (int i = 0; i < repeatCount; i++) {
        if (!_isActiveSession(sessionId, TtsPlaybackOwner.vocabReview)) break;

        await _ttsService.speak(word.word);

        if (i < repeatCount - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      await Future.delayed(const Duration(milliseconds: 800));
    }

    await setTtsSpeed(1.0);
    _finishTtsSession(sessionId, TtsPlaybackOwner.vocabReview);
  }

  // ==================== STATISTICS ====================

  Map<String, dynamic> getSegmentStats() {
    final easy = getSegmentsByDifficulty(TextSegmentDifficulty.easy).length;
    final medium = getSegmentsByDifficulty(TextSegmentDifficulty.medium).length;
    final hard = getSegmentsByDifficulty(TextSegmentDifficulty.hard).length;
    final needsReview = getSegmentsForReview().length;

    double avgMastery = 0.0;
    if (_segments.isNotEmpty) {
      avgMastery =
          _segments.map((s) => s.masteryLevel).reduce((a, b) => a + b) /
              _segments.length;
    }

    return {
      'total': _segments.length,
      'easy': easy,
      'medium': medium,
      'hard': hard,
      'needsReview': needsReview,
      'averageMastery': avgMastery,
    };
  }

  Map<CEFRLevel, int> getCEFRStats() {
    final stats = <CEFRLevel, int>{};
    for (final level in CEFRLevel.values) {
      stats[level] = 0;
    }
    for (final line in _analyzedLines) {
      for (final word in line) {
        stats[word.cefrLevel] = (stats[word.cefrLevel] ?? 0) + 1;
      }
    }
    return stats;
  }

  Map<WordType, int> getWordTypeStats() {
    final stats = <WordType, int>{};
    for (final type in WordType.values) {
      stats[type] = 0;
    }
    for (final line in _analyzedLines) {
      for (final word in line) {
        stats[word.wordType] = (stats[word.wordType] ?? 0) + 1;
      }
    }
    return stats;
  }

  // ==================== DISPLAY SETTINGS ====================

  void setFontSize(double size) {
    _fontSize = size.clamp(12.0, 32.0);

    // ★ THÊM: Persist
    _storage.saveFontSize(_fontSize);

    notifyListeners();
  }

  void toggleTranslation() {
    // Bridge to mixin: toggle between hidden and stacked
    if (translationDisplayMode == TranslationDisplayMode.hidden) {
      setTranslationDisplayMode(TranslationDisplayMode.stackedBelow);
    } else {
      setTranslationDisplayMode(TranslationDisplayMode.hidden);
    }
    _storage.saveShowTranslation(showTranslation);
    notifyListeners();
  }

  void toggleLineNumbers() {
    _showLineNumbers = !_showLineNumbers;
    notifyListeners();
  }

  void setSubMode(ReadSubMode mode) {
    _subMode = mode;
    notifyListeners();
  }

  void setTextAlign(TextAlign align) {
    _textAlign = align;
    // _storage.saveTextAlign(align == TextAlign.center ? 'center' : 'left'); // Tạm thời bỏ qua
    notifyListeners();
  }

  void toggleAutoSplit(bool value) {
    _useAutoSplit = value;
    _parsePlainText(_fullText, title: _currentDocument?.title);
  }

  void toggleWordTypes() {
    _showWordTypes = !_showWordTypes;
    notifyListeners();
  }

  // ==================== LEGACY ====================

  void markLineDifficulty(int lineIndex, DifficultyMark difficulty) {
    if (lineIndex >= 0 && lineIndex < _lines.length) {
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
    notifyListeners();
  }

  // ==================== SYNC WITH AUDIO ====================

  void syncWithAudioPosition(Duration position) {
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

  // ==================== ANALYZED LINES ====================

  void setAnalyzedLines(List<List<AnalyzedWord>> lines) {
    _analyzedLines = lines;
    notifyListeners();
  }

  void updateAnalyzedLines(List<List<AnalyzedWord>> analyzed) {
    setAnalyzedLines(analyzed);
  }

  // ==================== SEGMENT EXTENSIONS ====================

  void addSegment({
    required String name,
    required String content,
    required int startLine,
    required int endLine,
    Color color = const Color(0xFF2196F3),
    String? note,
    String? ipa,
    String? translation,
  }) {
    final segment = TextSegment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      content: content,
      startLine: startLine,
      endLine: endLine,
      color: color,
      note: note,
      ipa: ipa,
      translation: translation,
    );
    _segments.add(segment);

    // ★ THÊM: Persist
    _storage.saveTextSegment(segment);

    notifyListeners();
  }

  // ==================== VOCABULARY ====================

  final List<AnalyzedWord> _savedWords = [];
  List<AnalyzedWord> get savedWords => List.unmodifiable(_savedWords);

  /// Lưu từ vựng (Đồng bộ logic với PDF Reader)
  void saveWord(AnalyzedWord word,
      {String? customMeaning, String? customNote}) {
    final existingIndex = _savedWords.indexWhere((w) => w.word == word.word);
    final updatedWord = word.copyWith(
      meaning: customMeaning ?? word.meaning,
    );

    if (existingIndex >= 0) {
      _savedWords[existingIndex] = updatedWord;
    } else {
      _savedWords.add(updatedWord);
    }

    // Lưu local storage cho tab Đọc
    _storage.saveWord(word.word, {
      'word': updatedWord.word,
      'meaning': updatedWord.meaning,
      'phonetic': word.phonetic,
      'example': word.example,
      'savedAt': DateTime.now().toIso8601String(),
    });

    // ★ THÊM: Đồng bộ sang hệ thống chung
    Future.microtask(() {
      VocabularyBridge.addFromAnalyzed(
        word: updatedWord.word,
        meaning: updatedWord.meaning,
        phonetic: word.phonetic,
        example: word.example,
        wordTypeName: updatedWord.wordType.name,
        cefrLevelName: updatedWord.cefrLevel.name,
        sourceFile: _currentTextPath?.split('/').last ?? 'Text',
      );
    });

    // ★ SỬA LẠI ĐOẠN NÀY:
    // Bọc trong Future.microtask để tránh xung đột luồng (Race Condition) và Stack Overflow
    Future.microtask(() {
      try {
        debugPrint('🔄 Đang gửi từ "${word.word}" sang Vườn Nhớ...');
        MemoryProvider.addWord(
          word: updatedWord.word,
          meaning: updatedWord.meaning,
          phonetic: word.phonetic,
          example: word.example,
          wordType: updatedWord.wordType.name,
          cefrLevel: updatedWord.cefrLevel.name,
          sourceFile: _currentTextPath?.split('/').last ?? 'Read Mode',
        );
        debugPrint('✅ Đã gửi xong!');
      } catch (e) {
        debugPrint('⚠️ Lỗi gửi sang Memory (không ảnh hưởng app): $e');
      }
    });

    notifyListeners();
  }

  // ==================== DISPOSE ====================

  @override
  void dispose() {
    _ttsService.stop();
    super.dispose();
  }

  /// Tách dòng tự động và load lại
  void autoSplitText({
    SplitMode mode = SplitMode.smart,
    int minWords = 4,
    int maxWords = 15,
  }) {
    if (_fullText.isEmpty) return;

    final lines = TextSplitterService.split(
      _fullText,
      mode: mode,
      minWordsBeforeSplit: minWords,
      maxWordsPerLine: maxWords,
    );

    _applyLines(lines);
  }

  /// Load từ danh sách dòng đã tách
  void loadFromLines(List<String> lines, {String? title}) {
    _applyLines(lines, title: title);
  }

  void _applyLines(List<String> lineStrings, {String? title}) {
    _lines = lineStrings.asMap().entries.map((entry) {
      return TextItem(
        id: 'line_${entry.key}',
        content: entry.value.trim(),
      );
    }).toList();

    _fullText = lineStrings.join('\n');

    _analyzedLines = SyntaxHighlighterService.analyzeLines(
      _lines.map((l) => l.content).toList(),
    );

    _currentDocument = TextDocument(
      id: _currentDocument?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: title ?? _currentDocument?.title ?? 'Untitled',
      lines: _lines,
      createdAt: _currentDocument?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _currentLineIndex = -1;
    _focusCueLineIndex = null;
    _selectedTextInfo = null;
    _selectedText = null;
    notifyListeners();

    debugPrint('✂️ Auto-split: ${_lines.length} lines');
  }
}
