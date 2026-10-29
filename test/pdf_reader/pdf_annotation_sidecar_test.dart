// B1: sidecar là thứ duy nhất giữ được công sức đánh dấu khi người dùng đổi máy,
// nên test nặng về (1) round-trip không mất dữ liệu, (2) từ chối file lạ thay vì
// đoán, (3) merge không bao giờ xoá highlight của người dùng.
import 'dart:convert';
import 'dart:ui' show Color, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/pdf_reader/models/pdf_annotation.dart';
import 'package:in4up/features/pdf_reader/services/pdf_annotation_sidecar.dart';
import 'package:in4up/features/pdf_reader/services/pdf_xfdf_export.dart' show pdfXfdfFileName;

PdfAnnotation ann({
  String id = 'a1',
  int page = 2,
  AnnotationType type = AnnotationType.highlight,
  Rect bounds = const Rect.fromLTRB(10, 700, 90, 680),
  String text = 'văn bản đã chọn',
  String? note,
  int? start,
  int? end,
  int color = 0xFFFFD54F,
  DateTime? at,
  List<Rect> lines = const [],
}) =>
    PdfAnnotation(
      id: id,
      pageIndex: page,
      bounds: bounds,
      selectedText: text,
      note: note,
      color: Color(color),
      type: type,
      createdAt: at ?? DateTime.parse('2026-09-01 10:00:00Z'),
      textStartOffset: start,
      textEndOffset: end,
      lineRects: lines,
    );

PdfAnnotationSidecar sample({List<PdfAnnotation>? list}) => PdfAnnotationSidecar(
      fileName: 'Sách A.pdf',
      fileSize: 123456,
      fileModifiedMs: 1700000000000,
      pageCount: 210,
      lastPageIndex: 41,
      exportedAt: DateTime.parse('2026-09-06 08:30:00Z'),
      annotations: list ?? [ann()],
    );

void main() {
  group('round-trip', () {
    test('giữ nguyên từng trường của annotation', () {
      final src = PdfAnnotationSidecar(
        fileName: 'Báo cáo tháng 9.pdf',
        fileSize: 999,
        fileModifiedMs: 1700000000001,
        pageCount: 3,
        lastPageIndex: 2,
        exportedAt: DateTime.parse('2026-09-06 08:30:15Z'),
        annotations: [
          ann(
            id: 'h1',
            type: AnnotationType.highlight,
            text: 'chu & "<chữ>"',
            note: 'ghi chú có "trích dẫn" và <thẻ>',
            start: 12,
            end: 40,
            color: 0xFF80DEEA,
            lines: const [Rect.fromLTRB(1, 700, 50, 690), Rect.fromLTRB(50, 690, 90, 680)],
          ),
          ann(id: 'b1', page: 5, type: AnnotationType.bookmark, bounds: Rect.zero),
          ann(id: 'n1', page: 7, type: AnnotationType.note, note: 'ở đây'),
        ],
      );
      final decoded = decodePdfAnnotationSidecar(src.encode());
      expect(decoded.isSuccess, isTrue, reason: '${decoded.problem}');
      final back = decoded.sidecar!;
      expect(back.fileName, src.fileName);
      expect(back.fileSize, 999);
      expect(back.pageCount, 3);
      expect(back.lastPageIndex, 2);
      expect(back.exportedAt, src.exportedAt);
      expect(back.annotations.length, 3);

      final h = back.annotations.first;
      expect(h.id, 'h1');
      expect(h.selectedText, 'chu & "<chữ>"');
      expect(h.note, 'ghi chú có "trích dẫn" và <thẻ>');
      expect(h.color.toARGB32(), 0xFF80DEEA);
      expect(h.textStartOffset, 12);
      expect(h.textEndOffset, 40);
      expect(h.lineRects.length, 2);
      expect(h.lineRects.first, const Rect.fromLTRB(1, 700, 50, 690));
      expect(back.annotations[1].type, AnnotationType.bookmark);
      expect(back.annotations[2].note, 'ở đây');
    });

    test('json có format/version để người dùng sửa tay vẫn hiểu được', () {
      final map = jsonDecode(sample().encode()) as Map<String, dynamic>;
      expect(map['format'], kPdfAnnotationSidecarFormat);
      expect(map['version'], kPdfAnnotationSidecarVersion);
      expect((map['file'] as Map)['name'], 'Sách A.pdf');
      expect(map['annotations'], isList);
    });

    test('trường lạ bị bỏ qua (schema cũ đọc file của bản mới)', () {
      final map = sample().toJson()
        ..['version'] = kPdfAnnotationSidecarVersion
        ..['motTruongTuongLai'] = 'x';
      (map['annotations'] as List<dynamic>).first['truongLacLoai'] = 1;
      expect(decodePdfAnnotationSidecar(jsonEncode(map)).isSuccess, isTrue);
    });
  });

  group('từ chối có thông báo', () {
    test('không phải JSON / sai format / bản mới hơn / rỗng', () {
      expect(decodePdfAnnotationSidecar('chữ thường').problem, PdfSidecarProblem.notJson);
      expect(decodePdfAnnotationSidecar('[1,2,3]').problem, PdfSidecarProblem.wrongFormat);
      expect(
        decodePdfAnnotationSidecar(jsonEncode({
          'format': 'khac-app',
          'version': 1,
          'annotations': [],
        })).problem,
        PdfSidecarProblem.wrongFormat,
      );
      expect(
        decodePdfAnnotationSidecar(jsonEncode({
          'format': kPdfAnnotationSidecarFormat,
          'version': kPdfAnnotationSidecarVersion + 1,
          'annotations': [ann().toJson()],
        })).problem,
        PdfSidecarProblem.newerVersion,
      );
      expect(
        decodePdfAnnotationSidecar(jsonEncode({
          'format': kPdfAnnotationSidecarFormat,
          'version': 1,
          'annotations': [],
        })).problem,
        PdfSidecarProblem.noAnnotations,
      );
    });

    test('mọi problem đều có key catalog để UI dịch (rule #5)', () {
      for (final p in PdfSidecarProblem.values) {
        final key = PdfSidecarDecoding.failure(p).problemLabelKey;
        expect(key, isNotNull, reason: '$p thiếu nhãn thông báo');
        expect(key, isNot(contains('\n')));
      }
    });

    test('một dòng hỏng không làm hỏng cả tệp', () {
      final map = sample().toJson();
      (map['annotations'] as List<dynamic>).insert(0, 'không phải object');
      final decoded = decodePdfAnnotationSidecar(jsonEncode(map));
      expect(decoded.sidecar?.annotations.length, 1);
    });
  });

  group('đối chiếu file', () {
    test('same/changed/pageChanged/unknown', () {
      final s = sample();
      expect(
        compareSidecarToFile(sidecar: s, fileSize: 123456, fileModifiedMs: 1700000000000, pageCount: 210),
        PdfSidecarFileMatch.sameFile,
      );
      expect(
        compareSidecarToFile(sidecar: s, fileSize: 123456, fileModifiedMs: 1700000000999, pageCount: 210),
        PdfSidecarFileMatch.contentChanged,
      );
      expect(
        compareSidecarToFile(sidecar: s, fileSize: 123456, fileModifiedMs: 1700000000000, pageCount: 220),
        PdfSidecarFileMatch.pageChanged,
      );
      // Không stat được file (web) ⇒ không được khẳng định "cùng file".
      final noStats = PdfAnnotationSidecar(
        fileName: 'x', fileSize: -1, fileModifiedMs: -1, pageCount: 0,
        lastPageIndex: 0, exportedAt: DateTime(0), annotations: [ann()],
      );
      expect(
        compareSidecarToFile(sidecar: noStats, fileSize: 1, fileModifiedMs: 2, pageCount: 5),
        PdfSidecarFileMatch.unknown,
      );
    });
  });

  group('merge', () {
    test('trùng vị trí thì giữ bản mới hơn, không nhân đôi', () {
      final local = ann(id: 'L', at: DateTime.parse('2026-09-01 00:00:00Z'));
      final imported = ann(id: 'I', at: DateTime.parse('2026-09-05 00:00:00Z'));
      final merged = mergeSidecarAnnotations(local: [local], imported: [imported]);
      expect(merged, hasLength(1));
      expect(merged.single.id, 'I');
    });

    test('cùng thời điểm thì giữ bên có ghi chú dài hơn', () {
      final at = DateTime.parse('2026-09-03 00:00:00Z');
      final merged = mergeSidecarAnnotations(
        local: [ann(id: 'L', note: 'dài hơn nhiều nhé', at: at)],
        imported: [ann(id: 'I', note: 'ngắn', at: at)],
      );
      expect(merged.single.id, 'L');
    });

    test('không cùng vị trí thì giữ cả hai, sắp theo trang', () {
      final merged = mergeSidecarAnnotations(
        local: [ann(id: 'L', page: 9)],
        imported: [ann(id: 'I', page: 1, bounds: const Rect.fromLTRB(1, 100, 2, 90))],
      );
      expect(merged.map((a) => a.id).toList(), ['I', 'L']);
    });

    test('offset ký tự thắng toạ độ: hai highlight cùng offset là MỘT', () {
      final merged = mergeSidecarAnnotations(
        local: [ann(id: 'L', start: 5, end: 9, bounds: const Rect.fromLTRB(0, 0, 1, 1))],
        imported: [ann(id: 'I', start: 5, end: 9, bounds: const Rect.fromLTRB(300, 40, 320, 20))],
      );
      expect(merged, hasLength(1));
    });

    test('bookmark cùng trang cùng loại được gộp (id khác nhau không nhân đôi)', () {
      final merged = mergeSidecarAnnotations(
        local: [ann(id: 'L', page: 4, type: AnnotationType.bookmark, bounds: Rect.zero)],
        imported: [ann(id: 'I', page: 4, type: AnnotationType.bookmark, bounds: Rect.zero)],
      );
      expect(merged, hasLength(1));
    });
  });

  group('tên file', () {
    test('bỏ thư mục + đuôi .pdf, giữ dấu tiếng Việt, lọc ký tự cấm', () {
      expect(pdfExportBaseName('/storage/emulated/0/Sách A (final).pdf'),
          'Sách A (final)');
      expect(pdfExportBaseName(r'C:\Users\Nam\Báo cáo <9>.pdf'), 'Báo cáo _9_');
      expect(pdfExportBaseName('khong-phai-pdf.txt'), 'khong-phai-pdf.txt');
      expect(pdfSidecarFileName('/x/Y.pdf'), 'Y.in4up.json');
      expect(pdfSidecarFileName('/x/abc'), 'abc.in4up.json');
      // Hai tệp cạnh nhau phải cùng gốc, nếu không người dùng không biết cặp nào
      // đi với file nào khi thư mục có 20 cuốn sách.
      expect(pdfXfdfFileName('/x/Y.pdf'), 'Y.xfdf');
    });
  });
}
