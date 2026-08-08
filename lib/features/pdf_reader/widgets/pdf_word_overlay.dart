import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart' hide PdfAnnotation;

import '../../../models/color_mode.dart';
import '../models/pdf_word_info.dart';

/// CustomPaint overlay vẽ highlight màu từng từ lên PDF page
class PdfWordOverlay extends StatelessWidget {
  final List<PdfWordInfo> words;
  final ColorMode colorMode;
  final PdfPage page;
  final String? speakingWord;

  const PdfWordOverlay({
    super.key,
    required this.words,
    required this.colorMode,
    required this.page,
    this.speakingWord,
  });

  @override
  Widget build(BuildContext context) {
    if (colorMode == ColorMode.none && speakingWord == null) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(builder: (context, constraints) {
      // Scale: PDF units → screen pixels
      final scaleX = constraints.maxWidth / page.width;
      final scaleY = constraints.maxHeight / page.height;

      return CustomPaint(
        size: Size(constraints.maxWidth, constraints.maxHeight),
        painter: _WordHighlightPainter(
          words: words,
          colorMode: colorMode,
          scaleX: scaleX,
          scaleY: scaleY,
          speakingWord: speakingWord,
          pageHeight: page.height,
        ),
      );
    });
  }
}

class _WordHighlightPainter extends CustomPainter {
  final List<PdfWordInfo> words;
  final ColorMode colorMode;
  final double scaleX;
  final double scaleY;
  final String? speakingWord;
  final double pageHeight;

  _WordHighlightPainter({
    required this.words,
    required this.colorMode,
    required this.scaleX,
    required this.scaleY,
    this.speakingWord,
    required this.pageHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final word in words) {
      // PDF coordinate: origin bottom-left, Flutter: top-left
      // Cần flip Y axis
      final flippedTop = pageHeight - word.bounds.bottom;
      final screenRect = Rect.fromLTWH(
        word.bounds.left * scaleX,
        flippedTop * scaleY,
        word.bounds.width * scaleX,
        word.bounds.height * scaleY,
      );

      // Highlight màu theo ColorMode
      if (colorMode != ColorMode.none) {
        final color = word.getHighlightColor(colorMode);
        if (color != Colors.transparent) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(screenRect, const Radius.circular(2)),
            Paint()..color = color,
          );
        }
      }

      // Speaking word highlight (yellow glow)
      if (speakingWord != null &&
          word.text.toLowerCase() == speakingWord!.toLowerCase()) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            screenRect.inflate(2),
            const Radius.circular(3),
          ),
          Paint()
            ..color = Color(0xFFFFEB3B).withValues(alpha: 0.6)
            ..style = PaintingStyle.fill,
        );
        // Border
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            screenRect.inflate(2),
            const Radius.circular(3),
          ),
          Paint()
            ..color = const Color(0xFFFFEB3B)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_WordHighlightPainter old) =>
      old.colorMode != colorMode ||
      old.speakingWord != speakingWord ||
      old.words.length != words.length;
}
