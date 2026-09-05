// lib/features/pdf_reader/services/pdf_word_hit_test.dart
//
// Hit-test "chạm vào từ nào" cho PDF Reader.
//
// Code cũ (`_WordTapDetector` trong pdf_reader_screen.dart) làm phép thử trong
// không gian PDF với bán kính cố định `dist < 20`, và gọi `word.bounds.contains()`
// — mà `contains` trên rect theo quy ước PDF (top > bottom) luôn trả về false
// (xem pdf_geometry.dart). Tức là thực chất người dùng chỉ đang được phục vụ bởi
// nhánh "tìm từ gần nhất", với một dung sai sai hoàn toàn khi zoom:
//   • zoom 40%  → 20 đơn vị PDF ≈ 8 px  → chạm hụt, phải rình từng chữ;
//   • zoom 300% → 20 đơn vị PDF = 3-4 từ → chạm nhầm từ bên cạnh.
//
// Bản này quy đổi về PIXEL của trang đang thấy và lấy cao độ chữ làm đơn vị
// dung sai → ổn định ở mọi mức zoom và mọi cỡ chữ.

import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import '../models/pdf_word_info.dart';
import 'pdf_geometry.dart';

class PdfWordHit {
  const PdfWordHit(this.word, this.viewRect, this.distancePx);

  final PdfWordInfo word;

  /// Rect của từ trong không gian nhìn — để vẽ vòng phản hồi, tính dung sai.
  final Rect viewRect;

  /// 0 khi chạm trúng thân chữ.
  final double distancePx;

  /// `true` khi chạm trúng hẳn trong thân chữ (không phải do nới dung sai).
  bool get isDirectHit => distancePx == 0;
}

/// Tìm từ gần [point] nhất. [point] là toạ độ cục bộ trong vùng nhìn của trang.
PdfWordHit? hitTestWord(
  List<PdfWordInfo> words, {
  required Offset point,
  required double pageWidth,
  required double pageHeight,
  required Size pageViewSize,
  double verticalTolerance = 0.45,
  double horizontalTolerance = 0.3,
  double maxMissDistanceFactor = 0.9,
}) {
  if (words.isEmpty || pageViewSize.width <= 0 || pageViewSize.height <= 0) {
    return null;
  }

  final scale = pageScaleFactors(
    pageWidth: pageWidth,
    pageHeight: pageHeight,
    pageViewSize: pageViewSize,
  );
  final scaleX = scale.x;
  final scaleY = scale.y;

  PdfWordHit? bestDirect;
  PdfWordHit? bestNear;
  var referenceHeight = 0.0;

  for (final word in words) {
    if (word.bounds == Rect.zero) continue;
    final rect = pdfRectToViewerRect(
      word.bounds,
      pageHeight: pageHeight,
      scaleX: scaleX,
      scaleY: scaleY,
    );
    if (rect.isEmpty) continue;
    if (referenceHeight <= 0 || rect.height > referenceHeight) {
      referenceHeight = rect.height;
    }

    if (rect.contains(point)) {
      final hit = PdfWordHit(word, rect, 0);
      if (bestDirect == null ||
          (point.dx - rect.center.dx).abs() <
              (point.dx - bestDirect.viewRect.center.dx).abs()) {
        bestDirect = hit;
      }
      continue;
    }

    final padY = math.max(1.5, rect.height * verticalTolerance);
    final padX = math.max(0.5, rect.width * horizontalTolerance);
    final expanded = Rect.fromLTRB(
      rect.left - padX,
      rect.top - padY,
      rect.right + padX,
      rect.bottom + padY,
    );
    if (!expanded.contains(point)) continue;

    final distance = _distanceToRect(rect, point);
    if (bestNear == null || distance < bestNear.distancePx) {
      bestNear = PdfWordHit(word, rect, distance);
    }
  }

  if (bestDirect != null) return bestDirect;
  if (bestNear != null) return bestNear;

  // Không có từ nào trong tầm nới → tìm gần nhất, nhưng chỉ trong dung sai theo
  // cao độ chữ: trang scan chữ nhỏ vẫn chạm được, trang zoom xa không ăn nhầm
  // từ ở dòng khác.
  final tolerance = math.max(
    10.0,
    (referenceHeight > 0 ? referenceHeight : 12.0) * maxMissDistanceFactor,
  );
  PdfWordHit? fallback;
  for (final word in words) {
    if (word.bounds == Rect.zero) continue;
    final rect = pdfRectToViewerRect(
      word.bounds,
      pageHeight: pageHeight,
      scaleX: scaleX,
      scaleY: scaleY,
    );
    if (rect.isEmpty) continue;
    final distance = _distanceToRect(rect, point);
    if (distance <= tolerance &&
        (fallback == null || distance < fallback.distancePx)) {
      fallback = PdfWordHit(word, rect, distance);
    }
  }
  return fallback;
}

double _distanceToRect(Rect rect, Offset point) {
  final dx = math.max(rect.left - point.dx, point.dx - rect.right);
  final dy = math.max(rect.top - point.dy, point.dy - rect.bottom);
  if (dx <= 0 && dy <= 0) return 0.0;
  if (dx <= 0) return dy;
  if (dy <= 0) return dx;
  return math.sqrt(dx * dx + dy * dy);
}
