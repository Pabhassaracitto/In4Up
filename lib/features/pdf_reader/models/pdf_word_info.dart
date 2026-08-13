import 'package:flutter/material.dart';
import 'package:in4up_core/vocab_level_difficulty.dart';

import '../../../models/color_mode.dart';
import '../../../models/word_analysis.dart';

/// Thông tin một từ trên PDF page, bao gồm vị trí pixel và phân tích ngôn ngữ.
class PdfWordInfo {
  final String text;
  final Rect bounds; // Tọa độ trong PDF coordinate space
  final int pageIndex;
  final int startOffset;
  final int endOffset;
  final String? contextSnippet;
  final AnalyzedWord? analyzed;

  const PdfWordInfo({
    required this.text,
    required this.bounds,
    required this.pageIndex,
    this.startOffset = 0,
    this.endOffset = 0,
    this.contextSnippet,
    this.analyzed,
  });

  String get normalizedText =>
      text.replaceAll(RegExp(r'[^\w\s]'), '').trim().toLowerCase();

  bool overlapsTextRange(int start, int end) => endOffset > start && startOffset < end;

  /// Lấy màu highlight theo ColorMode
  Color getHighlightColor(ColorMode mode) {
    if (analyzed == null) return Colors.transparent;
    switch (mode) {
      case ColorMode.none:
        return Colors.transparent;
      case ColorMode.wordType:
        return analyzed!.wordType.color.withAlpha((255 * 0.28).round());
      case ColorMode.cefrLevel:
        return analyzed!.cefrLevel.color.withAlpha((255 * 0.28).round());
      case ColorMode.difficulty:
        return (analyzed!.userDifficulty?.color ?? Colors.transparent)
            .withAlpha((255 * 0.28).round());
    }
  }
}
