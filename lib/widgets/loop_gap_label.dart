// lib/widgets/loop_gap_label.dart
//
// AUDIT v1.30.1 (mục 7) — «ô khoảng lặng của lặp AB: khi chọn chỉ tô vàng và
// xổ xuống đóng lên, chữ/biểu tượng không đổi theo giá trị».
//
// Nguyên nhân gốc: nhãn chip preset và badge đều in `toInt()`, trong khi slider
// chia 20 khoảng trên 0–10s (bước 0.5s) ⇒ chọn 1.5s hiện «1s», 2.5s hiện «2s»,
// 0.5s hiện «0s»/«Tắt». Người dùng thấy "đã chọn mà chữ không đổi" vì hai giá
// trị lẻ liền nhau ra cùng một nhãn.
//
// Tách thành file thuần để test bằng Dart thường: `ab_loop_controls.dart`
// import `media_export_actions` (plugin) nên không chạy được trên host VM.

/// Nhãn cho một giá trị khoảng lặng: `0.5s`, `1s`, `1.5s`, `3s`…
///
/// Bỏ `.0` của số nguyên cho gọn (`1s` thay vì `1.0s`) nhưng GIỮ phần lẻ —
/// giữ phần lẻ chính là chỗ sửa lỗi trên.
String formatGapDurationLabel(double seconds) {
  if (seconds.isNaN || seconds.isInfinite) return '0s';
  final rounded = (seconds * 10).round() / 10;
  final text =
      rounded == rounded.roundToDouble() ? '${rounded.toInt()}' : '$rounded';
  return '${text}s';
}

/// Nhãn badge của ô «Khoảng lặng»: `0` ⇒ «Tắt», còn lại dùng
/// [formatGapDurationLabel].
///
/// Để riêng một hàm vì badge và chip preset trước đây lệch nhau (badge in
/// `toStringAsFixed(1)` = «1.5s», chip in `toInt()` = «1s») — nay cả hai đi qua
/// đây nên không thể lệch lại.
String formatGapDurationBadge(double seconds) {
  if (seconds <= 0) return 'off';
  return formatGapDurationLabel(seconds);
}
