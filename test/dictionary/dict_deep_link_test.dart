// ADR-0018 (P1) — bóc link/tệp từ ngoài app. Thuần Dart: KHÔNG plugin,
// KHÔNG Flutter ⇒ chạy được trên CI và không treo (bài học run 40575300780).
//
// Ma trận ca xấu là phần quan trọng nhất: đầu vào đến từ hệ điều hành, tức là
// dữ liệu KHÔNG tin được.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/dictionary/services/dict_deep_link.dart';

void main() {
  group('in4up://dict — link tra từ', () {
    test('bóc đúng từ', () {
      final request = DictDeepLink.parse('in4up://dict?w=ubiquitous');
      expect(request, isNotNull);
      expect(request!.kind, DictDeepLinkKind.word);
      expect(request.value, 'ubiquitous');
      expect(request.source, 'deep_link');
    });

    test('percent-encode: tiếng Việt có dấu cách', () {
      final request = DictDeepLink.parse('in4up://dict?w=h%E1%BB%8Dc%20sinh');
      expect(request!.value, 'học sinh');
    });

    test('nhận các tên khoá khác cho từ', () {
      expect(DictDeepLink.parse('in4up://dict?word=hello')!.value, 'hello');
      expect(DictDeepLink.parse('in4up://dict?q=hello')!.value, 'hello');
    });

    test('không phân biệt hoa/thường ở host', () {
      expect(DictDeepLink.parse('in4up://DICT?w=hello')!.value, 'hello');
    });

    test('host rỗng nhưng có w ⇒ vẫn nhận (một số trình tạo link bỏ host)', () {
      expect(DictDeepLink.parse('in4up://?w=hello')!.value, 'hello');
    });

    test('scheme i4u là bí danh', () {
      expect(DictDeepLink.parse('i4u://dict?w=hello')!.value, 'hello');
    });
  });

  group('ca xấu — trả null, KHÔNG ném', () {
    test('thiếu w', () {
      expect(DictDeepLink.parse('in4up://dict'), isNull);
      expect(DictDeepLink.parse('in4up://dict?w='), isNull);
      expect(DictDeepLink.parse('in4up://dict?w=%20%20'), isNull);
    });

    test('host lạ', () {
      expect(DictDeepLink.parse('in4up://settings?w=hello'), isNull);
      expect(DictDeepLink.parse('in4up://translate?w=hello'), isNull);
    });

    test('scheme lạ', () {
      expect(DictDeepLink.parse('ftp://dict?w=hello'), isNull);
      expect(DictDeepLink.parse('market://details?id=com.in4up'), isNull);
      expect(DictDeepLink.parse('https://example.com/dict?w=hello'), isNull);
    });

    test('từ quá dài (> 64) ⇒ từ chối, không cắt lặng', () {
      final long = 'a' * (DictDeepLink.maxWordLength + 1);
      expect(DictDeepLink.parse('in4up://dict?w=$long'), isNull);
    });

    test('đúng 64 ký tự ⇒ vẫn nhận', () {
      final word = 'b' * DictDeepLink.maxWordLength;
      expect(DictDeepLink.parse('in4up://dict?w=$word')!.value, word);
    });

    test('ký tự điều khiển bị bỏ, không làm hỏng từ', () {
      final request = DictDeepLink.parse('in4up://dict?w=he%0Allo');
      expect(request!.value, 'hello');
    });

    test('chuỗi rỗng / chỉ khoảng trắng / rác', () {
      expect(DictDeepLink.parse(''), isNull);
      expect(DictDeepLink.parse('   '), isNull);
    });
  });

  group('https://in4up.app/dict — để sau này chỉ cần assetlinks', () {
    test('bóc đúng từ', () {
      final request = DictDeepLink.parse('https://in4up.app/dict?w=hello');
      expect(request!.kind, DictDeepLinkKind.word);
      expect(request.value, 'hello');
    });

    test('host www + đường dẫn con vẫn nhận', () {
      expect(DictDeepLink.parse('https://www.in4up.app/dict?w=hi')!.value, 'hi');
      expect(
        DictDeepLink.parse('https://in4up.app/dictionary/lookup?w=hi')!.value,
        'hi',
      );
    });

    test('trang khác của site ⇒ null (không cướp link thường)', () {
      expect(DictDeepLink.parse('https://in4up.app/blog'), isNull);
      expect(DictDeepLink.parse('https://in4up.app/'), isNull);
    });
  });

  group('tệp — chỉ đuôi app đọc được', () {
    test('in4up://open?path=… với đuôi hợp lệ', () {
      final request = DictDeepLink.parse('in4up://open?path=/sdcard/x.mdx');
      expect(request!.kind, DictDeepLinkKind.file);
      expect(request.value, '/sdcard/x.mdx');
    });

    test('file:// cũng nhận', () {
      final request = DictDeepLink.parse('file:///sdcard/doc.pdf');
      expect(request!.kind, DictDeepLinkKind.file);
      expect(request.value, '/sdcard/doc.pdf');
    });

    test('argv đưa đường dẫn trần (Windows/Linux)', () {
      final request = DictDeepLink.parse(r'C:\Users\me\dict.mdx');
      expect(request!.kind, DictDeepLinkKind.file);
      expect(request.value, r'C:\Users\me\dict.mdx');
    });

    test('đuôi lạ ⇒ null (không nhận */*)', () {
      expect(DictDeepLink.parse('in4up://open?path=/sdcard/app.apk'), isNull);
      expect(DictDeepLink.parse('/sdcard/movie.mkv'), isNull);
      expect(DictDeepLink.parse('/sdcard/no-extension'), isNull);
    });

    test('đuôi không phân biệt hoa/thường', () {
      expect(DictDeepLink.parse('/sdcard/A.MDX'), isNotNull);
    });

    test('có `..` ⇒ từ chối (link không được trỏ lung tung)', () {
      expect(DictDeepLink.parse('in4up://open?path=/sdcard/../../data/x.mdx'),
          isNull);
      expect(DictDeepLink.parse(r'C:\a\..\..\b.mdx'), isNull);
    });

    test('mdx/mdd/pdf/txt/md/markdown/epub đều nhận', () {
      for (final ext in DictDeepLink.allowedFileExtensions) {
        expect(DictDeepLink.parse('/tmp/file.$ext'), isNotNull,
            reason: '.$ext phải được nhận');
      }
    });
  });

  group('parseArguments — argv của Windows/Linux', () {
    test('bỏ qua cờ, lấy tệp đầu tiên hợp lệ', () {
      final request = DictDeepLink.parseArguments(<String>[
        '--enable-software-rendering',
        r'C:\docs\a.pdf',
      ]);
      expect(request!.value, r'C:\docs\a.pdf');
      expect(request.source, 'argv');
    });

    test('chấp nhận cả link riêng trong argv', () {
      expect(
        DictDeepLink.parseArguments(<String>['in4up://dict?w=hello'])!.value,
        'hello',
      );
    });

    test('không có gì hợp lệ ⇒ null', () {
      expect(DictDeepLink.parseArguments(const <String>[]), isNull);
      expect(
        DictDeepLink.parseArguments(const <String>['--no-sandbox', 'x.apk']),
        isNull,
      );
    });
  });

  group('normalizeWord / fileExtension', () {
    test('gộp khoảng trắng, cắt đầu cuối', () {
      expect(DictDeepLink.normalizeWord('  học   sinh '), 'học sinh');
      expect(DictDeepLink.normalizeWord(null), isNull);
      expect(DictDeepLink.normalizeWord('   '), isNull);
    });

    test('fileExtension', () {
      expect(DictDeepLink.fileExtension('/a/b/c.MDX'), 'mdx');
      expect(DictDeepLink.fileExtension(r'C:\a\b.txt'), 'txt');
      expect(DictDeepLink.fileExtension('/a/.hidden'), isNull);
      expect(DictDeepLink.fileExtension('/a/b'), isNull);
    });
  });
}
