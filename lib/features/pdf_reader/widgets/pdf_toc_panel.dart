// Panel mục lục (document outline). Đọc từ `PdfDocument.loadOutline()` — file
// không có outline thì hiện thông báo thật, không bịa danh sách rỗng vô nghĩa.
import 'package:in4up/core/language/localized_material.dart';
import 'package:pdfrx/pdfrx.dart' hide PdfAnnotation;

import '../services/pdf_outline_index.dart';
import 'pdf_thumbnail_grid.dart';

class PdfTocPanel extends StatefulWidget {
  const PdfTocPanel({
    super.key,
    required this.entries,
    required this.activeIndex,
    required this.onSelect,
    this.isLoading = false,
    this.hasOutline = true,
  });

  final List<PdfOutlineEntry> entries;

  /// Mục đang đọc (`findActiveOutlineIndex`), -1 nếu chưa có.
  final int activeIndex;
  final ValueChanged<PdfOutlineEntry> onSelect;
  final bool isLoading;

  /// `false` = tài liệu không có outline (khác với "đang tải").
  final bool hasOutline;

  @override
  State<PdfTocPanel> createState() => _PdfTocPanelState();
}

class _PdfTocPanelState extends State<PdfTocPanel> {
  static const double _itemExtent = 44;

  final ScrollController _scroll = ScrollController();
  int _lastAutoScrolledActive = -2;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PdfTocPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Chỉ canh lại khi mục lục vừa kịp tải về (panel mở lúc `loadOutline()` còn
    // chạy). KHÔNG cuộn theo mỗi lần lật trang: người dùng đang tự lướt mục lục
    // mà bị kéo về chương hiện tại là rất khó chịu.
    if (oldWidget.entries.isEmpty && widget.entries.isNotEmpty) {
      _lastAutoScrolledActive = -2;
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealActive());
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealActive());
  }

  void _revealActive() {
    final active = widget.activeIndex;
    if (!_scroll.hasClients || active < 0) return;
    if (_lastAutoScrolledActive == active) return;
    _lastAutoScrolledActive = active;
    final target = (active * _itemExtent - 88)
        .clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!widget.hasOutline) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.uiText('Tài liệu này không có mục lục'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ),
      );
    }
    if (widget.entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      controller: _scroll,
      itemExtent: _itemExtent,
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: widget.entries.length,
      itemBuilder: (context, index) {
        final entry = widget.entries[index];
        final isActive = index == widget.activeIndex;
        return InkWell(
          onTap: entry.isJumpable
              ? () => widget.onSelect(entry)
              : null,
          child: Container(
            color: isActive
                ? const Color(0xFF2196F3).withValues(alpha: 0.16)
                : null,
            padding: EdgeInsets.only(
              left: 12 + entry.level * 14.0,
              right: 12,
            ),
            child: Row(
              children: [
                if (!entry.isJumpable)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.folder_outlined,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                if (entry.hasChildren && entry.isJumpable)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.article_outlined,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                Expanded(
                  child: Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.white70,
                      fontSize: entry.level == 0 ? 13.5 : 12.5,
                      fontWeight: entry.level == 0
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
                if (entry.pageNumber != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      '${entry.pageNumber}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Sheet điều hướng: Mục lục + Ảnh thu nhỏ trang. Trả về `true` nếu người dùng
/// đã chọn một mục (để caller ẩn chrome/đóng sheet khác nếu cần).
Future<bool?> showPdfReadingNavigator({
  required BuildContext context,
  required List<PdfOutlineEntry> entries,
  required int activeIndex,
  required bool isLoadingOutline,
  required bool hasOutline,
  required int currentPage,
  required int totalPages,
  required ValueChanged<PdfOutlineEntry> onSelectEntry,
  required ValueChanged<int> onSelectPage,
  PdfDocument? document,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF161B22),
    builder: (sheetContext) {
      return SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.72,
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                TabBar(
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  indicatorColor: const Color(0xFF2196F3),
                  tabs: [
                    Tab(
                      child: Text(sheetContext.uiText('Mục lục'),
                          style: const TextStyle(fontSize: 13)),
                    ),
                    Tab(
                      child: Text(sheetContext.uiText('Trang'),
                          style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      PdfTocPanel(
                        entries: entries,
                        activeIndex: activeIndex,
                        onSelect: (entry) {
                          onSelectEntry(entry);
                          Navigator.of(sheetContext).pop(true);
                        },
                        isLoading: isLoadingOutline,
                        hasOutline: hasOutline,
                      ),
                      PdfThumbnailGrid(
                        document: document,
                        totalPages: totalPages,
                        currentPage: currentPage,
                        onSelectPage: (pageIndex) {
                          onSelectPage(pageIndex);
                          Navigator.of(sheetContext).pop(true);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
