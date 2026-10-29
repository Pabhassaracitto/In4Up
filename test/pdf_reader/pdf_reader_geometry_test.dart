// Săn lỗ hổng toạ độ PDF (P0-18): rect trang PDF có `top > bottom` (PDF y-up),
// nên `height` âm và `contains()` luôn false. Nếu ai đó "sửa" bằng cách đổi
// quy ước lưu trữ thì dữ liệu đã về máy người dùng (PdfAnnotation.bounds,
// VocabContext.rectHint, Evidence.locator) sẽ hỏng hàng loạt — nên hợp đồng là:
// LƯU nguyên như engine cho ra, QUY ĐỔI ở consumer, và consumer phải dùng hàm
// trong pdf_geometry.dart thay vì tự tính.
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/pdf_reader/models/pdf_word_info.dart';
import 'package:in4up/features/pdf_reader/services/pdf_geometry.dart';
import 'package:in4up/features/pdf_reader/services/pdf_word_hit_test.dart';

/// Trang A4-ish: 612 x 792 đơn vị PDF.
const double kPageW = 612;
const double kPageH = 792;

/// Một dòng chữ ở gần đầu trang: đỉnh y=712, đáy y=700, x 100..180.
const Rect kLineA = Rect.fromLTRB(100, 712, 180, 700);

void main() {
  group('pdfRectToViewerRect', () {
    test('quy đổi PDF space -> px (lật trục y, nhân scale)', () {
      final rect = pdfRectToViewerRect(
        kLineA,
        pageHeight: kPageH,
        scaleX: 0.5,
        scaleY: 0.5,
      );
      // top PDF 712 -> (792-712)*0.5 = 40 ; chiều cao 12*0.5 = 6
      expect(rect, const Rect.fromLTWH(50, 40, 40, 6));
      expect(rect.height, greaterThan(0));
      expect(rect.isEmpty, isFalse);
    });

    test('rect degenerate -> Rect.zero (không bao giờ trả chiều âm)', () {
      const flat = Rect.fromLTRB(10, 700, 80, 700); // height 0
      expect(pdfRectToViewerRect(flat, pageHeight: kPageH, scaleX: 1, scaleY: 1),
          Rect.zero);
      expect(pdfRectToViewerRect(Rect.zero, pageHeight: kPageH, scaleX: 1, scaleY: 1),
          Rect.zero);
      // empty => Positioned hợp lệ (chiều >= 0) hoặc bị caller bỏ qua
      expect(pdfRectToViewerRect(flat, pageHeight: kPageH, scaleX: 2, scaleY: 2),
          Rect.zero);
    });

    test('chấp nhận cả rect bị đảo chiều y (dữ liệu cũ)', () {
      final pdf = pdfRectToViewerRect(kLineA,
          pageHeight: kPageH, scaleX: 1, scaleY: 1);
      final yDown = pdfRectToViewerRect(const Rect.fromLTRB(100, 700, 180, 712),
          pageHeight: kPageH, scaleX: 1, scaleY: 1);
      expect(pdf.height, 12);
      expect(yDown.height, 12);
      expect(pdf.top, yDown.top);
      expect(yDown.top, 792 - 712);
    });
  });

  group('isPdfSpaceRect / isPaintablePdfRect', () {
    test('đánh dấu đúng quy ước PDF', () {
      expect(isPdfSpaceRect(kLineA), isTrue);
      expect(isPdfSpaceRect(const Rect.fromLTRB(0, 0, 10, 10)), isFalse);
      expect(isPdfSpaceRect(Rect.zero), isFalse);
    });

    test('vẽ được bất kể chiều y, nhưng không phải rect rỗng', () {
      expect(isPaintablePdfRect(kLineA), isTrue);
      expect(isPaintablePdfRect(const Rect.fromLTRB(100, 700, 180, 712)), isTrue);
      expect(isPaintablePdfRect(const Rect.fromLTRB(100, 700, 180, 700)), isFalse);
      expect(isPaintablePdfRect(Rect.zero), isFalse);
    });
  });

  group('pageScaleFactors', () {
    test('px trên một đơn vị PDF', () {
      final s = pageScaleFactors(
        pageWidth: kPageW,
        pageHeight: kPageH,
        pageViewSize: const Size(306, 396),
      );
      expect(s.x, 0.5);
      expect(s.y, 0.5);
    });

    test('kích thước trang chưa biết -> không chia 0', () {
      final s = pageScaleFactors(
        pageWidth: 0,
        pageHeight: 0,
        pageViewSize: const Size(306, 396),
      );
      expect(s.x, 1);
      expect(s.y, 1);
    });
  });

  group('hitTestWord', () {
    final words = [
      const PdfWordInfo(text: 'Enlightenment', bounds: kLineA, pageIndex: 0),
      const PdfWordInfo(
        text: 'silence',
        bounds: Rect.fromLTRB(100, 692, 200, 680),
        pageIndex: 0,
      ),
    ];

    test('chạm trúng thân chữ ở zoom 50%', () {
      final hit = hitTestWord(
        words,
        point: const Offset(70, 43), // giữa rect A đã quy đổi
        pageWidth: kPageW,
        pageHeight: kPageH,
        pageViewSize: const Size(306, 396),
      );
      expect(hit, isNotNull);
      expect(hit!.word.text, 'Enlightenment');
      expect(hit.isDirectHit, isTrue);
    });

    test('kết quả không đổi theo mức zoom (cùng một điểm nội tại của chữ)', () {
      // Điểm giữa chữ A trong không gian px, ở hai cỡ render khác nhau.
      final small = hitTestWord(
        words,
        point: const Offset(70, 43),
        pageWidth: kPageW,
        pageHeight: kPageH,
        pageViewSize: const Size(306, 396),
      );
      final big = hitTestWord(
        words,
        point: const Offset(280, 172), // zoom 200%: rect A ở scale 2 = (200,160,160,24)
        pageWidth: kPageW,
        pageHeight: kPageH,
        pageViewSize: const Size(1224, 1584),
      );
      expect(small, isNotNull);
      expect(big, isNotNull);
      expect(small!.word.text, big!.word.text);
      expect(small.word.text, 'Enlightenment');
    });

    test('chạm sát dưới chân chữ vẫn ăn từ gần nhất (dung sai theo cao độ)', () {
      final hit = hitTestWord(
        words,
        point: const Offset(70, 62),
        pageWidth: kPageW,
        pageHeight: kPageH,
        pageViewSize: const Size(306, 396),
      );
      expect(hit?.word.text, 'silence');
      expect(hit?.isDirectHit, isFalse);
    });

    test('chạm xa mọi chữ -> null, không ăn bừa từ gần nhất', () {
      expect(
        hitTestWord(
          words,
          point: const Offset(150, 300),
          pageWidth: kPageW,
          pageHeight: kPageH,
          pageViewSize: const Size(306, 396),
        ),
        isNull,
      );
    });

    test('không có trang / không có chữ -> null', () {
      expect(
        hitTestWord(
          const [],
          point: Offset.zero,
          pageWidth: kPageW,
          pageHeight: kPageH,
          pageViewSize: const Size(306, 396),
        ),
        isNull,
      );
      expect(
        hitTestWord(
          words,
          point: Offset.zero,
          pageWidth: kPageW,
          pageHeight: kPageH,
          pageViewSize: Size.zero,
        ),
        isNull,
      );
    });
  });
}
