import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:in4up/features/learn_by_heart/controllers/learn_by_heart_provider.dart';
import 'package:in4up/features/tipitaka/models/book.dart';
import 'package:in4up/features/tipitaka/models/segment.dart';
import 'package:in4up/features/tipitaka/services/tipitaka_learn_by_heart_service.dart';
import 'package:in4up/features/tipitaka/services/tipitaka_worklist_service.dart';
import 'package:in4up/models/vocabulary_type.dart';
import 'package:in4up/providers/vocabulary_provider.dart';
import 'package:in4up/features/tipitaka/screens/download_screen.dart';
import 'package:in4up/features/tipitaka/services/db_service.dart';
import 'package:in4up/features/tts/tts_service.dart';

/// A continuous, paragraph-aligned Tipiṭaka reader.
///
/// The old reader loaded only the first 50 rows and showed one paragraph at a
/// time. That made a successful import look incomplete. This reader keeps the
/// page-like reading flow of OpenTipitaka while loading the book in pages as
/// the reader approaches the end.
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
  List<TipitakaSegment> _segments = const [];
  int _totalCount = 0;
  int _loadedOffset = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  bool _showPali = true;
  bool _hasPali = true;
  Set<String> _availableLanguages = const {};
  bool _showVietnamese = true;
  bool _showEnglish = false;
  double _fontScale = 1;
  bool _selectionSheetOpen = false;
  final _initialSegmentKey = GlobalKey();
  late final TipitakaBook _worklistBook;
  late int? _requestedSegmentId;
  final TtsService _tts = TtsService();
  int? _speakingSegmentId;
  bool _readingArticle = false;
  int _ttsCursor = 0;

  @override
  void initState() {
    super.initState();
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
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    if (_readingArticle || _speakingSegmentId != null) {
      _globalTtsGeneration++;
      _tts.stop();
    }
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loadingMore || !_hasMore) return;
    if (_scrollController.position.extentAfter < 700) _loadMore();
  }

  Future<void> _loadFirstPage() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _segments = const [];
        _loadedOffset = 0;
        _hasMore = true;
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
        if (!_hasPali) _showPali = false;
        _loadedOffset = requestedOffset;
        _segments = firstPage;
        _hasMore = _loadedOffset + firstPage.length < total;
        _loading = false;
      });
      if (_requestedSegmentId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final target = _initialSegmentKey.currentContext;
          if (target != null) Scrollable.ensureVisible(target, alignment: .25);
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

  Future<void> _openSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void update(VoidCallback change) {
              setSheetState(change);
              setState(change);
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.uiText('Cài đặt hiển thị'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _showPali,
                      title: Text(context.uiText('Pāli nguyên bản')),
                      subtitle: _hasPali
                          ? null
                          : Text(
                              context.uiText(
                                'Chưa import Pāli; bản dịch vẫn đọc độc lập.',
                              ),
                            ),
                      onChanged: !_hasPali
                          ? null
                          : (value) => update(() => _showPali = value ?? true),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _showVietnamese,
                      title: Text(context.uiText('Bản dịch tiếng Việt')),
                      onChanged: (value) => update(() => _showVietnamese = value ?? false),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _showEnglish,
                      title: const Text('English'),
                      onChanged: _availableLanguages.contains('en')
                          ? (value) => update(() => _showEnglish = value ?? false)
                          : null,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _hasPali,
                      title: Text(context.uiText('Căn hàng song ngữ')),
                      subtitle: !_hasPali
                          ? Text(
                              context.uiText(
                                'Tạm tắt vì chưa có Pāli để đối chiếu.',
                              ),
                            )
                          : null,
                      onChanged: null,
                    ),
                    const Divider(),
                    Row(
                      children: [
                        Text(context.uiText('Cỡ chữ')),
                        const Spacer(),
                        IconButton(
                          tooltip: context.uiText('Thu nhỏ chữ'),
                          onPressed: _fontScale <= .85
                              ? null
                              : () => update(() => _fontScale -= .05),
                          icon: const Icon(Icons.text_decrease),
                        ),
                        Text('${(_fontScale * 100).round()}%'),
                        IconButton(
                          tooltip: context.uiText('Phóng to chữ'),
                          onPressed: _fontScale >= 1.35
                              ? null
                              : () => update(() => _fontScale += .05),
                          icon: const Icon(Icons.text_increase),
                        ),
                      ],
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
    final text = _cleanDisplayText(segment.paliText);
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
    final pali = _cleanDisplayText(segment.paliText);
    if (pali.isNotEmpty) return pali;
    final translation = segment.firstTranslation;
    return _cleanDisplayText(translation?.value ?? '');
  }

  String _segmentTranslationLanguage(TipitakaSegment segment) {
    if ((segment.translationVi ?? '').trim().isNotEmpty) return 'vi';
    if ((segment.translationEn ?? '').trim().isNotEmpty) return 'en';
    return segment.firstTranslation?.key ?? 'vi';
  }

  String _segmentReadingText(TipitakaSegment segment) {
    if (_showVietnamese) {
      final vietnamese = _cleanDisplayText(segment.translationFor('vi'));
      if (vietnamese.isNotEmpty) return vietnamese;
    }
    if (_showEnglish) {
      final english = _cleanDisplayText(segment.translationFor('en'));
      if (english.isNotEmpty) return english;
    }
    final other = segment.firstTranslation;
    if (other != null && other.value.trim().isNotEmpty) {
      return _cleanDisplayText(other.value);
    }
    return _cleanDisplayText(segment.paliText);
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
    final translated = Localizations.localeOf(context).languageCode == 'vi'
        ? segment.translationFor('vi')
        : segment.translationFor('en');
    final text = translated.trim().isNotEmpty
        ? translated
        : segment.paliText.trim().isNotEmpty
            ? segment.paliText
            : segment.firstTranslation?.value ?? '';
    final clean = _cleanDisplayText(text);
    return clean.isEmpty ? context.uiText('Mục chưa có tiêu đề') : clean;
  }

  Future<void> _openTableOfContents() async {
    final db = await TipitakaDb.openReady();
    final outline = await TipitakaDb.getBookOutline(db, widget.bookId);
    if (!mounted) return;
    final selected = await showModalBottomSheet<TipitakaSegment>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
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
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: outline.length,
                  itemBuilder: (context, index) => ListTile(
                    leading: Text('${index + 1}'),
                    title: Text(
                      _outlineTitle(outline[index]),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => Navigator.pop(context, outline[index]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null && _segments.isEmpty) {
      return Scaffold(
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
      );
    }

    final requestedTitle = widget.bookName.trim();
    final title = requestedTitle.isEmpty ||
            _worklistBook.isTechnicalTitle(requestedTitle)
        ? _worklistBook.displayTitle(
            Localizations.localeOf(context).languageCode,
          )
        : requestedTitle;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        titleSpacing: 16,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
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
            icon: Icon(_readingArticle ? Icons.stop_circle : Icons.play_circle),
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
      ),
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
        child: ListView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
          itemCount: _segments.length + 2,
          itemBuilder: (context, index) {
            if (index == 0) return _buildBookHeader(context, title);
            if (index <= _segments.length) {
              return _SegmentCard(
                key: _requestedSegmentId == _segments[index - 1].id
                    ? _initialSegmentKey
                    : ValueKey('tipitaka-segment-${_segments[index - 1].id}'),
                segment: _segments[index - 1],
                number: _loadedOffset + index,
                showPali: _showPali,
                showVietnamese: _showVietnamese,
                showEnglish: _showEnglish,
                fontScale: _fontScale,
                isSpeaking: _speakingSegmentId == _segments[index - 1].id,
                onSpeakSegment: (segment) => _toggleSegmentTts(
                  segment,
                  _loadedOffset + index - 1,
                ),
                onPaliSelection: _onPaliSelection,
                onSaveSegment: _saveWholeSegment,
                onLearnSegment: _learnWholeSegment,
              );
            }
            return _buildEndOfBook(context);
          },
        ),
      ),
    );
  }

  Widget _buildBookHeader(BuildContext context, String title) {
    final progress = _totalCount == 0
        ? 0.0
        : ((_loadedOffset + _segments.length) / _totalCount).clamp(0.0, 1.0);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              _hasPali
                  ? context.uiText(
                      'Đọc song song Pāli và bản dịch theo từng đoạn. Nội dung sẽ tự tải thêm khi cuộn.',
                    )
                  : context.uiText(
                      'Đang đọc bản dịch độc lập. Nên import Pāli để đối chiếu tốt hơn; song ngữ và căn hàng hiện tạm giảm cấp.',
                    ),
              style: Theme.of(context).textTheme.bodySmall,
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
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: progress),
            ),
            const SizedBox(height: 6),
            Text(
              '${_loadedOffset + _segments.length}/$_totalCount ${context.uiText('đoạn đã tải')}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEndOfBook(BuildContext context) {
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
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Center(
        child: Text(
          context.uiText('Đã hiển thị toàn bộ nội dung sách.'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

class _SegmentCard extends StatelessWidget {
  final TipitakaSegment segment;
  final int number;
  final bool showPali;
  final bool showVietnamese;
  final bool showEnglish;
  final double fontScale;
  final bool isSpeaking;
  final Future<void> Function(TipitakaSegment segment)? onSpeakSegment;
  final void Function(TipitakaSegment segment, TextSelection selection)?
      onPaliSelection;
  final Future<void> Function(TipitakaSegment segment)? onSaveSegment;
  final Future<void> Function(TipitakaSegment segment)? onLearnSegment;

  const _SegmentCard({
    super.key,
    required this.segment,
    required this.number,
    required this.showPali,
    required this.showVietnamese,
    required this.showEnglish,
    required this.fontScale,
    required this.isSpeaking,
    this.onSpeakSegment,
    this.onPaliSelection,
    this.onSaveSegment,
    this.onLearnSegment,
  });

  @override
  Widget build(BuildContext context) {
    final paliText = _cleanDisplayText(segment.paliText);
    final vietnameseText = _cleanDisplayText(segment.translationVi ?? '');
    final englishText = _cleanDisplayText(segment.translationEn ?? '');
    final hasVietnamese = vietnameseText.isNotEmpty;
    final hasEnglish = englishText.isNotEmpty;
    final displayEnglish =
        hasEnglish && (showEnglish || !showVietnamese || !hasVietnamese);
    final otherTranslation = !hasVietnamese && !hasEnglish
        ? segment.firstTranslation
        : null;
    final otherText = _cleanDisplayText(otherTranslation?.value ?? '');
    final hasVisibleText = (showPali && paliText.isNotEmpty) ||
        (showVietnamese && hasVietnamese) ||
        (displayEnglish && hasEnglish) ||
        otherText.isNotEmpty;
    final reference = segment.reference.trim().isEmpty
        ? 'M $number'
        : segment.reference.trim();
    final blockType = _displayBlockType(segment);

    if (blockType != 'paragraph') {
      return _HeadingCard(
        blockType: blockType,
        paliText: showPali ? paliText : '',
        vietnameseText: showVietnamese ? vietnameseText : '',
        englishText: displayEnglish ? englishText : '',
        fontScale: fontScale,
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 15, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    reference,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                if (onSpeakSegment != null)
                  IconButton(
                    tooltip: isSpeaking
                        ? context.uiText('Dừng đọc đoạn')
                        : context.uiText('Đọc đoạn này'),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onSpeakSegment!(segment),
                    icon: Icon(
                      isSpeaking ? Icons.stop_circle : Icons.volume_up_outlined,
                    ),
                  ),
                if (onSaveSegment != null)
                  IconButton(
                    tooltip: context.uiText('Lưu đoạn vào Worklist'),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onSaveSegment!(segment),
                    icon: const Icon(Icons.bookmark_add_outlined),
                  ),
                if (onLearnSegment != null)
                  IconButton(
                    tooltip: context.uiText('Học thuộc đoạn này'),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onLearnSegment!(segment),
                    icon: const Icon(Icons.school_outlined),
                  ),
                Text(
                  '#$number',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            if (showPali && paliText.isNotEmpty) ...[
              const SizedBox(height: 15),
              _TextBlock(
                label: 'PĀḶI',
                text: paliText,
                fontSize: 18 * fontScale,
                italic: true,
                color: Theme.of(context).colorScheme.onSurface,
                onSelectionChanged: onPaliSelection == null
                    ? null
                    : (selection) => onPaliSelection!(segment, selection),
              ),
            ],
            if (showVietnamese && hasVietnamese) ...[
              const SizedBox(height: 15),
              _TextBlock(
                label: context.uiText('Tiếng Việt'),
                text: vietnameseText,
                fontSize: 16 * fontScale,
                color: Theme.of(context).colorScheme.onSurface,
                tinted: true,
              ),
            ],
            if (displayEnglish && hasEnglish) ...[
              const SizedBox(height: 15),
              _TextBlock(
                label: 'ENGLISH',
                text: englishText,
                fontSize: 16 * fontScale,
                color: Theme.of(context).colorScheme.onSurface,
                tinted: true,
              ),
            ],
            if (otherText.isNotEmpty) ...[
              const SizedBox(height: 15),
              _TextBlock(
                label: (otherTranslation?.key ?? '').toUpperCase(),
                text: otherText,
                fontSize: 16 * fontScale,
                color: Theme.of(context).colorScheme.onSurface,
                tinted: true,
              ),
            ],
            if (!hasVisibleText)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  context.uiText('Đoạn này chưa có nội dung văn bản.'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _displayBlockType(TipitakaSegment segment) {
  if (segment.blockType != 'paragraph') return segment.blockType;
  final raw = segment.paliText.toLowerCase();
  if (raw.contains('rend="book"') || raw.contains("rend='book'")) return 'book';
  if (raw.contains('rend="chapter"') || raw.contains("rend='chapter'")) {
    return 'chapter';
  }
  if (raw.contains('rend="subhead"') ||
      raw.contains('rend="heading"') ||
      raw.contains("rend='subhead'") ||
      raw.contains("rend='heading'")) {
    return 'heading';
  }
  if (raw.contains('rend="centre"') ||
      raw.contains('rend="center"') ||
      raw.contains("rend='centre'") ||
      raw.contains("rend='center'")) {
    return 'center';
  }
  return 'paragraph';
}

String _cleanDisplayText(String value) {
  return value
      .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</\s*p\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&#39;', "'")
      .replaceAll('&quot;', '"')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .trim();
}

class _HeadingCard extends StatelessWidget {
  final String blockType;
  final String paliText;
  final String vietnameseText;
  final String englishText;
  final double fontScale;

  const _HeadingCard({
    required this.blockType,
    required this.paliText,
    required this.vietnameseText,
    required this.englishText,
    required this.fontScale,
  });

  @override
  Widget build(BuildContext context) {
    final isBook = blockType == 'book';
    final isCenter = blockType == 'center';
    final titleSize = (isBook ? 22 : 19) * fontScale;
    return Padding(
      padding: EdgeInsets.fromLTRB(8, isBook ? 22 : 12, 8, 10),
      child: Column(
        crossAxisAlignment:
            isCenter ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          if (paliText.isNotEmpty)
            SelectableText(
              paliText,
              textAlign: isCenter ? TextAlign.center : TextAlign.start,
              style: TextStyle(
                fontSize: titleSize,
                height: 1.45,
                fontWeight: isBook ? FontWeight.w800 : FontWeight.w700,
                fontStyle: isCenter ? FontStyle.italic : FontStyle.normal,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          if (vietnameseText.isNotEmpty) ...[
            const SizedBox(height: 5),
            SelectableText(
              vietnameseText,
              textAlign: isCenter ? TextAlign.center : TextAlign.start,
              style: TextStyle(
                fontSize: (isBook ? 17 : 15) * fontScale,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ],
          if (englishText.isNotEmpty) ...[
            const SizedBox(height: 4),
            SelectableText(
              englishText,
              textAlign: isCenter ? TextAlign.center : TextAlign.start,
              style: TextStyle(
                fontSize: 14 * fontScale,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (paliText.isEmpty && vietnameseText.isEmpty && englishText.isEmpty)
            Text(context.uiText('Đoạn tiêu đề chưa có nội dung.')),
          Divider(
            height: isBook ? 22 : 16,
            color: Theme.of(context).colorScheme.outlineVariant,
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
  final Color color;
  final bool tinted;
  final ValueChanged<TextSelection>? onSelectionChanged;

  const _TextBlock({
    required this.label,
    required this.text,
    required this.fontSize,
    required this.color,
    this.italic = false,
    this.tinted = false,
    this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
      decoration: BoxDecoration(
        color: tinted ? scheme.surfaceContainerHighest.withValues(alpha: .45) : null,
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
          const SizedBox(height: 7),
          SelectableText(
            text,
            onSelectionChanged: onSelectionChanged == null
                ? null
                : (selection, _) => onSelectionChanged!(selection),
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              height: 1.65,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }
}
