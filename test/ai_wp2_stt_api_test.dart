// test/ai_wp2_stt_api_test.dart — WP2 (API-003)
//
// Test logic thuần của tầng STT file qua API (không cần server/ffmpeg thật):
// - AiTranscription.fromJson: fixture verbose_json chuẩn OpenAI/Groq (words
//   có/không, field thiếu — parse phòng thủ, không fake).
// - OpenAiCompatClient.transcribeAudio: MockClient.streaming — body multipart
//   đúng (model/response_format/file/audio-wav, language chỉ khi mã ISO hợp
//   lệ), Authorization Bearer, 429 backoff retry ĐÚNG 1 lần, hết retry ⇒ mã
//   rateLimited, 200 rỗng ⇒ invalidResponse (không fake success), cleartext
//   public ⇒ chặn.
// - planRemoteChunks (thuần): 1 chunk khi ngắn; chia đều khi không có khoảng
//   lặng; snap biên vào trung tâm khoảng lặng ±90s; min chunk 60s; phủ kín
//   [0, duration] KHÔNG chồng lấn (kỷ luật hymt_chunking).
// - scanSilenceGaps: WAV PCM 16k mono thật trên đĩa — phát hiện khoảng lặng
//   ≥400ms, parse đúng offset chunk 'data' (kể cả header có LIST metadata).
// - SttEngineRemote (inject toàn bộ I/O): noProvider fail sạch; single-flight
//   busy; offset stitch đa chunk (uids đúng mốc file gốc); cancel giữa chừng
//   ⇒ mã (canceled); map language 'en-US'→'en', 'auto'→null; emptyResult.
// - Engine mặc định + AiProviderStore: offlineOnly(chưa cấu hình) ⇒ resolve
//   null ⇒ (noProvider) TRƯỚC khi đụng file/mạng (AT offline-only).

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in4up_ai/in4up_ai.dart';
import 'package:in4up_stt/in4up_stt.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _tProvider = AiProviderConfig(
  id: 'p1',
  label: 'Test server',
  baseUrl: 'https://api.test.local/v1',
  apiKey: 'sk-test',
  sttModel: 'whisper-large-v3',
);

Map<String, dynamic> _verboseJson(List<Map<String, dynamic>> segments,
        {String text = '', String language = 'en'}) =>
    {
      'task': 'transcribe',
      'language': language,
      'duration': 10.5,
      'text': text.isEmpty ? segments.map((s) => s['text']).join(' ') : text,
      'segments': segments,
    };

http.StreamedResponse _jsonResponse(Object body, {int status = 200}) {
  return http.StreamedResponse(
    http.ByteStream(Stream.value(utf8.encode(jsonEncode(body)))),
    status,
  );
}

/// WAV 16k mono 16-bit nhỏ (header chuẩn 44 byte + PCM).
List<int> _wavBytes(List<int> pcm) {
  List<int> le32(int v) => [v & 255, (v >> 8) & 255, (v >> 16) & 255, v >> 24];
  return [
    ...'RIFF'.codeUnits,
    ...le32(36 + pcm.length),
    ...'WAVE'.codeUnits,
    ...'fmt '.codeUnits,
    ...le32(16),
    1, 0, // PCM
    1, 0, // mono
    ...le32(16000),
    ...le32(32000),
    1, 0, // block align
    16, 0, // bits
    ...'data'.codeUnits,
    ...le32(pcm.length),
    ...pcm,
  ];
}

List<int> _silenceMs(int ms) => List.filled(32 * ms, 0);
List<int> _toneMs(int ms, {int amp = 2000}) =>
    List.generate(32 * ms, (i) => (i % 20 < 10 ? amp : -amp));

void main() {
  test('SttEngineType có remote (additive — không phá serialization cũ)', () {
    expect(SttEngineType.values, contains(SttEngineType.remote));
    expect(SttEngineType.remote.name, 'remote');
  });

  group('AiTranscription.fromJson — verbose_json chuẩn + phòng thủ', () {
    test('đầy đủ segments + words', () {
      final t = AiTranscription.fromJson(_verboseJson([
        {
          'id': 0,
          'start': 0.0,
          'end': 2.5,
          'text': ' Hello world.',
          'words': [
            {'word': 'Hello', 'start': 0.0, 'end': 0.5},
            {'word': 'world.', 'start': 0.6, 'end': 1.2},
          ],
        },
        {'id': 1, 'start': 3.0, 'end': 5.0, 'text': ' Second line.'},
      ], language: 'vi'));
      expect(t.text, isNotEmpty);
      expect(t.language, 'vi');
      expect(t.durationSeconds, 10.5);
      expect(t.segments, hasLength(2));
      expect(t.segments.first.words, hasLength(2));
      expect(t.segments.first.words.first.end, 0.5);
      expect(t.segments.last.words, isEmpty);
      expect(t.hasWords, isTrue);
    });

    test('thiếu words / thiếu id / segment text rỗng — không crash, không bịa',
        () {
      final t = AiTranscription.fromJson({
        'text': 'ok',
        'language': 'en',
        'segments': [
          {'start': 1, 'end': 2, 'text': '   '}, // rỗng → bỏ
          {'start': 3, 'end': 4, 'text': 'real'}, // thiếu id → fallback index
        ],
      });
      expect(t.segments, hasLength(1));
      expect(t.segments.first.id, 0);
      expect(t.segments.first.text, 'real');
      expect(t.hasWords, isFalse);
    });

    test('segments null / words hỏng — trả rỗng (caller coi là lỗi)', () {
      final t = AiTranscription.fromJson({'text': 'x', 'language': ''});
      expect(t.segments, isEmpty);
      expect(t.text, 'x');
    });
  });

  group('OpenAiCompatClient.transcribeAudio — MockClient.streaming', () {
    late Directory tmp;
    late String wavPath;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('wp2_client_test');
      wavPath = '${tmp.path}/test.wav';
      await File(wavPath).writeAsBytes(_wavBytes(_toneMs(50)));
    });
    tearDown(() async {
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    });

    test('multipart đúng: model/response_format/file + Bearer + audio/wav',
        () async {
      final bodies = <String>[];
      final client = OpenAiCompatClient(
        baseUrl: 'https://api.test.local/v1',
        apiKey: 'sk-test',
        httpClient: MockClient.streaming((req, bodyStream) async {
          expect(req.url.path, endsWith('/v1/audio/transcriptions'));
          expect(req.method, 'POST');
          expect(req.headers['authorization'], 'Bearer sk-test');
          expect(req.headers['content-type'], contains('multipart/form-data'));
          final bytes = await bodyStream
              .fold<List<int>>(<int>[], (a, d) => a..addAll(d));
          bodies.add(utf8.decode(bytes));
          return _jsonResponse(_verboseJson([
            {'id': 0, 'start': 0, 'end': 1, 'text': 'ok'},
          ]));
        }),
      );
      final t = await client.transcribeAudio(
        filePath: wavPath,
        model: 'whisper-large-v3',
        language: 'auto',
      );
      expect(t.segments, hasLength(1));
      expect(bodies, hasLength(1));
      final body = bodies.single;
      expect(body, contains('name="model"'));
      expect(body, contains('whisper-large-v3'));
      expect(body, contains('name="response_format"'));
      expect(body, contains('verbose_json'));
      expect(body, contains('name="temperature"'));
      expect(body, contains('name="file"; filename="test.wav"'));
      expect(body, contains('audio/wav'));
      // 'auto' KHÔNG phải mã ISO — phải omit để server tự detect.
      expect(body, isNot(contains('name="language"')));
    });

    test("language 'vi-VN' → field 'vi'; 'auto' → omit (server tự detect)",
        () async {
      final bodies = <String>[];
      final mk = () => OpenAiCompatClient(
            baseUrl: 'https://api.test.local/v1',
            httpClient: MockClient.streaming((req, bodyStream) async {
              final bytes = await bodyStream
                  .fold<List<int>>(<int>[], (a, d) => a..addAll(d));
              bodies.add(utf8.decode(bytes));
              return _jsonResponse(
                  _verboseJson([{'id': 0, 'start': 0, 'end': 1, 'text': 'ok'}]));
            }),
          );
      await mk().transcribeAudio(
          filePath: wavPath, model: 'm', language: 'vi-VN');
      expect(bodies.single, contains('name="language"'));
      expect(bodies.single, contains('\r\nvi\r\n'));
      bodies.clear();
      await mk().transcribeAudio(filePath: wavPath, model: 'm');
      expect(bodies.single, isNot(contains('name="language"')));
    });

    test('429 → backoff Retry-After → retry ĐÚNG 1 lần rồi thành công',
        () async {
      var n = 0;
      final client = OpenAiCompatClient(
        baseUrl: 'https://api.test.local/v1',
        httpClient: MockClient.streaming((req, bodyStream) async {
          n++;
          if (n == 1) {
            return http.StreamedResponse(
              http.ByteStream(Stream.value(utf8.encode(
                  jsonEncode({'error': {'message': 'slow down'}})))),
              429,
              headers: {'retry-after': '1'},
            );
          }
          return _jsonResponse(
              _verboseJson([{'id': 0, 'start': 0, 'end': 1, 'text': 'ok'}]));
        }),
      );
      final t = await client.transcribeAudio(filePath: wavPath, model: 'm');
      expect(n, 2, reason: '429 phải được retry đúng 1 lần');
      expect(t.text, 'ok');
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('429 hai lần liên tiếp ⇒ AiApiException rateLimited (không retry múa)',
        () async {
      var n = 0;
      final client = OpenAiCompatClient(
        baseUrl: 'https://api.test.local/v1',
        httpClient: MockClient.streaming((req, bodyStream) async {
          n++;
          return http.StreamedResponse(
            http.ByteStream(Stream.value(utf8.encode('{"error":{}}'))),
            429,
            headers: {'retry-after': '1'},
          );
        }),
      );
      await expectLater(
        client.transcribeAudio(filePath: wavPath, model: 'm'),
        throwsA(isA<AiApiException>()
            .having((e) => e.code, 'code', AiApiErrorCode.rateLimited)),
      );
      expect(n, 2, reason: 'tối đa 1 retry = tổng 2 request');
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('401 ⇒ unauthorized; 200 mà rỗng ⇒ invalidResponse (không fake)',
        () async {
      final unauthorized = OpenAiCompatClient(
        baseUrl: 'https://api.test.local/v1',
        httpClient: MockClient.streaming((req, bodyStream) async =>
            _jsonResponse({'error': {'message': 'bad key'}}, status: 401)),
      );
      await expectLater(
        unauthorized.transcribeAudio(filePath: wavPath, model: 'm'),
        throwsA(isA<AiApiException>()
            .having((e) => e.code, 'code', AiApiErrorCode.unauthorized)),
      );
      final empty = OpenAiCompatClient(
        baseUrl: 'https://api.test.local/v1',
        httpClient: MockClient.streaming((req, bodyStream) async =>
            _jsonResponse({'text': '', 'language': 'en', 'segments': []})),
      );
      await expectLater(
        empty.transcribeAudio(filePath: wavPath, model: 'm'),
        throwsA(isA<AiApiException>()
            .having((e) => e.code, 'code', AiApiErrorCode.invalidResponse)),
      );
    });

    test('baseUrl http công cộng ⇒ cleartextBlocked TRƯỚC khi đụng file',
        () async {
      final client = OpenAiCompatClient(baseUrl: 'http://public.example.com');
      await expectLater(
        client.transcribeAudio(filePath: '/no/such/file.wav', model: 'm'),
        throwsA(isA<AiApiException>()
            .having((e) => e.code, 'code', AiApiErrorCode.cleartextBlocked)),
      );
    });
  });

  group('planRemoteChunks — thuần (kỷ luật hymt_chunking)', () {
    test('ngắn hơn target ⇒ 1 chunk nguyên file', () {
      final c = planRemoteChunks(
        durationMs: 300000,
        targetChunkMs: 600000,
        silences: const [],
      );
      expect(c, hasLength(1));
      expect(c.single, (startMs: 0, endMs: 300000));
    });

    test('không có khoảng lặng ⇒ chia đều, phủ kín, không chồng lấn', () {
      final c = planRemoteChunks(
        durationMs: 300000,
        targetChunkMs: 120000,
        silences: const [],
      );
      expect(c, hasLength(3));
      expect(c.first.startMs, 0);
      expect(c.last.endMs, 300000);
      for (var i = 0; i < c.length; i++) {
        expect(c[i].endMs - c[i].startMs, greaterThanOrEqualTo(60000),
            reason: 'chunk $i phải ≥ minChunkMs');
        if (i > 0) {
          expect(c[i].startMs, c[i - 1].endMs,
              reason: 'contiguous — không mất đoạn, không lặp đoạn');
        }
      }
    });

    test('snap biên vào TRUNG TÂM khoảng lặng gần ideal (±90s)', () {
      final c = planRemoteChunks(
        durationMs: 300000,
        targetChunkMs: 120000,
        silences: [SttRemoteSilence(125.0, 135.0)], // mid = 130s
      );
      expect(c.first.endMs, 130000,
          reason: 'ideal 120s → snap mid 130s (dist 10s ≤ 90s)');
      expect(c[1].startMs, 130000);
    });

    test('khoảng lặng quá gần đầu chunk ⇒ clamp về minChunkMs (60s)', () {
      final c = planRemoteChunks(
        durationMs: 300000,
        targetChunkMs: 120000,
        silences: [SttRemoteSilence(25.0, 35.0)], // mid = 30s < 60s
      );
      expect(c.first.endMs, 60000);
    });

    test('một khoảng lặng không bị dùng cho 2 biên', () {
      final c = planRemoteChunks(
        durationMs: 480000,
        targetChunkMs: 120000,
        silences: [SttRemoteSilence(115.0, 125.0)], // 1 khoảng duy nhất
      );
      final borders = c.sublist(0, c.length - 1).map((x) => x.endMs).toList();
      final uniq = borders.toSet();
      expect(uniq.length, borders.length,
          reason: 'không có 2 biên trùng nhau');
    });

    test('duration ≤ 0 ⇒ rỗng (caller fail sạch, không chia đều bịa)', () {
      expect(
        planRemoteChunks(
            durationMs: 0, targetChunkMs: 600000, silences: const []),
        isEmpty,
      );
    });
  });

  group('scanSilenceGaps — WAV thật trên đĩa, stream không load RAM', () {
    late Directory tmp;
    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('wp2_silence_test');
    });
    tearDown(() async {
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    });

    test('phát hiện khoảng lặng ≥400ms giữa 2 đoạn tiếng', () async {
      final path = '${tmp.path}/a.wav';
      // 0.5s tiếng + 1s lặng + 1s tiếng + 0.5s lặng + 0.5s tiếng.
      await File(path).writeAsBytes(_wavBytes([
        ..._toneMs(500),
        ..._silenceMs(1000),
        ..._toneMs(1000),
        ..._silenceMs(500),
        ..._toneMs(500),
      ]));
      final gaps = await scanSilenceGaps(path);
      expect(gaps, hasLength(2));
      // Gap = [đầu chuỗi lặng, đầu cửa sổ tiếng kế tiếp].
      expect(gaps[0].startSeconds, closeTo(0.5, 0.2));
      expect(gaps[0].endSeconds, closeTo(1.5, 0.2));
      expect(gaps[1].startSeconds, closeTo(2.5, 0.2));
      expect(gaps[1].endSeconds, closeTo(3.0, 0.2));
    });

    test('lặng ngắn hơn 400ms KHÔNG tính là khoảng lặng', () async {
      final path = '${tmp.path}/b.wav';
      await File(path).writeAsBytes(_wavBytes([
        ..._toneMs(500),
        ..._silenceMs(200),
        ..._toneMs(500),
      ]));
      expect(await scanSilenceGaps(path), isEmpty);
    });

    test('header có LIST metadata → vẫn parse đúng offset chunk data',
        () async {
      List<int> le32(int v) => [v & 255, (v >> 8) & 255, (v >> 16) & 255, v >> 24];
      final path = '${tmp.path}/c.wav';
      final pcm = [
        ..._toneMs(500),
        ..._silenceMs(1000),
        ..._toneMs(500),
      ];
      final extra = [...'INFO'.codeUnits, 1, 2, 3, 4]; // LIST payload 8 byte
      // RIFF: [WAVE][LIST size=8][INFOxxxx][fmt 16][data]
      final bytes = <int>[
        ...'RIFF'.codeUnits,
        ...le32(36 + extra.length + pcm.length),
        ...'WAVE'.codeUnits,
        ...'LIST'.codeUnits,
        ...le32(extra.length),
        ...extra,
        ...'fmt '.codeUnits,
        ...le32(16),
        1, 0,
        1, 0,
        ...le32(16000),
        ...le32(32000),
        1, 0,
        16, 0,
        ...'data'.codeUnits,
        ...le32(pcm.length),
        ...pcm,
      ];
      await File(path).writeAsBytes(bytes);
      final gaps = await scanSilenceGaps(path);
      expect(gaps, hasLength(1));
      expect(gaps.single.startSeconds, closeTo(0.5, 0.2));
    });
  });

  group('SttEngineRemote — inject toàn bộ I/O', () {
    late Directory tmp;
    late String convertedPath;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('wp2_engine_test');
      convertedPath = '${tmp.path}/x_converted.wav';
      await File(convertedPath).writeAsBytes(_wavBytes(_toneMs(100)));
    });
    tearDown(() async {
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    });

    OpenAiCompatClient mockClient(
      Future<http.StreamedResponse> Function() responder,
    ) =>
        OpenAiCompatClient(
          baseUrl: 'https://api.test.local/v1',
          apiKey: 'sk-test',
          httpClient: MockClient.streaming(
              (req, bodyStream) async => await responder()),
        );

    test('chưa cấu hình provider ⇒ (noProvider) — KHÔNG fake success', () async {
      final engine = SttEngineRemote(providerResolver: () => null);
      await expectLater(
        engine.transcribeFile('whatever.mp3'),
        throwsA(isA<StateError>()
            .having((e) => e.message, 'msg', contains('(noProvider)'))),
      );
    });

    test('file ngắn ⇒ 1 chunk, upload thẳng converted, uid đúng fingerprint',
        () async {
      final uploads = <String>[];
      final capturer = OpenAiCompatClient(
        baseUrl: 'https://api.test.local/v1',
        apiKey: 'sk-test',
        httpClient: MockClient.streaming((req, bodyStream) async {
          final bytes = await bodyStream
              .fold<List<int>>(<int>[], (a, d) => a..addAll(d));
          final bodyText = utf8.decode(bytes);
          final m = RegExp(r'filename="([^"]+)"').firstMatch(bodyText);
          uploads.add(m?.group(1) ?? '?');
          return _jsonResponse(_verboseJson([
            {'id': 0, 'start': 0.5, 'end': 3.0, 'text': 'Hello there.'},
          ]));
        }),
      );
      final engine = SttEngineRemote(
        providerResolver: () => _tProvider,
        clientFactory: (_) => capturer,
        wavPreparer: (_) async => convertedPath,
        durationProber: (_) async => 60000,
        silenceDetector: (_) async => const [],
      );

      final r = await engine.transcribeFile(
        'source.mp3',
        options: {'language': 'vi-VN', 'audioFingerprint': 'FP'},
      );
      expect(r.engineUsed, SttEngineType.remote);
      expect(r.isFinal, isTrue);
      expect(r.segments.single.text, 'Hello there.');
      expect(r.segments.single.startSeconds, 0.5);
      expect(r.hasWordTimestamps, isFalse,
          reason: 'fake client không trả words');
      expect(
        r.segments.single.uid,
        ContentId.segmentUid(
            audioFingerprint: 'FP', startMs: 500, text: 'Hello there.'),
      );
      expect(uploads.single, 'x_converted.wav');
      expect(r.language, 'en', reason: 'language lấy từ server');
    });

    test('file dài ⇒ offset stitch đúng mốc file gốc + renumber id', () async {
      final cutCalls = <({double start, double dur})>[];
      var call = 0;
      // 5 phút, target 2 phút, lặng quanh 120s (mid 120s) → 3 chunks
      // [0,120s), [120s,240s), [240s,300s).
      final engine = SttEngineRemote(
        providerResolver: () => _tProvider,
        clientFactory: (_) => OpenAiCompatClient(
              baseUrl: 'https://api.test.local/v1',
              apiKey: 'sk-test',
              httpClient: MockClient.streaming((req, bodyStream) async {
                call++;
                // Timestamps CHUNK-RELATIVE (whisper server luôn trả vậy).
                return _jsonResponse(_verboseJson([
                  {
                    'id': 0,
                    'start': 1.0 + call,
                    'end': 10.0,
                    'text': 'chunk $call',
                  },
                ], language: 'en'));
              }),
            ),
        wavPreparer: (_) async => convertedPath,
        durationProber: (_) async => 300000,
        silenceDetector: (_) async => [SttRemoteSilence(118.0, 122.0)],
        targetChunkMs: 120000,
        segmentCutter: ({required String inputPath, required double startSeconds, required double durationSeconds, required String outputPath}) async {
          cutCalls.add((start: startSeconds, dur: durationSeconds));
          await File(outputPath).writeAsBytes(_wavBytes(_toneMs(10)));
          return true;
        },
      );

      var progressCalls = 0;
      final r = await engine.transcribeFile(
        'source.mp3',
        options: {
          'language': 'auto',
          'audioFingerprint': 'FP',
          'onProgress': (int i, int count, SttResult partial) {
            progressCalls++;
            expect(count, 3);
            expect(partial.isFinal, isFalse);
          },
        },
      );

      expect(call, 3, reason: '3 chunk → 3 request');
      expect(cutCalls, hasLength(3));
      expect(cutCalls[0].start, 0);
      expect(cutCalls[1].start, 120.0);
      expect(cutCalls[2].start, 240.0);
      expect(progressCalls, 3);

      // Stitch: chunk-rel start = 1+call → call1=2.0(+0), call2=3.0(+120s),
      // call3=4.0(+240s).
      expect(r.segments.map((s) => s.startSeconds).toList(),
          [2.0, 123.0, 244.0]);
      expect(r.segments.map((s) => s.id).toList(), [0, 1, 2]);
      expect(r.fullText, contains('chunk 1'));
      expect(r.fullText, contains('chunk 3'));
      // UID theo mốc FILE GỐC (không phải mốc chunk).
      expect(
        r.segments[1].uid,
        ContentId.segmentUid(
            audioFingerprint: 'FP', startMs: 123000, text: 'chunk 2'),
      );
    });

    test('single-flight (mẫu hymt_slot): request kế tiếp ⇒ (busy)', () async {
      final gate = Completer<void>();
      final engine = SttEngineRemote(
        providerResolver: () => _tProvider,
        clientFactory: (_) => mockClient(() async {
              await gate.future;
              return _jsonResponse(_verboseJson(
                  [{'id': 0, 'start': 0, 'end': 1, 'text': 'ok'}]));
            }),
        wavPreparer: (_) async => convertedPath,
        durationProber: (_) async => 60000,
        silenceDetector: (_) async => const [],
      );
      final first = engine.transcribeFile('source.mp3');
      await pumpEventQueue();
      await expectLater(
        engine.transcribeFile('source.mp3'),
        throwsA(isA<StateError>()
            .having((e) => e.message, 'msg', contains('(busy)'))),
      );
      gate.complete();
      final r = await first;
      expect(r.segments, isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('shouldCancel trước chunk 1 ⇒ (canceled), không request nào đi ra',
        () async {
      var requests = 0;
      final engine = SttEngineRemote(
        providerResolver: () => _tProvider,
        clientFactory: (_) => OpenAiCompatClient(
              baseUrl: 'https://api.test.local/v1',
              httpClient: MockClient.streaming((req, b) async {
                requests++;
                return _jsonResponse(const {});
              }),
            ),
        wavPreparer: (_) async => convertedPath,
        durationProber: (_) async => 300000,
        silenceDetector: (_) async => const [],
        targetChunkMs: 120000,
      );
      await expectLater(
        engine.transcribeFile(
          'source.mp3',
          options: {'shouldCancel': () => true},
        ),
        throwsA(isA<StateError>()
            .having((e) => e.message, 'msg', contains('(canceled)'))),
      );
      expect(requests, 0);
    });

    test('server trả rỗng ⇒ (emptyResult) — không fake success', () async {
      final engine = SttEngineRemote(
        providerResolver: () => _tProvider,
        clientFactory: (_) => mockClient(() async => _jsonResponse(
            {'text': '', 'language': 'en', 'segments': []})),
        wavPreparer: (_) async => convertedPath,
        durationProber: (_) async => 60000,
        silenceDetector: (_) async => const [],
      );
      await expectLater(
        engine.transcribeFile('source.mp3'),
        throwsA(isA<StateError>()
            .having((e) => e.message, 'msg', contains('(emptyResult)'))),
      );
    });

    test('AiApiException.noNetwork ⇒ StateError mã (noNetwork)', () async {
      final engine = SttEngineRemote(
        providerResolver: () => _tProvider,
        clientFactory: (_) => OpenAiCompatClient(
              baseUrl: 'https://api.test.local/v1',
              httpClient: MockClient.streaming((req, b) async {
                throw http.ClientException('connection reset');
              }),
            ),
        wavPreparer: (_) async => convertedPath,
        durationProber: (_) async => 60000,
        silenceDetector: (_) async => const [],
      );
      await expectLater(
        engine.transcribeFile('source.mp3'),
        throwsA(isA<StateError>()
            .having((e) => e.message, 'msg', contains('(noNetwork)'))),
      );
    });

    test("language mapping: 'en-US'→'en' gửi server, 'auto'→null", () async {
      final langs = <String?>[];
      final engine = SttEngineRemote(
        providerResolver: () => _tProvider,
        clientFactory: (_) => OpenAiCompatClient(
              baseUrl: 'https://api.test.local/v1',
              apiKey: 'sk-test',
              httpClient: MockClient.streaming((req, bodyStream) async {
                final bytes = await bodyStream
                    .fold<List<int>>(<int>[], (a, d) => a..addAll(d));
                final bodyText = utf8.decode(bytes);
                final m = RegExp(r'name="language"\r\n\r\n([^\r]+)').firstMatch(bodyText);
                langs.add(m?.group(1));
                return _jsonResponse(_verboseJson(
                    [{'id': 0, 'start': 0, 'end': 1, 'text': 'ok'}]));
              }),
            ),
        wavPreparer: (_) async => convertedPath,
        durationProber: (_) async => 60000,
        silenceDetector: (_) async => const [],
      );
      await engine.transcribeFile('a.mp3', options: {'language': 'en-US'});
      await engine.transcribeFile('b.mp3', options: {'language': 'auto'});
      expect(langs, ['en', null]);
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('capabilities trung thực (AT: live mic + offline KHÔNG qua API)',
        () async {
      final caps = SttEngineRemote().capabilities;
      expect(caps.supportsFileTranscription, isTrue);
      expect(caps.supportsOffline, isFalse);
      expect(caps.supportsLiveMic, isFalse);
      expect(caps.supportsWordTimestamps, isTrue);
      expect(caps.supportsChunking, isTrue);
    });
  });

  group('AiProviderStore + engine mặc định — offline gate (AT)', () {
    test('offlineOnly(sttFile) ⇒ resolveProvider null ⇒ (noProvider) TRƯỚC I/O',
        () async {
      SharedPreferences.setMockInitialValues({
        'ai_providers_json_v1': encodeProviders([_tProvider]),
        'ai_routing_json_v1': jsonEncode(const AiRoutingPrefs(
          modes: {AiRouteCapability.sttFile: AiRouteMode.offlineOnly},
        ).toJson()),
      });
      await AiProviderStore.instance.ensureLoaded();
      expect(AiProviderStore.instance.apiAllowed(AiRouteCapability.sttFile),
          isFalse);

      final engine = SttEngineRemote(); // default resolver
      await expectLater(
        engine.transcribeFile('/no/such/file.mp3'),
        throwsA(isA<StateError>()
            .having((e) => e.message, 'msg', contains('(noProvider)'))),
      );
    });

    test('onlineFirst(sttFile) + provider có sttModel ⇒ resolve được provider',
        () async {
      await AiProviderStore.instance.updateRouting(const AiRoutingPrefs(
        modes: {AiRouteCapability.sttFile: AiRouteMode.onlineFirst},
      ));
      final p = AiProviderStore.instance.resolveProvider(
          AiRouteCapability.sttFile);
      expect(p, isNotNull);
      expect(p!.id, 'p1');
      expect(p.sttModel, 'whisper-large-v3');
    });
  });
}
