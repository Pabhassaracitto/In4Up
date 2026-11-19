// PSRC-209 — "tinh chỉnh bằng AI" sau OCR phải báo ĐÚNG cấu hình còn thiếu
// và GIỮ NGUYÊN số khối (map 1-1) của văn bản OCR.
//
// Toàn bộ test ở đây THUẦN logic: env (provider/mạng/routing) và backend
// (chat completion) đều được tiêm ⇒ không SharedPreferences, không
// connectivity_plus, không mạng — chạy được trên CI.
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/app_ui_translations.dart';
import 'package:in4up/features/ocr/ocr_ai_refine_service.dart';
import 'package:in4up_ai/in4up_ai.dart';

AiProviderConfig _provider({
  String id = 'or',
  String label = 'OpenRouter',
  String baseUrl = 'https://openrouter.ai/api/v1',
  String? apiKey = 'sk-test',
  String? chatModel = 'openrouter/free',
  String? translationModel,
  bool enabled = true,
}) {
  return AiProviderConfig(
    id: id,
    label: label,
    baseUrl: baseUrl,
    apiKey: apiKey,
    chatModel: chatModel,
    translationModel: translationModel,
    enabled: enabled,
  );
}

OcrAiRefineSetup _setup({
  List<AiProviderConfig>? providers,
  AiProviderConfig? provider,
  AiRouteCapability capability = AiRouteCapability.chat,
  AiRouteMode mode = AiRouteMode.auto,
  bool hasNetwork = true,
  String? model,
}) {
  final list = providers ?? <AiProviderConfig>[provider ?? _provider()];
  final chosen = provider ?? (list.isEmpty ? null : list.first);
  return OcrAiRefineSetup(
    providers: list,
    capability: capability,
    configuredMode: mode,
    hasNetwork: hasNetwork,
    provider: chosen,
    model: model ?? chosen?.modelFor(capability),
  );
}

class _FakeEnv implements OcrAiRefineEnv {
  final OcrAiRefineSetup setup;
  int loads = 0;

  _FakeEnv(this.setup);

  @override
  Future<OcrAiRefineSetup> load() async {
    loads++;
    return setup;
  }
}

class _FakeBackend implements OcrAiRefineBackend {
  final Future<String> Function(
    String userPrompt,
    String? reminder,
    int maxTokens,
  ) handler;

  final List<String> prompts = [];
  final List<String?> reminders = [];
  final List<int> maxTokensUsed = [];

  _FakeBackend(this.handler);

  int get calls => prompts.length;

  @override
  Future<String> chat({
    required AiProviderConfig provider,
    required String model,
    required String systemPrompt,
    required String userPrompt,
    String? reminder,
    required int maxTokens,
    required Duration timeout,
  }) {
    prompts.add(userPrompt);
    reminders.add(reminder);
    maxTokensUsed.add(maxTokens);
    return handler(userPrompt, reminder, maxTokens);
  }
}

void main() {
  group('OCR AI refinement availability', () {
    test('offers refinement only when the editable OCR text has content', () {
      expect(OcrAiRefinePolicy.shouldOffer('  '), isFalse);
      expect(OcrAiRefinePolicy.shouldOffer('\n\t'), isFalse);
      expect(OcrAiRefinePolicy.shouldOffer('Recognized words'), isTrue);
    });
  });

  group('PSRC-209 — chẩn đoán nêu ĐÚNG cấu hình còn thiếu', () {
    test('chưa thêm provider nào / provider đang tắt ⇒ noProvider', () {
      expect(
        OcrAiRefinePolicy.missingPrerequisite(_setup(providers: const [])),
        OcrAiRefineError.noProvider,
      );
      final disabled = _provider(enabled: false);
      expect(
        OcrAiRefinePolicy.missingPrerequisite(
          _setup(providers: [disabled], provider: disabled),
        ),
        OcrAiRefineError.noProvider,
      );
    });

    test('provider bật nhưng chưa chọn model ⇒ noModel', () {
      final noModel = _provider(chatModel: null);
      expect(
        OcrAiRefinePolicy.missingPrerequisite(
          _setup(providers: [noModel], provider: noModel),
        ),
        OcrAiRefineError.noModel,
      );
    });

    test('routing "Chỉ offline" ⇒ offlineOnly (không phải "chưa cấu hình")',
        () {
      expect(
        OcrAiRefinePolicy.missingPrerequisite(
          _setup(mode: AiRouteMode.offlineOnly),
        ),
        OcrAiRefineError.offlineOnly,
      );
    });

    test('mất mạng ⇒ noNetwork (không phải "chưa cấu hình")', () {
      expect(
        OcrAiRefinePolicy.missingPrerequisite(_setup(hasNetwork: false)),
        OcrAiRefineError.noNetwork,
      );
    });

    test('provider cloud thiếu API key ⇒ missingApiKey; server LAN thì không',
        () {
      final cloud = _provider(apiKey: null);
      expect(
        OcrAiRefinePolicy.missingPrerequisite(
          _setup(providers: [cloud], provider: cloud),
        ),
        OcrAiRefineError.missingApiKey,
      );
      final lan = _provider(
        id: 'lan',
        label: 'llama.cpp',
        baseUrl: 'http://192.168.1.8:8080/v1',
        apiKey: null,
      );
      expect(
        OcrAiRefinePolicy.missingPrerequisite(
          _setup(providers: [lan], provider: lan),
        ),
        isNull,
      );
    });

    test('cấu hình đầy đủ ⇒ không thiếu gì', () {
      expect(OcrAiRefinePolicy.missingPrerequisite(_setup()), isNull);
    });

    test('requiresApiKey phân biệt cloud với LAN/localhost', () {
      expect(OcrAiRefinePolicy.requiresApiKey(_provider()), isTrue);
      expect(
        OcrAiRefinePolicy.requiresApiKey(
          _provider(baseUrl: 'http://localhost:11434/v1'),
        ),
        isFalse,
      );
      expect(
        OcrAiRefinePolicy.requiresApiKey(
          _provider(baseUrl: 'http://192.168.0.20:8080'),
        ),
        isFalse,
      );
      expect(
        OcrAiRefinePolicy.requiresApiKey(
          _provider(baseUrl: 'http://deskpc:8080/v1'),
        ),
        isFalse,
      );
      expect(
        OcrAiRefinePolicy.requiresApiKey(
          _provider(baseUrl: 'https://box.lan/v1'),
        ),
        isFalse,
      );
    });

    test('provider chỉ có model DỊCH vẫn dùng được (map 1-1 không đổi)', () {
      final translationOnly = _provider(
        chatModel: null,
        translationModel: 'gemini-2.0-flash',
      );
      final setup = _setup(
        providers: [translationOnly],
        provider: translationOnly,
        capability: AiRouteCapability.translation,
      );
      expect(setup.model, 'gemini-2.0-flash');
      expect(OcrAiRefinePolicy.missingPrerequisite(setup), isNull);
    });
  });

  group('PSRC-209 — chia lô và ghép lại giữ đúng số khối', () {
    test('số khối = số dòng có chữ; dòng trống giữ nguyên', () {
      const text = 'Dòng một\n\nDòng hai\nDòng ba';
      expect(OcrAiRefineBlocks.countBlocks(text), 3);

      final plan = OcrAiRefineBlocks.plan(text);
      expect(plan.chunks.length, 1);
      expect(plan.partsPerLine.length, 3);

      // Không có kết quả nào ⇒ trả nguyên văn (kể cả dòng trống).
      expect(OcrAiRefineBlocks.assemble(plan, const {}), text);

      // Chỉ sửa 1 dòng ⇒ các dòng khác + dòng trống giữ nguyên vị trí.
      expect(
        OcrAiRefineBlocks.assemble(plan, {
          0: {0: 'Dòng một (đã sửa)'},
        }),
        'Dòng một (đã sửa)\n\nDòng hai\nDòng ba',
      );
    });

    test('mỗi lô ≤ 1200 ký tự và phủ đủ mọi dòng có chữ', () {
      final lines = List.generate(40, (i) => 'Dòng số $i ' * 4);
      final text = lines.join('\n');
      final plan = OcrAiRefineBlocks.plan(text);

      expect(plan.chunks.length, greaterThan(1));
      for (final chunk in plan.chunks) {
        expect(chunk.prompt.length, lessThanOrEqualTo(1200));
      }
      final covered = <int>{};
      for (final chunk in plan.chunks) {
        for (final segment in chunk.segments) {
          covered.add(segment.line);
        }
      }
      expect(covered.length, lines.length);
    });

    test('dòng quá dài bị cắt thành phần và ghép lại ĐÚNG khoảng trắng', () {
      final longLine = List.filled(400, 'abcd').join(' ');
      expect(longLine.length, greaterThan(1600));

      final plan = OcrAiRefineBlocks.plan(longLine);
      expect(plan.partsPerLine[0], 2);
      expect(plan.gluesPerLine[0], [' ']);

      expect(
        OcrAiRefineBlocks.assemble(plan, {
          0: {0: 'phần đầu', 1: 'phần sau'},
        }),
        'phần đầu phần sau',
      );
    });

    test('max_tokens tính theo lô, trần 4096 — không bao giờ 8192', () {
      expect(OcrAiRefineBlocks.maxTokensFor(0), 512);
      expect(OcrAiRefineBlocks.maxTokensFor(1200), 1456);
      expect(OcrAiRefineBlocks.maxTokensFor(8000), 4096);
    });

    test('bóc <think>, code fence và số thứ tự model tự thêm', () {
      expect(
        OcrAiRefineBlocks.outputLines(
          '<think>đang nghĩ</think>Dòng thật',
        ),
        ['Dòng thật'],
      );
      expect(
        OcrAiRefineBlocks.outputLines('```text\nDòng một\nDòng hai\n```'),
        ['Dòng một', 'Dòng hai'],
      );
      expect(
        OcrAiRefineBlocks.outputLines('1. Dòng một\n2. Dòng hai'),
        ['Dòng một', 'Dòng hai'],
      );
      // Một dòng duy nhất bắt đầu bằng số là NỘI DUNG, không phải đánh số.
      expect(
        OcrAiRefineBlocks.outputLines('1. Bhikkhu'),
        ['1. Bhikkhu'],
      );
    });
  });

  group('PSRC-209 — gọi provider thật (backend giả)', () {
    test('giữ nguyên số khối khi model trả đúng cấu trúc', () async {
      final backend = _FakeBackend(
        (prompt, reminder, maxTokens) async => prompt.toUpperCase(),
      );
      final service = OcrAiRefineService.forTest(
        env: _FakeEnv(_setup()),
        backend: backend,
      );

      const input = 'Dòng một\n\nDòng hai';
      final out = await service.refine(input);

      expect(out, 'DÒNG MỘT\n\nDÒNG HAI');
      expect(
        OcrAiRefineBlocks.countBlocks(out),
        OcrAiRefineBlocks.countBlocks(input),
      );
      expect(backend.calls, 1);
      expect(backend.maxTokensUsed.single, lessThanOrEqualTo(4096));
    });

    test('model gộp dòng ⇒ nhắc định dạng rồi sửa từng dòng (1-1)', () async {
      final backend = _FakeBackend((prompt, reminder, maxTokens) async {
        if (prompt.contains('\n')) return 'gộp hết thành một dòng';
        return prompt.toUpperCase();
      });
      final service = OcrAiRefineService.forTest(
        env: _FakeEnv(_setup()),
        backend: backend,
      );

      final out = await service.refine('alpha\nbeta');

      expect(out, 'ALPHA\nBETA');
      expect(OcrAiRefineBlocks.countBlocks(out), 2);
      // 1 lần đầu + 1 lần nhắc định dạng + 2 lần sửa từng dòng.
      expect(backend.calls, 4);
      expect(backend.reminders[1], isNotNull);
    });

    test('429 ⇒ backoff rồi thử lại MỘT lần là xong', () async {
      var attempt = 0;
      final backend = _FakeBackend((prompt, reminder, maxTokens) async {
        attempt++;
        if (attempt == 1) {
          throw const AiApiException(
            AiApiErrorCode.rateLimited,
            'Rate limited (HTTP 429)',
            statusCode: 429,
          );
        }
        return prompt;
      });
      final service = OcrAiRefineService.forTest(
        env: _FakeEnv(_setup()),
        backend: backend,
      );

      expect(await service.refine('giữ nguyên'), 'giữ nguyên');
      expect(backend.calls, 2);
    });

    test('401 ⇒ ném mã unauthorized (dialog chỉ đúng API key)', () async {
      final backend = _FakeBackend(
        (prompt, reminder, maxTokens) async => throw const AiApiException(
          AiApiErrorCode.unauthorized,
          'Unauthorized (HTTP 401)',
          statusCode: 401,
        ),
      );
      final service = OcrAiRefineService.forTest(
        env: _FakeEnv(_setup()),
        backend: backend,
      );

      await expectLater(
        service.refine('abc'),
        throwsA(
          isA<OcrAiRefineException>().having(
            (e) => e.code,
            'code',
            OcrAiRefineError.unauthorized,
          ),
        ),
      );
      expect(backend.calls, 1);
    });

    test('thiếu cấu hình ⇒ ném đúng mã và KHÔNG gọi provider', () async {
      final backend = _FakeBackend(
        (prompt, reminder, maxTokens) async => prompt,
      );
      final noProvider = OcrAiRefineService.forTest(
        env: _FakeEnv(_setup(providers: const [])),
        backend: backend,
      );
      await expectLater(
        noProvider.refine('abc'),
        throwsA(
          isA<OcrAiRefineException>().having(
            (e) => e.code,
            'code',
            OcrAiRefineError.noProvider,
          ),
        ),
      );

      final noNetwork = OcrAiRefineService.forTest(
        env: _FakeEnv(_setup(hasNetwork: false)),
        backend: backend,
      );
      await expectLater(
        noNetwork.refine('abc'),
        throwsA(
          isA<OcrAiRefineException>().having(
            (e) => e.code,
            'code',
            OcrAiRefineError.noNetwork,
          ),
        ),
      );
      expect(backend.calls, 0);
    });

    test('văn bản quá dài ⇒ tooLong thay vì gửi hàng loạt request', () async {
      final backend = _FakeBackend(
        (prompt, reminder, maxTokens) async => prompt,
      );
      final service = OcrAiRefineService.forTest(
        env: _FakeEnv(_setup()),
        backend: backend,
        maxChunks: 1,
        maxChunkChars: 20,
      );
      await expectLater(
        service.refine('dòng thứ nhất rất dài\n\ndòng thứ hai rất dài'),
        throwsA(
          isA<OcrAiRefineException>().having(
            (e) => e.code,
            'code',
            OcrAiRefineError.tooLong,
          ),
        ),
      );
      expect(backend.calls, 0);
    });

    test('model trả rỗng cho mọi lô ⇒ emptyOutput (không im lặng)', () async {
      final backend = _FakeBackend(
        (prompt, reminder, maxTokens) async => '',
      );
      final service = OcrAiRefineService.forTest(
        env: _FakeEnv(_setup()),
        backend: backend,
      );
      await expectLater(
        service.refine('abc'),
        throwsA(
          isA<OcrAiRefineException>().having(
            (e) => e.code,
            'code',
            OcrAiRefineError.emptyOutput,
          ),
        ),
      );
    });
  });

  test('OCR AI action and feedback are translated in all priority locales', () {
    const messages = [
      'Tinh chỉnh bằng AI',
      'Đang tinh chỉnh...',
      'Không thể tinh chỉnh lúc này. Kiểm tra cấu hình AI và kết nối rồi thử lại.',
      'Xem bản AI',
      'Xem bản trước AI',
      // PSRC-209: mỗi mã thiếu cấu hình có câu hướng dẫn riêng.
      'Chưa bật nhà cung cấp AI nào. Mở Cài đặt → Quản lý Model AI → Server & API để thêm và bật một nhà cung cấp.',
      'Nhà cung cấp AI đang bật nhưng chưa chọn model. Mở Cài đặt → Quản lý Model AI → Server & API để chọn model.',
      'Định tuyến AI Chat đang đặt “Chỉ offline”. Đổi sang “Ưu tiên online” trong Cài đặt → Quản lý Model AI → Server & API.',
      'Không có kết nối mạng. Kết nối Wi-Fi hoặc dữ liệu di động rồi thử lại.',
      'Nhà cung cấp AI chưa có API key. Nhập API key trong Cài đặt → Quản lý Model AI → Server & API.',
      'API key của nhà cung cấp AI không hợp lệ hoặc đã hết hạn. Kiểm tra lại trong Cài đặt → Quản lý Model AI → Server & API.',
      'Nhà cung cấp AI đang giới hạn truy vấn. Chờ một lát rồi thử lại.',
      'Hết thời gian chờ nhà cung cấp AI. Kiểm tra kết nối rồi thử lại.',
      'Văn bản quá dài để tinh chỉnh một lần. Chọn ít dòng hơn rồi thử lại.',
      'AI không trả về nội dung nào. Thử lại hoặc chọn model khác trong Cài đặt → Quản lý Model AI → Server & API.',
    ];
    const locales = ['en', 'hi', 'zh', 'zh_TW', 'si', 'my', 'th', 'ja'];

    for (final message in messages) {
      for (final locale in locales) {
        expect(
          AppUITranslations.translate(message, locale),
          isNot(message),
          reason: '$message has no translation for $locale',
        );
      }
    }
  });
}
