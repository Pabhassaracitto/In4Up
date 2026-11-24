import 'package:flutter/material.dart';

/// Unified 3-tier corner radius scale across controls, cards, and sheets.
abstract final class AppRadius {
  static const double control = 10.0;
  static const double card = 16.0;
  static const double sheet = 24.0;
  static const double pill = 999.0;

  static final BorderRadius controlBorder = BorderRadius.circular(control);
  static final BorderRadius cardBorder = BorderRadius.circular(card);
  static final BorderRadius sheetTopBorder = const BorderRadius.vertical(
    top: Radius.circular(sheet),
  );
}
