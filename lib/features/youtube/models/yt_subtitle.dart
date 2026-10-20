// YT-LR-002 — Model phụ đề / từ vựng của chế độ học YouTube.
//
// Tách từ `yt_player_screen.dart` (presentation file) sang `models/` để widget
// bảng tra từ (`widgets/yt_word_panel.dart`) dùng được mà không tạo import
// vòng với màn hình chính.
//
// LƯU Ý i18n: file này KHÔNG phải presentation file nên gate
// `tool/generate_legacy_ui_fallbacks.py` không quét literal ở đây. Vì vậy không
// được chứa nhãn tiếng Việt hiển thị ra UI — mọi nhãn nằm ở call-site
// `uiText()` trong widget.

import 'package:flutter/material.dart';

// ─── Word knowledge state ─────────────────────────────────
enum WordState { unknown, known, learning, ignored }

class LrWord {
  final String text;
  final String type; // noun, verb, adj, adv, prep, conj, other
  final int langRank;
  WordState state;

  LrWord({
    required this.text,
    required this.type,
    required this.langRank,
    this.state = WordState.unknown,
  });

  Color get typeColor {
    switch (type) {
      case 'verb':
        return const Color(0xFF4CAF50); // xanh lá
      case 'noun':
        return const Color(0xFFFF9800); // cam
      case 'proper':
        return const Color(0xFF9C27B0); // tím
      case 'adj':
        return const Color(0xFF2196F3); // xanh
      case 'adv':
        return const Color(0xFFFFCA28); // vàng
      case 'prep':
      case 'conj':
        return const Color(0xFF78909C); // xám
      default:
        return Colors.white;
    }
  }

  // Nhãn từ loại KHÔNG nằm ở file model này: gate i18n
  // (`tool/generate_legacy_ui_fallbacks.py`) chỉ quét literal trong file
  // presentation, nên nhãn phải nằm ở call-site của `uiText()` — xem
  // `_typeLabel` trong `widgets/yt_word_panel.dart`.
}

// ─── Subtitle line ────────────────────────────────────────
class SubtitleLine {
  final Duration start;
  final Duration end;
  final String text;
  final String? translation;

  /// Văn bản GỐC của dòng (khi track là "rolling window" thì [text] chỉ là
  /// phần MỚI, còn [fullText] là cả cửa sổ). Dùng cho tab VĂN BẢN.
  final String fullText;

  final List<LrWord> words;

  SubtitleLine({
    required this.start,
    required this.end,
    required this.text,
    this.translation,
    String? fullText,
    required this.words,
  }) : fullText = fullText ?? text;
}
