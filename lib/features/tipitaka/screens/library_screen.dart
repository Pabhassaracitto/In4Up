import 'package:in4up/core/language/localized_material.dart';

import 'package:in4up/features/tipitaka/models/book.dart';
import 'package:in4up/features/tipitaka/models/collection.dart';
import 'package:in4up/features/tipitaka/screens/download_screen.dart';
import 'package:in4up/features/tipitaka/screens/reader_screen.dart';
import 'package:in4up/features/tipitaka/screens/search_screen.dart';
import 'package:in4up/features/tipitaka/services/db_service.dart';

class TipitakaLibraryScreen extends StatefulWidget {
  const TipitakaLibraryScreen({super.key});

  @override
  State<TipitakaLibraryScreen> createState() => _TipitakaLibraryScreenState();
}

class _TipitakaLibraryScreenState extends State<TipitakaLibraryScreen> {
  List<TipitakaCollection> collections = [];
  TipitakaCollection? selectedCollection;
  List<TipitakaBook> books = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() {
      loading = true;
      error = null;
    });
    try {
      final db = await TipitakaDb.openReady();
      final cols = await TipitakaDb.getCollections(db);
      if (!mounted) return;
      setState(() {
        collections = cols;
        loading = false;
        selectedCollection = cols.isEmpty ? null : cols.first;
      });
      if (cols.isNotEmpty) await _selectCollection(cols.first);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        collections = [];
        books = [];
        error = e.toString();
      });
    }
  }

  Future<void> _selectCollection(TipitakaCollection collection) async {
    if (!mounted) return;
    setState(() {
      selectedCollection = collection;
      books = [];
    });
    try {
      final db = await TipitakaDb.openReady();
      final loadedBooks = await TipitakaDb.getBooksByCollection(db, collection.id);
      if (mounted) setState(() => books = loadedBooks);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> _openDataManager() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TipitakaDownloadScreen()),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final isVietnamese = Localizations.localeOf(context).languageCode == 'vi';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tipiṭaka Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: context.uiText('Tìm kiếm'),
            onPressed: error == null
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TipitakaSearchScreen(),
                      ),
                    )
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.storage),
            tooltip: context.uiText('Quản lý dữ liệu'),
            onPressed: _openDataManager,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? _MissingDatabaseView(
                  onManage: _openDataManager,
                  onRetry: _load,
                )
              : Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: ListView.builder(
                        itemCount: collections.length,
                        itemBuilder: (context, index) {
                          final collection = collections[index];
                          return ListTile(
                            selected: selectedCollection?.id == collection.id,
                            title: Text(
                              collection.nameEn.isNotEmpty
                                  ? collection.nameEn
                                  : collection.namePali,
                            ),
                            subtitle: isVietnamese
                                ? (collection.nameVi.isEmpty
                                    ? null
                                    : Text(collection.nameVi))
                                : (collection.namePali.isEmpty
                                    ? null
                                    : Text(collection.namePali)),
                            onTap: () => _selectCollection(collection),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: books.isEmpty
                          ? const Center(child: Text('Chọn Piṭaka để xem sách'))
                          : ListView.builder(
                              itemCount: books.length,
                              itemBuilder: (context, index) {
                                final book = books[index];
                                return ListTile(
                                  title: Text(
                                    '${book.code} — ${isVietnamese && book.nameVi.isNotEmpty ? book.nameVi : (book.nameEn.isNotEmpty ? book.nameEn : book.namePali)}',
                                  ),
                                  subtitle: Text(book.namePali),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TipitakaReaderScreen(
                                        bookId: book.id,
                                        bookCode: book.code,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}

class _MissingDatabaseView extends StatelessWidget {
  final VoidCallback onManage;
  final VoidCallback onRetry;

  const _MissingDatabaseView({
    required this.onManage,
    required this.onRetry,
  });

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
                'Tipiṭaka chưa có dữ liệu',
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
                label: const Text('Import hoặc tải dữ liệu'),
              ),
              TextButton(onPressed: onRetry, child: const Text('Thử lại')),
            ],
          ),
        ),
      ),
    );
  }
}
