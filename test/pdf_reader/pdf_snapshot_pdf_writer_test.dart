// B2: tệp PDF tự viết tay thì không có "chạy thử trên máy in" nào ở CI, nên test
// phải tự đóng vai trình đọc: kiểm offset trong bảng xref trỏ ĐÚNG vào object,
// kiểm /Length sát với dòng stream thật, và GIẢI NÉN lại ảnh để chứng minh phần
// Predictor 15 không sai một byte.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/pdf_reader/services/pdf_snapshot_pdf_writer.dart';

PdfSnapshotFrame frame({
  int w = 2,
  int h = 1,
  double pageW = 595,
  double pageH = 842,
  List<int>? bgra,
}) {
  final px = Uint8List.fromList(
    bgra ?? <int>[30, 20, 10, 255, 60, 50, 40, 255], // BGRA: (10,20,30) & (40,50,60)
  );
  return PdfSnapshotFrame(
    pixelWidth: w,
    pixelHeight: h,
    pageWidthPts: pageW,
    pageHeightPts: pageH,
    bgra: px,
  );
}

/// Tìm nội dung object `n` (giữa `n 0 obj` và `endobj`) trong tệp PDF.
///
/// `latin1.decode` là cách đọc byte-as-ASCII ngắn nhất; an toàn vì latin1 ánh xạ
/// đủ 0..255 (không bao giờ ném). `allowMalformed` KHÔNG tồn tại trên `Codec.decode`
/// (nó là tham số riêng của `Utf8Decoder`), nên đừng có thêm vào.
Uint8List objectBytes(Uint8List pdf, int n) {
  final text = latin1.decode(pdf);
  final start = text.indexOf('$n 0 obj');
  expect(start, greaterThan(-1), reason: 'không tìm thấy object $n');
  final end = text.indexOf('endobj', start);
  expect(end, greaterThan(start));
  return Uint8List.sublistView(pdf, start, end);
}

/// Đọc một stream object: vừa trả về nội dung, vừa **kiểm `/Length` bằng khoảng
/// cách thật** giữa `\nstream\n` và `\nendstream`. Đây là lỗi chết người điển
/// hình của PDF tự viết: lệch 1 byte là mọi trình đọc báo file hỏng.
({int length, Uint8List stream}) streamOf(Uint8List pdf, int n) {
  final obj = objectBytes(pdf, n);
  final text = latin1.decode(obj);
  final declared = int.parse(RegExp(r'/Length (\d+)').firstMatch(text)!.group(1)!);
  const marker = '\nstream\n';
  final start = text.indexOf(marker) + marker.length;
  expect(start, greaterThan(marker.length - 1), reason: 'thiếu keyword stream');
  final end = text.indexOf('\nendstream', start);
  expect(end - start, declared, reason: 'object $n: /Length khai báo != số byte thật');
  return (length: declared, stream: Uint8List.sublistView(obj, start, end));
}

void main() {
  test('từ chối dữ liệu rác thay vì xuất file hỏng', () {
    expect(() => buildPdfFromSnapshotFrames(frames: const []),
        throwsA(isA<ArgumentError>()));
    expect(
      () => buildPdfFromSnapshotFrames(frames: [frame(w: 3, h: 3)]),
      throwsA(isA<ArgumentError>()),
      reason: 'pixelWidth*height*4 != số byte => phải báo, không được cắt ảnh',
    );
  });

  test('mở đầu %PDF-1.7 + dòng nhị phân, kết thúc %%EOF', () {
    final pdf = buildPdfFromSnapshotFrames(frames: [frame()]);
    expect(latin1.decode(Uint8List.sublistView(pdf, 0, 9)), '%PDF-1.7\n');
    expect(pdf[10], 0xE2, reason: 'cần byte >127 để tool coi đây là binary');
    expect(latin1.decode(pdf).trimRight().endsWith('%%EOF'), isTrue);
  });

  test('catalog/pages đúng cho 3 trang', () {
    final pdf = buildPdfFromSnapshotFrames(frames: [frame(), frame(), frame()]);
    final catalog = latin1.decode(objectBytes(pdf, 1));
    expect(catalog, contains('/Type /Catalog'));
    expect(catalog, contains('/Pages 2 0 R'));
    final pages = latin1.decode(objectBytes(pdf, 2));
    expect(pages, contains('/Count 3'));
    // 3 trang -> obj 3,6,9 (page), kids phải trỏ đúng ba số chẵn đầu của dãy 3*i
    final kids = RegExp(r'/Kids \[(.*?)\]').firstMatch(pages)!.group(1)!;
    expect(kids.trim().split(RegExp(r'\s+')), ['3', '0', 'R', '6', '0', 'R', '9', '0', 'R']);
  });

  test('MediaBox theo point, content stream scale ảnh đúng khổ trang', () {
    final pdf = buildPdfFromSnapshotFrames(frames: [frame(pageW: 612, pageH: 792)]);
    final page = latin1.decode(objectBytes(pdf, 3));
    expect(page, contains('/MediaBox [0 0 612 792]'));
    expect(page, contains('/XObject << /Im0 5 0 R >>'));
    expect(page, contains('/Contents 4 0 R'));
    final content = latin1.decode(streamBytes(pdf, 4));
    expect(content, contains('q 612 0 0 792 0 0 cm /Im0 Do Q'));
  });

  test('ảnh: /Length khớp, và giải nén ra ĐÚNG từng byte hàng RGB', () {
    final pdf = buildPdfFromSnapshotFrames(frames: [frame()]);
    final img = latin1.decode(objectBytes(pdf, 5));
    expect(img, contains('/Width 2'));
    expect(img, contains('/Height 1'));
    expect(img, contains('/ColorSpace /DeviceRGB'));
    expect(img, contains('/Filter /FlateDecode'));
    expect(img, contains('/Predictor 15 /Colors 3 /BitsPerComponent 8 /Columns 2'));

    final s = streamOf(pdf, 5);
    final rows = ZLibCodec().decode(s.stream);
    // 1 dòng: [filter=0][R G B][R G B]
    expect(rows, <int>[0, 10, 20, 30, 40, 50, 60]);
    expect(s.length, greaterThan(0));
  });

  test('xref: mọi offset trỏ đúng vào "<n> 0 obj", số bản ghi = /Size', () {
    final pdf = buildPdfFromSnapshotFrames(frames: [frame(), frame()]);
    final text = latin1.decode(pdf);
    final xrefAt = text.lastIndexOf('\nxref\n');
    expect(xrefAt, greaterThan(0));
    final headerMatch = RegExp(r'xref\n0 (\d+)\n').firstMatch(text.substring(xrefAt))!;
    final size = int.parse(headerMatch.group(1)!);
    // 2 trang -> 1,2 catalog/pages + 3*(page,content,image) + info = 9 obj, +1 free
    expect(size, 10);
    var cursor = text.indexOf('\n', text.indexOf('xref\n0 $size')) + 1;
    final entries = <int>[];
    for (var n = 0; n < size; n++) {
      entries.add(int.parse(text.substring(cursor, cursor + 10)));
      cursor += 20;
    }
    expect(entries.first, 0, reason: 'bản ghi 0 là slot tự do');
    for (var n = 1; n < size; n++) {
      final at = entries[n];
      expect(text.substring(at, at + '$n 0 obj'.length), '$n 0 obj',
          reason: 'xref entry $n trỏ sai -> Acrobat sẽ báo file hỏng');
    }
    final startXref = RegExp(r'startxref\n(\d+)\n').firstMatch(text)!.group(1)!;
    expect(int.parse(startXref), xrefAt + 1);
    expect(text, contains('/Root 1 0 R'));
    expect(text, contains('/Info 9 0 R'));
  });

  group('metadata an toàn với tiếng Việt', () {
    test('/Title là hex UTF-16BE có BOM, không phải Latin-1', () {
      final pdf = buildPdfFromSnapshotFrames(
        frames: [frame()],
        title: 'Báo cáo',
        createdAt: DateTime.utc(2026, 9, 6, 7, 8, 9),
      );
      final info = latin1.decode(objectBytes(pdf, 6));
      expect(info, contains('/Title <FEFF'));
      expect(info, contains(pdfUtf16HexWithoutBom('Báo')));
      expect(info, contains("/CreationDate (D:20260906070809+00'00')"));
      expect(info, contains('/Producer (In4Up)'));
    });

    test('Producer có ngoặc đơn/backslash bị thoát, ký tự điều khiển bị loại', () {
      final pdf = buildPdfFromSnapshotFrames(
        frames: [frame()],
        title: 'a(b)c\\d',
        producer: 'x\ty(z)\\w',
      );
      final info = latin1.decode(objectBytes(pdf, 6));
      expect(info, contains(r'/Producer (x y\(z\)\\w)'));
      expect(pdfUtf16HexWithoutBom('a(b)c\\d'), contains('0028'));
    });

    test('/ID là 32 chữ số hex và ổn định cho cùng đầu vào', () {
      final a = latin1.decode(buildPdfFromSnapshotFrames(
          frames: [frame()], title: 'x', createdAt: DateTime.utc(2026)));
      final b = latin1.decode(buildPdfFromSnapshotFrames(
          frames: [frame()], title: 'x', createdAt: DateTime.utc(2026)));
      final id = RegExp(r'/ID \[<([0-9a-f]{32})> <\1>\]').firstMatch(a);
      expect(id, isNotNull, reason: 'ID phải 16 byte hex, hai nửa giống nhau');
      expect(RegExp(r'/ID \[<([0-9a-f]{32})> <\1>\]').hasMatch(b), isTrue);
    });
  });

  test('khổ trang lẻ (sách scan) không làm hỏng số học', () {
    final pdf = buildPdfFromSnapshotFrames(
      frames: [frame(w: 3, h: 2, pageW: 595.28, pageH: 841.89,
          bgra: List<int>.filled(3 * 2 * 4, 128))],
    );
    final page = latin1.decode(objectBytes(pdf, 3));
    expect(page, contains('/MediaBox [0 0 595.28 841.89]'));
    final rows = ZLibCodec().decode(streamOf(pdf, 5).stream);
    expect(rows.length, 2 * (1 + 3 * 3));
    expect(rows[0], 0);
    expect(rows.sublist(1, 4), <int>[128, 128, 128]);
  });
}

Uint8List streamBytes(Uint8List pdf, int n) => streamOf(pdf, n).stream;
