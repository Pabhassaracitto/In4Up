// packages/in4up_ai/test/openai_compat_client_stt_test.dart
//
// WP2 (API-003) — Test cho OpenAiCompatClient.transcribeAudio() (dùng chung
// bởi in4up_stt qua SttEngineRemote). KHÔNG cần mạng thật: dùng
// package:http/testing.dart MockClient để giả lập server OpenAI-compatible
// (Groq/Speaches).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in4up_ai/in4up_ai.dart';

Future<String> _writeTempAudioFile() async {
  final dir = await Directory.systemTemp.createTemp('stt_remote_test_');
  final file = File('${dir.path}/chunk.wav');
  await file.writeAsBytes(List<int>.filled(64, 0));
  return file.path;
}

void main() {
  group('OpenAiCompatClient.transcribeAudio', () {
    late String audioPath;

    setUp(() async {
      audioPath = await _writeTempAudioFile();
    });

    tearDown(() async {
      try {
        await File(audioPath).parent.delete(recursive: true);
      } catch (_) {}
    });

    test('trả đúng JSON verbose_json khi server 200 OK', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), 'https://api.groq.com/v1/audio/transcriptions');
        // multipart body chứa field 'model' đã encode.
        final text = utf8.decode(request.bodyBytes, allowMalformed: true);
        expect(text, contains('name="model"'));
        expect(text, contains('whisper-large-v3'));
        expect(request.headers['authorization'], 'Bearer sk-test');

        final json = jsonEncode({
          'text': 'xin chào',
          'language': 'vietnamese',
          'segments': [
            {'start': 0.0, 'end': 1.2, 'text': 'xin chào'},
          ],
        });
        return http.Response(json, 200,
            headers: {'content-type': 'application/json'});
      });

      final client = OpenAiCompatClient(
        baseUrl: 'https://api.groq.com/v1',
        apiKey: 'sk-test',
        httpClient: mock,
      );

      final result = await client.transcribeAudio(
        audioFilePath: audioPath,
        model: 'whisper-large-v3',
      );

      expect(result['text'], 'xin chào');
      expect(result['segments'], isA<List<dynamic>>());
      expect((result['segments'] as List).length, 1);
    });

    test('không gửi field language khi language = auto (mặc định)', () async {
      final mock = MockClient((request) async {
        final text = utf8.decode(request.bodyBytes, allowMalformed: true);
        expect(text, isNot(contains('name="language"')));
        return http.Response(jsonEncode({'text': '', 'segments': []}), 200);
      });

      final client = OpenAiCompatClient(
        baseUrl: 'http://localhost:8000/v1',
        httpClient: mock,
      );

      await client.transcribeAudio(
        audioFilePath: audioPath,
        model: 'Systran/faster-whisper-large-v3',
        language: 'auto',
      );
    });

    test('HTTP 401 → AiApiException(unauthorized), KHÔNG treo', () async {
      final mock = MockClient((request) async {
        return http.Response('{"error":"bad key"}', 401);
      });
      final client = OpenAiCompatClient(
        baseUrl: 'https://api.groq.com/v1',
        apiKey: 'sk-wrong',
        httpClient: mock,
      );

      await expectLater(
        client.transcribeAudio(audioFilePath: audioPath, model: 'whisper-large-v3'),
        throwsA(isA<AiApiException>().having(
          (e) => e.code,
          'code',
          AiApiErrorCode.unauthorized,
        )),
      );
    });

    test('HTTP 429 → AiApiException(rateLimited)', () async {
      final mock = MockClient((request) async => http.Response('rate limited', 429));
      final client = OpenAiCompatClient(
        baseUrl: 'https://api.groq.com/v1',
        apiKey: 'sk-test',
        httpClient: mock,
      );

      await expectLater(
        client.transcribeAudio(audioFilePath: audioPath, model: 'whisper-large-v3'),
        throwsA(isA<AiApiException>().having(
          (e) => e.code,
          'code',
          AiApiErrorCode.rateLimited,
        )),
      );
    });

    test('mất mạng giữa chừng (ClientException) → AiApiException(noNetwork), '
        'lỗi có mã cấu trúc — không treo vô hạn', () async {
      final mock = MockClient((request) async {
        throw http.ClientException('Connection reset by peer');
      });
      final client = OpenAiCompatClient(
        baseUrl: 'https://api.groq.com/v1',
        apiKey: 'sk-test',
        httpClient: mock,
      );

      await expectLater(
        client.transcribeAudio(audioFilePath: audioPath, model: 'whisper-large-v3'),
        throwsA(isA<AiApiException>().having(
          (e) => e.code,
          'code',
          AiApiErrorCode.noNetwork,
        )),
      );
    });

    test('file audio không tồn tại → invalidResponse (không gọi mạng)', () async {
      var called = false;
      final mock = MockClient((request) async {
        called = true;
        return http.Response('{}', 200);
      });
      final client = OpenAiCompatClient(
        baseUrl: 'https://api.groq.com/v1',
        httpClient: mock,
      );

      await expectLater(
        client.transcribeAudio(
          audioFilePath: '/tmp/khong-ton-tai-${DateTime.now().microsecondsSinceEpoch}.wav',
          model: 'whisper-large-v3',
        ),
        throwsA(isA<AiApiException>().having(
          (e) => e.code,
          'code',
          AiApiErrorCode.invalidResponse,
        )),
      );
      expect(called, isFalse);
    });

    test('http:// cleartext bị chặn cho host public (không phải LAN)', () async {
      final client = OpenAiCompatClient(
        baseUrl: 'http://api.example.com/v1',
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );

      await expectLater(
        client.transcribeAudio(audioFilePath: audioPath, model: 'whisper-large-v3'),
        throwsA(isA<AiApiException>().having(
          (e) => e.code,
          'code',
          AiApiErrorCode.cleartextBlocked,
        )),
      );
    });
  });
}
