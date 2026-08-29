import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/services/syntax_highlighter_service.dart';
import 'package:in4up/services/text_source_loader.dart';

void main() {
  group('docxXmlToPlainText', () {
    test('joins Vietnamese runs split by Word XML pretty-print', () {
      const xml = '''
<w:document>
  <w:body>
    <w:p>
      <w:r><w:t>Xin</w:t></w:r>
      <w:r><w:t xml:space="preserve"> chào </w:t></w:r>
      <w:r><w:t>Việt</w:t></w:r>
      <w:r><w:t xml:space="preserve"> </w:t></w:r>
      <w:r><w:t>Nam</w:t></w:r>
    </w:p>
  </w:body>
</w:document>
''';

      expect(
        TextSourceLoader.docxXmlToPlainText(xml),
        'Xin chào Việt Nam',
      );
    });

    test('joins character-level proofing runs in one paragraph', () {
      const xml = '''
<w:p>
  <w:r><w:t>ng</w:t></w:r>
  <w:r><w:t>ườ</w:t></w:r>
  <w:r><w:t>i</w:t></w:r>
  <w:r><w:t xml:space="preserve"> </w:t></w:r>
  <w:r><w:t>V</w:t></w:r>
  <w:r><w:t>iệ</w:t></w:r>
  <w:r><w:t>t</w:t></w:r>
</w:p>
''';

      expect(TextSourceLoader.docxXmlToPlainText(xml), 'người Việt');
    });

    test('keeps real paragraph and break boundaries', () {
      const xml = '''
<w:p><w:r><w:t>Đoạn một</w:t></w:r></w:p>
<w:p><w:r><w:t>Dòng</w:t></w:r><w:br/><w:r><w:t>kế</w:t></w:r></w:p>
''';

      expect(
        TextSourceLoader.docxXmlToPlainText(xml),
        'Đoạn một\nDòng\nkế',
      );
    });

    test('decodes entities and skips field instrText', () {
      const xml = '''
<w:p>
  <w:r><w:instrText> HYPERLINK "https://example.com" </w:instrText></w:r>
  <w:r><w:t>Xem &amp; đọc</w:t></w:r>
</w:p>
''';

      expect(TextSourceLoader.docxXmlToPlainText(xml), 'Xem & đọc');
    });
  });

  group('SyntaxHighlighterService.tokenizeText', () {
    test('keeps Vietnamese words whole', () {
      expect(
        SyntaxHighlighterService.tokenizeText('Xin chào Việt Nam, người ơi!'),
        ['Xin', 'chào', 'Việt', 'Nam', ',', 'người', 'ơi', '!'],
      );
    });

    test('keeps Pali diacritics in one token', () {
      expect(
        SyntaxHighlighterService.tokenizeText('Dhammapada saṃsāra ñāṇa'),
        ['Dhammapada', 'saṃsāra', 'ñāṇa'],
      );
    });

    test('still splits English words and punctuation', () {
      expect(
        SyntaxHighlighterService.tokenizeText("Don't stop."),
        ["Don't", 'stop', '.'],
      );
    });
  });
}
