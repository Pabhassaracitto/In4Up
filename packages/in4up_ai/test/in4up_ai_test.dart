import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_ai/in4up_ai.dart';
import 'package:in4up_ai/src/prompts/ai_prompts_library.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('chat message round trips through JSON', () {
    final original = ChatMessage(
      id: 'm1',
      role: ChatRole.user,
      text: 'How do I use this word?',
      createdAt: DateTime.parse('2026-08-10T10:00:00.000Z'),
    );

    final restored = ChatMessage.fromJson(original.toJson());
    expect(restored.id, original.id);
    expect(restored.role, ChatRole.user);
    expect(restored.text, original.text);
    expect(restored.createdAt, original.createdAt);
  });

  test('conversation type is available to the AI contract', () {
    expect(AiAnalysisType.values, contains(AiAnalysisType.conversation));
  });

  test('mapper returns a safe fallback for malformed model output', () {
    final result = AiModelMapper.parse(
      rawOutput: 'not json',
      inputText: 'hello',
      type: AiAnalysisType.conversation,
    );
    expect(result.success, isFalse);
    expect(result.source, AiAnalysisSource.fallback);
  });

  test(
      'gemma engine falls back to mock inference when native backend is unavailable',
      () async {
    // Môi trường test/CI không có libin4up_ai_native.so/dll ⇒ isolate phải
    // fallback về _mockInference và vẫn trả analysis hợp lệ (không crash).
    final engine = AiEngineGemma();
    try {
      final ok = await engine.initialize(modelPath: '');
      expect(ok, isTrue);
      final result = await engine
          .analyze(text: 'hello', type: AiAnalysisType.wordLookup)
          .first;
      expect(result.success, isTrue);
      expect(result.summary, isNotEmpty);
    } finally {
      await engine.dispose();
    }
  });

  test('conversation prompt is Gemma chat, not JSON analysis', () {
    final prompt = AiPromptsLibrary.buildPrompt(
      type: AiAnalysisType.conversation,
      text: 'Hello',
      context: 'user: hi',
    );
    expect(prompt, contains('<start_of_turn>user'));
    expect(prompt, contains('<start_of_turn>model'));
    expect(prompt, contains('Student: Hello'));
    expect(prompt.toLowerCase(), isNot(contains('return only valid json')));
    expect(prompt, isNot(contains('technical_terms')));
  });

  test('plain chat text becomes the reply instead of Invalid Gemma JSON', () {
    final result = AiAnalysis.fromGemmaJson(
      'Mình có thể giúp bạn luyện từ vựng.<end_of_turn>',
      analysisType: AiAnalysisType.conversation,
      inputText: 'Hello',
    );
    expect(result.success, isTrue);
    expect(result.summary, contains('luyện từ vựng'));
    expect(result.summary, isNot(contains('<end_of_turn>')));
  });

  test('recentChatContext uses last turns, not the first, and skips errors', () {
    final messages = <ChatMessage>[
      for (var i = 0; i < 12; i++)
        ChatMessage(id: 'u$i', role: ChatRole.user, text: 'old-$i'),
      ChatMessage(
        id: 'err',
        role: ChatRole.assistant,
        text: 'AI xử lý quá lâu',
        isError: true,
      ),
      ChatMessage(id: 'now', role: ChatRole.user, text: 'current question'),
    ];
    final ctx = AiServiceFacade.recentChatContext(messages, maxTurns: 6);
    expect(ctx, isNot(contains('old-0')));
    expect(ctx, isNot(contains('AI xử lý quá lâu')));
    expect(ctx, isNot(contains('current question')));
    expect(ctx, contains('old-11'));
  });

  test('facade reports hasModel=false in mock mode (truthful model status)',
      () async {
    SharedPreferences.setMockInitialValues({});
    final facade = AiServiceFacade();
    try {
      await facade.initialize(modelPath: '', useMock: true);
      expect(facade.useMock, isTrue);
      // Fix: hasModel phải PHẢN ÁNH model thật — mock mode không được báo
      // "AI model đã sẵn sàng".
      expect(facade.hasModel, isFalse);
      // Mock engine vẫn trả lời được (isReady) nhưng không phải model thật.
      expect(facade.isReady, isTrue);
    } finally {
      facade.dispose();
    }
  });
}
