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
        return 'Content';
      case GrammarHighlightStyle.underline:
        return 'Content';
      case GrammarHighlightStyle.outline:
        return 'Content';
      case GrammarHighlightStyle.bold:
        return 'Content';
      case GrammarHighlightStyle.mixed:
        return 'Content';
    }
  }
}