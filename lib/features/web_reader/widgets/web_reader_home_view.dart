import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/web_collection.dart';
import '../web_reader_controller.dart';

class WebReaderHomeView extends StatefulWidget {
  final WebReaderController controller;
  final ValueChanged<String> onNavigate;

  const WebReaderHomeView({
    super.key,
    required this.controller,
    required this.onNavigate,
  });

  @override
  State<WebReaderHomeView> createState() => _WebReaderHomeViewState();
}

class _WebReaderHomeViewState extends State<WebReaderHomeView> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D1117),
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final pinnedCollections =
              _filterCollections(widget.controller.pinnedCollections);
          final presetCollections =
              _filterCollections(widget.controller.presetCollections);
          final userCollections =
              _filterCollections(widget.controller.userCollections);
          final resumeEntries =
              _filterHistory(widget.controller.resumeEntries).take(6).toList();
          final history = _filterHistory(widget.controller.history).take(12).toList();
          final bookmarks =
              _filterHistory(widget.controller.bookmarks).take(8).toList();
          final hasQuery = _normalizedQuery.isNotEmpty;
          final hasAnyResults = resumeEntries.isNotEmpty ||
              pinnedCollections.isNotEmpty ||
              presetCollections.isNotEmpty ||
              userCollections.isNotEmpty ||
              history.isNotEmpty ||
              bookmarks.isNotEmpty;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroSection(context),
                const SizedBox(height: 18),
                _buildSearchBar(),
                const SizedBox(height: 12),
                _buildSearchMeta(
                  pinnedCount: pinnedCollections.length,
                  presetCount: presetCollections.length,
                  userCount: userCollections.length,
                  bookmarkCount: bookmarks.length,
                  historyCount: history.length,
                  resumeCount: resumeEntries.length,
                  hasQuery: hasQuery,
                ),
                if (hasQuery && !hasAnyResults) ...[
                  const SizedBox(height: 18),
                  _buildEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Không thấy kết quả phù hợp',
                    description:
                        'Thử từ khoá ngắn hơn, tên miền, hoặc tên bộ sưu tập / link.',
                  ),
                ] else ...[
                  const SizedBox(height: 24),
                  _SectionHeader(
                    icon: Icons.play_circle_outline,
                    title: hasQuery
                        ? 'Tiếp tục đọc · ${resumeEntries.length}'
                        : 'Tiếp tục đọc',
                    subtitle:
                        'Nhớ trang mở gần nhất và những bài bạn đang đọc dở theo tiến độ.',
                  ),
                  const SizedBox(height: 14),
                  if (resumeEntries.isEmpty)
                    _buildCompactEmpty(
                      hasQuery
                          ? 'Không có trang tiếp tục đọc nào khớp với từ khoá này.'
                          : 'Khi bạn cuộn đọc trong Web Reader, app sẽ nhớ tiến độ để quay lại đúng chỗ gần nhất.',
                    )
                  else
                    _buildResumeGrid(resumeEntries),
                  if (pinnedCollections.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    _SectionHeader(
                      icon: Icons.push_pin_outlined,
                      title: 'Đã ghim',
                      subtitle:
                          'Các bộ sưu tập quan trọng được kéo lên đầu để mở nhanh.',
                    ),
                    const SizedBox(height: 14),
                    _buildCollectionGrid(pinnedCollections, allowManage: true),
                  ],
                  const SizedBox(height: 28),
                  _SectionHeader(
                    icon: Icons.dashboard_customize_outlined,
                    title: hasQuery
                        ? 'Bộ sưu tập có sẵn · ${presetCollections.length}'
                        : 'Bộ sưu tập có sẵn',
                    subtitle:
                        'Preset của app, luôn giữ lại khi bạn thêm nhóm riêng.',
                  ),
                  const SizedBox(height: 14),
                  if (presetCollections.isEmpty && hasQuery)
                    _buildCompactEmpty('Không có preset nào khớp với từ khoá này.')
                  else
                    _buildCollectionGrid(presetCollections, allowManage: false),
                  const SizedBox(height: 28),
                  _SectionHeader(
                    icon: Icons.folder_copy_outlined,
                    title: hasQuery
                        ? 'Nhóm của tôi · ${userCollections.length}'
                        : 'Nhóm của tôi',
                    subtitle: 'Tự tạo nhóm link để gom nguồn học cá nhân.',
                    action: TextButton.icon(
                      onPressed: () => _showCollectionEditor(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Tạo nhóm'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (widget.controller.userCollections.isEmpty)
                    _buildEmptyState(
                      icon: Icons.folder_open,
                      title: 'Chưa có nhóm riêng',
                      description:
                          'Hãy tạo nhóm đầu tiên như “IELTS Reading”, “Pháp thoại buổi sáng”, hoặc “Nguồn nghiên cứu”.',
                      action: FilledButton.icon(
                        onPressed: () => _showCollectionEditor(),
                        icon: const Icon(Icons.add),
                        label: const Text('Tạo nhóm đầu tiên'),
                      ),
                    )
                  else if (userCollections.isEmpty && hasQuery)
                    _buildCompactEmpty('Không có nhóm riêng nào khớp với từ khoá này.')
                  else
                    _buildCollectionGrid(userCollections, allowManage: true),
                  const SizedBox(height: 28),
                  _SectionHeader(
                    icon: Icons.bookmark_rounded,
                    title: hasQuery
                        ? 'Đã lưu nhanh · ${bookmarks.length}'
                        : 'Đã lưu nhanh',
                    subtitle:
                        'Bookmark từ khi bạn đang đọc trong Web Reader.',
                  ),
                  const SizedBox(height: 14),
                  _buildHistoryBlock(
                    items: bookmarks,
                    emptyIcon: Icons.bookmark_border,
                    emptyTitle: hasQuery
                        ? 'Không có bookmark khớp tìm kiếm'
                        : 'Chưa có bookmark',
                    emptyDescription: hasQuery
                        ? 'Thử tên trang, tên miền, hoặc xoá bộ lọc tìm kiếm.'
                        : 'Khi đang mở một trang, bấm biểu tượng bookmark trên toolbar để lưu lại.',
                  ),
                  const SizedBox(height: 28),
                  _SectionHeader(
                    icon: Icons.history_rounded,
                    title: hasQuery
                        ? 'Lịch sử duyệt gần đây · ${history.length}'
                        : 'Lịch sử duyệt gần đây',
                    subtitle: 'Giữ mạch học cũ để quay lại đúng bài đang đọc.',
                    action: history.isEmpty || hasQuery
                        ? null
                        : TextButton.icon(
                            onPressed: _confirmClearHistory,
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Xoá lịch sử'),
                          ),
                  ),
                  const SizedBox(height: 14),
                  _buildHistoryBlock(
                    items: history,
                    emptyIcon: Icons.history_toggle_off,
                    emptyTitle: hasQuery
                        ? 'Không có lịch sử nào khớp tìm kiếm'
                        : 'Chưa có lịch sử đọc',
                    emptyDescription: hasQuery
                        ? 'Thử tên miền, tiêu đề trang, hoặc xoá từ khoá tìm kiếm.'
                        : 'Sau khi bạn mở một trang web, lịch sử sẽ hiện ở đây để quay lại nhanh.',
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  String get _normalizedQuery => _searchQuery.trim().toLowerCase();

  List<WebCollection> _filterCollections(List<WebCollection> collections) {
    if (_normalizedQuery.isEmpty) return collections;
    return collections.where(_matchesCollection).toList();
  }

  List<WebHistoryEntry> _filterHistory(List<WebHistoryEntry> items) {
    if (_normalizedQuery.isEmpty) return items;
    return items.where(_matchesHistory).toList();
  }

  bool _matchesCollection(WebCollection collection) {
    final q = _normalizedQuery;
    final haystacks = <String>[
      collection.title,
      collection.description,
      collection.emoji,
      ...collection.links.map((e) => e.title),
      ...collection.links.map((e) => e.note),
      ...collection.links.map((e) => e.url),
      ...collection.links.map((e) => e.domain),
    ].map((e) => e.toLowerCase());
    return haystacks.any((text) => text.contains(q));
  }

  bool _matchesHistory(WebHistoryEntry entry) {
    final q = _normalizedQuery;
    return entry.title.toLowerCase().contains(q) ||
        entry.url.toLowerCase().contains(q) ||
        entry.preview.toLowerCase().contains(q) ||
        _domain(entry.url).toLowerCase().contains(q);
  }

  Widget _buildHeroSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF121A2B), Color(0xFF18253D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'WEB READER · PHASE 3',
              style: TextStyle(
                color: Color(0xFF64B5F6),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Đọc tiếp đúng bài, đúng chỗ, đúng tiến độ',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Phase 3 đi sâu vào mạch học thật: nhớ bài vừa mở, theo dõi tiến độ cuộn đọc, và tạo lối quay lại nhanh cho những trang bạn đang đọc dở.',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 13,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () => _showCollectionEditor(),
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const Text('Tạo nhóm của tôi'),
              ),
              OutlinedButton.icon(
                onPressed: () => _showLinkEditorForQuickCollection(),
                icon: const Icon(Icons.add_link_outlined),
                label: const Text('Thêm link vào nhóm'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchCtrl,
      onChanged: (value) => setState(() => _searchQuery = value),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Tìm bộ sưu tập, link, bookmark, lịch sử, tên miền...',
        hintStyle: TextStyle(color: Colors.grey[500]),
        prefixIcon: const Icon(Icons.search, color: Colors.white70),
        suffixIcon: _searchQuery.trim().isEmpty
            ? null
            : IconButton(
                tooltip: 'Xoá tìm kiếm',
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() => _searchQuery = '');
                },
                icon: const Icon(Icons.close, color: Colors.white70),
              ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF64B5F6)),
        ),
      ),
    );
  }

  Widget _buildSearchMeta({
    required int pinnedCount,
    required int presetCount,
    required int userCount,
    required int bookmarkCount,
    required int historyCount,
    required int resumeCount,
    required bool hasQuery,
  }) {
    final queryLabel = _searchQuery.trim().length > 24
        ? '${_searchQuery.trim().substring(0, 24)}…'
        : _searchQuery.trim();
    final chips = <Widget>[
      _InfoChip(icon: Icons.play_circle_outline, label: '$resumeCount tiếp tục'),
      _InfoChip(icon: Icons.push_pin_outlined, label: '$pinnedCount ghim'),
      _InfoChip(
          icon: Icons.dashboard_customize_outlined,
          label: '$presetCount preset'),
      _InfoChip(icon: Icons.folder_copy_outlined, label: '$userCount nhóm riêng'),
      _InfoChip(icon: Icons.bookmark_outline, label: '$bookmarkCount bookmark'),
      _InfoChip(icon: Icons.history_rounded, label: '$historyCount lịch sử'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (hasQuery)
          _InfoChip(
            icon: Icons.tune,
            label: 'Đang lọc: “$queryLabel”',
          ),
        ...chips,
      ],
    );
  }

  Widget _buildResumeGrid(List<WebHistoryEntry> entries) {
    final lastOpenedUrl = widget.controller.lastOpenedEntry?.url;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int columns = 1;
        if (width >= 1100) {
          columns = 3;
        } else if (width >= 760) {
          columns = 2;
        }
        final spacing = 14.0;
        final itemWidth = columns == 1
            ? width
            : (width - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: entries
              .map(
                (entry) => SizedBox(
                  width: itemWidth,
                  child: _ResumeCard(
                    entry: entry,
                    isLastOpened: entry.url == lastOpenedUrl,
                    onTap: () => widget.onNavigate(entry.url),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildCollectionGrid(
    List<WebCollection> collections, {
    required bool allowManage,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int columns = 1;
        if (width >= 1100) {
          columns = 3;
        } else if (width >= 720) {
          columns = 2;
        }
        final spacing = 14.0;
        final itemWidth = columns == 1
            ? width
            : (width - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: collections
              .map(
                (collection) {
                  final canManage = allowManage && !collection.isPreset;
                  return SizedBox(
                    width: itemWidth,
                    child: _CollectionCard(
                      collection: collection,
                      allowManage: canManage,
                      isPinned:
                          widget.controller.isCollectionPinned(collection.id),
                      onTogglePin: () => widget.controller
                          .toggleCollectionPin(collection.id),
                      onOpen: () => _showCollectionSheet(collection),
                      onNavigate: widget.onNavigate,
                      onEdit: canManage
                          ? () => _showCollectionEditor(existing: collection)
                          : null,
                      onDelete: canManage
                          ? () => _confirmDeleteCollection(collection)
                          : null,
                      onAddLink: canManage
                          ? () => _showLinkEditor(collectionId: collection.id)
                          : null,
                    ),
                  );
                },
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildHistoryBlock({
    required List<WebHistoryEntry> items,
    required IconData emptyIcon,
    required String emptyTitle,
    required String emptyDescription,
  }) {
    if (items.isEmpty) {
      return _buildEmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        description: emptyDescription,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _HistoryTile(
              entry: items[i],
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onNavigate(items[i].url);
              },
            ),
            if (i != items.length - 1)
              Divider(
                height: 1,
                color: Colors.white.withValues(alpha: 0.05),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String description,
    Widget? action,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.grey[700], size: 34),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 13,
              height: 1.5,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 14),
            action,
          ],
        ],
      ),
    );
  }

  Widget _buildCompactEmpty(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Text(
        message,
        style: TextStyle(color: Colors.grey[400], height: 1.45),
      ),
    );
  }

  Future<void> _showCollectionEditor({WebCollection? existing}) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final emojiCtrl = TextEditingController(text: existing?.emoji ?? '📁');

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151B26),
          title: Text(existing == null ? 'Tạo nhóm mới' : 'Sửa nhóm'),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(
                  controller: titleCtrl,
                  label: 'Tên nhóm',
                  hint: 'Ví dụ: IELTS Reading',
                ),
                const SizedBox(height: 12),
                _dialogField(
                  controller: descCtrl,
                  label: 'Mô tả',
                  hint: 'Mục đích của nhóm này',
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                _dialogField(
                  controller: emojiCtrl,
                  label: 'Emoji',
                  hint: '📁 hoặc 🪷 hoặc 🇬🇧',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tên nhóm không được để trống')),
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: Text(existing == null ? 'Tạo' : 'Lưu'),
            ),
          ],
        );
      },
    );

    if (shouldSave == true) {
      await widget.controller.createOrUpdateUserCollection(
        id: existing?.id,
        title: titleCtrl.text,
        description: descCtrl.text,
        emoji: emojiCtrl.text,
        links: existing?.links ?? const [],
      );
    }
  }

  Future<void> _showLinkEditorForQuickCollection() async {
    final collections = widget.controller.userCollections;
    if (collections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hãy tạo ít nhất 1 nhóm trước đã')),
      );
      return;
    }

    String selectedId = collections.first.id;
    final titleCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF151B26),
              title: const Text('Thêm link vào nhóm'),
              titleTextStyle: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedId,
                      dropdownColor: const Color(0xFF151B26),
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Nhóm đích'),
                      items: collections
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text('${c.emoji} ${c.title}'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setLocalState(() => selectedId = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _dialogField(
                      controller: titleCtrl,
                      label: 'Tên link',
                      hint: 'Ví dụ: Bài đọc 01',
                    ),
                    const SizedBox(height: 12),
                    _dialogField(
                      controller: urlCtrl,
                      label: 'URL',
                      hint: 'https://...',
                    ),
                    const SizedBox(height: 12),
                    _dialogField(
                      controller: noteCtrl,
                      label: 'Ghi chú',
                      hint: 'Nếu cần',
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Huỷ'),
                ),
                FilledButton(
                  onPressed: () {
                    if (urlCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Bạn cần nhập URL')),
                      );
                      return;
                    }
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('Thêm link'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldSave == true) {
      final added = await widget.controller.addLinkToUserCollection(
        collectionId: selectedId,
        title: titleCtrl.text,
        url: urlCtrl.text,
        note: noteCtrl.text,
      );
      if (mounted && !added) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link này đã có trong nhóm rồi')),
        );
      }
    }
  }

  Future<void> _showLinkEditor({required String collectionId}) async {
    final titleCtrl = TextEditingController();
    final urlCtrl = TextEditingController(
      text: widget.controller.currentUrl,
    );
    final noteCtrl = TextEditingController();

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151B26),
          title: const Text('Thêm link vào nhóm'),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(
                  controller: titleCtrl,
                  label: 'Tên link',
                  hint: 'Ví dụ: Lesson 12',
                ),
                const SizedBox(height: 12),
                _dialogField(
                  controller: urlCtrl,
                  label: 'URL',
                  hint: 'https://...',
                ),
                const SizedBox(height: 12),
                _dialogField(
                  controller: noteCtrl,
                  label: 'Ghi chú',
                  hint: 'Nếu cần',
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () {
                if (urlCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bạn cần nhập URL')),
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Thêm'),
            ),
          ],
        );
      },
    );

    if (shouldSave == true) {
      final added = await widget.controller.addLinkToUserCollection(
        collectionId: collectionId,
        title: titleCtrl.text,
        url: urlCtrl.text,
        note: noteCtrl.text,
      );
      if (mounted && !added) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link này đã có trong nhóm rồi')),
        );
      }
    }
  }

  Future<void> _showCollectionSheet(WebCollection collection) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF111827),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final currentCollection = collection.isPreset
                ? collection
                : widget.controller.userCollections.firstWhere(
                    (c) => c.id == collection.id,
                    orElse: () => collection,
                  );
            final isPinned =
                widget.controller.isCollectionPinned(currentCollection.id);
            final canSaveCurrentPage = !currentCollection.isPreset &&
                widget.controller.currentUrl.isNotEmpty &&
                widget.controller.state == WebReaderState.ready;

            return FractionallySizedBox(
              heightFactor: 0.85,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          currentCollection.emoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentCollection.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currentCollection.description,
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: isPinned ? 'Bỏ ghim' : 'Ghim bộ sưu tập',
                          onPressed: () async {
                            await widget.controller
                                .toggleCollectionPin(currentCollection.id);
                            if (mounted) setModalState(() {});
                          },
                          icon: Icon(
                            isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                            color: isPinned ? Colors.amber : Colors.white70,
                          ),
                        ),
                        if (!currentCollection.isPreset)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Thêm link',
                                onPressed: () async {
                                  await _showLinkEditor(
                                      collectionId: currentCollection.id);
                                  if (mounted) setModalState(() {});
                                },
                                icon: const Icon(Icons.add_link,
                                    color: Colors.white),
                              ),
                              IconButton(
                                tooltip: 'Sửa nhóm',
                                onPressed: () async {
                                  await _showCollectionEditor(
                                      existing: currentCollection);
                                  if (mounted) setModalState(() {});
                                },
                                icon: const Icon(Icons.edit_outlined,
                                    color: Colors.white),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.07)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.link_rounded,
                              size: 18, color: Colors.blue[200]),
                          const SizedBox(width: 8),
                          Text(
                            '${currentCollection.linkCount} liên kết',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            currentCollection.isPreset
                                ? 'Preset của app'
                                : 'Link do bạn thêm sẽ được lưu lại',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canSaveCurrentPage) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () async {
                            final added = await widget.controller
                                .addCurrentPageToUserCollection(
                                    currentCollection.id);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  added
                                      ? 'Đã lưu trang hiện tại vào nhóm "${currentCollection.title}"'
                                      : 'Trang này đã có sẵn trong nhóm "${currentCollection.title}"',
                                ),
                              ),
                            );
                            setModalState(() {});
                          },
                          icon: const Icon(Icons.playlist_add),
                          label: const Text('Lưu trang hiện tại vào nhóm này'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Expanded(
                      child: currentCollection.links.isEmpty
                          ? _buildEmptyState(
                              icon: Icons.link_off,
                              title: 'Nhóm này chưa có liên kết',
                              description:
                                  'Thêm URL đầu tiên để dùng nhóm này như lối vào nhanh cho Web Reader.',
                              action: currentCollection.isPreset
                                  ? null
                                  : FilledButton.icon(
                                      onPressed: () async {
                                        await _showLinkEditor(
                                            collectionId: currentCollection.id);
                                        if (mounted) setModalState(() {});
                                      },
                                      icon: const Icon(Icons.add_link),
                                      label: const Text('Thêm liên kết'),
                                    ),
                            )
                          : ListView.separated(
                              itemCount: currentCollection.links.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                              itemBuilder: (context, index) {
                                final link = currentCollection.links[index];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 4),
                                  leading: CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Colors.white12,
                                    child: Text(
                                      currentCollection.emoji,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                  title: Text(
                                    link.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        link.domain,
                                        style: TextStyle(
                                          color: Colors.blue[200],
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (link.note.trim().isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          link.note,
                                          style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 12,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  trailing: currentCollection.isPreset
                                      ? const Icon(Icons.open_in_new,
                                          color: Colors.white54, size: 18)
                                      : IconButton(
                                          tooltip: 'Xoá link',
                                          onPressed: () async {
                                            await widget.controller
                                                .removeLinkFromUserCollection(
                                              collectionId: currentCollection.id,
                                              linkId: link.id,
                                            );
                                            if (mounted) setModalState(() {});
                                          },
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.white70,
                                          ),
                                        ),
                                  onTap: () {
                                    Navigator.pop(sheetContext);
                                    widget.onNavigate(link.url);
                                  },
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
  }

  Future<void> _confirmDeleteCollection(WebCollection collection) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151B26),
          title: const Text('Xoá nhóm này?'),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          content: Text(
            'Nhóm "${collection.title}" sẽ bị xoá, nhưng các preset mặc định và lịch sử duyệt sẽ không bị ảnh hưởng.',
            style: TextStyle(color: Colors.grey[300], height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Xoá'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      await widget.controller.deleteUserCollection(collection.id);
    }
  }

  Future<void> _confirmClearHistory() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151B26),
          title: const Text('Xoá lịch sử duyệt?'),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          content: Text(
            'Chỉ xoá lịch sử duyệt Web Reader. Bookmark và các bộ sưu tập của bạn vẫn được giữ nguyên.',
            style: TextStyle(color: Colors.grey[300], height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Xoá lịch sử'),
            ),
          ],
        );
      },
    );

    if (shouldClear == true) {
      await widget.controller.clearHistory();
    }
  }

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(label, hint: hint),
    );
  }

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: Colors.grey[300]),
      hintStyle: TextStyle(color: Colors.grey[600]),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.04),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF64B5F6)),
      ),
    );
  }

  String _domain(String url) {
    try {
      return Uri.parse(url).host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: Colors.blue[200]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

class _ResumeCard extends StatelessWidget {
  final WebHistoryEntry entry;
  final bool isLastOpened;
  final VoidCallback onTap;

  const _ResumeCard({
    required this.entry,
    required this.isLastOpened,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progress = entry.progress.clamp(0.0, 1.0).toDouble();
    final showProgress = progress > 0.01;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: isLastOpened
                      ? Icons.history_toggle_off
                      : Icons.menu_book,
                  label: isLastOpened ? 'Lần mở gần nhất' : 'Đang đọc dở',
                ),
                _InfoChip(
                  icon: Icons.language,
                  label: _HistoryTile._domain(entry.url),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              entry.title.isNotEmpty ? entry.title : entry.url,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
            if (entry.preview.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                entry.preview.trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (showProgress) ...[
              LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(999),
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation(
                  progress >= 0.98 ? Colors.greenAccent : const Color(0xFF64B5F6),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Tiến độ ~ ${entry.progressPercent}%',
                    style: TextStyle(
                      color: Colors.blue[200],
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _HistoryTile._formatVisitedAt(entry.effectiveReadAt),
                    style: TextStyle(color: Colors.grey[500], fontSize: 11.5),
                  ),
                ],
              ),
            ] else ...[
              Text(
                'Mới mở · ${_HistoryTile._formatVisitedAt(entry.effectiveReadAt)}',
                style: TextStyle(color: Colors.grey[500], fontSize: 11.5),
              ),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Tiếp tục đọc'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  final WebCollection collection;
  final bool allowManage;
  final bool isPinned;
  final VoidCallback onTogglePin;
  final VoidCallback onOpen;
  final ValueChanged<String> onNavigate;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAddLink;

  const _CollectionCard({
    required this.collection,
    required this.allowManage,
    required this.isPinned,
    required this.onTogglePin,
    required this.onOpen,
    required this.onNavigate,
    this.onEdit,
    this.onDelete,
    this.onAddLink,
  });

  @override
  Widget build(BuildContext context) {
    final previewLinks = collection.links.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(collection.emoji, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      collection.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      collection.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: isPinned ? 'Bỏ ghim' : 'Ghim bộ sưu tập',
                visualDensity: VisualDensity.compact,
                onPressed: onTogglePin,
                icon: Icon(
                  isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  color: isPinned ? Colors.amber : Colors.white70,
                ),
              ),
              if (allowManage)
                PopupMenuButton<String>(
                  color: const Color(0xFF151B26),
                  icon: const Icon(Icons.more_vert, color: Colors.white70),
                  onSelected: (value) {
                    switch (value) {
                      case 'add':
                        onAddLink?.call();
                        break;
                      case 'edit':
                        onEdit?.call();
                        break;
                      case 'delete':
                        onDelete?.call();
                        break;
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'add', child: Text('Thêm link')),
                    PopupMenuItem(value: 'edit', child: Text('Sửa nhóm')),
                    PopupMenuItem(value: 'delete', child: Text('Xoá nhóm')),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.link,
                label: '${collection.linkCount} link',
              ),
              _InfoChip(
                icon: collection.isPreset ? Icons.lock_outline : Icons.edit,
                label: collection.isPreset ? 'Preset' : 'Tuỳ biến',
              ),
              if (isPinned)
                const _InfoChip(
                  icon: Icons.push_pin,
                  label: 'Đã ghim',
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (previewLinks.isEmpty)
            Text(
              'Chưa có link nào trong nhóm này.',
              style: TextStyle(color: Colors.grey[500], fontSize: 12.5),
            )
          else
            ...previewLinks.map(
              (link) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => onNavigate(link.url),
                  borderRadius: BorderRadius.circular(12),
                  child: Ink(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.open_in_new,
                            size: 16, color: Colors.white70),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                link.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                link.domain,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.blue[200],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.view_list_rounded, size: 18),
              label: Text(
                collection.linkCount > previewLinks.length
                    ? 'Xem tất cả ${collection.linkCount} link'
                    : 'Mở chi tiết nhóm',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final WebHistoryEntry entry;
  final VoidCallback onTap;

  const _HistoryTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final progress = entry.progress.clamp(0.0, 1.0).toDouble();
    final showProgress = progress > 0.01;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.language, color: Colors.white70, size: 18),
      ),
      title: Text(
        entry.title.isNotEmpty ? entry.title : entry.url,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _domain(entry.url),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.blue[200], fontSize: 12),
            ),
            if (entry.preview.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                entry.preview.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[400], fontSize: 11.8),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatVisitedAt(entry.effectiveReadAt),
                    style: TextStyle(color: Colors.grey[500], fontSize: 11.5),
                  ),
                ),
                if (showProgress)
                  Text(
                    '${entry.progressPercent}%',
                    style: TextStyle(
                      color: Colors.blue[200],
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            if (showProgress) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                borderRadius: BorderRadius.circular(999),
                backgroundColor: Colors.white10,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFF64B5F6)),
              ),
            ],
          ],
        ),
      ),
      trailing:
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white54),
      onTap: onTap,
    );
  }

  static String _domain(String url) {
    try {
      return Uri.parse(url).host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }

  static String _formatVisitedAt(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inHours < 1) return '${diff.inMinutes} phút trước';
    if (diff.inDays < 1) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    final day = time.day.toString().padLeft(2, '0');
    final month = time.month.toString().padLeft(2, '0');
    return '$day/$month/${time.year}';
  }
}
