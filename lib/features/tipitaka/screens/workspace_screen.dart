import 'package:in4up/core/language/localized_material.dart';

import 'package:in4up/features/tipitaka/models/book.dart';
import 'package:in4up/features/tipitaka/models/collection.dart';
import 'package:in4up/features/tipitaka/models/segment.dart';
import 'package:in4up/features/tipitaka/screens/reader_screen.dart';
import 'package:in4up/features/tipitaka/services/db_service.dart';

class TipitakaWorkspaceTab {
  final TipitakaBook book;
  final String title;
  final int? initialSegmentId;

  const TipitakaWorkspaceTab({
    required this.book,
    required this.title,
    this.initialSegmentId,
  });

  String get id => '${book.id}:${initialSegmentId ?? 'all'}';
}

/// Obsidian-style reading workspace. Every tab remains mounted while hidden,
/// so loaded pages, scroll offsets, selections, and TTS cursors survive tab
/// changes. Split view simply reveals a second mounted tab.
typedef TipitakaWorkspaceReaderBuilder = Widget Function(
  BuildContext context,
  TipitakaWorkspaceTab tab,
);

class TipitakaWorkspaceScreen extends StatefulWidget {
  final TipitakaWorkspaceTab initialTab;
  final List<TipitakaWorkspaceTab> additionalTabs;
  final TipitakaWorkspaceReaderBuilder? readerBuilder;

  const TipitakaWorkspaceScreen({
    super.key,
    required this.initialTab,
    this.additionalTabs = const [],
    this.readerBuilder,
  });

  @override
  State<TipitakaWorkspaceScreen> createState() =>
      _TipitakaWorkspaceScreenState();
}

class _TipitakaWorkspaceScreenState extends State<TipitakaWorkspaceScreen> {
  late final List<TipitakaWorkspaceTab> _tabs = [
    widget.initialTab,
    for (final tab in widget.additionalTabs)
      if (tab.id != widget.initialTab.id) tab,
  ];
  int _primaryIndex = 0;
  int? _secondaryIndex;
  bool _split = false;

  void _openTab(TipitakaWorkspaceTab tab) {
    final existing = _tabs.indexWhere((item) => item.id == tab.id);
    setState(() {
      final previous = _primaryIndex;
      if (existing >= 0) {
        _primaryIndex = existing;
      } else {
        _tabs.add(tab);
        _primaryIndex = _tabs.length - 1;
      }
      if (_tabs.length > 1 && previous != _primaryIndex) {
        _secondaryIndex = previous;
      }
    });
  }

  void _selectPrimary(int index) {
    if (index == _primaryIndex) return;
    setState(() {
      if (_split && index == _secondaryIndex) {
        _secondaryIndex = _primaryIndex;
      }
      _primaryIndex = index;
    });
  }

  void _toggleSplit() {
    if (_tabs.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.uiText('Mở thêm một bài để dùng chế độ chia đôi.')),
        ),
      );
      return;
    }
    setState(() {
      _split = !_split;
      if (_split && (_secondaryIndex == null || _secondaryIndex == _primaryIndex)) {
        _secondaryIndex = _primaryIndex == 0 ? 1 : 0;
      }
    });
  }

  void _closeTab(int index) {
    if (_tabs.length == 1) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      final oldPrimary = _primaryIndex;
      final oldSecondary = _secondaryIndex;
      _tabs.removeAt(index);

      if (index < oldPrimary) {
        _primaryIndex = oldPrimary - 1;
      } else if (index == oldPrimary) {
        _primaryIndex = index.clamp(0, _tabs.length - 1).toInt();
      }

      if (oldSecondary != null) {
        if (index < oldSecondary) {
          _secondaryIndex = oldSecondary - 1;
        } else if (index == oldSecondary) {
          _secondaryIndex = null;
        }
      }
      if (_tabs.length < 2) {
        _split = false;
        _secondaryIndex = null;
      } else if (_split &&
          (_secondaryIndex == null || _secondaryIndex == _primaryIndex)) {
        _secondaryIndex = _primaryIndex == 0 ? 1 : 0;
      }
    });
  }

  Future<void> _showBookPicker() async {
    try {
      final language = Localizations.localeOf(context).languageCode;
      final db = await TipitakaDb.openReady();
      final collections = await TipitakaDb.getCollections(db);
      final groups = <TipitakaCollection, List<TipitakaBook>>{};
      for (final collection in collections) {
        groups[collection] = await TipitakaDb.getBooksByCollection(
          db,
          collection.id,
          languageCode: language,
        );
      }
      if (!mounted) return;
      final selected = await showModalBottomSheet<TipitakaBook>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: FractionallySizedBox(
            heightFactor: .82,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    context.uiText('Mở bài trong tab mới'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                for (final entry in groups.entries)
                  ExpansionTile(
                    title: Text(_collectionTitle(entry.key, language)),
                    children: [
                      for (final book in entry.value)
                        ListTile(
                          leading: const Icon(Icons.article_outlined),
                          title: Text(book.displayTitle(language)),
                          onTap: () => Navigator.pop(context, book),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
      if (selected != null) {
        await _showOutlinePicker(selected, language);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.uiText('Không thể mở danh mục: $error'))),
      );
    }
  }

  Future<void> _showOutlinePicker(
    TipitakaBook book,
    String language,
  ) async {
    final db = await TipitakaDb.openReady();
    final outline = await TipitakaDb.getBookOutline(db, book.id);
    if (!mounted) return;
    if (outline.isEmpty) {
      _openTab(
        TipitakaWorkspaceTab(
          book: book,
          title: book.displayTitle(language),
        ),
      );
      return;
    }

    final selectedId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .82,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            children: [
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: Text(context.uiText('Đọc toàn bộ nhóm/bộ')),
                subtitle: Text(book.displayTitle(language)),
                onTap: () => Navigator.pop(context, -1),
              ),
              const Divider(),
              for (var index = 0; index < outline.length; index++)
                ListTile(
                  leading: Text('${index + 1}'),
                  title: Text(_outlineTitle(outline[index], language, index)),
                  onTap: () => Navigator.pop(context, outline[index].id),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || selectedId == null) return;
    final selectedIndex = selectedId < 0
        ? -1
        : outline.indexWhere((item) => item.id == selectedId);
    final selected = selectedIndex < 0 ? null : outline[selectedIndex];
    _openTab(
      TipitakaWorkspaceTab(
        book: book,
        title: selected == null
            ? book.displayTitle(language)
            : _outlineTitle(selected, language, selectedIndex),
        initialSegmentId: selected?.id,
      ),
    );
  }

  String _outlineTitle(
    TipitakaSegment segment,
    String language,
    int index,
  ) {
    var text = segment.translationFor(language).trim();
    if (text.isEmpty) text = segment.paliText.trim();
    if (text.isEmpty) text = segment.firstTranslation?.value.trim() ?? '';
    text = text
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text.isEmpty ? '${index + 1}. ${context.uiText('Mục chưa có tiêu đề')}' : text;
  }

  String _collectionTitle(TipitakaCollection collection, String language) {
    if (language == 'vi' && collection.nameVi.trim().isNotEmpty) {
      return collection.nameVi;
    }
    if (collection.nameEn.trim().isNotEmpty) return collection.nameEn;
    return collection.namePali;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.uiText('Không gian đọc Tipiṭaka')),
        actions: [
          IconButton(
            onPressed: _showBookPicker,
            tooltip: context.uiText('Mở bài trong tab mới'),
            icon: const Icon(Icons.add),
          ),
          IconButton(
            key: const ValueKey('tipitaka-toggle-split'),
            onPressed: _toggleSplit,
            tooltip: context.uiText('Chia đôi màn hình'),
            icon: Icon(_split ? Icons.vertical_split : Icons.view_sidebar_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTabStrip(context),
          const Divider(height: 1),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => _buildPanes(constraints),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabStrip(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        itemCount: _tabs.length,
        itemBuilder: (context, index) {
          final selected = index == _primaryIndex;
          final secondary = _split && index == _secondaryIndex;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Material(
              color: selected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : secondary
                      ? Theme.of(context).colorScheme.secondaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                key: ValueKey('tipitaka-tab-${_tabs[index].id}'),
                borderRadius: BorderRadius.circular(8),
                onTap: () => _selectPrimary(index),
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Row(
                    children: [
                      if (secondary) const Icon(Icons.looks_two_outlined, size: 16),
                      if (secondary) const SizedBox(width: 5),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 190),
                        child: Text(
                          _tabs[index].title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: context.uiText('Đóng tab'),
                        onPressed: () => _closeTab(index),
                        icon: const Icon(Icons.close, size: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPanes(BoxConstraints constraints) {
    final secondary = _split ? _secondaryIndex : null;
    final half = constraints.maxWidth / 2;
    return Stack(
      children: [
        for (var index = 0; index < _tabs.length; index++)
          Positioned(
            left: index == _primaryIndex
                ? 0
                : index == secondary
                    ? half + .5
                    : 0,
            width: index == _primaryIndex
                ? (_split ? half - .5 : constraints.maxWidth)
                : index == secondary
                    ? half - .5
                    : constraints.maxWidth,
            top: 0,
            bottom: 0,
            child: Offstage(
              offstage: index != _primaryIndex && index != secondary,
              child: widget.readerBuilder?.call(context, _tabs[index]) ??
                  TipitakaReaderScreen(
                    key: ValueKey('tipitaka-workspace-${_tabs[index].id}'),
                    bookId: _tabs[index].book.id,
                    bookCode: _tabs[index].book.code,
                    bookName: _tabs[index].title,
                    book: _tabs[index].book,
                    initialSegmentId: _tabs[index].initialSegmentId,
                    embedded: true,
                  ),
            ),
          ),
        if (_split)
          Positioned(
            left: half - .5,
            width: 1,
            top: 0,
            bottom: 0,
            child: ColoredBox(color: Theme.of(context).dividerColor),
          ),
      ],
    );
  }
}
