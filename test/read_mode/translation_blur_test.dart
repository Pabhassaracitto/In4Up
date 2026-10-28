import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/translation/translation_display_mode.dart';
import 'package:in4up/features/translation/translation_toolbar.dart';

void main() {
  for (final mode in [TranslationDisplayMode.stackedBelow, TranslationDisplayMode.sideBySide]) {
    testWidgets('translation can be revealed and hidden in $mode', (tester) async {
      Widget build(String text, {bool blur = true}) => MaterialApp(
            home: Scaffold(
              body: TranslationLineDisplay(
                originalText: 'Original',
                translatedText: text,
                displayMode: mode,
                blurTranslation: blur,
                originalWidget: const Text('Original'),
              ),
            ),
          );

      await tester.pumpWidget(build('Answer'));
      expect(find.ancestor(of: find.text('Answer'), matching: find.byType(ExcludeSemantics)), findsOneWidget);
      await tester.tap(find.text('Answer'));
      await tester.pump();
      expect(find.ancestor(of: find.text('Answer'), matching: find.byType(ExcludeSemantics)), findsNothing);
      await tester.tap(find.text('Answer'));
      await tester.pump();
      expect(find.ancestor(of: find.text('Answer'), matching: find.byType(ExcludeSemantics)), findsOneWidget);

      await tester.tap(find.text('Answer'));
      await tester.pump();
      await tester.pumpWidget(build('New answer'));
      expect(find.ancestor(of: find.text('New answer'), matching: find.byType(ExcludeSemantics)), findsOneWidget);
      await tester.pumpWidget(build('New answer', blur: false));
      expect(find.ancestor(of: find.text('New answer'), matching: find.byType(ExcludeSemantics)), findsNothing);
    });
  }
}
