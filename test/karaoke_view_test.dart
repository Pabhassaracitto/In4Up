import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/app_ui_translations.dart';
import 'package:in4up/providers/karaoke_settings_provider.dart';
import 'package:in4up/widgets/karaoke_lyrics_line.dart';
import 'package:in4up/widgets/karaoke_settings_sheet.dart';
import 'package:in4up/widgets/karaoke_transcript_view.dart';
import 'package:in4up_stt/stt_lrc_converter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<LrcLine> lyrics() => List.generate(120, (index) => LrcLine(
  timestamp: Duration(seconds: index * 2),
  text: index % 5 == 0
      ? 'Line $index ${'a long lyric with wrapping and punctuation ' * 5}'
      : 'Line $index',
));

Widget host({
  required List<LrcLine> lines,
  required int current,
  KaraokeStyle style = const KaraokeStyle(),
  bool autoFollow = true,
  double height = 150,
  double textScale = 1,
  ValueChanged<LrcLine>? onTap,
}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: SizedBox(
          width: 280,
          height: height,
          child: KaraokeTranscriptView(
            lines: lines,
            currentLineIndex: current,
            currentWordIndex: 0,
            wordsForLine: (index) => lines[index].words,
            style: style,
            autoFollow: autoFollow,
            compact: true,
            translationForLine: (line) => line.text.startsWith('Line 9 ')
                ? 'A translation that wraps on a narrow display.'
                : null,
            onLineTap: onTap ?? (_) {},
          ),
        ),
      ),
    ),
  ),
);

Future<void> settleFollowing(WidgetTester tester) async {
  // The index jump is scheduled post-layout. Give it a frame, then let any
  // short in-viewport alignment animation finish.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pump();
}

void expectCurrentVisible(WidgetTester tester, int index) {
  final item = find.byKey(ValueKey('karaoke-line-$index'));
  expect(item, findsOneWidget);
  expect(item.hitTestable(), findsOneWidget);
  final itemRect = tester.getRect(item);
  final viewport = tester.getRect(find.byType(KaraokeTranscriptView));
  expect(itemRect.top, greaterThanOrEqualTo(viewport.top - 3));
  expect(itemRect.bottom, lessThanOrEqualTo(viewport.bottom + 3));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('long variable-height transcript follows far seeks and resizing', (tester) async {
    final lines = lyrics();
    const style = KaraokeStyle(showTranslation: true);
    await tester.pumpWidget(host(lines: lines, current: 1, style: style));
    await settleFollowing(tester);
    expectCurrentVisible(tester, 1);

    // A fixed index*height estimate cannot land correctly past many wrapping lines.
    await tester.pumpWidget(host(lines: lines, current: 71, style: style));
    await settleFollowing(tester);
    expectCurrentVisible(tester, 71);

    await tester.pumpWidget(host(
      lines: lines, current: 91, style: style, height: 100, textScale: 1.6,
    ));
    await settleFollowing(tester);
    expectCurrentVisible(tester, 91);

    await tester.pumpWidget(host(lines: lines, current: 3, style: style));
    await settleFollowing(tester);
    expectCurrentVisible(tester, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explicitly disabled auto-follow stays put; enabling catches up', (tester) async {
    final lines = lyrics();
    await tester.pumpWidget(host(lines: lines, current: 1, autoFollow: false));
    await settleFollowing(tester);
    await tester.pumpWidget(host(lines: lines, current: 81, autoFollow: false));
    await settleFollowing(tester);
    expect(find.byKey(const ValueKey('karaoke-line-81')).hitTestable(), findsNothing);
    await tester.pumpWidget(host(lines: lines, current: 81));
    await settleFollowing(tester);
    expectCurrentVisible(tester, 81);
  });

  testWidgets('manual scrolling is not fought, and follow resumes after the grace period', (tester) async {
    final lines = lyrics();
    await tester.pumpWidget(host(lines: lines, current: 41));
    await settleFollowing(tester);
    expectCurrentVisible(tester, 41);
    await tester.drag(find.byType(KaraokeTranscriptView), const Offset(0, 350));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('karaoke-line-41')).hitTestable(), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await settleFollowing(tester);
    expectCurrentVisible(tester, 41);
  });

  testWidgets('single-line mode shows only the current line and seeks on tap', (tester) async {
    final lines = lyrics();
    final selected = <LrcLine>[];
    const style = KaraokeStyle(displayMode: KaraokeDisplayMode.currentLineOnly);
    await tester.pumpWidget(host(lines: lines, current: -1, style: style));
    expect(find.text('Waiting for the first line'), findsOneWidget);
    await tester.pumpWidget(host(lines: lines, current: 13, style: style, onTap: selected.add));
    await settleFollowing(tester);
    expect(find.byKey(const ValueKey('karaoke-line-13')), findsOneWidget);
    expect(find.text('Line 12'), findsNothing);
    expect(find.text('Line 14'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('karaoke-line-13')));
    expect(selected.single.timestamp, const Duration(seconds: 26));
    await tester.pumpWidget(host(lines: lines, current: 14, style: style));
    await settleFollowing(tester);
    expect(find.byKey(const ValueKey('karaoke-line-13')), findsNothing);
    expect(find.byKey(const ValueKey('karaoke-line-14')), findsOneWidget);
  });

  testWidgets('source text is not translated or re-spaced during word highlighting', (tester) async {
    final line = LrcLine(
      timestamp: Duration.zero,
      text: '你好，世界  foo!',
      words: const [
        LrcWord(word: '你好', start: Duration.zero),
        LrcWord(word: '世界', start: Duration(seconds: 1)),
        LrcWord(word: 'foo', start: Duration(seconds: 2)),
      ],
    );
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: KaraokeLyricsLine(
      line: line, isActive: true, words: line.words, activeWordIndex: 1,
    ))));
    final rich = tester.widget<RichText>(find.descendant(
      of: find.byType(KaraokeLyricsLine), matching: find.byType(RichText),
    ));
    expect(rich.text.toPlainText(), line.text);
    final userText = LrcLine(timestamp: Duration.zero, text: 'Bài trước');
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: KaraokeLyricsLine(
      line: userText, isActive: false,
      style: const KaraokeStyle(fontSize: 16, inactiveFontSize: 24),
    ))));
    expect(find.text('Bài trước'), findsOneWidget);
    expect(tester.widget<Text>(find.text('Bài trước')).style!.fontSize, lessThan(16));
  });

  test('display preference defaults safely and persists the latest selection', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = KaraokeSettingsProvider();
    await settings.load();
    expect(settings.style.displayMode, KaraokeDisplayMode.context);
    final first = settings.update(settings.style.copyWith(
      displayMode: KaraokeDisplayMode.currentLineOnly,
    ));
    final second = settings.update(settings.style.copyWith(
      displayMode: KaraokeDisplayMode.context,
    ));
    await Future.wait([first, second]);
    final restored = KaraokeSettingsProvider();
    await restored.load();
    expect(restored.style.displayMode, KaraokeDisplayMode.context);
    await restored.update(restored.style.copyWith(
      displayMode: KaraokeDisplayMode.currentLineOnly,
    ));
    final next = KaraokeSettingsProvider();
    await next.load();
    expect(next.style.displayMode, KaraokeDisplayMode.currentLineOnly);
    settings.dispose();
    restored.dispose();
    next.dispose();
  });

  testWidgets('settings sheet offers both choices on a short screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = KaraokeSettingsProvider();
    await tester.binding.setSurfaceSize(const Size(320, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ChangeNotifierProvider<KaraokeSettingsProvider>.value(
      value: settings,
      child: MaterialApp(home: Scaffold(body: Builder(builder: (context) => TextButton(
        onPressed: () => KaraokeSettingsSheet.show(context),
        child: const Text('Open'),
      )))),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Current line only'), findsOneWidget);
    expect(find.text('Other lines smaller and dimmed'), findsOneWidget);
    await tester.tap(find.text('Current line only'));
    await tester.ensureVisible(find.text('Apply'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(settings.style.displayMode, KaraokeDisplayMode.currentLineOnly);
    expect(tester.takeException(), isNull);
    settings.dispose();
  });

  test('new chrome has priority translations and English fallback', () {
    const labels = [
      'Kiểu hiển thị lời',
      'Chỉ dòng hiện hành',
      'Dòng khác mờ và nhỏ',
      'Chưa đến dòng đầu tiên',
      'Tự cuộn lời',
      'Cỡ chữ (dòng đang phát)',
    ];
    for (final label in labels) {
      final en = AppUITranslations.translate(label, 'en');
      expect(en, isNot(label));
      expect(AppUITranslations.translate(label, 'es'), en);
      for (final locale in ['hi', 'zh', 'zh_TW', 'si', 'my', 'th', 'ja']) {
        final translated = AppUITranslations.translate(label, locale);
        expect(translated, isNot(label), reason: '$locale: $label');
        expect(translated, isNot(en), reason: '$locale: $label');
      }
    }
  });
}
