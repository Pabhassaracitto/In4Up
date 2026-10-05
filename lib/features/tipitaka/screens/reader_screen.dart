import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:in4up/features/learn_by_heart/controllers/learn_by_heart_provider.dart';
import 'package:in4up/features/tipitaka/models/book.dart';
import 'package:in4up/features/tipitaka/models/reader_appearance.dart';
import 'package:in4up/features/tipitaka/models/segment.dart';
import 'package:in4up/features/tipitaka/services/reading_position_store.dart';
import 'package:in4up/features/tipitaka/services/tipitaka_learn_by_heart_service.dart';
import 'package:in4up/features/tipitaka/services/tipitaka_markup.dart';
import 'package:in4up/features/tipitaka/services/tipitaka_worklist_service.dart';
import 'package:in4up/models/vocabulary_type.dart';
import 'package:in4up/providers/vocabulary_provider.dart';
import 'package:in4up/features/tipitaka/screens/download_screen.dart';
import 'package:in4up/features/tipitaka/services/db_service.dart';
import 'package:in4up/features/tts/tts_service.dart';

/// A continuous, paragraph-aligned Tipiṭaka reader, laid out like a book page
/// rather than a scroll of cards — the direction set by OpenTipitaka.
///
/// Highlights:
///  * one centred reading column (max ~800 px on wide screens), paragraphs
///    separated by hairlines instead of cards;
///  * immersive `SliverAppBar` that hides while scrolling down, with a thin
///    progress line measuring the *reading position* (not loaded rows);
///  * CSCD-aware layout: book/chapter/subhead/center headings, verse (`gatha`)
///    indentation, inline `hangnum` paragraph numbers, and edition page
///    markers (`<pb ed="M" n="…"/>` → “M …” chips);
///  * persistent display settings (display mode, primary translation
///    language, sepia/night surfaces, font scale) via
///    [TipitakaReaderAppearance];
///  * two-directional paging: jumping from the TOC into the middle of a book
///    can still page *backwards* to earlier paragraphs.
class TipitakaReaderScreen extends StatefulWidget {
  final int bookId;
  final String bookCode;
  final String bookName;
  final TipitakaBook? book;
  final int? initialSegmentId;
  final bool embedded;

  const TipitakaReaderScreen({
    super.key,
    required this.bookId,
    required this.bookCode,
    this.bookName = '',
    this.book,
    this.initialSegmentId,
    this.embedded = false,
  });

  @override
  State<TipitakaReaderScreen> createState() => _TipitakaReaderScreenState();
}

class _TipitakaReaderScreenState extends State<TipitakaReaderScreen> {
  static const _pageSize = 60;
  static int _globalTtsGeneration = 0;

  final _scrollController = ScrollController();
  final TipitakaReaderAppearance _appearance = TipitakaReaderAppearance.instance;
  List<TipitakaSegment> _segments = const [];
  int _totalCount = 0;
  int _loadedOffset = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _loadingPrevious = false;
  bool _hasMore = true;
  String? _error;

  bool _hasPali = true;
  Set<String> _availableLanguages = const {};
  double _ttsSpeed = 1.0;
  bool _selectionSheetOpen = false;
  final _initialSegmentKey = GlobalKey();
  final GlobalKey _prependAnchorKey = GlobalKey();
  int? _prependAnchorSegmentId;
  late final TipitakaBook _worklistBook;
  late int? _requestedSegmentId;
  final TtsService _tts = TtsService();
  int? _speakingSegmentId;
  bool _readingArticle = false;
  int _ttsCursor = 0;
  double _scrollProgress = 0;
  bool _restoreAttempted = false;
  double _lastSavedPixels = -1;
  DateTime _lastPositionSavedAt =
      DateTime.fromMillisecondsSinceEpoch(0);

  bool get _showPali =>
      _hasPali &&
      _appearance.displayMode != TipitakaDisplayMode.translationOnly;

  // Databases without an imported Pāli pack make "Pali only" meaningless;
  // fall through to translations so the reader is never blank.
  bool get _showPrimaryTranslation =>
      _appearance.displayMode != TipitakaDisplayMode.paliOnly || !_hasPali;

  bool get _showEnglishSecondary =>
      _showPrimaryTranslation &&
      _appearance.englishSecondary &&
      _appearance.primaryLanguage != 'en' &&
      _availableLanguages.contains('en');

  int get _previousSlot => _loadedOffset > 0 ? 1 : 0;

  int get _itemCount => _segments.length + 2 + _previousSlot;

  @override
  void initState() {
    super.initState();
    _ttsSpeed = _tts.speed;
    _requestedSegmentId = widget.initialSegmentId;
    _worklistBook = widget.book ??
        TipitakaBook(
          id: widget.bookId,
          collectionId: 0,
          code: widget.bookCode,
          namePali: widget.bookCode,
          nameEn: widget.bookName,
          nameVi: widget.bookName,
          orderIndex: 0,
        );
    _appearance.addListener(_onAppearanceChanged);
    _appearance.ensureLoaded();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    // Final "Đọc tiếp" checkpoint before the screen tears down.
    if (_scrollController.hasClients && widget.bookId > 0 && !_loading) {
      TipitakaReadingPositions.save(
        widget.bookId,
        _scrollController.position.pixels,
        _totalCount,
      );
    }
    _appearance.removeListener(_onAppearanceChanged);
    if (_readingArticle || _speakingSegmentId != null) {
      _globalTtsGeneration++;
      _tts.stop();
    }
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onAppearanceChanged() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent > 0) {
      final progress =
          (position.pixels / position.maxScrollExtent).clamp(0.0, 1.0).toDouble();
      if ((progress * 120).round() != (_scrollProgress * 120).round()) {
        setState(() => _scrollProgress = progress);
      }
    }
    _maybeSavePosition(position.pixels);
    if (_loadingMore || !_hasMore) return;
    if (position.extentAfter < 700) _loadMore();
  }

  /// Throttled "Đọc tiếp" checkpoint: persists the scroll offset when the
  /// user has moved meaningfully and at most ~once per 1.2 s.
  void _maybeSavePosition(double pixels) {
    if (widget.bookId <= 0 || _loading) return;
    if ((pixels - _lastSavedPixels).abs() < 320) return;
    final now = DateTime.now();
    if (now.difference(_lastPositionSavedAt).inMilliseconds < 1200) return;
    _lastSavedPixels = pixels;
    _lastPositionSavedAt = now;
    TipitakaReadingPositions.save(widget.bookId, pixels, _totalCount);
  }

  /// Restores the saved "Đọc tiếp" offset after opening a book from the top,
  /// paging forward until the content is tall enough to host it.
  Future<void> _restoreReadingPosition() async {
    try {
      final saved = await TipitakaReadingPositions.load(widget.bookId);
      if (!mounted ||
          saved == null ||
          saved.pixels < TipitakaReadingPositions.minMeaningfulPixels) {
        return;
      }
      var guard = 0;
      while (mounted && _hasMore && guard < 25) {
        final position =
            _scrollController.hasClients ? _scrollController.position : null;
        if (position == null ||
            position.maxScrollExtent >= saved.pixels) {
          break;
        }
        guard++;
        await _loadMore();
        await WidgetsBinding.instance.endOfFrame;
      }
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      final limit = position.hasContentDimensions
          ? position.maxScrollExtent
          : 0.0;
      final target = saved.pixels.clamp(0.0, limit).toDouble();
      if (target >= TipitakaReadingPositions.minMeaningfulPixels) {
        _scrollController.jumpTo(target);
      }
    } catch (_) {
      // Best-effort resume: a restore failure must never block reading.
    }
  }

  Key _keyForSegment(TipitakaSegment segment) {
    if (segment.id == _requestedSegmentId) return _initialSegmentKey;
    if (segment.id == _prependAnchorSegmentId) return _prependAnchorKey;
    return ValueKey('tipitaka-segment-${segment.id}');
  }

  Future<void> _loadFirstPage() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _segments = const [];
        _loadedOffset = 0;
        _hasMore = true;
        _loadingPrevious = false;
        _prependAnchorSegmentId = null;
        _scrollProgress = 0;
      });
    }
    try {
      final db = await TipitakaDb.openReady();
      final total = await TipitakaDb.getBookSegmentCount(db, widget.bookId);
      final info = await TipitakaDb.info(db);
      final requestedOffset = _requestedSegmentId == null
          ? 0
          : (await TipitakaDb.getSegmentOrderIndex(db, _requestedSegmentId!) ?? 0)
              .clamp(0, total > 0 ? total - 1 : 0)
              .toInt();
      final firstPage = await TipitakaDb.getSegmentsByBook(
        db,
        widget.bookId,
        limit: _pageSize,
        offset: requestedOffset,
      );
      if (!mounted) return;
      setState(() {
        _totalCount = total;
        _availableLanguages = info.availableLanguages;
        _hasPali = info.availableLanguages.contains('pi');
        _loadedOffset = requestedOffset;
        _segments = firstPage;
        _hasMore = _loadedOffset + firstPage.length < total;
        _loading = false;
      });
      if (_requestedSegmentId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final target = _initialSegmentKey.currentContext;
          if (target != null) Scrollable.ensureVisible(target, alignment: .22);
        });
      } else if (!_restoreAttempted) {
        _restoreAttempted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _restoreReadingPosition();
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _segments = const [];
        _error = error.toString();
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final db = await TipitakaDb.openReady();
      final nextPage = await TipitakaDb.getSegmentsByBook(
        db,
        widget.bookId,
        limit: _pageSize,
        offset: _loadedOffset + _segments.length,
      );
      if (!mounted) return;
      setState(() {
        _segments = [..._segments, ...nextPage];
        _hasMore =
            _loadedOffset + _segments.length < _totalCount && nextPage.isNotEmpty;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _error = error.toString();
      });
    }
  }

  /// Pages backwards after a deep jump (TOC / search result): prepends one
  /// page of earlier paragraphs and re-anchors the previously first segment.
  Future<void> _loadPrevious() async {
    if (_loadingPrevious || _loadedOffset <= 0) return;
    _prependAnchorSegmentId = _segments.isEmpty ? null : _segments.first.id;
    setState(() => _loadingPrevious = true);
    try {
      final db = await TipitakaDb.openReady();
      final newOffset =
          (_loadedOffset - _pageSize).clamp(0, _loadedOffset).toInt();
      final previousPage = await TipitakaDb.getSegmentsByBook(
        db,
        widget.bookId,
        limit: _loadedOffset - newOffset,
        offset: newOffset,
      );
      if (!mounted) return;
      setState(() {
        _segments = [...previousPage, ..._segments];
        _loadedOffset = newOffset;
        _loadingPrevious = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final anchor = _prependAnchorKey.currentContext;
        if (anchor != null) {
          Scrollable.ensureVisible(
            anchor,
            alignment: .03,
            duration: Duration.zero,
          );
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingPrevious = false;
        _prependAnchorSegmentId = null;
        _error = error.toString();
      });
    }
  }

  Future<void> _openSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return AnimatedBuilder(
          animation: _appearance,
          builder: (context, _) {
            final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
            final languages = _contentLanguages;
            final englishAvailable =
                _availableLanguages.contains('en') &&
                _appearance.primaryLanguage != 'en';
            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + bottomInset),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.uiText('Cài đặt hiển thị'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    _SettingsSectionLabel(context.uiText('Chế độ đọc')),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<TipitakaDisplayMode>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(
                            value: TipitakaDisplayMode.bilingual,
                            enabled: _hasPali,
                            icon: const Icon(Icons.translate, size: 18),
                            label: Text(context.uiText('Song ngữ')),
                          ),
                          ButtonSegment(
                            value: TipitakaDisplayMode.paliOnly,
                            enabled: _hasPali,
                            icon: const Icon(Icons.menu_book_outlined, size: 18),
                            label: const Text('Pāḷi'),
                          ),
                          ButtonSegment(
                            value: TipitakaDisplayMode.translationOnly,
                            icon: const Icon(Icons.article_outlined, size: 18),
                            label: Text(context.uiText('Bản dịch')),
                          ),
                        ],
                        selected: {
                          _hasPali
                              ? _appearance.displayMode
                              : TipitakaDisplayMode.translationOnly,
                        },
                        onSelectionChanged: (selection) {
                          _appearance.displayMode = selection.first;
                          if (selection.first ==
                              TipitakaDisplayMode.translationOnly) {
                            _appearance.englishSecondary = false;
                          }
                        },
                      ),
                    ),
                    if (!_hasPali)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          context.uiText(
                            'Chưa import Pāli; bản dịch vẫn đọc độc lập.',
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    const SizedBox(height: 18),
                    _SettingsSectionLabel(context.uiText('Ngôn ngữ bản dịch')),
                    const SizedBox(height: 4),
                    Text(
                      context.uiText(
                        'Độc lập với ngôn ngữ giao diện — xem Pāli kèm bản dịch bất kỳ đã import.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final language in languages)
                          ChoiceChip(
                            label: Text(tipitakaLanguageLabel(language)),
                            selected:
                                _appearance.primaryLanguage == language,
                            onSelected: (_) =>
                                _appearance.primaryLanguage = language,
                          ),
                      ],
                    ),
                    if (englishAvailable)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _appearance.englishSecondary,
                        title: Text(context.uiText('Kèm thêm English')),
                        subtitle: Text(
                          context.uiText('Hiển thị English dưới bản dịch chính'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        onChanged: (value) =>
                            _appearance.englishSecondary = value,
                      ),
                    const SizedBox(height: 10),
                    _SettingsSectionLabel(context.uiText('Nền trang đọc')),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _themeChip(
                          context,
                          TipitakaReadingTheme.system,
                          context.uiText('Hệ thống'),
                          Icons.brightness_auto_outlined,
                        ),
                        _themeChip(
                          context,
                          TipitakaReadingTheme.light,
                          context.uiText('Sáng'),
                          Icons.light_mode_outlined,
                        ),
                        _themeChip(
                          context,
                          TipitakaReadingTheme.sepia,
                          'Sepia',
                          Icons.coffee_outlined,
                        ),
                        _themeChip(
                          context,
                          TipitakaReadingTheme.dark,
                          context.uiText('Tối'),
                          Icons.dark_mode_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _SettingsSectionLabel(context.uiText('Cỡ chữ')),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: _appearance.fontScale,
                            min: TipitakaReaderAppearance.minFontScale,
                            max: TipitakaReaderAppearance.maxFontScale,
                            divisions: 16,
                            label:
                                '${(_appearance.fontScale * 100).round()}%',
                            onChanged: (value) =>
                                _appearance.fontScale = value,
                          ),
                        ),
                        SizedBox(
                          width: 52,
                          child: Text(
                            '${(_appearance.fontScale * 100).round()}%',
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _SettingsSectionLabel(context.uiText('Tốc độ đọc')),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: _ttsSpeed,
                            min: 0.5,
                            max: 1.5,
                            divisions: 10,
                            label: '${_ttsSpeed.toStringAsFixed(2)}x',
                            onChanged: (value) {
                              setState(() => _ttsSpeed = value);
                              _tts.configure(speed: value);
                            },
                          ),
                        ),
                        SizedBox(
                          width: 52,
                          child: Text(
                            '${_ttsSpeed.toStringAsFixed(2)}x',
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _appearance.reset,
                        icon: const Icon(Icons.restart_alt, size: 18),
                        label: Text(context.uiText('Đặt lại mặc định')),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _themeChip(
    BuildContext context,
    TipitakaReadingTheme theme,
    String label,
    IconData icon,
  ) {
    return ChoiceChip(
      avatar: Icon(icon, size: 17),
      label: Text(label),
      selected: _appearance.readingTheme == theme,
      onSelected: (_) => _appearance.readingTheme = theme,
    );
  }

  List<String> get _contentLanguages {
    const preferred = ['vi', 'en', 'my', 'th'];
    final available =
        _availableLanguages.where((code) => code != 'pi').toSet();
    final ordered = <String>[];
    for (final code in preferred) {
      if (available.remove(code)) ordered.add(code);
    }
    final extras = available.toList()..sort();
    ordered.addAll(extras);
    if (!ordered.contains(_appearance.primaryLanguage)) {
      ordered.insert(0, _appearance.primaryLanguage);
    }
    return ordered;
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  void _onPaliSelection(TipitakaSegment segment, TextSelection selection) {
    if (_selectionSheetOpen || selection.isCollapsed) return;
    final text = cleanTipitakaText(segment.paliText);
    final start = selection.start.clamp(0, text.length).toInt();
    final end = selection.end.clamp(0, text.length).toInt();
    if (start >= end) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selectionSheetOpen) return;
      _showSelectionActions(segment, text.substring(start, end), start, end);
    });
  }

  Future<void> _showSelectionActions(
    TipitakaSegment segment,
    String selectedText,
    int startOffset,
    int endOffset,
  ) async {
    _selectionSheetOpen = true;
    try {
      final isWord = !selectedText.trim().contains(RegExp(r'\s'));
      final action = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.bookmark_add_outlined),
                title: Text(
                  context.uiText(isWord ? 'Lưu từ vào Worklist' : 'Lưu cụm từ vào Worklist'),
                ),
                subtitle: Text(selectedText),
                onTap: () => Navigator.pop(context, 'save'),
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: Text(context.uiText('Sao chép lựa chọn')),
                onTap: () => Navigator.pop(context, 'copy'),
              ),
            ],
          ),
        ),
      );
      if (!mounted || action == null) return;
      if (action == 'copy') {
        await Clipboard.setData(ClipboardData(text: selectedText));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.uiText('Đã sao chép lựa chọn.'))),
          );
        }
        return;
      }
      await _saveSelection(
        segment,
        selectedText,
        startOffset,
        endOffset,
      );
    } finally {
      _selectionSheetOpen = false;
    }
  }

  Future<void> _saveWholeSegment(TipitakaSegment segment) async {
    final text = _segmentStudyText(segment);
    if (text.isEmpty) return;
    await _saveSelection(
      segment,
      text,
      0,
      text.length,
      forceType: VocabularyType.paragraph,
    );
  }

  Future<void> _learnWholeSegment(TipitakaSegment segment) async {
    try {
      final index = _segments.indexWhere((item) => item.id == segment.id);
      await const TipitakaLearnByHeartService().savePassage(
        provider: context.read<LearnByHeartProvider>(),
        book: _worklistBook,
        segment: segment,
        bookName: widget.bookName.trim().isEmpty
            ? widget.bookCode
            : widget.bookName,
        contextBefore:
            index > 0 ? _segmentStudyText(_segments[index - 1]) : '',
        contextAfter: index >= 0 && index + 1 < _segments.length
            ? _segmentStudyText(_segments[index + 1])
            : '',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.uiText('Đã thêm đoạn vào Học thuộc lòng.'))),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.uiText('Không thể thêm vào Học thuộc lòng: $error'))),
      );
    }
  }

  Future<void> _saveSelection(
    TipitakaSegment segment,
    String selectedText,
    int startOffset,
    int endOffset, {
    VocabularyType? forceType,
  }) async {
    try {
      final index = _segments.indexWhere((item) => item.id == segment.id);
      final before =
          index > 0 ? _segmentStudyText(_segments[index - 1]) : '';
      final after = index >= 0 && index + 1 < _segments.length
          ? _segmentStudyText(_segments[index + 1])
          : '';
      final result = await const TipitakaWorklistService().saveSelection(
        vocabulary: context.read<VocabularyProvider>(),
        book: _worklistBook,
        segment: segment,
        selectedText: selectedText,
        startOffset: startOffset,
        endOffset: endOffset,
        translationLanguage: _segmentTranslationLanguage(segment),
        contextBefore: before,
        contextAfter: after,
        forceType: forceType,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.wasExisting
                ? context.uiText('Đã thêm ngữ cảnh Tipiṭaka vào từ đã có.')
                : context.uiText('Đã lưu vào Worklist.'),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.uiText('Không thể lưu vào Worklist: $error'))),
      );
    }
  }

  String _segmentStudyText(TipitakaSegment segment) {
    final pali = cleanTipitakaText(segment.paliText);
    if (pali.isNotEmpty) return pali;
    final translation = segment.firstTranslation;
    return cleanTipitakaText(translation?.value ?? '');
  }

  String _segmentTranslationLanguage(TipitakaSegment segment) {
    final primary = _appearance.primaryLanguage;
    if (segment.translationFor(primary).trim().isNotEmpty) return primary;
    if ((segment.translationVi ?? '').trim().isNotEmpty) return 'vi';
    if ((segment.translationEn ?? '').trim().isNotEmpty) return 'en';
    return segment.firstTranslation?.key ?? primary;
  }

  String _segmentReadingText(TipitakaSegment segment) {
    if (_showPrimaryTranslation) {
      final primary =
          cleanTipitakaText(segment.translationFor(_appearance.primaryLanguage));
      if (primary.isNotEmpty) return primary;
      for (final code in const ['vi', 'en', 'my', 'th']) {
        final text = cleanTipitakaText(segment.translationFor(code));
        if (text.isNotEmpty) return text;
      }
      final other = segment.firstTranslation;
      if (other != null && other.value.trim().isNotEmpty) {
        return cleanTipitakaText(other.value);
      }
    }
    return cleanTipitakaText(segment.paliText);
  }

  Future<void> _stopTts() async {
    _globalTtsGeneration++;
    await _tts.stop();
    if (mounted) {
      setState(() {
        _readingArticle = false;
        _speakingSegmentId = null;
      });
    }
  }

  Future<void> _toggleSegmentTts(
    TipitakaSegment segment,
    int absoluteIndex,
  ) async {
    if (_speakingSegmentId == segment.id) {
      await _stopTts();
      return;
    }
    final text = _segmentReadingText(segment);
    if (text.isEmpty) return;
    final generation = ++_globalTtsGeneration;
    await _tts.stop();
    if (!mounted) return;
    setState(() {
      _readingArticle = false;
      _speakingSegmentId = segment.id;
      _ttsCursor = absoluteIndex;
    });
    await _tts.speak(text);
    if (!mounted || generation != _globalTtsGeneration) return;
    setState(() {
      _speakingSegmentId = null;
      _ttsCursor = absoluteIndex + 1;
    });
  }

  Future<void> _toggleArticleTts() async {
    if (_readingArticle) {
      await _stopTts();
      return;
    }
    final generation = ++_globalTtsGeneration;
    await _tts.stop();
    if (!mounted) return;
    setState(() => _readingArticle = true);
    var offset = _ttsCursor.clamp(0, _totalCount).toInt();
    if (offset == 0 && _loadedOffset > 0) offset = _loadedOffset;
    try {
      final db = await TipitakaDb.openReady();
      while (offset < _totalCount && generation == _globalTtsGeneration) {
        final page = await TipitakaDb.getSegmentsByBook(
          db,
          widget.bookId,
          limit: 30,
          offset: offset,
        );
        if (page.isEmpty) break;
        for (final segment in page) {
          if (generation != _globalTtsGeneration) return;
          final text = _segmentReadingText(segment);
          setState(() {
            _speakingSegmentId = segment.id;
            _ttsCursor = offset;
          });
          if (text.isNotEmpty) await _tts.speak(text);
          offset++;
          _ttsCursor = offset;
        }
      }
    } finally {
      if (mounted && generation == _globalTtsGeneration) {
        setState(() {
          _readingArticle = false;
          _speakingSegmentId = null;
          if (_ttsCursor >= _totalCount) _ttsCursor = 0;
        });
      }
    }
  }

  String _outlineTitle(TipitakaSegment segment) {
    final translated = cleanTipitakaText(
      segment.translationFor(_appearance.primaryLanguage),
    );
    final secondary = translated.isNotEmpty
        ? translated
        : cleanTipitakaText(
            Localizations.localeOf(context).languageCode == 'vi'
                ? segment.translationFor('vi')
                : segment.translationFor('en'),
          );
    final text = secondary.isNotEmpty
        ? secondary
        : cleanTipitakaText(segment.paliText).isNotEmpty
            ? cleanTipitakaText(segment.paliText)
            : cleanTipitakaText(segment.firstTranslation?.value ?? '');
    return text.isEmpty ? context.uiText('Mục chưa có tiêu đề') : text;
  }

  Future<void> _openTableOfContents() async {
    final db = await TipitakaDb.openReady();
    final outline = await TipitakaDb.getBookOutline(db, widget.bookId);
    if (!mounted) return;
    final selected = await showModalBottomSheet<TipitakaSegment>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        var query = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final needle = query.trim().toLowerCase();
            final items = needle.isEmpty
                ? outline
                : outline
                    .where((segment) => _outlineTitle(segment)
                        .toLowerCase()
                        .contains(needle))
                    .toList();
            return SafeArea(
              child: FractionallySizedBox(
                heightFactor: .82,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.format_list_numbered),
                      title: Text(
                        context.uiText('Mục lục chi tiết'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      trailing: Text(
                        '${items.length}/${outline.length}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: TextField(
                        autofocus: outline.length > 12,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          isDense: true,
                          prefixIcon: const Icon(Icons.search, size: 20),
                          hintText: context.uiText('Lọc mục lục…'),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (value) =>
                            setSheetState(() => query = value),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: items.isEmpty
                          ? Center(
                              child: Text(
                                context.uiText('Không có mục nào khớp bộ lọc.'),
                              ),
                            )
                          : ListView.builder(
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                final segment = items[index];
                                return ListTile(
                                  dense: true,
                                  leading: Text(
                                    '${outline.indexOf(segment) + 1}',
                                  ),
                                  title: Text(
                                    _outlineTitle(segment),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () =>
                                      Navigator.pop(context, segment),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (selected == null) return;
    _requestedSegmentId = selected.id;
    _ttsCursor = await TipitakaDb.getSegmentOrderIndex(db, selected.id) ?? 0;
    await _loadFirstPage();
    _scrollToTop();
  }

  void _showTechnicalDetails() {
    final index = _worklistBook.catalogIndex;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.data_object),
          title: Text(context.uiText('Chi tiết kỹ thuật')),
          subtitle: Text('${index.normalizedCode}\n${index.sourceTable}'),
        ),
      ),
    );
  }

  ThemeData _resolveReadingTheme(ThemeData base) {
    final theme = _appearance.readingTheme;
    if (theme == TipitakaReadingTheme.system) return base;
    if (theme == TipitakaReadingTheme.light) {
      return _applyScheme(
        base,
        ColorScheme.fromSeed(
          seedColor: base.colorScheme.primary,
          brightness: Brightness.light,
        ),
      );
    }
    if (theme == TipitakaReadingTheme.sepia) {
      return _applyScheme(
        base,
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF836546),
          brightness: Brightness.light,
        ).copyWith(
          surface: const Color(0xFFF5EDDC),
          surfaceContainerLowest: const Color(0xFFFBF7EC),
          surfaceContainerLow: const Color(0xFFF2E9D5),
          surfaceContainer: const Color(0xFFEEE3CC),
          surfaceContainerHigh: const Color(0xFFEADCC1),
          surfaceContainerHighest: const Color(0xFFE5D6B9),
          onSurface: const Color(0xFF3B332A),
          onSurfaceVariant: const Color(0xFF5E5546),
          outlineVariant: const Color(0xFFC9BCA3),
        ),
      );
    }
    return _applyScheme(
      base,
      ColorScheme.fromSeed(
        seedColor: base.colorScheme.primary,
        brightness: Brightness.dark,
      ).copyWith(
        surface: const Color(0xFF14110D),
        surfaceContainerLowest: const Color(0xFF0F0D0A),
        surfaceContainerLow: const Color(0xFF1A1712),
        surfaceContainer: const Color(0xFF1F1B15),
        surfaceContainerHigh: const Color(0xFF25211A),
        surfaceContainerHighest: const Color(0xFF2D2820),
      ),
    );
  }

  ThemeData _applyScheme(ThemeData base, ColorScheme scheme) {
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      dividerColor: scheme.outlineVariant,
    );
  }

  @override
  Widget build(BuildContext context) {
    final readerTheme = _resolveReadingTheme(Theme.of(context));
    if (_loading) {
      return Theme(
        data: readerTheme,
        child: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    if (_error != null && _segments.isEmpty) {
      return Theme(
        data: readerTheme,
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: !widget.embedded,
            title: const Text('Tipiṭaka'),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.menu_book_outlined, size: 56),
                  const SizedBox(height: 12),
                  Text(
                    context.uiText('Không thể mở nội dung sách.'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _loadFirstPage,
                    icon: const Icon(Icons.refresh),
                    label: Text(context.uiText('Thử lại')),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TipitakaDownloadScreen(),
                      ),
                    ),
                    child: Text(context.uiText('Quản lý dữ liệu')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final requestedTitle = widget.bookName.trim();
    final title = requestedTitle.isEmpty ||
            _worklistBook.isTechnicalTitle(requestedTitle)
        ? _worklistBook.displayTitle(
            Localizations.localeOf(context).languageCode,
          )
        : requestedTitle;
    return Theme(
      data: readerTheme,
      child: Scaffold(
        floatingActionButton: _segments.length > _pageSize
            ? FloatingActionButton.small(
                heroTag: 'tipitaka-reader-top',
                onPressed: _scrollToTop,
                tooltip: context.uiText('Về đầu sách'),
                child: const Icon(Icons.keyboard_arrow_up),
              )
            : null,
        body: RefreshIndicator(
          onRefresh: _loadFirstPage,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final available = constraints.maxWidth;
              final horizontal = available > 840
                  ? ((available - 800) / 2).clamp(12.0, 480.0).toDouble()
                  : 12.0;
              return CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    automaticallyImplyLeading: !widget.embedded,
                    floating: true,
                    snap: true,
                    titleSpacing: 16,
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _segments.isEmpty
                              ? '0/$_totalCount ${context.uiText('đoạn')}'
                              : '${context.uiText('Đoạn')} ${_loadedOffset + 1}'
                                '–${_loadedOffset + _segments.length}'
                                '/$_totalCount',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                    actions: [
                      IconButton(
                        tooltip: context.uiText('Mục lục chi tiết'),
                        onPressed: _openTableOfContents,
                        icon: const Icon(Icons.format_list_numbered),
                      ),
                      IconButton(
                        tooltip: _readingArticle
                            ? context.uiText('Dừng đọc bài')
                            : context.uiText('Đọc bài từ vị trí hiện tại'),
                        onPressed: _toggleArticleTts,
                        icon: Icon(_readingArticle
                            ? Icons.stop_circle
                            : Icons.play_circle),
                      ),
                      IconButton(
                        tooltip: context.uiText('Cài đặt hiển thị'),
                        onPressed: _openSettings,
                        icon: const Icon(Icons.tune),
                      ),
                      IconButton(
                        tooltip: context.uiText('Chi tiết kỹ thuật'),
                        onPressed: _showTechnicalDetails,
                        icon: const Icon(Icons.info_outline),
                      ),
                    ],
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(3),
                      child: _scrollProgress <= 0
                          ? const SizedBox(height: 3)
                          : LinearProgressIndicator(
                              value: _scrollProgress,
                              minHeight: 3,
                              backgroundColor: Colors.transparent,
                            ),
                    ),
                  ),
                  SliverPadding(
                    padding:
                        EdgeInsets.fromLTRB(horizontal, 12, horizontal, 32),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildItem(context, index, title),
                        childCount: _itemCount,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index, String title) {
    if (index == 0) return _buildBookHeader(context, title);
    final segmentStart = 1 + _previousSlot;
    if (index < segmentStart) return _buildPreviousLoader(context);
    final segmentIndex = index - segmentStart;
    if (segmentIndex < _segments.length) {
      final segment = _segments[segmentIndex];
      final number = _loadedOffset + segmentIndex + 1;
      final kind = tipitakaBlockKind(segment);
      if (kind == TipitakaBlockKind.hangnum) {
        return _ParagraphNumberLine(
          key: ValueKey('tipitaka-hangnum-${segment.id}'),
          label: tipitakaParagraphNumber(segment),
        );
      }
      return _SectionBlock(
        key: _keyForSegment(segment),
        segment: segment,
        number: number,
        kind: kind,
        showPali: _showPali,
        showPrimaryTranslation: _showPrimaryTranslation,
        primaryLanguage: _appearance.primaryLanguage,
        showEnglishSecondary: _showEnglishSecondary,
        fontScale: _appearance.fontScale,
        isSpeaking: _speakingSegmentId == segment.id,
        isAnchor: _requestedSegmentId == segment.id,
        onSpeakSegment: (value) =>
            _toggleSegmentTts(value, _loadedOffset + segmentIndex),
        onPaliSelection: _onPaliSelection,
        onSaveSegment: _saveWholeSegment,
        onLearnSegment: _learnWholeSegment,
      );
    }
    return _buildEndOfBook(context);
  }

  Widget _buildPreviousLoader(BuildContext context) {
    if (_loadingPrevious) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Center(
        child: TextButton.icon(
          onPressed: _loadPrevious,
          icon: const Icon(Icons.expand_less),
          label: Text(context.uiText('Tải các đoạn phía trước')),
        ),
      ),
    );
  }

  Widget _buildBookHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final edition = _worklistBook.catalogIndex.editionLabel;
    final languageNames = _availableLanguages
        .where((code) => code != 'pi')
        .map(tipitakaLanguageLabel)
        .join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            edition.isEmpty
                ? 'TIPIṬAKA'
                : 'TIPIṬAKA · ${edition.toUpperCase()}',
            style: theme.textTheme.labelMedium?.copyWith(
              letterSpacing: 1.6,
              fontWeight: FontWeight.w700,
              color: scheme.secondary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 25 * _appearance.fontScale,
              height: 1.25,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
              fontFamilyFallback: tipitakaSerifFallback,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _hasPali
                ? context.uiText(
                    'Đọc song song Pāli và bản dịch theo từng đoạn. Nội dung tự tải thêm khi cuộn.',
                  )
                : context.uiText(
                    'Đang đọc bản dịch độc lập. Nên import Pāli để đối chiếu tốt hơn.',
                  ),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.notes, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  languageNames.isEmpty
                      ? '$_totalCount ${context.uiText('đoạn')}'
                      : '$_totalCount ${context.uiText('đoạn')} · $languageNames',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (!_hasPali) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 17),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.uiText('Pāli không bắt buộc để tiếp tục đọc.'),
                    style: theme.textTheme.labelMedium,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Divider(height: 1, color: scheme.outlineVariant),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildEndOfBook(BuildContext context) {
    final theme = Theme.of(context);
    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: OutlinedButton.icon(
            onPressed: _loadMore,
            icon: const Icon(Icons.expand_more),
            label: Text(context.uiText('Tải thêm đoạn')),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26),
      child: Column(
        children: [
          Divider(
            indent: 120,
            endIndent: 120,
            color: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(height: 10),
          Text(
            context.uiText('Đã hiển thị toàn bộ nội dung sách.'),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Slim inline paragraph-number line for CSCD `hangnum` rows (1. 2. 3.) —
/// previously each one inflated into a full card.
class _ParagraphNumberLine extends StatelessWidget {
  final String label;

  const _ParagraphNumberLine({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: .5,
              fontWeight: FontWeight.w700,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: .85),
            ),
      ),
    );
  }
}

/// One semantic section of the page: a heading (book/chapter/subhead/center)
/// or a paragraph with reference chip, action row and aligned text blocks.
class _SectionBlock extends StatelessWidget {
  final TipitakaSegment segment;
  final int number;
  final TipitakaBlockKind kind;
  final bool showPali;
  final bool showPrimaryTranslation;
  final String primaryLanguage;
  final bool showEnglishSecondary;
  final double fontScale;
  final bool isSpeaking;
  final bool isAnchor;
  final Future<void> Function(TipitakaSegment segment)? onSpeakSegment;
  final void Function(TipitakaSegment segment, TextSelection selection)?
      onPaliSelection;
  final Future<void> Function(TipitakaSegment segment)? onSaveSegment;
  final Future<void> Function(TipitakaSegment segment)? onLearnSegment;

  const _SectionBlock({
    super.key,
    required this.segment,
    required this.number,
    required this.kind,
    required this.showPali,
    required this.showPrimaryTranslation,
    required this.primaryLanguage,
    required this.showEnglishSecondary,
    required this.fontScale,
    required this.isSpeaking,
    required this.isAnchor,
    this.onSpeakSegment,
    this.onPaliSelection,
    this.onSaveSegment,
    this.onLearnSegment,
  });

  @override
  Widget build(BuildContext context) {
    final paliText = cleanTipitakaText(segment.paliText);
    final translation = _resolveTranslation(segment, primaryLanguage);
    final englishText = cleanTipitakaText(segment.translationEn ?? '');
    final showEnglishBlock = showEnglishSecondary &&
        englishText.isNotEmpty &&
        translation.language != 'en';

    if (kind != TipitakaBlockKind.paragraph &&
        kind != TipitakaBlockKind.gatha) {
      // Headings keep the canonical title when no translation exists, even
      // in translation-only mode — an empty heading would strand the reader.
      final headingPali = showPali || translation.text.isEmpty ? paliText : '';
      return _HeadingBlock(
        kind: kind,
        paliText: headingPali,
        translationText: showPrimaryTranslation ? translation.text : '',
        englishText: showEnglishSecondary ? englishText : '',
        fontScale: fontScale,
      );
    }

    final visiblePali = showPali && paliText.isNotEmpty;
    final visibleTranslation =
        showPrimaryTranslation && translation.text.isNotEmpty;
    // Translation-only mode must never strand the reader on an empty slot:
    // fall back to the canonical text, clearly labelled as Pāli.
    final paliFallback = showPrimaryTranslation &&
        !visiblePali &&
        translation.text.isEmpty &&
        paliText.isNotEmpty;
    final hasVisibleText =
        visiblePali || visibleTranslation || showEnglishBlock || paliFallback;
    final verse = kind == TipitakaBlockKind.gatha;

    final scheme = Theme.of(context).colorScheme;
    final decorated = isSpeaking || isAnchor;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: decorated
          ? BoxDecoration(
              color: isSpeaking
                  ? scheme.primaryContainer.withValues(alpha: .24)
                  : scheme.secondaryContainer.withValues(alpha: .28),
              borderRadius: BorderRadius.circular(14),
            )
          : null,
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SegmentMetaBar(
            segment: segment,
            number: number,
            isSpeaking: isSpeaking,
            onSpeakSegment: onSpeakSegment,
            onSaveSegment: onSaveSegment,
            onLearnSegment: onLearnSegment,
          ),
          if (visiblePali || paliFallback) ...[
            const SizedBox(height: 12),
            _TextBlock(
              label: 'PĀḶI',
              text: paliText,
              fontSize: 18 * fontScale,
              italic: true,
              verse: verse,
              color: scheme.onSurface,
              onSelectionChanged: onPaliSelection == null
                  ? null
                  : (selection) => onPaliSelection!(segment, selection),
            ),
          ],
          if (visibleTranslation) ...[
            const SizedBox(height: 12),
            _TextBlock(
              label: tipitakaLanguageLabel(
                translation.language ?? primaryLanguage,
              ).toUpperCase(),
              text: translation.text,
              fontSize: 16 * fontScale,
              color: scheme.onSurface,
              tinted: true,
            ),
          ],
          if (showEnglishBlock) ...[
            const SizedBox(height: 12),
            _TextBlock(
              label: 'ENGLISH',
              text: englishText,
              fontSize: 16 * fontScale,
              color: scheme.onSurface,
              tinted: true,
            ),
          ],
          if (!hasVisibleText)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                context.uiText('Đoạn này chưa có nội dung văn bản.'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          const SizedBox(height: 16),
          Divider(
            height: 1,
            thickness: .6,
            color: scheme.outlineVariant.withValues(alpha: .7),
          ),
        ],
      ),
    );
  }
}

/// Reference chip + per-paragraph actions, adaptive to the available width so
/// the workspace split view on narrow screens never overflows: page markers
/// and the line number drop first, then save/learn fold into an overflow
/// menu, and in the tightest panes everything lives in that menu.
class _SegmentMetaBar extends StatelessWidget {
  final TipitakaSegment segment;
  final int number;
  final bool isSpeaking;
  final Future<void> Function(TipitakaSegment segment)? onSpeakSegment;
  final Future<void> Function(TipitakaSegment segment)? onSaveSegment;
  final Future<void> Function(TipitakaSegment segment)? onLearnSegment;

  const _SegmentMetaBar({
    required this.segment,
    required this.number,
    required this.isSpeaking,
    this.onSpeakSegment,
    this.onSaveSegment,
    this.onLearnSegment,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 430;
        final tight = constraints.maxWidth < 330;
        final menuItems = <PopupMenuEntry<String>>[
          if (tight && onSpeakSegment != null)
            PopupMenuItem<String>(
              value: 'speak',
              child: _menuRow(
                context,
                isSpeaking ? Icons.stop_circle : Icons.volume_up_outlined,
                isSpeaking
                    ? context.uiText('Dừng đọc đoạn')
                    : context.uiText('Đọc đoạn này'),
              ),
            ),
          if (onSaveSegment != null)
            PopupMenuItem<String>(
              value: 'save',
              child: _menuRow(
                context,
                Icons.bookmark_add_outlined,
                context.uiText('Lưu đoạn vào Worklist'),
              ),
            ),
          if (onLearnSegment != null)
            PopupMenuItem<String>(
              value: 'learn',
              child: _menuRow(
                context,
                Icons.school_outlined,
                context.uiText('Học thuộc đoạn này'),
              ),
            ),
        ];
        final useOverflowMenu = tight ||
            (compact && (onSaveSegment != null || onLearnSegment != null));
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: .75),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  _referenceLabel(context, segment, number),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
            if (!compact)
              for (final marker
                  in tipitakaPageMarkers(segment.paliText).take(2))
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      border: Border.all(color: scheme.outlineVariant),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      marker,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ),
            const Spacer(),
            if (onSpeakSegment != null && !tight)
              IconButton(
                tooltip: isSpeaking
                    ? context.uiText('Dừng đọc đoạn')
                    : context.uiText('Đọc đoạn này'),
                visualDensity: VisualDensity.compact,
                color: scheme.onSurfaceVariant,
                onPressed: () => onSpeakSegment!(segment),
                icon: Icon(
                  isSpeaking ? Icons.stop_circle : Icons.volume_up_outlined,
                ),
              ),
            if (useOverflowMenu && menuItems.isNotEmpty)
              PopupMenuButton<String>(
                tooltip: context.uiText('Thêm thao tác'),
                iconSize: 21,
                padding: EdgeInsets.zero,
                icon: Icon(Icons.more_vert, color: scheme.onSurfaceVariant),
                onSelected: (value) {
                  if (value == 'speak') {
                    onSpeakSegment?.call(segment);
                  } else if (value == 'save') {
                    onSaveSegment?.call(segment);
                  } else if (value == 'learn') {
                    onLearnSegment?.call(segment);
                  }
                },
                itemBuilder: (context) => menuItems,
              )
            else ...[
              if (onSaveSegment != null)
                IconButton(
                  tooltip: context.uiText('Lưu đoạn vào Worklist'),
                  visualDensity: VisualDensity.compact,
                  color: scheme.onSurfaceVariant,
                  onPressed: () => onSaveSegment!(segment),
                  icon: const Icon(Icons.bookmark_add_outlined),
                ),
              if (onLearnSegment != null)
                IconButton(
                  tooltip: context.uiText('Học thuộc đoạn này'),
                  visualDensity: VisualDensity.compact,
                  color: scheme.onSurfaceVariant,
                  onPressed: () => onLearnSegment!(segment),
                  icon: const Icon(Icons.school_outlined),
                ),
            ],
            if (!compact)
              Text(
                '#$number',
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        );
      },
    );
  }

  Widget _menuRow(BuildContext context, IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 19),
        const SizedBox(width: 10),
        Flexible(child: Text(label, maxLines: 1)),
      ],
    );
  }
}

String _referenceLabel(
  BuildContext context,
  TipitakaSegment segment,
  int number,
) {
  final reference = segment.reference.trim();
  final technical = reference.isEmpty ||
      reference.contains('_') ||
      RegExp(r'^(SEG|ROW|PARA)?\s*\d+$', caseSensitive: false)
          .hasMatch(reference);
  if (technical) return '${context.uiText('Đoạn')} $number';
  return reference;
}

/// Resolves the best translation for display: primary language first, then
/// the fixed translation columns, then any imported translation pack.
({String text, String? language}) _resolveTranslation(
  TipitakaSegment segment,
  String primaryLanguage,
) {
  final primary = cleanTipitakaText(segment.translationFor(primaryLanguage));
  if (primary.isNotEmpty) return (text: primary, language: primaryLanguage);
  for (final code in const ['vi', 'en', 'my', 'th']) {
    if (code == primaryLanguage) continue;
    final text = cleanTipitakaText(segment.translationFor(code));
    if (text.isNotEmpty) return (text: text, language: code);
  }
  final other = segment.firstTranslation;
  if (other != null) {
    final text = cleanTipitakaText(other.value);
    if (text.isNotEmpty) return (text: text, language: other.key);
  }
  return (text: '', language: null);
}

class _HeadingBlock extends StatelessWidget {
  final TipitakaBlockKind kind;
  final String paliText;
  final String translationText;
  final String englishText;
  final double fontScale;

  const _HeadingBlock({
    required this.kind,
    required this.paliText,
    required this.translationText,
    required this.englishText,
    required this.fontScale,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isBook = kind == TipitakaBlockKind.book;
    final isChapter = kind == TipitakaBlockKind.chapter;
    final isCenter = kind == TipitakaBlockKind.center;
    final titleSize =
        (isBook ? 22.0 : isChapter ? 20.0 : isCenter ? 17.0 : 18.0) *
            fontScale;
    final centered = isBook || isCenter;
    return Padding(
      padding: EdgeInsets.fromLTRB(6, isBook ? 26 : 16, 6, 6),
      child: Column(
        crossAxisAlignment:
            centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          if (paliText.isNotEmpty)
            SelectableText(
              paliText,
              textAlign: centered ? TextAlign.center : TextAlign.start,
              style: TextStyle(
                fontSize: titleSize,
                height: 1.35,
                fontWeight:
                    isBook || isChapter ? FontWeight.w800 : FontWeight.w700,
                fontStyle: isCenter ? FontStyle.italic : FontStyle.normal,
                color: scheme.primary,
                fontFamilyFallback: tipitakaSerifFallback,
              ),
            ),
          if (translationText.isNotEmpty) ...[
            const SizedBox(height: 5),
            SelectableText(
              translationText,
              textAlign: centered ? TextAlign.center : TextAlign.start,
              style: TextStyle(
                fontSize: titleSize * .76,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: scheme.secondary,
                fontFamilyFallback: tipitakaSerifFallback,
              ),
            ),
          ],
          if (englishText.isNotEmpty) ...[
            const SizedBox(height: 4),
            SelectableText(
              englishText,
              textAlign: centered ? TextAlign.center : TextAlign.start,
              style: TextStyle(
                fontSize: titleSize * .68,
                height: 1.45,
                color: scheme.onSurfaceVariant,
                fontFamilyFallback: tipitakaSerifFallback,
              ),
            ),
          ],
          if (paliText.isEmpty &&
              translationText.isEmpty &&
              englishText.isEmpty)
            Text(context.uiText('Đoạn tiêu đề chưa có nội dung.')),
          const SizedBox(height: 12),
          Divider(
            height: 1,
            thickness: .6,
            indent: isBook ? 60 : 0,
            endIndent: isBook ? 60 : 0,
            color: scheme.outlineVariant,
          ),
        ],
      ),
    );
  }
}

class _TextBlock extends StatelessWidget {
  final String label;
  final String text;
  final double fontSize;
  final bool italic;
  final bool verse;
  final Color color;
  final bool tinted;
  final ValueChanged<TextSelection>? onSelectionChanged;

  const _TextBlock({
    required this.label,
    required this.text,
    required this.fontSize,
    required this.color,
    this.italic = false,
    this.verse = false,
    this.tinted = false,
    this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(verse ? 26 : 13, 10, 13, 11),
      decoration: BoxDecoration(
        color: tinted
            ? scheme.surfaceContainerHighest.withValues(alpha: .45)
            : null,
        border: Border(
          left: BorderSide(
            color: tinted ? scheme.secondary : scheme.primary,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w800,
                  color: tinted ? scheme.secondary : scheme.primary,
                ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            text,
            onSelectionChanged: onSelectionChanged == null
                ? null
                : (selection, _) => onSelectionChanged!(selection),
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              height: 1.72,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              fontFamilyFallback: tipitakaSerifFallback,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionLabel extends StatelessWidget {
  final String label;

  const _SettingsSectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            letterSpacing: .4,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }
}
