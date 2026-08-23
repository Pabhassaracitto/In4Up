import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/models/text_item.dart';
import 'package:in4up/screens/understand_mode/services/lrc_translation_resolver.dart';

void main() {
  group('resolveLrcTranslation', () {
    test('reuses an exact saved Read translation', () {
      final lines = [
        TextItem(
          id: 'line-1',
          content: 'How are you?',
          translation: 'Bạn khỏe không?',
        ),
      ];

      expect(
        resolveLrcTranslation(lines, '  HOW   ARE YOU? '),
        'Bạn khỏe không?',
      );
    });

    test('matches different Read and LRC segment boundaries', () {
      final lines = [
        TextItem(
          id: 'line-1',
          content: 'Welcome back',
          translation: 'Chào mừng trở lại',
        ),
      ];

      expect(
        resolveLrcTranslation(lines, 'Hello and welcome back to the show'),
        'Chào mừng trở lại',
      );
    });

    test('ignores empty translations and unrelated lines', () {
      final lines = [
        TextItem(id: 'line-1', content: 'Hello', translation: '  '),
        TextItem(id: 'line-2', content: 'Goodbye'),
      ];

      expect(resolveLrcTranslation(lines, 'Hello'), isNull);
    });
  });
}
