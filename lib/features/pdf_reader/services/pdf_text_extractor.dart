import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../models/color_mode.dart';
import '../../../services/syntax_highlighter_service.dart';
import '../models/pdf_word_info.dart';

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
      // ✅ Ép kiểu rõ ràng sang PdfTextPage? để tránh lỗi PdfPageRawText
      final textPage = (await page.loadText());

      if (textPage == null) {
        _textCache[pageIndex] = '';
        return '';
      }

      // ✅ Bây giờ fullText sẽ được nhận diện chính xác
      final text = _cleanExtractedText(textPage.fullText);
      _textCache[pageIndex] = text;
      return text;

      // HOẶC nếu cần dùng fragments:
      // final buffer = StringBuffer();
      // for (final fragment in textPage.fragments) {
      //   final fragmentText = textPage.fullText.substring(
      //     fragment.index,
      //     fragment.end,
      //   );
      //   buffer.write(fragmentText);
      //   if (!fragmentText.endsWith(' ')) buffer.write(' ');
      // }
      // final text = _cleanExtractedText(buffer.toString());
      // _textCache[pageIndex] = text;
      // return text;
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
      final textPage = await page.loadText(); // <- thực tế là PdfPageRawText?
      if (textPage == null) return [];

      final fullText = textPage.fullText;
      final charRects = textPage
          .charRects; // <- có từ engine: PdfPageRawText(fullText, charRects)

      final words = <PdfWordInfo>[];

      for (final m in RegExp(r'\S+').allMatches(fullText)) {
        final token = m.group(0)!.trim();
        if (token.isEmpty) continue;

        final bounds = _rectFromCharRects(charRects, m.start, m.end);

        final normalized = token.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
        final analyzed = (colorMode != ColorMode.none && normalized.isNotEmpty)
            ? SyntaxHighlighterService.instance.analyzeWord(normalized)
            : null;

        words.add(PdfWordInfo(
          text: token,
          bounds: bounds,
          pageIndex: pageIndex,
          startOffset: m.start,
          endOffset: m.end,
          contextSnippet: _extractContextSnippet(fullText, m.start, m.end),
          analyzed: analyzed,
        ));
      }

      if (colorMode == ColorMode.none) {
        _pageCache[pageIndex] = words;
      }
      return words;
    } catch (e) {
      debugPrint(
          'PdfTextExtractor: error extracting words page $pageIndex: $e');
      return [];
    }
  }

  /// Gom bounds từ charRects[start..end)
  Rect _rectFromCharRects(List<PdfRect> charRects, int start, int end) {
    if (charRects.isEmpty) return Rect.zero;

    final s = start.clamp(0, charRects.length);
    final e = end.clamp(s, charRects.length);
    if (s >= e) return Rect.zero;

    Rect? out;
    for (int i = s; i < e; i++) {
      final r = _pdfRectToRect(charRects[i]); // dùng helper hiện có của bạn
      out = (out == null) ? r : out.expandToInclude(r);
    }
    return out ?? Rect.zero;
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

  String _extractContextSnippet(String source, int start, int end) {
    if (source.isEmpty) return '';

    var left = start.clamp(0, source.length);
    var right = end.clamp(0, source.length);

    while (left > 0) {
      final ch = source[left - 1];
      if (ch == '.' || ch == '!' || ch == '?' || ch == '\n') break;
      left--;
    }

    while (right < source.length) {
      final ch = source[right];
      if (ch == '.' || ch == '!' || ch == '?' || ch == '\n') {
        right++;
        break;
      }
      right++;
    }

    if (right - left < 18) {
      left = (start - 72).clamp(0, source.length);
      right = (end + 92).clamp(0, source.length);
    }

    return source
        .substring(left, right)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
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
