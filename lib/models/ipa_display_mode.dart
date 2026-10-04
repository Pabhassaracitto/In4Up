// lib/models/ipa_display_mode.dart
import 'package:flutter/material.dart';

/// Chế độ hiển thị phiên âm IPA trong Read Mode.
///
/// Tách khỏi [ColorMode]: ColorMode tô màu chữ gốc theo POS/CEFR/…,
/// còn IPA là lớp phiên âm riêng xếp chồng dưới dòng — không tô chữ.
/// (ADR-0005)
enum IpaDisplayMode {
  /// Ẩn (mặc định)
  hidden,

  /// Chỉ dòng đang phát / dòng hiện tại
  activeLine,

  /// Toàn bộ văn bản
  all;

  /// Nhãn UI (vi) — dịch qua `context.uiText(label)`.
  String get label {
    switch (this) {
      case IpaDisplayMode.hidden:
        return 'Tắt';
      case IpaDisplayMode.activeLine:
        return 'Dòng hiện tại';
      case IpaDisplayMode.all:
        return 'Toàn văn bản';
    }
  }

  IconData get icon {
    switch (this) {
      case IpaDisplayMode.hidden:
        return Icons.abc;
      case IpaDisplayMode.activeLine:
        return Icons.title;
      case IpaDisplayMode.all:
        return Icons.subject;
    }
  }

  /// Cycle: Tắt → Dòng hiện tại → Toàn văn bản → Tắt …
  IpaDisplayMode get next {
    final values = IpaDisplayMode.values;
    return values[(index + 1) % values.length];
  }
}
