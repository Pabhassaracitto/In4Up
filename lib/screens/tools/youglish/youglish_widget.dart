// lib/screens/tools/youglish/youglish_widget.dart
//
// PRON-001 (ADR-0015 D5): lớp VỎ. Toàn bộ logic WebView + dựng URL đã về
// `youglish_view.dart` (một nguồn sự thật). Giữ nguyên tên + API cũ để
// `youglish_screen.dart` (và mọi import lịch sử) không đổi; mã mới nên dùng
// thẳng `YouGlishView`.
//
// Trước PRON-001 file này tự tạo WebViewController + tự viết `_buildUrl()`,
// trùng với bản copy trong mini sheet cũ.

// localized_material = flutter/material (hide Text) + `context.uiText`.
import 'package:in4up/core/language/localized_material.dart';

import 'youglish_config.dart';
import 'youglish_view.dart';

class YouGlishWidget extends StatelessWidget {
  const YouGlishWidget({
    super.key,
    required this.word,
    this.language = YouGlishLanguage.english,
    this.accent = YouGlishAccent.us,
    this.height,
    this.autoPlay = true,
  });

  final String word;
  final YouGlishLanguage language;
  final YouGlishAccent? accent;

  /// `null` = fill parent.
  final double? height;
  final bool autoPlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: YouGlishView(
        word: word,
        language: language,
        accent: accent,
        autoplay: autoPlay,
        radius: 16,
        indicatorColor: const Color(0xFF6C63FF),
      ),
    );
  }
}
