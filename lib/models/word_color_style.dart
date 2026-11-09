// lib/models/word_color_style.dart
//
// READ-WORDSTYLE-001 (owner 2026-10-25): "cho phép người dùng chọn cách hiển
// thị các từ — ví như có người chỉ muốn đổi màu chữ thôi thay vì có màu nền để
// nhìn nó được đơn giản hơn, để khi đọc hay xem không bị phân tâm bởi màu sắc
// quá thì vẫn có thể điều chỉnh được ở setting."
//
// Trước đây chế độ tô màu trong tab Đọc CHỈ có một kiểu: mỗi từ một ô có NỀN
// màu (alpha ~0.12) + chữ màu. Với người đọc lâu, nền màu dày đặc làm mắt mỏi
// và phân tán. Nay có 3 kiểu, độc lập với việc chọn *màu gì* (loại từ / CEFR /
// độ khó):
//
//   • [fill]      — NỀN màu + chữ màu.
//   • [textOnly]  — CHỈ đổi màu chữ, không nền, không viền.
//   • [underline] — chữ thường + GẠCH CHÂN màu (nhẹ nhất, kiểu sách giấy).
//
// Enum thuần Dart (không import Flutter) để dùng được ở model/service/test mà
// không kéo widget tree vào.

/// Kiểu hiển thị của một từ khi bật tô màu trong tab Đọc.
enum WordColorStyle {
  fill,
  textOnly,
  underline;

  /// Khoá lưu bền trong `SharedPreferences` (giữ tên cũ khi đổi enum).
  String get storageKey => name;

  /// Nhãn tiếng Việt nguồn — UI dịch qua `context.uiText(...)`.
  String get label {
    switch (this) {
      case WordColorStyle.fill:
        return 'Nền màu';
      case WordColorStyle.textOnly:
        return 'Chỉ màu chữ';
      case WordColorStyle.underline:
        return 'Gạch chân';
    }
  }

  /// Mô tả ngắn cho màn Cài đặt.
  String get description {
    switch (this) {
      case WordColorStyle.fill:
        return 'Mỗi từ một ô nền màu — dễ thấy nhất khi lướt nhanh.';
      case WordColorStyle.textOnly:
        return 'Không nền, chỉ đổi màu chữ — dịu mắt khi đọc lâu.';
      case WordColorStyle.underline:
        return 'Chữ giữ màu gốc, gạch chân màu — nhẹ nhất, ít phân tâm.';
    }
  }

  static WordColorStyle fromStorage(String? value) {
    for (final style in WordColorStyle.values) {
      if (style.name == value) return style;
    }
    return WordColorStyle.textOnly;
  }
}
