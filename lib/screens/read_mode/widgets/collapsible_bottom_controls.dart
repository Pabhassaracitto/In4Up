// lib/screens/read_mode/widgets/collapsible_bottom_controls.dart
//
// Wrapper gập/ẩn thanh đáy tab Đọc (SmartPlaybackBar + ReadBottomBar).
// Tách khỏi `read_mode_screen.dart` để có seam test được (lane A4 —
// BATCH-0915).
//
// READ-TOOLBAR-001: thanh đáy "đen thui nhưng vẫn che chữ" khi cuộn trên một
// số GPU Android (Mali/Adreno). Nghi phạm theo card: cụm layer `ClipRect` +
// `AnimatedSlide` offset phân số (0, 1.2) + `AnimatedOpacity` chồng nhau bị
// render thành khối đen. Fix theo đúng thứ tự ít rủi ro của card:
//   1. BỎ `ClipRect` tường minh — trạng thái ẩn giờ không còn lớp nào vẽ ra
//      ngoài slot (offset đúng 1.0 chiều cao + opacity 0 → con bị dời hết ra
//      ngoài và không vẽ); khi Focus gập chiều cao, `RenderAnimatedSize` tự
//      clip hardEdge trong lúc animate size (verify source Flutter stable:
//      paint() pushClipRect khi `_hasVisualOverflow` — đã đọc
//      rendering/animated_size.dart).
//   2. Offset ẩn bị CHẶN ở (0, 1.0) — không overshoot > 1 chiều cao con
//      (offset phân số 1.2 tạo pixel vẽ ngoài vùng clip trên GPU yếu).
// Không đổi hành vi: smart-hide giữ nguyên chỗ layout (không nhảy chữ),
// Focus mode vẫn gập về 0 (hợp đồng READ-FOCUS-001).
// Nếu máy owner VẪN đen: bước kế tiếp theo card là thay AnimatedSize bằng
// build điều kiện (hy sinh animation gập) — xem KANBAN READ-TOOLBAR-001.
import 'package:flutter/material.dart';

class CollapsibleBottomControls extends StatelessWidget {
  const CollapsibleBottomControls({
    super.key,
    required this.visible,
    required this.collapsed,
    required this.child,
  });

  /// Smart-hide khi cuộn: `false` = ẩn (slide xuống + mờ đi, VẪN chiếm chỗ
  /// layout — tránh văn bản nhảy khi đọc).
  final bool visible;

  /// Focus mode: gập chiều cao về 0 (hợp đồng READ-FOCUS-001).
  final bool collapsed;

  final Widget child;

  /// Offset trạng thái ẩn. PHẢI ≤ 1.0 chiều cao con — overshoot phân số
  /// (1.2 cũ) là nghi phạm khối đen READ-TOOLBAR-001. Invariant được khoá
  /// bởi `test/read_bottom_controls_visibility_test.dart`.
  static const Offset hiddenOffset = Offset(0, 1.0);

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: collapsed
          ? const SizedBox(width: double.infinity, height: 0)
          // KHÔNG bọc ClipRect ở đây nữa (fix #1 READ-TOOLBAR-001): một lớp
          // clip/saveLayer ít chồng lên opacity layer trên GPU yếu.
          : AnimatedSlide(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              offset: visible ? Offset.zero : hiddenOffset,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: visible ? 1.0 : 0.0,
                child: child,
              ),
            ),
    );
  }
}
