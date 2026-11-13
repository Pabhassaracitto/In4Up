import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/localized_material.dart';
import 'package:in4up/features/shadowing/services/lrc_ab_suggestions.dart';
import 'package:in4up/features/shadowing/widgets/shadowing_sentence_picker.dart';
import 'package:in4up_stt/stt_lrc_converter.dart' show LrcLine;

void main() {
  final suggestions = LrcAbSuggestions.buildSentenceSuggestions(
    lines: [
      LrcLine(timestamp: Duration.zero, text: 'First line.'),
      LrcLine(timestamp: const Duration(seconds: 5), text: 'Second line.'),
      LrcLine(timestamp: const Duration(seconds: 10), text: 'Third line.'),
    ],
    trackDuration: const Duration(seconds: 15),
  );

  testWidgets('PSRC-228: existing lyric hints are visible and select exactly one line', (tester) async {
    final selected = <AbSuggestion>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ShadowingSentencePicker(
            suggestions: suggestions,
            selectedIndex: -1,
            onSelected: selected.add,
            onUseCurrent: () {},
          ),
        ),
      ),
    ));

    expect(find.byKey(const ValueKey('shadowing-sentence-picker')), findsOneWidget);
    expect(find.text('First line.'), findsOneWidget);
    expect(find.text('Second line.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('shadowing-sentence-2')));
    expect(selected.single.text, 'Third line.');
    expect(selected.single.start, const Duration(seconds: 10));
    expect(selected.single.end, const Duration(seconds: 15));
  });

  testWidgets('empty timed data renders no dead picker', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ShadowingSentencePicker(
          suggestions: const [],
          selectedIndex: -1,
          onSelected: (_) {},
          onUseCurrent: () {},
        ),
      ),
    ));
    expect(find.byKey(const ValueKey('shadowing-sentence-picker')), findsNothing);
  });

  test('PSRC-228: both tabs share the picker and the speakSentence entry point', () {
    final speak = File('lib/features/shadowing/widgets/shadowing_widget.dart').readAsStringSync();
    final understand = File('lib/screens/understand_mode/understand_mode_screen.dart').readAsStringSync();
    for (final source in [speak, understand]) {
      expect(source, contains('ShadowingSentencePicker('));
      expect(source, contains('shadowing.speakSentence(index)'));
      expect(source, contains('shadowing.setSentenceSuggestions('));
    }
    expect(understand, isNot(contains("linesInLoop.join(' ')")));
    expect(understand, contains('final loopText = selected?.text'));
  });
}
