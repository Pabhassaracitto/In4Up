// lib/features/pdf_reader/services/pdf_page_ocr.dart
//
// Render một trang PDF ra pixels BGRA8888 để đưa vào OCR (ADR-0009 · OCR-001).
//
// Vì sao cần: PDF Reader extract text BẰNG CODE nên chỉ chạy với PDF có
// text layer. Trang scan (image-only) hiện dừng TTS và báo "Trang này là ảnh,
// không có chữ để đọc" (`widgets/pdf_tts_bar.dart`) — ngõ cụt. OCR mở ngõ đó.
//
// Vì sao trả pixels mà không phải file ảnh: `PdfPage.render()` của pdfrx trả
// về `PdfImage.pixels` = BGRA8888 THÔ (xem ghi chú đầu pdf_snapshot_burn.dart),
// và `InputImage.fromBitmap` của ML Kit khai đúng `InputImageFormat.bgra8888`
// → khớp nhau. Encode PNG trong tiến trình Dart rồi mới đưa cho ML Kit là
// thêm một bước thừa + thêm code không test được.
//
// Cỡ render dùng chung `pdfSnapshotRenderSize` với tính năng "in bản chụp":
// nhất quán một mức cap bộ nhớ, và hàm đó đã có test
// (test/pdf_reader/pdf_snapshot_burn_test.dart).
//
// Nền tảng: render + OCR đều chỉ chạy Android/iOS/Windows theo pdfrx, còn
// OCR chỉ Android/iOS — việc gate nền tảng là của OcrService, file này không
// tự quyết.

import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart' hide PdfAnnotation;

import 'pdf_snapshot_burn.dart';

/// Nền trắng — OCR muốn nền trắng chữ đen, khớp `kPdfSnapshotBackgroundArgb`
/// của bản in. Khai local để không phải import cả pdf_export_service (kéo theo
/// file_picker/share_plus) chỉ vì một hằng số.
const int _kOcrBackgroundArgb = 0xFFFFFFFF;

/// Một trang PDF đã raster hoá: pixels BGRA8888 + kích thước pixel.
class PdfPageRaster {
  final Uint8List pixels;
  final int width;
  final int height;

  const PdfPageRaster({
    required this.pixels,
    required this.width,
    required this.height,
  });

  /// Số byte kỳ vọng cho BGRA8888 (4 byte/pixel).
  int get expectedBytes => width * height * 4;

  /// True khi pixels khớp kích thước — điều kiện tiên quyết trước khi đưa
  /// sang native, nếu không ML Kit sẽ đọc tràn bộ nhớ.
  bool get isConsistent => pixels.length == expectedBytes;
}

/// Render trang [pageIndex] (0-based) của [doc] ra [PdfPageRaster].
///
/// Trả về null khi: chỉ số trang ngoài phạm vi, cỡ render suy ra không hợp lệ,
/// engine trả null, hoặc pixels không khớp kích thước. KHÔNG throw — caller
/// (nút OCR trên thanh đọc to) tự báo cho user.
Future<PdfPageRaster?> rasterizePdfPage(PdfDocument doc, int pageIndex) async {
  if (pageIndex < 0 || pageIndex >= doc.pages.length) return null;

  final page = doc.pages[pageIndex];
  final pageWidthPts = page.width.toDouble();
  final pageHeightPts = page.height.toDouble();
  final size = pdfSnapshotRenderSize(
    pageWidthPts: pageWidthPts,
    pageHeightPts: pageHeightPts,
  );
  if (size.width <= 0 || size.height <= 0) return null;

  final image = await page.render(
    fullWidth: size.width.toDouble(),
    fullHeight: size.height.toDouble(),
    backgroundColor: _kOcrBackgroundArgb,
  );
  if (image == null) return null;

  // Đọc width/height TRƯỚC khi dispose, và COPY pixels ra khỏi bộ nhớ engine:
  // dùng lại `image.pixels` sau dispose là UB (cùng bài học đã ghi trong
  // pdf_export_service.dart — "may thì rác, xui thì crash").
  final width = image.width;
  final height = image.height;
  final Uint8List pixels;
  try {
    pixels = Uint8List.fromList(image.pixels);
  } finally {
    image.dispose();
  }

  final raster = PdfPageRaster(pixels: pixels, width: width, height: height);
  return raster.isConsistent ? raster : null;
}
