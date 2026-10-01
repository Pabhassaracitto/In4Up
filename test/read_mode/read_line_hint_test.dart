// I4U18-READ-IPA-001 (Agent F · F1.2/F1.3) — luật hiện gợi ý chế độ dòng.
//
// Gợi ý phải đủ hữu ích (mở Word là thấy) nhưng không được phiền: một lần
// cho mỗi tài liệu, và tắt hẳn khi người dùng đã bảo "đừng nhắc lại" —
// lúc đó vẫn mở lại được bằng nút Trợ giúp (đường `force`, không đi qua
// hàm này).

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/screens/read_mode/services/read_line_hint_service.dart';

void main() {
  group('nhận diện nguồn chữ theo dòng', () {
    test('Word/DOCX và các nguồn chữ khác đều là nguồn theo dòng', () {
      expect(isLineModeTextSource('/sdcard/Download/Kinh.docx'), isTrue);
      expect(isLineModeTextSource(r'C:\Docs\bai giang.DOCX'), isTrue);
      expect(isLineModeTextSource('/x/notes.md'), isTrue);
      expect(isLineModeTextSource('/x/transcript.txt'), isTrue);
      expect(isLineModeTextSource('/x/lyrics.lrc'), isTrue);
    });

    test('PDF / ảnh / không có đường dẫn thì không nhắc', () {
      expect(isLineModeTextSource('/x/sach.pdf'), isFalse);
      expect(isLineModeTextSource('/x/trang.jpg'), isFalse);
      expect(isLineModeTextSource(null), isFalse);
      expect(isLineModeTextSource('khong-co-duoi'), isFalse);
    });

    test('nhận riêng nguồn Word để đổi câu nhắc', () {
      expect(isWordSource('/x/a.docx'), isTrue);
      expect(isWordSource('/x/a.doc'), isTrue);
      expect(isWordSource('/x/a.md'), isFalse);
    });

    test('lấy đuôi file chịu được cả dấu / và \\', () {
      expect(readSourceExtension('/a/b/c.TXT'), 'txt');
      expect(readSourceExtension(r'C:\a\b\c.Docx'), 'docx');
      expect(readSourceExtension('/a/b/c.'), '');
      expect(readSourceExtension('/a/b/.hidden'), '');
    });
  });

  group('shouldAutoShowLineHint', () {
    bool call({
      String? path = '/x/bai.docx',
      String? documentId = 'doc-1',
      bool dismissed = false,
      String? lastShown,
      bool hasLines = true,
    }) =>
        shouldAutoShowLineHint(
          path: path,
          documentId: documentId,
          dismissedForever: dismissed,
          lastShownDocumentId: lastShown,
          hasLines: hasLines,
        );

    test('mở Word lần đầu → nhắc', () => expect(call(), isTrue));

    test('cùng tài liệu đó lần hai → không nhắc lại', () {
      expect(call(lastShown: 'doc-1'), isFalse);
    });

    test('tài liệu KHÁC → nhắc lại', () {
      expect(call(documentId: 'doc-2', lastShown: 'doc-1'), isTrue);
    });

    test('đã bảo đừng nhắc lại → im', () {
      expect(call(dismissed: true), isFalse);
    });

    test('chưa có dòng nào (tài liệu rỗng) → im', () {
      expect(call(hasLines: false), isFalse);
    });

    test('chưa có tài liệu → im', () {
      expect(call(documentId: null), isFalse);
      expect(call(documentId: ''), isFalse);
    });

    test('nguồn PDF → im (PDF Reader có hướng dẫn riêng)', () {
      expect(call(path: '/x/sach.pdf'), isFalse);
    });
  });
}
