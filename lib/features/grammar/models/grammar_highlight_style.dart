enum GrammarHighlightStyle {
  subtleBackground,
  underline,
  outline,
  bold,
  mixed,
}

extension GrammarHighlightStyleInfo on GrammarHighlightStyle {
  String get labelVi {
    switch (this) {
      case GrammarHighlightStyle.subtleBackground:
        return 'Nền nhẹ';
      case GrammarHighlightStyle.underline:
        return 'Gạch dưới';
      case GrammarHighlightStyle.outline:
        return 'Viền';
      case GrammarHighlightStyle.bold:
        return 'Đậm';
      case GrammarHighlightStyle.mixed:
        return 'Hỗn hợp';
    }
  }
}
