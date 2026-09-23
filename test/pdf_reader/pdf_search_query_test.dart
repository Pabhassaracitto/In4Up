// Tìm trong file PDF cho người Việt: hoa/thường, có dấu hay không có dấu, và
// snippet ngữ cảnh. Ba hàm này thuần -> test được không cần pdfrx/PdfRenderer.
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/pdf_reader/services/pdf_search_query.dart';

void main() {
  group('isPdfSearchQueryMeaningful', () {
    test('1 ký tự hoặc toàn khoảng trắng thì không quét cả sách', () {
      expect(isPdfSearchQueryMeaningful('a'), isFalse);
      expect(isPdfSearchQueryMeaningful('   '), isFalse);
      expect(isPdfSearchQueryMeaningful('ab'), isTrue);
      expect(isPdfSearchQueryMeaningful('  cả  '), isTrue);
    });
  });

  group('buildPdfSearchPattern', () {
    test('query rỗng -> null (không dựng regex khớp mọi thứ)', () {
      expect(buildPdfSearchPattern(''), isNull);
      expect(buildPdfSearchPattern('   '), isNull);
    });

    test('mặc định: tôn trọng dấu, bỏ qua hoa/thường', () {
      final p = buildPdfSearchPattern('PhẢI')!;
      expect(p.hasMatch('phải rồi'), isTrue);
      expect(p.hasMatch('PHẢI'), isTrue);
      expect(p.hasMatch('phai roi'), isFalse,
          reason: 'không bật ignoreTones thì "phai" không được khớp "phải"');
    });

    test('ignoreTones: khớp hai chiều, giữ nguyên độ dài chuỗi', () {
      final fromToned = buildPdfSearchPattern('thăn', ignoreTones: true)!;
      expect(fromToned.hasMatch('than'), isTrue);
      expect(fromToned.hasMatch('thăn'), isTrue);
      expect(fromToned.hasMatch('THĂN'), isTrue);

      final fromPlain = buildPdfSearchPattern('nam mo', ignoreTones: true)!;
      expect(fromPlain.hasMatch('năm mô'), isTrue);
      expect(fromPlain.hasMatch('nam mo'), isTrue);
    });

    test('đ <-> d', () {
      final p = buildPdfSearchPattern('đi', ignoreTones: true)!;
      expect(p.hasMatch('DI'), isTrue);
      expect(p.hasMatch('đi'), isTrue);
      expect(p.hasMatch('di'), isTrue);
    });

    test('gộp a/ă/â là CÓ Ý, nhưng offset vẫn 1:1 nên highlight không lệch', () {
      final p = buildPdfSearchPattern('cân', ignoreTones: true)!;
      expect(p.hasMatch('cân'), isTrue);
      expect(p.hasMatch('cẦn'), isTrue);
      expect(p.hasMatch('can'), isTrue,
          reason: 'bật "không phân biệt dấu" là để tìm kiểu gõ liền không dấu');

      // Cái ta KHÔNG cho phép: co giãn aa <-> â (sẽ làm lệch offset kết quả).
      const full = 'aa cấp và â cấp';
      final m = buildPdfSearchPattern('â', ignoreTones: true)!.firstMatch(full)!;
      expect(full.substring(m.start, m.end), 'â');
      expect(m.end - m.start, 1);
    });

    test('escape ký tự đặc biệt: query là văn bản, không phải regex', () {
      expect(buildPdfSearchPattern('a.b')!.hasMatch('axb'), isFalse);
      expect(buildPdfSearchPattern('a.b')!.hasMatch('a.b'), isTrue);
      expect(buildPdfSearchPattern(r'c++')!.hasMatch('c++'), isTrue);
      expect(buildPdfSearchPattern('(x)')!.hasMatch('(x)'), isTrue);
      // Ký tự có ý nghĩa đặc biệt bên trong `[...]` cũng phải escape.
      expect(buildPdfSearchPattern('^a', ignoreTones: true)!.hasMatch('^a'),
          isTrue);
      expect(buildPdfSearchPattern('a]b')!.hasMatch('a]b'), isTrue);
    });

    test('khoảng trắng trong query khớp cả xuống dòng của PDF', () {
      final p = buildPdfSearchPattern('hello world')!;
      expect(p.hasMatch('hello\n     world'), isTrue);
      expect(p.hasMatch('hello world'), isTrue);
      expect(p.hasMatch('helloworld'), isFalse);
    });

    test('start/end của match trỏ đúng vị trí trong fullText', () {
      const full = 'Giới thiệu về Machine Learning và học máy.';
      final p = buildPdfSearchPattern('machine', ignoreTones: true)!;
      final m = p.firstMatch(full)!;
      expect(full.substring(m.start, m.end).toLowerCase(), 'machine');
    });
  });

  group('pdfSearchSnippet', () {
    test('gấp khoảng trắng và thêm dấu ba chấm khi cắt', () {
      final text = 'Một dòng rất dài  chứa\nnhiều  khoảng trắng để kiểm tra '
          'viết tắt quanh từ khóa nào đó trong trang.';
      final at = text.indexOf('từ khóa');
      final snippet = pdfSearchSnippet(text, at, at + 'từ khóa'.length,
          radius: 12);
      expect(snippet, contains('từ khóa'));
      expect(snippet, startsWith('…'));
      expect(snippet, endsWith('…'));
      expect(snippet, isNot(contains('\n')));
      expect(snippet, isNot(contains('  ')));
    });

    test('đầu/cuối trang không bị cắt oan, chuỗi ngắn trả nguyên văn', () {
      expect(pdfSearchSnippet('abcdef', 0, 3), 'abcdef');
      expect(pdfSearchSnippet('abcdef', 3, 6), 'abcdef');
      expect(pdfSearchSnippet('x', 0, 1), 'x');
    });

    test('index ngoài phạm vi được clamp, không RangeError', () {
      expect(() => pdfSearchSnippet('abc', 5, 9), returnsNormally);
      expect(pdfSearchSnippet('abc', 99, 99), isNotEmpty);
      expect(pdfSearchSnippet('', 0, 0), '');
      // start > end (khớp rỗng/đảo chiều) cũng không được ném.
      expect(() => pdfSearchSnippet('abcdef', 4, 1), returnsNormally);
    });
  });
}
