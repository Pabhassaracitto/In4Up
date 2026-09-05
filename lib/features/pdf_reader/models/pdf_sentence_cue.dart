import 'dart:ui' show Rect;

/// Một "cue" = một câu (hoặc một dòng ngắn) của trang PDF, kèm rect theo TỪNG
/// DÒNG để overlay tô sáng đúng hình dạng câu khi TTS đọc tới.
///
/// `startOffset/endOffset` là offset trong `fullText` THÔ của trang (cùng hệ
/// toạ độ với `PdfWordInfo.startOffset`) → reopened đúng vị trí, và dùng lại
/// được cho `VocabContext.textStartOffset`.
class PdfSentenceCue {
  const PdfSentenceCue({
    required this.pageIndex,
    required this.startOffset,
    required this.endOffset,
    required this.speakText,
    required this.lineRects,
    this.rectHintSourceText,
  });

  final int pageIndex;
  final int startOffset;
  final int endOffset;

  /// Văn bản ĐÃ làm sạch (nối từ bị ngắt dòng, bỏ soft hyphen) để đưa vào TTS.
  final String speakText;

  /// Rect của từng dòng trong câu, theo không gian trang PDF (gốc dưới-trái).
  final List<Rect> lineRects;

  /// Bản gốc có dấu xuống dòng — để đối chiếu/debug.
  final String? rectHintSourceText;

  bool get isUsable => speakText.trim().length > 1 && lineRects.isNotEmpty;

  Rect get bounds {
    if (lineRects.isEmpty) return Rect.zero;
    var out = lineRects.first;
    for (final r in lineRects.skip(1)) {
      out = out.expandToInclude(r);
    }
    return out;
  }

  String get preview {
    final t = speakText.trim();
    return t.length <= 80 ? t : '${t.substring(0, 77)}…';
  }

  @override
  String toString() =>
      'PdfSentenceCue(p$pageIndex, $startOffset..$endOffset, ${speakText.length} chars)';
}
