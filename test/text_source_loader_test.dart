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

  group('docxToPlainText ZIP', () {
    test('inflates deflated word/document.xml (Word/LibreOffice style)', () {
      final bytes = _minimalDocxZip(
        '<w:p><w:r><w:t>Xin chào Việt Nam</w:t></w:r></w:p>',
        deflate: true,
      );
      expect(TextSourceLoader.looksLikeZip(bytes), isTrue);
      expect(TextSourceLoader.looksLikeOleDoc(bytes), isFalse);
      expect(
        TextSourceLoader.docxToPlainText(bytes),
        'Xin chào Việt Nam',
      );
    });

    test('reads stored (method 0) word/document.xml', () {
      final bytes = _minimalDocxZip(
        '<w:p><w:r><w:t>Stored run</w:t></w:r></w:p>',
        deflate: false,
      );
      expect(TextSourceLoader.docxToPlainText(bytes), 'Stored run');
    });

    test('rejects OLE .doc magic', () {
      expect(
        TextSourceLoader.looksLikeOleDoc(
          Uint8List.fromList([0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]),
        ),
        isTrue,
      );
    });
  });
}

/// Local-file-header-only ZIP (parser không cần central directory).
Uint8List _minimalDocxZip(String innerXml, {required bool deflate}) {
  final xml = utf8.encode(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
    '$innerXml'
    '</w:document>',
  );
  final name = utf8.encode('word/document.xml');
  final payload = deflate
      ? Uint8List.fromList(ZLibEncoder(raw: true).convert(xml))
      : Uint8List.fromList(xml);
  final method = deflate ? 8 : 0;
  final out = BytesBuilder();
  void u16(int v) {
    out.addByte(v & 0xff);
    out.addByte((v >> 8) & 0xff);
  }

  void u32(int v) {
    out.addByte(v & 0xff);
    out.addByte((v >> 8) & 0xff);
    out.addByte((v >> 16) & 0xff);
    out.addByte((v >> 24) & 0xff);
  }

  out.add([0x50, 0x4B, 0x03, 0x04]);
  u16(20);
  u16(0);
  u16(method);
  u16(0); // time
  u16(0); // date
  u32(0); // crc ignored
  u32(payload.length);
  u32(xml.length);
  u16(name.length);
  u16(0);
  out.add(name);
  out.add(payload);
  return out.toBytes();
}
