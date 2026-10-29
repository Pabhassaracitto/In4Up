// B2 (Wave 2) — "in bản chụp": phủ highlight/ghi chú lên ảnh trang đã render,
// trực tiếp trên pixel.
//
// Vì sao composite tay mà không qua Canvas/dart:ui: `PdfPage.render()` của
// pdfrx_engine 0.3.9 trả về `PdfImage.pixels` = **BGRA8888 thô**, nên toàn bộ
// phần này là số học trên `Uint8List` — thuần Dart, chạy được trong
// `flutter test`, không cần thiết bị, không cần plugin. Đổi lại: không in được
// CHỮ của ghi chú lên ảnh (app không có font rasterizer trong tiến trình này);
// ghi chú đi theo marker + sidecar, và điều đó được nói thẳng ở docs.
import 'dart:typed_data';
import 'dart:ui' show Color, Rect;

import '../models/pdf_annotation.dart';

/// Hình chữ nhật theo PIXEL của ảnh trang (gốc trên-trái).
final class PdfPixelRect {
  const PdfPixelRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final int x;
  final int y;
  final int width;
  final int height;

  bool get isEmpty => width <= 0 || height <= 0;

  @override
  bool operator ==(Object other) =>
      other is PdfPixelRect &&
      other.x == x &&
      other.y == y &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(x, y, width, height);

  @override
  String toString() => 'PdfPixelRect($x,$y ${width}x$height)';
}

/// Đổi một `Rect` trong không gian PDF (gốc DƯỚI-trái, `top > bottom`) sang pixel
/// của ảnh trang (gốc TRÊN-trái). Đây chính là chỗ dễ lật trục sai nhất của tính
/// năng này, nên nó tách ra và có test riêng.
PdfPixelRect? pdfAnnotationPixelRect(
  Rect bounds, {
  required double pageWidthPts,
  required double pageHeightPts,
  required int imageWidth,
  required int imageHeight,
}) {
  if (pageWidthPts <= 0 || pageHeightPts <= 0) return null;
  if (imageWidth <= 0 || imageHeight <= 0) return null;
  final left = bounds.left, right = bounds.right;
  // KHÔNG dùng min/max của dart:math ở file này: trong SDK mà CI đang dùng,
  // kết quả bị suy luận là `num`, và mọi phép index `Uint8List[int]` phía sau vỡ
  // hàng loạt (7 error một lúc). Ternary tường minh giữ kiểu `int`/`double`.
  final high = bounds.top > bounds.bottom ? bounds.top : bounds.bottom;
  final low = bounds.top > bounds.bottom ? bounds.bottom : bounds.top;
  if (right <= left || high <= low) return null;

  final sx = imageWidth / pageWidthPts;
  final sy = imageHeight / pageHeightPts;

  var x0 = (left * sx).floor();
  var x1 = (right * sx).ceil();
  var y0 = ((pageHeightPts - high) * sy).floor();
  var y1 = ((pageHeightPts - low) * sy).ceil();

  if (x0 < 0) x0 = 0;
  if (y0 < 0) y0 = 0;
  if (x1 > imageWidth) x1 = imageWidth;
  if (y1 > imageHeight) y1 = imageHeight;
  if (x1 <= x0 || y1 <= y0) return null;
  return PdfPixelRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0);
}

/// Vuông nhỏ đánh dấu "chỗ này có ghi chú", đặt ở mép phải của vùng được chọn.
/// Không thể in chữ nên phải có dấu hiệu nhìn thấy được.
PdfPixelRect pdfNoteMarkerRect(PdfPixelRect region, {required int imageWidth}) {
  final int side = region.height < 6 ? 6 : (region.height > 14 ? 14 : region.height);
  final int maxStart = imageWidth - side < 0 ? 0 : imageWidth - side;
  int x = region.x + region.width + 2;
  if (x + side > imageWidth) x = region.x + region.width - side;
  if (x < 0) x = 0;
  if (x > maxStart) x = maxStart;
  return PdfPixelRect(x: x, y: region.y, width: side, height: side);
}

/// Sơn một chữ nhật lên buffer BGRA (hoà màu theo alpha, giữ nguyên kênh alpha
/// của nền vì ảnh render từ pdfium là opaque).
///
/// Trả về số byte đã sửa (để test/đo mà không cần so cả mảng).
int fillBgraRect({
  required Uint8List bgra,
  required int imageWidth,
  required int imageHeight,
  required PdfPixelRect rect,
  required int colorArgb,
  required double alpha,
}) {
  if (bgra.length < imageWidth * imageHeight * 4) return 0;
  if (rect.isEmpty) return 0;
  final double a = alpha < 0 ? 0.0 : (alpha > 1 ? 1.0 : alpha);
  if (a <= 0) return 0;
  final int srcR = (colorArgb >> 16) & 0xFF;
  final int srcG = (colorArgb >> 8) & 0xFF;
  final int srcB = colorArgb & 0xFF;
  final double inv = 1.0 - a;
  final int xStart = rect.x < 0 ? 0 : rect.x;
  final int yStart = rect.y < 0 ? 0 : rect.y;
  final int xRaw = rect.x + rect.width, yRaw = rect.y + rect.height;
  final int xEnd = xRaw < imageWidth ? xRaw : imageWidth;
  final int yEnd = yRaw < imageHeight ? yRaw : imageHeight;
  int touched = 0;
  for (int y = yStart; y < yEnd; y++) {
    int i = (y * imageWidth + xStart) * 4;
    for (int x = xStart; x < xEnd; x++, i += 4, touched += 4) {
      bgra[i] = (srcB * a + bgra[i] * inv).round();
      bgra[i + 1] = (srcG * a + bgra[i + 1] * inv).round();
      bgra[i + 2] = (srcR * a + bgra[i + 2] * inv).round();
      bgra[i + 3] = 255;
    }
  }
  return touched;
}

/// Toàn bộ bước burn: lấy `lineRects` (nếu có) rồi `bounds`, bỏ bookmark, bỏ
/// annotation không hình học. `noteMarkerColor` vẽ vuông dấu ghi chú.
///
/// Trả về số vùng đã sơn — 0 nghĩa là trang này không có gì để in.
int burnPdfAnnotationsIntoBgra(
  Uint8List bgra, {
  required int imageWidth,
  required int imageHeight,
  required double pageWidthPts,
  required double pageHeightPts,
  required List<PdfAnnotation> annotations,
  double highlightAlpha = 0.35,
  int noteMarkerColorArgb = 0xFF1E88E5,
  bool drawNoteMarkers = true,
}) {
  var painted = 0;
  for (final a in annotations) {
    if (a.type == AnnotationType.bookmark) continue;
    for (final rect in a.rectsForPainting) {
      final px = pdfAnnotationPixelRect(
        rect,
        pageWidthPts: pageWidthPts,
        pageHeightPts: pageHeightPts,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );
      if (px == null) continue;
      fillBgraRect(
        bgra: bgra,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        rect: px,
        colorArgb: a.color.toARGB32(),
        alpha: highlightAlpha,
      );
      painted++;
      final hasNote = (a.note?.trim().isNotEmpty ?? false);
      if (drawNoteMarkers && hasNote) {
        fillBgraRect(
          bgra: bgra,
          imageWidth: imageWidth,
          imageHeight: imageHeight,
          rect: pdfNoteMarkerRect(px, imageWidth: imageWidth),
          colorArgb: noteMarkerColorArgb,
          alpha: 1.0,
        );
      }
    }
  }
  return painted;
}

/// Kích thước ảnh hợp lý cho một trang: ~150 dpi (2x mật độ in thông thường của
/// máy tính tiền văn phòng), chặn ở 1800px cạnh dài để không nổ RAM trên điện
/// thoại khi xuất 40 trang.
({int width, int height}) pdfSnapshotRenderSize({
  required double pageWidthPts,
  required double pageHeightPts,
  double dpi = 150,
  int maxLongEdge = 1800,
}) {
  if (pageWidthPts <= 0 || pageHeightPts <= 0) return (width: 0, height: 0);
  final scale = dpi / 72.0;
  var w = (pageWidthPts * scale).round();
  var h = (pageHeightPts * scale).round();
  final int long = w > h ? w : h;
  if (long > maxLongEdge) {
    final shrink = maxLongEdge / long;
    w = (w * shrink).round();
    h = (h * shrink).round();
  }
  return (width: w < 1 ? 1 : w, height: h < 1 ? 1 : h);
}

/// Màu nền trang khi render cho bản in (trắng, không phải nền tối của app).
Color get pdfSnapshotPageBackground => const Color(0xFFFFFFFF);
