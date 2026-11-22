// PSRC-264 — ngữ cảnh "trợ lý hiểu bài" (và ngữ cảnh YouTube) chỉ được đính
// vào prompt của lượt ĐẦU, KHÔNG tái đính vào mọi câu hỏi sau.
//
// Root cause trước khi sửa: cả `ai_chat_screen.dart` lẫn `yt_lexa_chat_tab.dart`
// đều NỐI block ngữ cảnh THẲNG vào text người dùng rồi `sendMessage(text)`.
// Facade lưu/sends nguyên chuỗi đó làm tin user ⇒ `ChatContextPolicy` tái đưa
// các tin user đã-wrap vào prompt của MỌI lượt sau ⇒ hỏi tiếp chuyện khác vẫn
// bị "dính" prompt của tab Hiểu, và bubble user hiện cả preamble dài.
//
// Sửa: tách `ChatMessage.oneShotContext` — lưu RIÊNG khỏi `text` hiển thị, chỉ
// đưa vào prompt của ĐÚNG lượt đó (qua `_composeUserPrompt`), còn lịch sử giữ
// `text` thuần. File này pin hành vi đó bằng facade + engine giả (bắt prompt),
// thêm source-scan để máy bắt "screen không còn nối preamble vào mọi tin".
//
// Chạy: flutter test test/ai_chat/chat_oneshot_context_test.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_ai/in4up_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Engine giả: trả lời ngay, ghi lại prompt + context từng lượt để soi.
class _CaptureEngine implements AiEngine {
  final List<String> prompts = <String>[];
  final List<String> contexts = <String>[];
  AiEngineState _state = AiEngineState.ready;

  @override
  AiEngineState get state => _state;

  @override
  bool get isBusy => false;

  @override
  Future<void> get modelReady => Future<void>.value();

  @override
  Future<bool> initialize({required String modelPath}) async => true;

  @override
  Future<bool> recover({String? reason}) async => true;

  @override
  Stream<AiAnalysis> analyze({
    required String text,
    required AiAnalysisType type,
    String? context,
    double temperature = 0.1,
    int maxTokens = 256,
  }) async* {
    prompts.add(text);
    contexts.add(context ?? '');
    _state = AiEngineState.ready;
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatMessage.oneShotContext — model', () {
    test('toJson/fromJson vòng tròn giữ ngữ cảnh một lần', () {
      final original = ChatMessage(
        id: 'u1',
        role: ChatRole.user,
        text: 'giải thích câu này',
        oneShotContext: 'Bài: Demo\nCâu trọng tâm: Hello world',
        createdAt: DateTime.utc(2026, 11, 22, 8, 30),
      );
      final restored = ChatMessage.fromJson(original.toJson());
      expect(restored.text, 'giải thích câu này');
      expect(restored.oneShotContext, 'Bài: Demo\nCâu trọng tâm: Hello world');
      expect(restored.role, ChatRole.user);
    });

    test('lịch sử cũ (không có field oneShotContext) vẫn đọc được', () {
      final restored = ChatMessage.fromJson(<String, dynamic>{
        'id': 'u9',
        'role': 'user',
        'text': 'câu cũ',
      });
      expect(restored.oneShotContext, isNull);
      expect(restored.toJson().containsKey('oneShotContext'), isFalse,
          reason: 'không ghi key thừa khi null — JSON gọn');
    });

    test('copyWith giữ oneShotContext khi sửa text (streaming)', () {
      final msg = ChatMessage(
        id: 'u2',
        role: ChatRole.user,
        text: 'hỏi',
        oneShotContext: 'ctx',
      );
      expect(msg.copyWith(text: 'hỏi (đã sửa)').oneShotContext, 'ctx');
    });
  });

  group('AiServiceFacade — oneShotContext chỉ đính vào đúng lượt', () {
    late AiServiceFacade facade;
    late _CaptureEngine engine;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      facade = AiServiceFacade();
      engine = _CaptureEngine();
      facade.debugAttachEngine(engine, modelLoaded: true);
    });

    tearDown(() => facade.dispose());

    test('prompt lượt 1 chứa ngữ cảnh; bubble user chỉ hiện câu hỏi', () async {
      await facade.sendMessage(
        'giải thích câu này',
        oneShotContext: 'Bài: Demo\nCâu trọng tâm: Hello world',
      );

      // Prompt xuống engine: ngữ cảnh + câu hỏi (một lần).
      expect(engine.prompts, hasLength(1));
      expect(engine.prompts.single, contains('Bài: Demo'));
      expect(engine.prompts.single, contains('Câu trọng tâm: Hello world'));
      expect(engine.prompts.single, contains('giải thích câu này'));

      // Bubble user chỉ hiện câu hỏi người dùng gõ — không lộ preamble.
      final userBubble =
          facade.chatMessages.firstWhere((m) => m.role == ChatRole.user);
      expect(userBubble.text, 'giải thích câu này');
      expect(userBubble.text, isNot(contains('Bài: Demo')));
    });

    test('lượt 2 KHÔNG tái đính ngữ cảnh của lượt 1 (cả prompt lẫn history)',
        () async {
      await facade.sendMessage(
        'giải thích câu này',
        oneShotContext: 'Bài: Demo\nCâu trọng tâm: Hello world',
      );
      await facade.sendMessage('còn từ này thì sao');

      expect(engine.prompts, hasLength(2));
      // Prompt của lượt 2 chỉ là câu hỏi thuần…
      expect(engine.prompts[1], 'còn từ này thì sao');
      // …và context (lịch sử) của lượt 2 KHÔNG chứa preamble của lượt 1 —
      // chính là bug "prompt tab Hiểu đính vào mọi tin" đã được dập.
      expect(engine.contexts[1], isNot(contains('Bài: Demo')),
          reason: 'lịch sử giữ text thuần ⇒ không tái đính preamble');
      expect(engine.contexts[1], contains('giải thích câu này'));
    });

    test('không truyền oneShotContext ⇒ prompt đúng bằng câu hỏi (chat Home)',
        () async {
      await facade.sendMessage('hello');
      expect(engine.prompts.single, 'hello');
    });
  });

  group('ai_chat_screen.dart — source-scan (máy bắt regression)', () {
    final src =
        File('lib/screens/ai_chat/ai_chat_screen.dart').readAsStringSync();

    test('screen dùng oneShotContext, không còn nối preamble vào text', () {
      expect(src, contains('oneShotContext:'),
          reason: 'screen phải truyền ngữ cảnh qua oneShotContext');
      expect(src, contains('_coachContextSent'),
          reason: 'screen phải theo dõi "đã đính ngữ cảnh lượt đầu chưa"');
    });

    test('screen chỉ đính ngữ cảnh khi chưa gửi (attachCoach = !sent)', () {
      expect(src, contains('coach != null && !_coachContextSent'),
          reason: 'ngữ cảnh chỉ đính vào lượt đầu tiên, không phải mọi tin');
    });
  });
}
