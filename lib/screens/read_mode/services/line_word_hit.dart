// lib/screens/read_mode/services/line_word_hit.dart
//
// PSRC-234 — tab Đọc, dòng KHÔNG bật "box từng từ": chạm một từ vẫn phải ra
// đúng từ đó (đọc + pop tra nhanh), chạm đúp ra nguyên dòng (đọc + dịch).
//
// Vì sao phải có file này: dòng không có ô từng từ được vẽ bằng MỘT đoạn chữ
// (một `RichText`), nên cử chỉ chỉ trả về TOẠ ĐỘ ĐIỂM CHẠM. Muốn biết "chạm
// vào từ nào" phải đi qua hai bước:
//
//   1. điểm chạm → chỉ số ký tự trong dòng: do `RenderParagraph`
//      (`getPositionForOffset`) làm, phải có widget tree nên nằm ở widget;
//   2. chỉ số ký tự → từ: phép tính THUẦN trên chuỗi, nằm ở đây để test được
//      mà không cần `flutter_test` dựng cây widget — cùng kiểu với
//      `word_range_selection.dart` (READ-SELECT-002).
//
// Luật ghép từ vào nội dung GIỮ NGUYÊN như `_coloredSpans` và
// `_openWordAtSelection` cũ của `text_line_widget.dart`: duyệt `analyzedWords`
// theo thứ tự, `indexOf(word, cursor)`. Nhờ vậy tô màu, chạm từ và menu
// "Chi tiết từ" luôn chỉ về CÙNG một chỗ trong câu, kể cả khi trong dòng có
// từ lặp lại ("the … the").

import 'dart:ui' show Offset;

/// Một từ đã quy ra khoảng ký tự `[start, end)` trong nội dung dòng.
class LineWordSpan {
  const LineWordSpan({
    required this.wordIndex,
    required this.start,
    required this.end,
  });

  /// Chỉ số của từ trong `analyzedWords` — KHÔNG phải vị trí của nó trong
  /// danh sách span (từ không tìm thấy trong nội dung bị bỏ qua).
  final int wordIndex;

  /// Chỉ số ký tự bắt đầu (tính từ đầu dòng).
  final int start;

  /// Chỉ số ký tự kết thúc, KHÔNG gồm ký tự này (`end - start = length`).
  final int end;

  int get length => end - start;

  /// Điểm chạm rơi ĐÚNG vào từ này? Gồm cả hai đầu: `RenderParagraph` trả về
  /// vị trí CHÈN ký tự, nên chạm nửa phải của ký tự cuối trong từ cho ra
  /// `offset == end` — vẫn phải tính là chạm từ đó, nếu không người dùng phải
  /// chạm lệch sang trái mới ăn.
  bool contains(int charOffset) => charOffset >= start && charOffset <= end;

  /// Khoảng cách (theo số ký tự) từ [charOffset] tới từ này; 0 nếu nằm trong.
  double distanceTo(int charOffset) {
    if (charOffset < start) return (start - charOffset).toDouble();
    if (charOffset > end) return (charOffset - end).toDouble();
    return 0;
  }

  @override
  String toString() => 'LineWordSpan(#$wordIndex, $start..$end)';
}

/// Ghép danh sách từ đã phân tích vào nội dung dòng.
///
/// * Từ không tìm thấy trong nội dung (phân tích lệch, dòng đã bị sửa) bị BỎ
///   QUA — không tạo span rỗng ở gốc toạ độ.
/// * Không bao giờ tạo hai span chồng nhau: con trỏ luôn nhảy tới cuối từ vừa
///   khớp.
List<LineWordSpan> buildLineWordSpans({
  required String content,
  required List<String> words,
}) {
  if (content.isEmpty || words.isEmpty) return const <LineWordSpan>[];

  final spans = <LineWordSpan>[];
  var cursor = 0;
  for (var i = 0; i < words.length; i++) {
    final word = words[i];
    if (word.isEmpty) continue;
    final start = content.indexOf(word, cursor);
    if (start < 0) continue;
    final end = start + word.length;
    spans.add(LineWordSpan(wordIndex: i, start: start, end: end));
    cursor = end;
  }
  return spans;
}

/// Từ nằm dưới con trỏ ký tự [charOffset].
///
/// Ưu tiên từ chứa [charOffset]; nếu con trỏ rơi vào khoảng trắng/dấu câu
/// giữa hai từ thì lấy từ GẦN NHẤT — chạm vào dòng là phải ra một từ, không
/// được "câm" chỉ vì trúng dấu cách (khác với bôi chọn, chỗ đó mới cần chính
/// xác tuyệt đối). `null` chỉ khi dòng không có từ nào ghép được.
int? wordIndexAtCharOffset({
  required List<LineWordSpan> spans,
  required int charOffset,
}) {
  if (spans.isEmpty) return null;

  LineWordSpan? nearest;
  var nearestDistance = double.infinity;
  for (final span in spans) {
    if (span.contains(charOffset)) return span.wordIndex;
    final distance = span.distanceTo(charOffset);
    if (distance < nearestDistance) {
      nearestDistance = distance;
      nearest = span;
    }
  }
  return nearest?.wordIndex;
}

/// Span của từ có chỉ số [wordIndex] (null nếu từ đó không ghép được vào dòng).
LineWordSpan? lineWordSpanFor({
  required List<LineWordSpan> spans,
  required int wordIndex,
}) {
  for (final span in spans) {
    if (span.wordIndex == wordIndex) return span;
  }
  return null;
}

/// Bộ phân biệt "chạm một lần" và "chạm đúp" cho dòng chữ một khối.
///
/// Vì sao không dùng `GestureDetector(onTap:, onDoubleTap:)`: khi có
/// `onDoubleTap` ở cùng cây, `DoubleTapGestureRecognizer` GIỮ gesture arena
/// tới hết `kDoubleTapTimeout` ⇒ chạm một lần bị trễ ~300 ms mới phát âm. Với
/// tab Đọc, "chạm từ là nghe ngay" là phản xạ chính — không được trễ. Nên:
/// chạm một lần chạy NGAY, và nếu 300 ms sau có cú chạm thứ hai ở cùng chỗ thì
/// cú thứ hai nâng cấp thành thao tác cả dòng (pop từ của cú đầu bị đóng lại).
///
/// Đồng hồ được TRUYỀN VÀO ([at]) để test thuần không phải chờ thật.
class LineTapClassifier {
  LineTapClassifier({
    this.doubleTapWindow = const Duration(milliseconds: 300),
    this.maxDistance = 24,
  });

  /// Hai cú chạm cách nhau quá khoảng này ⇒ hai lần chạm rời.
  final Duration doubleTapWindow;

  /// Hai cú chạm lệch nhau quá bán kính này (logical pixel) ⇒ hai lần chạm rời
  /// (người dùng chạm hai từ khác nhau thật nhanh, không phải nhấp đúp).
  final double maxDistance;

  DateTime? _lastTapAt;
  Offset? _lastTapPosition;

  /// Ghi nhận MỘT cú chạm đã hoàn tất tại [position].
  ///
  /// Trả `true` nếu đây là cú thứ hai của một cú nhấp đúp (và tự xoá trạng
  /// thái để cú thứ ba lại là "chạm một lần").
  bool registerTap({required Offset position, required DateTime at}) {
    final lastAt = _lastTapAt;
    final lastPosition = _lastTapPosition;

    final isDouble = lastAt != null &&
        lastPosition != null &&
        at.difference(lastAt) <= doubleTapWindow &&
        (position - lastPosition).distance <= maxDistance;

    if (isDouble) {
      reset();
      return true;
    }

    _lastTapAt = at;
    _lastTapPosition = position;
    return false;
  }

  /// Quên cú chạm vừa rồi (dòng đổi nội dung, widget bị dựng lại…).
  void reset() {
    _lastTapAt = null;
    _lastTapPosition = null;
  }
}
