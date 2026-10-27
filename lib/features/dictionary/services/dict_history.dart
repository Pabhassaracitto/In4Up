// DICT-HISTORY-001 — lịch sử tra từ của MÀN TỪ ĐIỂN (ADR-0018, P1).
//
// Tách phần THUẦN (danh sách + thứ tự + khử trùng) khỏi `SharedPreferences`
// để test được trên CI mà không cần plugin. Quy tắc:
//   - Từ mới tra lên ĐẦU;
//   - Không trùng (không phân biệt hoa/thường — `Book` và `book` là một);
//   - Khi trùng, giữ dạng CHỮ người dùng vừa tra (để hiển thị đúng như họ gõ);
//   - Giới hạn [maxItems] — mặc định 30, đủ dài để có ích, đủ ngắn để không
//     phình `SharedPreferences`.

class DictHistory {
  DictHistory._();

  /// Số từ nhớ tối đa.
  static const int defaultMaxItems = 30;

  /// Khoá lưu trong `SharedPreferences`.
  static const String prefsKey = 'dict_screen_history_v1';

  /// Chuẩn hoá từ để hiển thị: gộp khoảng trắng, cắt đầu/cuối.
  /// Trả rỗng nếu không có gì dùng được (đừng lưu rác vào lịch sử).
  static String normalize(String word) =>
      word.replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Khoá so sánh (không phân biệt hoa/thường).
  static String keyOf(String word) => normalize(word).toLowerCase();

  /// Thêm [word] vào đầu [current], khử trùng, cắt còn [maxItems].
  static List<String> add(
    List<String> current,
    String word, {
    int maxItems = defaultMaxItems,
  }) {
    final cleaned = normalize(word);
    if (cleaned.isEmpty || maxItems <= 0) {
      return List<String>.from(current);
    }
    final key = keyOf(cleaned);
    final next = <String>[cleaned];
    for (final item in current) {
      if (keyOf(item) == key) continue;
      if (next.length >= maxItems) break;
      final normalized = normalize(item);
      if (normalized.isEmpty) continue;
      next.add(normalized);
    }
    return next;
  }

  /// Bỏ một từ khỏi lịch sử (vuốt/nút xoá từng dòng).
  static List<String> remove(List<String> current, String word) {
    final key = keyOf(word);
    return <String>[
      for (final item in current)
        if (keyOf(item) != key) item,
    ];
  }

  /// Lọc lịch sử theo từ khoá đang gõ (màn hình hiện lịch sử khi ô tìm còn
  /// trống, và lọc khi người dùng gõ tiếp mà chưa có gợi ý từ từ điển).
  static List<String> matching(
    List<String> history,
    String query, {
    int limit = 8,
  }) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) {
      return history.take(limit).toList();
    }
    return <String>[
      for (final item in history)
        if (item.toLowerCase().contains(needle)) item,
    ].take(limit).toList();
  }
}
