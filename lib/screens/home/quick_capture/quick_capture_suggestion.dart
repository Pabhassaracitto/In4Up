// lib/screens/home/quick_capture/quick_capture_suggestion.dart
//
// HOME-QUICK-001 — nút "Gợi ý" ở card "Nạp tri thức nhanh".
//
// Lấy MỘT ENTRY THẬT từ WordList (không random text/ảnh giả):
//  * Ưu tiên thẻ đến kỳ ôn (SRS/FSRS của WordList — `WordEntry.isDue`,
//    xếp theo `daysUntilDue`); trong nhóm đến kỳ sớm nhất chọn ngẫu nhiên
//    để không lặp mãi một từ.
//  * Chưa có thẻ đến kỳ → chọn ngẫu nhiên trong toàn bộ WordList.
//  * WordList rỗng → null (UI hiện empty state có hướng dẫn).

import 'dart:math';

import '../../../models/word_entry.dart';

class QuickSuggestion {
  const QuickSuggestion({
    required this.entry,
    required this.dueForReview,
  });

  final WordEntry entry;

  /// `true` khi entry được chọn vì đến kỳ ôn.
  final bool dueForReview;

  String get word => entry.word.trim();
  String get phonetic => (entry.phonetic ?? '').trim();
  String get meaning => entry.meaning.trim();
  bool get hasMeaning => meaning.isNotEmpty;
  bool get hasPhonetic => phonetic.isNotEmpty;
}

/// Thuật toán chọn gợi ý (pure — test được với [Random] cố định).
class QuickSuggestionPicker {
  QuickSuggestionPicker._();

  /// Số thẻ đến kỳ sớm nhất được đưa vào "rổ" random.
  static const int duePoolSize = 5;

  static QuickSuggestion? pick({
    required List<WordEntry> entries,
    Random? random,
    int poolSize = duePoolSize,
  }) {
    final usable = entries
        .where((e) => e.word.trim().isNotEmpty)
        .toList(growable: false);
    if (usable.isEmpty) return null;

    final rnd = random ?? Random();

    final due = usable.where((e) => e.isDue).toList()
      ..sort((a, b) {
        final byDue = a.daysUntilDue.compareTo(b.daysUntilDue);
        if (byDue != 0) return byDue;
        // Cùng hạn → ít mastery hơn cần được nhắc trước.
        return a.mastery.compareTo(b.mastery);
      });

    if (due.isNotEmpty) {
      final limit = poolSize < 1 ? 1 : poolSize;
      final pool = due.take(limit).toList(growable: false);
      return QuickSuggestion(
        entry: pool[rnd.nextInt(pool.length)],
        dueForReview: true,
      );
    }

    return QuickSuggestion(
      entry: usable[rnd.nextInt(usable.length)],
      dueForReview: false,
    );
  }
}
