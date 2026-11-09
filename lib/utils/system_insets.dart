// lib/utils/system_insets.dart
//
// SAFE-INSET-001 (2026-11-08) — chống hiện tượng "thanh nội dung / bottom bar
// chìm dưới thanh điều hướng của hệ thống" (Android gesture bar, 3-button nav,
// iOS home indicator).
//
// VÌ SAO CẦN: từ `targetSdk 35` (android/app/build.gradle.kts) Android 15 ép
// **edge-to-edge** — cửa sổ app vẽ TRÀN xuống dưới thanh điều hướng hệ
// thống.
// Bất kỳ widget nào neo bằng `Positioned(bottom: 0)` / `Padding(bottom: 84)`
// mà không cộng thêm vùng inset hệ thống sẽ bị **che một phần hoặc toàn bộ**.
// `Scaffold.bottomNavigationBar` thì Flutter tự chừa; nhưng thanh neo đáy tự
// dựng trong `Stack` (bar TTS của PDF, chú giải web reader, floating bar…)
// thì **KHÔNG** — phải tự cộng.
//
// QUY ƯỚC:
//   * Thanh/dock neo đáy ⇒ bọc `BottomSafeArea` (không tự viết SafeArea nữa,
//     để một nguồn sự thật duy nhất + test pin được).
//   * Widget `Positioned(bottom: N)` neo đáy ⇒ đổi `N` thành
//     `bottomInsetOffset(context, N)`.
//   * Padding đáy của nội dung để né thanh neo đáy ⇒ dùng `bottomInsetExtra`.
//
// Dùng `MediaQuery.paddingOf` (KHÔNG phải `viewPaddingOf`) cho khớp ngữ nghĩa
// của `SafeArea`: khi bàn phím mở, `padding.bottom` = 0 vì bàn phím đã phủ
// vùng thanh điều hướng, nên thanh neo đáy không bị đẩy lên 2 lần.

import 'package:flutter/widgets.dart';

/// Vùng chiếm đáy của thanh điều hướng hệ thống (0 nếu không có).
double systemBottomInset(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom;

/// Giá trị `bottom` cho `Positioned`: [base] + inset hệ thống, clamp ≥ 0.
double bottomInsetOffset(BuildContext context, [double base = 0]) {
  final value = base + systemBottomInset(context);
  return value < 0 ? 0 : value;
}

/// `EdgeInsets` đáy đã cộng inset hệ thống (giữ nguyên các cạnh khác).
EdgeInsets bottomInsetExtra(BuildContext context, EdgeInsets base) =>
    base + EdgeInsets.only(bottom: systemBottomInset(context));

/// Bọc thanh/dock neo đáy: luôn chừa đúng vùng thanh điều hướng hệ thống.
///
/// [minimum] — sàn tối thiểu (ví dụ 8 để thanh không dính sát mép trên
/// máy không có thanh điều hướng).
class BottomSafeArea extends StatelessWidget {
  const BottomSafeArea({
    super.key,
    required this.child,
    this.minimum = 0,
  });

  final Widget child;
  final double minimum;

  @override
  Widget build(BuildContext context) {
    final inset = systemBottomInset(context);
    final pad = inset > minimum ? inset : minimum;
    // Padding 0 vẫn trả về widget con nguyên vẹn (không tạo thêm layout layer
    // khi máy không có thanh điều hướng) — giữ chi phí bằng 0 ở trường hợp phổ
    // biến trên desktop/web.
    if (pad <= 0) return child;
    return Padding(
      padding: EdgeInsets.only(bottom: pad),
      child: child,
    );
  }
}
