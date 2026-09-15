// B1 (Wave 2) — XFDF: định dạng trung lập để người dùng mở highlight/ghi chú
// bằng app PDF khác (Acrobat, xodo, pdfium viewer...). Định dạng vòng-tròn-riêng
// của In4Up là `.in4up.json` (xem pdf_annotation_sidecar.dart); XFDF chỉ là chiều
// XUẤT, ta không nhập lại nó — và nói rõ điều đó thay vì hứa hão.
//
// Ba điều phải giữ đúng:
//  * `page` trong XFDF là **0-based** — trùng với `PdfAnnotation.pageIndex`, nên
//    ở đây không cộng 1 (khác `PdfDest.pageNumber` 1-based của pdfrx).
//  * toạ độ là không gian user-space của PDF, **gốc dưới-trái** — đúng cái model
//    đang lưu (`Rect` PDF y-up), nên chỉ cần in ra, không lật trục.
//  * Highlight nhiều dòng: một `<highlight>` cho MỘT quadpoints, tức xuất theo
//    `lineRects` khi có. Xuất cả `bounds` cho highlight 3 dòng sẽ phủ luôn phần
//    trắng giữa các dòng — thứ mà trên màn hình app ta đã cố tránh.
import 'dart:ui' show Color, Rect;

import '../models/pdf_annotation.dart';
import 'pdf_annotation_sidecar.dart' show pdfExportBaseName;

/// Màu mặc định của highlight khi annotation không mang màu hợp lệ.
const int kPdfXfdfDefaultHighlightArgb = 0xFFFFD54F;

/// Độ mờ highlight. Acrobat hỗ trợ `opacity` từ XFDF 1.0 (không phải mọi app
/// đều đọc; app bỏ qua thì vẫn thấy highlight, chỉ là đặc hơn).
const double kPdfXfdfHighlightOpacity = 0.40;

/// Tên app hiện trong thuộc tính `title` của annotation (ai mở file sẽ thấy).
const String kPdfXfdfProducerTitle = 'In4Up';

/// Đường dẫn file XFDF nên đặt cạnh file PDF: `<tên>.xfdf`.
String pdfXfdfFileName(String pdfPath) {
  final base = pdfExportBaseName(pdfPath);
  return base.isEmpty ? 'annotations.xfdf' : '$base.xfdf';
}

/// Tạo nội dung XFDF. Bookmark **không** được xuất: đó là thứ của app (đánh dấu
/// để mở lại), không phải markup trong trang PDF; nó vẫn nằm trong JSON sidecar.
String buildPdfXfdfExport({
  required String pdfFileName,
  required List<PdfAnnotation> annotations,
  required DateTime exportedAt,
}) {
  final buffer = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8"?>\n')
    ..write('<xfdf xmlns="http://ns.adobe.com/XFDF/1.0" xml:space="preserve">\n')
    ..write('  <header>\n')
    ..write('    <pdf>\n')
    ..write('      <aux name="filename" value="')
    ..write(_escape(pdfFileName))
    ..write('"/>\n')
    ..write('    </pdf>\n')
    ..write('  </header>\n')
    ..write('  <fields/>\n')
    ..write('  <annot action="annotReplace">\n');

  var written = 0;
  for (final a in annotations) {
    if (a.type == AnnotationType.bookmark) continue;
    for (final rect in _rectsForXfdf(a)) {
      written++;
      buffer
        ..write(a.type == AnnotationType.note ? _textMarkup(a, rect) : _highlightMarkup(a, rect))
        ..write('\n');
    }
  }
  if (written == 0) {
    buffer.write('    <!-- không có highlight/ghi chú nào để xuất -->\n');
  }
  buffer
    ..write('  </annot>\n')
    ..write('  <trail modified="')
    ..write(_isoDate(exportedAt))
    ..write('"/>\n')
    ..write('</xfdf>\n');
  return buffer.toString();
}

/// Số annotation sẽ đi vào XFDF (để UI báo "không có gì để xuất" trước khi gọi).
int pdfXfdfExportableCount(List<PdfAnnotation> annotations) =>
    annotations
        .where((a) => a.type != AnnotationType.bookmark)
        .fold<int>(0, (sum, a) => sum + _rectsForXfdf(a).length);

List<Rect> _rectsForXfdf(PdfAnnotation a) {
  final rects = a.rectsForPainting;
  return rects.where((r) => _isUsable(r)).toList(growable: false);
}

bool _isUsable(Rect r) =>
    !r.isEmpty && r.right > r.left && (r.top - r.bottom).abs() > 0;

String _highlightMarkup(PdfAnnotation a, Rect rect) {
  final attrs = <String>[
    'page="${a.pageIndex}"',
    'rect="${_rect(rect)}"',
    'quadpoints="${_quadpoints(rect)}"',
    'color="${_hexColor(a.color)}"',
    'opacity="${kPdfXfdfHighlightOpacity.toStringAsFixed(2)}"',
    'title="${_escape(kPdfXfdfProducerTitle)}"',
    'subject="Highlight"',
    'name="${_escape(a.id)}"',
    'created="${_isoDate(a.createdAt)}"',
  ];
  final body = _contentFor(a);
  return '    <highlight ${attrs.join(' ')}>'
      '${body.isEmpty ? '' : '<contents>$body</contents>'}'
      '</highlight>';
}

String _textMarkup(PdfAnnotation a, Rect rect) {
  final attrs = <String>[
    'page="${a.pageIndex}"',
    'rect="${_rect(rect)}"',
    'color="${_hexColor(a.color)}"',
    'icon="Comment"',
    'title="${_escape(kPdfXfdfProducerTitle)}"',
    'subject="Note"',
    'name="${_escape(a.id)}"',
    'created="${_isoDate(a.createdAt)}"',
  ];
  final body = _escape(a.note ?? a.selectedText);
  return '    <text ${attrs.join(' ')}>'
      '${body.isEmpty ? '' : '<contents>$body</contents>'}'
      '</text>';
}

/// Highlight ưu tiên hiện đúng chữ đã chọn; nếu người dùng ghi chú thì ghi chú
/// quan trọng hơn (App khác không có ngữ cảnh để hiện cả hai).
String _contentFor(PdfAnnotation a) {
  final note = a.note?.trim();
  if (note != null && note.isNotEmpty) return _escape(note);
  return _escape(a.selectedText.trim());
}

/// `rect` trong PDF là `left bottom right top` (gốc dưới-trái).
String _rect(Rect r) =>
    '${_n(r.left)} ${_n(r.bottom)} ${_n(r.right)} ${_n(r.top)}';

/// 4 điểm theo thứ tự trên-trái, trên-phải, dưới-trái, dưới-phải — PDF space.
String _quadpoints(Rect r) => <String>[
      _n(r.left),
      _n(r.top),
      _n(r.right),
      _n(r.top),
      _n(r.left),
      _n(r.bottom),
      _n(r.right),
      _n(r.bottom),
    ].join(' ');

String _n(double v) => v.toStringAsFixed(2);

String _hexColor(Color color) {
  final argb = color.toARGB32();
  String two(int shift) =>
      ((argb >> shift) & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase();
  return '#${two(16)}${two(8)}${two(0)}';
}

/// ISO-8601 rút gọn theo đúng yêu cầu của date string trong PDF/XFDF.
String _isoDate(DateTime value) {
  final v = value.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${v.year.toString().padLeft(4, '0')}-${two(v.month)}-${two(v.day)}'
      'T${two(v.hour)}:${two(v.minute)}:${two(v.second)}Z';
}

/// Escape 5 ký tự XML + bỏ ký tự điều khiển (trừ \n \t) vì highlight có thể chứa
/// chữ dán từ nơi khác.
String _escape(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
  return cleaned
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
