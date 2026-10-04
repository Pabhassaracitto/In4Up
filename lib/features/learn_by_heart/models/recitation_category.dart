// lib/features/learn_by_heart/models/recitation_category.dart

import 'package:flutter/material.dart';

/// Thể loại nội dung học thuộc lòng
enum RecitationCategory {
  /// Kinh Pháp Cú (Dhammapada)
  dhammapada,

  /// Kinh Tụng & Chân Ngôn (Daily Chanting / Mantras / Paritta)
  chanting,

  /// Đoạn Kinh Ý Nghĩa (Selected Suttas / Nikaya / Mahayana)
  sutta,

  /// Kệ Ngôn Trí Tuệ & Thơ Thiền (Gathas / Zen Verses)
  gatha,

  /// Nội Dung Tự Tạo / Cá Nhân (Custom Recitations)
  custom,
}

extension RecitationCategoryExtension on RecitationCategory {
  String get displayName {
    switch (this) {
      case RecitationCategory.dhammapada:
        return 'Kinh Pháp Cú';
      case RecitationCategory.chanting:
        return 'Kinh Tụng & Chân Ngôn';
      case RecitationCategory.sutta:
        return 'Đoạn Kinh Ý Nghĩa';
      case RecitationCategory.gatha:
        return 'Kệ Ngôn & Thơ Thiền';
      case RecitationCategory.custom:
        return 'Tự Tạo & Ghi Chú';
    }
  }

  IconData get icon {
    switch (this) {
      case RecitationCategory.dhammapada:
        return Icons.menu_book_rounded;
      case RecitationCategory.chanting:
        return Icons.record_voice_over_rounded;
      case RecitationCategory.sutta:
        return Icons.auto_stories_rounded;
      case RecitationCategory.gatha:
        return Icons.spa_rounded;
      case RecitationCategory.custom:
        return Icons.edit_note_rounded;
    }
  }

  Color get color {
    switch (this) {
      case RecitationCategory.dhammapada:
        return const Color(0xFFFFB300); // Amber / Vàng nghệ
      case RecitationCategory.chanting:
        return const Color(0xFF6C63FF); // Tím thanh tịnh
      case RecitationCategory.sutta:
        return const Color(0xFF26A69A); // Xanh lam ngọc
      case RecitationCategory.gatha:
        return const Color(0xFF81C784); // Xanh lá thiền
      case RecitationCategory.custom:
        return const Color(0xFF42A5F5); // Xanh dương
    }
  }
}
