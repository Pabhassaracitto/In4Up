// AUDIT-1.21.0 #6 — dịch ra NGUYÊN link https://linux.do/t/topic/...
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/translation/translation_link_guard.dart';

void main() {
  group('isUrlToken', () {
    test('link có scheme / www / host trần', () {
      expect(isUrlToken('https://linux.do/t/topic/111737'), isTrue);
      expect(isUrlToken('www.linux.do/t/topic/111737'), isTrue);
      expect(isUrlToken('linux.do/t/topic/111737'), isTrue);
      expect(isUrlToken('(https://linux.do/t/topic/111737)'), isTrue);
      expect(isUrlToken('https://linux.do/t/topic/111737.'), isTrue);
    });
    test('không bắt nhầm từ / giờ / số', () {
      expect(isUrlToken('xin chào'), isFalse);
      expect(isUrlToken('12:30'), isFalse);
      expect(isUrlToken('topic'), isFalse);
    });
  });

  group('isLinkOnlyText', () {
    test('đúng triệu chứng owner: chỉ 1 dòng link', () {
      expect(isLinkOnlyText('https://linux.do/t/topic/111737'), isTrue);
      expect(isLinkOnlyText('linux.do/t/topic/111737'), isTrue);
    });
    test('nhiều link vẫn là link-only', () {
      expect(isLinkOnlyText('https://a.com https://b.com/t/x'), isTrue);
    });
    test('câu CÓ kèm link vẫn được dịch bình thường', () {
      expect(isLinkOnlyText('Xem thêm: https://linux.do/t/topic/111737'),
          isFalse);
      expect(isLinkOnlyText('Hướng dẫn DeepLX tại linux.do thì làm sao?'),
          isFalse);
    });
    test('text thường / rỗng không bị chặn', () {
      expect(isLinkOnlyText(''), isFalse);
      expect(isLinkOnlyText('Hello world'), isFalse);
      expect(isLinkOnlyText('12:30'), isFalse);
    });
  });
}
