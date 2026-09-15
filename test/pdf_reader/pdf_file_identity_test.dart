// Mọi thứ người đọc tạo (highlight, ghi chú, trang cuối, từ đã lưu) bị khoá
// theo đường dẫn. ReadEra giữ trạng thái theo chính file nên "đổi tên / chuyển
// thư mục / copy từ chỗ khác" không mất gì. Test này chốt hành vi đó.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/pdf_reader/services/pdf_file_identity.dart';

void main() {
  group('pdfBaseName', () {
    test('cắt được cả / và \\ (Windows trả về tên, không phải cả chuỗi)', () {
      expect(pdfBaseName(r'C:\Users\anht\Docs\Sách.pdf'), 'Sách.pdf');
      expect(pdfBaseName('/data/user/0/files/Sách.pdf'), 'Sách.pdf');
      expect(pdfBaseName('Sách.pdf'), 'Sách.pdf');
      expect(pdfBaseName(r'\\\\nas\\share\\a\\b.pdf'), 'b.pdf');
    });

    test('bỏ dấu / thừa ở cuối, an toàn với chuỗi rỗng', () {
      expect(pdfBaseName('/a/b/'), 'b');
      expect(pdfBaseName('///'), '');
      expect(pdfBaseName(''), '');
    });
  });

  group('pdfDisplayName', () {
    test('lược phần mở rộng và cắt dài bằng dấu …', () {
      expect(pdfDisplayName('/x/Introduction to Grammar.pdf'),
          'Introduction to Grammar');
      final long = pdfDisplayName('/x/${'A' * 80}.pdf', maxLength: 20);
      expect(long.length, 20);
      expect(long.endsWith('…'), isTrue);
    });
  });

  group('pdfSourceMatches', () {
    test('khớp tên hiển thị với đường dẫn đầy đủ (lỗ hổng WordList panel)', () {
      expect(
        pdfSourceMatches('Sách.pdf', '/data/user/0/com/files/Sách.pdf'),
        isTrue,
      );
      expect(pdfSourceMatches('Sách.pdf', r'C:\Docs\Sách.pdf'), isTrue);
      expect(pdfSourceMatches('sách.PDF', '/docs/Sách.pdf'), isTrue);
      expect(
        pdfSourceMatches('file:///docs/My%20Book.pdf', '/docs/My Book.pdf'),
        isTrue,
      );
    });

    test('hai file khác tên không được khớp', () {
      expect(pdfSourceMatches('A.pdf', '/docs/B.pdf'), isFalse);
      expect(pdfSourceMatches('', '/docs/B.pdf'), isFalse);
      expect(pdfSourceMatches('Grammar.pdf', '/docs/Advanced Grammar.pdf'),
          isFalse);
    });

    test('so với tên có dấu cách đầu/cuỗi vẫn khớp', () {
      expect(pdfSourceMatches('  Sách.pdf  ', '/docs/Sách.pdf'), isTrue);
    });
  });

  group('PdfFileIdentity keys', () {
    test('pathKey bền với cách viết đường dẫn', () {
      final a = PdfFileIdentity.hashPath(r'C:\\Docs\\Sách.pdf');
      final b = PdfFileIdentity.hashPath('c:/docs/sách.pdf');
      expect(a, b);
      expect(PdfFileIdentity.normalizePath('  '), 'pdf');
    });

    test('legacyKey giữ nguyên công thức cũ để còn đọc dữ liệu cũ', () {
      const path = '/docs/old.pdf';
      expect(PdfFileIdentity.legacyKeyFor(path),
          '${path.hashCode.abs()}');
      expect(PdfFileIdentity.legacyKeyFor(path),
          isNot(PdfFileIdentity.hashPath(path)));
    });

    test('identity cache trả cùng một object cho cùng đường dẫn', () {
      final first = PdfFileIdentity.resolveSync('/docs/cache-me.pdf');
      final second = PdfFileIdentity.resolveSync('/docs/cache-me.pdf');
      expect(identical(first, second), isTrue);
      expect(first.hasStat, isFalse); // file không tồn tại
      expect(first.primaryKey, first.pathKey); // -> dùng pathKey dự phòng
      PdfFileIdentity.forget('/docs/cache-me.pdf');
      expect(identical(first, PdfFileIdentity.resolveSync('/docs/cache-me.pdf')),
          isFalse);
    });
  });

  group(' PdfFileIdentity.resolve — bền khi di chuyển file', () {
    late Directory tempDir;

    setUp(() => tempDir = Directory.systemTemp.createTempSync('pdf_id_'));
    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('đổi tên / đổi thư mục vẫn cùng primaryKey (nội dung + mtime giữ nguyên)',
        () async {
      final bytes = List<int>.generate(4096, (i) => i % 251);
      final when = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      final original = File('${tempDir.path}/A.pdf')..writeAsBytesSync(bytes);
      original.setLastModifiedSync(when);

      final moved = File('${tempDir.path}/sub/B-final.pdf')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);
      moved.setLastModifiedSync(when);

      final before = await PdfFileIdentity.resolve(original.path);
      final after = await PdfFileIdentity.resolve(moved.path);

      expect(before.hasStat, isTrue);
      expect(after.hasStat, isTrue);
      expect(before.primaryKey, after.primaryKey,
          reason: 'khoá phải đi theo file, không theo đường dẫn');
      expect(before.pathKey, isNot(after.pathKey));
      expect(before.legacyKey, isNot(after.legacyKey));
    });

    test('hai file khác nội dung không đụng khoá (hashCode 32-bit từng làm vậy)',
        () async {
      final one = File('${tempDir.path}/one.pdf')..writeAsBytesSync([1, 2, 3]);
      final two = File('${tempDir.path}/two.pdf')
        ..writeAsBytesSync(List<int>.filled(5000, 7));
      two.setLastModifiedSync(one.statSync().modified);

      final a = await PdfFileIdentity.resolve(one.path);
      final b = await PdfFileIdentity.resolve(two.path);
      expect(a.primaryKey, isNot(b.primaryKey));
    });
  });
}
