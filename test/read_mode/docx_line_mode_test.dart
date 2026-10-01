// I4U18-READ-IPA-001 (Agent F · F1) — chế độ dòng khi mở Word/DOCX.
//
// Lỗi gốc: `docxXmlToPlainText` xuất ranh giới đoạn bằng MỘT `\n`, còn
// `TextSplitterService` (chế độ smart — mặc định của tab Đọc) chỉ coi
// `\n\s*\n` là ranh giới cứng. Hệ quả: các đoạn Word không kết bằng dấu
// `.`/`!`/`?` (tiêu đề, kệ, gạch đầu dòng, thơ) bị DÍNH lại thành một "dòng"
// khổng lồ → chạm dòng không ra IPA/tra từ theo dòng.
//
// Test này khoá hành vi đúng ở CẢ HAI tầng: text_source_loader xuất dòng
// trống, và splitter cho ra đúng số dòng đọc.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/services/text_source_loader.dart';
import 'package:in4up/services/text_splitter_service.dart';

void main() {
  group('DOCX → chế độ dòng', () {
    test('mỗi đoạn Word là một ranh giới cứng (dòng trống)', () {
      const xml = '''
<w:p><w:r><w:t>Kinh Chuyển Pháp Luân</w:t></w:r></w:p>
<w:p><w:r><w:t>Phần một</w:t></w:r></w:p>
<w:p><w:r><w:t>Phần hai</w:t></w:r></w:p>
''';

      expect(
        TextSourceLoader.docxXmlToPlainText(xml),
        'Kinh Chuyển Pháp Luân\n\nPhần một\n\nPhần hai',
      );
    });

    test('ba đoạn KHÔNG có dấu câu vẫn ra ba dòng đọc (lỗi cũ: 1 dòng)', () {
      const xml = '''
<w:p><w:r><w:t>Kinh Chuyển Pháp Luân</w:t></w:r></w:p>
<w:p><w:r><w:t>Phần một</w:t></w:r></w:p>
<w:p><w:r><w:t>Phần hai</w:t></w:r></w:p>
''';

      final text = TextSourceLoader.docxXmlToPlainText(xml)!;
      final lines = TextSplitterService.split(text, mode: SplitMode.smart);

      expect(lines, [
        'Kinh Chuyển Pháp Luân',
        'Phần một',
        'Phần hai',
      ]);
    });

    test('xuống dòng mềm (Shift+Enter) cũng là một dòng đọc', () {
      const xml = '''
<w:p><w:r><w:t>Dòng trên</w:t></w:r><w:br/><w:r><w:t>Dòng dưới</w:t></w:r></w:p>
''';

      final text = TextSourceLoader.docxXmlToPlainText(xml)!;
      expect(
        TextSplitterService.split(text, mode: SplitMode.smart),
        ['Dòng trên', 'Dòng dưới'],
      );
    });

    test('đoạn văn xuôi nhiều câu vẫn tách theo câu như cũ', () {
      const xml = '''
<w:p><w:r><w:t>Câu một. Câu hai! Câu ba?</w:t></w:r></w:p>
''';

      final text = TextSourceLoader.docxXmlToPlainText(xml)!;
      expect(
        TextSplitterService.split(text, mode: SplitMode.smart),
        ['Câu một.', 'Câu hai!', 'Câu ba?'],
      );
    });

    test('nhiều đoạn trống liên tiếp không sinh dòng rỗng', () {
      const xml = '''
<w:p><w:r><w:t>Trên</w:t></w:r></w:p>
<w:p></w:p>
<w:p></w:p>
<w:p><w:r><w:t>Dưới</w:t></w:r></w:p>
''';

      final text = TextSourceLoader.docxXmlToPlainText(xml)!;
      expect(
        TextSplitterService.split(text, mode: SplitMode.smart),
        ['Trên', 'Dưới'],
      );
    });

    test('run bị Word cắt nhỏ trong CÙNG đoạn vẫn nối lại thành một dòng', () {
      const xml = '''
<w:p>
  <w:r><w:t>ng</w:t></w:r>
  <w:r><w:t>ườ</w:t></w:r>
  <w:r><w:t>i</w:t></w:r>
  <w:r><w:t xml:space="preserve"> </w:t></w:r>
  <w:r><w:t>Việt</w:t></w:r>
</w:p>
''';

      final text = TextSourceLoader.docxXmlToPlainText(xml)!;
      expect(TextSplitterService.split(text, mode: SplitMode.smart),
          ['người Việt']);
    });
  });
}
