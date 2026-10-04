import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../models/color_mode.dart';
import '../../../services/syntax_highlighter_service.dart';
import '../models/pdf_sentence_cue.dart';
import '../models/pdf_word_info.dart';

/// Trích chữ + toạ độ từ một trang PDF.
///
/// Hai luồng dùng chung dữ liệu này:
///  1) overlay tô màu theo từ (cần `bounds` từng từ),
///  2) TTS "karaoke" theo câu (cần `PdfSentenceCue` + rect theo dòng).
class PdfTextExtractor {
  /// Dòng kết thúc một câu khi tách câu cho TTS: dấu kết thúc, cho phép nháy
  /// đóng/ngoặc đóng đứng sau.
  ///
  /// VIẾT BẰNG RAW STRING 3 NHÁY. Trong `r'...'` một nháy, `\'` **không** thoát
  /// được nháy — chuỗi kết thúc ngay sau `\`, phần còn lại bị parser hiểu thành
  /// mã nguồn → ~20 error dây chuyền trong `flutter analyze` của CI mà grep mã
  /// thường không đọc ra. `test/pdf_reader/pdf_text_cleaning_test.dart` khóa
  /// hành vi này lại.
  static final RegExp sentenceEndPattern = RegExp(r'''[.!?…]["'”’)\]]*$''');

  // Cache per-page. Key phải tính tới CẢ colorMode lẫn nhu cầu phân tích từ,
  // vì với ColorMode.none code cũ bỏ qua `analyzeWord` → recall markers (vốn
  // đọc `analyzed`) vĩnh viễn không hiện khi người dùng tắt tô màu
  // (READ-630-03). Cache key bên dưới sửa đúng chỗ đó.
  final Map<int, List<PdfWordInfo>> _pageCache = {};
  final Map<int, String> _pageCacheKey = {};
  final Map<int, String> _textCache = {};
  final Map<int, List<PdfSentenceCue>> _sentenceCache = {};

  /// Extract toàn bộ text của một page (plain string).
  Future<String> extractPageText(PdfPage page, int pageIndex) async {
    final cached = _textCache[pageIndex];
    if (cached != null) return cached;

    try {
      final textPage = await page.loadText();
      if (textPage == null) {
        _textCache[pageIndex] = '';
        return '';
      }
      final text = cleanExtractedText(textPage.fullText);
      _textCache[pageIndex] = text;
      return text;
    } catch (e) {
      debugPrint('PdfTextExtractor: error extracting page $pageIndex: $e');
      return '';
    }
  }

  /// Extract toàn bộ document thành string (dùng cho Text Mode).
  ///
  /// [onProgress] được gọi sau mỗi trang để UI hiện tiến độ — trước đây vòng lặp
  /// này chạy im lặng trên UI isolate nên file vài trăm trang trông như app treo.
  Future<String> extractFullText(
    PdfDocument document, {
    void Function(int pageIndex, int pageCount)? onProgress,
  }) async {
    final buffer = StringBuffer();
    final count = document.pages.length;
    for (int i = 0; i < count; i++) {
      final pageText = await extractPageText(document.pages[i], i);
      if (pageText.isNotEmpty) {
        buffer.writeln(pageText);
        buffer.writeln();
      }
      onProgress?.call(i, count);
      // Nhả UI isolate để app không bị coi là đơ trên file lớn.
      if (i % 8 == 7) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    return buffer.toString();
  }

  /// Words + vị trí để overlay tô màu / recall marker / hit-test chạm.
  Future<List<PdfWordInfo>> extractWordsWithPositions(
    PdfPage page,
    int pageIndex,
    ColorMode colorMode, {
    bool needsAnalysis = false,
  }) async {
    final cacheKey = '${colorMode.name}|$needsAnalysis';
    if (_pageCache.containsKey(pageIndex) &&
        _pageCacheKey[pageIndex] == cacheKey) {
      return _pageCache[pageIndex]!;
    }

    try {
      final textPage = await page.loadText();
      if (textPage == null) return const [];

      final fullText = textPage.fullText;
      final charRects = textPage.charRects;
      final analyze = colorMode != ColorMode.none || needsAnalysis;

      final words = <PdfWordInfo>[];
      for (final m in RegExp(r'\S+').allMatches(fullText)) {
        final token = m.group(0)!.trim();
        if (token.isEmpty) continue;

        final bounds = _rectFromCharRects(charRects, m.start, m.end);

        final normalized = token.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
        final analyzed = (analyze && normalized.isNotEmpty)
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

      _pageCache[pageIndex] = words;
      _pageCacheKey[pageIndex] = cacheKey;
      return words;
    } catch (e) {
      debugPrint(
          'PdfTextExtractor: error extracting words page $pageIndex: $e');
      return const [];
    }
  }

  /// Tách trang thành từng CÂU kèm rect theo dòng — nền cho TTS karaoke và cho
  /// "lặp lại câu đang đọc".
  ///
  /// `fullText` của PDFium có một dòng văn bản = một dòng trong chuỗi, nên ta lấy
  /// dòng làm đơn vị dựng rect rồi gom thành câu. Nhờ vậy:
  ///  - rect tô sáng khớp hình dạng câu (không phải một khối chữ nhật khổng lồ
  ///    phủ cả khoảng trắng cuối dòng),
  ///  - offset vẫn neo trên text thô → reopened đúng `VocabContext`.
  Future<List<PdfSentenceCue>> extractSentences(
    PdfPage page,
    int pageIndex,
  ) async {
    final cached = _sentenceCache[pageIndex];
    if (cached != null) return cached;

    final cues = <PdfSentenceCue>[];
    try {
      final textPage = await page.loadText();
      if (textPage != null) {
        final fullText = textPage.fullText;
        final charRects = textPage.charRects;

        final lineStarts = <int>[];
        final lineEnds = <int>[];
        var cursor = 0;
        for (final raw in fullText.split('\n')) {
          if (raw.trim().isNotEmpty) {
            lineStarts.add(cursor);
            lineEnds.add(cursor + raw.length);
          }
          cursor += raw.length + 1;
        }

        final buffer = StringBuffer();
        var firstLine = -1;
        for (int i = 0; i < lineStarts.length; i++) {
          final line = fullText.substring(lineStarts[i], lineEnds[i]).trim();
          if (firstLine < 0) firstLine = i;
          if (buffer.isNotEmpty) buffer.write(' ');
          buffer.write(line);

          final accumulated = buffer.toString().trim();
          final endsWithPunctuation = sentenceEndPattern.hasMatch(line);
          final isShortHeading = line.length <= 42 && !endsWithPunctuation;
          final tooLong = accumulated.length >= 300;

          if (endsWithPunctuation ||
              isShortHeading ||
              tooLong ||
              i == lineStarts.length - 1) {
            final speak = cleanExtractedText(accumulated);
            if (speak.replaceAll(RegExp(r'[^\w]'), '').length >= 2) {
              cues.add(PdfSentenceCue(
                pageIndex: pageIndex,
                startOffset: lineStarts[firstLine],
                endOffset: lineEnds[i],
                speakText: speak,
                lineRects: _lineRectsFor(charRects, lineStarts, lineEnds,
                    firstLine, i),
                rectHintSourceText: accumulated,
              ));
            }
            buffer.clear();
            firstLine = -1;
          }
        }
      }
    } catch (e) {
      debugPrint('PdfTextExtractor: sentence error page $pageIndex: $e');
    }
    _sentenceCache[pageIndex] = cues;
    return cues;
  }

  /// Rect cho từng dòng trong đoạn [fromLine..toLine] (inclusive).
  List<Rect> _lineRectsFor(
    List<PdfRect> charRects,
    List<int> lineStarts,
    List<int> lineEnds,
    int fromLine,
    int toLine,
  ) {
    final rects = <Rect>[];
    for (int li = fromLine; li <= toLine; li++) {
      rects.addAll(_rectPartsFromCharRects(charRects, lineStarts[li], lineEnds[li]));
    }
    return rects;
  }

  /// Gom charRects của một dòng thành 1..n rect.
  ///
  /// Tách khi khoảng hở ngang lớn (> 3 lần bề rộng ký tự trung bình): đó là chữ
  /// thụt đầu dòng, số trang ở lề phải, hoặc hai cột trên cùng một dòng. Không
  /// tách thì một rect duy nhất phủ cả vùng trắng giữa hai cột.
  List<Rect> _rectPartsFromCharRects(
      List<PdfRect> charRects, int start, int end) {
    final boxes = <Rect>[];
    final s = start.clamp(0, charRects.length);
    final e = end.clamp(s, charRects.length);
    for (int i = s; i < e; i++) {
      final r = _pdfRectToRect(charRects[i]);
      if (r.width <= 0 || r.height <= 0) continue;
      boxes.add(r);
    }
    if (boxes.isEmpty) return const [];

    var avgWidth = 0.0;
    for (final b in boxes) {
      avgWidth += b.width;
    }
    avgWidth = avgWidth / boxes.length;
    final gapLimit = avgWidth * 3;

    final out = <Rect>[];
    var current = boxes.first;
    for (int i = 1; i < boxes.length; i++) {
      final next = boxes[i];
      final height = current.height > 0 ? current.height : next.height;
      final sameLine = (next.top - current.top).abs() < height * 0.6;
      if (next.left - current.right > gapLimit || !sameLine) {
        out.add(current);
        current = next;
      } else {
        current = current.expandToInclude(next);
      }
    }
    out.add(current);
    return out;
  }

  /// Gom bounds từ charRects[start..end) thành một rect bao trọn.
  Rect _rectFromCharRects(List<PdfRect> charRects, int start, int end) {
    if (charRects.isEmpty) return Rect.zero;
    final s = start.clamp(0, charRects.length);
    final e = end.clamp(s, charRects.length);
    if (s >= e) return Rect.zero;

    Rect? out;
    for (int i = s; i < e; i++) {
      final r = _pdfRectToRect(charRects[i]);
      if (r.width <= 0 && r.height <= 0) continue;
      out = (out == null) ? r : out.expandToInclude(r);
    }
    return out ?? Rect.zero;
  }

  /// Convert PDF PdfRect → Flutter Rect, GIỮ nguyên hệ toạ độ gốc dưới-trái của
  /// PDF. Việc lật trục nằm ở `pdfRectToViewerRect` và overlay painter — hai chỗ
  /// đó dùng chung một công thức nên chạm trúng đâu sáng đúng đó.
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
      if (ch == '.' || ch == '!' || ch == '?') {
        right++;
        break;
      }
      if (ch == '\n') break;
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

  /// Làm sạch text extract từ PDF (dùng chung cho TTS + Text Mode).
  String cleanExtractedText(String raw) {
    return raw
        // Xóa soft hyphen (word wrap trong PDF)
        .replaceAll('\u00AD', '')
        // Nối từ bị cắt ngang dòng: "enlighten-\nment" → "enlightenment"
        .replaceAll(RegExp(r'-\n(?=[a-z])'), '')
        // Nhiều space thành 1
        .replaceAll(RegExp(r' {2,}'), ' ')
        // Nhiều newline thành 2 (paragraph break)
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  void clearCache() {
    _pageCache.clear();
    _pageCacheKey.clear();
    _textCache.clear();
    _sentenceCache.clear();
  }

  /// Chỉ huỷ cache của những trang cần vẽ lại — thay cho `clearCache()` toàn
  /// phần, vốn khiến mỗi lần lưu 1 từ lại re-extract cả trang (giật).
  void invalidatePages(Iterable<int> pageIndexes) {
    for (final i in pageIndexes) {
      _pageCache.remove(i);
      _pageCacheKey.remove(i);
      _textCache.remove(i);
      _sentenceCache.remove(i);
    }
  }

  void clearPageCache(int pageIndex) => invalidatePages([pageIndex]);
}
