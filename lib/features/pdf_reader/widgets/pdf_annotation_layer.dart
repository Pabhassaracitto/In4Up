// lib/features/pdf_reader/widgets/pdf_annotation_layer.dart
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart' hide PdfAnnotation;

import '../models/pdf_annotation.dart';
import '../services/pdf_geometry.dart';

/// Lớp vẽ highlight/ghi chú/bookmark lên một trang PDF.
///
/// Điểm chết người từng có ở đây: rect annotation được lưu theo quy ước PDF
/// (`top > bottom`), nên `ann.bounds.height` là số ÂM → `Positioned(height: -12)`
/// hoặc không vẽ gì. Vì vậy highlight người dùng lưu gần như không hiện ra.
/// Lớp này luôn đi qua `pdfRectToViewerRect` và vẽ THEO TỪNG DÒNG khi annotation
/// có `lineRects` (selection dài 3 dòng phải sáng 3 vạch, không phải một khối
/// phủ trọn vùng trắng giữa các dòng).
class PdfAnnotationLayer extends StatelessWidget {
  final List<PdfAnnotation> annotations;
  final PdfPage page;
  final void Function(PdfAnnotation) onAnnotationTap;

  const PdfAnnotationLayer({
    super.key,
    required this.annotations,
    required this.page,
    required this.onAnnotationTap,
  });

  @override
  Widget build(BuildContext context) {
    if (annotations.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(builder: (context, constraints) {
      final scaleX = constraints.maxWidth / page.width;
      final scaleY = constraints.maxHeight / page.height;

      return Stack(
        clipBehavior: Clip.none,
        children: [
          for (final ann in annotations)
            if (ann.type == AnnotationType.bookmark)
              _BookmarkFlag(
                annotation: ann,
                onTap: () => onAnnotationTap(ann),
              )
            else
              for (final rect in _rectsFor(ann))
                _HighlightStrip(
                  annotation: ann,
                  rect: pdfRectToViewerRect(
                    rect,
                    pageHeight: page.height,
                    scaleX: scaleX,
                    scaleY: scaleY,
                  ),
                  onTap: () => onAnnotationTap(ann),
                  showNoteBadge: ann.rectsForPainting.first == rect,
                ),
        ],
      );
    });
  }

  static List<Rect> _rectsFor(PdfAnnotation ann) =>
      // Lọc SAU khi quy đổi: rect degenerate biến thành Rect.zero và bị loại,
      // rect hợp lệ ở bất kỳ chiều y nào cũng còn vẽ được.
      ann.rectsForPainting
          .where(isPaintablePdfRect)
          .toList(growable: false);
}

class _HighlightStrip extends StatelessWidget {
  const _HighlightStrip({
    required this.annotation,
    required this.rect,
    required this.onTap,
    required this.showNoteBadge,
  });

  final PdfAnnotation annotation;
  final Rect rect;
  final VoidCallback onTap;
  final bool showNoteBadge;

  @override
  Widget build(BuildContext context) {
    // positioned không nhận chiều âm/0 -> bỏ qua (chứ không ném đỏ).
    if (rect.isEmpty || rect.height <= 0 || rect.width <= 0) {
      return const SizedBox.shrink();
    }
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: annotation.color.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
                border: Border(
                  bottom: BorderSide(color: annotation.color, width: 2),
                ),
              ),
            ),
            if (showNoteBadge &&
                annotation.note != null &&
                annotation.note!.isNotEmpty)
              Positioned(
                top: -10,
                right: -10,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: annotation.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.note,
                    size: 10,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Cờ bookmark ở mép phải trang — một điểm chạm để mở lại đúng trang.
class _BookmarkFlag extends StatelessWidget {
  const _BookmarkFlag({
    required this.annotation,
    required this.onTap,
  });

  final PdfAnnotation annotation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 2,
      top: 6,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          decoration: BoxDecoration(
            color: annotation.color.withValues(alpha: 0.9),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: const Icon(Icons.bookmark, size: 13, color: Colors.white),
        ),
      ),
    );
  }
}
