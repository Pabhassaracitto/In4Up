// I4U18-PDF-OCR-TTS-001 (Agent F · F2) — phân biệt PDF text-layer vs scan.
//
// Luật cần khoá: một trang trống chữ KHÔNG đủ để gọi cả cuốn là scan (trang
// bìa/trang trắng có ở mọi cuốn sách), và tài liệu đã có lớp chữ thì KHÔNG
// bao giờ được mời chạy OCR.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/pdf_reader/services/pdf_text_layer_probe.dart';

void main() {
  group('classifyPdfTextLayer', () {
    test('không có mẫu → unknown (đừng đoán khi chưa dò)', () {
      expect(classifyPdfTextLayer(const []), PdfTextLayerKind.unknown);
    });

    test('mọi trang mẫu trống chữ → scanned', () {
      expect(
        classifyPdfTextLayer(const ['', '   ', '\n\n', '12', '— 3 —']),
        PdfTextLayerKind.scanned,
      );
    });

    test('một trang có chữ thật là đủ để kết luận textLayer', () {
      expect(
        classifyPdfTextLayer(const [
          '', // bìa ảnh
          'Chương một: bốn sự thật cao thượng',
          '',
        ]),
        PdfTextLayerKind.textLayer,
      );
    });

    test('số trang / watermark ngắn không được tính là lớp chữ', () {
      expect(classifyPdfTextLayer(const ['7', 'ii', '— 128 —']),
          PdfTextLayerKind.scanned);
    });

    test('đếm chữ bỏ qua khoảng trắng và dấu câu', () {
      expect(pdfTextLayerCharCount('a b, c! d?'), 4);
      expect(pdfTextLayerCharCount('   ...   '), 0);
      expect(pdfTextLayerCharCount('Việt 123'), 7);
    });
  });

  group('pdfTextLayerProbePages', () {
    test('tài liệu rỗng → không lấy mẫu', () {
      expect(pdfTextLayerProbePages(0), isEmpty);
    });

    test('ít trang hơn số mẫu → lấy hết, không trùng', () {
      final pages = pdfTextLayerProbePages(3);
      expect(pages, [0, 1, 2]);
    });

    test('rải đều đầu — giữa — cuối, tăng dần, không vượt biên', () {
      final pages = pdfTextLayerProbePages(100, maxSamples: 3);
      expect(pages.length, 3);
      expect(pages.first, 0);
      expect(pages.last, 99);
      for (var i = 1; i < pages.length; i++) {
        expect(pages[i], greaterThan(pages[i - 1]));
      }
    });

    test('trang đang đọc luôn nằm trong mẫu', () {
      final pages = pdfTextLayerProbePages(500, startPage: 321, maxSamples: 4);
      expect(pages, contains(321));
      expect(pages.length, 4);
      expect(pages.every((p) => p >= 0 && p < 500), isTrue);
    });

    test('startPage ngoài biên được kẹp lại, không văng lỗi', () {
      expect(pdfTextLayerProbePages(10, startPage: 999, maxSamples: 2),
          contains(9));
      expect(pdfTextLayerProbePages(10, startPage: -5, maxSamples: 2),
          contains(0));
    });
  });

  group('shouldOfferOcrForPage', () {
    test('trang đã có chữ → KHÔNG mời OCR (không spinner vô cớ)', () {
      expect(shouldOfferOcrForPage(pageHasText: true), isFalse);
    });

    test('trang trống chữ → mời OCR', () {
      expect(shouldOfferOcrForPage(pageHasText: false), isTrue);
    });
  });
}
