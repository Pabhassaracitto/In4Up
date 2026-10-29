// YT-DL-RANGE-001 — pin lỗi owner báo ngày 2026-10-24:
//
//   "Tải thất bại: Lỗi: RangeError (end): Invalid value: Not in inclusive
//    range 0..70: 74"
//
// Nguyên nhân: `_sanitize` cắt chuỗi theo độ dài của tên **GỐC**
// (`.substring(0, name.length.clamp(0, 80))`) trong khi `replaceAll` ở trên đã
// làm chuỗi NGẮN lại. Tên 74 ký tự có 3 ký tự bị loại ⇒ chuỗi còn 71 ⇒
// `substring(0, 74)` ném RangeError đúng như trên. Lỗi ném ra giữa luồng tải
// nên người dùng chỉ thấy "Tải thất bại" — trông như lỗi mạng.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/youtube/services/yt_downloader.dart';

void main() {
  group('YtDownloader.sanitizeFileName', () {
    test('tên 74 ký tự có ký tự bị loại KHÔNG còn ném RangeError', () {
      // 3 dấu ":" bị loại ⇒ còn 71 ký tự, trong khi tên gốc dài 74.
      // 21 + 1 + 21 + 1 + 21 + 1 + 8 = 74 ký tự; bỏ 3 dấu ':' ⇒ còn 71.
      final name = '${'a' * 21}:${'b' * 21}:${'c' * 21}:${'d' * 8}';
      expect(name.length, 74);
      final safe = YtDownloader.sanitizeFileName(name);
      expect(safe.length, 71);
      expect(safe.contains(':'), isFalse);
    });

    test('tên RẤT dài bị cắt còn 80 ký tự', () {
      final safe = YtDownloader.sanitizeFileName('x' * 300);
      expect(safe.length, 80);
    });

    test('tên dài đúng 80 thì giữ nguyên', () {
      final safe = YtDownloader.sanitizeFileName('y' * 80);
      expect(safe.length, 80);
    });

    test('loại hết ký tự cấm của Windows/Android', () {
      final safe = YtDownloader.sanitizeFileName('a<b>c:d"e/f\\g|h?i*j');
      expect(safe, 'abcdefghij');
    });

    test('gộp khoảng trắng liên tiếp và cắt hai đầu', () {
      expect(YtDownloader.sanitizeFileName('  a    b  '), 'a b');
    });

    test('chuỗi rỗng / toàn ký tự bị loại ⇒ trả chuỗi rỗng, không ném lỗi',
        () {
      expect(YtDownloader.sanitizeFileName(''), '');
      expect(YtDownloader.sanitizeFileName(':::/\\\\'), '');
    });
  });
}
