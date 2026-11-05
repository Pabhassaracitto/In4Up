// AUDIT-1.21.0 #6 — link bài hướng dẫn DeepLX bị dán nhầm làm endpoint.
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/translation/engines/deeplx_endpoint.dart';

void main() {
  group('assessDeepLXEndpoint', () {
    test('link forum linux.do/t/topic ⇒ từ chối NGAY (không tốn 20s probe)', () {
      final v = assessDeepLXEndpoint('https://linux.do/t/topic/111737');
      expect(v.isValid, isFalse);
      expect(v.isArticleLink, isTrue);
      expect(v.normalizedUrl, isNull);
    });

    test('host nội dung (GitHub, blog) cũng không phải server', () {
      expect(assessDeepLXEndpoint('https://github.com/user/repo').isValid,
          isFalse);
      expect(
        assessDeepLXEndpoint('https://github.com/user/repo').issue,
        DeepLXEndpointIssue.contentHost,
      );
    });

    test('Termux / LAN host trần ⇒ tự nối /translate', () {
      final v = assessDeepLXEndpoint('http://127.0.0.1:1188');
      expect(v.isValid, isTrue);
      expect(v.normalizedUrl, 'http://127.0.0.1:1188/translate');
    });

    test('giữ query token và endpoint reverse-proxy', () {
      expect(
        assessDeepLXEndpoint('http://localhost:1188/?token=abc').normalizedUrl,
        'http://localhost:1188/translate?token=abc',
      );
      expect(
        assessDeepLXEndpoint('https://x.hf.space/v2/translate').normalizedUrl,
        'https://x.hf.space/v2/translate',
      );
    });

    test('URL rác / sai scheme / ô trống', () {
      expect(assessDeepLXEndpoint('not a url').issue,
          DeepLXEndpointIssue.malformed);
      expect(assessDeepLXEndpoint('ftp://x.com').issue,
          DeepLXEndpointIssue.unsupportedScheme);
      final empty = assessDeepLXEndpoint('  ');
      expect(empty.issue, DeepLXEndpointIssue.notConfigured);
      expect(empty.isConfigured, isFalse);
    });
  });
}
