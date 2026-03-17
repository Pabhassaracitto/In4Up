import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../models/color_mode.dart';
import '../../../services/syntax_highlighter_service.dart';
import '../models/pdf_word_info.dart';
import 'package:flutter/material.dart';

class PdfTextExtractor {
  // Cache kết quả per-page để tránh recompute
  final Map<int, List<PdfWordInfo>> _pageCache = {};
  final Map<int, String> _textCache = {};

  /// Extract toàn bộ text của một page (plain string)
  Future<String> extractPageText(PdfPage page, int pageIndex) async {
    if (_textCache.containsKey(pageIndex)) {
      return _textCache[pageIndex]!;
    }

    try {
      final textPage = await page.loadText();
      final buffer = StringBuffer();

      for (final fragment in textPage.fragments) {
        buffer.write(fragment.text);
        // Thêm space nếu fragment không kết thúc bằng space
        if (!fragment.text.endsWith(' ')) buffer.write(' ');
      }

      final text = _cleanExtractedText(buffer.toString());
      _textCache[pageIndex] = text;
      return text;
    } catch (e) {
      debugPrint('PdfTextExtractor: error extracting page $pageIndex: $e');
      return '';
    }
  }

  /// Extract toàn bộ document thành string (dùng cho Text Mode)
  Future<String> extractFullText(PdfDocument document) async {
    final buffer = StringBuffer();
    for (int i = 0; i < document.pages.length; i++) {
      final pageText = await extractPageText(document.pages[i], i);
      if (pageText.isNotEmpty) {
        buffer.writeln(pageText);
        buffer.writeln(); // Blank line giữa các trang
      }
    }
    return buffer.toString();
  }

  /// Extract words với vị trí pixel cho một page
  /// Trả về List<PdfWordInfo> để dùng cho overlay highlight
  Future<List<PdfWordInfo>> extractWordsWithPositions(
    PdfPage page,
    int pageIndex,
    ColorMode colorMode,
  ) async {
    if (_pageCache.containsKey(pageIndex) && colorMode == ColorMode.none) {
      return _pageCache[pageIndex]!;
    }

    try {
      final textPage = await page.loadText();
      final words = <PdfWordInfo>[];

      for (final fragment in textPage.fragments) {
        final rawText = fragment.text.trim();
        if (rawText.isEmpty) continue;

        // Tách fragments thành từng từ nếu fragment chứa nhiều từ
        final subWords = rawText.split(RegExp(r'\s+'));

        if (subWords.length == 1) {
          // Single word - dùng bounds trực tiếp
          final analyzed = colorMode != ColorMode.none
              ? SyntaxHighlighterService.instance.analyzeWord(
                  rawText.toLowerCase().replaceAll(RegExp(r'[^\w]'), ''))
              : null;

          words.add(PdfWordInfo(
            text: rawText,
            bounds: _pdfRectToRect(fragment.bounds),
            pageIndex: pageIndex,
            analyzed: analyzed,
          ));
        } else {
          // Multi-word fragment - chia bounds đều (approximate)
          final totalWidth = fragment.bounds.width;
          final wordWidth = totalWidth / subWords.length;

          for (int wi = 0; wi < subWords.length; wi++) {
            final word = subWords[wi].trim();
            if (word.isEmpty) continue;

            final wordBounds = Rect.fromLTWH(
              fragment.bounds.left + wi * wordWidth,
              fragment.bounds.top,
              wordWidth,
              fragment.bounds.height,
            );

            final analyzed = colorMode != ColorMode.none
                ? SyntaxHighlighterService.instance.analyzeWord(
                    word.toLowerCase().replaceAll(RegExp(r'[^\w]'), ''))
                : null;

            words.add(PdfWordInfo(
              text: word,
              bounds: wordBounds,
              pageIndex: pageIndex,
              analyzed: analyzed,
            ));
          }
        }
      }

      _pageCache[pageIndex] = words;
      return words;
    } catch (e) {
      debugPrint(
          'PdfTextExtractor: error extracting words page $pageIndex: $e');
      return [];
    }
  }

  /// Convert PDF PdfRect → Flutter Rect
  Rect _pdfRectToRect(PdfRect pdfRect) {
    return Rect.fromLTRB(
      pdfRect.left,
      pdfRect.top,
      pdfRect.right,
      pdfRect.bottom,
    );
  }

  /// Làm sạch text extract từ PDF
  String _cleanExtractedText(String raw) {
    return raw
        // Xóa soft hyphen (word wrap trong PDF)
        .replaceAll('\u00AD', '')
        // Nối từ bị cắt ngang dòng: "enlight-\nment" → "enlightment"
        .replaceAll(RegExp(r'-\n(?=[a-z])'), '')
        // Nhiều space thành 1
        .replaceAll(RegExp(r' {2,}'), ' ')
        // Nhiều newline thành 2 (paragraph break)
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  void clearCache() {
    _pageCache.clear();
    _textCache.clear();
  }

  void clearPageCache(int pageIndex) {
    _pageCache.remove(pageIndex);
    _textCache.remove(pageIndex);
  }
}
