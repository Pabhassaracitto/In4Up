import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../models/color_mode.dart';
import '../models/pdf_word_info.dart';

/// CustomPaint overlay vẽ highlight màu từng từ lên PDF page.
class PdfWordOverlay extends StatelessWidget {
  final List<PdfWordInfo> words;
  final int pageIndex;
  final ColorMode colorMode;
  final PdfPage page;
  final String? speakingWord;
  final String? focusWordCue;
  final Rect? focusRectCue;
  final int? focusPageIndexCue;
  final int? focusTextStartOffsetCue;
  final int? focusTextEndOffsetCue;

  const PdfWordOverlay({
    super.key,
    required this.words,
    required this.pageIndex,
    required this.colorMode,
    required this.page,
    this.speakingWord,
    this.focusWordCue,
    this.focusRectCue,
    this.focusPageIndexCue,
    this.focusTextStartOffsetCue,
    this.focusTextEndOffsetCue,
  });

  @override
  Widget build(BuildContext context) {
    final hasRecallMarkers = words.any((w) =>
        w.analyzed?.isSaved == true ||
        w.analyzed?.hasSavedNotes == true ||
        w.analyzed?.hasDueReview == true);
    final hasFocusCue =
        focusWordCue != null || focusRectCue != null || focusTextStartOffsetCue != null;

    if (colorMode == ColorMode.none && speakingWord == null && !hasRecallMarkers && !hasFocusCue) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(builder: (context, constraints) {
      final scaleX = constraints.maxWidth / page.width;
      final scaleY = constraints.maxHeight / page.height;

      return CustomPaint(
        size: Size(constraints.maxWidth, constraints.maxHeight),
        painter: _WordHighlightPainter(
          words: words,
          pageIndex: pageIndex,
          colorMode: colorMode,
          scaleX: scaleX,
          scaleY: scaleY,
          speakingWord: speakingWord,
          focusWordCue: focusWordCue,
          focusRectCue: focusRectCue,
          focusPageIndexCue: focusPageIndexCue,
          focusTextStartOffsetCue: focusTextStartOffsetCue,
          focusTextEndOffsetCue: focusTextEndOffsetCue,
          pageHeight: page.height,
        ),
      );
    });
  }
}

class _WordHighlightPainter extends CustomPainter {
  final List<PdfWordInfo> words;
  final int pageIndex;
  final ColorMode colorMode;
  final double scaleX;
  final double scaleY;
  final String? speakingWord;
  final String? focusWordCue;
  final Rect? focusRectCue;
  final int? focusPageIndexCue;
  final int? focusTextStartOffsetCue;
  final int? focusTextEndOffsetCue;
  final double pageHeight;

  _WordHighlightPainter({
    required this.words,
    required this.pageIndex,
    required this.colorMode,
    required this.scaleX,
    required this.scaleY,
    this.speakingWord,
    this.focusWordCue,
    this.focusRectCue,
    this.focusPageIndexCue,
    this.focusTextStartOffsetCue,
    this.focusTextEndOffsetCue,
    required this.pageHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    var matchedPreciseCue = false;

    for (final word in words) {
      final screenRect = _toScreenRect(word.bounds);

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

      if (_matchesPreciseCue(word)) {
        matchedPreciseCue = true;
        _drawFocusCue(canvas, screenRect);
      } else if (focusWordCue != null && word.normalizedText == focusWordCue) {
        _drawFocusCue(canvas, screenRect);
      }

      if (speakingWord != null && word.text.toLowerCase() == speakingWord!.toLowerCase()) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            screenRect.inflate(2),
            const Radius.circular(3),
          ),
          Paint()
            ..color = const Color(0xFFFFEB3B).withValues(alpha: 0.6)
            ..style = PaintingStyle.fill,
        );
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

    final shouldDrawFallbackRect = focusRectCue != null &&
        !matchedPreciseCue &&
        (focusPageIndexCue == null || focusPageIndexCue == pageIndex);
    if (shouldDrawFallbackRect) {
      _drawFocusCue(canvas, _toScreenRect(focusRectCue!));
    }
  }

  bool _matchesPreciseCue(PdfWordInfo word) {
    if (focusPageIndexCue != null && focusPageIndexCue != word.pageIndex) return false;

    if (focusTextStartOffsetCue != null && focusTextEndOffsetCue != null) {
      return word.overlapsTextRange(
        focusTextStartOffsetCue!,
        focusTextEndOffsetCue!,
      );
    }

    if (focusRectCue != null) {
      return word.bounds.overlaps(focusRectCue!.inflate(1));
    }

    return false;
  }

  Rect _toScreenRect(Rect pdfRect) {
    final flippedTop = pageHeight - pdfRect.bottom;
    return Rect.fromLTWH(
      pdfRect.left * scaleX,
      flippedTop * scaleY,
      pdfRect.width * scaleX,
      pdfRect.height * scaleY,
    );
  }

  void _drawFocusCue(Canvas canvas, Rect screenRect) {
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

  @override
  bool shouldRepaint(_WordHighlightPainter old) =>
      old.pageIndex != pageIndex ||
      old.colorMode != colorMode ||
      old.speakingWord != speakingWord ||
      old.focusWordCue != focusWordCue ||
      old.focusRectCue != focusRectCue ||
      old.focusPageIndexCue != focusPageIndexCue ||
      old.focusTextStartOffsetCue != focusTextStartOffsetCue ||
      old.focusTextEndOffsetCue != focusTextEndOffsetCue ||
      old.words.length != words.length;
}
