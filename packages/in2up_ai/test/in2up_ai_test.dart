import 'package:flutter_test/flutter_test.dart';
import 'package:in2up_ai/in2up_ai.dart';

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
}
