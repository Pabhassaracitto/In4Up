// Lưới ảnh thu nhỏ trang. `PdfPageView` tự render theo kích thước ô và tự hủy
// ảnh khi bị thải khỏi viewport, nên ListView/GridView dựng lười là đủ rẻ cho
// sách 500 trang — không cần hàng đợi thumbnail riêng.
import 'package:in4up/core/language/localized_material.dart';
import 'package:pdfrx/pdfrx.dart' hide PdfAnnotation;

class PdfThumbnailGrid extends StatelessWidget {
  const PdfThumbnailGrid({
    super.key,
    required this.document,
    required this.totalPages,
    required this.currentPage,
    required this.onSelectPage,
  });

  /// `PdfDocument` đang mở trong viewer. `null` khi chưa load xong.
  final PdfDocument? document;

  final int totalPages;

  /// 0-based, như `PdfReaderController.currentPage`.
  final int currentPage;
  final ValueChanged<int> onSelectPage;

  @override
  Widget build(BuildContext context) {
    final document = this.document;
    if (document == null || totalPages <= 0) {
      return Center(
        child: Text(
          context.uiText('Đang tải trang...'),
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 132,
        childAspectRatio: 0.72,
        crossAxisSpacing: 12,
        mainAxisSpacing: 10,
      ),
      // 500 trang mà dựng hết một lần là chết máy; builder chỉ dựng ô thấy được.
      itemCount: totalPages,
      itemBuilder: (context, index) {
        final isCurrent = index == currentPage;
        return InkWell(
          onTap: () => onSelectPage(index),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isCurrent
                          ? const Color(0xFF2196F3)
                          : Colors.white.withValues(alpha: 0.12),
                      width: isCurrent ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: PdfPageView(
                    document: document,
                    pageNumber: index + 1,
                    // Thumbnail không cần nét: 96 DPI là đủ; pdfrx dựng ảnh theo
                    // đúng kích thước ô nên DPI cao chỉ tổ tốn RAM.
                    maximumDpi: 96,
                    backgroundColor: const Color(0xFFEDF1F7),
                    decoration: const BoxDecoration(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 11,
                  color: isCurrent
                      ? const Color(0xFF64B5F6)
                      : Colors.white54,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
