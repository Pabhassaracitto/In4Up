// lib/screens/read_mode/widgets/collapsible_bottom_controls.dart
//
// Wrapper gập/ẩn thanh đáy tab Đọc (SmartPlaybackBar + ReadBottomBar).
// Tách khỏi `read_mode_screen.dart` để có seam test được (lane A4 —
// BATCH-0915).
//
// READ-TOOLBAR-001 (v2): thanh đáy "đen thui nhưng vẫn che chữ" khi cuộn trên
// một số GPU Android (Mali/Adreno).
//
// Owner AT sau v1 (commit 278a1d9 bỏ ClipRect + chặn offset ẩn 1.0):
//   "Khi kéo cuộn lên thì ẩn các icon chức năng… nhưng vẫn còn bị khối đen che chữ"
//
// Phân tích & nguyên nhân v1 chưa đủ:
//   - Icon ẩn đúng -> logic state/cuộn hoạt động đúng.
//   - Khối đen vẫn còn -> nghi phạm duy nhất còn lại là các widget ANIMATION
//     (`AnimatedSize`, `AnimatedSlide`, `AnimatedOpacity`). Trong đó, `AnimatedOpacity`
//     và `AnimatedSize` tạo `RenderOpacity` / layer clipping trung gian
//     (saveLayer với alpha biến thiên qua nhiều frame) khiến GPU Mali/Adreno render
//     thành khối đen (black rectangle).
//
// Fix v2 (theo đúng Bước 2 của card READ-TOOLBAR-001):
//   "Thay AnimatedSize bằng build điều kiện — hy sinh animation gập, giữ đúng chức năng"
//   Mở rộng nhất quán: LOẠI BỎ HẲN TOÀN BỘ widget animation (AnimatedSize,
//   AnimatedSlide, AnimatedOpacity, ClipRect) trên đường ẩn/hiện/gập:
//   1. Focus mode (`collapsed == true`): build điều kiện trả về
//      `SizedBox(width: double.infinity, height: 0)` — tức thì, gập về 0
//      (hợp đồng READ-FOCUS-001).
//   2. Smart-hide (`visible == false`): bọc trong `Opacity(opacity: 0)` kèm
//      `IgnorePointer(ignoring: true)` — theo cơ chế `RenderOpacity`, khi opacity = 0
//      nó skip paint hoàn toàn (không gọi child.paint, không tạo saveLayer rác);
//      đồng thời giữ nguyên chiều cao layout (không nhảy chữ khi đọc) và
//      không bắt tap của nút bên dưới.
//   3. Trạng thái hiện (`visible == true`): vẽ trực tiếp (opacity 1.0) không qua
//      bất kỳ layer animation hay clipping nào.
//
// Chấp nhận: ẩn/hiện/gập diễn ra tức thời (không còn hiệu ứng trượt/mờ).
import 'package:flutter/material.dart';

class CollapsibleBottomControls extends StatelessWidget {
  const CollapsibleBottomControls({
    super.key,
    required this.visible,
    required this.collapsed,
    required this.child,
  });

  /// Smart-hide khi cuộn: `false` = ẩn (opacity 0 + IgnorePointer, VẪN chiếm chỗ
  /// layout — tránh văn bản nhảy khi đọc).
  final bool visible;

  /// Focus mode: gập chiều cao về 0 (hợp đồng READ-FOCUS-001).
  final bool collapsed;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (collapsed) {
      return const SizedBox(width: double.infinity, height: 0);
    }

    return IgnorePointer(
      ignoring: !visible,
      child: Opacity(
        opacity: visible ? 1.0 : 0.0,
        child: child,
      ),
    );
  }
}
