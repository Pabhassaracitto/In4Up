import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/screens/ai_chat/ai_chat_screen.dart';
import 'package:in4up_ai/in4up_ai.dart';

void main() {
  testWidgets('thinking only before the first answer token', (tester) async {
    final user = ChatMessage(id: 'u', role: ChatRole.user, text: 'Hi');
    final placeholder = ChatMessage(id: 'a', role: ChatRole.assistant, text: '');
    Future<void> show(bool loading, List<ChatMessage> messages) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ThinkingIndicator(isLoading: loading, messages: messages)),
      ));
    }

    await show(true, [user]);
    expect(find.text('Thinking…'), findsOneWidget);
    await show(true, [user, placeholder]);
    expect(find.text('Thinking…'), findsOneWidget);
    await show(true, [user, placeholder.copyWith(text: 'First token')]);
    expect(find.text('Thinking…'), findsNothing);
    await show(false, [user]);
    expect(find.text('Thinking…'), findsNothing);
  });

  test('screen keeps original Vietnamese translation key', () {
    expect(File('lib/screens/ai_chat/ai_chat_screen.dart').readAsStringSync(),
        contains('Đang suy nghĩ'));
  });
}
