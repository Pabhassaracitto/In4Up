// lib/features/pdf_reader/services/pdf_geometry.dart
//
// HÌNH HỌC PDF READER — nguồn sự thật duy nhất cho việc quy đổi toạ độ.
//
// Quy ước của repo (KHÔNG đổi, vì `VocabContext.rectHint` và
// `PdfAnnotation.bounds` đang được lưu theo quy ước này, `Evidence.locator`
// của module knowledge cũng vậy):
//
//   một `Rect` "PDF space" ở đây = PdfRect của pdfrx chép nguyên vào:
//     left / right : x tăng sang phải
//     top          : y LỚN hơn  (đỉnh chữ — PDF có gốc dưới-trái, y hướng lên)
//     bottom       : y NHỎ hơn  (đáy chữ)
//
//   Hệ quả: `Rect.height = bottom - top` là SỐ ÂM và `Rect.contains(...)` luôn
//   trả về false. Code cũ dùng đúng hai thứ đó (vẽ highlight, hit-test chạm)
//   nên highlight bị lật ngược, còn chạm-vào-từ chỉ "ăn" nhờ nhánh tìm-gần-nhất.
//   Mọi chỗ cần kích thước thật phải đi qua các hàm dưới đây.
//
// `PdfRect(left, top, right, bottom)` của engine assert `top >= bottom` — cùng
// quy ước, nên không cần chuyển đổi khi gọi `goToRectInsidePage`.
//
// (dòng này chỉ để commit probe chạm `lib/**` — xem 5.7 trong
// docs/skills/ci-red-debugging: workflow chỉ chạy khi paths filter khớp)
import 'dart:math' as math;
import 'dart:ui' show Rect, Size;

/// Chiều cao dương của một rect ở không gian PDF.
double pdfRectHeight(Rect r) => r.top - r.bottom;

/// `true` nếu rect có hình học PDF hợp lệ (top >= bottom, right >= left).
bool isPdfSpaceRect(Rect r) =>
    r != Rect.zero && r.top >= r.bottom && r.right >= r.left;

/// `true` nếu rect còn vẽ được: khác 0, rộng > 0 và CAO ĐỘ KHÁC 0.
///
/// Không hỏi chiều y: dữ liệu cũ có thể mang rect `top > bottom` (đúng quy ước
/// PDF) hoặc `top < bottom`; cả hai đều phải được quy đổi thay vì bị loại
/// (rect bị loại = highlight biến mất, là bug gốc của lớp này).
bool isPaintablePdfRect(Rect r) =>
    r != Rect.zero &&
    r.right > r.left &&
    (r.top - r.bottom).abs() > 0;

/// Quy đổi rect từ không gian PDF của trang sang không gian nhìn (px, gốc
/// trên-trái của vùng vẽ trang).
///
/// Dùng min/max cho hai cạnh y nên hàm đúng với cả hai chiều lưu; degenerate
/// (height = 0) trả `Rect.zero` để caller bỏ qua thay vì đưa chiều âm vào
/// `Positioned`.
Rect pdfRectToViewerRect(
  Rect pdfRect, {
  required double pageHeight,
  required double scaleX,
  required double scaleY,
}) {
  if (pdfRect == Rect.zero) return Rect.zero;
  final yHigh = math.max(pdfRect.top, pdfRect.bottom);
  final yLow = math.min(pdfRect.top, pdfRect.bottom);
  final height = yHigh - yLow;
  if (height <= 0 || pdfRect.right <= pdfRect.left) return Rect.zero;
  return Rect.fromLTWH(
    pdfRect.left * scaleX,
    (pageHeight - yHigh) * scaleY,
    pdfRect.width * scaleX,
    height * scaleY,
  );
}

/// Hệ số phóng của trang trong viewer (px trên một đơn vị PDF).
({double x, double y}) pageScaleFactors({
  required double pageWidth,
  required double pageHeight,
  required Size pageViewSize,
}) {
  if (pageWidth <= 0 || pageHeight <= 0) return (x: 1, y: 1);
  return (x: pageViewSize.width / pageWidth, y: pageViewSize.height / pageHeight);
}
