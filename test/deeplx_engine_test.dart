// XLAT-DEEPLX-001: test DeepLXEngine — chuẩn hoá URL, khế ước request/response
// với mọi phiên bản DeepLX, và probe (nút "Thử kết nối"). Toàn bộ dùng
// MockClient — không network.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in4up/features/translation/engines/deeplx_engine.dart';

void main() {
  group('DeepLXEngine.normalizeUrl', () {
    test('host trần (hay gặp với HF Space) → tự nối /translate', () {
      expect(
        DeepLXEngine.normalizeUrl('https://beyou8778-deeplx.hf.space'),
        'https://beyou8778-deeplx.hf.space/translate',
      );
      expect(
        DeepLXEngine.normalizeUrl('https://beyou8778-deeplx.hf.space/'),
        'https://beyou8778-deeplx.hf.space/translate',
      );
      expect(
        DeepLXEngine.normalizeUrl('  http://localhost:1188  '),
        'http://localhost:1188/translate',
      );
    });

    test('URL đã có endpoint → giữ nguyên (bỏ "/" thừa cuối)', () {
      expect(
        DeepLXEngine.normalizeUrl('https://x.hf.space/translate'),
        'https://x.hf.space/translate',
      );
      expect(
        DeepLXEngine.normalizeUrl('https://x.hf.space/translate/'),
        'https://x.hf.space/translate',
      );
      expect(
        DeepLXEngine.normalizeUrl('https://x.hf.space/v2/translate'),
        'https://x.hf.space/v2/translate',
      );
      // Path riêng (reverse-proxy...) → tin người dùng, không tự ý sửa.
      expect(
        DeepLXEngine.normalizeUrl('https://x.com/custom/deeplx'),
        'https://x.com/custom/deeplx',
      );
    });

    test('giữ nguyên query ?token= (DeepLX hỗ trợ token qua URL)', () {
      expect(
        DeepLXEngine.normalizeUrl('https://x.hf.space/?token=abc'),
        'https://x.hf.space/translate?token=abc',
      );
      expect(
        DeepLXEngine.normalizeUrl('https://x.hf.space/translate?token=abc'),
        'https://x.hf.space/translate?token=abc',
      );
    });

    test('URL rác → trả nguyên bản (caller sẽ báo lỗi rõ)', () {
      expect(DeepLXEngine.normalizeUrl(''), '');
      expect(DeepLXEngine.normalizeUrl('not a url'), 'not a url');
    });
  });

  group('DeepLXEngine.translate (MockClient, không network)', () {
    test('200 + data → success; body đúng chuẩn {text, source_lang, target_lang}',
        () async {
      http.Request? captured;
      final engine = DeepLXEngine(
        // Host trần — engine phải tự nối /translate.
        serverUrl: 'https://x.hf.space',
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'code': 200,
              'id': 1779423094485,
              'data': 'Xin chào',
              'source_lang': 'EN',
              'target_lang': 'VI',
              'method': 'Free',
            }),
            200,
          );
        }),
      );

      final result = await engine.translate(
        text: 'Hello',
        targetLang: 'VI',
        sourceLang: 'EN',
      );

      expect(result.isSuccess, isTrue);
      expect(result.translatedText, 'Xin chào');
      expect(result.engineName, 'DeepLX');
      expect(captured!.url.toString(), 'https://x.hf.space/translate');
      expect(captured!.method, 'POST');
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['text'], 'Hello');
      expect(body['source_lang'], 'EN');
      expect(body['target_lang'], 'VI');
    });

    test('source_lang rỗng → bỏ khỏi body (DeepLX tự nhận diện ngôn ngữ)',
        () async {
      http.Request? captured;
      final engine = DeepLXEngine(
        serverUrl: 'http://localhost:1188',
        client: MockClient((request) async {
          captured = request;
          return http.Response('{"code":200,"data":"ok"}', 200);
        }),
      );

      await engine.translate(text: 'Hello', targetLang: 'VI', sourceLang: '  ');

      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body.containsKey('source_lang'), isFalse);
    });

    test('chấp nhận dạng /v2/translate (DeepL chính thức): translations[0].text',
        () async {
      final engine = DeepLXEngine(
        serverUrl: 'https://x.hf.space/v2/translate',
        client: MockClient((request) async => http.Response(
              jsonEncode({
                'translations': [
                  {'detected_source_language': 'EN', 'text': 'Xin chào'},
                ],
              }),
              200,
            )),
      );

      final result = await engine.translate(text: 'Hello', targetLang: 'VI');

      expect(result.isSuccess, isTrue);
      expect(result.translatedText, 'Xin chào');
    });

    test('chấp nhận dạng jsonrpc wrapper: result.data / result.texts[0].text',
        () async {
      for (final body in [
        '{"result":{"data":"Xin chào"}}',
        '{"result":{"texts":[{"text":"Xin chào"}]}}',
      ]) {
        final engine = DeepLXEngine(
          serverUrl: 'https://x.hf.space',
          client: MockClient((request) async => http.Response(body, 200)),
        );
        final result = await engine.translate(text: 'Hello', targetLang: 'VI');
        expect(result.isSuccess, isTrue, reason: body);
        expect(result.translatedText, 'Xin chào', reason: body);
      }
    });

    test('404 → failure kèm HTTP status rõ ràng', () async {
      final engine = DeepLXEngine(
        serverUrl: 'https://x.hf.space',
        client:
            MockClient((request) async => http.Response('Not Found', 404)),
      );

      final result = await engine.translate(text: 'Hello', targetLang: 'VI');

      expect(result.isSuccess, isFalse);
      expect(result.error, contains('404'));
    });

    test('400 + message → failure rút ra được message của server', () async {
      final engine = DeepLXEngine(
        serverUrl: 'https://x.hf.space',
        client: MockClient((request) async => http.Response(
              jsonEncode({
                'code': 400,
                'message': 'unsupported target_lang "XX"; valid codes: …',
              }),
              400,
            )),
      );

      final result = await engine.translate(text: 'Hello', targetLang: 'XX');

      expect(result.isSuccess, isFalse);
      expect(result.error, contains('400'));
      expect(result.error, contains('unsupported target_lang'));
    });

    test('text rỗng → success rỗng, không gọi network', () async {
      var called = 0;
      final engine = DeepLXEngine(
        serverUrl: 'https://x.hf.space',
        client: MockClient((request) async {
          called++;
          return http.Response('{}', 200);
        }),
      );

      final result = await engine.translate(text: '   ', targetLang: 'VI');

      expect(result.isSuccess, isTrue);
      expect(result.translatedText, '');
      expect(called, 0);
    });

    test('exception mạng → failure không ném ra ngoài', () async {
      final engine = DeepLXEngine(
        serverUrl: 'https://x.hf.space',
        client: MockClient((request) async {
          throw Exception('SocketException: Failed host lookup');
        }),
      );

      final result = await engine.translate(text: 'Hello', targetLang: 'VI');

      expect(result.isSuccess, isFalse);
      expect(result.error, contains('SocketException'));
    });
  });

  group('DeepLXEngine.probe (nút "Thử kết nối")', () {
    test('thành công → ok + sample + statusCode 200', () async {
      final engine = DeepLXEngine(
        serverUrl: 'https://x.hf.space',
        client: MockClient((request) async => http.Response(
              jsonEncode({'code': 200, 'data': 'Xin chào'}),
              200,
            )),
      );

      final probe = await engine.probe(text: 'Hello', targetLang: 'VI');

      expect(probe.ok, isTrue);
      expect(probe.sample, 'Xin chào');
      expect(probe.statusCode, 200);
    });

    test('URL không hợp lệ → ok=false, không có statusCode', () async {
      final engine = DeepLXEngine(serverUrl: 'not a url');

      final probe = await engine.probe();

      expect(probe.ok, isFalse);
      expect(probe.statusCode, isNull);
      expect(probe.error, contains('invalid URL'));
    });

    test('lỗi HTTP → trả đúng statusCode + message', () async {
      final engine = DeepLXEngine(
        serverUrl: 'https://x.hf.space',
        client: MockClient((request) async => http.Response(
              jsonEncode({'code': 401, 'message': 'Invalid access token'}),
              401,
            )),
      );

      final probe = await engine.probe();

      expect(probe.ok, isFalse);
      expect(probe.statusCode, 401);
      expect(probe.error, contains('Invalid access token'));
    });

    test('không kết nối được (Space ngủ/chưa chạy) → ok=false kèm lỗi',
        () async {
      final engine = DeepLXEngine(
        serverUrl: 'https://x.hf.space',
        client: MockClient((request) async {
          throw Exception('Connection refused');
        }),
      );

      final probe = await engine.probe();

      expect(probe.ok, isFalse);
      expect(probe.statusCode, isNull);
      expect(probe.error, contains('Connection refused'));
    });
  });
}
