// AUDIT-1.21.0 #6 — link bài hướng dẫn DeepLX bị dán nhầm làm endpoint.
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in4up/features/translation/engines/deeplx_endpoint.dart';
import 'package:in4up/features/translation/engines/deeplx_engine.dart';

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

  // AUDIT-1.21.0 #6 — chốt lại mối lo "GET root làm rơi ?token=":
  // `Uri.replace(path: '/')` trong dart:core GIỮ `_query` khi không truyền
  // `query`/`queryParameters` (sdk/lib/core/uri.dart: `query = this._query`).
  // Test dưới đây dùng MockClient để pin hành vi thay vì đoán.
  group('DeepLXEngine.isAvailable (query token + article link)', () {
    test('GET root vẫn mang ?token=abc', () async {
      Uri? seen;
      final engine = DeepLXEngine(
        serverUrl: 'http://localhost:1188/translate?token=abc',
        client: MockClient((request) async {
          seen = request.url;
          return http.Response('ok', 200);
        }),
      );
      expect(await engine.isAvailable(), isTrue);
      expect(seen, isNotNull);
      expect(seen!.host, 'localhost');
      expect(seen!.port, 1188);
      expect(seen!.path, '/');
      expect(seen!.queryParameters['token'], 'abc',
          reason: 'token phải sống sót qua Uri.replace(path: "/")');
    });

    test('link bài hướng dẫn ⇒ false và KHÔNG gọi mạng', () async {
      var calls = 0;
      final engine = DeepLXEngine(
        serverUrl: 'https://linux.do/t/topic/111737',
        client: MockClient((request) async {
          calls++;
          return http.Response('ok', 200);
        }),
      );
      expect(await engine.isAvailable(), isFalse);
      expect(calls, 0,
          reason: 'link/forum phải bị từ chối trước khi tốn 3s probe');
    });
  });
}
