import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../models/color_mode.dart';
import '../models/pdf_word_info.dart';

/// CustomPaint overlay vẽ highlight màu từng từ lên PDF page
class PdfWordOverlay extends StatelessWidget {
  final List<PdfWordInfo> words;
  final ColorMode colorMode;
  final PdfPage page;
  final String? speakingWord;
  final String? focusWordCue;

  const PdfWordOverlay({
    super.key,
    required this.words,
    required this.colorMode,
    required this.page,
    this.speakingWord,
    this.focusWordCue,
  });

  @override
  Widget build(BuildContext context) {
    final hasRecallMarkers = words.any((w) =>
        w.analyzed?.isSaved == true ||
        w.analyzed?.hasSavedNotes == true ||
        w.analyzed?.hasDueReview == true);
    if (colorMode == ColorMode.none && speakingWord == null && !hasRecallMarkers) {
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
          focusWordCue: focusWordCue,
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
  final String? focusWordCue;
  final double pageHeight;

  _WordHighlightPainter({
    required this.words,
    required this.colorMode,
    required this.scaleX,
    required this.scaleY,
    this.speakingWord,
    this.focusWordCue,
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

      final analyzed = word.analyzed;
      if (analyzed?.isSaved == true) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(screenRect.inflate(1), const Radius.circular(3)),
          Paint()
            ..color = const Color(0xFF4CAF50).withValues(alpha: 0.45)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
      if (analyzed?.hasSavedNotes == true) {
        canvas.drawCircle(
          Offset(screenRect.right - 3, screenRect.top + 3),
          2.4,
          Paint()..color = Colors.amberAccent,
        );
      }
      if (analyzed?.hasDueReview == true) {
        canvas.drawCircle(
          Offset(screenRect.left + 3, screenRect.top + 3),
          2.4,
          Paint()..color = Colors.redAccent,
        );
      }

      if (focusWordCue != null) {
        final normalized = word.text.replaceAll(RegExp(r'[^\w\s]'), '').trim().toLowerCase();
        if (normalized == focusWordCue) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              screenRect.inflate(3),
              const Radius.circular(4),
            ),
            Paint()
              ..color = const Color(0xFF64B5F6).withValues(alpha: 0.28)
              ..style = PaintingStyle.fill,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              screenRect.inflate(3),
              const Radius.circular(4),
            ),
            Paint()
              ..color = const Color(0xFF64B5F6)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.8,
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
            ..color = const Color(0xFFFFEB3B).withValues(alpha: 0.6)
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
      old.focusWordCue != focusWordCue ||
      old.words.length != words.length;
}
