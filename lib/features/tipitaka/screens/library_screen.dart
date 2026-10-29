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
  Map<TipitakaCatalogSection, Set<int>> _sectionCollections = const {};
  Set<String> _languages = const {};
  List<({TipitakaReadingPosition position, TipitakaBook book})>
      _recentPositions = const [];
  String _language = 'en';
  String _catalogLanguage = 'en';
  bool _catalogLanguageChosen = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    TipitakaDb.importRevision.addListener(_onDatabaseImported);
    _load();
  }

  @override
  void dispose() {
    TipitakaDb.importRevision.removeListener(_onDatabaseImported);
    super.dispose();
  }

  void _onDatabaseImported() {
    if (mounted) _load();
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
      // Only read the small normalized book index at startup. Content-derived
      // titles stay lazy, while empty taxonomy branches are hidden accurately.
      final indexBooks = await TipitakaDb.getCatalogIndexBooks(db);
      final sectionCollections = <TipitakaCatalogSection, Set<int>>{};
      for (final book in indexBooks) {
        sectionCollections
            .putIfAbsent(book.catalogSection, () => <int>{})
            .add(book.collectionId);
      }
      final info = await TipitakaDb.info(db);
      if (!mounted) return;
      setState(() {
        _collections = collections;
        _sectionCollections = sectionCollections;
        _booksByCollection = const {};
        _languages = info.availableLanguages;
        if (!_catalogLanguageChosen || !info.availableLanguages.contains(_catalogLanguage)) {
          _catalogLanguage = info.availableLanguages.contains(_language)
              ? _language
              : info.availableLanguages.contains('en')
                  ? 'en'
                  : info.availableLanguages.contains('pi')
                      ? 'pi'
                      : info.availableLanguages.isEmpty
                          ? _language
                          : (info.availableLanguages.toList()..sort()).first;
          _catalogLanguageChosen = false;
        }
        _loading = false;
      });
      _loadRecentPositions();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _collections = const [];
        _booksByCollection = const {};
        _sectionCollections = const {};
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
        final book = await TipitakaDb.getBookById(
          db,
          position.bookId,
          languageCode: _catalogLanguage,
        );
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TipitakaWorkspaceScreen(
          initialTab: TipitakaWorkspaceTab(
            book: book,
            title: articleTitle ?? book.displayTitle(_catalogLanguage),
            initialSegmentId: segment?.id,
          ),
        ),
      ),
    );
  }

  Future<void> _openHighlight(TipitakaHighlight highlight) async {
    final db = await TipitakaDb.openReady();
    final book = await TipitakaDb.getBookById(
      db,
      highlight.bookId,
      languageCode: _catalogLanguage,
    );
    if (!mounted || book == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TipitakaWorkspaceScreen(
          initialTab: TipitakaWorkspaceTab(
            book: book,
            title: book.displayTitle(_catalogLanguage),
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
                      if (_languages.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: DropdownButtonFormField<String>(
                              value: _languages.contains(_catalogLanguage)
                                  ? _catalogLanguage
                                  : _languages.first,
                              decoration: InputDecoration(
                                labelText: context.uiText('Ngôn ngữ bản dịch'),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              items: (_languages.toList()..sort()).map((code) {
                                return DropdownMenuItem<String>(
                                  value: code,
                                  child: Text(tipitakaLanguageLabel(code)),
                                );
                              }).toList(),
                              onChanged: (code) {
                                if (code == null) return;
                                setState(() {
                                  _catalogLanguage = code;
                                  _catalogLanguageChosen = true;
                                  _booksByCollection = const {};
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      for (final section in TipitakaCatalogSection.values)
                        if (_sectionCollections.containsKey(section))
                          Card(
                            clipBehavior: Clip.antiAlias,
                            child: ExpansionTile(
                              key: ValueKey('$_catalogLanguage-${section.name}'),
                              initiallyExpanded:
                                  section == TipitakaCatalogSection.canonical,
                              leading: Icon(_catalogSectionIcon(section)),
                              title: Text(
                                context.uiText(section.labelKey),
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              subtitle: Text(
                                context.uiText('Tạng → nhóm/bộ → bài kinh'),
                              ),
                              children: [
                                for (final collection in _collections)
                                  if (_sectionCollections[section]
                                          ?.contains(collection.id) ==
                                      true)
                                    _CollectionTreeNode(
                                      key: ValueKey(
                                        '$_catalogLanguage-${section.name}-${collection.id}',
                                      ),
                                      section: section,
                                      catalogLanguage: _catalogLanguage,
                                      collection: collection,
                                      books: (_booksByCollection[collection.id] ??
                                              const <TipitakaBook>[])
                                          .where((book) =>
                                              book.catalogSection == section)
                                          .toList(),
                                      onLoadBooks: () async {
                                        final db = await TipitakaDb.openReady();
                                        final loaded =
                                            await TipitakaDb.getBooksByCollection(
                                          db,
                                          collection.id,
                                          languageCode: _catalogLanguage,
                                        );
                                        if (mounted) {
                                          setState(() => _booksByCollection = {
                                                ..._booksByCollection,
                                                collection.id: loaded,
                                              });
                                        }
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

IconData _catalogSectionIcon(TipitakaCatalogSection section) => switch (section) {
      TipitakaCatalogSection.canonical => Icons.account_balance_outlined,
      TipitakaCatalogSection.commentary => Icons.menu_book_outlined,
      TipitakaCatalogSection.subcommentary => Icons.notes_outlined,
      TipitakaCatalogSection.extraCanonical => Icons.library_books_outlined,
      TipitakaCatalogSection.sriLanka => Icons.history_edu_outlined,
    };

class _CollectionTreeNode extends StatefulWidget {
  final TipitakaCatalogSection section;
  final String catalogLanguage;
  final TipitakaCollection collection;
  final List<TipitakaBook> books;
  final Future<void> Function() onLoadBooks;
  final void Function(
    TipitakaBook book, {
    TipitakaSegment? segment,
    String? articleTitle,
  }) onOpen;

  const _CollectionTreeNode({
    super.key,
    required this.section,
    required this.catalogLanguage,
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

  String _divisionTitle(BuildContext context) {
    final source = '${widget.collection.namePali} ${widget.collection.nameEn} '
            '${widget.collection.nameVi}'
        .toLowerCase();
    if (source.contains('vin') || source.contains('discipline') || source.contains('luật')) {
      return context.uiText('Tạng Luật');
    }
    if (source.contains('abh') || source.contains('higher dhamma') || source.contains('diệu')) {
      return context.uiText('Tạng Vi Diệu Pháp');
    }
    if (source.contains('sutta') || source.contains('sutra') || source.contains('kinh')) {
      return context.uiText('Tạng Kinh');
    }
    return widget.collection.displayTitle(widget.catalogLanguage);
  }

  Map<String, List<TipitakaBook>> _families() {
    final grouped = <String, List<TipitakaBook>>{};
    for (final book in widget.books) {
      grouped.putIfAbsent(book.catalogIndex.parallelFamilyCode, () => []).add(book);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final families = _families();
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ExpansionTile(
        initiallyExpanded: _expanded,
        onExpansionChanged: (value) async {
          setState(() => _expanded = value);
          if (value && widget.books.isEmpty && !_loading) {
            setState(() => _loading = true);
            try {
              await widget.onLoadBooks();
            } finally {
              if (mounted) setState(() => _loading = false);
            }
          }
        },
        leading: CircleAvatar(
          radius: 17,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(_catalogSectionIcon(widget.section), size: 18),
        ),
        title: Text(
          _divisionTitle(context),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: _loading
            ? Text(context.uiText('Đang tải mục lục…'))
            : Text('${widget.books.length} ${context.uiText('sách')}'),
        children: _loading
            ? [const LinearProgressIndicator(minHeight: 2)]
            : [
                for (final entry in families.entries)
                  if (entry.value.length == 1)
                    _BookTreeNode(
                      key: ValueKey('${widget.catalogLanguage}-${entry.value.single.id}'),
                      book: entry.value.single,
                      catalogLanguage: widget.catalogLanguage,
                      onOpen: widget.onOpen,
                    )
                  else
                    _BookFamilyTreeNode(
                      key: ValueKey('${widget.catalogLanguage}-${widget.section.name}-${widget.collection.id}-${entry.key}'),
                      familyCode: entry.key,
                      books: entry.value,
                      catalogLanguage: widget.catalogLanguage,
                      onOpen: widget.onOpen,
                    ),
              ],
      ),
    );
  }
}

class _BookFamilyTreeNode extends StatelessWidget {
  final String familyCode;
  final List<TipitakaBook> books;
  final String catalogLanguage;
  final void Function(
    TipitakaBook book, {
    TipitakaSegment? segment,
    String? articleTitle,
  }) onOpen;

  const _BookFamilyTreeNode({
    super.key,
    required this.familyCode,
    required this.books,
    required this.catalogLanguage,
    required this.onOpen,
  });

  String _title(BuildContext context) {
    final first = books.first;
    final contentTitle = first.displayTitle(catalogLanguage).trim();
    final withoutEdition = contentTitle.replaceFirst(
      RegExp(r'\s*[·–-]\s*(Mūla|Aṭṭhakathā|Ṭīkā|Mula|Tika)\s*$',
          caseSensitive: false),
      '',
    );
    if (withoutEdition != contentTitle) return withoutEdition;
    if (books.length == 1) return contentTitle;
    return '${context.uiText('Nhóm sách')} · $familyCode';
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 12),
        child: ExpansionTile(
          leading: const Icon(Icons.folder_open_outlined, size: 20),
          title: Text(_title(context)),
          subtitle: Text('${books.length} ${context.uiText('ấn bản')}'),
          children: [
            for (final book in books)
              _BookTreeNode(
                key: ValueKey('$catalogLanguage-${book.id}'),
                book: book,
                catalogLanguage: catalogLanguage,
                onOpen: onOpen,
              ),
          ],
        ),
      );
}

class _BookTreeNode extends StatefulWidget {
  final TipitakaBook book;
  final String catalogLanguage;
  final void Function(
    TipitakaBook book, {
    TipitakaSegment? segment,
    String? articleTitle,
  }) onOpen;

  const _BookTreeNode({
    super.key,
    required this.book,
    required this.catalogLanguage,
    required this.onOpen,
  });

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

  String _articleTitle(
    BuildContext context,
    TipitakaSegment segment,
    String language,
  ) {
    final selected = language == 'vi'
        ? segment.translationFor('vi')
        : segment.translationFor(language);
    final fallback = segment.canonicalPaliText.trim().isNotEmpty
        ? segment.canonicalPaliText
        : segment.firstTranslation?.value ?? '';
    final clean = _cleanText(selected.trim().isNotEmpty ? selected : fallback);
    if (clean.isEmpty) {
      return context.uiText('Bài kinh');
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
            context.uiText('${index.normalizedCode}\n${index.sourceTable}\n${widget.book.metadataJson ?? ''}'),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.catalogLanguage;
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
                title: Text(_articleTitle(context, segment, language)),
                onTap: () => widget.onOpen(
                  widget.book,
                  segment: segment,
                  articleTitle: _articleTitle(context, segment, language),
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
