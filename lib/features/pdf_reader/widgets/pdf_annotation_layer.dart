import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart' hide PdfAnnotation;
import 'package:in2up/features/pdf_reader/models/pdf_annotation.dart';

/// Layer hiển thị tất cả annotations (highlight + note icons) trên PDF page
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
        children: annotations.map((ann) {
          final flippedTop = page.height - ann.bounds.bottom;
          final left = ann.bounds.left * scaleX;
          final top = flippedTop * scaleY;
          final width = ann.bounds.width * scaleX;
          final height = ann.bounds.height * scaleY;

          return Positioned(
            left: left,
            top: top,
            width: width,
            height: height,
            child: GestureDetector(
              onTap: () => onAnnotationTap(ann),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Highlight color strip
                  Container(
                    decoration: BoxDecoration(
                      color: ann.color.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                      border: Border(
                        bottom: BorderSide(color: ann.color, width: 2),
                      ),
                    ),
                  ),
                  // Note icon nếu có ghi chú
                  if (ann.note != null && ann.note!.isNotEmpty)
                    Positioned(
                      top: -10,
                      right: -10,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: ann.color,
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
        }).toList(),
      );
    });
  }
}
