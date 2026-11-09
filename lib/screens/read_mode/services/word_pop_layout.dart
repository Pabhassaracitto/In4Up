// lib/screens/read_mode/services/word_pop_layout.dart
//
// READ-POP-003 (owner 2026-10-25): pop tra từ trong tab Đọc phải "trồi lên như
// cung cấp thông tin nhanh", KHÔNG làm tối các phần khác và KHÔNG chặn chạm.
//
// Vì vậy pop là một OVERLAY không barrier (xem `word_mini_pop.dart`), đặt cạnh
// đúng từ vừa chạm. Phần tính vị trí tách riêng ở đây (hàm thuần, không dựng
// widget tree) để test được bằng `flutter test` không cần màn hình thật:
//
//   • ưu tiên đặt DƯỚI từ (đọc từ trên xuống vẫn thấy nghĩa);
//   • không đủ chỗ ⇒ đặt TRÊN từ;
//   • luôn kẹp trong màn hình (trừ safe-area) ⇒ không bao giờ tràn mép;
//   • trả `maxHeight` để pop tự cuộn bên trong thay vì tràn (RenderFlex
//     overflow = vạch vàng-đen trong app).

import 'dart:ui' show Offset, Rect, Size;

/// Hộp đặt pop đã tính xong: toạ độ theo hệ của chính overlay.
class WordPopPlacement {
  const WordPopPlacement({
    required this.left,
    required this.top,
    required this.width,
    required this.maxHeight,
    required this.below,
  });

  final double left;
  final double top;
  final double width;
  final double maxHeight;

  /// `true` = pop nằm DƯỚI từ (mặc định), `false` = phải lật lên TRÊN.
  final bool below;

  Offset get offset => Offset(left, top);

  @override
  String toString() =>
      'WordPopPlacement(left=$left, top=$top, w=$width, h<=$maxHeight, '
      'below=$below)';
}

/// Tính vị trí + kích thước tối đa cho pop của một từ.
///
/// [anchor] = hình chữ nhật của từ (toạ độ toàn cục của overlay).
/// [screen] = kích thước overlay (thường `MediaQuery.size`).
/// [padding] = chừa mép (mặc định 8).
/// [gap] = khoảng cách pop ↔ từ.
/// [maxWidth] = bề rộng mong muốn (pop hẹp như thẻ thông tin, không phải sheet).
WordPopPlacement computeWordPopPlacement({
  required Rect anchor,
  required Size screen,
  double padding = 8,
  double gap = 8,
  double maxWidth = 340,
  double preferredBelowHeight = 240,
  double preferredAboveHeight = 260,
}) {
  final width =
      (screen.width - padding * 2).clamp(180.0, maxWidth).toDouble();
  var left = anchor.left;
  if (left + width > screen.width - padding) {
    left = screen.width - padding - width;
  }
  if (left < padding) left = padding;

  final spaceBelow = screen.height - anchor.bottom - gap - padding;
  final spaceAbove = anchor.top - gap - padding;

  // Đủ chỗ cho một thẻ gọn ở dưới ⇒ đặt dưới. Không đủ ⇒ chọn bên rộng hơn.
  final bool below =
      spaceBelow >= preferredBelowHeight || spaceBelow >= spaceAbove;

  final double top;
  if (below) {
    top = anchor.bottom + gap;
  } else {
    final aboveSlot = spaceAbove.clamp(0.0, preferredAboveHeight).toDouble();
    top = (anchor.top - gap - aboveSlot)
        .clamp(padding, screen.height - padding)
        .toDouble();
  }

  // Chiều cao khả dụng phải tính từ ĐỈNH THẬT của pop (sau khi kẹp), không
  // phải toàn bộ khoảng trống của phía đó — nếu không, pop lật lên trên sẽ
  // tràn xuống dưới đáy màn hình (test "sát đáy" bắt đúng lỗi này).
  final maxHeight =
      (screen.height - padding - top).clamp(96.0, screen.height - padding * 2);
  return WordPopPlacement(
    left: left,
    top: top,
    width: width,
    maxHeight: maxHeight.toDouble(),
    below: below,
  );
}
