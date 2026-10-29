import 'package:flutter/material.dart';

import '../models/grammar_category.dart';
import '../models/grammar_highlight_settings.dart';
import '../models/grammar_highlight_style.dart';
import '../models/grammar_palette.dart';

class GrammarResolvedStyle {
  final Color foreground;
  final Color background;
  final Color? underline;
  final Color? outline;
  final FontWeight fontWeight;
  final bool shouldDim;

  const GrammarResolvedStyle({
    required this.foreground,
    required this.background,
    this.underline,
    this.outline,
    required this.fontWeight,
    required this.shouldDim,
  });
}

class GrammarStyleMapper {
  GrammarStyleMapper._();

  static GrammarResolvedStyle resolve({
    required GrammarCategory category,
    required GrammarPalette palette,
    required GrammarHighlightSettings settings,
    required Color defaultTextColor,
  }) {
    final entry = palette.styleFor(category);
    final visible = settings.isVisible(category);
    final baseColor = entry.color;
    final shouldDim = settings.dimHiddenCategories && !visible;
    final alpha = shouldDim ? 0.18 : 0.14;

    switch (settings.highlightStyle) {
      case GrammarHighlightStyle.subtleBackground:
        return GrammarResolvedStyle(
          foreground: visible ? baseColor : defaultTextColor.withValues(alpha: 0.58),
          background: visible ? baseColor.withValues(alpha: alpha) : Colors.transparent,
          fontWeight: entry.isBold ? FontWeight.w700 : FontWeight.w500,
          shouldDim: shouldDim,
        );
      case GrammarHighlightStyle.underline:
        return GrammarResolvedStyle(
          foreground: visible ? baseColor : defaultTextColor.withValues(alpha: 0.58),
          background: Colors.transparent,
          underline: visible ? baseColor : null,
          fontWeight: entry.isBold ? FontWeight.w700 : FontWeight.w500,
          shouldDim: shouldDim,
        );
      case GrammarHighlightStyle.outline:
        return GrammarResolvedStyle(
          foreground: visible ? baseColor : defaultTextColor.withValues(alpha: 0.58),
          background: Colors.transparent,
          outline: visible ? baseColor.withValues(alpha: 0.6) : null,
          fontWeight: entry.isBold ? FontWeight.w700 : FontWeight.w500,
          shouldDim: shouldDim,
        );
      case GrammarHighlightStyle.bold:
        return GrammarResolvedStyle(
          foreground: visible ? baseColor : defaultTextColor.withValues(alpha: 0.58),
          background: Colors.transparent,
          fontWeight: visible ? FontWeight.w800 : FontWeight.w500,
          shouldDim: shouldDim,
        );
      case GrammarHighlightStyle.mixed:
        return GrammarResolvedStyle(
          foreground: visible ? baseColor : defaultTextColor.withValues(alpha: 0.58),
          background: category.isContentWord && visible
              ? baseColor.withValues(alpha: alpha)
              : Colors.transparent,
          underline: !category.isContentWord && visible ? baseColor : null,
          outline: category == GrammarCategory.modal && visible
              ? baseColor.withValues(alpha: 0.55)
              : null,
          fontWeight: entry.isBold || (settings.emphasizeContentWords && category.isContentWord)
              ? FontWeight.w700
              : FontWeight.w500,
          shouldDim: shouldDim,
        );
    }
  }
}
