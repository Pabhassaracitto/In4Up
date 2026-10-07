// READ-SELECT-002 — luật chọn nhiều từ ở chế độ ô chữ của tab Đọc.
//
// Vì sao có file này (audit 0.10.3 mục 1.e: "chọn nhiều từ thường thất bại —
// chạm thì phát âm, giữ thì ra việc khác"): ở chế độ tô màu/IPA mỗi từ là một
// `GestureDetector` riêng, KHÔNG có `SelectableText` ⇒ bôi chọn nhiều từ là
// bất khả thi chứ không phải lỗi ngẫu nhiên.
//
// Cách chữa: GIỮ một từ ⇒ vào chế độ chọn (từ đó là mỏ neo), kéo ngang hoặc
// chạm từ thứ hai ⇒ mở rộng vùng chọn liên tục. Toàn bộ phần "gộp khoảng chọn
// thành chữ + offset" nằm ở đây để test thuần (không cần dựng widget tree);
// widget chỉ còn việc bắt thao tác tay và gọi [ReadTextActionRunner] đúng một
// đường xử lý duy nhất (READ-ACT-001).

import 'dart:ui' show Offset, Rect;

import '../../../models/word_analysis.dart';

/// Khoảng chọn từ trong MỘT dòng, tính theo chỉ số từ (bao gồm cả hai đầu).
///
/// [anchorIndex] là mỏ neo (từ người dùng giữ) — không đổi khi kéo; mở rộng
/// chỉ đổi [focusIndex]. Nhờ vậy, kéo ngược qua mỏ neo vẫn ra đúng khoảng.
class WordRange {
  const WordRange({required this.anchorIndex, required this.focusIndex});

  final int anchorIndex;
  final int focusIndex;

  int get start => anchorIndex <= focusIndex ? anchorIndex : focusIndex;
  int get end => anchorIndex <= focusIndex ? focusIndex : anchorIndex;
  int get length => end - start + 1;

  bool contains(int wordIndex) =>
      wordIndex >= start && wordIndex <= end;

  /// Cùng mỏ neo, đầu kéo mới — thao tác mở rộng duy nhất.
  ///
  /// KHÔNG kẹp biên (không biết số từ): luôn đi qua [resolveWordRange] khi
  /// chỉ số đến từ thao tác tay.
  WordRange extendTo(int wordIndex) =>
      WordRange(anchorIndex: anchorIndex, focusIndex: wordIndex);

  @override
  String toString() => 'WordRange($start..$end, anchor=$anchorIndex)';
}

/// Chuỗi đã ghép + khoảng offset trong nội dung dòng.
///
/// [text] là thứ đưa cho [ReadTextActionRunner] (`selectedText`); offset dùng
/// để ghi vào `TextProvider.selectTextWithOffsets(...)` — phần còn lại của
/// app (lưu từ, ngữ pháp, dịch, nút ở header) nhìn thấy như một selection thật.
class WordSelectionText {
  const WordSelectionText({
    required this.text,
    required this.startOffset,
    required this.endOffset,
  });

  final String text;
  final int startOffset;
  final int endOffset;

  @override
  String toString() =>
      'WordSelectionText("$text", $startOffset..$endOffset)';
}

/// Kẹp khoảng chọn vào `[0, wordCount)`.
///
/// Trả `null` khi không có từ nào (dòng rỗng) hoặc hai chỉ số không hợp lệ —
/// widget coi như không vào chế độ chọn, thay vì giữ một vùng chọn rỗng.
WordRange? resolveWordRange({
  required int? anchorIndex,
  required int? focusIndex,
  required int wordCount,
}) {
  if (wordCount <= 0) return null;
  final anchor = anchorIndex;
  if (anchor == null || anchor < 0 || anchor >= wordCount) return null;
  final rawFocus = focusIndex ?? anchor;
  final focus = rawFocus < 0
      ? 0
      : rawFocus >= wordCount
          ? wordCount - 1
          : rawFocus;
  return WordRange(anchorIndex: anchor, focusIndex: focus);
}

/// Gộp các từ `start..end` thành chuỗi để xử lý + offset trong [lineContent].
///
/// * `text` = các từ nối bằng ĐÚNG một dấu cách (giống `TextProvider` khi
///   `speak`/dịch một cụm).
/// * `startOffset` = vị trí từ đầu tiên trong dòng (tìm theo chữ; không thấy
///   thì rơi về 0 — cùng cách chịu lỗi như `ReadTextActionRunner`).
/// * `endOffset` = hết từ cuối cùng.
WordSelectionText? buildWordSelectionText({
  required List<AnalyzedWord> words,
  required int start,
  required int end,
  required String lineContent,
}) {
  if (words.isEmpty) return null;
  if (start < 0 || end < start || end >= words.length) return null;

  final selected = <String>[
    for (var i = start; i <= end; i++) words[i].word,
  ];
  final text = selected.join(' ');
  if (text.trim().isEmpty) return null;

  final firstWord = words[start].word;
  var startOffset = firstWord.isEmpty ? -1 : lineContent.indexOf(firstWord);
  if (startOffset < 0) startOffset = 0;

  final lastWord = words[end].word;
  var endOffset = lastWord.isEmpty ? -1 : lineContent.lastIndexOf(lastWord);
  if (endOffset < 0) {
    endOffset = startOffset + text.length;
  } else {
    endOffset += lastWord.length;
  }
  if (endOffset < startOffset) endOffset = startOffset + text.length;

  return WordSelectionText(
    text: text,
    startOffset: startOffset,
    endOffset: endOffset,
  );
}

/// Từ nào đang nằm dưới một điểm chạm/kéo?
///
/// Thuần hình học (không cần widget tree): [boxes] là hình chữ nhật của từng
/// từ theo đúng thứ tự từ trong dòng (`null` = chưa đo được, bỏ qua — không
/// được coi là hình ở gốc toạ độ). Ưu tiên hình chứa điểm; nếu con trỏ đã ra
/// ngoài mọi từ (kéo quá mép), lấy từ GẦN NHẤT để vùng chọn vẫn mở rộng liên
/// tục thay vì đứng im.
int? wordIndexAtPoint({
  required List<Rect?> boxes,
  required Offset point,
}) {
  if (boxes.isEmpty) return null;
  int? nearest;
  double nearestDistance = double.infinity;
  for (var i = 0; i < boxes.length; i++) {
    final rect = boxes[i];
    if (rect == null) continue;
    if (rect.contains(point)) return i;
    final distance = _distanceToRect(rect, point);
    if (distance < nearestDistance) {
      nearestDistance = distance;
      nearest = i;
    }
  }
  return nearest;
}

double _distanceToRect(Rect rect, Offset point) {
  final dx = point.dx < rect.left
      ? rect.left - point.dx
      : point.dx > rect.right
          ? point.dx - rect.right
          : 0.0;
  final dy = point.dy < rect.top
      ? rect.top - point.dy
      : point.dy > rect.bottom
          ? point.dy - rect.bottom
          : 0.0;
  return dx * dx + dy * dy;
}

/// Ô chữ nào đang ở chế độ chọn nhiều từ?
///
/// Chỉ có MỘT vùng chọn sống tại một thời điểm. Tầng dòng
/// (`text_line_widget.dart`) hỏi biến này để biết "chạm ra ngoài" phải BỎ CHỌN
/// thay vì chạy tiếp thao tác chạm dòng (đọc dòng/seek audio).
class WordSelectionState {
  WordSelectionState._();

  static int? activeLineIndex;

  static bool get isActive => activeLineIndex != null;

  static void activate(int lineIndex) => activeLineIndex = lineIndex;

  static void deactivate() => activeLineIndex = null;
}
