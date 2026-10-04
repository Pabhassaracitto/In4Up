// XFDF là định dạng TA không tự quyết, nên test phải giữ đúng 3 hợp đồng của
// nó: page 0-based, toạ độ gốc dưới-trái, và XML tự cân bằng + escape.
import 'dart:ui' show Color, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/pdf_reader/models/pdf_annotation.dart';
import 'package:in4up/features/pdf_reader/services/pdf_xfdf_export.dart';

PdfAnnotation a({
  String id = 'x1',
  int page = 2,
  AnnotationType type = AnnotationType.highlight,
  Rect bounds = const Rect.fromLTRB(10, 700, 90, 680),
  String text = 'chữ',
  String? note,
  List<Rect> lines = const [],
  int color = 0xFFFFD54F,
}) =>
    PdfAnnotation(
      id: id,
      pageIndex: page,
      bounds: bounds,
      selectedText: text,
      note: note,
      color: Color(color),
      type: type,
      createdAt: DateTime.parse('2026-09-02 07:08:09Z'),
      lineRects: lines,
    );

final DateTime at = DateTime.parse('2026-09-06 00:00:00Z');

String build(List<PdfAnnotation> list) =>
    buildPdfXfdfExport(pdfFileName: 'Sách.pdf', annotations: list, exportedAt: at);

void main() {
  test('header/aux trỏ đúng tên file để app khác biết dán vào đâu', () {
    final xml = build([a()]);
    expect(xml, startsWith('<?xml version="1.0" encoding="UTF-8"?>'));
    expect(xml, contains('xmlns="http://ns.adobe.com/XFDF/1.0"'));
    expect(xml, contains('<aux name="filename" value="Sách.pdf"/>'));
    expect(xml, contains('<annot action="annotReplace">'));
    expect(xml.trimRight(), endsWith('</xfdf>'));
    expect(xml, contains('<trail modified="2026-09-06T00:00:00Z"/>'));
  });

  test('page là 0-based — KHÔNG cộng 1', () {
    final xml = build([a(page: 0)]);
    expect(xml, contains('page="0"'));
    expect(xml, isNot(contains('page="1"')));
  });

  test('rect theo thứ tự left bottom right top (PDF space)', () {
    final xml = build([a(bounds: const Rect.fromLTRB(10, 700, 90, 680))]);
    expect(xml, contains('rect="10.00 680.00 90.00 700.00"'));
    expect(xml, contains(
        'quadpoints="10.00 700.00 90.00 700.00 10.00 680.00 90.00 680.00"'));
  });

  test('highlight nhiều dòng: xuất TỪNG dòng, không phủ cả khoảng trắng', () {
    final xml = build([
      a(lines: const [
        Rect.fromLTRB(0, 700, 100, 690),
        Rect.fromLTRB(0, 690, 100, 680),
        Rect.fromLTRB(0, 680, 60, 670),
      ]),
    ]);
    expect('<highlight'.allMatches(xml).length, 3);
  });

  test('bookmark không phải markup trong trang ⇒ không xuất', () {
    expect(pdfXfdfExportableCount([a(type: AnnotationType.bookmark)]), 0);
    final xml = build([a(type: AnnotationType.bookmark)]);
    expect(xml, isNot(contains('<highlight')));
    expect(xml, contains('không có highlight/ghi chú nào để xuất'));
  });

  test('note -> <text icon="Comment">, highlight giữ contents = ghi chú nếu có',
      () {
    final xml = build([
      a(type: AnnotationType.note, note: 'ở đây có ghi chú'),
      a(id: 'h', note: 'ưu tiên ghi chú', text: 'bỏ qua cái này'),
    ]);
    expect(xml, contains('<text page="2"'));
    expect(xml, contains('icon="Comment"'));
    expect(xml, contains('<contents>ưu tiên ghi chú</contents>'));
    expect(xml, isNot(contains('bỏ qua cái này')));
  });

  test('màu lấy từ annotation, viết dạng #RRGGBB', () {
    final xml = build([a(color: 0xFF00AABB)]);
    expect(xml, contains('color="#00AABB"'));
    expect(xml, contains('opacity="0.40"'));
  });

  group('XML an toàn', () {
    test('escape 5 ký tự, bỏ điều khiển, không để raw < trong contents', () {
      final xml = build([
        a(text: 'a & b < c > d "e" \'f\'', note: 'hộp\tđtab\nxuống dòng\x00\x07'),
      ]);
      expect(xml, contains('a &amp; b &lt; c &gt; d &quot;e&quot; &apos;f&apos;'));
      expect(xml, contains('hộp\tdtab'));
      expect(xml, isNot(contains('\x00')));
      expect(xml, isNot(contains('\x07')));
    });

    test('mọi tag bật ra đều được đóng, mọi dòng thuộc tính có nháy chẵn', () {
      final xml = build([
        a(),
        a(id: 'n', type: AnnotationType.note, note: 'ghi <chú> & "trích"'),
        a(id: 'h', lines: const [Rect.fromLTRB(0, 100, 5, 90)]),
      ]);
      for (final tag in ['xfdf', 'header', 'pdf', 'annot', 'highlight', 'text', 'contents']) {
        final open = RegExp('<$tag[ >/]').allMatches(xml).length;
        final close = RegExp('</$tag>').allMatches(xml).length;
        final selfClosed = RegExp('<$tag[^>]*/>').allMatches(xml).length;
        expect(open, close + selfClosed, reason: 'tag <$tag> không cân bằng');
      }
      for (final line in xml.split('\n')) {
        expect('"'.allMatches(line).length.isEven, isTrue,
            reason: 'dòng lẻ dấu nháy (attribute hỏng): $line');
      }
    });

    test('tên file có ký tự cấm vẫn sinh tên .xfdf hợp lệ', () {
      expect(pdfXfdfFileName('/a/b/Sách: <9>.pdf'), 'Sách_ _9_.xfdf');
      expect(pdfXfdfFileName(''), 'annotations.xfdf');
    });
  });
}
