import 'package:in4up/core/language/localized_material.dart';

import 'package:in4up/features/tipitaka/models/book.dart';
import 'package:in4up/features/tipitaka/models/collection.dart';
import 'package:in4up/features/tipitaka/models/segment.dart';
import 'package:in4up/features/tipitaka/screens/download_screen.dart';
import 'package:in4up/features/tipitaka/screens/search_screen.dart';
import 'package:in4up/features/tipitaka/screens/workspace_screen.dart';
import 'package:in4up/features/tipitaka/services/db_service.dart';

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
      final books = <int, List<TipitakaBook>>{};
      for (final collection in collections) {
        books[collection.id] = await TipitakaDb.getBooksByCollection(
          db,
          collection.id,
          languageCode: _language,
        );
      }
      final info = await TipitakaDb.info(db);
      if (!mounted) return;
      setState(() {
        _collections = collections;
        _booksByCollection = books;
        _languages = info.availableLanguages;
        _loading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      ),
      body: _loading
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
                                onOpen: _openReader,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
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

class _CollectionTreeNode extends StatelessWidget {
  final TipitakaCollection collection;
  final List<TipitakaBook> books;
  final void Function(
    TipitakaBook book, {
    TipitakaSegment? segment,
    String? articleTitle,
  }) onOpen;

  const _CollectionTreeNode({
    required this.collection,
    required this.books,
    required this.onOpen,
  });

  String _title(String language) {
    final names = '${collection.namePali} ${collection.nameEn} ${collection.nameVi}'
        .toLowerCase();
    if (names.contains('vin') || names.contains('luật')) {
      return language == 'vi' ? 'Tạng Luật' : 'Vinaya Piṭaka';
    }
    if (names.contains('abh') || names.contains('diệu')) {
      return language == 'vi' ? 'Tạng Luận' : 'Abhidhamma Piṭaka';
    }
    return language == 'vi' ? 'Tạng Kinh' : 'Sutta Piṭaka';
  }

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ExpansionTile(
        leading: const Icon(Icons.folder_open_outlined),
        title: Text(_title(language)),
        subtitle: Text('${books.length} ${context.uiText('nhóm/bộ')}'),
        children: [
          for (final book in books)
            _BookTreeNode(book: book, onOpen: onOpen),
        ],
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
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 4),
      child: ExpansionTile(
        onExpansionChanged: _loadOutline,
        leading: const Icon(Icons.library_books_outlined),
        title: Text(widget.book.displayTitle(language)),
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
