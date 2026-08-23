import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_ai/in4up_ai.dart';
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
