// Text Mode + TTS dùng chung một chuỗi đã làm sạch; nếu hai bên sạch khác nhau thì
// offset lệch và "mở lại đúng chỗ" sai. Test này giữ hợp đồng làm sạch.
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/pdf_reader/services/pdf_text_extractor.dart';

void main() {
  group('PdfTextExtractor.cleanExtractedText', () {
    final extractor = PdfTextExtractor();
    String clean(String raw) => extractor.cleanExtractedText(raw);

    test('nối từ bị cắt cuối dòng', () {
      expect(clean('enlighten-\nment is here'), 'enlightenment is here');
    });

    test('bỏ soft hyphen do word-wrap', () {
      expect(clean('wa\u00ADter and pow\u00ADer'), 'water and powder');
    });

    test('không tự ý bỏ dấu gạch khi chữ sau viết hoa', () {
      // "Euro-\npe" là do PDF ngắt dòng sai ngữ cảnh; giữ nguyên dấu gạch để
      // người đọc còn thấy. Đổi hành vi này phải có chủ đích.
      expect(clean('Euro-\npe'), 'Euro-\npe');
    });

    test('gộp space thừa, giữ ngắt đoạn, cắt newline rỗng', () {
      expect(clean('a   b\t c'), 'a b\t c');
      expect(clean('para one\n\n\n\n\npara two'), 'para one\n\npara two');
      expect(clean('  spaced  '), 'spaced');
    });

    test('chuỗi rỗng an toàn', () {
      expect(clean(''), '');
      expect(clean('\n\n'), '');
    });
  });

  // `flutter analyze` của CI đã nổ ~20 error chỉ vì một dấu nháy đơn trong regex:
  // `RegExp(r'[.!?…]["\'…]*$')` — `\'` không thoát nháy trong raw string một nháy,
  // chuỗi cụt và parser đọc phần còn lại như mã nguồn. Pattern nằm trong
  // `PdfTextExtractor.sentenceEndPattern` (raw string 3 nháy) để test được trực tiếp.
  group('PdfTextExtractor.sentenceEndPattern', () {
    test('nhận dấu kết thúc câu kể cả khi có nháy/ngoặc đóng phía sau', () {
      expect(PdfTextExtractor.sentenceEndPattern.hasMatch('It is done.'), isTrue);
      expect(PdfTextExtractor.sentenceEndPattern.hasMatch('He said "yes."'), isTrue);
      expect(PdfTextExtractor.sentenceEndPattern.hasMatch('Đi (hết).'), isTrue);
      expect(PdfTextExtractor.sentenceEndPattern.hasMatch('Vậy à?'), isTrue);
    });

    test('không nhận dòng chưa kết thúc (heading, câu dở)', () {
      expect(PdfTextExtractor.sentenceEndPattern.hasMatch('Chapter 3'), isFalse);
      expect(PdfTextExtractor.sentenceEndPattern.hasMatch('n = 1.5'), isFalse);
      expect(PdfTextExtractor.sentenceEndPattern.hasMatch(''), isFalse);
    });
  });
}
