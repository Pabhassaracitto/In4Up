// B2: ảnh trang đến từ pdfium là BGRA, còn rect của ta ở không gian PDF gốc
// DƯỚI-trái — hai hệ trục ngược nhau. Test này giữ đúng phép lật trục và phép
// blend, vì sai một trong hai là bản in ra file ảnh bị lộn ngược hoặc mất nét.
import 'dart:typed_data';
import 'dart:ui' show Color, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/pdf_reader/models/pdf_annotation.dart';
import 'package:in4up/features/pdf_reader/services/pdf_snapshot_burn.dart';

PdfAnnotation ann({
  int page = 0,
  AnnotationType type = AnnotationType.highlight,
  Rect bounds = const Rect.fromLTRB(100, 500, 300, 450),
  String? note,
  int color = 0xFFFF0000,
  List<Rect> lines = const [],
}) =>
    PdfAnnotation(
      id: 'a',
      pageIndex: page,
      bounds: bounds,
      lineRects: lines,
      selectedText: 'x',
      note: note,
      color: Color(color),
      type: type,
      createdAt: DateTime(2026, 9, 6),
    );

Uint8List solidBgra(int w, int h, int b, int g, int r, {int alpha = 255}) {
  final out = Uint8List(w * h * 4);
  for (var i = 0; i < w * h; i++) {
    out[i * 4] = b;
    out[i * 4 + 1] = g;
    out[i * 4 + 2] = r;
    out[i * 4 + 3] = alpha;
  }
  return out;
}

// Thứ tự trường (r,g,b,a) cố ý khớp với các record literal bên dưới: record so
// sánh theo CẢ kiểu, mà kiểu record phân biệt theo thứ tự trường.
({int r, int g, int b, int a}) pixelAt(Uint8List buf, int w, int x, int y) {
  final i = (y * w + x) * 4;
  return (r: buf[i + 2], g: buf[i + 1], b: buf[i], a: buf[i + 3]);
}

void main() {
  group('đổi toạ độ PDF -> pixel', () {
    test('lật trục Y và nhân đúng tỉ lệ', () {
      // Trang 400x600pt, ảnh 800x1200px (2 px/pt). Rect PDF: cao 500, thấp 450.
      final px = pdfAnnotationPixelRect(
        const Rect.fromLTRB(100, 500, 300, 450),
        pageWidthPts: 400,
        pageHeightPts: 600,
        imageWidth: 800,
        imageHeight: 1200,
      )!;
      expect(px.x, 200);
      expect(px.width, 400);
      expect(px.y, (600 - 500) * 2); // 200
      expect(px.height, (500 - 450) * 2); // 100
    });

    test('rect lưu ngược chiều (bottom > top) vẫn ra cùng ô', () {
      final normal = pdfAnnotationPixelRect(
        const Rect.fromLTRB(0, 700, 10, 680),
        pageWidthPts: 100,
        pageHeightPts: 800,
        imageWidth: 100,
        imageHeight: 800,
      );
      final flipped = pdfAnnotationPixelRect(
        const Rect.fromLTRB(0, 680, 10, 700),
        pageWidthPts: 100,
        pageHeightPts: 800,
        imageWidth: 100,
        imageHeight: 800,
      );
      expect(flipped, normal);
    });

    test('cắt vào trong trang; ra ngoài hoàn toàn -> null', () {
      final outside = pdfAnnotationPixelRect(
        const Rect.fromLTRB(900, 500, 1000, 450),
        pageWidthPts: 400,
        pageHeightPts: 600,
        imageWidth: 800,
        imageHeight: 1200,
      );
      expect(outside, isNull, reason: 'rect nằm ngoài trang thì không vẽ gì');
      final partly = pdfAnnotationPixelRect(
        const Rect.fromLTRB(350, 620, 500, 400),
        pageWidthPts: 400,
        pageHeightPts: 600,
        imageWidth: 800,
        imageHeight: 1200,
      )!;
      expect(partly.x + partly.width, 800);
      expect(partly.y, 0);
    });

    test('dữ liệu rác -> null, không ném', () {
      for (final bounds in [Rect.zero, const Rect.fromLTRB(5, 5, 5, 5), const Rect.fromLTRB(0, 10, 3, 10)]) {
        expect(
          pdfAnnotationPixelRect(bounds,
              pageWidthPts: 100,
              pageHeightPts: 100,
              imageWidth: 100,
              imageHeight: 100),
          anyOf(isNull, isA<PdfPixelRect>()),
        );
      }
      expect(
        pdfAnnotationPixelRect(const Rect.fromLTRB(0, 10, 5, 0),
            pageWidthPts: 0, pageHeightPts: 100, imageWidth: 10, imageHeight: 10),
        isNull,
      );
      expect(
        pdfAnnotationPixelRect(const Rect.fromLTRB(0, 10, 5, 0),
            pageWidthPts: 100, pageHeightPts: 100, imageWidth: 0, imageHeight: 10),
        isNull,
      );
    });
  });

  group('blend lên BGRA', () {
    test('alpha 0.5 đỏ trên nền trắng = (255,128,128) và alpha về 255', () {
      final buf = solidBgra(2, 2, 255, 255, 255, alpha: 255);
      final touched = fillBgraRect(
        bgra: buf,
        imageWidth: 2,
        imageHeight: 2,
        rect: const PdfPixelRect(x: 0, y: 0, width: 2, height: 1),
        colorArgb: 0xFFFF0000,
        alpha: 0.5,
      );
      expect(touched, 2 * 4); // 2 pixel * 4 byte
      expect(pixelAt(buf, 2, 0, 0), (r: 255, g: 128, b: 128, a: 255));
      expect(pixelAt(buf, 2, 1, 0), (r: 255, g: 128, b: 128, a: 255));
      // dòng dưới không bị chạm
      expect(pixelAt(buf, 2, 0, 1), (r: 255, g: 255, b: 255, a: 255));
    });

    test('alpha 1.0 ghi đè tuyệt đối; alpha 0 và buffer cộc -> 0 byte', () {
      final buf = solidBgra(2, 2, 255, 255, 255);
      fillBgraRect(
        bgra: buf,
        imageWidth: 2,
        imageHeight: 2,
        rect: const PdfPixelRect(x: 0, y: 0, width: 2, height: 2),
        colorArgb: 0xFF0000FF,
        alpha: 1.0,
      );
      expect(pixelAt(buf, 2, 1, 1), (r: 0, g: 0, b: 255, a: 255));

      final buf2 = solidBgra(2, 2, 0, 0, 0);
      expect(
        fillBgraRect(
          bgra: buf2,
          imageWidth: 2,
          imageHeight: 2,
          rect: const PdfPixelRect(x: 0, y: 0, width: 2, height: 2),
          colorArgb: 0xFFFFFFFF,
          alpha: 0,
        ),
        0,
      );
      expect(pixelAt(buf2, 2, 0, 0), (r: 0, g: 0, b: 0, a: 255));

      final tiny = Uint8List(4);
      expect(
        fillBgraRect(
          bgra: tiny,
          imageWidth: 8,
          imageHeight: 8,
          rect: const PdfPixelRect(x: 0, y: 0, width: 8, height: 8),
          colorArgb: 0xFFFFFFFF,
          alpha: 1,
        ),
        0,
        reason: 'buffer ngắn hơn khai báo: phải từ chối, không được ghi đè bộ nhớ',
      );
    });

    test('rect tràn cạnh được kẹp, không vượt ngoài ảnh', () {
      final buf = solidBgra(4, 4, 255, 255, 255);
      fillBgraRect(
        bgra: buf,
        imageWidth: 4,
        imageHeight: 4,
        rect: const PdfPixelRect(x: 2, y: 2, width: 99, height: 99),
        colorArgb: 0xFF112233,
        alpha: 1,
      );
      expect(pixelAt(buf, 4, 3, 3), (r: 0x11, g: 0x22, b: 0x33, a: 255));
    });
  });

  group('burn mức annotation', () {
    test('bookmark bị bỏ; highlight có lineRects sơn theo từng dòng', () {
      final buf = solidBgra(100, 100, 255, 255, 255);
      expect(
        burnPdfAnnotationsIntoBgra(
          buf,
          imageWidth: 100,
          imageHeight: 100,
          pageWidthPts: 100,
          pageHeightPts: 100,
          annotations: [ann(type: AnnotationType.bookmark)],
        ),
        0,
      );
      final painted = burnPdfAnnotationsIntoBgra(
        buf,
        imageWidth: 100,
        imageHeight: 100,
        pageWidthPts: 100,
        pageHeightPts: 100,
        annotations: [
          ann(lines: const [Rect.fromLTRB(0, 90, 10, 80), Rect.fromLTRB(0, 70, 10, 60)]),
        ],
      );
      expect(painted, 2);
      expect(pixelAt(buf, 100, 5, 15).g, lessThan(255)); // dòng 1
      expect(pixelAt(buf, 100, 5, 35).g, lessThan(255)); // dòng 2
      expect(pixelAt(buf, 100, 5, 25).g, 255, reason: 'giữa hai dòng: KHÔNG bị phủ');
    });

    test('annotation có ghi chú -> vuông marker màu marker, nằm ngoài vùng sơn',
        () {
      final buf = solidBgra(100, 100, 255, 255, 255);
      // bounds PDF (0,90)-(40,80) trên trang 100x100 -> pixel x0..39, y10..19.
      // Marker (cạnh 10px) phải nằm NGAY SAU vùng sơn: x=42, y=10.
      burnPdfAnnotationsIntoBgra(
        buf,
        imageWidth: 100,
        imageHeight: 100,
        pageWidthPts: 100,
        pageHeightPts: 100,
        annotations: [
          ann(note: 'ghi chú đây', color: 0x0000FF00,
              bounds: const Rect.fromLTRB(0, 90, 40, 80)),
        ],
        highlightAlpha: 0, // tắt phủ màu để cô lập riêng marker
      );
      expect(pixelAt(buf, 100, 45, 12), (r: 0x1E, g: 0x88, b: 0xE5, a: 255),
          reason: 'marker phải xuất hiện even khi alpha highlight = 0');
      expect(pixelAt(buf, 100, 20, 12), (r: 255, g: 255, b: 255, a: 255),
          reason: 'trong vùng sơn nhưng alpha 0 => không đổi');
    });

    test('drawNoteMarkers = false -> không có marker', () {
      final buf = solidBgra(100, 100, 255, 255, 255);
      burnPdfAnnotationsIntoBgra(
        buf,
        imageWidth: 100,
        imageHeight: 100,
        pageWidthPts: 100,
        pageHeightPts: 100,
        annotations: [ann(note: 'x', bounds: const Rect.fromLTRB(0, 90, 40, 80))],
        highlightAlpha: 0,
        drawNoteMarkers: false,
      );
      expect(pixelAt(buf, 100, 45, 12), (r: 255, g: 255, b: 255, a: 255));
    });

    test('kích thước ảnh render: 150dpi và chặn cạnh dài 1800px', () {
      expect(pdfSnapshotRenderSize(pageWidthPts: 595, pageHeightPts: 842),
          (width: 1240, height: 1754));
      final capped = pdfSnapshotRenderSize(pageWidthPts: 2000, pageHeightPts: 3000);
      expect(capped.height, 1800);
      expect(capped.width, 1200);
      expect(pdfSnapshotRenderSize(pageWidthPts: 0, pageHeightPts: 100),
          (width: 0, height: 0));
    });
  });
}
