// lib/models/read_content_source.dart
import 'package:flutter/material.dart';

/// Nguồn nội dung mà workspace Đọc có thể dùng.
///
/// Đây CHỈ là một lựa chọn kiểu dữ liệu (giống `ColorMode`, `IpaDisplayMode`)
/// — nó không biết cách mở màn hình/drawer tương ứng. Việc mở
/// `TextLibraryDrawer`, `WebReaderScreen`, `TipitakaLibraryScreen` thuộc về
/// callback do nơi dùng `ReadSourcePicker` truyền vào (xem
/// `lib/screens/read_mode/widgets/read_source_picker.dart`). Nhờ vậy widget
/// ở tầng UI không phải phụ thuộc ngược vào các màn hình đó, và một agent
/// tích hợp khác có thể nối dây thật mà không phải sửa lại tầng UX này.
///
/// Lưu ý: đây là Source (nguồn nội dung) — khác với Tool (Dịch / Ngữ pháp /
/// Phát âm / Từ điển) và khác với Mode (Đọc / Viết). Ba khái niệm này không
/// được trộn lẫn vào cùng một picker.
enum ReadContentSource {
  /// Tài liệu đã nhập/lưu trong máy (mở qua `TextLibraryDrawer`).
  document,

  /// Trang web đọc trực tiếp (mở qua `WebReaderScreen`).
  web,

  /// Kinh tạng Pali (mở qua `TipitakaLibraryScreen`).
  tipitaka;

  /// Nhãn UI (vi) — dịch qua `context.uiText(label)` tại nơi hiển thị.
  String get label {
    switch (this) {
      case ReadContentSource.document:
        return 'Tài liệu';
      case ReadContentSource.web:
        return 'Web';
      case ReadContentSource.tipitaka:
        return 'Tam tạng';
    }
  }

  IconData get icon {
    switch (this) {
      case ReadContentSource.document:
        return Icons.description_outlined;
      case ReadContentSource.web:
        return Icons.public;
      case ReadContentSource.tipitaka:
        return Icons.menu_book_outlined;
    }
  }
}
