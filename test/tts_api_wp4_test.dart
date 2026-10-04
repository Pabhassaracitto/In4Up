// test/tts_api_wp4_test.dart — WP4 (API-005)
//
// Test logic thuần của engine TTS qua API (không network thật, không
// SharedPreferences, không TtsService — singleton có platform channels):
// - OpenAiVoicesParser: mọi biến thể body /audio/voices gặp thực tế
// - OpenAiCompatClient.synthesizeSpeech: request chuẩn + phân loại lỗi
// - OpenAiCompatTtsEngine: guard cấu hình, chunking, clamp speed, retry
//   (429/5xx → tối đa 1 retry), fallback giọng mặc định, mapping Kokoro
// - Pin nghiệp vụ bằng source-scan: thứ tự engine mặc định KHÔNG đổi so
//   với trước WP4 (engine mới nằm CUỐI), và engine dùng store chung WP0
//   (AiProviderStore) — không nhập key riêng.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:in4up_ai/in4up_ai.dart';

import 'package:in4up/features/tts/engines/openai_compat_tts_engine.dart';

/// HTTP client giả — ghi lại request + body, trả response theo hàng đợi
/// hành vi do test dựng. Không chạm network.
class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this.onRequest);

  final Future<http.StreamedResponse> Function(
      http.BaseRequest request, String body) onRequest;

  final List<http.BaseRequest> requests = [];
  final List<String> bodies = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests.add(request);
    final body = request is http.Request ? request.body : '';
    bodies.add(body);
    return onRequest(request, body);
  }
}

http.StreamedResponse _bytes(int status, List<int> bytes) =>
    http.StreamedResponse(Stream.value(bytes), status);

/// Payload mp3 giả, dài hơn ngưỡng guard 100B của client.
List<int> _fakeMp3(int seed) =>
    List<int>.generate(256, (i) => (seed + i) & 0xFF);

/// Key test KHÔNG hard-code (luật BYOK) — sinh lúc chạy.
String _runtimeKey() => 'wp4-${DateTime.now().microsecondsSinceEpoch}';

AiProviderConfig _provider({
  String label = 'Kokoro nhà',
  String baseUrl = 'http://192.168.1.5:8880',
  String? apiKey,
  String? ttsModel = 'kokoro',
}) {
  return AiProviderConfig(
    id: 'p1',
    label: label,
    baseUrl: baseUrl,
    apiKey: apiKey,
    ttsModel: ttsModel,
  );
}

void main() {
  group('OpenAiVoicesParser', () {
    const parser = OpenAiVoicesParser();

    test('Kokoro-FastAPI: {"voices": [String…]}', () {
      expect(parser.parse('{"voices": ["af_heart", "bm_lewis"]}'),
          ['af_heart', 'bm_lewis']);
    });

    test('OpenAI-ish: {"data": [{"id": …}]} như /models', () {
      expect(parser.parse('{"data": [{"id": "alloy"}, {"id": "nova"}]}'),
          ['alloy', 'nova']);
    });

    test('top-level list thuần', () {
      expect(parser.parse('["alloy", 1, {"voice": "af_x"}]'),
          ['alloy', 'af_x']);
    });

    test('item Map: nhận khoá id/voice/name theo thứ tự ưu tiên', () {
      expect(
        parser.parse('{"models": [{"id": "a"}, {"voice": "b"}, {"name": "c"}]}'),
        ['a', 'b', 'c'],
      );
    });

    test('shape lạ → invalidResponse', () {
      expect(
        () => parser.parse('{"nope": 1}'),
        throwsA(isA<AiApiException>()
            .having((e) => e.code, 'code', AiApiErrorCode.invalidResponse)),
      );
    });
  });

  group('OpenAiCompatClient.synthesizeSpeech', () {
    test('POST chuẩn: /v1/audio/speech, body đủ field, Bearer theo key', () async {
      final key = _runtimeKey();
      final fake = _FakeHttpClient((req, body) async => _bytes(200, _fakeMp3(1)));
      final client = OpenAiCompatClient(
        baseUrl: 'http://192.168.1.5:8880',
        apiKey: key,
        httpClient: fake,
      );

      final bytes = await client.synthesizeSpeech(
        model: 'tts-1',
        input: 'Xin chào',
        voice: 'nova',
        speed: 1.5,
      );

      expect(bytes, _fakeMp3(1));
      expect(fake.requests.single.method, 'POST');
      expect(fake.requests.single.url.toString(),
          'http://192.168.1.5:8880/v1/audio/speech');
      expect(fake.requests.single.headers['authorization'], 'Bearer $key');
      final json = jsonDecode(fake.bodies.single) as Map<String, dynamic>;
      expect(json['model'], 'tts-1');
      expect(json['input'], 'Xin chào');
      expect(json['voice'], 'nova');
      expect(json['speed'], 1.5);
      expect(json['response_format'], 'mp3');
    });

    test('baseUrl gốc không /v1 → normalize tự thêm', () async {
      final fake = _FakeHttpClient((req, body) async => _bytes(200, _fakeMp3(2)));
      final client = OpenAiCompatClient(
        baseUrl: 'http://localhost:8880',
        httpClient: fake,
      );
      await client.synthesizeSpeech(model: 'm', input: 'a');
      expect(fake.requests.single.url.toString(),
          'http://localhost:8880/v1/audio/speech');
    });

    test('401 → unauthorized (kèm statusCode)', () async {
      final fake = _FakeHttpClient((req, body) async =>
          _bytes(401, utf8.encode('{"error": {"message": "bad key"}}')));
      final client = OpenAiCompatClient(
        baseUrl: 'https://api.example.test',
        apiKey: _runtimeKey(),
        httpClient: fake,
      );
      await expectLater(
        () => client.synthesizeSpeech(model: 'm', input: 'x'),
        throwsA(isA<AiApiException>()
            .having((e) => e.code, 'code', AiApiErrorCode.unauthorized)
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.message, 'message', contains('bad key'))),
      );
    });

    test('429 → rateLimited', () async {
      final fake = _FakeHttpClient((req, body) async => _bytes(429, []));
      final client = OpenAiCompatClient(
        baseUrl: 'http://192.168.1.5:8880',
        httpClient: fake,
      );
      await expectLater(
        () => client.synthesizeSpeech(model: 'm', input: 'x'),
        throwsA(isA<AiApiException>()
            .having((e) => e.code, 'code', AiApiErrorCode.rateLimited)),
      );
    });

    test('500 → httpError kèm snippet lỗi của server', () async {
      final fake = _FakeHttpClient((req, body) async =>
          _bytes(500, utf8.encode('{"message": "model not loaded"}')));
      final client = OpenAiCompatClient(
        baseUrl: 'http://192.168.1.5:8880',
        httpClient: fake,
      );
      await expectLater(
        () => client.synthesizeSpeech(model: 'm', input: 'x'),
        throwsA(isA<AiApiException>()
            .having((e) => e.code, 'code', AiApiErrorCode.httpError)
            .having((e) => e.statusCode, 'statusCode', 500)
            .having(
                (e) => e.message, 'message', contains('model not loaded'))),
      );
    });

    test('200 nhưng payload quá nhỏ → invalidResponse (nghi trang lỗi)',
        () async {
      final fake =
          _FakeHttpClient((req, body) async => _bytes(200, [1, 2, 3]));
      final client = OpenAiCompatClient(
        baseUrl: 'http://192.168.1.5:8880',
        httpClient: fake,
      );
      await expectLater(
        () => client.synthesizeSpeech(model: 'm', input: 'x'),
        throwsA(isA<AiApiException>()
            .having((e) => e.code, 'code', AiApiErrorCode.invalidResponse)),
      );
    });

    test('http công cộng bị chặn trước khi gửi (luật cleartext)', () async {
      final fake = _FakeHttpClient((req, body) async => _bytes(200, _fakeMp3(3)));
      final client = OpenAiCompatClient(
        baseUrl: 'http://api.example.com',
        httpClient: fake,
      );
      await expectLater(
        () => client.synthesizeSpeech(model: 'm', input: 'x'),
        throwsA(isA<AiApiException>()
            .having((e) => e.code, 'code', AiApiErrorCode.cleartextBlocked)),
      );
      expect(fake.requests, isEmpty, reason: 'không được gửi request nào ra');
    });
  });

  group('OpenAiCompatClient.listVoices', () {
    test('GET /audio/voices → parse list', () async {
      final fake = _FakeHttpClient(
          (req, body) async => _bytes(200, utf8.encode('{"voices": ["af_a"]}')));
      final client = OpenAiCompatClient(
        baseUrl: 'http://192.168.1.5:8880',
        httpClient: fake,
      );
      expect(await client.listVoices(), ['af_a']);
      expect(fake.requests.single.method, 'GET');
      expect(fake.requests.single.url.toString(),
          'http://192.168.1.5:8880/v1/audio/voices');
    });

    test('server không có endpoint (404) → httpError (engine tự fallback)',
        () async {
      final fake = _FakeHttpClient((req, body) async => _bytes(404, []));
      final client = OpenAiCompatClient(
        baseUrl: 'http://192.168.1.5:8880',
        httpClient: fake,
      );
      await expectLater(
        () => client.listVoices(),
        throwsA(isA<AiApiException>()
            .having((e) => e.code, 'code', AiApiErrorCode.httpError)),
      );
    });
  });

  group('OpenAiCompatTtsEngine.synthesize', () {
    OpenAiCompatTtsEngine engineFor(
      _FakeHttpClient fake, {
      AiProviderConfig? provider,
    }) {
      final p = provider ?? _provider();
      return OpenAiCompatTtsEngine(
        provider: p,
        client: OpenAiCompatClient(
          baseUrl: p.baseUrl,
          apiKey: p.apiKey,
          httpClient: fake,
        ),
      );
    }

    test('happy path: mp3 bytes, tên engine gắn model · giọng', () async {
      final fake = _FakeHttpClient((req, body) async => _bytes(200, _fakeMp3(7)));
      final provider = _provider(ttsModel: 'tts-1');
      final engine = engineFor(fake, provider: provider);

      final result = await engine.synthesize(
        text: 'Xin chào thế giới',
        language: 'vi-VN',
      );

      expect(result.isSuccess, isTrue);
      expect(result.audioData, isNotEmpty);
      expect(result.engineName, 'Server TTS · Kokoro nhà (tts-1 · alloy)');
      expect(fake.requests, hasLength(1));
    });

    test('voiceId được truyền xuống request; rỗng → alloy', () async {
      final fake = _FakeHttpClient((req, body) async => _bytes(200, _fakeMp3(8)));
      final engine = engineFor(fake, provider: _provider(ttsModel: 'tts-1'));

      await engine.synthesize(
        text: 'hi',
        language: 'en-US',
        voiceId: '  shimmer  ',
      );
      expect((jsonDecode(fake.bodies[0]) as Map)['voice'], 'shimmer');

      await engine.synthesize(text: 'hi', language: 'en-US', voiceId: '  ');
      expect((jsonDecode(fake.bodies[1]) as Map)['voice'], 'alloy');
    });

    test('chưa chọn model TTS → failure hướng về Server & API (không gọi HTTP)',
        () async {
      final fake = _FakeHttpClient((req, body) async => _bytes(200, _fakeMp3(9)));
      final engine =
          engineFor(fake, provider: _provider(label: 'MyBox', ttsModel: null));

      final result =
          await engine.synthesize(text: 'xin chào', language: 'vi-VN');

      expect(result.isSuccess, isFalse);
      expect(result.error, contains('chưa chọn model TTS'));
      expect(result.error, contains('Server & API'));
      expect(result.error, contains('MyBox'));
      expect(fake.requests, isEmpty);
    });

    test('text trống → failure', () async {
      final fake = _FakeHttpClient((req, body) async => _bytes(200, _fakeMp3(10)));
      final engine = engineFor(fake, provider: _provider(ttsModel: 'tts-1'));
      final result =
          await engine.synthesize(text: '   ', language: 'vi-VN');
      expect(result.isSuccess, isFalse);
      expect(fake.requests, isEmpty);
    });

    test('speed clamp v [0.25, 4.0]', () async {
      final fake = _FakeHttpClient((req, body) async => _bytes(200, _fakeMp3(11)));
      final engine = engineFor(fake, provider: _provider(ttsModel: 'tts-1'));

      await engine.synthesize(text: 'a', language: 'en', speed: 10);
      expect((jsonDecode(fake.bodies[0]) as Map)['speed'], 4.0);

      await engine.synthesize(text: 'a', language: 'en', speed: 0.01);
      expect((jsonDecode(fake.bodies[1]) as Map)['speed'], 0.25);
    });

    test('text dài → chia chunks ≤ maxCharsPerRequest, ghép đúng thứ tự', () async {
      final partA = _fakeMp3(100);
      final partB = _fakeMp3(150);
      var call = 0;
      final fake = _FakeHttpClient(
          (req, body) async => _bytes(200, call++ == 0 ? partA : partB));
      final engine =
          engineFor(fake, provider: _provider(ttsModel: 'tts-1'));

      // Mỗi câu ~1200 ký tự → 2 chunks (max 2000).
      final cau1 = 'Một${' hai' * 250}. ';
      final cau2 = 'Ba${' bốn' * 260}.';
      final result = await engine.synthesize(
        text: cau1 + cau2,
        language: 'vi-VN',
      );

      expect(result.isSuccess, isTrue);
      expect(fake.requests.length, greaterThanOrEqualTo(2));
      expect(result.audioData, equals([...partA, ...partB]));
      // Không chunk nào vượt trần.
      for (final body in fake.bodies) {
        final input = (jsonDecode(body) as Map)['input'] as String;
        expect(input.length, lessThanOrEqualTo(engine.maxCharsPerRequest));
      }
    });

    test('5xx → retry 1 lần rồi thành công', () async {
      var attempt = 0;
      final fake = _FakeHttpClient((req, body) async {
        attempt++;
        return attempt == 1 ? _bytes(500, []) : _bytes(200, _fakeMp3(12));
      });
      final engine =
          engineFor(fake, provider: _provider(ttsModel: 'tts-1'));

      final result = await engine.synthesize(text: 'a', language: 'en');

      expect(result.isSuccess, isTrue);
      expect(attempt, 2, reason: 'đúng 1 retry');
    });

    test('429 liên tiếp → failure (không vượt quá 1 retry — luật backoff)', () async {
      var attempt = 0;
      final fake = _FakeHttpClient((req, body) async {
        attempt++;
        return _bytes(429, []);
      });
      final engine =
          engineFor(fake, provider: _provider(ttsModel: 'tts-1'));

      final result = await engine.synthesize(text: 'a', language: 'en');

      expect(result.isSuccess, isFalse);
      expect(result.error, contains('rate-limit'));
      expect(attempt, 2);
    });

    test('401 → KHÔNG retry (lỗi cấu hình), thông điệp không lộ key', () async {
      var attempt = 0;
      final key = _runtimeKey();
      final fake = _FakeHttpClient((req, body) async {
        attempt++;
        return _bytes(401, utf8.encode('{"error": {"message": "nope"}}'));
      });
      final provider = _provider(ttsModel: 'kokoro', apiKey: key);
      final engine = engineFor(fake, provider: provider);

      final result = await engine.synthesize(text: 'a', language: 'en');

      expect(result.isSuccess, isFalse);
      expect(attempt, 1);
      expect(result.error, contains('API key'));
      expect(result.error, isNot(contains(key)),
          reason: 'thông điệp hiển thị không được lộ key');
    });

    test('unsupported language (fr-FR) → voices rỗng (chain còn engine khác)',
        () async {
      final fake = _FakeHttpClient((req, body) async => _bytes(200, _fakeMp3(13)));
      final engine =
          engineFor(fake, provider: _provider(ttsModel: 'tts-1'));
      expect(await engine.getAvailableVoices('fr-FR'), isEmpty);
    });
  });

  group('OpenAiCompatTtsEngine.voices & availability', () {
    test('server có /audio/voices → map Kokoro prefix (vùng, giới tính)',
        () async {
      final fake = _FakeHttpClient((req, body) async => _bytes(
          200,
          utf8.encode(
              '{"voices": ["af_bella", "bm_lewis", "jf_alpha", "nova"]}')));
      final provider = _provider(ttsModel: 'kokoro');
      final engine = OpenAiCompatTtsEngine(
        provider: provider,
        client: OpenAiCompatClient(baseUrl: provider.baseUrl, httpClient: fake),
      );

      final voices = await engine.getAvailableVoices('vi-VN');

      expect(voices, hasLength(4));
      expect(voices[0].id, 'af_bella');
      expect(voices[0].language, 'en-US');
      expect(voices[0].gender, 'female');
      expect(voices[1].language, 'en-GB');
      expect(voices[1].gender, 'male');
      expect(voices[2].language, 'ja-JP');
      expect(voices[3].language, 'vi-VN', reason: 'id lạ → fallback theo tham số');
      expect(voices[3].gender, 'female', reason: 'nova giọng nữ OpenAI');
      expect(voices.every((v) => v.isNeural), isTrue);
    });

    test('server KHÔNG có /audio/voices → fallback 6 giọng OpenAI mặc định',
        () async {
      final fake = _FakeHttpClient((req, body) async => _bytes(404, []));
      final provider = _provider(ttsModel: 'tts-1');
      final engine = OpenAiCompatTtsEngine(
        provider: provider,
        client: OpenAiCompatClient(baseUrl: provider.baseUrl, httpClient: fake),
      );

      final voices = await engine.getAvailableVoices('vi-VN');

      expect(voices, hasLength(6));
      expect(voices.map((v) => v.id),
          containsAll(['alloy', 'nova', 'shimmer', 'echo', 'onyx', 'fable']));
      expect(voices.every((v) => v.language == 'vi-VN'), isTrue,
          reason: 'giọng OpenAI đa ngôn ngữ → gắn ngôn ngữ đang xét');
      expect(voices.firstWhere((v) => v.id == 'alloy').gender, 'neutral');
    });

    test('isAvailable: false khi thiếu ttsModel (không gọi HTTP)', () async {
      final fake = _FakeHttpClient((req, body) async => _bytes(200, _fakeMp3(14)));
      final provider = _provider(ttsModel: null);
      final engine = OpenAiCompatTtsEngine(
        provider: provider,
        client: OpenAiCompatClient(baseUrl: provider.baseUrl, httpClient: fake),
      );
      expect(await engine.isAvailable(), isFalse);
      expect(fake.requests, isEmpty);
    });

    test('isAvailable: theo healthCheck của server', () async {
      final ok = _FakeHttpClient((req, body) async =>
          _bytes(200, utf8.encode('{"data": [{"id": "kokoro"}]}')));
      final provider = _provider(ttsModel: 'kokoro');
      final engineOk = OpenAiCompatTtsEngine(
        provider: provider,
        client: OpenAiCompatClient(baseUrl: provider.baseUrl, httpClient: ok),
      );
      expect(await engineOk.isAvailable(), isTrue);

      final down = _FakeHttpClient((req, body) async => _bytes(503, []));
      final engineDown = OpenAiCompatTtsEngine(
        provider: provider,
        client: OpenAiCompatClient(baseUrl: provider.baseUrl, httpClient: down),
      );
      expect(await engineDown.isAvailable(), isFalse);
    });

    test('supportedLanguages bao phủ VI + EN (AT WP4)', () {
      final engine =
          OpenAiCompatTtsEngine(provider: _provider(ttsModel: 'tts-1'));
      expect(engine.supportedLanguages, containsAll(['vi-VN', 'vi', 'en-US', 'en']));
      expect(engine.id, 'openai_compat_tts');
    });
  });

  group('Source-scan: pin nghiệp vụ TtsService', () {
    test('thứ tự engine mặc định KHÔNG đổi — engine API nằm cuối chuỗi', () {
      final source =
          File('lib/features/tts/tts_service.dart').readAsStringSync();
      // Neo vào ĐỊNH NGHĨA hàm (call-site xuất hiện trước trong file).
      final start = source.indexOf('void _buildDefaultEngineOrder()');
      expect(start, greaterThan(0), reason: 'hàm build order phải tồn tại');
      final end = source.indexOf('];', start);
      final segment = source.substring(start, end);

      final ids = RegExp("id: '([a-z_]+)'")
          .allMatches(segment)
          .map((m) => m.group(1)!)
          .toList();

      expect(ids, [
        'piper_tts',
        'offline_tts',
        'google_tts',
        'zalo_tts',
        'fpt_tts',
        'openai_compat_tts', // WP4 — xếp SAU, không đẩy engine cũ
      ]);
    });

    test('engine API dùng store chung WP0 (AiProviderStore) — không key riêng',
        () {
      final source =
          File('lib/features/tts/tts_service.dart').readAsStringSync();
      expect(source, contains('AiProviderStore'));
      expect(source, contains('AiRouteCapability.tts'));

      final engineSource =
          File('lib/features/tts/engines/openai_compat_tts_engine.dart')
              .readAsStringSync();
      // Engine không tự lưu key — chỉ nhận OpenAiCompatClient/provider inject.
      expect(engineSource, isNot(contains('SharedPreferences')));
    });
  });
}
