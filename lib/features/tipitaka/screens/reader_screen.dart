import 'package:in4up/core/language/localized_material.dart';

import 'package:in4up/features/tipitaka/models/segment.dart';
import 'package:in4up/features/tipitaka/screens/download_screen.dart';
import 'package:in4up/features/tipitaka/services/db_service.dart';

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

  const TipitakaReaderScreen({
    super.key,
    required this.bookId,
    required this.bookCode,
    this.bookName = '',
  });

  @override
  State<TipitakaReaderScreen> createState() => _TipitakaReaderScreenState();
}

class _TipitakaReaderScreenState extends State<TipitakaReaderScreen> {
  static const _pageSize = 60;

  final _scrollController = ScrollController();
  List<TipitakaSegment> _segments = const [];
  int _totalCount = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  bool _showPali = true;
  bool _showVietnamese = true;
  bool _showEnglish = false;
  double _fontScale = 1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
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
        _hasMore = true;
      });
    }
    try {
      final db = await TipitakaDb.openReady();
      final total = await TipitakaDb.getBookSegmentCount(db, widget.bookId);
      final firstPage = await TipitakaDb.getSegmentsByBook(
        db,
        widget.bookId,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _totalCount = total;
        _segments = firstPage;
        _hasMore = firstPage.length < total;
        _loading = false;
      });
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
        offset: _segments.length,
      );
      if (!mounted) return;
      setState(() {
        _segments = [..._segments, ...nextPage];
        _hasMore = _segments.length < _totalCount && nextPage.isNotEmpty;
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
                      onChanged: (value) => update(() => _showPali = value ?? true),
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
                      onChanged: (value) => update(() => _showEnglish = value ?? false),
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null && _segments.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('${widget.bookCode} — Tipiṭaka')),
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

    final title = widget.bookName.trim().isEmpty
        ? widget.bookCode
        : widget.bookName;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              widget.bookCode,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: context.uiText('Về đầu sách'),
            onPressed: _scrollToTop,
            icon: const Icon(Icons.vertical_align_top),
          ),
          IconButton(
            tooltip: context.uiText('Cài đặt hiển thị'),
            onPressed: _openSettings,
            icon: const Icon(Icons.tune),
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
                segment: _segments[index - 1],
                number: index,
                showPali: _showPali,
                showVietnamese: _showVietnamese,
                showEnglish: _showEnglish,
                fontScale: _fontScale,
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
        : (_segments.length / _totalCount).clamp(0.0, 1.0);
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
              context.uiText(
                'Đọc song song Pāli và bản dịch theo từng đoạn. Nội dung sẽ tự tải thêm khi cuộn.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: progress),
            ),
            const SizedBox(height: 6),
            Text(
              '${_segments.length}/$_totalCount ${context.uiText('đoạn đã tải')}',
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

  const _SegmentCard({
    required this.segment,
    required this.number,
    required this.showPali,
    required this.showVietnamese,
    required this.showEnglish,
    required this.fontScale,
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
    final hasVisibleText = (showPali && paliText.isNotEmpty) ||
        (showVietnamese && hasVietnamese) ||
        (displayEnglish && hasEnglish);
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

  const _TextBlock({
    required this.label,
    required this.text,
    required this.fontSize,
    required this.color,
    this.italic = false,
    this.tinted = false,
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
