// AI-CHAT-01 (lane B3) — regression tests cho runtime chat local (GGUF).
//
// Bốn nhóm DoD được máy bắt ở đây:
//   1. Model đã nạp: gửi tin KHÔNG làm engine/màn hình rơi về "chưa nạp"
//      (state=processing vẫn được coi là ready).
//   2. Hai tin liên tiếp được XẾP HÀNG và trả lời đủ — không có "engine not
//      ready" giả, không nuốt tin thứ hai.
//   3. Request có timeout HỮU HẠN; hết hạn ⇒ lỗi rõ + retry được, và engine
//      được dựng lại để tin sau chạy được (không xoay vòng vô hạn).
//   4. Context chat bị GIỚI HẠN (tin mới nhất + ngân sách ký tự) và maxTokens
//      được tính theo chỗ trống của context 2048 token.
//   5. Isolate chết (OOM killer thu hồi) ⇒ request đang chờ có kết cục lỗi,
//      recover() đưa backend về ready để request sau hoạt động.
//
// Chạy: flutter test test/ai_chat/chat_runtime_stability_test.dart

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_ai/in4up_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Engine giả: giữ request ở `processing` cho tới khi test mở "cổng" — mô
/// phỏng native generate chậm (30s–2 phút) trên máy yếu. `dead = true` mô
/// phỏng isolate đã bị hệ thống thu hồi (state=error, không phản hồi).
class _GatedEngine implements AiEngine {
  final List<String> prompts = <String>[];
  final List<String> contexts = <String>[];
  final List<int> maxTokensSeen = <int>[];
  final List<String> recoveries = <String>[];
  final List<Completer<void>> gates = <Completer<void>>[];

  /// true ⇒ trả lời ngay, không cần mở cổng.
  bool autoAnswer = false;

  /// true ⇒ backend coi như đã chết (OOM thu hồi) cho tới khi recover().
  bool dead = false;

  int _pending = 0;
  AiEngineState _state = AiEngineState.ready;

  @override
  AiEngineState get state => dead ? AiEngineState.error : _state;

  @override
  bool get isBusy => !dead && _pending > 0;

  @override
  Future<void> get modelReady => Future<void>.value();

  @override
  Future<bool> initialize({required String modelPath}) async => true;

  @override
  Future<bool> recover({String? reason}) async {
    recoveries.add(reason ?? '');
    // Giống kill isolate: các request treo được "giải phóng".
    for (final gate in gates) {
      if (!gate.isCompleted) gate.complete();
    }
    _pending = 0;
    dead = false;
    _state = AiEngineState.ready;
    return true;
  }

  @override
  Stream<AiAnalysis> analyze({
    required String text,
    required AiAnalysisType type,
    String? context,
    double temperature = 0.1,
    int maxTokens = 256,
  }) async* {
    if (dead) {
      yield AiAnalysis.fallback(
        text,
        errorReason: 'AI process bị hệ thống thu hồi (thiếu bộ nhớ) — thử lại.',
        analysisType: type,
      );
      return;
    }
    prompts.add(text);
    contexts.add(context ?? '');
    maxTokensSeen.add(maxTokens);
    _pending++;
    _state = AiEngineState.processing;
    if (!autoAnswer) {
      final gate = Completer<void>();
      gates.add(gate);
      await gate.future;
    }
    _pending--;
    if (_pending <= 0) _state = AiEngineState.ready;
    yield AiAnalysis(
      inputText: text,
      summary: 'trả lời cho "$text"',
      topics: const <String>[],
      terms: const <AiTerm>[],
      success: true,
      language: 'vi',
      analysisType: type,
      generatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> warmUp() async {}

  @override
  Future<void> dispose() async {}
}

final _loader = AiModelLoader();

void _useModelFile(String? path) => _loader.debugSetCachedModelPath(path);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatContextPolicy — context có giới hạn', () {
    test('chỉ lấy các tin MỚI NHẤT trong ngân sách ký tự', () {
      const policy = ChatContextPolicy(
        maxHistoryMessages: 4,
        maxHistoryChars: 100,
        maxMessageChars: 40,
      );
      final messages = <ChatMessage>[
        for (var i = 0; i < 10; i++)
          ChatMessage(id: 'm$i', role: ChatRole.user, text: 'x' * 50),
      ];

      final selected = policy.selectHistory(messages);
      expect(selected.length, 1,
          reason: 'ngân sách 100 ký tự ⇒ chỉ 1 dòng "USER: " + 50 ký tự');
      expect(identical(selected.first, messages.last), isTrue,
          reason: 'phải là tin MỚI NHẤT, không phải tin cũ nhất');

      final built = policy.build(messages);
      expect(built, startsWith('USER: xxx'));
      expect(built.length, lessThanOrEqualTo(100),
          reason: 'build() phải cắt theo maxMessageChars/ngân sách');
    });

    test('lấy đủ số tin gần nhất khi còn ngân sách', () {
      const policy = ChatContextPolicy(
        maxHistoryMessages: 3,
        maxHistoryChars: 1000,
        maxMessageChars: 600,
      );
      final messages = <ChatMessage>[
        for (var i = 0; i < 6; i++)
          ChatMessage(
            id: 'm$i',
            role: i.isEven ? ChatRole.user : ChatRole.assistant,
            text: 'tin $i',
          ),
      ];
      final selected = policy.selectHistory(messages);
      expect(selected.map((m) => m.text).toList(), <String>[
        'tin 3',
        'tin 4',
        'tin 5',
      ]);
    });

    test('bỏ bubble lỗi + tin đang hỏi khỏi context', () {
      const policy = ChatContextPolicy.defaults;
      final current =
          ChatMessage(id: 'u2', role: ChatRole.user, text: 'câu hỏi mới');
      final messages = <ChatMessage>[
        ChatMessage(id: 'u1', role: ChatRole.user, text: 'câu cũ'),
        ChatMessage(
          id: 'e1',
          role: ChatRole.assistant,
          text: 'AI xử lý quá lâu (model lớn trên máy yếu).',
          isError: true,
        ),
        current,
      ];
      final built = policy.build(messages, current: current);
      expect(built, contains('câu cũ'));
      expect(built, isNot(contains('quá lâu')));
      expect(built, isNot(contains('câu hỏi mới')),
          reason: 'câu đang hỏi được gửi riêng ở trường text của prompt');
    });

    test('câu hỏi quá dài bị cắt trước khi vào prompt', () {
      const policy = ChatContextPolicy.defaults;
      expect(policy.clipQuestion('ngắn gọn'), 'ngắn gọn');
      final clipped = policy.clipQuestion('z' * 5000);
      expect(clipped.length, policy.maxQuestionChars + 1,
          reason: 'giữ phần đầu + dấu "…", không nhét cả 5000 ký tự vào n_ctx');
      // Worst-case ngân sách phải nằm trong context native 2048 token — kể cả
      // khi tiếng Việt tokenize tệ hơn ước lượng (~2 ký tự/token).
      final worstCaseChars = policy.maxHistoryChars +
          policy.maxQuestionChars +
          260; // prompt schema (SYSTEM/TYPE/OUTPUT SCHEMA)
      const pessimisticCharsPerToken = 2;
      final worstCaseTokens = (worstCaseChars / pessimisticCharsPerToken).ceil();
      expect(worstCaseTokens + policy.reservedTokens + policy.minMaxTokens,
          lessThan(policy.contextTokens),
          reason: 'prompt + chừa chỗ + sàn câu trả lời < n_ctx 2048');
      final worstCaseMaxTokens =
          policy.resolveMaxTokens(promptChars: worstCaseChars);
      expect(worstCaseMaxTokens, greaterThanOrEqualTo(policy.minMaxTokens));
      expect(
          policy.estimateTokens(worstCaseChars) +
              policy.reservedTokens +
              worstCaseMaxTokens,
          lessThanOrEqualTo(policy.contextTokens),
          reason: 'với ước lượng của policy, prompt + chừa chỗ + maxTokens '
              'phải nằm trong n_ctx');
    });

    test('maxTokens co theo chỗ trống của context 2048 token', () {
      const policy = ChatContextPolicy.defaults;
      expect(policy.resolveMaxTokens(promptChars: 0, requested: 512), 512);
      expect(policy.resolveMaxTokens(promptChars: 0, requested: 4096), 512,
          reason: 'không vượt trần chat');
      expect(policy.resolveMaxTokens(promptChars: 100000), policy.minMaxTokens,
          reason: 'prompt khổng lồ ⇒ trả về sàn, không tràn context native');
      final mid = policy.resolveMaxTokens(promptChars: 3000, requested: 512);
      expect(mid, inInclusiveRange(policy.minMaxTokens, 512));
    });
  });

  group('AiServiceFacade — queue + banner + timeout', () {
    late _GatedEngine engine;
    late AiServiceFacade facade;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      facade = AiServiceFacade();
      engine = _GatedEngine();
      _useModelFile('/tmp/in4up-test/gemma-test.gguf');
      facade.debugAttachEngine(engine, modelLoaded: true);
    });

    tearDown(() {
      facade.dispose();
      _useModelFile(null);
    });

    test('banner GIỮ XANH khi engine đang generate (state=processing)', () async {
      final sent = facade.sendMessage('tin đang xử lý');
      await pumpEventQueue();

      expect(engine.state, AiEngineState.processing);
      // DoD #1: model đã nạp ⇒ hasModel vẫn true (banner xanh) trong suốt lượt
      // generate; bản cũ `isReady` chỉ nhận `ready` nên hasModel bật false.
      expect(facade.hasModel, isTrue);
      expect(facade.hasModelFile, isTrue);
      expect(facade.isChatLoading, isTrue);
      expect(facade.isModelLoading, isFalse,
          reason: 'không được rơi về trạng thái "đang nạp"/"chưa nạp"');

      engine.gates.first.complete();
      await sent;
      expect(facade.isChatLoading, isFalse);
      expect(facade.engineError, isNull);
      expect(facade.hasModel, isTrue);
    });

    test('hai tin liên tiếp được xếp hàng, trả lời đủ, không "not ready" giả',
        () async {
      final first = facade.sendMessage('tin một');
      await pumpEventQueue(times: 30);
      final second = facade.sendMessage('tin hai');
      await pumpEventQueue(times: 30);

      // Tin thứ hai KHÔNG bị nuốt và KHÔNG đẩy xuống isolate khi tin 1 còn chạy.
      expect(facade.chatQueueLength, 1);
      expect(engine.prompts, <String>['tin một']);
      expect(facade.hasModel, isTrue);

      engine.gates.first.complete();
      await pumpEventQueue(times: 30);
      expect(engine.prompts, <String>['tin một', 'tin hai'],
          reason: 'tin hai phải tự chạy sau khi tin một xong');

      engine.gates[1].complete();
      await Future.wait<void>(<Future<void>>[first, second]);

      final replies = facade.chatMessages
          .where((m) => m.role == ChatRole.assistant)
          .toList();
      expect(replies.length, 2);
      expect(replies.any((m) => m.isError), isFalse);
      expect(replies.any((m) => m.text.contains('not ready')), isFalse);
      expect(replies.any((m) => m.text.contains('chưa sẵn sàng')), isFalse);
      expect(replies.first.text, contains('tin một'));
      expect(replies.last.text, contains('tin hai'));
      expect(facade.isChatLoading, isFalse);
      expect(facade.chatQueueLength, 0);
    });

    test('timeout hữu hạn ⇒ lỗi rõ + retry được, tin sau vẫn chạy', () async {
      facade.chatRequestTimeout = const Duration(milliseconds: 150);

      await facade.sendMessage('tin chậm');

      // Không xoay vòng vô hạn: spinner tắt, có bubble lỗi để người dùng thử lại.
      expect(facade.isChatLoading, isFalse);
      final errorBubble = facade.chatMessages.last;
      expect(errorBubble.isError, isTrue);
      expect(errorBubble.text, contains('thử lại'));

      // Request treo ⇒ engine được dựng lại (recover) để tin sau chạy được.
      expect(engine.recoveries, isNotEmpty,
          reason: 'timeout còn request treo ⇒ phải recover ở nền');
      expect(await facade.restartEngine(), isTrue);
      expect(facade.engineError, isNull);
      expect(facade.hasModel, isTrue, reason: 'sau recover banner vẫn xanh');

      engine.autoAnswer = true;
      await facade.sendMessage('tin sau timeout');
      final last = facade.chatMessages.last;
      expect(last.role, ChatRole.assistant);
      expect(last.isError, isFalse);
      expect(last.text, contains('tin sau timeout'));
    });

    test('context gửi xuống engine bị giới hạn (không gửi toàn lịch sử)',
        () async {
      engine.autoAnswer = true;
      for (var i = 0; i < 12; i++) {
        await facade.sendMessage('câu số $i');
      }
      // Tin dài (5000 ký tự) không được ăn hết context.
      await facade.sendMessage('y' * 5000);
      await facade.sendMessage('câu cuối');

      // Context của tin dài: các tin gần nhất, không phải 10 tin ĐẦU hội thoại.
      final longContext = engine.contexts[engine.contexts.length - 2];
      expect(longContext, contains('câu số 11'));
      expect(longContext, isNot(contains('câu số 0')),
          reason: 'không gửi lại 10 tin đầu như bản cũ `take(10)`');
      expect(longContext.length,
          lessThanOrEqualTo(ChatContextPolicy.defaults.maxHistoryChars + 8));

      // Prompt khổng lồ ⇒ maxTokens bị hạ theo chỗ trống, không tràn context.
      expect(engine.maxTokensSeen, isNotEmpty);
      expect(engine.maxTokensSeen.every((t) => t >= 96 && t <= 512), isTrue,
          reason: 'maxTokens luôn dương và không vượt trần chat 512');
      for (final ctx in engine.contexts) {
        expect(ctx.length,
            lessThanOrEqualTo(ChatContextPolicy.defaults.maxHistoryChars + 8),
            reason: 'mọi prompt đều nằm trong ngân sách context');
      }
    });

    test('MODELS-002 không regress: import lỗi ⇒ stage failed, không báo "đã nạp"',
        () async {
      _useModelFile(null);
      facade.debugAttachEngine(AiEngineMock(), modelLoaded: false);

      // Môi trường test không có file picker ⇒ import thất bại có kiểm soát.
      final ok = await facade.importModelFromUser();

      expect(ok, isFalse);
      expect(facade.importStage, AiImportStage.failed);
      expect(facade.importError, isNotNull);
      expect(facade.isImportActive, isFalse);
      // Không được báo "AI sẵn sàng" giả khi import không thành công.
      expect(facade.hasModel, isFalse);
    });

    test('engine chết (state=error) ⇒ tin sau tự khởi động lại rồi trả lời',
        () async {
      engine.autoAnswer = true;
      engine.dead = true; // như isolate bị OOM thu hồi

      await facade.sendMessage('tin khi engine chết');

      expect(engine.recoveries, isNotEmpty,
          reason: 'facade phải tự recover thay vì báo "not ready" cho user');
      final last = facade.chatMessages.last;
      expect(last.role, ChatRole.assistant);
      expect(last.isError, isFalse);
      expect(last.text, contains('tin khi engine chết'));
      expect(facade.engineError, isNull);
      expect(facade.hasModel, isTrue);
    });
  });

  test(
      'AiEngineGemma: isolate chết (native treo/OOM) ⇒ request có kết cục '
      'hữu hạn + recover() cho tin sau', () async {
    final engine = AiEngineGemma();
    try {
      // Isolate "treo" (như llama.cpp deadlock): nhận request nhưng không bao
      // giờ trả lời — mô phỏng đúng ca "nút gửi xoay vòng mãi" của chủ.
      engine.debugSetIsolateHang(true);
      // modelPath rỗng: môi trường test không có libin4up_ai_native ⇒ isolate
      // tự dùng mock inference (đường đã có trong test của package).
      expect(await engine.initialize(modelPath: ''), isTrue);
      // Không ai await modelReady ở đây ⇒ phải không thành unhandled error.
      unawaited(engine.modelReady.then<void>((_) {}, onError: (Object _) {}));

      final pending = engine
          .analyze(text: 'hello', type: AiAnalysisType.conversation)
          .first;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(engine.isBusy, isTrue,
          reason: 'request đang chờ isolate treo ⇒ engine phải biết đang bận');

      engine.debugKillIsolate(); // như OOM killer thu hồi process con

      // KHÔNG treo vô hạn: mọi request đang chờ nhận lỗi rõ ràng.
      final result = await pending.timeout(const Duration(seconds: 10));
      expect(result.success, isFalse);
      expect(result.errorReason, contains('thu hồi'));
      expect(engine.state, AiEngineState.error,
          reason: 'backend chết ⇒ không được báo ready giả');
      expect(engine.isBusy, isFalse);

      // Request sau: recover() rồi chạy lại được (DoD #3).
      engine.debugSetIsolateHang(false); // isolate mới khoẻ
      expect(await engine.recover(reason: 'test isolate chết'), isTrue);
      expect(engine.state, AiEngineState.ready);
      final again = await engine
          .analyze(text: 'hello again', type: AiAnalysisType.wordLookup)
          .first
          .timeout(const Duration(seconds: 20));
      expect(again.success, isTrue);
      expect(again.summary, isNotEmpty);
    } finally {
      await engine.dispose();
    }
  });
}
