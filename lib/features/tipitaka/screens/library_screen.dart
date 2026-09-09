import 'package:in4up/core/language/localized_material.dart';

import 'package:in4up/features/tipitaka/models/book.dart';
import 'package:in4up/features/tipitaka/models/collection.dart';
import 'package:in4up/features/tipitaka/screens/download_screen.dart';
import 'package:in4up/features/tipitaka/screens/reader_screen.dart';
import 'package:in4up/features/tipitaka/screens/search_screen.dart';
import 'package:in4up/features/tipitaka/services/db_service.dart';

/// Tipiṭaka catalogue and reading entry point.
///
/// The layout follows the useful parts of OpenTipitaka's workspace: a clear
/// tree/catalogue, a focused book list, and a reading view that keeps Pāli and
/// translations aligned by paragraph. It also adapts the catalogue to a
/// narrow phone screen instead of forcing two cramped columns.
class TipitakaLibraryScreen extends StatefulWidget {
  const TipitakaLibraryScreen({super.key});

  @override
  State<TipitakaLibraryScreen> createState() => _TipitakaLibraryScreenState();
}

class _TipitakaLibraryScreenState extends State<TipitakaLibraryScreen> {
  List<TipitakaCollection> _collections = const [];
  TipitakaCollection? _selectedCollection;
  List<TipitakaBook> _books = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final db = await TipitakaDb.openReady();
      final collections = await TipitakaDb.getCollections(db);
      if (!mounted) return;
      setState(() {
        _collections = collections;
        _selectedCollection = collections.isEmpty ? null : collections.first;
        _books = const [];
        _loading = false;
      });
      if (collections.isNotEmpty) await _selectCollection(collections.first);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _collections = const [];
        _books = const [];
        _error = error.toString();
      });
    }
  }

  Future<void> _selectCollection(TipitakaCollection collection) async {
    if (!mounted) return;
    setState(() {
      _selectedCollection = collection;
      _books = const [];
    });
    try {
      final db = await TipitakaDb.openReady();
      final books = await TipitakaDb.getBooksByCollection(db, collection.id);
      if (mounted) setState(() => _books = books);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _openDataManager() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TipitakaDownloadScreen()),
    );
    if (mounted) _load();
  }

  String _bookTitle(TipitakaBook book, bool isVietnamese) {
    if (isVietnamese && book.nameVi.trim().isNotEmpty) return book.nameVi;
    if (book.nameEn.trim().isNotEmpty) return book.nameEn;
    return book.namePali.isNotEmpty ? book.namePali : book.code;
  }

  @override
  Widget build(BuildContext context) {
    final isVietnamese = Localizations.localeOf(context).languageCode == 'vi';
    final isCompact = MediaQuery.sizeOf(context).width < 720;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.uiText('Thư viện Tipiṭaka')),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: context.uiText('Tìm kiếm'),
            onPressed: _error == null
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TipitakaSearchScreen(),
                      ),
                    )
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.storage_outlined),
            tooltip: context.uiText('Quản lý dữ liệu'),
            onPressed: _openDataManager,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _MissingDatabaseView(onManage: _openDataManager, onRetry: _load)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LibraryHeader(
                        collectionCount: _collections.length,
                        bookCount: _books.length,
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _buildCatalogue(
                          context,
                          isCompact: isCompact,
                          isVietnamese: isVietnamese,
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCatalogue(
    BuildContext context, {
    required bool isCompact,
    required bool isVietnamese,
  }) {
    final collectionBar = SizedBox(
      height: isCompact ? 54 : null,
      child: isCompact
          ? ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _collections.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, index) => _collectionChip(
                _collections[index],
                isVietnamese,
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
              itemCount: _collections.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _collectionTile(
                context,
                _collections[index],
                isVietnamese,
              ),
            ),
    );

    final bookPanel = _BookList(
      books: _books,
      isVietnamese: isVietnamese,
      titleFor: _bookTitle,
    );

    if (isCompact) {
      return Column(
        children: [
          collectionBar,
          const SizedBox(height: 4),
          Expanded(child: bookPanel),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 245,
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
              child: collectionBar,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: bookPanel),
      ],
    );
  }

  Widget _collectionChip(
    TipitakaCollection collection,
    bool isVietnamese,
  ) {
    final selected = _selectedCollection?.id == collection.id;
    return ChoiceChip(
      selected: selected,
      label: Text(_collectionTitle(collection, isVietnamese)),
      onSelected: (_) => _selectCollection(collection),
    );
  }

  Widget _collectionTile(
    BuildContext context,
    TipitakaCollection collection,
    bool isVietnamese,
  ) {
    final selected = _selectedCollection?.id == collection.id;
    return ListTile(
      dense: true,
      selected: selected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Icon(
        selected ? Icons.menu_book : Icons.menu_book_outlined,
        color: selected ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(_collectionTitle(collection, isVietnamese)),
      subtitle: collection.namePali.trim().isEmpty
          ? null
          : Text(collection.namePali),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _selectCollection(collection),
    );
  }

  String _collectionTitle(TipitakaCollection collection, bool isVietnamese) {
    if (isVietnamese && collection.nameVi.trim().isNotEmpty) {
      return collection.nameVi;
    }
    if (collection.nameEn.trim().isNotEmpty) return collection.nameEn;
    return collection.namePali;
  }
}

class _LibraryHeader extends StatelessWidget {
  final int collectionCount;
  final int bookCount;

  const _LibraryHeader({required this.collectionCount, required this.bookCount});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.auto_stories,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.uiText('Đọc Tipiṭaka'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    context.uiText(
                      'Chọn một tạng và sách để đọc Pāli cùng bản dịch theo từng đoạn.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$collectionCount ${context.uiText('tạng')}'),
                Text('$bookCount ${context.uiText('sách đang chọn')}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BookList extends StatelessWidget {
  final List<TipitakaBook> books;
  final bool isVietnamese;
  final String Function(TipitakaBook, bool) titleFor;

  const _BookList({
    required this.books,
    required this.isVietnamese,
    required this.titleFor,
  });

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return Center(
        child: Text(
          context.uiText('Chưa tìm thấy sách trong mục này.'),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: books.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final book = books[index];
        final title = titleFor(book, isVietnamese);
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
              child: Text('${index + 1}'),
            ),
            title: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${book.code}${book.namePali.isEmpty ? '' : ' · ${book.namePali}'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TipitakaReaderScreen(
                  bookId: book.id,
                  bookCode: book.code,
                  bookName: title,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MissingDatabaseView extends StatelessWidget {
  final VoidCallback onManage;
  final VoidCallback onRetry;

  const _MissingDatabaseView({required this.onManage, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.menu_book_outlined, size: 64),
              const SizedBox(height: 16),
              Text(
                context.uiText('Tipiṭaka chưa có dữ liệu'),
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                context.uiText('Không thể mở cơ sở dữ liệu Tipiṭaka.'),
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
      ),
    );
  }
}
