import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/providers/text_provider.dart';
import 'package:in4up/screens/read_mode/write_studio_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildSubject(TextProvider textProvider) {
    return ChangeNotifierProvider<TextProvider>.value(
      value: textProvider,
      child: MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: WriteStudioScreen(
            onOpenWebReader: () {},
            onOpenPdfReader: () {},
            onOpenQuickActions: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('all writing exercises are selectable before choosing a source',
      (tester) async {
    final textProvider = TextProvider();
    await tester.pumpWidget(buildSubject(textProvider));
    await tester.pump();

    expect(find.byKey(const ValueKey('write-exercise-dictation')), findsOneWidget);
    expect(find.byKey(const ValueKey('write-exercise-clozeInput')), findsOneWidget);
    expect(find.byKey(const ValueKey('write-exercise-clozeChoice')), findsOneWidget);
    expect(find.byKey(const ValueKey('write-exercise-rewrite')), findsOneWidget);
    expect(find.byKey(const ValueKey('write-exercise-summary')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('write-exercise-rewrite')));
    await tester.pump();

    expect(find.text('Đang chọn · Viết lại ý'), findsOneWidget);
    expect(find.byKey(const ValueKey('write-source-starter')), findsOneWidget);
  });

  testWidgets('pasted text starts the selected writing exercise',
      (tester) async {
    final textProvider = TextProvider();
    await tester.pumpWidget(buildSubject(textProvider));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('write-exercise-rewrite')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('write-manual-source-field')),
      'Learning improves when feedback is specific.',
    );
    final startButton = find.byKey(const ValueKey('write-use-manual-source'));
    await tester.ensureVisible(startButton);
    await tester.tap(startButton);
    await tester.pump();

    expect(textProvider.hasLyrics, isTrue);
    expect(find.text('Viết lại ý bằng câu khác'), findsOneWidget);
    expect(find.byKey(const ValueKey('write-source-starter')), findsNothing);

    final summarySelector =
        find.byKey(const ValueKey('write-exercise-summary'));
    await tester.ensureVisible(summarySelector);
    await tester.tap(summarySelector);
    await tester.pump();
    expect(find.text('Tóm tắt nội dung dài'), findsOneWidget);
  });

  testWidgets('every selector opens its functional exercise card',
      (tester) async {
    const cases = <(String, String)>[
      ('dictation', 'Chép chính tả / Recall câu'),
      ('clozeInput', 'Cloze · Điền từ'),
      ('clozeChoice', 'Cloze · Chọn đáp án'),
      ('rewrite', 'Viết lại ý bằng câu khác'),
      ('summary', 'Tóm tắt nội dung dài'),
    ];

    for (final exerciseCase in cases) {
      final textProvider = TextProvider();
      await tester.pumpWidget(buildSubject(textProvider));
      await tester.pump();

      final selector =
          find.byKey(ValueKey('write-exercise-${exerciseCase.$1}'));
      await tester.ensureVisible(selector);
      await tester.tap(selector);
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('write-manual-source-field')),
        'Focused practice and specific feedback help learners improve every day.',
      );
      final startButton = find.byKey(const ValueKey('write-use-manual-source'));
      await tester.ensureVisible(startButton);
      await tester.tap(startButton);
      await tester.pump();

      expect(find.text(exerciseCase.$2), findsOneWidget,
          reason: 'Exercise ${exerciseCase.$1} did not open');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}
