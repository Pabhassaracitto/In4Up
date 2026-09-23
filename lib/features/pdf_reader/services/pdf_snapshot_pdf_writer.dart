// B2 (Wave 2) — tối thiểu một tệp PDF "bản chụp" từ các ảnh trang đã render,
// KHÔNG thêm dependency nào.
//
// Vì sao tự viết mà không dùng package `pdf`/`printing`: `dart:pdf` chỉ TẠO PDF
// mới chứ không parse PDF có sẵn (nên không "stamp" vào file gốc được dù có thêm
// package), còn thứ ta cần ở đây — nhúng ảnh JPEG/RGB vào các trang cỡ A4 — là
// một tập hợp con rất nhỏ của đặc tả PDF và viết tay được. Thêm package = ADR +
// rủi ro build cho cả app, không xứng với một tính năng xuất.
//
// Mỗi trang = 1 image XObject, dữ liệu ảnh là các hàng RGB có byte lọc PNG (0 =
// None) rồi nén bằng zlib, khai báo `/DecodeParms << /Predictor 15 ... >>`. Cách
// này nén nền trắng cực tốt (một trang chủ yếu trắng ra cỡ vài chục KB), và
// **đoàn hồi được trong test**: giải nén lại rồi so từng byte với ảnh gốc.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Một trang của bản chụp: pixel BGRA + kích thước trang theo point (1/72 inch).
final class PdfSnapshotFrame {
  const PdfSnapshotFrame({
    required this.pixelWidth,
    required this.pixelHeight,
    required this.pageWidthPts,
    required this.pageHeightPts,
    required this.bgra,
  });

  final int pixelWidth;
  final int pixelHeight;
  final double pageWidthPts;
  final double pageHeightPts;

  /// BGRA8888, `pixelWidth * pixelHeight * 4` byte — đúng định dạng
  /// `PdfImage.pixels` trả về từ `PdfPage.render`.
  final Uint8List bgra;

  bool get hasConsistentPixels =>
      bgra.length == pixelWidth * pixelHeight * 4 &&
      pixelWidth > 0 &&
      pixelHeight > 0 &&
      pageWidthPts > 0 &&
      pageHeightPts > 0;
}

/// Kích thước trang PDF mặc định khi engine không cho biết (points).
const double kPdfFallbackPagePts = 595.0;

/// Tạo tệp PDF. Ném [ArgumentError] khi dữ liệu không nhất quán — caller phải
/// bắt và báo người dùng, không im lặng xuất file hỏng.
Uint8List buildPdfFromSnapshotFrames({
  required List<PdfSnapshotFrame> frames,
  String? title,
  DateTime? createdAt,
  String producer = 'In4Up',
}) {
  if (frames.isEmpty) {
    throw ArgumentError.value(frames, 'frames', 'không có trang nào để xuất');
  }
  for (var i = 0; i < frames.length; i++) {
    if (!frames[i].hasConsistentPixels) {
      throw ArgumentError('trang ${i + 1}: kích thước ảnh và pixel không khớp');
    }
  }

  final count = frames.length;
  final infoNum = 3 + count * 3;
  final bodies = <int, List<int>>{};

  List<int> ascii(String s) => utf8.encode(s);

  bodies[1] = ascii('<< /Type /Catalog /Pages 2 0 R >>');
  final kids = StringBuffer('<< /Type /Pages /Count $count /Kids [');
  for (var i = 0; i < count; i++) {
    if (i > 0) kids.write(' ');
    kids.write('${3 + i * 3} 0 R');
  }
  kids.write(' ] >>');
  bodies[2] = ascii(kids.toString());

  for (var i = 0; i < count; i++) {
    final frame = frames[i];
    final pageNum = 3 + i * 3;
    final contentNum = 4 + i * 3;
    final imageNum = 5 + i * 3;

    bodies[pageNum] = ascii(
      '<< /Type /Page /Parent 2 0 R'
      ' /MediaBox [0 0 ${_num(frame.pageWidthPts)} ${_num(frame.pageHeightPts)}]'
      ' /Resources << /XObject << /Im0 $imageNum 0 R >> >>'
      ' /Contents $contentNum 0 R >>',
    );

    final content = ascii(
      'q ${_num(frame.pageWidthPts)} 0 0 ${_num(frame.pageHeightPts)} 0 0 cm '
      '/Im0 Do Q\n',
    );
    bodies[contentNum] = _streamObject(
      '<< /Length ${content.length} >>',
      content,
      ascii,
    );

    final rows = _rgbRowsWithPngFilter(frame);
    // `ZLibEncoder` không dùng được ở đây: nó là AsynchronousEncoder (chỉ có
    // `encodeChunk`/`bind`), còn `ZLibCodec` thì có ctor là `factory` nên cũng
    // không bọc `const` được. Đường đúng cho dữ liệu đã nằm trong bộ nhớ:
    final compressed = ZLibCodec(level: 6).encode(rows);
    bodies[imageNum] = _streamObject(
      '<< /Type /XObject /Subtype /Image'
      ' /Width ${frame.pixelWidth} /Height ${frame.pixelHeight}'
      ' /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /FlateDecode'
      ' /DecodeParms << /Predictor 15 /Colors 3 /BitsPerComponent 8'
      ' /Columns ${frame.pixelWidth} >>'
      ' /Length ${compressed.length} >>',
      compressed,
      ascii,
    );
  }

  final info = StringBuffer('<< /Producer (${_literalString(producer)})');
  if (title != null && title.trim().isNotEmpty) {
    info.write(' /Title ${_textString(title.trim())}');
  }
  info.write(' /CreationDate (${_pdfDate(createdAt ?? DateTime.now())})');
  info.write(' /ModDate (${_pdfDate(createdAt ?? DateTime.now())})');
  info.write(' >>');
  bodies[infoNum] = ascii(info.toString());

  final out = BytesBuilder(copy: false);
  out.add(ascii('%PDF-1.7\n%'));
  out.add(Uint8List.fromList(<int>[0xE2, 0xE3, 0xCF, 0xD3, 0x0A]));

  final offsets = List<int>.filled(infoNum + 1, 0);
  for (var num = 1; num <= infoNum; num++) {
    offsets[num] = out.length;
    out.add(ascii('$num 0 obj\n'));
    out.add(bodies[num]!);
    out.add(ascii('endobj\n'));
  }

  final xrefOffset = out.length;
  final size = infoNum + 1;
  final xref = StringBuffer('xref\n0 $size\n0000000000 65535 f \n');
  for (var num = 1; num <= infoNum; num++) {
    xref.write('${offsets[num].toString().padLeft(10, '0')} 00000 n \n');
  }
  final id = _fileId(title: title, createdAt: createdAt ?? DateTime.now());
  xref.write('trailer\n<< /Size $size /Root 1 0 R /Info $infoNum 0 R'
      ' /ID [<$id> <$id>] >>\n');
  xref.write('startxref\n$xrefOffset\n%%EOF\n');
  out.add(ascii(xref.toString()));

  return out.toBytes();
}

List<int> _streamObject(
  String dict,
  List<int> payload,
  List<int> Function(String) ascii,
) {
  final builder = BytesBuilder(copy: false)
    ..add(ascii('$dict\nstream\n'))
    ..add(payload)
    ..add(ascii('\nendstream\n'));
  return builder.toBytes();
}

/// Hàng pixel dạng `filter(0) + RGB...` (PNG predictor, không lọc) — nén tốt
/// mà vẫn đơn giản, và giải được ngược trong test.
Uint8List _rgbRowsWithPngFilter(PdfSnapshotFrame frame) {
  final w = frame.pixelWidth, h = frame.pixelHeight;
  final rows = Uint8List(h * (1 + w * 3));
  final src = frame.bgra;
  var o = 0;
  for (var y = 0; y < h; y++) {
    rows[o++] = 0;
    var i = y * w * 4;
    for (var x = 0; x < w; x++, i += 4) {
      rows[o++] = src[i + 2]; // R
      rows[o++] = src[i + 1]; // G
      rows[o++] = src[i]; // B
    }
  }
  return rows;
}

String _num(double v) => v == v.roundToDouble()
    ? v.toInt().toString()
    : v.toStringAsFixed(2);

/// Chuỗi literal PDF: thoát 3 ký tự, bỏ ký tự điều khiển (title lấy từ tên file
/// của người dùng nên có thể chứa đủ thứ).
String _literalString(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ');
  return cleaned
      .replaceAll(r'\', r'\\')
      .replaceAll('(', r'\(')
      .replaceAll(')', r'\)');
}

/// Chuỗi Unicode: `<FEFF ...>` hex UTF-16BE. Đây là cách AN TOÀN cho tiếng Việt
/// có dấu — tên font base-14 không chứa đủ glyph và mã hoá Latin-1 sẽ ra rác.
/// Ký tự ngoài BMP bị loại (PDF text string không cần emoji ở đây).
String _textString(String value) {
  final units = <int>[];
  for (final rune in value.runes) {
    if (rune > 0xFFFF) continue;
    units.add((rune >> 8) & 0xFF);
    units.add(rune & 0xFF);
  }
  final bytes = Uint8List.fromList(units);
  return '<FEFF${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}>';
}

/// exposed cho test: đúng từng byte của `_textString`, không có BOM.
String pdfUtf16HexWithoutBom(String value) =>
    _textString(value).replaceAll('<FEFF', '').replaceAll('>', '');

/// `D:YYYYMMDDHHmmSS+00'00'` — định dạng date string của PDF.
String _pdfDate(DateTime value) {
  final v = value.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return 'D:${v.year.toString().padLeft(4, '0')}${two(v.month)}${two(v.day)}'
      '${two(v.hour)}${two(v.minute)}${two(v.second)}+00\'00\'';
}

/// /ID: 16 byte hex đủ tính nhận dạng (không cần đúng thuật toán của Acrobat —
/// Acrobat chỉ đòi có mặt khoá này, và file vẫn mở được nếu ID không khớp).
String _fileId({String? title, required DateTime createdAt}) {
  final seed = '${title ?? ''}|${createdAt.microsecondsSinceEpoch}';
  final hash = seed.codeUnits.fold<int>(0x811C9DC5, (h, c) {
    return ((h ^ c) * 0x01000193) & 0xFFFFFFFF;
  });
  final buf = StringBuffer();
  var v = hash;
  for (var i = 0; i < 16; i++) {
    v = ((v * 1103515245) + 12345 + i) & 0xFFFFFFFF;
    buf.write(((v >> 16) & 0xFF).toRadixString(16).padLeft(2, '0'));
  }
  return buf.toString();
}
