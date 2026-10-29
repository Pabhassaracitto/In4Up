// Mục lục (document outline) của PDF -> danh sách phẳng để render + suy ra
// "đang ở chương nào". Tách ra khỏi widget để test được không cần viewer.
import 'package:pdfrx/pdfrx.dart' hide PdfAnnotation;

/// One flattened outline row.
///
/// `pageNumber` is **1-based** (the convention of [PdfDest.pageNumber]) while
/// [PdfReaderController.currentPage] is 0-based — every comparison in this
/// file goes through [findActiveOutlineIndex] so the two never meet by accident.
class PdfOutlineEntry {
  const PdfOutlineEntry({
    required this.title,
    required this.level,
    required this.index,
    this.pageNumber,
    this.dest,
    this.hasChildren = false,
  });

  final String title;

  /// 0 = chương cấp 1.
  final int level;

  /// Vị trí trong danh sách đã làm phẳng (dùng làm key khi auto-scroll).
  final int index;

  /// Trang 1-based, `null` khi mục không có destination (nhóm mục lục thuần).
  final int? pageNumber;

  final PdfDest? dest;
  final bool hasChildren;

  bool get isJumpable => dest != null;
}

/// DFS làm phẳng cây outline. `maxNodes` là phanh an toàn: file truyện có mục
/// lục vài nghìn dòng thì panel vẫn dựng được, phần bị cắt có [kickedOutCount].
List<PdfOutlineEntry> flattenPdfOutline(
  List<PdfOutlineNode>? nodes, {
  int maxNodes = 3000,
}) {
  final out = <PdfOutlineEntry>[];
  if (nodes == null) return out;

  void walk(List<PdfOutlineNode> level, int depth) {
    for (final node in level) {
      if (out.length >= maxNodes) return;
      out.add(
        PdfOutlineEntry(
          title: node.title.trim().isEmpty ? '—' : node.title.trim(),
          level: depth,
          index: out.length,
          pageNumber: node.dest?.pageNumber,
          dest: node.dest,
          hasChildren: node.children.isNotEmpty,
        ),
      );
      if (node.children.isNotEmpty) walk(node.children, depth + 1);
    }
  }

  walk(nodes, 0);
  return out;
}

/// Mục đang "active" = mục cuối cùng có trang <= trang hiện tại.
///
/// [zeroBasedPage] là `PdfReaderController.currentPage` (0-based); cộng 1 để
/// so với `PdfOutlineEntry.pageNumber` (1-based). Trả về `-1` khi danh sách rỗng
/// hoặc người dùng đang đọc trước mục lục đầu tiên.
int findActiveOutlineIndex(
  List<PdfOutlineEntry> entries,
  int zeroBasedPage,
) {
  final page = zeroBasedPage + 1;
  var best = -1;
  for (final entry in entries) {
    final at = entry.pageNumber;
    if (at == null || at < 1) continue;
    if (at <= page) {
      best = entry.index;
    } else {
      // Danh sách làm phẳng theo DFS luôn tăng theo trang *trong cùng một
      // nhánh*, nhưng giữa các nhánh có thể lộn xộn (sách dịch 2 thứ tự) →
      // không được break, đi hết danh sách.
      continue;
    }
  }
  return best;
}

/// Nhãn chương cho toolbar: `null` khi file không có mục lục.
String? describeActiveOutline(List<PdfOutlineEntry> entries, int zeroBasedPage) {
  final idx = findActiveOutlineIndex(entries, zeroBasedPage);
  if (idx < 0 || idx >= entries.length) return null;
  return entries[idx].title;
}
