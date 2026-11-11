// lib/screens/memory_mode/models/rating_gate.dart
//
// PSRC-197 — "SRS Cram Hard: cho chấm điểm không cần lật thẻ".
//
// Trước đây flashcard chặn mọi thao tác chấm điểm (nút + vuốt) cho tới khi
// người học lật thẻ xem nghĩa (trừ vuốt xuống = hoãn học). Với chế độ nhồi
// (Cram) điều đó làm đứt nhịp: người đã nhớ nghĩa vẫn bị bắt lật rồi mới
// chấm. Hai chỗ chặn (nút dưới thẻ và `_commitSwipe`) nay đi qua CÙNG một
// quyết định thuần Dart dưới đây để không lệch nhau lần nữa.
//
// Quy tắc:
//   • `allowRateBeforeFlip == true` (mặc định) → chấm được ngay, nghĩa vẫn ẩn.
//   • `allowRateBeforeFlip == false` → giữ nguyên kỷ luật cũ: phải lật trước.
//   • Vuốt XUỐNG (hoãn học) luôn được phép vì nó không phải là một câu trả
//     lời về trí nhớ.

import 'review_session.dart';

class RatingGate {
  const RatingGate._();

  /// Người học có được chấm điểm thẻ này ngay bây giờ không?
  static bool allowsRating({
    required bool isFlipped,
    required bool allowRateBeforeFlip,
  }) =>
      isFlipped || allowRateBeforeFlip;

  /// Có được commit một cú vuốt theo hướng [direction] không?
  ///
  /// Hoãn học (xuống) không tiết lộ/khẳng định gì về trí nhớ nên luôn hợp lệ,
  /// kể cả khi thẻ chưa lật — giữ đúng hành vi cũ.
  static bool allowsSwipe({
    required bool isFlipped,
    required SwipeDirection direction,
    required bool allowRateBeforeFlip,
  }) {
    if (direction == SwipeDirection.down) return true;
    return allowsRating(
      isFlipped: isFlipped,
      allowRateBeforeFlip: allowRateBeforeFlip,
    );
  }
}
