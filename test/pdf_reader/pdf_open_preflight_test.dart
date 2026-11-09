// AUDIT-1.21.0 #4 — «Gần đây» mở PDF chết ⇒ FPDF_ER_FILE:2.
// Test THUẦN dart:io, không cần pdfrx / thiết bị.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/pdf_reader/services/pdf_open_preflight.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('i4up_pdf_preflight_'));
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  File file(String name) => File('${dir.path}/$name');

  group('inspectPdfForOpen', () {
    test('đường dẫn không còn ⇒ missing', () {
      expect(inspectPdfForOpen('${dir.path}/gone.pdf').issue,
          PdfOpenIssue.missing);
      expect(inspectPdfForOpen('').issue, PdfOpenIssue.missing);
    });

    test('file rỗng / tải dở ⇒ empty', () {
      file('empty.pdf').writeAsBytesSync(<int>[]);
      expect(inspectPdfForOpen(file('empty.pdf').path).issue,
          PdfOpenIssue.empty);
      file('tiny.pdf').writeAsBytesSync('%PDF-1.4\n'.codeUnits);
      expect(inspectPdfForOpen(file('tiny.pdf').path).issue,
          PdfOpenIssue.empty);
    });

    test('HTML / link dán nhầm ⇒ notPdf (không đẩy xuống PDFium)', () {
      file('page.html').writeAsStringSync(
          '<html><body>' + 'x' * 300 + '</body></html>');
      expect(inspectPdfForOpen(file('page.html').path).issue,
          PdfOpenIssue.notPdf);
    });

    test('PDF có header + đủ dung lượng ⇒ canOpen', () {
      final f = file('ok.pdf');
      f.writeAsBytesSync('%PDF-1.7\n'.codeUnits + List<int>.filled(400, 0));
      final check = inspectPdfForOpen(f.path);
      expect(check.canOpen, isTrue);
      expect(check.issue, PdfOpenIssue.none);
      expect(check.length, greaterThanOrEqualTo(kPdfMinPlausibleBytes));
    });

    test('BOM / khoảng trắng đầu vẫn nhận là PDF', () {
      final f = file('bom.pdf');
      f.writeAsBytesSync(<int>[0xEF, 0xBB, 0xBF, 0x20] +
          '%PDF-1.4\n'.codeUnits +
          List<int>.filled(400, 0));
      expect(inspectPdfForOpen(f.path).canOpen, isTrue);
    });

    test('đường dẫn là thư mục ⇒ unreadable (không văng)', () {
      expect(inspectPdfForOpen(dir.path).issue, PdfOpenIssue.unreadable);
    });
  });

  group('isPdfFileError', () {
    test('nhận diện đúng lỗi PDFium file:2', () {
      expect(isPdfFileError('PdfException: FPDF_ER_FILE:2'), isTrue);
      expect(isPdfFileError('PDF file not found'), isTrue);
      expect(isPdfFileError('Could not be opened (pdf)'), isTrue);
    });
    test('không bắt nhầm lỗi khác', () {
      expect(isPdfFileError('Network timeout'), isFalse);
      expect(isPdfFileError('Invalid page index'), isFalse);
    });
  });
}
