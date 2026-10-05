import 'package:in4up/core/language/localized_material.dart';

import 'package:in4up/features/tipitaka/models/book.dart';
import 'package:in4up/features/tipitaka/models/collection.dart';
import 'package:in4up/features/tipitaka/models/highlight.dart';
import 'package:in4up/features/tipitaka/models/segment.dart';
import 'package:in4up/features/tipitaka/screens/download_screen.dart';
import 'package:in4up/features/tipitaka/screens/search_screen.dart';
import 'package:in4up/features/tipitaka/screens/workspace_screen.dart';
import 'package:in4up/features/tipitaka/services/db_service.dart';
import 'package:in4up/features/tipitaka/services/reading_position_store.dart';
import 'package:in4up/features/tipitaka/services/tipitaka_markup.dart';

/// Canonical-content tree:
/// Tam Tạng Chính Văn → Tạng → nhóm/bộ → bài kinh.
class TipitakaLibraryScreen extends StatefulWidget {
  const TipitakaLibraryScreen({super.key});

  @override
  State<TipitakaLibraryScreen> createState() => _TipitakaLibraryScreenState();
}

class _TipitakaLibraryScreenState extends State<TipitakaLibraryScreen> {
  List<TipitakaCollection> _collections = const [];
  Map<int, List<TipitakaBook>> _booksByCollection = const {};
  Set<String> _languages = const {};
  List<({TipitakaReadingPosition position, TipitakaBook book})>
      _recentPositions = const [];
  String _language = 'en';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = Localizations.localeOf(context).languageCode;
    if (language == _language) return;
    _language = language;
    if (!_loading) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final db = await TipitakaDb.openReady();
      final collections = await TipitakaDb.getCollections(db);
      // Chỉ tải catalogue cấp cao ở startup. Danh sách sách/tiêu đề được
      // tải theo nhu cầu khi người dùng mở từng Tạng; database Tipitaka có
      // thể rất lớn và không nên chặn màn hình khởi động.
      final info = await TipitakaDb.info(db);
      if (!mounted) return;
      setState(() {
        _collections = collections;
        _booksByCollection = const {};
        _languages = info.availableLanguages;
        _loading = false;
      });
      _loadRecentPositions();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _collections = const [];
        _booksByCollection = const {};
        _error = error.toString();
      });
    }
  }

  Future<void> _openDataManager() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TipitakaDownloadScreen()),
    );
    if (mounted) _load();
  }

  /// Loads up to 3 resumable reading positions ("Đọc tiếp") and resolves
  /// them to books still present in the current database.
  Future<void> _loadRecentPositions() async {
    try {
      final positions = await TipitakaReadingPositions.loadAll();
      if (positions.isEmpty) {
        if (mounted && _recentPositions.isNotEmpty) {
          setState(() => _recentPositions = const []);
        }
        return;
      }
      final db = await TipitakaDb.openReady();
      final recent =
          <({TipitakaReadingPosition position, TipitakaBook book})>[];
      for (final position in positions) {
        if (recent.length >= 3) break;
        if (position.pixels <
            TipitakaReadingPositions.minMeaningfulPixels) {
          continue;
        }
        final book = await TipitakaDb.getBookById(db, position.bookId);
        if (book != null) {
          recent.add((position: position, book: book));
        }
      }
      if (mounted) setState(() => _recentPositions = recent);
    } catch (_) {
      // Vị trí đọc là tiện ích phụ — lỗi đọc không được ảnh hưởng thư viện.
    }
  }

  void _openReader(
    TipitakaBook book, {
    TipitakaSegment? segment,
    String? articleTitle,
  }) {
    final language = Localizations.localeOf(context).languageCode;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TipitakaWorkspaceScreen(
          initialTab: TipitakaWorkspaceTab(
            book: book,
            title: articleTitle ?? book.displayTitle(language),
            initialSegmentId: segment?.id,
          ),
        ),
      ),
    );
  }

  Future<void> _openHighlight(TipitakaHighlight highlight) async {
    final db = await TipitakaDb.openReady();
    final book = await TipitakaDb.getBookById(db, highlight.bookId);
    if (!mounted || book == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TipitakaWorkspaceScreen(
          initialTab: TipitakaWorkspaceTab(
            book: book,
            title: book.displayTitle(_language),
            initialSegmentId: highlight.segmentId,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
      appBar: AppBar(
        title: Text(context.uiText('Thư viện Tipiṭaka')),
        actions: [
          IconButton(
            onPressed: _error == null
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TipitakaSearchScreen(),
                      ),
                    )
                : null,
            tooltip: context.uiText('Tìm kiếm'),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            onPressed: _openDataManager,
            tooltip: context.uiText('Quản lý dữ liệu'),
            icon: const Icon(Icons.storage_outlined),
          ),
        ],
        bottom: TabBar(
          tabs: [
            Tab(text: context.uiText('Thư viện')),
            Tab(text: context.uiText('Đánh dấu')),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _MissingDatabaseView(
                  onManage: _openDataManager,
                  onRetry: _load,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
                    children: [
                      if (_recentPositions.isNotEmpty) ...[
                        _RecentPositionsCard(
                          entries: _recentPositions,
                          onOpen: (entry) => _openReader(entry.book),
                          onRemove: (position) async {
                            await TipitakaReadingPositions.remove(
                              position.bookId,
                            );
                            await _loadRecentPositions();
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                      _LibraryStatusCard(languages: _languages),
                      const SizedBox(height: 10),
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: ExpansionTile(
                          initiallyExpanded: true,
                          leading: const Icon(Icons.account_balance_outlined),
                          title: Text(
                            context.uiText('Tam Tạng Chính Văn'),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            context.uiText('Tạng → nhóm/bộ → bài kinh'),
                          ),
                          children: [
                            for (final collection in _collections)
                              _CollectionTreeNode(
                                collection: collection,
                                books: _booksByCollection[collection.id] ?? const [],
                                onLoadBooks: () async {
                                  final db = await TipitakaDb.openReady();
                                  final loaded = await TipitakaDb.getBooksByCollection(
                                    db, collection.id, languageCode: _language);
                                  if (mounted) setState(() => _booksByCollection = {
                                    ..._booksByCollection, collection.id: loaded});
                                },
                                onOpen: _openReader,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          _HighlightsView(onOpen: _openHighlight),
        ],
      ),
    ));
  }
}

class _HighlightsView extends StatefulWidget {
  final Future<void> Function(TipitakaHighlight highlight) onOpen;

  const _HighlightsView({required this.onOpen});

  @override
  State<_HighlightsView> createState() => _HighlightsViewState();
}

class _HighlightsViewState extends State<_HighlightsView> {
  late Future<List<TipitakaHighlight>> _items = _load();

  Future<List<TipitakaHighlight>> _load() async {
    final db = await TipitakaDb.openReady();
    return TipitakaDb.getHighlights(db);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TipitakaHighlight>>(
      future: _items,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                context.uiText('Chưa có đoạn được đánh dấu. Nhấn giữ một đoạn khi đọc để bắt đầu.'),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            setState(() => _items = _load());
            await _items;
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              final excerpt = cleanTipitakaText(item.paliText).trim();
              return ListTile(
                leading: const Icon(Icons.highlight_outlined),
                title: Text(
                  item.reference.trim().isEmpty ? context.uiText('Đoạn đã đánh dấu') : item.reference,
                ),
                subtitle: Text(
                  [
                    if (item.bookTitle.isNotEmpty) item.bookTitle,
                    if (excerpt.isNotEmpty) excerpt,
                    if (item.note.isNotEmpty) item.note,
                  ].join('\n'),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => widget.onOpen(item),
              );
            },
          ),
        );
      },
    );
  }
}

/// "Đọc tiếp" card — resumes books at their saved scroll positions.
class _RecentPositionsCard extends StatelessWidget {
  final List<({TipitakaReadingPosition position, TipitakaBook book})> entries;
  final void Function(({TipitakaReadingPosition position, TipitakaBook book})
      entry) onOpen;
  final void Function(TipitakaReadingPosition position) onRemove;

  const _RecentPositionsCard({
    required this.entries,
    required this.onOpen,
    required this.onRemove,
  });

  static String _formatSavedAt(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(time.day)}/${two(time.month)}/${time.year} '
        '${two(time.hour)}:${two(time.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
            child: Row(
              children: [
                Icon(Icons.history_edu_outlined,
                    size: 19, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  context.uiText('Đọc tiếp'),
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          for (final entry in entries)
            ListTile(
              dense: true,
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(
                entry.book.displayTitle(language),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(_formatSavedAt(entry.position.savedAt)),
              trailing: IconButton(
                tooltip: context.uiText('Xóa vị trí đã lưu'),
                visualDensity: VisualDensity.compact,
                onPressed: () => onRemove(entry.position),
                icon: const Icon(Icons.close, size: 18),
              ),
              onTap: () => onOpen(entry),
            ),
        ],
      ),
    );
  }
}

class _LibraryStatusCard extends StatelessWidget {
  final Set<String> languages;

  const _LibraryStatusCard({required this.languages});

  @override
  Widget build(BuildContext context) {
    final hasPali = languages.contains('pi');
    return Card(
      color: hasPali
          ? null
          : Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: .55),
      child: ListTile(
        leading: Icon(hasPali ? Icons.auto_stories : Icons.info_outline),
        title: Text(context.uiText('Đọc Tam Tạng theo ngôn ngữ đã import')),
        subtitle: Text(
          hasPali
              ? context.uiText('Có thể đối chiếu Pāli và bản dịch theo đoạn.')
              : context.uiText(
                  'Bản dịch vẫn đọc độc lập. Nên import Pāli để đối chiếu tốt hơn; song ngữ và căn hàng đang tạm giảm cấp.',
                ),
        ),
        trailing: Text(languages.join(' · ')),
      ),
    );
  }
}

class _CollectionTreeNode extends StatefulWidget {
  final TipitakaCollection collection;
  final List<TipitakaBook> books;
  final Future<void> Function() onLoadBooks;
  final void Function(
    TipitakaBook book, {
    TipitakaSegment? segment,
    String? articleTitle,
  }) onOpen;

  const _CollectionTreeNode({
    required this.collection,
    required this.books,
    required this.onLoadBooks,
    required this.onOpen,
  });

  @override
  State<_CollectionTreeNode> createState() => _CollectionTreeNodeState();
}

class _CollectionTreeNodeState extends State<_CollectionTreeNode> {
  bool _expanded = false;
  bool _loading = false;

  /// Piṭaka identity: title, icon and accent colour per basket, so the three
  /// Tipiṭaka divisions are visually distinct like on OpenTipitaka.
  ({String title, IconData icon, Color color}) _style(String language) {
    final names = '${widget.collection.namePali} ${widget.collection.nameEn} ${widget.collection.nameVi}'
        .toLowerCase();
    if (names.contains('vin') || names.contains('luật')) {
      return (
        title: language == 'vi' ? 'Tạng Luật' : 'Vinaya Piṭaka',
        icon: Icons.balance_outlined,
        color: Colors.deepPurple,
      );
    }
    if (names.contains('abh') || names.contains('diệu')) {
      return (
        title: language == 'vi' ? 'Tạng Luận' : 'Abhidhamma Piṭaka',
        icon: Icons.psychology_outlined,
        color: Colors.deepOrange,
      );
    }
    return (
      title: language == 'vi' ? 'Tạng Kinh' : 'Sutta Piṭaka',
      icon: Icons.menu_book_outlined,
      color: Colors.teal,
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    final style = _style(language);
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ExpansionTile(
        initiallyExpanded: _expanded,
        onExpansionChanged: (value) async {
          setState(() => _expanded = value);
          if (value && widget.books.isEmpty && !_loading) {
            setState(() => _loading = true);
            try { await widget.onLoadBooks(); } finally { if (mounted) setState(() => _loading = false); }
          }
        },
        leading: CircleAvatar(
          radius: 17,
          backgroundColor: style.color.withValues(alpha: .14),
          child: Icon(style.icon, size: 18, color: style.color),
        ),
        title: Text(
          style.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: _loading
            ? const Text('Đang tải mục lục…')
            : Text('${widget.books.length} ${context.uiText('nhóm/bộ')}'),
        children: _loading
            ? [const LinearProgressIndicator(minHeight: 2)]
            : [for (final book in widget.books)
                _BookTreeNode(book: book, onOpen: widget.onOpen)],
      ),
    );
  }
}

class _BookTreeNode extends StatefulWidget {
  final TipitakaBook book;
  final void Function(
    TipitakaBook book, {
    TipitakaSegment? segment,
    String? articleTitle,
  }) onOpen;

  const _BookTreeNode({required this.book, required this.onOpen});

  @override
  State<_BookTreeNode> createState() => _BookTreeNodeState();
}

class _BookTreeNodeState extends State<_BookTreeNode> {
  List<TipitakaSegment>? _outline;
  bool _loading = false;

  Future<void> _loadOutline(bool expanded) async {
    if (!expanded || _outline != null || _loading) return;
    setState(() => _loading = true);
    try {
      final db = await TipitakaDb.openReady();
      final outline = await TipitakaDb.getBookOutline(db, widget.book.id);
      if (mounted) setState(() => _outline = outline);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _articleTitle(TipitakaSegment segment, String language) {
    final selected = language == 'vi'
        ? segment.translationFor('vi')
        : segment.translationFor(language);
    final fallback = segment.paliText.trim().isNotEmpty
        ? segment.paliText
        : segment.firstTranslation?.value ?? '';
    final clean = _cleanText(selected.trim().isNotEmpty ? selected : fallback);
    if (clean.isEmpty) {
      return language == 'vi' ? 'Bài kinh' : 'Discourse';
    }
    return clean.length > 110 ? '${clean.substring(0, 110)}…' : clean;
  }

  void _showDetails(BuildContext context) {
    final index = widget.book.catalogIndex;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.data_object),
          title: Text(context.uiText('Chi tiết kỹ thuật')),
          subtitle: Text(
            '${index.normalizedCode}\n${index.sourceTable}\n${widget.book.metadataJson ?? ''}',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    final outline = _outline;
    final edition = widget.book.catalogIndex.editionLabel;
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 4),
      child: ExpansionTile(
        onExpansionChanged: _loadOutline,
        leading: const Icon(Icons.library_books_outlined),
        title: Text(widget.book.displayTitle(language)),
        subtitle: edition.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .secondaryContainer
                          .withValues(alpha: .55),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      edition,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSecondaryContainer,
                          ),
                    ),
                  ),
                ),
              ),
        trailing: IconButton(
          onPressed: () => _showDetails(context),
          tooltip: context.uiText('Chi tiết kỹ thuật'),
          icon: const Icon(Icons.info_outline, size: 19),
        ),
        children: [
          ListTile(
            contentPadding: const EdgeInsets.only(left: 48, right: 12),
            leading: const Icon(Icons.chrome_reader_mode_outlined),
            title: Text(context.uiText('Đọc toàn bộ nhóm/bộ')),
            onTap: () => widget.onOpen(widget.book),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            )
          else if (outline != null)
            for (final segment in outline)
              ListTile(
                contentPadding: const EdgeInsets.only(left: 58, right: 12),
                leading: const Icon(Icons.article_outlined, size: 19),
                title: Text(_articleTitle(segment, language)),
                onTap: () => widget.onOpen(
                  widget.book,
                  segment: segment,
                  articleTitle: _articleTitle(segment, language),
                ),
              ),
        ],
      ),
    );
  }
}

String _cleanText(String value) => value
    .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'</\s*p\s*>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'<[^>]*>'), ' ')
    .replaceAll(RegExp(r'[ \t]+'), ' ')
    .trim();

class _MissingDatabaseView extends StatelessWidget {
  final VoidCallback onManage;
  final VoidCallback onRetry;

  const _MissingDatabaseView({required this.onManage, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book_outlined, size: 64),
            const SizedBox(height: 16),
            Text(
              context.uiText('Tipiṭaka chưa có dữ liệu'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              context.uiText(
                'Import một gói ngôn ngữ bất kỳ để bắt đầu. Pāli được khuyến nghị nhưng không bắt buộc.',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onManage,
              icon: const Icon(Icons.storage),
              label: Text(context.uiText('Import hoặc tải dữ liệu')),
            ),
            TextButton(
              onPressed: onRetry,
              child: Text(context.uiText('Thử lại')),
            ),
          ],
        ),
      ),
    );
  }
}
