// test/ai_wp1_remote_test.dart — WP1 (API-002)
//
// Test logic thuần của tầng LLM remote (không cần server thật):
// - planLlmRoute: routing thuần — offlineOnly ⇒ KHÔNG có stop remote
//   (AT: "không có request /chat/completions nào đi ra").
// - AiSseChatParser: SSE chuẩn OpenAI + biến thể (data: không space, CRLF,
//   keep-alive, JSON hỏng, usage/x_groq, [DONE] không newline).
// - OpenAiCompatClient.chatStream: MockClient.streaming — ghép delta, usage,
//   mã lỗi cấu trúc (429/noNetwork), cancel token đóng stream SẠCH, idle
//   timeout hữu hạn.
// - AiEngineRemote: initialize encoded `api://<providerId>/<model>`,
//   isBusy/state trung thực, Word Lookup parse đúng JSON schema như Gemma
//   (fixture JSON thật của model remote, bọc markdown fence), emptyOutput.
// - AiServiceFacade: remote chết (connection refused) ⇒ fallback mock trung
//   thực + mã lỗi cấu trúc; offlineOnly ⇒ không có vết request API nào.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in4up_ai/in4up_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

String sse(Object? obj) => 'data: ${jsonEncode(obj)}\n\n';

http.StreamedResponse sseResponse(List<String> events, {int status = 200}) {
  return http.StreamedResponse(
    http.ByteStream(
      Stream.fromIterable(events.map(utf8.encode).toList()),
    ),
    status,
  );
}

const _tProvider = AiProviderConfig(
  id: 'p1',
  label: 'Test server',
  baseUrl: 'https://api.test.local/v1',
  chatModel: 'llama3.1:8b',
);

void main() {
  group('planLlmRoute — routing thuần (AT offline-only)', () {
    test('offlineOnly ⇒ KHÔNG có stop remote — không request nào đi ra', () {
      final plan = planLlmRoute(
        mode: AiRouteMode.offlineOnly,
        remoteAvailable: true,
        localModelReady: false,
      );
      expect(plan.usesRemote, isFalse, reason: 'offlineOnly tuyệt đối không gọi API');
      expect(plan.stops, [AiLlmRouteStop.local]);
      expect(plan.remoteFirst, isFalse);
    });

    test('chưa cấu hình provider ⇒ [local] cho mọi mode (app như cũ)', () {
      for (final mode in AiRouteMode.values) {
        final plan = planLlmRoute(
          mode: mode,
          remoteAvailable: false,
          localModelReady: false,
        );
        expect(plan.usesRemote, isFalse, reason: mode.name);
        expect(plan.stops, [AiLlmRouteStop.local]);
      }
    });

    test('onlineFirst ⇒ remote trước, local fallback', () {
      final plan = planLlmRoute(
        mode: AiRouteMode.onlineFirst,
        remoteAvailable: true,
        localModelReady: true,
      );
      expect(plan.stops, [AiLlmRouteStop.remote, AiLlmRouteStop.local]);
      expect(plan.remoteFirst, isTrue);
    });

    test('offlineFirst + model local sẵn sàng ⇒ local trước, remote dự phòng',
        () {
      final plan = planLlmRoute(
        mode: AiRouteMode.offlineFirst,
        remoteAvailable: true,
        localModelReady: true,
      );
      expect(plan.stops, [AiLlmRouteStop.local, AiLlmRouteStop.remote]);
      expect(plan.remoteFirst, isFalse);
    });

    test('offlineFirst + KHÔNG có model local ⇒ remote trước (mock là lớp cuối)',
        () {
      final plan = planLlmRoute(
        mode: AiRouteMode.offlineFirst,
        remoteAvailable: true,
        localModelReady: false,
      );
      expect(plan.stops, [AiLlmRouteStop.remote, AiLlmRouteStop.local]);
      expect(plan.remoteFirst, isTrue);
    });
  });

  group('AiSseChatParser — SSE chuẩn OpenAI + biến thể ngoài đời', () {
    test('ghép delta content + usage ở chunk cuối + [DONE]', () {
      final body = [
        sse({
          'id': 'chatcmpl-1',
          'choices': [
            {'index': 0, 'delta': {'role': 'assistant', 'content': ''}}
          ]
        }),
        sse({
          'choices': [
            {'index': 0, 'delta': {'content': 'Hello'}}
          ]
        }),
        sse({
          'choices': [
            {'index': 0, 'delta': {'content': ' world'}}
          ]
        }),
        sse({
          'choices': [
            {'index': 0, 'delta': {}, 'finish_reason': 'stop'}
          ],
          'usage': {'prompt_tokens': 12, 'completion_tokens': 34},
        }),
        'data: [DONE]\n\n',
      ].join();
      final parser = AiSseChatParser();
      final chunks = parser.feed(body);
      expect(parser.isDone, isTrue);
      final text = chunks
          .where((c) => c.deltaContent != null)
          .map((c) => c.deltaContent!)
          .join();
      expect(text, 'Hello world');
      final usage = chunks.lastWhere((c) => c.usage != null).usage!;
      expect(usage.promptTokens, 12);
      expect(usage.completionTokens, 34);
      expect(usage.total, 46);
    });

    test('chunk cắt giữa dòng / giữa ký tự đa byte (feed 2 lần)', () {
      final parser = AiSseChatParser();
      final out = parser.feed('data: {"choices":[{"delta":{"con');
      expect(out, isEmpty);
      out.addAll(parser.feed('tent":"tiếng Việt"}}]}\n\n'));
      expect(out.map((c) => c.deltaContent ?? '').join(), 'tiếng Việt');
    });

    test('data: không space + CRLF + keep-alive comment', () {
      final body =
          ': ping\r\n\r\ndata:{"choices":[{"delta":{"content":"A"}}]}\r\n\r\n'
          'data: [DONE]\r\n\r\n';
      final parser = AiSseChatParser();
      final chunks = parser.feed(body);
      expect(parser.isDone, isTrue);
      expect(chunks.map((c) => c.deltaContent ?? '').join(), 'A');
    });

    test('JSON hỏng của 1 event bị bỏ qua — stream không chết', () {
      final body = [
        'data: not-json\n\n',
        sse({
          'choices': [
            {'delta': {'content': 'B'}}
          ]
        }),
      ].join();
      final parser = AiSseChatParser();
      final chunks = parser.feed(body);
      expect(chunks.map((c) => c.deltaContent ?? '').join(), 'B');
    });

    test('close() xử lý [DONE] cuối stream không có newline (Ollama cũ)', () {
      final parser = AiSseChatParser();
      final out = parser.feed(sse({
        'choices': [
          {'delta': {'content': 'C'}}
        ]
      }));
      expect(out.map((c) => c.deltaContent ?? '').join(), 'C');
      final tail = parser.close('data: [DONE]');
      expect(tail, isEmpty);
      expect(parser.isDone, isTrue);
    });

    test('usage kiểu Groq (x_groq.usage) và OpenAI include_usage (choices rỗng)',
        () {
      final groq = AiSseChatParser.parseChunkBody(
          '{"x_groq":{"usage":{"prompt_tokens":5,"completion_tokens":7}}}');
      expect(groq, isNotNull);
      expect(groq!.usage, isNotNull);
      expect(groq.usage!.completionTokens, 7);

      final openAiUsage = AiSseChatParser.parseChunkBody(
          '{"choices":[],"usage":{"prompt_tokens":9,"completion_tokens":8,"total_tokens":17}}');
      expect(openAiUsage, isNotNull);
      expect(openAiUsage!.usage!.total, 17);
    });
  });

  group('OpenAiCompatClient.chatStream — MockClient.streaming', () {
    test('POST đúng body chuẩn OpenAI + ghép delta + usage', () async {
      http.Request? captured;
      final client = OpenAiCompatClient(
        baseUrl: 'https://api.test.local/v1',
        apiKey: 'k-test',
        httpClient: MockClient.streaming((req) async {
          captured = req as http.Request;
          return sseResponse([
            sse({
              'choices': [
                {'delta': {'content': 'Xin '}}
              ]
            }),
            sse({
              'choices': [
                {'delta': {'content': 'chào'}}
              ]
            }),
            sse({
              'choices': [
                {'delta': {}, 'finish_reason': 'stop'}
              ],
              'usage': {'prompt_tokens': 10, 'completion_tokens': 2},
            }),
            'data: [DONE]\n\n',
          ]);
        }),
      );

      final out = <String>[];
      AiChatUsage? usage;
      await for (final chunk in client.chatStream(
        model: 'llama3.1:8b',
        messages: const [
          AiChatMessage('system', 's'),
          AiChatMessage('user', 'hi'),
        ],
        temperature: 0.3,
        maxTokens: 64,
        includeUsage: true,
      )) {
        if (chunk.deltaContent != null) out.add(chunk.deltaContent!);
        if (chunk.usage != null) usage = chunk.usage;
      }
      expect(out.join(), 'Xin chào');
      expect(usage, isNotNull);
      expect(usage!.promptTokens, 10);

      expect(captured, isNotNull);
      expect(captured!.method, 'POST');
      expect(captured!.url.toString(), 'https://api.test.local/v1/chat/completions');
      expect(captured!.headers['Authorization'], 'Bearer k-test');
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['stream'], true);
      expect(body['model'], 'llama3.1:8b');
      expect(body['temperature'], 0.3);
      expect(body['max_tokens'], 64);
      expect(body['stream_options'], {'include_usage': true});
      expect((body['messages'] as List).length, 2);
    });

    test('HTTP 429 ⇒ AiChatException rateLimited (mã cấu trúc)', () async {
      final client = OpenAiCompatClient(
        baseUrl: 'https://api.test.local/v1',
        httpClient: MockClient.streaming((req) async => sseResponse(
              ['{"error":{"message":"Rate limit reached"}}'],
              status: 429,
            )),
      );
      final errorCompleter = Completer<Object>();
      client.chatStream(
        model: 'm',
        messages: const [AiChatMessage('user', 'x')],
      ).listen(null, onError: (Object e) {
        if (!errorCompleter.isCompleted) errorCompleter.complete(e);
      });
      final e = await errorCompleter.future;
      expect(e, isA<AiChatException>());
      expect((e as AiChatException).code, AiChatErrorCode.rateLimited);
      expect(e.statusCode, 429);
    });

    test('mạng đứt (ClientException) ⇒ noNetwork — dừng sạch', () async {
      final client = OpenAiCompatClient(
        baseUrl: 'https://api.test.local/v1',
        httpClient: MockClient.streaming((req) async {
          throw http.ClientException('Connection refused', req.url);
        }),
      );
      final errorCompleter = Completer<Object>();
      client.chatStream(
        model: 'm',
        messages: const [AiChatMessage('user', 'x')],
      ).listen(null, onError: (Object e) {
        if (!errorCompleter.isCompleted) errorCompleter.complete(e);
      });
      final e = await errorCompleter.future;
      expect(e, isA<AiChatException>());
      expect((e as AiChatException).code, AiChatErrorCode.noNetwork);
    });

    test('cancel token giữa stream ⇒ lỗi canceled + socket bị đóng', () async {
      final upstream = StreamController<List<int>>();
      var upstreamCanceled = false;
      upstream.onCancel = () => upstreamCanceled = true;

      final client = OpenAiCompatClient(
        baseUrl: 'https://api.test.local/v1',
        httpClient: MockClient.streaming(
          (req) async => http.StreamedResponse(
            http.ByteStream(upstream.stream),
            200,
          ),
        ),
      );

      final emitted = <String>[];
      final errorCompleter = Completer<Object>();
      final token = AiChatCancelToken();
      client.chatStream(
        model: 'm',
        messages: const [AiChatMessage('user', 'x')],
        cancelToken: token,
        idleTimeout: const Duration(seconds: 30),
      ).listen(
        (chunk) {
          if (chunk.deltaContent != null) emitted.add(chunk.deltaContent!);
        },
        onError: (Object e) {
          if (!errorCompleter.isCompleted) errorCompleter.complete(e);
        },
      );

      // Chờ request bắt đầu rồi nhận 1 delta.
      await pumpEventQueue();
      upstream.add(utf8.encode(sse({
        'choices': [
          {'delta': {'content': 'A'}}
        ]
      })));
      await pumpEventQueue();
      expect(emitted, ['A']);

      // User bấm Dừng / đóng màn — token hủy ngay giữa lúc generate.
      token.cancel('user stopped');
      final e = await errorCompleter.future.timeout(const Duration(seconds: 5));
      expect(e, isA<AiChatException>());
      expect((e as AiChatException).code, AiChatErrorCode.canceled);

      // Socket đã bị đóng (cancel subscription của response stream) và
      // KHÔNG token nào chảy tiếp sau khi hủy.
      await pumpEventQueue();
      expect(upstreamCanceled, isTrue);
      expect(token.isCancelled, isTrue);
      final emittedAfter = List.of(emitted);
      upstream.add(utf8.encode(sse({
        'choices': [
          {'delta': {'content': 'LEAK'}}
        ]
      })));
      await pumpEventQueue();
      expect(emitted, emittedAfter);
      await upstream.close();
    });

    test('idle timeout hữu hạn khi server im lặng ⇒ lỗi timeout', () async {
      final upstream = StreamController<List<int>>();
      var upstreamCanceled = false;
      upstream.onCancel = () => upstreamCanceled = true;
      final client = OpenAiCompatClient(
        baseUrl: 'https://api.test.local/v1',
        httpClient: MockClient.streaming(
          (req) async => http.StreamedResponse(
            http.ByteStream(upstream.stream),
            200,
          ),
        ),
      );
      final errorCompleter = Completer<Object>();
      client.chatStream(
        model: 'm',
        messages: const [AiChatMessage('user', 'x')],
        idleTimeout: const Duration(milliseconds: 80),
      ).listen(null, onError: (Object e) {
        if (!errorCompleter.isCompleted) errorCompleter.complete(e);
      });
      final e = await errorCompleter.future.timeout(const Duration(seconds: 5));
      expect((e as AiChatException).code, AiChatErrorCode.timeout);
      // Timeout ⇒ socket bị đóng (cancel subscription), không chờ vô hạn.
      await pumpEventQueue();
      expect(upstreamCanceled, isTrue);
      await upstream.close();
    });
  });

  group('AiEngineRemote — engine cắm vào interface AiEngine', () {
    test('initialize nhận config encoded api://<providerId>/<model>', () async {
      final engine = AiEngineRemote(provider: _tProvider);
      expect(await engine.initialize(modelPath: 'api://p1/llama3.1:8b'), isTrue);
      expect(engine.modelId, 'llama3.1:8b');
      expect(engine.state, AiEngineState.ready);

      // Model override qua encoded path (model có thể chứa '/').
      expect(await engine.initialize(modelPath: 'api://p1/or/deepseek-r1'), isTrue);
      expect(engine.modelId, 'or/deepseek-r1');

      // modelPath rỗng ⇒ dùng chatModel của provider.
      expect(await engine.initialize(modelPath: ''), isTrue);
      expect(engine.modelId, 'llama3.1:8b');

      await engine.dispose();
    });

    test('initialize từ chối provider lệch + đường dẫn file .gguf', () async {
      final wrong = AiEngineRemote(provider: _tProvider);
      expect(await wrong.initialize(modelPath: 'api://other/x'), isFalse);
      expect(await wrong.initialize(modelPath: '/storage/gemma-2b.gguf'), isFalse);
      await wrong.dispose();

      const noModel = AiProviderConfig(
          id: 'p9', label: 'No model', baseUrl: 'https://api.test.local/v1');
      final noModelEngine = AiEngineRemote(provider: noModel);
      expect(await noModelEngine.initialize(modelPath: ''), isFalse);
      await noModelEngine.dispose();
    });

    test('modelReady complete ngay — isBusy/state trung thực qua 1 request',
        () async {
      final upstream = StreamController<List<int>>();
      final engine = AiEngineRemote(
        provider: _tProvider,
        httpClient: MockClient.streaming(
          (req) async => http.StreamedResponse(
            http.ByteStream(upstream.stream),
            200,
          ),
        ),
      );
      await engine.initialize(modelPath: 'api://p1/llama3.1:8b');
      await engine.modelReady.timeout(const Duration(seconds: 1));
      expect(engine.isBusy, isFalse);

      final doneCompleter = Completer<void>();
      final chunks = <String>[];
      engine.chatStream(
        messages: const [AiChatMessage('user', 'hi')],
      ).listen(
        (c) {
          if (c.deltaContent != null) chunks.add(c.deltaContent!);
        },
        onError: (Object e) {
          if (!doneCompleter.isCompleted) doneCompleter.complete();
        },
        onDone: () {
          if (!doneCompleter.isCompleted) doneCompleter.complete();
        },
      );
      expect(engine.isBusy, isTrue);
      expect(engine.state, AiEngineState.processing);

      upstream.add(utf8.encode(sse({
        'choices': [
          {'delta': {'content': 'ok'}}
        ]
      })));
      await pumpEventQueue();
      await upstream.close();
      await doneCompleter.future.timeout(const Duration(seconds: 5));
      expect(chunks, ['ok']);
      expect(engine.isBusy, isFalse);
      expect(engine.state, AiEngineState.ready);
      await engine.dispose();
    });

    test('Word Lookup qua API parse đúng JSON schema như Gemma (fixture)',
        () async {
      // Fixture mô phỏng output thật của model remote (Gemini/GPT/Ollama)
      // cho prompt wordLookup của AiPromptsLibrary: JSON đúng schema, thường
      // bọc markdown fence — pipeline fromGemmaJson phải parse được y Gemma.
      final payload = <String, dynamic>{
        'summary': 'may mắn tình cờ',
        'topics': ['Vocabulary'],
        'technical_terms': <Map<String, dynamic>>[],
        'action_items': <String>[],
        'language': 'en',
        'word_detail': {
          'word': 'serendipity',
          'meaning': 'may mắn tình cờ; tìm thấy điều tốt không ngờ tới',
          'cefr_level': 'C1',
          'word_type': 'noun',
          'etymology_hint':
              'Horace Walpole đặt ra năm 1754 từ truyện Ba vị vua xứ Serendip.',
          'memory_hook': 'Tình cờ lục ngăn kéo cũ tìm ra bức thư quý.',
        },
        'pao_suggestions': [
          'Einstein (P) nhặt (A) tờ lottery trúng (O) khi cúi nhặt kính.',
          'Hermione (P) mở (A) cuốn sách hiếm giữa đống đồ cũ (O).',
          'Bạn (P) gặp (A) thầy cũ ở quán cà phê lạ (O).',
        ],
        'context_examples': [
          'Finding that café was pure serendipity.',
          'By serendipity, she sat next to her future boss.',
        ],
        'ipa_fallback': '/ˌserənˈdɪpəti/',
        'visual_prompt': 'Một ngăn kéo cũ mở ra với ánh sáng vàng.',
      };
      final fullText = '```json\n${jsonEncode(payload)}\n```';
      // Chia như stream thật: fence mở, nửa đầu, nửa sau, chunk cuối usage.
      final mid = fullText.length ~/ 2;
      final events = [
        sse({
          'choices': [
            {'delta': {'role': 'assistant'}}
          ]
        }),
        sse({
          'choices': [
            {'delta': {'content': fullText.substring(0, mid)}}
          ]
        }),
        sse({
          'choices': [
            {'delta': {'content': fullText.substring(mid)}}
          ]
        }),
        sse({
          'choices': [
            {'delta': {}, 'finish_reason': 'stop'}
          ],
          'usage': {'prompt_tokens': 210, 'completion_tokens': 96},
        }),
        'data: [DONE]\n\n',
      ];
      final engine = AiEngineRemote(
        provider: _tProvider,
        httpClient: MockClient.streaming((req) async => sseResponse(events)),
      );
      await engine.initialize(modelPath: 'api://p1/llama3.1:8b');

      final result = await engine
          .analyze(text: 'serendipity', type: AiAnalysisType.wordLookup)
          .first;
      expect(result.success, isTrue);
      expect(result.analysisType, AiAnalysisType.wordLookup);
      expect(result.summary, 'may mắn tình cờ');
      expect(result.wordDetail, isNotNull);
      expect(result.wordDetail!.word, 'serendipity');
      expect(result.wordDetail!.cefrLevel, 'C1');
      expect(result.wordDetail!.wordType, 'noun');
      expect(result.wordDetail!.memoryHook, contains('ngăn kéo'));
      expect(result.contextExamples, hasLength(2));
      expect(result.paoSuggestions, hasLength(3));
      expect(result.ipaFallback, '/ˌserənˈdɪpəti/');
      expect(engine.lastUsage, isNotNull);
      expect(engine.lastUsage!.promptTokens, 210);
      await engine.dispose();
    });

    test('stream xong mà không có nội dung ⇒ emptyOutput (mã cấu trúc)',
        () async {
      final engine = AiEngineRemote(
        provider: _tProvider,
        httpClient: MockClient.streaming((req) async => sseResponse([
              sse({
                'choices': [
                  {'delta': {'role': 'assistant'}}
                ]
              }),
              'data: [DONE]\n\n',
            ])),
      );
      await engine.initialize(modelPath: 'api://p1/llama3.1:8b');
      final result = await engine
          .analyze(text: 'hello', type: AiAnalysisType.wordLookup)
          .first;
      expect(result.success, isFalse);
      expect(result.errorReason, contains('emptyOutput'));
      expect(engine.lastErrorOrNull?.code, AiChatErrorCode.emptyOutput);
      await engine.dispose();
    });

    test('AiRemoteJsonExtractor — lột fence + câu dẫn quanh JSON', () {
      expect(AiRemoteJsonExtractor.extract('```json\n{"a":1}\n```'), '{"a":1}');
      expect(AiRemoteJsonExtractor.extract('```\n{"a":1}\n```'), '{"a":1}');
      expect(AiRemoteJsonExtractor.extract('Sure! Here: {"a":1} hope it helps'),
          '{"a":1}');
      expect(AiRemoteJsonExtractor.extract('no braces at all'),
          'no braces at all');
    });
  });

  group('AiServiceFacade — routing + fallback (server chết thật sự)', () {
    // Provider trỏ tới port bị đóng (127.0.0.1:9 — connection refused tức
    // thì) ⇒ mọi request API đều fail nhanh với noNetwork.
    const deadProvider = AiProviderConfig(
      id: 'dead',
      label: 'Dead server',
      baseUrl: 'http://127.0.0.1:9/v1',
      chatModel: 'llama3.1:8b',
    );

    test('remote chết ⇒ fallback mock TRUNG THỰC + mã lỗi cấu trúc',
        () async {
      SharedPreferences.setMockInitialValues({
        'ai_providers_json_v1': encodeProviders([deadProvider]),
        'ai_routing_json_v1': jsonEncode(const AiRoutingPrefs(
          modes: {AiRouteCapability.chat: AiRouteMode.onlineFirst},
        ).toJson()),
      });
      final facade = AiServiceFacade();
      await facade.initialize(modelPath: '', useMock: true);
      await AiProviderStore.instance.ensureLoaded();

      expect(facade.isRemoteChatConfigured, isTrue);
      expect(facade.isRemoteChatPreferred, isTrue,
          reason: 'onlineFirst + provider ⇒ remote đứng đầu route');

      await facade.sendMessage('hello');
      final messages = facade.chatMessages;
      expect(messages, hasLength(2));
      final last = messages.last;
      expect(last.role, ChatRole.assistant);
      expect(last.isError, isFalse);
      // Mock disclaimer trung thực (pattern _useMock cũ) — không fake success.
      expect(last.text, contains('MẪU'));
      // Lỗi API được ghi theo MÃ — UI branch theo mã, không match chuỗi.
      expect(facade.lastChatErrorCode, AiChatErrorCode.noNetwork);

      await facade.dispose();
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('offlineOnly ⇒ KHÔNG có vết request API nào (AT routing)', () async {
      // Store singleton đã nạp ở test trên — đổi routing live qua API store
      // (cùng cơ chế màn Server & API dùng).
      await AiProviderStore.instance.updateRouting(const AiRoutingPrefs(
        modes: {AiRouteCapability.chat: AiRouteMode.offlineOnly},
      ));

      final facade = AiServiceFacade();
      await facade.initialize(modelPath: '', useMock: true);

      // Provider vẫn được cấu hình, nhưng mode chặn ⇒ không dùng API.
      expect(facade.isRemoteChatConfigured, isTrue);
      expect(facade.isRemoteChatPreferred, isFalse);
      expect(facade.debugUsesRemoteChatRoute, isFalse);

      await facade.sendMessage('hi');
      final last = facade.chatMessages.last;
      expect(last.role, ChatRole.assistant);
      // Không request nào đi ra ⇒ không có lỗi API nào được ghi (nếu có
      // request tới Dead server, lastChatApiError chắc chắn != null).
      expect(facade.lastChatApiError, isNull);
      expect(facade.lastChatErrorCode, isNull);

      await facade.dispose();
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
