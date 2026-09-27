// test/llm_mt_engine_test.dart
//
// WP3 (API-004) — test thuần cho LlmMtEngine + phần client WP3 dùng chung.
// KHÔNG network thật (backend/env inject), KHÔNG key (provider giả dạng
// server LAN không cần key — tuân luật "không hard-code key, kể cả key test").
//
// Phủ AT WP3:
// - Prompt nghiêm ngặt: chỉ dịch, không giải thích, giữ slot `__G{n}__`
//   (test nội dung prompt + parse/làm sạch output).
// - Mã lỗi cấu trúc (errorCode) — không match chuỗi.
// - Chuỗi fallback nguyên vẹn khi tầng tắt/mất mạng; routing offlineFirst /
//   onlineFirst chèn đúng vị trí; glossary → slot → restore nguyên vẹn.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in4up_ai/in4up_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:in4up/features/translation/cache/translation_cache.dart';
import 'package:in4up/features/translation/engines/llm_mt_engine.dart';
import 'package:in4up/features/translation/engines/llm_mt_prompts.dart';
import 'package:in4up/features/translation/engines/translation_engine.dart';
import 'package:in4up/features/translation/glossary/translation_glossary.dart';
import 'package:in4up/features/translation/translation_service.dart';

// ─────────────────────────────── Fakes ───────────────────────────────

/// Provider giả dạng server LAN (không cần apiKey — không có key nào trong
/// code test, kể cả key giả).
const AiProviderConfig _lanProvider = AiProviderConfig(
  id: 'test-lan',
  label: 'Server nhà (test)',
  baseUrl: 'http://192.168.1.10:11434/v1',
  chatModel: 'test-mt-model',
);

class _FakeEnv implements LlmMtEnv {
  _FakeEnv({
    this.provider,
    this.network = true,
    this.mode = AiRouteMode.offlineFirst,
  });

  final AiProviderConfig? provider;
  final bool network;
  final AiRouteMode mode;

  @override
  Future<AiProviderConfig?> resolveProvider() async => provider;

  @override
  Future<AiRouteMode> routeMode() async => mode;

  @override
  Future<bool> hasNetwork() async => network;
}

/// 1 lần gọi chat của backend.
class _ChatCall {
  final String systemPrompt;
  final String userPrompt;
  final int maxTokens;
  final Duration timeout;
  const _ChatCall(this.systemPrompt, this.userPrompt, this.maxTokens,
      this.timeout);
}

/// Backend giả: hành vi scripted. Trả String = output; throw Exception
/// (AiApiException/TimeoutException/...) = lỗi backend.
class _ScriptedBackend implements LlmMtBackend {
  _ScriptedBackend(this.behavior);

  final FutureOr<Object> Function(_ChatCall call, int callIndex) behavior;
  final List<_ChatCall> calls = <_ChatCall>[];

  @override
  Future<String> chat({
    required AiProviderConfig provider,
    required String model,
    required String systemPrompt,
    required String userPrompt,
    required int maxTokens,
    required Duration timeout,
  }) async {
    final call = _ChatCall(systemPrompt, userPrompt, maxTokens, timeout);
    calls.add(call);
    final result = await behavior(call, calls.length - 1);
    if (result is String) return result;
    throw result;
  }
}

/// Engine ghi lại input (mẫu _RecordingEngine của translation_glossary_test).
class _RecordingEngine extends TranslationEngine {
  _RecordingEngine({this.transform});

  final String Function(String input)? transform;
  final List<String> inputs = <String>[];

  @override
  String get name => 'Fake Engine';

  @override
  String get id => 'fake';

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<TranslationResult> translate({
    required String text,
    required String targetLang,
    String sourceLang = 'auto',
  }) async {
    inputs.add(text);
    final out = transform?.call(text) ?? text;
    return TranslationResult.success(
      original: text,
      translated: out,
      engine: name,
      detectedLang: sourceLang,
      targetLang: targetLang,
    );
  }
}

class _FailingEngine extends TranslationEngine {
  @override
  String get name => 'Failing Engine';

  @override
  String get id => 'failing';

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<TranslationResult> translate({
    required String text,
    required String targetLang,
    String sourceLang = 'auto',
  }) async {
    return TranslationResult.failure(
      original: text,
      error: 'boom (giả lập lỗi engine)',
      engine: name,
    );
  }
}

GlossaryEntry _glossaryEntry(
  String source,
  String target, {
  String sourceLang = 'pi',
}) {
  return GlossaryEntry(
    id: GlossaryEntry.makeId(source, sourceLang, 'vi'),
    sourceNorm: source,
    sourceLang: sourceLang,
    targetLang: 'vi',
    targetText: target,
    locked: true,
    domain: GlossaryDomain.buddhist,
    priority: 0,
  );
}

LlmMtEngine _engineWith({
  AiProviderConfig? provider = _lanProvider,
  bool network = true,
  AiRouteMode mode = AiRouteMode.offlineFirst,
  required FutureOr<Object> Function(_ChatCall call, int callIndex) behavior,
  Duration chunkTimeout = const Duration(seconds: 60),
  Duration retryBackoff = Duration.zero,
  Duration queueWait = const Duration(seconds: 10),
}) {
  return LlmMtEngine.forTest(
    env: _FakeEnv(provider: provider, network: network, mode: mode),
    backend: _ScriptedBackend(behavior),
    chunkTimeout: chunkTimeout,
    retryBackoff: retryBackoff,
    queueWait: queueWait,
  );
}

// ─────────────────── 1. Client: parse chat completions ───────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // TranslationCache (của TranslationService) dùng SharedPreferences —
    // mock in-memory cho test + clear để các test không ăn cache của nhau.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await TranslationCache().clear();
  });

  group('OpenAiCompatClient.parseChatContent', () {
    test('content String chuẩn OpenAI', () {
      const body =
          '{"choices":[{"message":{"role":"assistant","content":"Xin chào"}}]}';
      expect(OpenAiCompatClient.parseChatContent(body), 'Xin chào');
    });

    test('content là List parts (lớp compat kiểu vision) — ghép text', () {
      const body =
          '{"choices":[{"message":{"role":"assistant","content":[{"type":"text","text":"A"},{"type":"text","text":"B"}]}}]}';
      expect(OpenAiCompatClient.parseChatContent(body), 'AB');
    });

    test('biến thể legacy choices[0].text', () {
      const body = '{"choices":[{"text":"Legacy output"}]}';
      expect(OpenAiCompatClient.parseChatContent(body), 'Legacy output');
    });

    test('không JSON / không choices / content rỗng → invalidResponse', () {
      expect(
        () => OpenAiCompatClient.parseChatContent('not json'),
        throwsA(isA<AiApiException>().having(
            (e) => e.code, 'code', AiApiErrorCode.invalidResponse)),
      );
      expect(
        () => OpenAiCompatClient.parseChatContent('{"choices":[]}'),
        throwsA(isA<AiApiException>()),
      );
      expect(
        () => OpenAiCompatClient.parseChatContent(
            '{"choices":[{"message":{"content":null}}]}'),
        throwsA(isA<AiApiException>()),
      );
    });
  });

  group('OpenAiCompatClient.chatCompletion (MockClient, không network)', () {
    test('200 → content; request đúng chuẩn OpenAI (model/messages/params)',
        () async {
      http.Request? captured;
      final client = OpenAiCompatClient(
        baseUrl: 'https://api.example.com/v1',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
              '{"choices":[{"message":{"role":"assistant","content":"Bản dịch"}}]}',
              200);
        }),
      );
      final content = await client.chatCompletion(
        model: 'mt-model',
        messages: const [
          OpenAiChatMessage('system', 'system prompt'),
          OpenAiChatMessage('user', 'user text'),
        ],
        temperature: 0.1,
        maxTokens: 128,
      );
      expect(content, 'Bản dịch');
      expect(captured!.url.toString(),
          'https://api.example.com/v1/chat/completions');
      expect(captured!.method, 'POST');
      final body =
          jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['model'], 'mt-model');
      expect(body['temperature'], 0.1);
      expect(body['max_tokens'], 128);
      final messages = body['messages'] as List<dynamic>;
      expect(messages, hasLength(2));
      expect((messages[0] as Map<String, dynamic>)['role'], 'system');
      expect((messages[1] as Map<String, dynamic>)['content'], 'user text');
    });

    test('provider LAN không key → KHÔNG có header Authorization', () async {
      http.Request? captured;
      final client = OpenAiCompatClient(
        baseUrl: 'http://192.168.1.10:11434/v1',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
              '{"choices":[{"message":{"content":"ok"}}]}', 200);
        }),
      );
      await client.chatCompletion(
        model: 'm',
        messages: const [OpenAiChatMessage('user', 'hi')],
      );
      expect(captured!.headers.containsKey('Authorization'), isFalse);
    });

    test('401 → unauthorized, 429 → rateLimited, 500 → httpError', () async {
      Future<AiApiException> run(int status) async {
        final client = OpenAiCompatClient(
          baseUrl: 'https://api.example.com/v1',
          httpClient: MockClient((request) async =>
              http.Response('{"error":"x"}', status)),
        );
        try {
          await client.chatCompletion(
              model: 'm', messages: const [OpenAiChatMessage('user', 'x')]);
          throw StateError('phải throw');
        } on AiApiException catch (e) {
          return e;
        }
      }

      expect((await run(401)).code, AiApiErrorCode.unauthorized);
      expect((await run(429)).code, AiApiErrorCode.rateLimited);
      final serverError = await run(500);
      expect(serverError.code, AiApiErrorCode.httpError);
      expect(serverError.statusCode, 500);
    });

    test('http:// host công cộng → cleartextBlocked (key không qua http)', () async {
      final client = OpenAiCompatClient(
        baseUrl: 'http://api.example.com/v1',
        httpClient: MockClient((request) async =>
            http.Response('{"choices":[{"message":{"content":"x"}}]}', 200)),
      );
      await expectLater(
        client.chatCompletion(
            model: 'm', messages: const [OpenAiChatMessage('user', 'x')]),
        throwsA(isA<AiApiException>().having(
            (e) => e.code, 'code', AiApiErrorCode.cleartextBlocked)),
      );
    });
  });

  // ─────────────────────── 2. Prompt (AT: nghiêm ngặt) ───────────────────────

  group('LlmMtPrompts — hợp đồng prompt', () {
    test('system prompt: CHỈ dịch, KHÔNG giải thích, giữ slot __G{n}__',
        () {
      final prompt = LlmMtPrompts.buildSystemPrompt(
          sourceLang: 'en', targetLang: 'vi');
      expect(prompt, contains('Output ONLY the translated text'));
      expect(prompt, contains('No explanation'));
      expect(prompt, contains('Vietnamese'));
      expect(prompt, contains('English'));
      // Slot: nêu rõ ví dụ + chữ-khỏi-chữ.
      expect(prompt, contains('__G1__'));
      expect(prompt, contains('EXACTLY'));
      expect(prompt, contains('Never translate, rename, reorder, split, or drop'));
      // Chuyên ngữ Phật học — mục tiêu chất lượng của WP3.
      expect(prompt, contains('Pali'));
    });

    test('user prompt = đúng text nguồn (chỉ dẫn tách riêng system)', () {
      const text = 'sati is the path\nsecond line';
      expect(LlmMtPrompts.buildUserPrompt(text), text);
    });

    test('languageDisplayName phủ catalog + fallback code gốc', () {
      expect(LlmMtPrompts.languageDisplayName('vi'), 'Vietnamese');
      expect(LlmMtPrompts.languageDisplayName('ZH-TW'),
          'Chinese (Traditional)');
      expect(LlmMtPrompts.languageDisplayName('si'), 'Sinhala');
      expect(LlmMtPrompts.languageDisplayName('xx'), 'XX');
    });

    test('slotsIn / lostSlot — kiểm tra slot giữ nguyên', () {
      expect(LlmMtPrompts.slotsIn('a __G0__ b __G1__ c __G0__'),
          ['__G0__', '__G1__']);
      expect(LlmMtPrompts.slotsIn('no slot here'), isEmpty);
      expect(LlmMtPrompts.lostSlot('__G0__ x', 'y __G0__ z'), isNull);
      // Hoa/thường khác vẫn coi là giữ (restore pass 2 gắn lại được).
      expect(LlmMtPrompts.lostSlot('__G0__ x', 'y __g0__ z'), isNull);
      expect(LlmMtPrompts.lostSlot('__G0__ x', 'y z'), '__G0__');
    });
  });

  group('LlmMtPrompts.cleanOutput — output KHÔNG chứa giải thích', () {
    test('bỏ fence code quanh bản dịch', () {
      expect(LlmMtPrompts.cleanOutput('```\nBản dịch\n```'), 'Bản dịch');
      expect(LlmMtPrompts.cleanOutput('```text\nBản dịch\n```'), 'Bản dịch');
    });

    test('bỏ lời dẫn phổ biến (kể cả 2 lớp "Sure, here is…")', () {
      expect(LlmMtPrompts.cleanOutput('Translation: Xin chào'), 'Xin chào');
      expect(LlmMtPrompts.cleanOutput('Bản dịch: Xin chào'), 'Xin chào');
      expect(LlmMtPrompts.cleanOutput(
          'Sure, here is the translation:\n\nXin chào'),
          'Xin chào');
    });

    test('model lặp lại nguồn rồi mới dịch → lấy phần dịch', () {
      const source = 'This is a fairly long source sentence for testing.';
      expect(
        LlmMtPrompts.cleanOutput('$source\nXin chào', sourceText: source),
        'Xin chào',
      );
    });

    test('bản dịch sạch giữ nguyên (không cắt oan)', () {
      const out = 'Chánh niệm là con đường duy nhất. Hãy thực hành.';
      expect(LlmMtPrompts.cleanOutput(out), out);
    });

    test('guard: nguồn bắt đầu "Translation:" → đó là nội dung, không strip',
        () {
      // Câu nguồn có chữ "Translation:" ở đầu — bản dịch giữ nguyên chữ đó.
      const source = 'Translation: the experiment failed.';
      expect(
        LlmMtPrompts.cleanOutput('Translation: the experiment failed.',
            sourceText: source),
        'Translation: the experiment failed.',
      );
    });

    test('guard: nguồn có fence code → fence là nội dung, không strip', () {
      const source = '```dart\ncode block\n```';
      expect(
        LlmMtPrompts.cleanOutput('```dart\nkhối code\n```',
            sourceText: source),
        '```dart\nkhối code\n```',
      );
    });
  });

  // ───────────────────────── 3. Engine thuần ─────────────────────────

  group('LlmMtEngine — điều kiện chạy + mã lỗi cấu trúc', () {
    test('interface: name/id/maxCharsPerRequest ~2000/requestDelay', () {
      final engine = _engineWith(behavior: (call, i) => 'x');
      expect(engine.name, 'LLM API');
      expect(engine.id, 'llm_mt');
      expect(engine.maxCharsPerRequest, 2000);
      expect(engine.requestDelay, const Duration(milliseconds: 300));
    });

    test('chưa cấu hình provider → no_provider (tầng tắt, fail nhanh)', () async {
      final backend = _ScriptedBackend((call, i) => 'không bao giờ gọi');
      final engine = LlmMtEngine.forTest(
        env: _FakeEnv(provider: null),
        backend: backend,
      );
      final result =
          await engine.translate(text: 'hello', targetLang: 'VI');
      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'no_provider');
      expect(backend.calls, isEmpty);
    });

    test('provider có nhưng mất mạng → no_network', () async {
      final backend = _ScriptedBackend((call, i) => 'không bao giờ gọi');
      final engine = LlmMtEngine.forTest(
        env: _FakeEnv(network: false),
        backend: backend,
      );
      final result =
          await engine.translate(text: 'hello', targetLang: 'VI');
      expect(result.errorCode, 'no_network');
      expect(backend.calls, isEmpty);
    });

    test('dịch thành công: đúng system/user prompt, maxTokens hợp lệ', () async {
      final backend = _ScriptedBackend((call, i) => 'Xin chào');
      final engine = LlmMtEngine.forTest(
        env: _FakeEnv(provider: _lanProvider),
        backend: backend,
      );
      final result = await engine.translate(
        text: 'hello',
        targetLang: 'VI',
        sourceLang: 'EN',
      );
      expect(result.isSuccess, isTrue);
      expect(result.translatedText, 'Xin chào');
      expect(result.engineName, 'LLM API');
      expect(backend.calls, hasLength(1));
      expect(backend.calls.single.systemPrompt,
          contains('Output ONLY the translated text'));
      expect(backend.calls.single.userPrompt, 'hello');
      expect(backend.calls.single.maxTokens, greaterThanOrEqualTo(1024));
    });

    test('output rỗng (chỉ khoảng trắng) → empty_output sau 1 retry', () async {
      final engine = _engineWith(
        behavior: (call, i) => '   ',
        retryBackoff: Duration.zero,
      );
      final result = await engine.translate(text: 'hello', targetLang: 'VI');
      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'empty_output');
    });

    test('429 lần 1 → backoff + retry; lần 2 thành công', () async {
      final engine = _engineWith(
        behavior: (call, i) => i == 0
            ? const AiApiException(AiApiErrorCode.rateLimited, '429',
                statusCode: 429)
            : 'Bản dịch sau retry',
        retryBackoff: Duration.zero,
      );
      final result = await engine.translate(text: 'hello', targetLang: 'VI');
      expect(result.isSuccess, isTrue);
      expect(result.translatedText, 'Bản dịch sau retry');
    });

    test('429 cả 2 lần → rate_limited (đủ mã cấu trúc)', () async {
      final engine = _engineWith(
        behavior: (call, i) => const AiApiException(
            AiApiErrorCode.rateLimited, '429',
            statusCode: 429),
        retryBackoff: Duration.zero,
      );
      final result = await engine.translate(text: 'hello', targetLang: 'VI');
      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'rate_limited');
    });

    test('401 → unauthorized, KHÔNG retry (đủ 1 lần gọi)', () async {
      var calls = 0;
      final engine = _engineWith(
        behavior: (call, i) {
          calls++;
          return const AiApiException(
              AiApiErrorCode.unauthorized, 'bad key',
              statusCode: 401);
        },
        retryBackoff: Duration.zero,
      );
      final result = await engine.translate(text: 'hello', targetLang: 'VI');
      expect(result.errorCode, 'unauthorized');
      expect(calls, 1);
    });

    test('5xx → http_error sau 1 retry; timeout → timeout không retry',
        () async {
      var calls = 0;
      final engine = _engineWith(
        behavior: (call, i) {
          calls++;
          return const AiApiException(
              AiApiErrorCode.httpError, 'server exploded',
              statusCode: 503);
        },
        retryBackoff: Duration.zero,
      );
      final result = await engine.translate(text: 'hello', targetLang: 'VI');
      expect(result.errorCode, 'http_error');
      expect(calls, 2);

      var timeoutCalls = 0;
      final timeoutEngine = _engineWith(
        behavior: (call, i) {
          timeoutCalls++;
          return const AiApiException(AiApiErrorCode.timeout, 'slow');
        },
        retryBackoff: Duration.zero,
      );
      final timeoutResult =
          await timeoutEngine.translate(text: 'hello', targetLang: 'VI');
      expect(timeoutResult.errorCode, 'timeout');
      expect(timeoutCalls, 1);
    });

    test('backend throw lạ → invalid_response', () async {
      final engine = _engineWith(
        behavior: (call, i) => StateError('bất ngờ'),
        retryBackoff: Duration.zero,
      );
      final result = await engine.translate(text: 'hello', targetLang: 'VI');
      expect(result.errorCode, 'invalid_response');
    });

    test('busy: 1 request/1 slot — request kế chờ hết hạn → busy', () async {
      final gate = Completer<void>();
      final engine = _engineWith(
        behavior: (call, i) async {
          await gate.future;
          return 'Bản dịch đầu';
        },
        queueWait: const Duration(milliseconds: 150),
      );
      final first = engine.translate(text: 'first', targetLang: 'VI');
      // Chờ request đầu giữ slot thật sự.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final second = await engine.translate(text: 'second', targetLang: 'VI');
      expect(second.isSuccess, isFalse);
      expect(second.errorCode, 'busy');
      gate.complete();
      final firstResult = await first;
      expect(firstResult.isSuccess, isTrue);
      expect(firstResult.translatedText, 'Bản dịch đầu');
    });
  });

  group('LlmMtEngine — giữ slot glossary __G{n}__ (hợp đồng service)', () {
    test('output giữ slot → success, slot nguyên vẹn', () async {
      final engine = _engineWith(
        behavior: (call, i) => 'thực hành __G0__ hằng ngày',
      );
      final result = await engine.translate(
        text: 'practice __G0__ daily',
        targetLang: 'VI',
      );
      expect(result.isSuccess, isTrue);
      expect(result.translatedText, contains('__G0__'));
    });

    test('slot viết thường (__g0__) vẫn coi là giữ (restore pass 2)', () async {
      final engine = _engineWith(
        behavior: (call, i) => 'thực hành __g0__ hằng ngày',
      );
      final result = await engine.translate(
        text: 'practice __G0__ daily',
        targetLang: 'VI',
      );
      expect(result.isSuccess, isTrue);
    });

    test('mất slot → retry 1 lần; vẫn mất → slot_lost (không fake success)',
        () async {
      var calls = 0;
      final engine = _engineWith(
        behavior: (call, i) {
          calls++;
          return 'thực hành chánh niệm hằng ngày'; // mất __G0__
        },
        retryBackoff: Duration.zero,
      );
      final result = await engine.translate(
        text: 'practice __G0__ daily',
        targetLang: 'VI',
      );
      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'slot_lost');
      expect(calls, 2);
    });

    test('mất slot lần 1, giữ lần 2 (retry) → success', () async {
      final engine = _engineWith(
        behavior: (call, i) =>
            i == 0 ? 'thực hành hằng ngày' : 'thực hành __G0__ hằng ngày',
        retryBackoff: Duration.zero,
      );
      final result = await engine.translate(
        text: 'practice __G0__ daily',
        targetLang: 'VI',
      );
      expect(result.isSuccess, isTrue);
      expect(result.translatedText, contains('__G0__'));
    });
  });

  group('LlmMtEngine — chunking ~2000 ký tự', () {
    test('text dài → nhiều chunk ≤2000, ghép đúng thứ tự', () async {
      // 6 câu ~800 ký tự = ~4800 ký tự → ≥3 chunk.
      final sentence = 'A' * 790 + '. ';
      final text = sentence * 6;
      final backend = _ScriptedBackend((call, i) => 'chunk-$i');
      final engine = LlmMtEngine.forTest(
        env: _FakeEnv(provider: _lanProvider),
        backend: backend,
      );
      final result = await engine.translate(
        text: text,
        targetLang: 'VI',
      );
      expect(result.isSuccess, isTrue);
      expect(backend.calls.length, greaterThan(1));
      for (final call in backend.calls) {
        expect(call.userPrompt.length, lessThanOrEqualTo(2000));
      }
      expect(result.translatedText, contains('chunk-0'));
      expect(result.translatedText, contains('chunk-1'));
      // Thứ tự: chunk-0 đứng trước chunk-1.
      expect(result.translatedText.indexOf('chunk-0'),
          lessThan(result.translatedText.indexOf('chunk-1')));
    });

    test('mọi chunk gửi xuống đều có system prompt nghiêm ngặt', () async {
      final sentence = 'B' * 790 + '. ';
      final text = sentence * 5;
      final backend = _ScriptedBackend((call, i) => 'x');
      final engine = LlmMtEngine.forTest(
        env: _FakeEnv(provider: _lanProvider),
        backend: backend,
      );
      await engine.translate(text: text, targetLang: 'VI');
      expect(backend.calls.length, greaterThan(1));
      for (final call in backend.calls) {
        expect(call.systemPrompt, contains('Output ONLY the translated text'));
        expect(call.maxTokens, greaterThanOrEqualTo(1024));
      }
    });
  });

  // ──────────────── 4. TranslationService: chèn theo routing ────────────────

  group('TranslationService — chuỗi engine theo routing (WP3)', () {
    test('onlineFirst: LLM thành công → engine free KHÔNG được gọi', () async {
      final free = _RecordingEngine();
      final backend = _ScriptedBackend((call, i) => 'bản dịch LLM');
      final llm = LlmMtEngine.forTest(
        env: _FakeEnv(provider: _lanProvider, mode: AiRouteMode.onlineFirst),
        backend: backend,
      );
      final service = TranslationService.forTest(
        onlineEngines: <TranslationEngine>[free],
        llmMtEngine: llm,
        networkAvailable: true,
      );
      final result = await service.translateText(
        'the dhamma is good',
        sourceLang: 'en',
        targetLang: 'vi',
      );
      expect(result.isSuccess, isTrue);
      expect(result.engineName, 'LLM API');
      expect(free.inputs, isEmpty);
      expect(backend.calls, hasLength(1));
    });

    test('onlineFirst: LLM fail → fallback nguyên vẹn sang engine free',
        () async {
      final free = _RecordingEngine();
      final llm = LlmMtEngine.forTest(
        env: _FakeEnv(provider: null, mode: AiRouteMode.onlineFirst),
        backend: _ScriptedBackend((call, i) => 'không gọi'),
      );
      final service = TranslationService.forTest(
        onlineEngines: <TranslationEngine>[free],
        llmMtEngine: llm,
        networkAvailable: true,
      );
      final result = await service.translateText(
        'the dhamma is good',
        sourceLang: 'en',
        targetLang: 'vi',
      );
      expect(result.isSuccess, isTrue);
      expect(result.engineName, 'Fake Engine');
      expect(free.inputs, hasLength(1));
    });

    test('offlineFirst (mặc định): engine free thành công → LLM KHÔNG gọi',
        () async {
      final free = _RecordingEngine();
      final backend = _ScriptedBackend((call, i) => 'bản dịch LLM');
      final llm = LlmMtEngine.forTest(
        env: _FakeEnv(
            provider: _lanProvider, mode: AiRouteMode.offlineFirst),
        backend: backend,
      );
      final service = TranslationService.forTest(
        onlineEngines: <TranslationEngine>[free],
        llmMtEngine: llm,
        networkAvailable: true,
      );
      final result = await service.translateText(
        'the dhamma is good',
        sourceLang: 'en',
        targetLang: 'vi',
      );
      expect(result.engineName, 'Fake Engine');
      expect(backend.calls, isEmpty);
    });

    test('offlineFirst: free + ML Kit fail → LLM chạy TRƯỚC từ điển', () async {
      final free = _FailingEngine();
      final mlkit = _FailingEngine();
      final dict = _RecordingEngine();
      final backend = _ScriptedBackend((call, i) => 'bản dịch LLM');
      final llm = LlmMtEngine.forTest(
        env: _FakeEnv(
            provider: _lanProvider, mode: AiRouteMode.offlineFirst),
        backend: backend,
      );
      final service = TranslationService.forTest(
        onlineEngines: <TranslationEngine>[free],
        offlineEngine: dict,
        mlkitEngine: mlkit,
        llmMtEngine: llm,
        networkAvailable: true,
      );
      final result = await service.translateText(
        'the dhamma is good',
        sourceLang: 'en',
        targetLang: 'vi',
      );
      expect(result.isSuccess, isTrue);
      expect(result.engineName, 'LLM API');
      expect(dict.inputs, isEmpty, reason: 'LLM phải đón trước từ điển');
    });

    test(
        'TẮT MẠNG (AT): chuỗi fallback nguyên vẹn — LLM không gọi dù onlineFirst',
        () async {
      final free = _FailingEngine();
      final mlkit = _FailingEngine();
      final dict = _RecordingEngine();
      final backend = _ScriptedBackend((call, i) => 'bản dịch LLM');
      final llm = LlmMtEngine.forTest(
        env: _FakeEnv(
            provider: _lanProvider, mode: AiRouteMode.onlineFirst),
        backend: backend,
      );
      final service = TranslationService.forTest(
        onlineEngines: <TranslationEngine>[free],
        offlineEngine: dict,
        mlkitEngine: mlkit,
        llmMtEngine: llm,
        networkAvailable: false,
      );
      final result = await service.translateText(
        'the dhamma is good',
        sourceLang: 'en',
        targetLang: 'vi',
      );
      // Hết mạng: online (free + LLM) bị bỏ qua → offline: từ điển đón.
      expect(result.engineName, 'Fake Engine');
      expect(backend.calls, isEmpty);
    });

    test('khóa "Chỉ offline": LLM bị bỏ qua như mọi engine online', () async {
      final dict = _RecordingEngine();
      final backend = _ScriptedBackend((call, i) => 'bản dịch LLM');
      final llm = LlmMtEngine.forTest(
        env: _FakeEnv(
            provider: _lanProvider, mode: AiRouteMode.onlineFirst),
        backend: backend,
      );
      final service = TranslationService.forTest(
        onlineEngines: const <TranslationEngine>[],
        offlineEngine: dict,
        llmMtEngine: llm,
        networkAvailable: true,
      )..offlineOnly = true;
      final result = await service.translateText(
        'the dhamma is good',
        sourceLang: 'en',
        targetLang: 'vi',
      );
      expect(result.engineName, 'Fake Engine');
      expect(backend.calls, isEmpty);
    });

    test('forTest KHÔNG inject LLM → chuỗi như trước WP3 (không regression)',
        () async {
      final free = _RecordingEngine();
      final service = TranslationService.forTest(
        onlineEngines: <TranslationEngine>[free],
        networkAvailable: true,
      );
      final result = await service.translateText(
        'the dhamma is good',
        sourceLang: 'en',
        targetLang: 'vi',
      );
      expect(result.isSuccess, isTrue);
      expect(result.engineName, 'Fake Engine');
    });

    test('glossary → LLM giữ slot → restore nghĩa khóa (AT pipeline đầy đủ)',
        () async {
      final glossary =
          Glossary(<GlossaryEntry>[_glossaryEntry('dhamma', 'Pháp')]);
      // Model dịch 'the __G0__ is good' → '__G0__ là tốt' (giữ slot).
      final backend = _ScriptedBackend((call, i) => '__G0__ là tốt');
      final llm = LlmMtEngine.forTest(
        env: _FakeEnv(provider: _lanProvider, mode: AiRouteMode.onlineFirst),
        backend: backend,
      );
      final service = TranslationService.forTest(
        onlineEngines: const <TranslationEngine>[],
        llmMtEngine: llm,
        glossary: glossary,
        networkAvailable: true,
      );
      final result = await service.translateText(
        'the dhamma is good',
        sourceLang: 'en',
        targetLang: 'vi',
      );
      expect(result.isSuccess, isTrue);
      // Engine nhận slot, KHÔNG nhận từ gốc.
      expect(backend.calls.single.userPrompt, contains('__G0__'));
      expect(
          backend.calls.single.userPrompt, isNot(contains('dhamma')));
      // Output restore nghĩa khóa.
      expect(result.translatedText, 'Pháp là tốt');
    });
  });
}
